import 'package:speech_to_text/speech_to_text.dart' as stt;

class SpeechService {
  final stt.SpeechToText _speech = stt.SpeechToText();

  Future<bool> initialize() async {
    return await _speech.initialize();
  }

  void listen({required Function(String) onResult}) {
    _speech.listen(onResult: (val) {
      onResult(val.recognizedWords);
    });
  }

  void stop() {
    _speech.stop();
  }
}
