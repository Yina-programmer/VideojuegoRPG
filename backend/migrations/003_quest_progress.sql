-- HU_8: estado de aventuras, independiente de la bitácora y el armario.
BEGIN;

CREATE TABLE IF NOT EXISTS player_quest_progress (
    player_id UUID NOT NULL,
    quest_id TEXT NOT NULL CHECK (quest_id IN ('hippies', 'politecnico', 'theatron', 'final')),
    status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'completed')),
    collected_items TEXT[] NOT NULL DEFAULT '{}',
    solved_steps TEXT[] NOT NULL DEFAULT '{}',
    started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    completed_at TIMESTAMPTZ,
    narrative_unlocked_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (player_id, quest_id),
    CHECK ((status = 'completed') = (completed_at IS NOT NULL)),
    CHECK (quest_id <> 'final' OR narrative_unlocked_at IS NULL)
);

COMMIT;
