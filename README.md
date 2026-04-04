# SmartWallet AI

AI-assisted personal finance: spending summaries, impulse checks, subscription heuristics, budgets, Plaid sync, cash-flow hints, and a conversational **financial assistant** chat.  
Stack: **FastAPI** (Python) + **Flutter** (mobile + web).

## Repository layout

| Path | Role |
|------|------|
| `backend/` | REST API (`/api/...`), SQLite by default, optional Plaid + Gemini |
| `frontend/flutter_app/` | Flutter UI |

## Prerequisites

- **Python** 3.11+ (3.13 works with the listed dependencies)
- **Flutter** SDK (for the app)
- Optional: **Gemini API** key for full AI text generation  
- Optional: **Plaid** credentials for live bank data (otherwise mock data can be used)

---

## Backend

### Install

```powershell
cd backend
python -m pip install -r requirements.txt
```

### Run (Windows)

`uvicorn` is often not on `PATH`; use the module form:

```powershell
cd backend
python -m uvicorn app.main:app --reload --host 127.0.0.1 --port 8000
```

- API root: <http://127.0.0.1:8000/>  
- Swagger UI: <http://127.0.0.1:8000/docs>

### Environment variables

Create a `.env` file in `backend/` (optional values shown):

| Variable | Purpose |
|----------|---------|
| `DATABASE_URL` | Default `sqlite:///./smartwallet.db` |
| `GEMINI_API_KEY` | Gemini features (recommendations, impulse copy, chat, etc.) |
| `GEMINI_MODEL` | Optional model override |
| `USE_MOCK_DATA` | `true`/`false` — use mock transactions when DB is empty (default `true`) |
| `AUTH_ENABLED` | `true` requires JWT on protected routes; default `false` (demo user) |
| `JWT_SECRET` | Required when issuing/validating tokens |
| `ALLOW_ANONYMOUS_DEMO` | When `AUTH_ENABLED=true`, allow no JWT and fall back to user id `1` (default `true` — turn off in production) |
| `GOOGLE_CLIENT_ID` / `GOOGLE_CLIENT_IDS` | For `/api/auth/google` |
| `PLAID_ENV`, `PLAID_CLIENT_ID`, `PLAID_SECRET` | Plaid Link + sync |
| `PLAID_WEBHOOK_URL` | Optional default webhook attached to new Link tokens |

### Demo user

On startup the API seeds **user id `1`** (`demo@smartwallet.ai`) when missing. This matches the Flutter client’s default `userId`.

### Database notes

SQLAlchemy `create_all` does not migrate existing SQLite files. After schema changes, delete `backend/smartwallet.db` if you hit table/column errors.

### CORS (Flutter Web)

The API allows browser requests from `localhost` / `127.0.0.1` on any port so Flutter Web (a different port than `:8000`) can call the API. For other hosts, extend `main.py` CORS settings.

---

## Frontend (Flutter)

### Install & run

```powershell
cd frontend/flutter_app
flutter pub get
flutter run
```

- **Android emulator**: API base URL defaults to `http://10.0.2.2:8000` (host machine).
- **Web / desktop**: defaults to `http://localhost:8000`.
- **Physical device** or custom host: pass your PC’s LAN URL:

```powershell
flutter run --dart-define=SMARTWALLET_API_URL=http://192.168.1.10:8000
```

### Troubleshooting

| Symptom | What to try |
|---------|-------------|
| `ClientException: Failed to fetch` (web) | Ensure the API is running; CORS is configured for localhost in `backend/app/main.py`. |
| Android device cannot reach API | Use `SMARTWALLET_API_URL` with your computer’s LAN IP and open the firewall for port 8000. |
| Chat or API returns 401 | Set `AUTH_ENABLED=false`, or keep `ALLOW_ANONYMOUS_DEMO=true`, or send a valid `Authorization: Bearer` token. |

---

## API overview (non-exhaustive)

| Prefix | Examples |
|--------|----------|
| `/api/auth/` | `me`, register, login, Google token exchange |
| `/api/chat/` | Conversations + messages (financial assistant) |
| `/api/transactions/` | Summary + balances |
| `/api/impulse/` | Impulse purchase check |
| `/api/subscriptions/` | Heuristic subscription scan |
| `/api/plaid/` | Link token, exchange, sync |
| `/api/budgets/`, `/api/alerts/`, `/api/cashflow/`, `/api/recommendations/` | Plan & insights |

---

## License

Use and modify per your team or hackathon rules.
