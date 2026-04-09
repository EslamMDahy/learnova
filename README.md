# Learnova

Learnova is a full-stack AI-powered Learning Management System (LMS) built with **Flutter** (web/mobile frontend) and **FastAPI** (Python backend).

---

## Project Structure

```
learnova/
├── flutter/          # Flutter frontend (web + mobile)
└── backend/          # FastAPI Python backend
```

---

## Flutter Frontend

### Stack

| Concern | Package |
|---|---|
| State management | `flutter_riverpod ^2.5.1` |
| Navigation | `go_router ^13.2.0` |
| HTTP client | `dio ^5.4.0` |
| File picking | `file_picker ^10.3.10` |
| URL launching | `url_launcher ^6.3.0` |
| Value equality | `equatable ^2.0.5` |

### Architecture

The app follows a **feature-first Clean Architecture** layout:

```
flutter/lib/
├── core/           # Cross-cutting concerns (routing, theme, network, storage, error)
├── features/
│   ├── auth/       # Login, register, token management
│   ├── instructor/ # Instructor screens and widgets
│   ├── admin/      # Admin panel views
│   ├── settings/   # User settings
│   └── data/       # Shared models and providers
└── shared/         # Reusable widgets and utilities
```

Each feature is split into `data/`, `domain/`, and `presentation/` layers.

### Running the Flutter App

```bash
cd flutter
flutter pub get
flutter run -d chrome          # web
flutter run                    # connected device
```

### Fonts

Custom fonts **Inter** and **Lexend** are bundled under `flutter/assets/fonts/`.

---

## Backend (FastAPI)

### Stack

- **Python** with **FastAPI**
- SQLAlchemy ORM
- CORS configured for `localhost:5173` (local dev)

### Feature Routers

| Router | Domain |
|---|---|
| `auth` | Authentication & sessions |
| `courses` | Course management |
| `learningOutcomes` | Learning outcome definitions |
| `modules` | Course modules |
| `materials` | Course materials (files, videos) |
| `topics` | Topic taxonomy |
| `questions` | Question bank |
| `organizations` | Multi-tenant organizations |
| `settings` | App/user settings |

### Running the Backend

```bash
cd backend
pip install -r requirements.txt
uvicorn main:app --reload
```

The API will be available at `http://localhost:8000`. Interactive docs at `http://localhost:8000/docs`.

---

## Key Features

- **Multi-role platform** — Student, Instructor, Admin, Organization owner
- **AI-powered** — AI chat per course, AI question generation, adaptive learning recommendations, weak-point detection
- **Monetization** — Credit wallet, transactions, subscription plans
- **Multi-tenancy** — Organizations with members and invitation flows
- **Module reuse** — Copy modules across courses via the module selector sheet

---

## Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/your-feature`
3. Commit your changes
4. Open a pull request targeting `main`
