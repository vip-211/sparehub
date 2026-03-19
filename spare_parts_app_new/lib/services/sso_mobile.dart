import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import '../utils/constants.dart';

class GoogleSSO {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'email',
      'profile',
    ],
  );

  Future<Map<String, String>?> signIn() async {
    try {
      if (kDebugMode) {
        debugPrint("GoogleSSO: Starting sign-in process...");
      }
      
      final GoogleSignInAccount? user = await _googleSignIn.signIn();

      if (user == null) {
        if (kDebugMode) {
          debugPrint("GoogleSSO: User cancelled the sign-in.");
        }
        return null;
      }

      if (kDebugMode) {
        debugPrint("GoogleSSO: Successfully signed in as ${user.email}");
      }

      return {
        'email': user.email,
        'name': user.displayName ?? '',
      };
    } catch (e) {
      if (kDebugMode) {
        debugPrint("Google sign-in error: $e");
        if (e.toString().contains('10')) {
          debugPrint("ERROR 10 (Developer Error) detected. Possible causes:");
          debugPrint("1. SHA-1 fingerprint mismatch in Firebase Console.");
          debugPrint("2. Missing google-services plugin in Gradle configuration.");
          debugPrint("3. The package name does not match the one in Firebase.");
        }
      }
      return null;
    }
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (e) {
      if (kDebugMode) {
        debugPrint("Google sign-out error: $e");
      }
    }
  }
}
