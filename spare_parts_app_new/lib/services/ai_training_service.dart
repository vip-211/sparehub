import 'remote_client.dart';
import '../utils/constants.dart';

class AITrainingService {
  final RemoteClient _remote = RemoteClient();

  /// Submits feedback for a bot response (positive/negative)
  Future<void> submitFeedback({
    required String prompt,
    required String response,
    required bool isPositive,
  }) async {
    if (Constants.useRemote) {
      await _remote.postJson('/ai/feedback', {
        'prompt': prompt,
        'response': response,
        'isPositive': isPositive,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } else {
      // Local storage fallback if needed, but the app seems to prefer remote
      print('Local feedback recorded: $prompt -> $response ($isPositive)');
    }
  }

  /// Submits a correction for a bot response
  Future<void> submitCorrection({
    required String prompt,
    required String originalResponse,
    required String correctedResponse,
  }) async {
    if (Constants.useRemote) {
      await _remote.postJson('/ai/train', {
        'prompt': prompt,
        'originalResponse': originalResponse,
        'correctedResponse': correctedResponse,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } else {
      print('Local correction recorded: $prompt -> $correctedResponse');
    }
  }
}
