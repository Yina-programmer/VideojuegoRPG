-- HU_11 / HU_12: cuentas, perfiles y sesiones autenticadas.
-- Migracion aditiva e idempotente: no elimina ni reasigna partidas anonimas.
BEGIN;

CREATE TABLE IF NOT EXISTS player_accounts (
    account_id          UUID        PRIMARY KEY,
    username            TEXT        NOT NULL,
    username_normalized TEXT        NOT NULL UNIQUE,
    email               TEXT        NOT NULL,
    email_normalized    TEXT        NOT NULL UNIQUE,
    password_hash       TEXT        NOT NULL,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT player_accounts_username_length CHECK (
        char_length(username) BETWEEN 3 AND 24
    ),
    CONSTRAINT player_accounts_email_length CHECK (
        char_length(email) BETWEEN 3 AND 254
    )
);

CREATE TABLE IF NOT EXISTS player_profiles (
    player_id    UUID        PRIMARY KEY,
    account_id   UUID        NOT NULL UNIQUE
                 REFERENCES player_accounts(account_id) ON DELETE CASCADE,
    display_name TEXT        NOT NULL,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS auth_sessions (
    session_id  UUID        PRIMARY KEY,
    account_id  UUID        NOT NULL
                REFERENCES player_accounts(account_id) ON DELETE CASCADE,
    token_hash  CHAR(64)    NOT NULL UNIQUE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_used_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at  TIMESTAMPTZ NOT NULL,
    revoked_at  TIMESTAMPTZ,
    CONSTRAINT auth_sessions_expiration CHECK (expires_at > created_at)
);

CREATE INDEX IF NOT EXISTS auth_sessions_account_active_idx
    ON auth_sessions (account_id, expires_at)
    WHERE revoked_at IS NULL;

-- Se conserva solamente un hash del identificador escrito en el login.
CREATE TABLE IF NOT EXISTS auth_login_attempts (
    identifier_hash CHAR(64)    PRIMARY KEY,
    failure_count   INTEGER     NOT NULL DEFAULT 0 CHECK (failure_count >= 0),
    window_started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    blocked_until   TIMESTAMPTZ,
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE player_profiles IS
    'Relacion uno a uno entre una cuenta autenticada y el player_id del progreso.';
COMMENT ON TABLE auth_sessions IS
    'Sesiones opacas: la base solo conserva SHA-256 del token, nunca el token real.';

COMMIT;
