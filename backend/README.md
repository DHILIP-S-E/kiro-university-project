# Personal Memory OS — Backend

FastAPI + PostgreSQL + Amazon Bedrock backend for the Personal Memory OS Flutter app.

```
Flutter App  →  FastAPI (this)  →  PostgreSQL (cloud)
                               →  Amazon S3 (media storage)
                               →  Amazon Bedrock (Amazon Nova / Titan)
```

---

## Prerequisites

- Python 3.11+
- Cloud PostgreSQL (Neon, Supabase, AWS RDS, etc.)
- AWS account with:
  - Bedrock access to a text model (Amazon Nova works with no form) and Titan Embeddings
  - S3 bucket created (private)
  - IAM user or role with Bedrock + S3 permissions

---

## Setup

```bash
# 1. Enter the backend directory
cd backend

# 2. Create and activate virtual environment
python -m venv venv
# Windows:
venv\Scripts\activate
# Mac/Linux:
source venv/bin/activate

# 3. Install dependencies
pip install -r requirements.txt

# 4. Copy and fill in environment variables
cp .env.example .env
# Edit .env with your real values (see .env.example for all keys)
```

---

## Environment Variables

| Variable | Description |
|---|---|
| `DATABASE_URL` | PostgreSQL connection string (`postgresql+asyncpg://...`) |
| `AWS_REGION` | AWS region (e.g. `us-east-1`) |
| `AWS_ACCESS_KEY_ID` | AWS access key (or use IAM role) |
| `AWS_SECRET_ACCESS_KEY` | AWS secret key (or use IAM role) |
| `S3_BUCKET` | Private S3 bucket name for media |
| `BEDROCK_MODEL_FAST` | Quick/cheap text model (default `apac.amazon.nova-lite-v1:0`) |
| `BEDROCK_MODEL_STRONG` | Stronger text model (default `apac.amazon.nova-pro-v1:0`) |
| `BEDROCK_EMBEDDING_MODEL` | Titan Embeddings model ID |
| `COGNITO_USER_POOL_ID` | Cognito User Pool ID |
| `COGNITO_REGION` | Cognito region |
| `COGNITO_APP_CLIENT_ID` | Cognito App Client ID |

> **Never commit a real `.env` file.** It is in `.gitignore`.

---

## Database Migration

```bash
# Run from backend/ directory with venv active
alembic upgrade head
```

This creates all tables:
- `reminders`, `events`, `event_deadlines`
- `captures`, `memory_documents`
- `notification_deliveries`

---

## Run the Development Server

```bash
uvicorn app.main:app --reload --port 8000
```

API is available at:
- **Swagger UI:** http://localhost:8000/docs
- **Health check:** http://localhost:8000/health

---

## API Endpoints

### Reminders
| Method | Path | Description |
|---|---|---|
| `POST` | `/reminders` | Create reminder |
| `GET` | `/reminders` | List reminders (filter by status, type) |
| `GET` | `/reminders/{id}` | Get single reminder |
| `PATCH` | `/reminders/{id}` | Update reminder |
| `DELETE` | `/reminders/{id}` | Delete reminder |

### Events
| Method | Path | Description |
|---|---|---|
| `POST` | `/events` | Create event + deadlines |
| `GET` | `/events` | List events |
| `GET` | `/events/{id}` | Event detail with deadlines + capture counts |
| `PATCH` | `/events/{id}` | Update event |
| `DELETE` | `/events/{id}` | Delete event (cascades deadlines) |
| `POST` | `/events/{id}/deadlines` | Add deadline |
| `POST` | `/events/{id}/generate-summary` | Generate AI summary (strong model) |
| `GET` | `/events/{id}/summary` | Get existing summary |

### Captures
| Method | Path | Description |
|---|---|---|
| `POST` | `/captures/upload-url` | Get S3 pre-signed PUT URL |
| `POST` | `/captures` | Register capture after upload |
| `POST` | `/captures/note` | Save text note (no S3) |
| `POST` | `/captures/link` | Save URL link |
| `GET` | `/captures` | List captures |
| `GET` | `/captures/{id}/download-url` | Get S3 pre-signed GET URL |
| `PATCH` | `/captures/{id}` | Update AI results |
| `DELETE` | `/captures/{id}` | Delete (removes S3 object) |

### Memory
| Method | Path | Description |
|---|---|---|
| `GET` | `/memory` | List memory documents |
| `GET` | `/memory/search?q=` | Keyword search |
| `POST` | `/memory/ask` | RAG Q&A (strong model + grounded citations) |
| `GET` | `/memory/{id}` | Single memory document |

### AI
| Method | Path | Description |
|---|---|---|
| `POST` | `/ai/parse-reminder` | NLP → structured reminder (fast model) |
| `POST` | `/ai/extract-event` | Text → structured event (fast model) |

### Account, devices and event policy
| Method | Path | Description |
|---|---|---|
| `GET` | `/account/export` | All of the user's data as JSON |
| `DELETE` | `/account` | Delete everything: DB rows, S3 media, schedules, KB documents |
| `POST` | `/devices` | Register an FCM/APNs token for cloud push |
| `GET` | `/events/{id}/reminder-policy` | Preview the smart reminder plan for an event |
| `POST` | `/events/{id}/reminder-policy` | Create the confirmed reminders |

---

## Tests

```bash
pip install -r requirements-dev.txt
python -m pytest
```

Property-based tests (hypothesis) cover reminder parsing, fire-time scheduling,
quiet hours, event policy and conditional reminders.

---

## Connect Flutter to Backend

In the Flutter app, enable real backend mode:

```bash
flutter run --dart-define=USE_REAL_BACKEND=true --dart-define=BACKEND_URL=http://10.0.2.2:8000
```

| Device | `BACKEND_URL` |
|---|---|
| Android emulator | `http://10.0.2.2:8000` |
| iOS simulator | `http://localhost:8000` |
| Physical device (same Wi-Fi) | `http://192.168.x.x:8000` |
| Production | `https://api.your-domain.com` |

---

## Architecture Notes

- **Flutter → FastAPI:** all API calls use `ApiClient` with Cognito JWT header
- **FastAPI → Bedrock:** `bedrock_service.py` handles all LLM calls — Flutter never calls Bedrock directly
- **FastAPI → S3:** pre-signed URLs generated server-side; Flutter uploads directly to S3
- **Auth:** Cognito JWT validated in `auth.py` middleware on every protected route
- **AI principles enforced:**
  - AI suggests, user confirms — no silent reminder/event creation from AI output
  - Every memory answer grounded in stored captures (source citations required)
  - LLM never executes scheduling — FastAPI + EventBridge Scheduler does
- **Auth fails closed:** if Cognito is not configured every request is refused (503). For local
  development only, set `ALLOW_INSECURE_DEV_AUTH=true` to accept unverified tokens.
- **Guardrails:** set `GUARDRAIL_ID` / `GUARDRAIL_VERSION` to apply a Bedrock Guardrail to every model call.
