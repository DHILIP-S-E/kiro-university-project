# Implementation Plan — Personal Memory OS Web Portal

## Architecture Decisions

**Framework:** Vite + React 18 + TypeScript — fastest iteration, native ESM, no CRA overhead.

**Styling:** Tailwind CSS v3 with a custom dark-theme config (no component library dependency — keeps bundle lean and lets us own the exact design tokens).

**Auth:** `amazon-cognito-identity-js` (direct, lightweight) rather than full AWS Amplify — we only need token management, not the full Amplify SDK.

**API client:** axios with a single interceptor that attaches the Cognito `id_token` as Bearer. The token is refreshed transparently before each request using the Cognito session.

**State management:** React Context + `useReducer` for auth state; React Query (`@tanstack/react-query`) for all server state — avoids prop drilling, handles caching/refetch without a separate store.

**Routing:** React Router v6 with a `<ProtectedRoute>` wrapper.

**File organisation:** mirrors the Flutter `features/` structure — `src/features/<domain>/` per domain.

---

## Backend Schema Reference (derived from actual code)

### Reminder (GET /reminders, POST /reminders, PATCH /reminders/:id)
```ts
interface Reminder {
  id: string;
  user_id: string;
  title: string;
  description: string | null;
  reminder_type: 'time' | 'deadline' | 'recurring' | 'follow-up' | 'multi-stage';
  scheduled_at: string | null;   // ISO 8601
  timezone: string;
  priority: 'low' | 'medium' | 'high' | 'critical';
  status: 'active' | 'completed' | 'snoozed' | 'cancelled';
  alarm_enabled: boolean;
  notification_enabled: boolean;
  recurrence_rule: string | null;
  source: 'manual' | 'ai' | 'event';
  context_id: string | null;
  depends_on_id: string | null;
  offsets: string[];
  created_at: string;
  updated_at: string;
}
```

### Event (GET /events, POST /events, PATCH /events/:id)
```ts
interface EventDeadline {
  id: string;
  event_id: string;
  user_id: string;
  title: string;
  deadline_type: string;
  deadline_at: string;
  status: string;
  created_at: string;
}
interface Event {
  id: string;
  user_id: string;
  title: string;
  description: string | null;
  event_type: 'hackathon' | 'conference' | 'workshop' | 'webinar' | 'meetup' | 'meeting' | 'appointment' | 'deadline' | 'custom';
  start_at: string;
  end_at: string | null;
  timezone: string;
  location: string | null;
  is_virtual: boolean;
  event_url: string | null;
  organizer: string | null;
  registration_url: string | null;
  status: 'draft' | 'registered' | 'upcoming' | 'active' | 'attended' | 'completed';
  summary_id: string | null;
  photo_count: number;
  voice_note_count: number;
  document_count: number;
  deadlines: EventDeadline[];
  created_at: string;
  updated_at: string;
}
```

### Capture (GET /captures, POST /captures, POST /captures/note, POST /captures/link)
```ts
interface AIResult {
  summary: string;
  topics: string[];
  key_points: string[];
  actions: string[];
}
interface Capture {
  id: string;
  user_id: string;
  event_id: string | null;
  capture_type: 'photo' | 'voice' | 'note' | 'document' | 'link';
  storage_key: string | null;
  mime_type: string | null;
  duration: number | null;
  transcription: string | null;
  content: string | null;
  processing_status: 'uploaded' | 'queued' | 'processing' | 'processed' | 'failed';
  ai_result: AIResult | null;
  created_at: string;
  updated_at: string;
}
```

### MemoryDocument (GET /memory, GET /memory/search?q=, POST /memory/ask)
```ts
interface MemoryDocument {
  id: string;
  user_id: string;
  event_id: string | null;
  event_title: string | null;
  overview: string | null;
  key_topics: string[];
  key_takeaways: string[];
  things_learned: string[];
  important_people: string[];
  resources: string[];
  links: string[];
  action_items: string[];
  deadlines: string[];
  decisions: string[];
  event_date: string;
  created_at: string;
  updated_at: string;
}
```

---

## Integration Risks

1. **CORS** — backend sets `allow_origins=["*"]` in dev; in production this must be tightened to the web portal origin.
2. **Token type** — backend `validate_claims` accepts both `access` and `id` tokens. Use `id_token` (has `aud` = client ID). Using `access_token` needs `client_id` claim — safer to always send `id_token`.
3. **S3 upload flow** — the web portal must replicate the 3-step capture flow: POST `/captures/upload-url` → PUT presigned URL (browser `fetch`, no auth header) → POST `/captures` to register. The presigned PUT must set the correct `Content-Type` or S3 rejects it.
4. **Datetime format** — backend returns ISO strings with timezone info (e.g. `2024-01-15T09:00:00+00:00`). Use `date-fns` or `dayjs` for display — do not rely on `new Date()` naively.
5. **JSON fields** — `ai_topics`, `ai_key_points`, `ai_actions` in Capture are already deserialized by `to_dict()` when fetched; same for all list fields in MemoryDocument. No client-side `JSON.parse()` needed.
6. **Capture `ai_result`** — this field is `null` if `ai_summary` is null (backend logic). Check for null before accessing.

---

## File Creation Order

Order matters to avoid import errors — lower layers first.

1. `web/` scaffold (package.json, vite.config.ts, tsconfig.json, tailwind.config.js, index.html)
2. `src/env.d.ts`, `.env.example`
3. `src/lib/colors.ts` (design tokens)
4. `src/types/` — all TypeScript interfaces
5. `src/lib/apiClient.ts` — axios instance
6. `src/lib/cognitoClient.ts` — Cognito auth helpers
7. `src/features/auth/` — AuthContext + hooks
8. `src/features/auth/screens/` — SignIn, SignUp, ForgotPassword
9. `src/components/` — shared: Layout, Sidebar, ProtectedRoute, Button, Badge, Card
10. `src/features/reminders/` — API + screens
11. `src/features/events/` — API + screens (EventList, EventDetail)
12. `src/features/capture/` — API + screen
13. `src/features/memory/` — API + screen
14. `src/features/settings/` — screen
15. `src/features/dashboard/` — screen (depends on all API layers)
16. `src/App.tsx`, `src/main.tsx` — router + providers (last, glues everything together)

---

## Implementation Plan

- [ ] 1. Scaffold the Vite + React + TypeScript project at `web/`.
      Create `web/package.json` with exact pinned versions:
      - react@18.3.1, react-dom@18.3.1, react-router-dom@6.26.2
      - @tanstack/react-query@5.59.0, axios@1.7.7
      - amazon-cognito-identity-js@6.3.12
      - date-fns@4.1.0
      - tailwindcss@3.4.14, autoprefixer@10.4.20, postcss@8.4.47
      - @types/react@18.3.12, @types/react-dom@18.3.1, typescript@5.6.3, vite@5.4.10
      Also create: `vite.config.ts`, `tsconfig.json`, `postcss.config.js`,
      `tailwind.config.js` (with dark-theme tokens), `index.html`.
      Files: web/package.json, web/vite.config.ts, web/tsconfig.json,
             web/postcss.config.js, web/tailwind.config.js, web/index.html
      Verify: `cd web && npm install` completes without errors; `npm run build` produces `dist/`.

- [ ] 2. Create design tokens and environment configuration.
      `src/lib/colors.ts` exports a `colors` object with background=#0F0F0F,
      surface=#1A1A1A, card=#242424, accent=#6366F1, accentHover=#4F46E5,
      textPrimary=#F9FAFB, textSecondary=#9CA3AF, textMuted=#6B7280,
      success=#22C55E, warning=#EAB308, error=#EF4444, border=#2D2D2D.
      `src/env.d.ts` declares `ImportMetaEnv` with VITE_BACKEND_URL,
      VITE_COGNITO_USER_POOL_ID, VITE_COGNITO_CLIENT_ID, VITE_COGNITO_REGION.
      `.env.example` with prefilled Cognito values:
        VITE_COGNITO_USER_POOL_ID=ap-south-1_lCFBN7JwX
        VITE_COGNITO_CLIENT_ID=qvh6nlqk5tt5oirrgvr7q5t47
        VITE_COGNITO_REGION=ap-south-1
        VITE_BACKEND_URL=http://localhost:8000
      Files: web/src/lib/colors.ts, web/src/env.d.ts, web/.env.example
      Verify: `npm run build` — TypeScript sees VITE_ env vars without error.

- [ ] 3. Define all TypeScript interfaces matching backend Pydantic/`to_dict()` shapes.
      Create `src/types/index.ts` exporting:
        Reminder, ReminderCreate, ReminderUpdate,
        Event, EventDeadline, EventCreate, EventUpdate, DeadlineIn,
        Capture, AIResult, UploadUrlRequest, UploadUrlResponse, RegisterCaptureRequest,
        MemoryDocument, AskRequest, AskResponse (shape from answer_memory_question — question, answer, sources array),
        ParseReminderResponse, ExtractEventResponse.
      All field names must exactly match backend `to_dict()` output.
      Files: web/src/types/index.ts
      Verify: `npm run build` — no TypeScript errors in types file.

- [ ] 4. Build the API client layer.
      `src/lib/cognitoClient.ts`: wraps `amazon-cognito-identity-js` —
        exports `signIn(email, password)`, `signUp(email, password)`, `confirmSignUp(email, code)`,
        `forgotPassword(email)`, `confirmForgotPassword(email, code, newPassword)`,
        `signOut()`, `getIdToken(): Promise<string|null>`, `getCurrentUser()`.
        Pool config uses `import.meta.env.VITE_COGNITO_USER_POOL_ID` and `VITE_COGNITO_CLIENT_ID`.
      `src/lib/apiClient.ts`: axios instance with `baseURL = import.meta.env.VITE_BACKEND_URL`.
        Request interceptor calls `getIdToken()` and sets `Authorization: Bearer <token>`.
        Response interceptor catches 401 and calls `signOut()` + redirects to `/signin`.
      Files: web/src/lib/cognitoClient.ts, web/src/lib/apiClient.ts
      Verify: `npm run build` — no TypeScript errors; interceptor types resolve cleanly.

- [ ] 5. Build per-domain API service modules.
      Each file exports typed async functions using `apiClient`:
      - `src/features/reminders/remindersApi.ts`:
          listReminders(params?), getReminder(id), createReminder(body), updateReminder(id, body), deleteReminder(id)
      - `src/features/events/eventsApi.ts`:
          listEvents(params?), getEvent(id), createEvent(body), updateEvent(id, body), deleteEvent(id),
          addDeadline(eventId, body), previewReminderPolicy(eventId), applyReminderPolicy(eventId),
          generateSummary(eventId), getEventSummary(eventId)
      - `src/features/capture/capturesApi.ts`:
          getUploadUrl(body), registerCapture(body), createTextNote(body), saveLink(body),
          listCaptures(params?), getCapture(id), getDownloadUrl(id), deleteCapture(id)
          + `uploadFileToS3(uploadUrl, file, contentType)` — plain `fetch` PUT, no auth header
      - `src/features/memory/memoryApi.ts`:
          listMemory(), searchMemory(q), askMemory(question), getMemoryDocument(id)
      - `src/features/ai/aiApi.ts`:
          parseReminder(text, timezone?), extractEvent(text)
      Files: web/src/features/reminders/remindersApi.ts,
             web/src/features/events/eventsApi.ts,
             web/src/features/capture/capturesApi.ts,
             web/src/features/memory/memoryApi.ts,
             web/src/features/ai/aiApi.ts
      Verify: `npm run build` — all API modules compile with no type errors.

- [ ] 6. Build the AuthContext and auth guard.
      `src/features/auth/AuthContext.tsx`: React context holding
        `{ user: CognitoUser|null, isLoading: boolean, signIn, signUp, confirmSignUp, signOut, forgotPassword, confirmForgotPassword }`.
        On mount, calls `getCurrentUser()` to rehydrate session.
      `src/components/ProtectedRoute.tsx`: renders `<Navigate to="/signin" />` if `!user && !isLoading`.
      Files: web/src/features/auth/AuthContext.tsx,
             web/src/components/ProtectedRoute.tsx
      Verify: `npm run build` — no TypeScript errors.

- [ ] 7. Build auth screens.
      All screens: dark background (#0F0F0F), centered card (#1A1A1A), indigo accent buttons.
      - `src/features/auth/screens/SignInScreen.tsx`: email + password form → `signIn()`.
          Shows error banner on failure. Links to /signup and /forgot-password.
      - `src/features/auth/screens/SignUpScreen.tsx`: email + password + confirm-password form → `signUp()`.
          On success shows confirmation code field → `confirmSignUp()` → redirect to /signin.
      - `src/features/auth/screens/ForgotPasswordScreen.tsx`: two-step —
          step 1 email input → `forgotPassword()`;
          step 2 code + new password → `confirmForgotPassword()` → redirect to /signin.
      Files: web/src/features/auth/screens/SignInScreen.tsx,
             web/src/features/auth/screens/SignUpScreen.tsx,
             web/src/features/auth/screens/ForgotPasswordScreen.tsx
      Verify: `npm run build` — no errors; screens render in browser (npm run dev).

- [ ] 8. Build shared layout components.
      `src/components/Layout.tsx`: full-height flex container with a fixed left sidebar + scrollable main area.
        Background: #0F0F0F. Sidebar: #1A1A1A, 240px wide.
        Nav items: Dashboard, Reminders, Events, Capture, Memory, Settings — with active-state indigo highlight.
        Top bar shows user email + Sign Out button.
      `src/components/ui/Button.tsx`: variant=primary(indigo filled)|secondary(surface outlined)|ghost|danger.
      `src/components/ui/Badge.tsx`: status badge with color map for reminder/event/capture statuses.
      `src/components/ui/Card.tsx`: surface (#1A1A1A or #242424) rounded-xl p-4 wrapper.
      `src/components/ui/EmptyState.tsx`: icon + title + subtitle + optional action button.
      `src/components/ui/LoadingSpinner.tsx`: indigo spinner.
      Files: web/src/components/Layout.tsx,
             web/src/components/ui/Button.tsx,
             web/src/components/ui/Badge.tsx,
             web/src/components/ui/Card.tsx,
             web/src/components/ui/EmptyState.tsx,
             web/src/components/ui/LoadingSpinner.tsx
      Verify: `npm run build` — no errors.

- [ ] 9. Build the Dashboard screen.
      `src/features/dashboard/DashboardScreen.tsx`: uses React Query to fetch
        - active reminders (filter `status=active`) → shows overdue ones at top in error-red
        - upcoming events (sorted by `start_at`) → next 3 events as cards
        - recent captures (last 5) → small list
      Summary row: total active reminders count, upcoming events count, captures this week.
      Each section has a "View all →" link to the relevant page.
      Files: web/src/features/dashboard/DashboardScreen.tsx
      Verify: `npm run build`; screen visible at `/` after sign-in with real backend data.

- [ ] 10. Build the Reminders feature.
       `src/features/reminders/RemindersScreen.tsx`:
         - List view with filter tabs: All / Active / Completed / Overdue
         - Each row: title, priority badge, scheduled_at, status badge, actions (complete/delete)
         - "New Reminder" button opens `CreateReminderModal`
         - "Parse with AI" button: text input → POST /ai/parse-reminder → pre-fills the form (user confirms before saving, per R1.9)
       `src/features/reminders/CreateReminderModal.tsx`:
         - Fields: title (required), description, reminder_type select, scheduled_at datetime-local,
           timezone, priority select, alarm_enabled toggle, recurrence_rule text, offsets (comma-separated)
         - On submit: POST /reminders; closes on success
       Files: web/src/features/reminders/RemindersScreen.tsx,
              web/src/features/reminders/CreateReminderModal.tsx
       Verify: `npm run build`; can list, create, complete, and delete a reminder against real backend.

- [ ] 11. Build the Events feature.
       `src/features/events/EventsScreen.tsx`:
         - List of events sorted by start_at desc; filter by status
         - Event card: title, event_type badge, start_at, location/virtual indicator, capture counts
         - "New Event" button opens `CreateEventModal`
         - "Extract from text" button: textarea → POST /ai/extract-event → pre-fills form
       `src/features/events/CreateEventModal.tsx`:
         - Fields: title, description, event_type select, start_at, end_at, timezone,
           location, is_virtual toggle, event_url, organizer, registration_url
         - Deadlines section: add deadline rows (title, deadline_type, deadline_at)
         - On submit: POST /events
       `src/features/events/EventDetailScreen.tsx` (route `/events/:id`):
         - Full event info header
         - Tabs: Overview | Captures | Deadlines | Reminders | Summary
         - Overview tab: all fields, edit inline via PATCH
         - Captures tab: list captures for event_id; link to add new capture
         - Deadlines tab: list deadlines + "Add Deadline" form
         - Reminders tab: "Preview Policy" button → GET /events/:id/reminder-policy → shows list with checkboxes → "Apply" button → POST /events/:id/reminder-policy
         - Summary tab: if summary_id exists show summary; else "Generate Summary" button → POST /events/:id/generate-summary
       Files: web/src/features/events/EventsScreen.tsx,
              web/src/features/events/CreateEventModal.tsx,
              web/src/features/events/EventDetailScreen.tsx
       Verify: `npm run build`; can create event, view detail, generate summary with real backend.

- [ ] 12. Build the Capture feature.
       `src/features/capture/CaptureScreen.tsx`:
         - Four capture mode tabs: Text Note | Link | Photo | Document
         - Text Note: textarea → POST /captures/note
         - Link: URL input → POST /captures/link
         - Photo/Document: file input → 3-step S3 flow (POST upload-url → PUT S3 → POST register)
           Show progress indicator during upload; status badge for processing_status.
         - Optional event_id selector (dropdown of user's events) to associate capture
         - Recent captures list (last 10) with processing status badges
         - Captures with `ai_result` show expandable AI summary card
       Files: web/src/features/capture/CaptureScreen.tsx
       Verify: `npm run build`; text note and link capture work against real backend; photo upload reaches S3.

- [ ] 13. Build the Memory / AI Search feature.
       `src/features/memory/MemoryScreen.tsx`:
         - Top: AI Ask bar — text input + submit → POST /memory/ask → shows answer + sources (cited event titles, per R4.5)
         - Below: keyword search input → GET /memory/search?q= → shows matching MemoryDocuments
         - Below: full memory list (GET /memory) as cards
         - Memory document card: event_title, event_date, overview snippet, key_topics badges,
           "View full" expands inline to show all fields (takeaways, people, action items, decisions, resources)
       Files: web/src/features/memory/MemoryScreen.tsx
       Verify: `npm run build`; search and AI ask work against real backend with grounded source display.

- [ ] 14. Build the Settings screen.
       `src/features/settings/SettingsScreen.tsx`:
         - Account section: display user email (from Cognito)
         - Data section: "Export All Data" button → GET /account/export → triggers JSON download
         - Danger zone: "Delete Account" button → confirmation dialog → DELETE /account → sign out
       Files: web/src/features/settings/SettingsScreen.tsx
       Verify: `npm run build`; export downloads a JSON file; delete account flow completes.

- [ ] 15. Wire the router and providers — final integration.
       `src/App.tsx`: wraps everything in `<QueryClientProvider>`, `<AuthProvider>`, `<BrowserRouter>`.
         Route tree:
           /signin → SignInScreen (public)
           /signup → SignUpScreen (public)
           /forgot-password → ForgotPasswordScreen (public)
           / → ProtectedRoute → Layout → DashboardScreen
           /reminders → ProtectedRoute → Layout → RemindersScreen
           /events → ProtectedRoute → Layout → EventsScreen
           /events/:id → ProtectedRoute → Layout → EventDetailScreen
           /capture → ProtectedRoute → Layout → CaptureScreen
           /memory → ProtectedRoute → Layout → MemoryScreen
           /settings → ProtectedRoute → Layout → SettingsScreen
           * → Navigate to /
       `src/main.tsx`: ReactDOM.createRoot + StrictMode.
       Files: web/src/App.tsx, web/src/main.tsx
       Verify: `npm run build` completes with 0 errors; `npm run dev` loads the app; full sign-in → dashboard flow works end-to-end with the real backend at VITE_BACKEND_URL.
