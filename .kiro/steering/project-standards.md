# Project Standards — Personal Memory OS

## Overview
This is a Flutter mobile application backed by an AWS-native cloud architecture.
The project is structured feature-first under `lib/features/`.

## Tech Stack
- **Frontend:** Flutter (Dart) — dark Material 3 theme
- **Auth:** Amazon Cognito via AWS Amplify
- **API:** AWS AppSync (GraphQL)
- **Backend:** AWS Lambda (domain functions)
- **Database:** Amazon Aurora PostgreSQL-Compatible
- **Storage:** Amazon S3 (private, KMS-encrypted)
- **AI:** Amazon Bedrock (Claude/Titan via Lambda — never called directly from Flutter)
- **Scheduling:** Amazon EventBridge Scheduler + local device notifications
- **Notifications:** Amazon SNS → APNs/FCM
- **Search/RAG:** Bedrock Knowledge Bases + OpenSearch Serverless
- **Queues:** Amazon SQS with dead-letter queues
- **IaC:** AWS CDK under `infra/`

## Code Conventions
- All Dart files use `lowerCamelCase` for variables and `UpperCamelCase` for classes
- Each feature lives under `lib/features/<feature>/screens/` and `lib/features/<feature>/widgets/`
- Shared, cross-feature widgets live in `lib/shared/widgets/`
- Service abstractions live in `lib/core/services/` — always use abstract classes + stub/real implementations
- Providers live in `lib/core/providers/` and extend `ChangeNotifier`
- Colors and text styles are always referenced from `AppColors` and `AppTextStyles` — never hard-code hex values inline
- All screens use `AppColors.background` as scaffold background

## AI Principles (from product spec)
- AI interprets; deterministic AWS services execute
- Never depend on an LLM to trigger or execute an alarm
- Always confirm AI-generated actions (reminders, deadlines) with the user before saving
- Every AI answer must be traceable to stored memory (source grounding)
- LLM calls happen server-side (Lambda → Bedrock), never from the Flutter client directly

## Reliability Rules
- Reminders use both EventBridge Scheduler (cloud) and flutter_local_notifications (device)
- Use SQS for all async AI processing
- Dead-letter queues for failed jobs
- Track every notification delivery (notification_deliveries table)
- Never silently drop a reminder

## File Naming
- Screens: `<feature>_screen.dart`
- Widgets: descriptive noun, e.g. `reminder_card.dart`, `now_card.dart`
- Models: singular noun, e.g. `reminder.dart`, `event.dart`
- Services: `<domain>_service.dart`
- Providers: `<domain>_provider.dart`

## Security
- S3 buckets are private; use pre-signed URLs
- All secrets in AWS Secrets Manager — never in source code
- KMS encryption for S3, Aurora, and sensitive fields
- Cognito JWT for all API calls — user-level authorization in Lambda
- WAF on AppSync endpoint
