import 'package:flutter/material.dart';

import '../models/household_member_model.dart';
import '../services/firestore_service.dart';
import '../widgets/member_rank_tile.dart';

class LeaderboardScreen extends StatelessWidget {
  final String householdId;

  const LeaderboardScreen({
    super.key,
    required this.householdId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Leaderboard')),
      body: StreamBuilder<List<HouseholdMemberModel>>(
        stream: FirestoreService().householdMembersStream(householdId),
        builder: (context, snapshot) {
          final members = [...(snapshot.data ?? const <HouseholdMemberModel>[])];
          members.sort((a, b) => b.weeklyPoints.compareTo(a.weeklyPoints));
          if (members.isEmpty) {
            return const Center(child: Text('No members found yet.'));
          }

          final topThree = members.take(3).toList();
          final rest = members.skip(3).toList();

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text('Weekly podium', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: topThree.asMap().entries.map((entry) {
                  final rank = entry.key + 1;
                  final member = entry.value;
                  final height = switch (rank) {
                    1 => 180.0,
                    2 => 140.0,
                    _ => 120.0,
                  };
                  final name = (member.user['displayName'] ?? member.user['phoneNumber'] ?? 'Member').toString();
                  return Expanded(
                    child: Container(
                      height: height,
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text('#$rank', style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(height: 10),
                          Text(
                            name,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Text('${member.weeklyPoints} pts'),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              ...rest.asMap().entries.map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: MemberRankTile(
                        member: entry.value,
                        rank: entry.key + 4,
                      ),
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }
}
