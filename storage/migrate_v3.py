
import psycopg2
import sys
import os

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from config.settings import DATABASE_URL


MIGRATION_SQL = """
-- ─────────────────────────────────────────────────────────────────────────
-- PREREQUISITE EXTENSIONS
-- ─────────────────────────────────────────────────────────────────────────

CREATE EXTENSION IF NOT EXISTS "pgcrypto";   -- gen_random_uuid()


-- ─────────────────────────────────────────────────────────────────────────
-- ARCH-1 ❶  users table
--
-- Central identity for every DevSignal user.
-- plan column gates feature access (free / pro / enterprise).
-- is_active lets us suspend accounts without deleting data.
-- ─────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS users (
    id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    email           TEXT        UNIQUE NOT NULL,
    hashed_password TEXT        NOT NULL,
    plan            TEXT        NOT NULL DEFAULT 'free'
                                    CHECK (plan IN ('free', 'pro', 'enterprise')),
    is_active       BOOLEAN     NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_users_plan       ON users(plan);


-- ─────────────────────────────────────────────────────────────────────────
-- ARCH-1 ❷  api_keys table
--
-- Per-user API keys stored as SHA-256 hashes (never plaintext).
-- The raw key is shown once at creation time; after that only the hash
-- is kept.  name lets users label keys ("iOS app", "n8n automation").
-- ─────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS api_keys (
    id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    key_hash    TEXT        UNIQUE NOT NULL,   -- SHA-256(raw_key)
    name        TEXT        NOT NULL DEFAULT 'default',
    last_used   TIMESTAMPTZ,
    revoked     BOOLEAN     NOT NULL DEFAULT FALSE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_api_keys_user_id  ON api_keys(user_id);
CREATE INDEX IF NOT EXISTS idx_api_keys_key_hash ON api_keys(key_hash);


-- ─────────────────────────────────────────────────────────────────────────
-- ARCH-1 ❸  add user_id to applications and device_tokens
--
-- NULLABLE so existing single-user data keeps working unchanged.
-- When a user authenticates and creates/moves an application the column
-- gets populated.  Composite indexes power per-user Kanban queries.
-- ─────────────────────────────────────────────────────────────────────────

ALTER TABLE applications
    ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES users(id) ON DELETE CASCADE;

ALTER TABLE device_tokens
    ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES users(id) ON DELETE CASCADE;

-- Composite index: "give me all applications for user X in stage Y"
CREATE INDEX IF NOT EXISTS idx_applications_user_stage
    ON applications(user_id, stage)
    WHERE user_id IS NOT NULL;

-- Composite index: "give me all device tokens for user X"
CREATE INDEX IF NOT EXISTS idx_device_tokens_user_id
    ON device_tokens(user_id)
    WHERE user_id IS NOT NULL;


-- ─────────────────────────────────────────────────────────────────────────
-- updated_at trigger for users table (same pattern already used elsewhere)
-- ─────────────────────────────────────────────────────────────────────────

-- The shared trigger function already exists (set_updated_at / update_updated_at_column).
-- Use OR REPLACE so we can safely re-run this migration.

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_users_updated_at ON users;
CREATE TRIGGER trg_users_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();


-- ─────────────────────────────────────────────────────────────────────────
-- ARCH-3  application → opportunity sync trigger
--
-- Problem before this fix
--   POST /jobs/{id}/apply did two separate writes:
--     1. upsert_application(job_id, stage)        → applications table
--     2. update_application_status(job_id, stage) → opportunities table
--   If write 1 succeeded but write 2 failed, the two tables drifted.
--   There was no transaction wrapping both writes.
--
-- Fix
--   A BEFORE trigger fires inside the same transaction as the applications
--   write, so both tables are always updated atomically.  The api/main.py
--   endpoint no longer needs to call update_application_status at all.
--
-- Mapping (applications.stage → opportunities columns)
--   applied   → applied=TRUE,  response_status='No response', interview_stage=''
--   waiting   → applied=TRUE,  response_status='No response', interview_stage=''
--   replied   → applied=TRUE,  response_status='Replied',     interview_stage=''
--   interview → applied=TRUE,  response_status='Replied',     interview_stage='Technical'
--   offer     → applied=TRUE,  response_status='Replied',     interview_stage='Offer'
--   rejected  → applied=TRUE,  response_status='Rejected',    interview_stage='Rejected'
-- ─────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION sync_application_to_opportunity()
RETURNS TRIGGER AS $$
DECLARE
    v_response_status  TEXT;
    v_interview_stage  TEXT;
BEGIN
    -- Derive legacy column values from the canonical stage
    CASE NEW.stage
        WHEN 'replied'   THEN
            v_response_status := 'Replied';
            v_interview_stage := '';
        WHEN 'interview' THEN
            v_response_status := 'Replied';
            v_interview_stage := 'Technical';
        WHEN 'offer'     THEN
            v_response_status := 'Replied';
            v_interview_stage := 'Offer';
        WHEN 'rejected'  THEN
            v_response_status := 'Rejected';
            v_interview_stage := 'Rejected';
        ELSE
            -- applied / waiting / anything unknown
            v_response_status := 'No response';
            v_interview_stage := '';
    END CASE;

    UPDATE opportunities
    SET
        applied          = TRUE,
        response_status  = v_response_status,
        interview_stage  = v_interview_stage
    WHERE id = NEW.job_id;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_sync_application_to_opportunity ON applications;
CREATE TRIGGER trg_sync_application_to_opportunity
    AFTER INSERT OR UPDATE OF stage ON applications
    FOR EACH ROW
    EXECUTE FUNCTION sync_application_to_opportunity();


-- ─────────────────────────────────────────────────────────────────────────
-- VERIFICATION
-- ─────────────────────────────────────────────────────────────────────────

DO $$
BEGIN
    RAISE NOTICE 'migrate_v3 applied successfully.';
    RAISE NOTICE 'New tables: users, api_keys';
    RAISE NOTICE 'Modified tables: applications (+ user_id), device_tokens (+ user_id)';
    RAISE NOTICE 'New trigger: trg_sync_application_to_opportunity';
END $$;
"""


def run_migration():
    print("=" * 60)
    print("  DevSignal v3 migration")
    print("  ARCH-1: users + api_keys tables")
    print("  ARCH-3: application→opportunity sync trigger")
    print("=" * 60)
    print(f"\n  Database: {DATABASE_URL[:50]}...")

    try:
        conn = psycopg2.connect(DATABASE_URL)
        conn.autocommit = True
        cursor = conn.cursor()

        cursor.execute(MIGRATION_SQL)

        cursor.close()
        conn.close()

        print("\n✅  Migration complete.")
        print("\n  Tables created / verified:")
        print("    ✓ users")
        print("    ✓ api_keys")
        print("    ✓ applications.user_id  (nullable)")
        print("    ✓ device_tokens.user_id (nullable)")
        print("\n  Triggers installed:")
        print("    ✓ trg_sync_application_to_opportunity")
        print("    ✓ trg_users_updated_at")
        print()

    except psycopg2.Error as e:
        print(f"\n❌  Migration failed: {e}")
        sys.exit(1)


if __name__ == "__main__":
    run_migration()