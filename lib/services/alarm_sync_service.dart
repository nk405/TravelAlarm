import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../models/alarm_sync_snapshot.dart';

class RemoteBackupState {
  const RemoteBackupState({
    required this.snapshot,
    required this.cloudUpdatedAtMillis,
  });

  final AlarmSyncSnapshot snapshot;
  final int cloudUpdatedAtMillis;
}

class AlarmSyncService {
  AlarmSyncService._();

  static final AlarmSyncService instance = AlarmSyncService._();

  static const String _collection = 'alarm_backups';
  static const String _docId = 'main';

  GoogleSignIn? get _googleSignInOrNull {
    if (Firebase.apps.isEmpty) return null;
    return GoogleSignIn();
  }

  FirebaseAuth? get _authOrNull {
    if (Firebase.apps.isEmpty) return null;
    return FirebaseAuth.instance;
  }

  FirebaseFirestore? get _firestoreOrNull {
    if (Firebase.apps.isEmpty) return null;
    return FirebaseFirestore.instance;
  }

  User? get currentUser => _authOrNull?.currentUser;

  Future<UserCredential> signInOrCreateAccount({
    required String email,
    required String password,
  }) async {
    final auth = _authOrNull;
    if (auth == null) {
      throw const SyncNotConfiguredException();
    }

    try {
      return await auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      if (e.code != 'user-not-found') rethrow;
      return auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    }
  }

  Future<UserCredential> signInWithGoogle() async {
    final auth = _authOrNull;
    final googleSignIn = _googleSignInOrNull;
    if (auth == null || googleSignIn == null) {
      throw const SyncNotConfiguredException();
    }

    final googleUser = await googleSignIn.signIn();
    if (googleUser == null) {
      throw const SyncSignInCancelledException();
    }

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    return auth.signInWithCredential(credential);
  }

  Future<void> signOut() async {
    final auth = _authOrNull;
    final googleSignIn = _googleSignInOrNull;
    if (auth == null) return;
    if (googleSignIn != null) {
      await googleSignIn.signOut();
    }
    await auth.signOut();
  }

  Future<void> backupNow(AlarmSyncSnapshot snapshot) async {
    final auth = _authOrNull;
    final firestore = _firestoreOrNull;
    if (auth == null || firestore == null) {
      throw const SyncNotConfiguredException();
    }

    final user = auth.currentUser;
    if (user == null) {
      throw const SyncUserNotSignedInException();
    }

    final data = <String, dynamic>{
      ...snapshot.toCloudJson(),
      'userId': user.uid,
      'updatedAt': FieldValue.serverTimestamp(),
      'deviceId': 'flutter-client',
    };

    await firestore
        .collection(_collection)
        .doc(user.uid)
        .collection('snapshots')
        .doc(_docId)
        .set(data);
  }

  Future<RemoteBackupState?> fetchBackup() async {
    final auth = _authOrNull;
    final firestore = _firestoreOrNull;
    if (auth == null || firestore == null) {
      throw const SyncNotConfiguredException();
    }

    final user = auth.currentUser;
    if (user == null) {
      throw const SyncUserNotSignedInException();
    }

    final doc =
        await firestore
            .collection(_collection)
            .doc(user.uid)
            .collection('snapshots')
            .doc(_docId)
            .get();

    if (!doc.exists || doc.data() == null) {
      return null;
    }

    final data = doc.data()!;
    final snapshot = AlarmSyncSnapshot.fromCloudJson(data);
    final cloudUpdatedAtMillis =
        (data['updatedAt'] as Timestamp?)?.millisecondsSinceEpoch ??
        snapshot.localUpdatedAtMillis;

    return RemoteBackupState(
      snapshot: snapshot,
      cloudUpdatedAtMillis: cloudUpdatedAtMillis,
    );
  }
}

class SyncUserNotSignedInException implements Exception {
  const SyncUserNotSignedInException();

  @override
  String toString() {
    return 'You need to sign in before using cloud backup.';
  }
}

class SyncNotConfiguredException implements Exception {
  const SyncNotConfiguredException();

  @override
  String toString() {
    return 'Firebase is not initialized for this app build.';
  }
}

class SyncSignInCancelledException implements Exception {
  const SyncSignInCancelledException();

  @override
  String toString() {
    return 'Sign in was canceled.';
  }
}
