import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/constants/firestore_paths.dart';
import '../core/errors/app_exception.dart';
import '../models/user_profile.dart';

/// Reads and writes everything under `users/{uid}`.
class UserRepository {
  UserRepository({FirebaseFirestore? db})
    : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      _db.collection(FirestorePaths.users).doc(uid);

  /// Creates the profile document on first login and keeps the volatile
  /// identity fields in sync on subsequent logins.
  Future<UserProfile> ensureProfile(User user) async {
    try {
      final ref = _doc(user.uid);
      final snapshot = await ref.get();

      if (!snapshot.exists) {
        final name = user.displayName ?? '';
        final parts = name.trim().split(RegExp(r'\s+'));
        final profile = UserProfile(
          uid: user.uid,
          email: user.email,
          phoneNumber: user.phoneNumber,
          displayName: name,
          firstName: parts.isNotEmpty ? parts.first : '',
          lastName: parts.length > 1 ? parts.sublist(1).join(' ') : '',
          photoUrl: user.photoURL,
          isAnonymous: user.isAnonymous,
        );
        await ref.set(profile.toMap());
        return profile;
      }

      await ref.set({
        'email': user.email,
        'isAnonymous': user.isAnonymous,
        if (user.photoURL != null) 'photoUrl': user.photoURL,
        if ((user.displayName ?? '').isNotEmpty &&
            ((snapshot.data()?['displayName'] as String?) ?? '').isEmpty)
          'displayName': user.displayName,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      final merged = await ref.get();
      return UserProfile.fromMap(user.uid, merged.data() ?? const {});
    } catch (error) {
      throw AppException.from(error);
    }
  }

  Stream<UserProfile?> watchProfile(String uid) =>
      _doc(uid).snapshots().map((snapshot) {
        final data = snapshot.data();
        if (data == null) return null;
        return UserProfile.fromMap(uid, data);
      });

  Future<UserProfile?> fetchProfile(String uid) async {
    try {
      final snapshot = await _doc(uid).get();
      final data = snapshot.data();
      if (data == null) return null;
      return UserProfile.fromMap(uid, data);
    } catch (error) {
      throw AppException.from(error);
    }
  }

  Future<void> updateDisplayName(String uid, String displayName) async {
    try {
      await _doc(uid).set({
        'displayName': displayName.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (error) {
      throw AppException.from(error);
    }
  }

  /// Saves the Edit Profile form.
  Future<void> updateProfile(
    String uid, {
    required String firstName,
    required String lastName,
    required String phoneCode,
    required String phoneNumber,
    String? gender,
    DateTime? birthday,
    int? avatarId,
  }) async {
    try {
      await _doc(uid).set({
        'firstName': firstName.trim(),
        'lastName': lastName.trim(),
        'displayName': '${firstName.trim()} ${lastName.trim()}'.trim(),
        'phoneCode': phoneCode,
        'phoneNumber': phoneNumber.trim(),
        'gender': gender,
        'birthday': birthday != null ? Timestamp.fromDate(birthday) : null,
        'avatarId': avatarId,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (error) {
      throw AppException.from(error);
    }
  }
}
