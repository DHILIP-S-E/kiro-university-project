import 'package:personal_memory_os/core/models/event.dart';
import 'package:personal_memory_os/core/services/event_service.dart';
import 'package:personal_memory_os/core/services/api_client.dart';

/// Real implementation of [EventService] that calls the FastAPI backend.
class ApiEventService implements EventService {
  final ApiClient _client;

  ApiEventService(this._client);

  @override
  Future<List<Event>> fetchEvents() async {
    final data = await _client.get('/events') as List<dynamic>;
    return data.map((j) => Event.fromJson(j as Map<String, dynamic>)).toList();
  }

  @override
  Future<Event> createEvent(Event event) async {
    final data = await _client.post('/events', {
      'title': event.title,
      'description': event.description,
      'event_type': event.eventType.name,
      'start_at': event.startAt.toUtc().toIso8601String(),
      'end_at': event.endAt?.toUtc().toIso8601String(),
      'timezone': event.timezone,
      'location': event.location,
      'is_virtual': event.isVirtual,
      'event_url': event.eventUrl,
      'organizer': event.organizer,
      'registration_url': event.registrationUrl,
      'deadlines': event.deadlines.map((d) => {
        'title': d.title,
        'deadline_type': d.deadlineType.name,
        'deadline_at': d.deadlineAt.toUtc().toIso8601String(),
      }).toList(),
    });
    return Event.fromJson(data as Map<String, dynamic>);
  }

  @override
  Future<Event> updateEvent(Event event) async {
    final data = await _client.patch('/events/${event.id}', {
      'title': event.title,
      'description': event.description,
      'status': event.status.name,
      'start_at': event.startAt.toUtc().toIso8601String(),
      'end_at': event.endAt?.toUtc().toIso8601String(),
      'location': event.location,
      'event_url': event.eventUrl,
      'organizer': event.organizer,
    });
    return Event.fromJson(data as Map<String, dynamic>);
  }

  @override
  Future<void> deleteEvent(String id) async {
    await _client.delete('/events/$id');
  }
}
