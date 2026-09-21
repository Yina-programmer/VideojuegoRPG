-- ============================================================
-- Migración 001: Creación inicial — VideojuegoRPG
-- Idempotente: puede ejecutarse varias veces sin efectos secundarios.
-- No contiene DROP, TRUNCATE ni operaciones destructivas.
-- ============================================================

BEGIN;

-- ── Catálogo: tipos de personaje ────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS character_types (
    slug  TEXT PRIMARY KEY,
    label TEXT NOT NULL
);

INSERT INTO character_types (slug, label)
VALUES ('mujer', 'Personaje Mujer')
ON CONFLICT (slug) DO NOTHING;

-- ── Catálogo: outfits ───────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS outfits (
    slug  TEXT PRIMARY KEY,
    label TEXT NOT NULL
);

INSERT INTO outfits (slug, label)
VALUES
    ('original',    'Clásico'),
    ('rosa',        'Rosa'),
    ('azul',        'Azul'),
    ('negro',       'Negro'),
    ('blanco_mono', 'Lazo blanco'),
    ('negro_mono',  'Lazo negro')
ON CONFLICT (slug) DO NOTHING;

-- ── Catálogo: estilos de cabello ────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS hair_styles (
    slug  TEXT PRIMARY KEY,
    label TEXT NOT NULL
);

INSERT INTO hair_styles (slug, label)
VALUES
    ('castano',       'Castaño'),
    ('trenzas_rojas', 'Trenzas rojas'),
    ('flor_verde',    'Flor verde')
ON CONFLICT (slug) DO NOTHING;

-- ── Tabla principal: un único registro de personalización por jugador ───────
CREATE TABLE IF NOT EXISTS player_customization (
    player_id      UUID        PRIMARY KEY,
    character_type TEXT        NOT NULL REFERENCES character_types(slug),
    outfit_id      TEXT        NOT NULL REFERENCES outfits(slug),
    hair_style_id  TEXT        NOT NULL REFERENCES hair_styles(slug),
    created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE player_customization IS
    'Un único registro por jugador (player_id). Usar UPSERT; nunca INSERT duplicado.';
COMMENT ON COLUMN player_customization.player_id IS
    'UUID v4 generado en el cliente (Godot). No autoincremental.';
COMMENT ON COLUMN player_customization.updated_at IS
    'Actualizado en cada UPSERT mediante updated_at = NOW(). created_at es inmutable.';

COMMIT;
