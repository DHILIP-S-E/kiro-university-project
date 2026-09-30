# Personal Reminder & Memory OS

> **Never forget what you need to do, and never lose what you learned.**

An AWS-native personal intelligence platform built with Flutter and Amazon Bedrock.

---

## What It Is

A mobile app combining a smart reminder engine with a personal memory system.

- **Reminder Engine** — time-based, deadline, recurring, follow-up, and multi-stage reminders with two-layer delivery (AWS + device)
- **Event Intelligence** — hackathons, workshops, conferences, webinars, meetings — each generates a smart reminder policy
- **Capture** — photos, voice notes, text, documents, links — captured instantly, organized by AI asynchronously
- **Memory** — every event becomes a structured, searchable knowledge document
- **AI Retrieval** — ask questions in natural language; answers grounded in your own captured content

---

## Quick Start

### Prerequisites

- Flutter SDK ≥ 3.16
- Dart SDK ≥ 3.2
- AWS account with Amplify CLI configured
- Amazon Bedrock model access enabled (Claude 3, Titan)

### Install dependencies

```bash
flutter pub get
```

### Run (stub mode — no AWS required)

```bash
flutter run
```

The app boots in stub mode with seeded demo data. All services have `Stub*` implementations that return realistic mock data without needing a live AWS backend.

### Configure AWS backend

1. Install Amplify CLI: `npm install -g @aws-amplify/cli`
2. Initialize: `amplify init`
3. Add auth: `amplify add auth` (Cognito User Pools + Google OAuth)
4. Add API: `amplify add api` (AppSync GraphQL)
5. Add storage: `amplify add storage` (S3 private)
6. Push: `amplify push`
7. Update `lib/aws/amplify_config.dart` with the generated values
8. Swap `Stub*Service` classes in `lib/main.dart` for real `Amplify*Service` implementations

---

## Project Structure

```
lib/
  main.dart                         ← App entry, provider wiring, service injection
  shell.dart                        ← Bottom NavigationBar shell (go_router ShellRoute)
  core/
    models/                         ← Pure Dart data classes
      reminder.dart                 ← Reminder, ReminderType, ReminderStatus, ReminderOffset
      event.dart                    ← Event, EventDeadline, EventType, EventStatus
      capture.dart                  ← Capture, CaptureAiResult, ExtractedAction
      memory_document.dart          ← MemoryDocument, ActionItemRef, DeadlineRef
      ai_message.dart               ← AiMessage, AiAnswer, AiMessageSource
    services/                       ← Abstract interfaces + stub implementations
      auth_service.dart             ← Cognito auth (StubAuthService)
      reminder_service.dart         ← AppSync reminders (StubReminderService)
      event_service.dart            ← AppSync events (StubEventService)
      capture_service.dart          ← S3 + AppSync captures (StubCaptureService)
      memory_service.dart           ← Bedrock Knowledge Bases search (StubMemoryService)
      ai_service.dart               ← Bedrock NLP + extraction (StubAiService)
    providers/                      ← ChangeNotifier state managers
      auth_provider.dart
      reminder_provider.dart        ← filters: today/upcoming/recurring/deadlines/overdue
      event_provider.dart
      capture_provider.dart
      memory_provider.dart          ← search + AI Q&A chat history
    router/app_router.dart          ← go_router config, all named routes
    theme/app_theme.dart            ← AppColors, AppTextStyles, AppTheme.dark
    utils/date_utils.dart           ← formatting, timeUntil, greeting
  features/
    today/
      today_screen.dart             ← Home: NowCard, today reminders/events, upcoming, recent memory
      widgets/now_card.dart         ← "NEXT UP" urgency card
      widgets/quick_capture_bar.dart← Bottom sheet quick actions
    reminders/
      screens/reminders_screen.dart ← Filter bar + dismissible list
      screens/reminder_create_screen.dart ← Manual + NLP tabs (Bedrock)
    capture/
      screens/capture_screen.dart   ← Camera/gallery/voice/note/link
      widgets/voice_recorder_sheet.dart
      widgets/text_note_sheet.dart
      widgets/link_capture_sheet.dart
    memory/
      screens/memory_screen.dart    ← Event timeline grouped by month + AI Q&A entry
      screens/memory_search_screen.dart ← Keyword + semantic search
      screens/ai_chat_screen.dart   ← Grounded Q&A with source citations
    events/
      screens/event_create_screen.dart  ← Manual + paste/AI extract tabs
      screens/event_detail_screen.dart  ← Deadlines, captures, memory summary
    settings/settings_screen.dart   ← Profile, notifications, AI, storage, privacy
    auth/auth_screen.dart           ← Email + Google sign-in (Cognito)
  shared/widgets/
    reminder_card.dart              ← Priority stripe, type icon, snooze/done actions
    event_card.dart                 ← Type badge, deadline chip
    capture_card.dart               ← Processing status, AI result preview
    ai_suggestion_banner.dart       ← Confirm/dismiss pattern for AI suggestions
    section_header.dart
    status_chip.dart
    empty_state.dart
  aws/amplify_config.dart           ← Amplify configuration (replace placeholders)

infra/                              ← AWS CDK stacks (to be implemented)
  auth/       api/       database/
  storage/    queues/    scheduler/
  notifications/   ai/   search/
  monitoring/ security/

.kiro/
  steering/
    project-standards.md   ← Always-included standards and conventions
    aws-architecture.md    ← Always-included AWS service map and data flows
    flutter-patterns.md    ← Auto-included when editing .dart files
  specs/
    personal-memory-os.md  ← Full requirements, design, and task checklist
  hooks/
    lint-on-dart-save.json         ← dart analyze on every .dart save
    review-write-standards.json    ← Pre-write standards check
    post-task-spec-sync.json       ← Sync spec after task completion
    session-start-context.json     ← Load project context on session start
```

---

## Architecture

```
Flutter App (AWS Amplify)
        │ Cognito JWT
        ▼
  AWS AppSync (GraphQL)
        │
   AWS Lambda
   ┌────┴──────────────────────────────────┐
   │            │            │             │
   ▼            ▼            ▼             ▼
Aurora       Amazon S3    Amazon SQS   EventBridge
PostgreSQL   (private)    (queues)     Scheduler
   │            │            │             │
   │            ▼            ▼             │
   │     Bedrock Data    Lambda         Amazon SNS
   │     Automation      Workers            │
   │         │               │         APNs / FCM
   │         └───────────────┘
   │                   │
   │           Amazon Bedrock
   │           (Claude 3 / Titan)
   │                   │
   │         Bedrock Knowledge Bases
   │                   │
   │         OpenSearch Serverless
   └───────────────────┘
```

### Two-Layer Alarm Strategy

```
Cloud:  EventBridge Scheduler → Lambda → SNS → APNs/FCM
Device: flutter_local_notifications (works offline)
```

The LLM never executes alarms. EventBridge Scheduler handles all server-side scheduling.

### Capture → Memory Pipeline

```
S3 upload → EventBridge → SQS → Lambda → Bedrock Data Automation
  → Bedrock LLM (summarize/extract) → Aurora + Knowledge Bases → client notification
```

---

## Key Product Principles

1. **Capture first. Organize later.** — Tap, capture, done. AI handles the rest.
2. **AI suggests. User confirms.** — No silent creation of reminders or deadlines from AI.
3. **AI interprets; deterministic systems execute.** — Bedrock parses, EventBridge schedules.
4. **Never silently lose a reminder.** — Two-layer delivery + delivery tracking.
5. **Every AI answer is traceable.** — Source citations on every Bedrock response.

---

## Kiro University Lessons Demonstrated

| Lesson | Implementation |
|---|---|
| **Spec-driven development** | `.kiro/specs/personal-memory-os.md` — full requirements, design, and task checklist |
| **Steering documents** | `project-standards.md` (always), `aws-architecture.md` (always), `flutter-patterns.md` (fileMatch: .dart) |
| **Hooks** | 4 hooks: lint-on-save, pre-write standards review, post-task spec sync, session-start context |
| **Property-based testing** | Reminder parsing properties defined in spec R1.2 (implementation pending) |
| **Custom agents** | Defined via session agent configuration |

---

## AWS Services Used (MVP)

| Service | Purpose |
|---|---|
| AWS Amplify | Mobile integration, CI/CD |
| Amazon Cognito | Auth (email + Google OAuth) |
| AWS AppSync | GraphQL API + real-time subscriptions |
| AWS Lambda | All backend compute (domain functions) |
| Amazon Aurora PostgreSQL | Source-of-truth relational database |
| Amazon S3 | Private media storage (KMS-encrypted) |
| Amazon SQS | Async processing queues + DLQs |
| Amazon EventBridge Scheduler | Reliable server-side reminder scheduling |
| Amazon SNS | Push notification delivery |
| Amazon Bedrock | NLP, summarization, extraction (Claude 3 / Titan) |
| Bedrock Data Automation | Photo/audio/document extraction |
| Bedrock Knowledge Bases | RAG — personal memory retrieval |
| Amazon OpenSearch Serverless | Vector search for semantic queries |
| AWS KMS | Encryption at rest |
| AWS Secrets Manager | Credential management |
| Amazon CloudWatch | Metrics, logs, alarms |
| AWS CloudTrail | API audit logs |
| AWS WAF | AppSync endpoint protection |

---

## Demo Flow (Hackathon Story)

1. User pastes hackathon webpage text → AI extracts event, dates, deadline
2. User confirms → Event created with reminder policy (registration + event-day)
3. Reminder fires 30 min before: *"AWS Hackathon starts in 30 minutes"*
4. User attends → captures 8 photos, 2 voice notes, 1 text note
5. AI processes → generates event summary: topics, takeaways, action items
6. AI suggests: *"You mentioned a prototype deadline — create reminder?"*
7. User confirms → reminder created, linked to the memory
8. Three months later: *"What did I learn about Bedrock Agents?"* → grounded answer with source citations
