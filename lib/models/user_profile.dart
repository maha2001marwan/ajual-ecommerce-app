import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestore document held at `users/{uid}`.
class UserProfile {
  const UserProfile({
    required this.uid,
    this.displayName = '',
    this.firstName = '',
    this.lastName = '',
    this.email,
    this.phoneNumber,
    this.phoneCode = 'PS +970',
    this.photoUrl,
    this.avatarId,
    this.gender,
    this.birthday,
    this.isAnonymous = false,
    this.createdAt,
    this.updatedAt,
  });

  final String uid;
  final String displayName;
  final String firstName;
  final String lastName;
  final String? email;
  final String? phoneNumber;
  final String phoneCode;
  final String? photoUrl;

  /// Index of a built-in avatar (photo uploads need Cloud Storage / Blaze).
  final int? avatarId;
  final String? gender;
  final DateTime? birthday;
  final bool isAnonymous;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// `johnsmith_23` style handle shown in the account header.
  String get username {
    final source = displayName.trim().isNotEmpty
        ? displayName
        : (email?.split('@').first ?? 'guest');
    final handle = source.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');
    final suffix = uid.length >= 2 ? uid.substring(0, 2).toLowerCase() : '00';
    return '${handle.isEmpty ? 'user' : handle}_$suffix';
  }

  String get initials {
    final parts = displayName.trim().split(RegExp(r'\s+'));
    final letters = parts
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0].toUpperCase())
        .join();
    return letters.isEmpty ? '?' : letters;
  }

  UserProfile copyWith({
    String? displayName,
    String? firstName,
    String? lastName,
    String? email,
    String? phoneNumber,
    String? phoneCode,
    String? photoUrl,
    int? avatarId,
    String? gender,
    DateTime? birthday,
    bool? isAnonymous,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserProfile(
      uid: uid,
      displayName: displayName ?? this.displayName,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      phoneCode: phoneCode ?? this.phoneCode,
      photoUrl: photoUrl ?? this.photoUrl,
      avatarId: avatarId ?? this.avatarId,
      gender: gender ?? this.gender,
      birthday: birthday ?? this.birthday,
      isAnonymous: isAnonymous ?? this.isAnonymous,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'displayName': displayName,
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'phoneNumber': phoneNumber,
      'phoneCode': phoneCode,
      'photoUrl': photoUrl,
      'avatarId': avatarId,
      'gender': gender,
      'birthday': birthday != null ? Timestamp.fromDate(birthday!) : null,
      'isAnonymous': isAnonymous,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  factory UserProfile.fromMap(String uid, Map<String, dynamic> map) {
    final displayName = (map['displayName'] as String?) ?? '';
    final parts = displayName.trim().split(RegExp(r'\s+'));
    final birthday = map['birthday'];
    return UserProfile(
      uid: uid,
      displayName: displayName,
      firstName: (map['firstName'] as String?) ??
          (parts.isNotEmpty ? parts.first : ''),
      lastName: (map['lastName'] as String?) ??
          (parts.length > 1 ? parts.sublist(1).join(' ') : ''),
      email: map['email'] as String?,
      phoneNumber: map['phoneNumber'] as String?,
      phoneCode: (map['phoneCode'] as String?) ?? 'PS +970',
      photoUrl: map['photoUrl'] as String?,
      avatarId: (map['avatarId'] as num?)?.toInt(),
      gender: map['gender'] as String?,
      birthday: birthday is Timestamp ? birthday.toDate() : null,
      isAnonymous: (map['isAnonymous'] as bool?) ?? false,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
    );
  }
}
