import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/event_model.dart';

class EventRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<List<EventModel>> streamEvents(String householdId) {
    return _db
        .collection('households')
        .doc(householdId)
        .collection('events')
        .orderBy('startTime')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => EventModel.fromMap({
                  ...doc.data(),
                  'id': doc.id,
                }),
              )
              .toList(),
        );
  }

  Future<void> saveEvent({
    required String householdId,
    required EventModel event,
  }) async {
    try {
      final collection = _db.collection('households').doc(householdId).collection('events');
      final ref = event.id.isEmpty ? collection.doc() : collection.doc(event.id);
      await ref.set(
        event.copyWith(id: ref.id).toMap(),
        SetOptions(merge: true),
      );
    } on FirebaseException {
      throw Exception('Could not save that event right now. Please try again.');
    }
  }

  Future<void> deleteEvent({
    required String householdId,
    required String eventId,
  }) async {
    try {
      await _db.collection('households').doc(householdId).collection('events').doc(eventId).delete();
    } on FirebaseException {
      throw Exception('Could not delete that event right now. Please try again.');
    }
  }

  List<EventModel> occurrencesForRange({
    required List<EventModel> events,
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) {
    final occurrences = <EventModel>[];
    for (final event in events) {
      occurrences.addAll(
        _expandOccurrences(
          event: event,
          rangeStart: rangeStart,
          rangeEnd: rangeEnd,
        ),
      );
    }
    occurrences.sort((a, b) => a.startDateTime.compareTo(b.startDateTime));
    return occurrences;
  }

  List<EventModel> eventsForDay({
    required List<EventModel> events,
    required DateTime day,
  }) {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    return occurrencesForRange(
      events: events,
      rangeStart: start,
      rangeEnd: end,
    ).where((event) {
      final startTime = event.startDateTime;
      return !startTime.isBefore(start) && startTime.isBefore(end);
    }).toList();
  }

  List<EventModel> _expandOccurrences({
    required EventModel event,
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) {
    final occurrences = <EventModel>[];
    final duration = event.endDateTime.difference(event.startDateTime);
    var currentStart = event.startDateTime;
    var currentEnd = event.endDateTime;

    while (currentStart.isBefore(rangeEnd)) {
      final overlapsRange =
          !currentEnd.isBefore(rangeStart) && currentStart.isBefore(rangeEnd);
      if (overlapsRange) {
        occurrences.add(
          event.copyWith(
            startTime: Timestamp.fromDate(currentStart),
            endTime: Timestamp.fromDate(currentEnd),
          ),
        );
      }

      if (!event.isRecurring || event.recurrence == EventRecurrence.none) {
        break;
      }

      currentStart = _nextDate(currentStart, event.recurrence);
      currentEnd = currentStart.add(duration);
    }

    return occurrences;
  }

  DateTime _nextDate(DateTime current, EventRecurrence recurrence) {
    switch (recurrence) {
      case EventRecurrence.daily:
        return current.add(const Duration(days: 1));
      case EventRecurrence.weekly:
        return current.add(const Duration(days: 7));
      case EventRecurrence.monthly:
        return DateTime(
          current.year,
          current.month + 1,
          current.day,
          current.hour,
          current.minute,
        );
      case EventRecurrence.none:
        return current;
    }
  }
}
