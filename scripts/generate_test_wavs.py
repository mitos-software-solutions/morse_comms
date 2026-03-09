"""
Generate synthetic Morse code WAV files for testing the Morse Comms decoder.

Each WAV is a pure sine wave shaped by ITU-R Morse timing, written as
16-bit mono PCM at 44100 Hz — the same format the app records and expects.

Supports additive white Gaussian noise at a specified SNR (dB).

Usage:
    python scripts/generate_test_wavs.py

Output: scripts/test_wavs/*.wav
"""

import math
import random
import struct
import os

# ── Constants ─────────────────────────────────────────────────────────────────

SAMPLE_RATE  = 44100
FREQUENCY_HZ = 700.0
AMPLITUDE    = 16000.0   # ~49 % of full scale (leaves headroom for noise)
FRAME_SIZE   = 512       # Must match app's kFrameSize

MORSE_TABLE = {
    'A': '.-',   'B': '-...', 'C': '-.-.', 'D': '-..',  'E': '.',
    'F': '..-.', 'G': '--.',  'H': '....', 'I': '..',   'J': '.---',
    'K': '-.-',  'L': '.-..', 'M': '--',   'N': '-.',   'O': '---',
    'P': '.--.', 'Q': '--.-', 'R': '.-.',  'S': '...',  'T': '-',
    'U': '..-',  'V': '...-', 'W': '.--',  'X': '-..-', 'Y': '-.--',
    'Z': '--..',
    '0': '-----', '1': '.----', '2': '..---', '3': '...--', '4': '....-',
    '5': '.....', '6': '-....', '7': '--...', '8': '---..', '9': '----.',
    '/': '-..-.', '?': '..--..', '.': '.-.-.-', ',': '--..--',
}

# ── Audio helpers ─────────────────────────────────────────────────────────────

def dot_samples(wpm: int) -> int:
    """Samples per dot unit at the given WPM (1200/wpm ms x sample rate)."""
    return round(SAMPLE_RATE * 1200 / (wpm * 1000))


def build_events(message: str, wpm: int) -> list[tuple[bool, int]]:
    """Return a list of (tone_on, num_samples) segments for the message."""
    dot = dot_samples(wpm)
    events: list[tuple[bool, int]] = []

    # Silent lead-in: 110 frames -- gives the OfflineAnalyzer plenty of noise floor data.
    events.append((False, 110 * FRAME_SIZE))

    words = message.upper().strip().split()
    for wi, word in enumerate(words):
        for ci, char in enumerate(word):
            pattern = MORSE_TABLE.get(char)
            if pattern is None:
                continue
            for si, sym in enumerate(pattern):
                duration = dot * 3 if sym == '-' else dot
                events.append((True, duration))
                if si < len(pattern) - 1:
                    events.append((False, dot))          # inter-symbol gap
            if ci < len(word) - 1:
                events.append((False, dot * 3))          # inter-letter gap
        if wi < len(words) - 1:
            events.append((False, dot * 7))              # inter-word gap

    # Trailing silence: 20 frames -- triggers final debounce.
    events.append((False, 20 * FRAME_SIZE))
    return events


def _gauss(rng: random.Random) -> float:
    """Box-Muller transform: one Gaussian N(0,1) sample."""
    while True:
        u1 = rng.random()
        if u1 > 1e-10:
            break
    u2 = rng.random()
    return math.sqrt(-2.0 * math.log(u1)) * math.cos(2.0 * math.pi * u2)


def render_pcm(
    events: list[tuple[bool, int]],
    freq_hz: float = FREQUENCY_HZ,
    snr_db: float | None = None,
    seed: int = 42,
) -> bytes:
    """Render event list to 16-bit signed PCM bytes (little-endian)."""
    rng = random.Random(seed)
    # noise_sigma: sigma = A / sqrt(2 * 10^(SNR/10))
    noise_sigma = (
        AMPLITUDE / math.sqrt(2.0 * 10.0 ** (snr_db / 10.0))
        if snr_db is not None
        else 0.0
    )

    samples: list[int] = []
    offset = 0
    for tone_on, count in events:
        for i in range(count):
            s = (
                AMPLITUDE * math.sin(2 * math.pi * freq_hz * (offset + i) / SAMPLE_RATE)
                if tone_on
                else 0.0
            )
            if noise_sigma > 0:
                s += noise_sigma * _gauss(rng)
            samples.append(max(-32768, min(32767, round(s))))
        offset += count
    return struct.pack(f'<{len(samples)}h', *samples)


def build_wav(pcm_bytes: bytes) -> bytes:
    """Wrap PCM bytes in a standard 44-byte WAV header."""
    data_len  = len(pcm_bytes)
    byte_rate = SAMPLE_RATE * 2      # 16-bit mono
    header = struct.pack(
        '<4sI4s4sIHHIIHH4sI',
        b'RIFF', 36 + data_len,
        b'WAVE',
        b'fmt ', 16,
        1,           # PCM
        1,           # mono
        SAMPLE_RATE,
        byte_rate,
        2,           # block align
        16,          # bits per sample
        b'data', data_len,
    )
    return header + pcm_bytes


def write_wav(
    path: str,
    message: str,
    wpm: int,
    snr_db: float | None = None,
    freq_hz: float = FREQUENCY_HZ,
    seed: int = 42,
) -> None:
    events  = build_events(message, wpm)
    pcm     = render_pcm(events, freq_hz=freq_hz, snr_db=snr_db, seed=seed)
    wav     = build_wav(pcm)
    total_s = sum(n for _, n in events) / SAMPLE_RATE
    snr_str = f'{snr_db:.0f}dB' if snr_db is not None else 'clean'
    with open(path, 'wb') as f:
        f.write(wav)
    print(f'  {os.path.basename(path):50s}  {len(wav)//1024:5d} KB  {total_s:.1f} s  [{snr_str}]')


# ── Test cases ────────────────────────────────────────────────────────────────
#
# Format: (filename_stem, message, wpm, snr_db, freq_hz)
#   snr_db=None  -> clean signal
#   snr_db=20.0  -> 20 dB SNR (moderate noise)
#   snr_db=10.0  -> 10 dB SNR (heavy noise)
#   snr_db=5.0   -> 5 dB SNR (near-limit)

BASELINE_CASES: list[tuple[str, str, int, float | None, float]] = [
    # ── Core messages at 20 WPM, clean ─────────────────────────────────────
    ('sos_20wpm',         'SOS',         20,  None,  700.0),
    ('hello_20wpm',       'HELLO',       20,  None,  700.0),
    ('paris_20wpm',       'PARIS',       20,  None,  700.0),
    ('cq_cq_20wpm',       'CQ CQ',       20,  None,  700.0),
    ('de_w1aw_20wpm',     'DE W1AW',     20,  None,  700.0),

    # ── WPM range, clean ────────────────────────────────────────────────────
    ('sos_5wpm',          'SOS',          5,  None,  700.0),
    ('sos_10wpm',         'SOS',         10,  None,  700.0),
    ('sos_15wpm',         'SOS',         15,  None,  700.0),
    ('sos_25wpm',         'SOS',         25,  None,  700.0),

    # ── Longer messages ─────────────────────────────────────────────────────
    ('alphabet_20wpm',    'ABCDEFGHIJKLMNOPQRSTUVWXYZ', 20, None, 700.0),
    ('numbers_20wpm',     '0123456789',  20,  None,  700.0),
    ('hello_world_15wpm', 'HELLO WORLD', 15,  None,  700.0),
]

LIMIT_CASES: list[tuple[str, str, int, float | None, float]] = [
    # ── High WPM (clean) ────────────────────────────────────────────────────
    ('sos_30wpm',         'SOS',         30,  None,  700.0),
    ('sos_35wpm',         'SOS',         35,  None,  700.0),
    ('sos_40wpm',         'SOS',         40,  None,  700.0),
    ('paris_30wpm',       'PARIS',       30,  None,  700.0),
    ('paris_40wpm',       'PARIS',       40,  None,  700.0),
    ('alphabet_30wpm',    'ABCDEFGHIJKLMNOPQRSTUVWXYZ', 30, None, 700.0),

    # ── Moderate noise (20 dB SNR) ───────────────────────────────────────────
    ('sos_20wpm_20db',    'SOS',         20, 20.0,  700.0),
    ('sos_25wpm_20db',    'SOS',         25, 20.0,  700.0),
    ('sos_30wpm_20db',    'SOS',         30, 20.0,  700.0),
    ('sos_40wpm_20db',    'SOS',         40, 20.0,  700.0),
    ('paris_20wpm_20db',  'PARIS',       20, 20.0,  700.0),
    ('hello_world_20db',  'HELLO WORLD', 20, 20.0,  700.0),

    # ── Heavy noise (10 dB SNR) ──────────────────────────────────────────────
    ('sos_5wpm_10db',     'SOS',          5, 10.0,  700.0),
    ('sos_10wpm_10db',    'SOS',         10, 10.0,  700.0),
    ('sos_20wpm_10db',    'SOS',         20, 10.0,  700.0),
    ('sos_30wpm_10db',    'SOS',         30, 10.0,  700.0),
    ('sos_40wpm_10db',    'SOS',         40, 10.0,  700.0),

    # ── Near-limit noise (5 dB SNR) ──────────────────────────────────────────
    ('sos_20wpm_5db',     'SOS',         20,  5.0,  700.0),
    ('sos_20wpm_3db',     'SOS',         20,  3.0,  700.0),
    ('paris_20wpm_5db',   'PARIS',       20,  5.0,  700.0),

    # ── Frequency offset (detector tuned to 700 Hz, tone at different freq) ──
    # These simulate a transmitter slightly off-frequency.
    ('sos_freq_672hz',    'SOS',         20,  None, 672.0),
    ('sos_freq_685hz',    'SOS',         20,  None, 685.0),
    ('sos_freq_715hz',    'SOS',         20,  None, 715.0),
    ('sos_freq_728hz',    'SOS',         20,  None, 728.0),
    ('sos_freq_750hz',    'SOS',         20,  None, 750.0),
    ('sos_freq_650hz',    'SOS',         20,  None, 650.0),  # large offset
    ('sos_freq_800hz',    'SOS',         20,  None, 800.0),  # large offset

    # ── Single-character edge cases ──────────────────────────────────────────
    ('char_E_20wpm',      'E',           20,  None, 700.0),
    ('char_T_20wpm',      'T',           20,  None, 700.0),
    ('char_M_20wpm',      'M',           20,  None, 700.0),
    ('char_O_20wpm',      'O',           20,  None, 700.0),

    # ── All-dots and all-dashes stress ──────────────────────────────────────
    ('eeeee_40wpm',       'EEEEE',       40,  None, 700.0),
    ('ttttt_40wpm',       'TTTTT',       40,  None, 700.0),
]

# ── Entry point ───────────────────────────────────────────────────────────────

if __name__ == '__main__':
    out_dir = os.path.join(os.path.dirname(__file__), 'test_wavs')
    os.makedirs(out_dir, exist_ok=True)

    all_cases = BASELINE_CASES + LIMIT_CASES
    print(f'Generating {len(all_cases)} WAV files -> {out_dir}/\n')
    print(f'  {"File":<50}  {"Size":>5}     Duration  [Noise]')
    print(f'  {"-"*50}  -----  --------  -------')

    print('\n  -- Baseline cases --')
    for stem, message, wpm, snr_db, freq_hz in BASELINE_CASES:
        path = os.path.join(out_dir, f'{stem}.wav')
        write_wav(path, message, wpm, snr_db=snr_db, freq_hz=freq_hz)

    print('\n  -- Limit-discovery cases --')
    for stem, message, wpm, snr_db, freq_hz in LIMIT_CASES:
        path = os.path.join(out_dir, f'{stem}.wav')
        write_wav(path, message, wpm, snr_db=snr_db, freq_hz=freq_hz)

    print(f'\nDone ({len(all_cases)} files). Push to device/emulator:')
    print(f'  adb push {out_dir}/ /sdcard/Download/')
