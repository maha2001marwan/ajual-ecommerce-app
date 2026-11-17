import 'package:flutter/material.dart';

import '../../models/user_profile.dart';

/// Built-in avatars. Uploading a photo needs Cloud Storage, which requires the
/// Blaze plan for new projects, so the free build offers these presets.
class AvatarPresets {
  AvatarPresets._();

  static const List<(Color, IconData)> all = [
    (Color(0xFF111111), Icons.person_rounded),
    (Color(0xFFE13D5C), Icons.face_3_rounded),
    (Color(0xFF3B82F6), Icons.face_6_rounded),
    (Color(0xFF1FB57A), Icons.emoji_nature_rounded),
    (Color(0xFFF59E0B), Icons.pets_rounded),
    (Color(0xFF7C4DFF), Icons.rocket_launch_rounded),
    (Color(0xFF0EA5E9), Icons.sports_esports_rounded),
    (Color(0xFF8D6E63), Icons.local_cafe_rounded),
  ];
}

class UserAvatar extends StatelessWidget {
  const UserAvatar({super.key, required this.profile, this.radius = 28});

  final UserProfile? profile;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final p = profile;
    final id = p?.avatarId;
    if (id != null && id >= 0 && id < AvatarPresets.all.length) {
      final (color, icon) = AvatarPresets.all[id];
      return CircleAvatar(
        radius: radius,
        backgroundColor: color,
        child: Icon(icon, color: Colors.white, size: radius),
      );
    }
    final photo = p?.photoUrl;
    if (photo != null && photo.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: const Color(0xFFEDEDED),
        backgroundImage: NetworkImage(photo),
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFFEDEDED),
      child: Text(
        p?.initials ?? '?',
        style: TextStyle(fontSize: radius * 0.7, fontWeight: FontWeight.w600, color: Colors.black),
      ),
    );
  }
}
