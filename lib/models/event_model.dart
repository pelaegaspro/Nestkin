import 'package:cloud_firestore/cloud_firestore.dart';

enum EventSource {
  nestkin,
  google,
}

enum EventRecurrence {
  none,
  daily,
  weekly,
  monthly,
}

class EventModel {
  final String id;
  final String title;
  final String description;
  final Timestamp startTime;
  final Timestamp endTime;
  final String createdBy;
  final String createdByName;
  final List<String> assignedTo;
  final List<String> assignedToNames;
  final String color;
  final bool isRecurring;
  final EventRecurrence recurrence;
  final EventSource source;
  final bool isSharedFromGoogle;

  const EventModel({
    required this.id,
    required this.title,
    required this.description,
    required this.startTime,
    required this.endTime,
    required this.createdBy,
    required this.createdByName,
    required this.assignedTo,
    required this.assignedToNames,
    required this.color,
    required this.isRecurring,
    required this.recurrence,
    required this.source,
    required this.isSharedFromGoogle,
  });

  DateTime get startDateTime => startTime.toDate();
  DateTime get endDateTime => endTime.toDate();
  bool get isGooglePersonal => source == EventSource.google && !isSharedFromGoogle;

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'description': description,
        'startTime': startTime,
        'endTime': endTime,
        'createdBy': createdBy,
        'createdByName': createdByName,
        'assignedTo': assignedTo,
        'assignedToNames': assignedToNames,
        'color': color,
        'isRecurring': isRecurring,
        'recurrenceRule': recurrence.name,
        'source': source.name,
        'isSharedFromGoogle': isSharedFromGoogle,
      };

  EventModel copyWith({
    String? id,
    String? title,
    String? description,
    Timestamp? startTime,
    Timestamp? endTime,
    String? createdBy,
    String? createdByName,
    List<String>? assignedTo,
    List<String>? assignedToNames,
    String? color,
    bool? isRecurring,
    EventRecurrence? recurrence,
    EventSource? source,
    bool? isSharedFromGoogle,
  }) {
    return EventModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      createdBy: createdBy ?? this.createdBy,
      createdByName: createdByName ?? this.createdByName,
      assignedTo: assignedTo ?? this.assignedTo,
      assignedToNames: assignedToNames ?? this.assignedToNames,
      color: color ?? this.color,
      isRecurring: isRecurring ?? this.isRecurring,
      recurrence: recurrence ?? this.recurrence,
      source: source ?? this.source,
      isSharedFromGoogle: isSharedFromGoogle ?? this.isSharedFromGoogle,
    );
  }

  factory EventModel.fromMap(Map<String, dynamic> map) {
    final recurrenceName = (map['recurrenceRule'] ?? 'none').toString();
    final sourceName = (map['source'] ?? 'nestkin').toString();

    return EventModel(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      startTime: map['startTime'] ?? Timestamp.now(),
      endTime: map['endTime'] ?? Timestamp.now(),
      createdBy: map['createdBy'] ?? '',
      createdByName: map['createdByName'] ?? 'Member',
      assignedTo: List<String>.from(map['assignedTo'] ?? const []),
      assignedToNames: List<String>.from(map['assignedToNames'] ?? const []),
      color: map['color'] ?? '#0B5C68',
      isRecurring: map['isRecurring'] ?? false,
      recurrence: EventRecurrence.values.firstWhere(
        (value) => value.name == recurrenceName,
        orElse: () => EventRecurrence.none,
      ),
      source: EventSource.values.firstWhere(
        (value) => value.name == sourceName,
        orElse: () => EventSource.nestkin,
      ),
      isSharedFromGoogle: map['isSharedFromGoogle'] ?? false,
    );
  }
}
