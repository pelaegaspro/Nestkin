import 'dart:async';

import 'package:flutter/material.dart';

import '../models/dose_log_model.dart';
import '../models/household_member_model.dart';
import '../models/medicine_model.dart';
import '../services/firestore_service.dart';
import '../services/medicine_notification_service.dart';
import '../services/medicine_repository.dart';
import '../widgets/add_medicine_sheet.dart';
import '../widgets/streak_calendar_widget.dart';
import 'medicine_detail_screen.dart';

class MedicinesScreen extends StatefulWidget {
  final String householdId;

  const MedicinesScreen({
    super.key,
    required this.householdId,
  });

  @override
  State<MedicinesScreen> createState() => _MedicinesScreenState();
}

class _MedicinesScreenState extends State<MedicinesScreen> {
  final _repository = MedicineRepository();
  final _firestoreService = FirestoreService();
  Timer? _ticker;
  String? _lastSyncKey;
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
    _ticker = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _initializeNotifications() async {
    await MedicineNotificationService.instance.initialize(
      onOpenMedicine: (householdId, medicineId) async {
        if (!mounted || householdId != widget.householdId) {
          return;
        }

        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => MedicineDetailScreen(
              householdId: householdId,
              medicineId: medicineId,
            ),
          ),
        );
      },
    );
  }

  Future<void> _openAddMedicineSheet(List<HouseholdMemberModel> members) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => AddMedicineSheet(
        householdId: widget.householdId,
        members: members,
      ),
    );
  }

  Future<void> _openMedicineDetail(MedicineModel medicine) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MedicineDetailScreen(
          householdId: widget.householdId,
          medicineId: medicine.id,
        ),
      ),
    );
  }

  void _syncMedicines(List<MedicineModel> medicines) {
    final now = DateTime.now();
    final syncKey = '${now.year}-${now.month}-${now.day}-${now.hour}-${now.minute}:'
        '${medicines.map((medicine) => '${medicine.id}-${medicine.reminderTimes.join(',')}-${medicine.endDate?.seconds ?? 0}').join('|')}';
    if (_syncing || _lastSyncKey == syncKey) {
      return;
    }
    _lastSyncKey = syncKey;
    _syncing = true;

    Future<void>(() async {
      try {
        for (final medicine in medicines) {
          await _repository.ensureDoseSlotsForDay(
            householdId: widget.householdId,
            medicine: medicine,
            day: now,
          );
          await _repository.markMissedDoses(
            householdId: widget.householdId,
            medicineId: medicine.id,
            now: now,
          );
        }

        await MedicineNotificationService.instance.syncSchedules(
          householdId: widget.householdId,
          medicines: medicines,
        );
      } finally {
        _syncing = false;
      }
    });
  }

  int _missedDoseCount(List<MedicineModel> medicines, List<DoseLogModel> logs) {
    final now = DateTime.now();
    final groupedLogs = <String, Map<String, DoseLogModel>>{};
    for (final log in logs) {
      groupedLogs.putIfAbsent(log.medicineId, () => <String, DoseLogModel>{})[log.id] = log;
    }

    var count = 0;
    for (final medicine in medicines) {
      final medicineLogs = groupedLogs[medicine.id] ?? const <String, DoseLogModel>{};
      if (!_isMedicineActiveOnDay(medicine, now)) {
        continue;
      }

      for (final reminder in medicine.reminderTimes) {
        final scheduled = _repository.scheduledDateTimeFor(day: now, reminderTime: reminder);
        if (scheduled == null || scheduled.isAfter(now)) {
          continue;
        }

        final doseId = _repository.doseIdForTimestamp(scheduled);
        final log = medicineLogs[doseId];
        if (log == null || log.status == 'missed' || log.status == 'pending') {
          count += 1;
        }
      }
    }

    return count;
  }

  bool _isMedicineActiveOnDay(MedicineModel medicine, DateTime day) {
    final dayOnly = DateTime(day.year, day.month, day.day);
    final start = DateTime(
      medicine.startDate.toDate().year,
      medicine.startDate.toDate().month,
      medicine.startDate.toDate().day,
    );
    final end = medicine.endDate == null
        ? null
        : DateTime(
            medicine.endDate!.toDate().year,
            medicine.endDate!.toDate().month,
            medicine.endDate!.toDate().day,
          );

    if (dayOnly.isBefore(start)) {
      return false;
    }
    if (end != null && dayOnly.isAfter(end)) {
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<HouseholdMemberModel>>(
      stream: _firestoreService.householdMembersStream(widget.householdId),
      builder: (context, membersSnapshot) {
        if (membersSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (membersSnapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Medicines')),
            body: const Center(child: Text('Could not load family members right now.')),
          );
        }

        final members = membersSnapshot.data ?? const <HouseholdMemberModel>[];
        final membersById = {for (final member in members) member.userId: member};

        return StreamBuilder<List<MedicineModel>>(
          stream: _repository.streamMedicines(widget.householdId),
          builder: (context, medicinesSnapshot) {
            if (medicinesSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }
            if (medicinesSnapshot.hasError) {
              return Scaffold(
                appBar: AppBar(title: const Text('Medicines')),
                body: const Center(child: Text('Could not load medicines right now.')),
              );
            }

            final medicines = medicinesSnapshot.data ?? const <MedicineModel>[];
            _syncMedicines(medicines);

            return StreamBuilder<List<DoseLogModel>>(
              stream: _repository.streamTodayDoseLogsForHousehold(widget.householdId),
              builder: (context, doseLogsSnapshot) {
                final todayLogs = doseLogsSnapshot.data ?? const <DoseLogModel>[];
                final missedCount = _missedDoseCount(medicines, todayLogs);

                final grouped = <String, List<MedicineModel>>{};
                for (final medicine in medicines) {
                  grouped.putIfAbsent(medicine.assignedTo, () => <MedicineModel>[]).add(medicine);
                }

                return Scaffold(
                  appBar: AppBar(
                    title: const Text('Medicines'),
                    actions: [
                      Padding(
                        padding: const EdgeInsets.only(right: 16),
                        child: Center(
                          child: Badge(
                            isLabelVisible: missedCount > 0,
                            label: Text('$missedCount'),
                            child: const Icon(Icons.medication_outlined),
                          ),
                        ),
                      ),
                    ],
                  ),
                  floatingActionButton: members.isEmpty
                      ? null
                      : FloatingActionButton(
                          onPressed: () => _openAddMedicineSheet(members),
                          child: const Icon(Icons.add),
                        ),
                  body: medicines.isEmpty
                      ? const Center(
                          child: Text('No medicines yet. Tap + to add one.'),
                        )
                      : ListView(
                          padding: const EdgeInsets.all(16),
                          children: grouped.entries.map((entry) {
                            final member = membersById[entry.key];
                            final headerName =
                                member == null ? 'Member' : (member.user['displayName'] ?? member.user['phoneNumber'] ?? 'Member').toString();
                            final headerColor = member?.color ?? '#0B5C68';

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: double.infinity,
                                  margin: const EdgeInsets.only(bottom: 12, top: 8),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: _parseColor(headerColor),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Text(
                                    headerName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                ...entry.value.map(
                                  (medicine) => _MedicineCard(
                                    householdId: widget.householdId,
                                    medicine: medicine,
                                    repository: _repository,
                                    onTap: () => _openMedicineDetail(medicine),
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                );
              },
            );
          },
        );
      },
    );
  }

  Color _parseColor(String hex) {
    final cleaned = hex.replaceAll('#', '');
    return Color(int.parse('FF$cleaned', radix: 16));
  }
}

class _MedicineCard extends StatelessWidget {
  final String householdId;
  final MedicineModel medicine;
  final MedicineRepository repository;
  final VoidCallback onTap;

  const _MedicineCard({
    required this.householdId,
    required this.medicine,
    required this.repository,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final end = DateTime.now().add(const Duration(days: 1));
    final start = DateTime.now().subtract(const Duration(days: 6));

    return StreamBuilder<List<DoseLogModel>>(
      stream: repository.streamDoseLogsForRange(
        householdId: householdId,
        medicineId: medicine.id,
        start: DateTime(start.year, start.month, start.day),
        end: DateTime(end.year, end.month, end.day),
      ),
      builder: (context, snapshot) {
        final logs = snapshot.data ?? const <DoseLogModel>[];
        final streakEntries = _buildStreakEntries(repository, medicine, logs);
        final streakCount = _streakCount(streakEntries);

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            title: Text(
              medicine.name,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(medicine.dosage),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: medicine.reminderTimes.map((time) => Chip(label: Text(time))).toList(),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Chip(
                        avatar: const Icon(Icons.local_fire_department, size: 16),
                        label: Text('Streak: $streakCount'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            onTap: onTap,
          ),
        );
      },
    );
  }

  List<StreakDayEntry> _buildStreakEntries(
    MedicineRepository repository,
    MedicineModel medicine,
    List<DoseLogModel> logs,
  ) {
    final now = DateTime.now();
    final logMap = {for (final log in logs) log.id: log};
    final entries = <StreakDayEntry>[];

    for (var offset = 6; offset >= 0; offset--) {
      final day = DateTime(now.year, now.month, now.day).subtract(Duration(days: offset));
      final active = _isActiveOnDay(medicine, day);
      if (!active) {
        entries.add(StreakDayEntry(day: day, status: StreakDayStatus.pending));
        continue;
      }

      var hasDueDose = false;
      var allTaken = true;
      var missed = false;

      for (final reminder in medicine.reminderTimes) {
        final scheduled = repository.scheduledDateTimeFor(day: day, reminderTime: reminder);
        if (scheduled == null) {
          continue;
        }
        if (scheduled.isAfter(now)) {
          continue;
        }

        hasDueDose = true;
        final log = logMap[repository.doseIdForTimestamp(scheduled)];
        if (log?.status == 'taken') {
          continue;
        }
        if (log?.status == 'missed' || scheduled.isBefore(now)) {
          missed = true;
          allTaken = false;
          break;
        }
        allTaken = false;
      }

      entries.add(
        StreakDayEntry(
          day: day,
          status: !hasDueDose
              ? StreakDayStatus.pending
              : missed
                  ? StreakDayStatus.missed
                  : allTaken
                      ? StreakDayStatus.taken
                      : StreakDayStatus.pending,
        ),
      );
    }

    return entries;
  }

  bool _isActiveOnDay(MedicineModel medicine, DateTime day) {
    final normalizedDay = DateTime(day.year, day.month, day.day);
    final start = DateTime(
      medicine.startDate.toDate().year,
      medicine.startDate.toDate().month,
      medicine.startDate.toDate().day,
    );
    final end = medicine.endDate == null
        ? null
        : DateTime(
            medicine.endDate!.toDate().year,
            medicine.endDate!.toDate().month,
            medicine.endDate!.toDate().day,
          );

    if (normalizedDay.isBefore(start)) {
      return false;
    }
    if (end != null && normalizedDay.isAfter(end)) {
      return false;
    }
    return true;
  }

  int _streakCount(List<StreakDayEntry> entries) {
    var count = 0;
    for (var i = entries.length - 1; i >= 0; i--) {
      if (entries[i].status == StreakDayStatus.taken) {
        count += 1;
      } else {
        break;
      }
    }
    return count;
  }
}
