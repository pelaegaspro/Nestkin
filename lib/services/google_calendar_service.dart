import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/calendar/v3.dart' as calendar;
import 'package:http/http.dart' as http;

import '../models/event_model.dart';

class GoogleCalendarService {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [calendar.CalendarApi.calendarReadonlyScope],
  );

  Future<List<EventModel>> fetchUpcomingEvents({
    bool promptIfNeeded = false,
  }) async {
    final account = await _googleSignIn.signInSilently() ??
        (promptIfNeeded ? await _googleSignIn.signIn() : null);
    if (account == null) {
      return const [];
    }

    try {
      final headers = await account.authHeaders;
      final client = _GoogleAuthClient(headers);
      final api = calendar.CalendarApi(client);
      final now = DateTime.now().toUtc();
      final end = now.add(const Duration(days: 30));

      final response = await api.events.list(
        'primary',
        singleEvents: true,
        orderBy: 'startTime',
        timeMin: now,
        timeMax: end,
      );

      return (response.items ?? const <calendar.Event>[])
          .where((event) =>
              event.start?.dateTime != null || event.start?.date != null)
          .map(_mapGoogleEvent)
          .toList();
    } catch (error) {
      if (_shouldSilentlyIgnore(error)) {
        return const [];
      }
      throw Exception(_friendlyErrorMessage(error));
    }
  }

  Future<void> signOut() => _googleSignIn.signOut();

  bool _shouldSilentlyIgnore(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('calendar api has not been used') ||
        message.contains('access_not_configured') ||
        message.contains('api has not been used in project') ||
        (message.contains('403') && message.contains('calendar'));
  }

  String _friendlyErrorMessage(Object error) {
    final message = error.toString().toLowerCase();
    if (message.contains('network')) {
      return 'Could not refresh Google Calendar right now.';
    }
    if (message.contains('sign_in_canceled') ||
        message.contains('sign in canceled')) {
      return 'Google Calendar sync was canceled.';
    }
    return 'Could not load personal Google Calendar events right now.';
  }

  EventModel _mapGoogleEvent(calendar.Event event) {
    final start =
        event.start?.dateTime ?? event.start?.date ?? DateTime.now().toUtc();
    final end = event.end?.dateTime ??
        event.end?.date ??
        start.add(const Duration(hours: 1));

    return EventModel(
      id: event.id ?? '',
      title: event.summary ?? 'Google event',
      description: event.description ?? '',
      startTime: Timestamp.fromDate(start.toLocal()),
      endTime: Timestamp.fromDate(end.toLocal()),
      createdBy: 'google',
      createdByName: 'Google Calendar',
      assignedTo: const [],
      assignedToNames: const [],
      color: '#9E9E9E',
      isRecurring: false,
      recurrence: EventRecurrence.none,
      source: EventSource.google,
      isSharedFromGoogle: false,
    );
  }
}

class _GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _inner = http.Client();

  _GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _inner.send(request);
  }
}
