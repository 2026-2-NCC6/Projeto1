import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../models/user.dart';

class UserAvatar extends StatelessWidget {
  const UserAvatar({super.key, required this.name, this.radius = 22, this.imageUrl});

  final String name;
  final double radius;
  final String? imageUrl;

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.surfaceElevated2,
      backgroundImage: imageUrl != null ? NetworkImage(imageUrl!) : null,
      child: imageUrl == null
          ? Text(
              _initials,
              style: TextStyle(
                color: AppColors.green,
                fontWeight: FontWeight.w800,
                fontSize: radius * 0.65,
              ),
            )
          : null,
    );
  }
}

extension AppUserAvatarX on AppUser {
  Widget avatar({double radius = 22}) => UserAvatar(name: name, radius: radius, imageUrl: avatarUrl);
}
