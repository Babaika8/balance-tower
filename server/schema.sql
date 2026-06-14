CREATE TABLE IF NOT EXISTS scores (
  user_id    INTEGER PRIMARY KEY,
  username   TEXT,
  best_score INTEGER NOT NULL DEFAULT 0,
  updated_at INTEGER NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_scores_best ON scores (best_score DESC);
