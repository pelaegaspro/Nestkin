import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import '../models/event_model.dart';
import '../models/household_member_model.dart';
import '../services/event_repository.dart';
import '../services/firestore_service.dart';
import '../services/google_calendar_service.dart';
import '../widgets/add_event_sheet.dart';
import '../widgets/event_detail_sheet.dart';
import '../widgets/share_to_household_sheet.dart';

enum CalendarViewMode {
  month,
  week,
  day,
}

class CalendarScreen extends StatefulWidget {
  final String householdId;

  const CalendarScreen({
    super.key,
    required this.householdId,
  });

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final _eventRepository = EventRepository();
  final _googleCalendarService = GoogleCalendarService();
  final _firestoreService = FirestoreService();

  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  CalendarViewMode _viewMode = CalendarViewMode.month;
  List<EventModel> _googleEvents = const [];
  bool _loadingGoogleEvents = false;
  String? _googleError;

  @override
  void initState() {
    super.initState();
    _loadGoogleEvents();
  }

  Future<void> _loadGoogleEvents({
    bool promptIfNeeded = false,
  }) async {
    setState(() {
      _loadingGoogleEvents = true;
      _googleError = null;
    });

    try {
      final events = await _googleCalendarService.fetchUpcomingEvents(
        promptIfNeeded: promptIfNeeded,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _googleEvents = events;
        _loadingGoogleEvents = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _googleError = error.toString().replaceFirst('Exception: ', '');
        _loadingGoogleEvents = false;
      });
    }
  }

  CalendarFormat get _calendarFormat {
    switch (_viewMode) {
      case CalendarViewMode.month:
        return CalendarFormat.month;
      case CalendarViewMode.week:
      case CalendarViewMode.day:
        return CalendarFormat.week;
    }
  }

  List<EventModel> _eventsForDay(
      List<EventModel> firestoreEvents, DateTime day) {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    final householdEvents = _eventRepository.eventsForDay(
      events: firestoreEvents,
      day: day,
    );
    final googleEvents = _googleEvents.where((event) {
      final eventStart = event.startDateTime;
      return !eventStart.isBefore(start) && eventStart.isBefore(end);
    });

    return [...householdEvents, ...googleEvents]..sort(
        (a, b) => a.startDateTime.compareTo(b.startDateTime),
      );
  }

  Future<void> _openAddEventSheet({
    EventModel? event,
    required List<HouseholdMemberModel> members,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => AddEventSheet(
        householdId: widget.householdId,
        members: members,
        initialDate: _selectedDay,
        existingEvent: event,
      ),
    );
  }

  Future<void> _openEventDetailSheet({
    required EventModel event,
    required List<HouseholdMemberModel> members,
  }) async {
    final canEdit = event.createdBy == FirebaseAuth.instance.currentUser!.uid;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => EventDetailSheet(
        event: event,
        canEdit: canEdit,
        onEdit: () {
          Navigator.pop(context);
          _openAddEventSheet(event: event, members: members);
        },
        onDelete: () async {
          Navigator.pop(context);
          try {
            await _eventRepository.deleteEvent(
              householdId: widget.householdId,
              eventId: event.id,
            );
            if (!mounted) {
              return;
            }
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Event deleted.')),
            );
          } catch (error) {
            if (!mounted) {
              return;
            }
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content:
                      Text(error.toString().replaceFirst('Exception: ', ''))),
            );
          }
        },
      ),
    );
  }

  Future<void> _openShareSheet(EventModel event) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => ShareToHouseholdSheet(
        householdId: widget.householdId,
        googleEvent: event,
      ),
    );
  }

  String _formatTimeRange(EventModel event) {
    final start = event.startDateTime;
    final end = event.endDateTime;
    final startHour = start.hour.toString().padLeft(2, '0');
    final startMinute = start.minute.toString().padLeft(2, '0');
    final endHour = end.hour.toString().padLeft(2, '0');
    final endMinute = end.minute.toString().padLeft(2, '0');
    return '$startHour:$startMinute - $endHour:$endMinute';
  }

  Color _parseColor(String hex) {
    final cleaned = hex.replaceAll('#', '');
    return Color(int.parse('FF$cleaned', radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<HouseholdMemberModel>>(
      future: _firestoreService.getHouseholdMembers(widget.householdId),
      builder: (context, membersSnapshot) {
        final members = membersSnapshot.data ?? const <HouseholdMemberModel>[];
        return StreamBuilder<List<EventModel>>(
          stream: _eventRepository.streamEvents(widget.householdId),
          builder: (context, snapshot) {
            final firestoreEvents = snapshot.data ?? const <EventModel>[];
            final selectedEvents = _eventsForDay(firestoreEvents, _selectedDay);

            return Scaffold(
              appBar: AppBar(
                title: const Text('Calendar'),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: _loadingGoogleEvents
                        ? null
                        : () => _loadGoogleEvents(promptIfNeeded: true),
                  ),
                ],
              ),
              floatingActionButton: FloatingActionButton(
                onPressed: () => _openAddEventSheet(members: members),
                child: const Icon(Icons.add),
              ),
              body: Column(
                children: [
                  if (_googleError != null)
                    Container(
                      width: double.infinity,
                      color: Colors.orange.shade100,
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        _googleError!,
                        style: TextStyle(color: Colors.orange.shade900),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: SegmentedButton<CalendarViewMode>(
                      segments: const [
                        ButtonSegment(
                            value: CalendarViewMode.month,
                            label: Text('Month')),
                        ButtonSegment(
                            value: CalendarViewMode.week, label: Text('Week')),
                        ButtonSegment(
                            value: CalendarViewMode.day, label: Text('Day')),
                      ],
                      selected: {_viewMode},
                      onSelectionChanged: (selection) {
                        setState(() => _viewMode = selection.first);
                      },
                    ),
                  ),
                  TableCalendar<EventModel>(
                    firstDay:
                        DateTime.now().subtract(const Duration(days: 365)),
                    lastDay: DateTime.now().add(const Duration(days: 365 * 3)),
                    focusedDay: _focusedDay,
                    calendarFormat: _calendarFormat,
                    selectedDayPredicate: (day) => isSameDay(day, _selectedDay),
                    eventLoader: (day) => _eventsForDay(firestoreEvents, day),
                    onDaySelected: (selectedDay, focusedDay) {
                      setState(() {
                        _selectedDay = selectedDay;
                        _focusedDay = focusedDay;
                        if (_viewMode == CalendarViewMode.day) {
                          _focusedDay = selectedDay;
                        }
                      });
                    },
                    onPageChanged: (focusedDay) {
                      _focusedDay = focusedDay;
                    },
                    headerVisible: _viewMode != CalendarViewMode.day,
                    availableCalendarFormats: const {
                      CalendarFormat.month: 'Month',
                      CalendarFormat.week: 'Week',
                    },
                    calendarBuilders: CalendarBuilders(
                      markerBuilder: (context, date, events) {
                        if (events.isEmpty) {
                          return null;
                        }
                        final markers = events.take(4).map((event) {
                          final isGoogle = event.source == EventSource.google &&
                              !event.isSharedFromGoogle;
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 1.5),
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isGoogle
                                  ? Colors.grey
                                  : _parseColor(event.color),
                              border: isGoogle
                                  ? Border.all(
                                      color: Colors.black54, width: 0.5)
                                  : null,
                            ),
                          );
                        }).toList();

                        return Positioned(
                          bottom: 4,
                          child: Row(children: markers),
                        );
                      },
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: _loadingGoogleEvents && selectedEvents.isEmpty
                        ? const Center(child: CircularProgressIndicator())
                        : selectedEvents.isEmpty
                            ? const Center(
                                child: Text('No events for this day.'))
                            : ListView.separated(
                                padding: const EdgeInsets.all(16),
                                itemBuilder: (context, index) {
                                  final event = selectedEvents[index];
                                  final isGooglePersonal =
                                      event.source == EventSource.google &&
                                          !event.isSharedFromGoogle;

                                  return ListTile(
                                    onTap: isGooglePersonal
                                        ? null
                                        : () => _openEventDetailSheet(
                                            event: event, members: members),
                                    onLongPress: isGooglePersonal
                                        ? () => _openShareSheet(event)
                                        : null,
                                    leading: CircleAvatar(
                                      backgroundColor: isGooglePersonal
                                          ? Colors.grey
                                          : _parseColor(event.color),
                                      child: Icon(
                                        isGooglePersonal
                                            ? Icons.lock_outline
                                            : Icons.event,
                                        color: Colors.white,
                                      ),
                                    ),
                                    title: Text(event.title),
                                    subtitle: Text(_formatTimeRange(event)),
                                    trailing: event.isRecurring
                                        ? const Icon(Icons.repeat, size: 18)
                                        : null,
                                  );
                                },
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 8),
                                itemCount: selectedEvents.length,
                              ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
