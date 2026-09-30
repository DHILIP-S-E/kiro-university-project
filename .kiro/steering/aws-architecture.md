# AWS Architecture Reference

## Service Map

| Concern | AWS Service |
|---|---|
| Mobile integration | AWS Amplify |
| Authentication | Amazon Cognito (User Pools + Identity Pools) |
| API | AWS AppSync (GraphQL + Subscriptions) |
| Backend compute | AWS Lambda (domain-scoped functions) |
| Relational database | Amazon Aurora PostgreSQL-Compatible (Serverless v2) |
| Object storage | Amazon S3 (private, KMS-encrypted) |
| Async queue | Amazon SQS + Dead-Letter Queues |
| Event routing | Amazon EventBridge |
| Reliable scheduling | Amazon EventBridge Scheduler |
| Push notifications | Amazon SNS → APNs (iOS) + FCM (Android) |
| AI models | Amazon Bedrock (Claude 3, Titan) |
| Multimedia extraction | Amazon Bedrock Data Automation |
| Transcription | Bedrock Data Automation / Amazon Transcribe |
| AI retrieval (RAG) | Amazon Bedrock Knowledge Bases |
| Vector search | Amazon OpenSearch Serverless |
| Image analysis | Amazon Bedrock / Amazon Rekognition |
| Encryption keys | AWS KMS |
| Secrets | AWS Secrets Manager |
| Monitoring | Amazon CloudWatch (metrics, logs, alarms) |
| Audit | AWS CloudTrail |
| API protection | AWS WAF |
| Infrastructure as code | AWS CDK (under `infra/`) |
| CI/CD | AWS CodePipeline + CodeBuild |

## Lambda Domain Functions

```
reminder-create       reminder-update       reminder-delete       reminder-process
event-create          event-update          event-delete
capture-create        capture-process
summary-generate      action-extract
memory-index          memory-search
notification-dispatch notification-status
```

## Data Flow — Capture → Memory

```
Mobile Upload (S3)
  → EventBridge rule fires
  → SQS message enqueued
  → Lambda worker dequeues
  → Bedrock Data Automation (extract text/images)
  → Lambda calls Bedrock LLM (summarize, extract topics/actions)
  → Results written to Aurora
  → Bedrock Knowledge Base synced (embeddings → OpenSearch Serverless)
  → AppSync subscription notifies Flutter client
```

## Alarm Strategy — Two-Layer

```
Cloud (reliable server-side):
  EventBridge Scheduler → Lambda → SNS → APNs/FCM

Device (offline protection):
  flutter_local_notifications (scheduled locally on device)
```

Critical reminders register BOTH layers. The LLM never executes scheduling.

## S3 Key Structure

```
personal-memory/
  users/
    {userId}/
      events/
        {eventId}/
          photos/
          audio/
          videos/
          documents/
          transcripts/
          generated/   ← AI summaries, extracted content
```

## Queue Names

```
photo-processing-queue        (DLQ: photo-processing-dlq)
voice-processing-queue        (DLQ: voice-processing-dlq)
document-processing-queue     (DLQ: document-processing-dlq)
summary-processing-queue      (DLQ: summary-processing-dlq)
notification-queue            (DLQ: notification-dlq)
```

## Environments

```
dev → staging → production
```

Never use production data in dev or staging.

## Bedrock Model Routing

```
Simple extraction / classification  → cheaper/faster model (e.g. Titan Text Lite)
Summarization                       → mid-tier model (e.g. Claude 3 Haiku)
Cross-event synthesis               → stronger model (e.g. Claude 3 Sonnet)
Complex personal question + RAG     → Claude 3 Sonnet / Opus
```

Model IDs must be configurable — never hard-code in Lambda source.
