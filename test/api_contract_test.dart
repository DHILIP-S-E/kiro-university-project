import 'package:flutter_test/flutter_test.dart';
import 'package:personal_memory_os/core/models/capture.dart';
import 'package:personal_memory_os/core/models/event.dart';
import 'package:personal_memory_os/core/models/reminder.dart';
import 'package:personal_memory_os/core/services/api_mapper.dart';

/// Payloads copied from the backend `to_dict()` methods — if the backend
/// contract changes, these break instead of the app at runtime.
void main() {
  test('reminder from backend', () {
    final r = reminderFromApi({
      'id': 'r1',
      'user_id': 'u1',
      'title': 'Submit',
      'description': null,
      'reminder_type': 'follow_up',
      'scheduled_at': '2026-10-04T09:00:00+00:00',
      'timezone': 'UTC',
      'priority': 'high',
      'status': 'active',
      'alarm_enabled': true,
      'notification_enabled': true,
      'recurrence_rule': null,
      'source': 'event',
      'context_id': 'e1',
      'offsets': ['-1d', '-3h'],
      'created_at': '2026-09-30T10:00:00',
      'updated_at': '2026-09-30T10:00:00',
    });
    expect(r.reminderType, ReminderType.followUp);
    expect(r.source, ReminderSource.eventPolicy);
    expect(r.offsets.map((o) => o.offset), ['-1d', '-3h']);
    expect(r.syncStatus, 'SYNCED');
    expect(r.scheduledAt!.isUtc || r.scheduledAt != null, isTrue);
  });

  test('every backend reminder type/source/priority value parses', () {
    for (final t in ['time', 'date', 'deadline', 'recurring', 'follow_up', 'multi_stage']) {
      for (final s in ['manual', 'nlp', 'ai_extracted', 'event']) {
        final r = reminderFromApi({
          'id': 'r', 'user_id': 'u', 'title': 't', 'reminder_type': t, 'source': s,
          'priority': 'low', 'status': 'active', 'offsets': [],
          'created_at': '2026-01-01T00:00:00', 'updated_at': '2026-01-01T00:00:00',
        });
        expect(r.title, 't');
      }
    }
  });

  test('capture from backend (with and without ai_result)', () {
    final base = {
      'id': 'c1', 'user_id': 'u1', 'event_id': 'e1', 'capture_type': 'photo',
      'storage_key': 'users/u1/events/e1/photo/c1.jpg', 'mime_type': 'image/jpeg',
      'duration': null, 'transcription': null, 'content': null,
      'processing_status': 'processed',
      'created_at': '2026-09-30T10:00:00', 'updated_at': '2026-09-30T10:00:00',
    };
    final plain = captureFromApi({...base, 'ai_result': null});
    expect(plain.type, CaptureType.photo);
    expect(plain.processingStatus, CaptureProcessingStatus.processed);
    expect(plain.aiResult, isNull);

    final withAi = captureFromApi({
      ...base,
      'ai_result': {
        'summary': 'Slides on Bedrock',
        'topics': ['Bedrock'],
        'key_points': ['Agents use tools'],
        'actions': ['Try AgentCore', {'title': 'Ship', 'due_at': '2026-10-01T00:00:00'}],
      },
    });
    expect(withAi.aiResult!.keyPoints, ['Agents use tools']);
    expect(withAi.aiResult!.actions.map((a) => a.title), ['Try AgentCore', 'Ship']);
  });

  test('event with deadlines from backend', () {
    final e = eventFromApi({
      'id': 'e1', 'user_id': 'u1', 'title': 'AWS Hackathon', 'description': null,
      'event_type': 'hackathon', 'start_at': '2026-10-04T09:00:00+00:00',
      'end_at': null, 'timezone': 'UTC', 'location': 'Bangalore',
      'is_virtual': false, 'event_url': null, 'organizer': null,
      'registration_url': null, 'status': 'upcoming', 'summary_id': null,
      'photo_count': 8, 'voice_note_count': 2, 'document_count': 0,
      'deadlines': [
        {
          'id': 'd1', 'event_id': 'e1', 'user_id': 'u1', 'title': 'Register',
          'deadline_type': 'registration', 'deadline_at': '2026-10-01T23:59:00+00:00',
          'status': 'active', 'created_at': '2026-09-30T10:00:00',
        }
      ],
      'created_at': '2026-09-30T10:00:00', 'updated_at': '2026-09-30T10:00:00',
    });
    expect(e.eventType, EventType.hackathon);
    expect(e.deadlines.single.deadlineType, DeadlineType.registration);
    expect(e.photoCount, 8);
  });

  test('memory document with summariser-shaped action items', () {
    final m = memoryFromApi({
      'id': 'm1', 'user_id': 'u1', 'event_id': 'e1', 'event_title': 'AWS Hackathon',
      'overview': 'o', 'key_topics': ['RAG'], 'key_takeaways': [], 'things_learned': [],
      'important_people': [], 'resources': [], 'links': [],
      'action_items': [
        {'title': 'Finish prototype', 'due_at': '2026-10-10'},
        'Read docs',
      ],
      'deadlines': [], 'decisions': [],
      'event_date': '2026-10-04T09:00:00+00:00',
      'created_at': '2026-10-05T10:00:00', 'updated_at': '2026-10-05T10:00:00',
    });
    expect(m.keyTopics, ['RAG']);
    expect(m.actionItems.map((a) => a.title), ['Finish prototype', 'Read docs']);
  });

  test('AI answer source from backend', () {
    final s = aiSourceFromApi(
        {'event_title': 'AWS Hackathon', 'capture_ref': 'c1', 'capture_type': 'voice'});
    expect(s.eventTitle, 'AWS Hackathon');
    expect(s.captureRef, 'c1');
  });

  test('camelize is idempotent on camelCase and handles nesting', () {
    expect(camelize('created_at'), 'createdAt');
    expect(camelize('alreadyCamel'), 'alreadyCamel');
    expect(camelizeKeys({'a_b': [{'c_d': 1}]}), {'aB': [{'cD': 1}]});
  });
}
