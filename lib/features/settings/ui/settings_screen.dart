import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/settings_cubit.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: BlocBuilder<SettingsCubit, SettingsState>(
        builder: (context, state) {
          final cubit = context.read<SettingsCubit>();
          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              _SectionHeader('Appearance'),
              _ThemeSelector(
                current: state.themeMode,
                onChanged: cubit.setThemeMode,
              ),
              const SizedBox(height: 16),
              _SectionHeader('Morse Settings'),
              _WpmTile(wpm: state.wpm, onChanged: cubit.setWpm),
              _FrequencyTile(
                hz: state.toneFrequency,
                onChanged: cubit.setToneFrequency,
              ),
              SwitchListTile(
                title: const Text('Side-tone while decoding'),
                subtitle: const Text(
                  'Play a beep in sync with the detected signal',
                ),
                value: state.sideTone,
                onChanged: cubit.setSideTone,
              ),
              const SizedBox(height: 16),
              _SectionHeader('Speech Recognition'),
              _SttLanguageTile(
                currentLocaleId: state.sttLocaleId,
                locales: state.sttLocales,
                onChanged: cubit.setSttLocaleId,
              ),
              const SizedBox(height: 16),
              const _SupportCard(),
              const SizedBox(height: 16),
              _SectionHeader('About'),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('Version'),
                trailing: Text(
                  '0.1.0',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              ListTile(
                leading: const Icon(Icons.article_outlined),
                title: const Text('Open-source licences'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => showLicensePage(
                  context: context,
                  applicationName: 'Morse Comms',
                  applicationVersion: '0.1.0',
                ),
              ),
            ],
          );
        },
      ),
    );
  }

}

// ---------------------------------------------------------------------------
// Section header
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              letterSpacing: 1.2,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Theme selector
// ---------------------------------------------------------------------------

class _ThemeSelector extends StatelessWidget {
  final ThemeMode current;
  final ValueChanged<ThemeMode> onChanged;

  const _ThemeSelector({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SegmentedButton<ThemeMode>(
        segments: const [
          ButtonSegment(
            value: ThemeMode.system,
            icon: Icon(Icons.brightness_auto),
            label: Text('System'),
          ),
          ButtonSegment(
            value: ThemeMode.light,
            icon: Icon(Icons.light_mode),
            label: Text('Light'),
          ),
          ButtonSegment(
            value: ThemeMode.dark,
            icon: Icon(Icons.dark_mode),
            label: Text('Dark'),
          ),
        ],
        selected: {current},
        onSelectionChanged: (set) => onChanged(set.first),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// WPM slider
// ---------------------------------------------------------------------------

class _WpmTile extends StatelessWidget {
  final int wpm;
  final ValueChanged<int> onChanged;

  const _WpmTile({required this.wpm, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          leading: const Icon(Icons.speed),
          title: const Text('Speed'),
          trailing: Text(
            '$wpm WPM',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Slider(
            min: 5,
            max: 40,
            divisions: 35,
            value: wpm.toDouble(),
            label: '$wpm WPM',
            onChanged: (v) => onChanged(v.round()),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Tone frequency slider
// ---------------------------------------------------------------------------

class _FrequencyTile extends StatelessWidget {
  final double hz;
  final ValueChanged<double> onChanged;

  const _FrequencyTile({required this.hz, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          leading: const Icon(Icons.graphic_eq),
          title: const Text('Tone frequency'),
          trailing: Text(
            '${hz.round()} Hz',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Slider(
            min: 400,
            max: 900,
            divisions: 50,
            value: hz,
            label: '${hz.round()} Hz',
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Support card
// ---------------------------------------------------------------------------

class _SupportCard extends StatelessWidget {
  const _SupportCard();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      color: colors.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('🍺', style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Buy me a beer?',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colors.onSecondaryContainer,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              "Hey! I'm just a regular guy who built this in his spare time "
              "because I love Morse code and couldn't find a good offline tool "
              "for preppers and ham radio operators.\n\n"
              "Morse Comms is completely free — no ads, no subscriptions, "
              "no data collection — and it always will be. "
              "If it's been useful to you, a virtual beer would honestly make my day. "
              "Either way, thanks for being here. 73 de the dev.",
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSecondaryContainer,
                    height: 1.5,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// STT language picker
// ---------------------------------------------------------------------------

class _SttLanguageTile extends StatelessWidget {
  final String currentLocaleId;
  final List<SttLocale> locales;
  final ValueChanged<String> onChanged;

  const _SttLanguageTile({
    required this.currentLocaleId,
    required this.locales,
    required this.onChanged,
  });

  void _openPicker(BuildContext context) {
    // Trigger locale loading only now (idempotent after first call).
    // Deferring to tap-time avoids SpeechToText.initialize() running on mount,
    // which on some Samsung devices causes a brief activity pause (black screen).
    context.read<SettingsCubit>().loadSttLocales();

    // Open the dialog immediately; BlocBuilder updates it when locales arrive.
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => BlocProvider.value(
        value: context.read<SettingsCubit>(),
        child: BlocBuilder<SettingsCubit, SettingsState>(
          builder: (_, state) => _LocalePickerDialog(
            locales: state.sttLocales,
            currentLocaleId: currentLocaleId,
            onSelected: (id) {
              Navigator.pop(dialogCtx);
              onChanged(id);
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final current = locales.where((l) => l.id == currentLocaleId).firstOrNull;
    final label = current?.name ?? currentLocaleId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          leading: const Icon(Icons.language),
          title: const Text('Voice input language'),
          subtitle: Text(label),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _openPicker(context),
        ),
        // Info banner — explains where languages come from and how to add more.
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline,
                  size: 18,
                  color: Theme.of(context).colorScheme.onSecondaryContainer,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Languages shown here are provided by your device\'s '
                    'speech engine — no downloads needed inside this app.\n\n'
                    'To add a language:\n'
                    'Android → Settings → System → Languages & input → '
                    'On-device recognition → Add a language\n\n'
                    'iOS → Settings → General → Language & Region → '
                    'add the language, then enable it in Keyboard settings.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSecondaryContainer,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _LocalePickerDialog extends StatelessWidget {
  final List<SttLocale> locales;
  final String currentLocaleId;
  final ValueChanged<String> onSelected;

  const _LocalePickerDialog({
    required this.locales,
    required this.currentLocaleId,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isLoading = locales.isEmpty;
    return AlertDialog(
      title: const Text('Voice input language'),
      contentPadding: const EdgeInsets.symmetric(vertical: 8),
      content: isLoading
          ? const SizedBox(
              height: 120,
              child: Center(child: CircularProgressIndicator()),
            )
          : SizedBox(
              width: double.maxFinite,
              child: RadioGroup<String>(
                groupValue: currentLocaleId,
                onChanged: (id) { if (id != null) onSelected(id); },
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: locales.length,
                  itemBuilder: (context, index) {
                    final locale = locales[index];
                    return RadioListTile<String>(
                      title: Text(locale.name),
                      subtitle: Text(
                        locale.id,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      value: locale.id,
                    );
                  },
                ),
              ),
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
