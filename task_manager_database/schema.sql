-- Task Manager MVP schema (idempotent)
-- Applies users, tasks, tags, and task_tags with useful indexes.
-- Designed to be safe to re-run on startup.

BEGIN;

-- Extensions (for UUID generation)
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Updated-at trigger helper
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ----------------------------
-- users
-- ----------------------------
CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email TEXT NOT NULL UNIQUE,
  password_hash TEXT NOT NULL,
  display_name TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger WHERE tgname = 'trg_users_set_updated_at'
  ) THEN
    CREATE TRIGGER trg_users_set_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW
    EXECUTE FUNCTION set_updated_at();
  END IF;
END $$;

-- ----------------------------
-- tasks
-- ----------------------------
CREATE TABLE IF NOT EXISTS tasks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,

  title TEXT NOT NULL,
  description TEXT,

  -- Completion
  is_completed BOOLEAN NOT NULL DEFAULT FALSE,
  completed_at TIMESTAMPTZ,

  -- Scheduling / prioritization
  due_at TIMESTAMPTZ,
  -- Simple MVP priority: 1 (highest) .. 5 (lowest)
  priority SMALLINT NOT NULL DEFAULT 3 CHECK (priority BETWEEN 1 AND 5),

  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger WHERE tgname = 'trg_tasks_set_updated_at'
  ) THEN
    CREATE TRIGGER trg_tasks_set_updated_at
    BEFORE UPDATE ON tasks
    FOR EACH ROW
    EXECUTE FUNCTION set_updated_at();
  END IF;
END $$;

-- Useful indexes for common queries (per-user lists, filtering, sorting)
CREATE INDEX IF NOT EXISTS idx_tasks_user_created_at ON tasks (user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_tasks_user_due_at ON tasks (user_id, due_at ASC);
CREATE INDEX IF NOT EXISTS idx_tasks_user_completed ON tasks (user_id, is_completed, updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_tasks_user_priority ON tasks (user_id, priority, due_at);

-- Search index (basic)
-- Note: this is not full-text search; it helps ILIKE with pattern ops sometimes.
-- For true FTS, backend can use to_tsvector; kept minimal for MVP.
CREATE INDEX IF NOT EXISTS idx_tasks_title_pattern ON tasks (title text_pattern_ops);

-- ----------------------------
-- tags
-- ----------------------------
CREATE TABLE IF NOT EXISTS tags (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,

  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  CONSTRAINT uq_tags_user_name UNIQUE (user_id, name)
);

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger WHERE tgname = 'trg_tags_set_updated_at'
  ) THEN
    CREATE TRIGGER trg_tags_set_updated_at
    BEFORE UPDATE ON tags
    FOR EACH ROW
    EXECUTE FUNCTION set_updated_at();
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_tags_user_name ON tags (user_id, name);

-- ----------------------------
-- task_tags (many-to-many)
-- ----------------------------
CREATE TABLE IF NOT EXISTS task_tags (
  task_id UUID NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
  tag_id UUID NOT NULL REFERENCES tags(id) ON DELETE CASCADE,

  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  PRIMARY KEY (task_id, tag_id)
);

CREATE INDEX IF NOT EXISTS idx_task_tags_tag_id ON task_tags (tag_id);
CREATE INDEX IF NOT EXISTS idx_task_tags_task_id ON task_tags (task_id);

COMMIT;
