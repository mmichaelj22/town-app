import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return const FirebaseOptions(
          apiKey: 'AIzaSyCCef3cDh9cZtqRZNZS_HGMW9sf4hpNrk8',
          appId: '1:638980393173:ios:c3aeb87dc61d903c543a5c',
          messagingSenderId: '638980393173',
          projectId: 'town-8352f',
          iosBundleId: 'com.michael.town', // Match Xcode
        );
      default:
        throw UnsupportedError(
            'DefaultFirebaseOptions are not supported for this platform.');
    }
  }
}
