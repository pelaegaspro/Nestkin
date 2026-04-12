import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/dose_log_model.dart';
import '../models/household_member_model.dart';
import '../models/medicine_model.dart';
import '../services/firestore_service.dart';
import '../services/medicine_notification_service.dart';
import '../services/medicine_repository.dart';
import '../widgets/add_medicine_sheet.dart';
import '../widgets/dose_timeline_widget.dart';
import '../widgets/streak_calendar_widget.dart';

class MedicineDetailScreen extends StatefulWidget {
  final String householdId;
  final String medicineId;

  const MedicineDetailScreen({
    super.key,
    required this.householdId,
    required this.medicineId,
  });

  @override
  State<MedicineDetailScreen> createState() => _MedicineDetailScreenState();
}

class _MedicineDetailScreenState extends State<MedicineDetailScreen> {
  final _repository = MedicineRepository();
  final _firestoreService = FirestoreService();
  Timer? _ticker;
  String? _lastSyncMinute;

  @override
  void initState() {
    super.initState();
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

  Future<void> _syncMedicine(MedicineModel medicine) async {
    final now = DateTime.now();
    final syncMinute = '${now.year}-${now.month}-${now.day}-${now.hour}-${now.minute}';
    if (_lastSyncMinute == syncMinute) {
      return;
    }
    _lastSyncMinute = syncMinute;

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
    await MedicineNotificationService.instance.scheduleForMedicine(
      householdId: widget.householdId,
      medicine: medicine,
    );
  }

  Future<void> _openEditSheet(MedicineModel medicine, List<HouseholdMemberModel> members) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => AddMedicineSheet(
        householdId: widget.householdId,
        members: members,
        existingMedicine: medicine,
      ),
    );
  }

  Future<void> _deleteMedicine(MedicineModel medicine) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete medicine'),
        content: Text('Delete "${medicine.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    try {
      await _repository.deleteMedicine(
        householdId: widget.householdId,
        medicineId: medicine.id,
      );
      await MedicineNotificationService.instance.cancelMedicineNotifications(medicine.id);

      if (!mounted) {
        return;
      }
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _takeDose(MedicineModel medicine, DateTime scheduledTime) async {
    try {
      await _repository.logDoseTaken(
        householdId: widget.householdId,
        medicineId: medicine.id,
        scheduledTime: scheduledTime,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<HouseholdMemberModel>>(
      stream: _firestoreService.householdMembersStream(widget.householdId),
      builder: (context, membersSnapshot) {
        final members = membersSnapshot.data ?? const <HouseholdMemberModel>[];

        return StreamBuilder<MedicineModel?>(
          stream: _repository.medicineStream(
            householdId: widget.householdId,
            medicineId: widget.medicineId,
          ),
          builder: (context, medicineSnapshot) {
            if (medicineSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }

            final medicine = medicineSnapshot.data;
            if (medicine == null) {
              return Scaffold(
                appBar: AppBar(title: const Text('Medicine')),
                body: const Center(
                  child: Text('This medicine is no longer available.'),
                ),
              );
            }

            _syncMedicine(medicine);

            final currentUid = FirebaseAuth.instance.currentUser!.uid;
            final canEdit = medicine.createdBy == currentUid || medicine.assignedTo == currentUid;
            final today = DateTime.now();
            final dayStart = DateTime(today.year, today.month, today.day);
            final nextDay = dayStart.add(const Duration(days: 1));
            final weekStart = dayStart.subtract(const Duration(days: 6));

            return StreamBuilder<List<DoseLogModel>>(
              stream: _repository.streamDoseLogsForRange(
                householdId: widget.householdId,
                medicineId: medicine.id,
                start: dayStart,
                end: nextDay,
              ),
              builder: (context, todayLogsSnapshot) {
                final todayLogs = todayLogsSnapshot.data ?? const <DoseLogModel>[];

                return StreamBuilder<List<DoseLogModel>>(
                  stream: _repository.streamDoseLogsForRange(
                    householdId: widget.householdId,
                    medicineId: medicine.id,
                    start: weekStart,
                    end: nextDay,
                  ),
                  builder: (context, weekLogsSnapshot) {
                    final weekLogs = weekLogsSnapshot.data ?? const <DoseLogModel>[];
                    final timelineEntries = _buildTodayTimelineEntries(medicine, todayLogs);
                    final streakEntries = _buildStreakEntries(medicine, weekLogs);

                    return Scaffold(
                      appBar: AppBar(
                        title: Text(medicine.name),
                        actions: [
                          if (canEdit)
                            IconButton(
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: () => _openEditSheet(medicine, members),
                            ),
                          if (canEdit)
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => _deleteMedicine(medicine),
                            ),
                        ],
                      ),
                      body: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    medicine.name,
                                    style: Theme.of(context).textTheme.headlineSmall,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(medicine.dosage),
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: medicine.reminderTimes.map((time) => Chip(label: Text(time))).toList(),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Today',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 12),
                          DoseTimelineWidget(
                            entries: timelineEntries,
                            onTake: (scheduledTime) => _takeDose(medicine, scheduledTime),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            '7-Day Streak',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 12),
                          StreakCalendarWidget(entries: streakEntries),
                        ],
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  List<DoseTimelineEntry> _buildTodayTimelineEntries(
    MedicineModel medicine,
    List<DoseLogModel> logs,
  ) {
    final now = DateTime.now();
    final entries = <DoseTimelineEntry>[];
    final logMap = {for (final log in logs) log.id: log};

    for (final reminderTime in medicine.reminderTimes) {
      final scheduled = _repository.scheduledDateTimeFor(day: now, reminderTime: reminderTime);
      if (scheduled == null) {
        continue;
      }

      final log = logMap[_repository.doseIdForTimestamp(scheduled)];
      final status = log?.status == 'taken'
          ? DoseVisualStatus.taken
          : (log?.status == 'missed' || scheduled.isBefore(now))
              ? DoseVisualStatus.missed
              : DoseVisualStatus.pending;

      entries.add(
        DoseTimelineEntry(
          scheduledTime: scheduled,
          status: status,
          takenAt: log?.takenAt?.toDate(),
          canTake: status == DoseVisualStatus.pending && !scheduled.isAfter(now),
        ),
      );
    }

    return entries;
  }

  List<StreakDayEntry> _buildStreakEntries(
    MedicineModel medicine,
    List<DoseLogModel> logs,
  ) {
    final now = DateTime.now();
    final logMap = {for (final log in logs) log.id: log};
    final entries = <StreakDayEntry>[];

    for (var offset = 6; offset >= 0; offset--) {
      final day = DateTime(now.year, now.month, now.day).subtract(Duration(days: offset));
      if (!_isActiveOnDay(medicine, day)) {
        entries.add(StreakDayEntry(day: day, status: StreakDayStatus.pending));
        continue;
      }

      var hasDueDose = false;
      var allTaken = true;
      var missed = false;

      for (final reminder in medicine.reminderTimes) {
        final scheduled = _repository.scheduledDateTimeFor(day: day, reminderTime: reminder);
        if (scheduled == null || scheduled.isAfter(now)) {
          continue;
        }

        hasDueDose = true;
        final log = logMap[_repository.doseIdForTimestamp(scheduled)];
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
}
