# Pupero Authentication Suite

A compact, production‑minded demo stack for authentication with:
- Login (FastAPI backend) — JWT auth, Argon2 password hashing, 2FA via TOTP, profile updates, account deletion
- FlaskProject (Flask frontend) — Simple UI for register/login/profile and 2FA management, talking to the backend
- CreateDB (SQLModel utility) — One‑off CLI to create database and tables

This repository is intended to be easy to run locally and straightforward to harden for production.


## Repository layout
- CreateDB/
  - main.py — CLI for creating database and tables
  - models.py — SQLModel models used to create the DB schema
  - schemas.py — Pydantic schemas mirroring the backend request/response models (for reference)
  - requirements.txt — dependencies for the CLI
- Login/
  - app/ — FastAPI application code
    - main.py — API endpoints
    - auth.py — password hashing (Argon2), JWT helpers, TOTP helpers
    - crud.py — user DB operations via SQLModel
    - database.py — SQLModel engine and session dependency
    - deps.py — request dependencies (auth)
    - models.py — SQLModel models (User)
    - schemas.py — Pydantic models (request/response)
    - config.py — strongly‑typed configuration via environment variables
  - requirements.txt — backend dependencies
- FlaskProject/
  - app.py — Flask UI that calls the backend
  - config.py — loads environment variables
  - templates/ — HTML templates
  - requirements.txt — frontend dependencies


## Quickstart

Prerequisites
- Python 3.11+
- A MariaDB/MySQL instance you can connect to

Create a virtualenv
- python -m venv .venv
- source .venv/bin/activate  (Linux/macOS)  or  .venv\Scripts\activate (Windows)

1) Create the database and tables
- Install CreateDB requirements: pip install -r CreateDB/requirements.txt
- Run the CLI (examples):
  - With interactive password prompt:
    - python CreateDB/main.py --user root --host 127.0.0.1 --port 3306 --database pupero --create-database
  - With env var DB_PASSWORD:
    - export DB_PASSWORD='your-db-password'
    - python CreateDB/main.py --user root --host 127.0.0.1 --port 3306 --database pupero --create-database
  - With explicit password flag (least secure; prefer prompt/env):
    - python CreateDB/main.py --user root --password 'your-db-password' --host 127.0.0.1 --port 3306 --database pupero --create-database

Notes
- Credentials in the SQLAlchemy URL are URL‑encoded for safety (special characters allowed).
- --create-database ensures the database exists with utf8mb4.

2) Configure the backend (Login)
- Install requirements: pip install -r Login/requirements.txt
- Create Login/app/.env with at least:
  - DATABASE_URL=mariadb+mariadbconnector://USER:PASSWORD@127.0.0.1:3306/pupero
  - JWT_SECRET_KEY=please-change-me
  - JWT_ACCESS_TOKEN_EXPIRE_MINUTES=30
  - JWT_REFRESH_TOKEN_EXPIRE_MINUTES=1440
  - REMEMBER_ME_DAYS=30
  - ANTI_PHISHING_PHRASE_DEFAULT=Welcome to Pupero
  - SQL_ECHO=false  # set true only for local debugging
- Start the API:
  - uvicorn app.main:app --reload --port 8000 --app-dir Login

3) Configure the frontend (FlaskProject)
- Install requirements: pip install -r FlaskProject/requirements.txt
- Create FlaskProject/.env with at least:
  - BACKEND_URL=http://127.0.0.1:8000
  - SECRET_KEY=please-change-me
  - REMEMBER_ME_DAYS=30
  - SECURE_COOKIES=false  # set true in production with HTTPS
  - SESSION_COOKIE_SAMESITE=Lax
- Run the Flask app:
  - cd FlaskProject
  - FLASK_APP=app.py FLASK_ENV=development flask run --port 5000
- Open http://127.0.0.1:5000


## What’s implemented

Backend (Login/FastAPI)
- Register with unique email (optional unique username).
- Login with username or email + password.
- Argon2 password hashing via passlib.
- Optional TOTP 2FA enable/confirm/disable.
- JWT access + refresh tokens (HS256); configurable lifetimes.
- Refresh endpoint (rotates refresh token in example code).
- Profile read and update (phrase, username, email change with password check, password change).
- GDPR‑style account deletion (requires confirmation, password, and TOTP if enabled).
- Basic JSON logging middleware with latency, path, and (if present) user email from token.

Frontend (Flask)
- Register/Login/Profile pages.
- Stores access token in an HttpOnly cookie and forwards it as Bearer to backend.
- SameSite and Secure cookie flags are configurable via env.
- "Remember me" controls token lifetime and cookie persistence.

CreateDB (utility)
- Creates DB and tables for the SQLModel models; can ensure database exists (utf8mb4) before creating tables.
- Reads DB password from CLI flag, DB_PASSWORD env var, or secure prompt.


## Configuration Reference

FlaskProject/.env
- BACKEND_URL: Backend base URL (default http://localhost:8000)
- SECRET_KEY: Flask secret key for sessions, CSRF extensions, etc. If absent, an ephemeral dev key is generated (development only).
- REMEMBER_ME_DAYS: Integer days for prolonged session cookies when "remember me" is enabled (default 30).
- SECURE_COOKIES: true/false to always set the Secure flag on cookies (default false). In production behind HTTPS, set to true.
- SESSION_COOKIE_SAMESITE: Lax/Strict/None (default Lax). If set to None, browsers require Secure=true.

Login/app/.env
- DATABASE_URL: SQLAlchemy URL to your MariaDB/MySQL. Example: mariadb+mariadbconnector://user:pass@127.0.0.1:3306/pupero
- JWT_SECRET_KEY: Secret for signing JWTs (HS256).
- JWT_ACCESS_TOKEN_EXPIRE_MINUTES: Access token lifetime (minutes).
- JWT_REFRESH_TOKEN_EXPIRE_MINUTES: Refresh token lifetime (minutes).
- REMEMBER_ME_DAYS: Days for long tokens when "remember me" is requested.
- ANTI_PHISHING_PHRASE_DEFAULT: Default phrase for new users.
- SQL_ECHO: true/false to toggle SQLAlchemy engine echo logging (default false; set true only for local debugging).

CreateDB CLI
- --user: DB username (required)
- --password: DB password (optional; prefer env/prompt)
- --host: DB host (default 127.0.0.1)
- --port: DB port (default 3306)
- --database: Database name to create tables in (required)
- --driver: SQLAlchemy driver (default mariadb+mariadbconnector)
- --echo: Echo SQL statements (debugging)
- --create-database: Ensure the database exists (utf8mb4)
- Also reads DB_PASSWORD env var if --password is not provided.


## Security considerations and best practices

Implemented
- Argon2 password hashing via passlib.
- JWT tokens signed with HS256; secret from environment.
- TOTP 2FA using time‑based one‑time passwords, with QR provisioning.
- Access token stored in HttpOnly cookie; SameSite and Secure flags configurable.
- Email enumeration protection for password reset.
- URL‑encoding of DB credentials when constructing SQLAlchemy URLs.
- Optional SQL echo logging disabled by default in backend (recommendation). Enable only for local debugging.

Recommended in production
- Always run both frontend and backend behind HTTPS. Set SECURE_COOKIES=true.
- Set strong SECRET_KEY and JWT_SECRET_KEY via environment, rotate secrets periodically.
- Put the backend behind a reverse proxy (nginx, Traefik) and configure X‑Forwarded‑Proto so request.is_secure is accurate, or force SECURE_COOKIES=true.
- Add CSRF protection for state‑changing forms if you move away from token‑based JSON requests (Flask‑WTF/Flask‑Talisman, etc.).
- Configure structured logging and centralize logs (e.g., JSON to stdout; ship with Fluent Bit).
- Consider rate limiting (e.g., SlowAPI for FastAPI; Flask‑Limiter for Flask) for login/registration endpoints.
- Consider enabling CORS only if you expose the API directly to browsers; with this frontend, API calls are server‑to‑server.
- Set database user with limited privileges (create user/db once with admin, then run with least privilege).


## API Overview (Login)

POST /register
- Body: { email, username, password }
- Returns: { user_id }

POST /login
- Body: { username or email, password, totp?, remember_me? }
- Returns: { access_token, refresh_token, token_type: "bearer" }

POST /refresh
- Body: { refresh_token }
- Returns: { access_token, refresh_token }

POST /password/reset
- Body: { email }
- Returns: generic message. Implement email delivery in production.

GET /user/profile
- Auth: Bearer access token
- Returns: { email, username, role, phrase }

PUT /user/update
- Auth: Bearer access token
- Body: can include phrase, username (unique), new_email (requires current_password), new_password (requires current_password)
- Returns: { message, access_token?, refresh_token? }

POST /totp/enable/start
- Auth: Bearer access token
- Returns: { secret, qr_code(base64) }

POST /totp/enable/confirm
- Auth: Bearer access token
- Body: { secret, code }
- Returns: { message }

POST /totp/disable
- Auth: Bearer access token
- Returns: { message }

DELETE /user/delete
- Auth: Bearer access token
- Body: { confirm: true, current_password, totp? }
- Returns: { message }


## Development tips
- Use separate virtualenvs or install requirements per subproject.
- Keep secrets in .env files and never commit real secrets.
- For local HTTPS, consider mkcert + reverse proxy (nginx) to test cookie Secure behavior.
- To inspect DB: use a client like DBeaver or mysql client.


## Troubleshooting
- DB connection error: verify host/port/user/password and that the mariadb+mariadbconnector driver is installed; ensure DB exists (use CreateDB with --create-database).
- Login returns 400: Incorrect username/email or password, or missing/invalid TOTP when enabled.
- Frontend shows "Unauthorized": Cookie may be missing or expired; log back in.
- Token cookies not set as Secure on localhost: browsers require HTTPS for Secure; for development keep SECURE_COOKIES=false.


## Notes about this codebase and changes in this revision
- CreateDB/main.py: supports password via env (DB_PASSWORD) or interactive prompt and URL‑encodes DB credentials.
- FlaskProject/config.py: adds SECURE_COOKIES and SESSION_COOKIE_SAMESITE configuration options.
- FlaskProject/app.py: hardens session cookie defaults and generates an ephemeral dev SECRET_KEY if not set.
- Login/app/config.py: adds SQL_ECHO setting to control SQL logging (recommended false by default).
- Further hardening suggestions and operational guidance are listed above in the Security section.
