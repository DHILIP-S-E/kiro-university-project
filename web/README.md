# Personal Memory OS — Web Portal

A React 18 + TypeScript SPA that gives users browser-based access to all Personal Memory OS features. Built with Vite, Tailwind CSS (dark theme), email/password login against the backend's own `/auth` API, and the same FastAPI backend that powers the mobile app.

---

## Prerequisites

- **Node.js 20+** (`node --version` should print `v20.x.x` or higher)
- **npm 10+** (bundled with Node 20)

---

## Setup

1. Copy the environment template and fill in your backend URL:

   ```bash
   cp .env.example .env
   ```

2. Open `.env` and set `VITE_BACKEND_URL` to wherever your backend is running:

   ```env
   VITE_BACKEND_URL=http://localhost:8000   # local dev
   # VITE_BACKEND_URL=https://api.yourdomain.com  # deployed backend
   ```

   That is the only setting. Sign-in uses the backend's `/auth/login`; there is no Cognito.

---

## Development

```bash
npm install
npm run dev
```

The dev server starts at **http://localhost:3000**. Hot-module replacement is enabled — changes to any `.tsx` or `.ts` file reload instantly.

---

## Production Build

```bash
npm run build
```

Output lands in `dist/`. Serve it with any static host (S3 + CloudFront, Nginx, etc.). Zero TypeScript errors = clean build.

---

## Pages

| Route | Screen | What it does |
|---|---|---|
| `/signin` | Sign In | Email + password login. Links to Sign Up. |
| `/signup` | Sign Up | Register a new account. Shows a confirmation code field after submission; enter the code sent to your email to activate the account. |
| `/forgot-password` | Forgot Password | Two-step reset: enter email to receive a code, then enter the code + new password. |
| `/` | Dashboard | At-a-glance overview — overdue reminders (highlighted in red), next 3 upcoming events, 5 most recent captures, and summary counts. Each section links to its full page. |
| `/reminders` | Reminders | Full reminder list with filter tabs (All / Active / Completed / Overdue). Create reminders manually or paste free text into the **Parse with AI** input to have the backend extract a structured reminder — you confirm the result before it is saved. |
| `/events` | Events | Event list sorted by date with status filters. Create events manually or paste a block of text into **Extract from text** to auto-fill the form. |
| `/events/:id` | Event Detail | Tabbed detail view: Overview (edit inline), Captures (attachments for that event), Deadlines, Reminders (preview and apply an AI-suggested reminder policy), Summary (generate or view the AI-written event summary). |
| `/capture` | Capture | Four-tab capture interface: Text Note, Link, Photo, and Document. Associate a capture with any of your events via the event selector. Recent captures are listed below with processing-status badges; captures with AI results show an expandable summary card. |
| `/memory` | Memory | AI-powered personal knowledge base. Ask a question in natural language (answered server-side by Bedrock with source grounding), keyword-search your memory documents, or browse the full list. Each memory document card expands to show key topics, takeaways, action items, people, decisions, and resources. |
| `/settings` | Settings | Account info (your email), export all data as JSON, and a danger-zone account deletion flow. |

---

## S3 Capture Flow (Photo & Document uploads)

Photo and Document captures follow a 3-step flow to upload directly to S3 without routing binary data through the backend:

```
Step 1 — Request a pre-signed URL
  POST /captures/upload-url
  Body: { filename, content_type, capture_type, event_id? }
  Response: { upload_url, storage_key }

Step 2 — Upload directly to S3
  PUT <upload_url>  (plain fetch — no Authorization header)
  Body: raw file bytes
  Content-Type: <content_type from step 1>

Step 3 — Register the capture
  POST /captures
  Body: { storage_key, capture_type, mime_type, event_id? }
  Response: Capture record — processing_status starts as "queued"
```

After step 3, the backend enqueues the file for AI processing (transcription, summarisation, topic extraction). Poll or refresh the captures list — `processing_status` moves through `queued → processing → processed`. The `ai_result` field populates once processing completes.

---

## AI Features

All AI calls happen **server-side** (Lambda → Amazon Bedrock). The web portal never calls Bedrock directly.

| Feature | How it works |
|---|---|
| Parse reminder from text | `POST /ai/parse-reminder` — backend extracts title, scheduled time, priority, and type from free text. The portal pre-fills the form; the user reviews and confirms before the reminder is saved. |
| Extract event from text | `POST /ai/extract-event` — backend extracts event fields from a pasted block of text. Same confirm-before-save flow. |
| Event summary | `POST /events/:id/generate-summary` — backend synthesises a structured summary from all captures attached to that event. |
| Reminder policy | `GET /events/:id/reminder-policy` returns a suggested set of reminders for an event's deadlines. `POST /events/:id/reminder-policy` applies the ones you select. |
| Memory / Ask | `POST /memory/ask` — backend performs RAG over your indexed memory (Bedrock Knowledge Bases + OpenSearch Serverless) and returns an answer with source citations. |
| Capture AI result | After a file is processed, the backend writes `ai_result` (summary, topics, key points, actions) to the capture record. |

---

## Project Structure

```
web/
├── src/
│   ├── features/
│   │   ├── auth/           # AuthContext, SignIn, SignUp, ForgotPassword
│   │   ├── dashboard/      # DashboardScreen
│   │   ├── reminders/      # RemindersScreen, CreateReminderModal, remindersApi
│   │   ├── events/         # EventsScreen, EventDetailScreen, CreateEventModal, eventsApi
│   │   ├── capture/        # CaptureScreen, capturesApi
│   │   ├── memory/         # MemoryScreen, memoryApi
│   │   ├── settings/       # SettingsScreen
│   │   └── ai/             # aiApi (parse-reminder, extract-event)
│   ├── components/
│   │   ├── Layout.tsx      # Sidebar + top bar shell
│   │   ├── ProtectedRoute.tsx
│   │   └── ui/             # Button, Badge, Card, EmptyState, LoadingSpinner
│   ├── lib/
│   │   ├── apiClient.ts    # axios instance that attaches the access token (refreshed automatically)
│   │   ├── authClient.ts
│   │   └── colors.ts       # design tokens (never hard-code hex values)
│   ├── types/
│   │   └── index.ts        # all TypeScript interfaces
│   ├── App.tsx             # router + providers
│   └── main.tsx
├── .env.example            # committed — safe (no secrets)
├── .env                    # NOT committed — add your VITE_BACKEND_URL here
├── index.html
├── vite.config.ts
├── tailwind.config.js
└── tsconfig.json
```

---

## Notes

- `.env` is git-ignored. Never commit real credentials.
- The short-lived access token is sent as `Authorization: Bearer` on every API request and refreshed quietly with the refresh token. Both live in `localStorage`, as is usual for a single-page app, so keep the site free of untrusted scripts.
- The backend only accepts browser calls from the origin in its `CORS_ORIGINS` setting (set to this site's address in production).
