import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../models/dose_log_model.dart';
import '../models/medicine_model.dart';

class MedicineRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<List<MedicineModel>> streamMedicines(String householdId) {
    return _db
        .collection('households')
        .doc(householdId)
        .collection('medicines')
        .orderBy('assignedToName')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => MedicineModel.fromMap({
                  ...doc.data(),
                  'id': doc.id,
                }),
              )
              .toList(),
        );
  }

  Stream<MedicineModel?> medicineStream({
    required String householdId,
    required String medicineId,
  }) {
    return _db
        .collection('households')
        .doc(householdId)
        .collection('medicines')
        .doc(medicineId)
        .snapshots()
        .map((doc) {
      if (!doc.exists || doc.data() == null) {
        return null;
      }

      return MedicineModel.fromMap({
        ...doc.data()!,
        'id': doc.id,
      });
    });
  }

  Stream<List<DoseLogModel>> streamDoseLogsForRange({
    required String householdId,
    required String medicineId,
    required DateTime start,
    required DateTime end,
  }) {
    return _db
        .collection('households')
        .doc(householdId)
        .collection('medicines')
        .doc(medicineId)
        .collection('doses')
        .where('scheduledTime', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('scheduledTime', isLessThan: Timestamp.fromDate(end))
        .orderBy('scheduledTime')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => DoseLogModel.fromMap({
                  ...doc.data(),
                  'id': doc.id,
                }),
              )
              .toList(),
        );
  }

  Stream<List<DoseLogModel>> streamTodayDoseLogsForHousehold(String householdId) {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));

    return _db
        .collectionGroup('doses')
        .where('householdId', isEqualTo: householdId)
        .where('scheduledTime', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('scheduledTime', isLessThan: Timestamp.fromDate(end))
        .orderBy('scheduledTime')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => DoseLogModel.fromMap({
                  ...doc.data(),
                  'id': doc.id,
                }),
              )
              .toList(),
        );
  }

  Future<MedicineModel> saveMedicine({
    required String householdId,
    required MedicineModel medicine,
  }) async {
    try {
      final medicineRef = medicine.id.isEmpty
          ? _db.collection('households').doc(householdId).collection('medicines').doc()
          : _db.collection('households').doc(householdId).collection('medicines').doc(medicine.id);

      final savedMedicine = medicine.copyWith(id: medicineRef.id);

      await medicineRef.set(
        savedMedicine.toMap(),
        SetOptions(merge: true),
      );
      return savedMedicine;
    } on FirebaseException {
      throw Exception('Could not save that medicine right now. Please try again.');
    }
  }

  Future<void> deleteMedicine({
    required String householdId,
    required String medicineId,
  }) async {
    try {
      final doses = await _db
          .collection('households')
          .doc(householdId)
          .collection('medicines')
          .doc(medicineId)
          .collection('doses')
          .get();

      final batch = _db.batch();
      for (final dose in doses.docs) {
        batch.delete(dose.reference);
      }
      batch.delete(
        _db.collection('households').doc(householdId).collection('medicines').doc(medicineId),
      );
      await batch.commit();
    } on FirebaseException {
      throw Exception('Could not delete that medicine right now. Please try again.');
    }
  }

  Future<void> ensureDoseSlotsForDay({
    required String householdId,
    required MedicineModel medicine,
    required DateTime day,
  }) async {
    final dateOnly = DateTime(day.year, day.month, day.day);
    final medicineStart = _stripTime(medicine.startDate.toDate());
    final medicineEnd = medicine.endDate == null ? null : _stripTime(medicine.endDate!.toDate());
    if (dateOnly.isBefore(medicineStart)) {
      return;
    }
    if (medicineEnd != null && dateOnly.isAfter(medicineEnd)) {
      return;
    }

    final start = dateOnly;
    final end = dateOnly.add(const Duration(days: 1));
    final existing = await _db
        .collection('households')
        .doc(householdId)
        .collection('medicines')
        .doc(medicine.id)
        .collection('doses')
        .where('scheduledTime', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('scheduledTime', isLessThan: Timestamp.fromDate(end))
        .get();

    final existingIds = existing.docs.map((doc) => doc.id).toSet();
    final batch = _db.batch();

    for (final reminderTime in medicine.reminderTimes) {
      final scheduledDateTime = _combineDateAndTime(dateOnly, reminderTime);
      if (scheduledDateTime == null) {
        continue;
      }

      final doseId = doseIdForTimestamp(scheduledDateTime);
      if (existingIds.contains(doseId)) {
        continue;
      }

      final dose = DoseLogModel(
        id: doseId,
        scheduledTime: Timestamp.fromDate(scheduledDateTime),
        takenAt: null,
        status: 'pending',
        householdId: householdId,
        medicineId: medicine.id,
      );

      batch.set(
        _db
            .collection('households')
            .doc(householdId)
            .collection('medicines')
            .doc(medicine.id)
            .collection('doses')
            .doc(doseId),
        dose.toMap(),
      );
    }

    await batch.commit();
  }

  Future<void> markMissedDoses({
    required String householdId,
    required String medicineId,
    required DateTime now,
  }) async {
    final pendingSnapshot = await _db
        .collection('households')
        .doc(householdId)
        .collection('medicines')
        .doc(medicineId)
        .collection('doses')
        .where('status', isEqualTo: 'pending')
        .where('scheduledTime', isLessThanOrEqualTo: Timestamp.fromDate(now))
        .get();

    if (pendingSnapshot.docs.isEmpty) {
      return;
    }

    final batch = _db.batch();
    for (final doc in pendingSnapshot.docs) {
      batch.update(doc.reference, {'status': 'missed'});
    }
    await batch.commit();
  }

  Future<void> logDoseTaken({
    required String householdId,
    required String medicineId,
    required DateTime scheduledTime,
  }) async {
    try {
      final doseId = doseIdForTimestamp(scheduledTime);
      final dose = DoseLogModel(
        id: doseId,
        scheduledTime: Timestamp.fromDate(scheduledTime),
        takenAt: Timestamp.now(),
        status: 'taken',
        householdId: householdId,
        medicineId: medicineId,
      );

      await _db
          .collection('households')
          .doc(householdId)
          .collection('medicines')
          .doc(medicineId)
          .collection('doses')
          .doc(doseId)
          .set(dose.toMap(), SetOptions(merge: true));
    } on FirebaseException {
      throw Exception('Could not mark that dose as taken right now. Please try again.');
    }
  }

  String doseIdForTimestamp(DateTime scheduledTime) {
    return DateFormat('yyyyMMdd_HHmm').format(scheduledTime);
  }

  DateTime? scheduledDateTimeFor({
    required DateTime day,
    required String reminderTime,
  }) {
    return _combineDateAndTime(day, reminderTime);
  }

  DateTime _stripTime(DateTime dateTime) {
    return DateTime(dateTime.year, dateTime.month, dateTime.day);
  }

  DateTime? _combineDateAndTime(DateTime day, String reminderTime) {
    final parts = reminderTime.split(':');
    if (parts.length != 2) {
      return null;
    }

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) {
      return null;
    }

    return DateTime(day.year, day.month, day.day, hour, minute);
  }
}
