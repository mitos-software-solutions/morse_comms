import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// I/O boundary for the encoder's save and share operations.
///
/// Keeps platform-specific file I/O and share-sheet logic out of
/// [EncoderBloc], making the bloc fully unit-testable via a stub subclass.
class EncoderService {
  /// Writes [wavBytes] to the temp directory as [filename].wav and returns
  /// the full path.  Used on mobile — caller follows up with [shareAudio].
  Future<String> saveTempAudio(Uint8List wavBytes, String filename) async {
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/$filename.wav';
    await File(path).writeAsBytes(wavBytes);
    return path;
  }

  /// Writes [wavBytes] to an explicit [path] chosen by the caller.
  /// Returns [path] unchanged.  Used on desktop where the screen resolves
  /// the Downloads directory before dispatching.
  Future<String> saveAudioToPath(Uint8List wavBytes, String path) async {
    await File(path).writeAsBytes(wavBytes);
    return path;
  }

  /// Opens the platform share sheet for the WAV file at [path].
  Future<void> shareAudio(String path) async {
    await Share.shareXFiles(
      [XFile(path, mimeType: 'audio/wav')],
      subject: 'Morse Audio',
    );
  }
}
