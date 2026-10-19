-- HU_7: progreso de exploración por jugador y lugar.
-- Independiente de player_customization: se puede explorar antes de guardar ropa.
BEGIN;

CREATE TABLE IF NOT EXISTS player_place_progress (
    player_id     UUID        NOT NULL,
    place_id      TEXT        NOT NULL,
    visited_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    discovered_at TIMESTAMPTZ,
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT player_place_progress_pkey PRIMARY KEY (player_id, place_id),
    CONSTRAINT discovery_after_visit CHECK (
        discovered_at IS NULL OR discovered_at >= visited_at
    )
);

COMMENT ON TABLE player_place_progress IS
    'HU_7: primera visita y primer descubrimiento cultural por UUID y lugar.';
COMMENT ON COLUMN player_place_progress.discovered_at IS
    'NULL significa visitado pero aún sin consultar la narrativa. Nunca retrocede.';

COMMIT;
