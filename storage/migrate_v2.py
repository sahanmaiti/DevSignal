import psycopg2
import sys
import os

# Ensure project root is in path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from config.settings import DATABASE_URL


MIGRATION_SQL = """
-- Enable UUID generation (required for gen_random_uuid)
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ─────────────────────────────────────────────
-- Table 1: device_tokens
-- ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS device_tokens (
    id          SERIAL PRIMARY KEY,
    token       TEXT UNIQUE NOT NULL,
    platform    TEXT NOT NULL DEFAULT 'ios',
    created_at  TIMESTAMPTZ DEFAULT NOW(),
    updated_at  TIMESTAMPTZ DEFAULT NOW()
);

-- ─────────────────────────────────────────────
-- Table 2: applications (FIXED → uses opportunities)
-- ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS applications (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    -- IMPORTANT: matches opportunities.id (INTEGER)
    job_id      INTEGER NOT NULL UNIQUE
                    REFERENCES opportunities(id)
                    ON DELETE CASCADE,

    stage       TEXT NOT NULL DEFAULT 'applied',
    applied_at  TIMESTAMPTZ DEFAULT NOW(),
    notes       TEXT,
    updated_at  TIMESTAMPTZ DEFAULT NOW()
);

-- ─────────────────────────────────────────────
-- Indexes
-- ─────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_applications_job_id 
    ON applications(job_id);

CREATE INDEX IF NOT EXISTS idx_applications_stage   
    ON applications(stage);

CREATE INDEX IF NOT EXISTS idx_device_tokens_token  
    ON device_tokens(token);

-- ─────────────────────────────────────────────
-- Trigger Function (shared)
-- ─────────────────────────────────────────────
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- ─────────────────────────────────────────────
-- Triggers
-- ─────────────────────────────────────────────
DROP TRIGGER IF EXISTS update_applications_updated_at ON applications;
CREATE TRIGGER update_applications_updated_at
    BEFORE UPDATE ON applications
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_device_tokens_updated_at ON device_tokens;
CREATE TRIGGER update_device_tokens_updated_at
    BEFORE UPDATE ON device_tokens
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();
"""


def run_migration():
    print("🔄 Running DevSignal v2 migration...")

    try:
        conn = psycopg2.connect(DATABASE_URL)
        conn.autocommit = True
        cursor = conn.cursor()

        cursor.execute(MIGRATION_SQL)

        cursor.close()
        conn.close()

        print("✅ Migration complete. Tables ready: device_tokens, applications")

    except Exception as e:
        print(f"❌ Migration failed: {e}")
        sys.exit(1)


if __name__ == "__main__":
    run_migration()