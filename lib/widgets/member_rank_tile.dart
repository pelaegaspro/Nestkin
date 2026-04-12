import 'package:flutter/material.dart';

import '../models/household_member_model.dart';
import 'badge_chip.dart';

class MemberRankTile extends StatelessWidget {
  final HouseholdMemberModel member;
  final int rank;

  const MemberRankTile({
    super.key,
    required this.member,
    required this.rank,
  });

  @override
  Widget build(BuildContext context) {
    final name = (member.user['displayName'] ?? member.user['phoneNumber'] ?? 'Member').toString();
    final photoUrl = member.user['photoUrl']?.toString();
    final initials = name
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0].toUpperCase())
        .join();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundImage: photoUrl != null && photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                  child: photoUrl == null || photoUrl.isEmpty
                      ? Text(initials.isEmpty ? 'M' : initials)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: Theme.of(context).textTheme.titleMedium),
                      Text('Rank #$rank'),
                    ],
                  ),
                ),
                Text(
                  '${member.weeklyPoints} pts',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            if (member.badges.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: member.badges.take(3).map((badge) => BadgeChip(label: badge)).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
