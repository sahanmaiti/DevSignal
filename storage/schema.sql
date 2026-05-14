-- storage/schema.sql
--
-- PURPOSE:
--   Defines the complete DevSignal database structure for fresh installs.
--   Safe to re-run — every statement uses IF NOT EXISTS / OR REPLACE.
--
-- TABLE NAMING (ARCH-5):
--   The main table is `jobs`.  A view named `opportunities` is created
--   immediately after for backward compatibility with the Streamlit
--   dashboard, db_sync.py, and any legacy code that queries
--   FROM opportunities.  New code should always query FROM jobs.
--
-- APPLICATIONS UNIQUENESS (ARCH-7):
--   The old UNIQUE(job_id) constraint is replaced with two partial indexes:
--     • idx_applications_job_id_personal  — single-user / personal mode
--     • idx_applications_user_job_multiuser — multi-user mode
--   This allows re-applying after rejection without hitting a constraint
--   and prepares the schema for multi-tenancy.
--
-- PLACEMENT: storage/schema.sql


-- ═══════════════════════════════════════════════════════════════════════
-- TABLE: jobs  (was: opportunities in earlier schema versions)
-- ═══════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS jobs (

    id                  SERIAL          PRIMARY KEY,

    -- ── When and where we found it ────────────────────────────────────
    date_found          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    job_source          VARCHAR(50)     NOT NULL DEFAULT '',
    apply_link          TEXT            NOT NULL DEFAULT '',
    job_hash            VARCHAR(32)     NOT NULL UNIQUE,

    -- ── Job details ───────────────────────────────────────────────────
    company             TEXT            NOT NULL DEFAULT '',
    role                TEXT            NOT NULL DEFAULT '',
    location            TEXT            NOT NULL DEFAULT '',
    remote              VARCHAR(10)     NOT NULL DEFAULT 'Unknown'
                            CHECK (remote IN ('Yes', 'No', 'Hybrid', 'Unknown')),
    visa_sponsorship    VARCHAR(10)     NOT NULL DEFAULT 'Unknown'
                            CHECK (visa_sponsorship IN ('Yes', 'No', 'Unknown')),
    experience_req      VARCHAR(100)    NOT NULL DEFAULT '',
    tech_stack          TEXT            NOT NULL DEFAULT '',
    description_raw     TEXT            NOT NULL DEFAULT '',

    -- ── Recruiter info (filled by processors/enricher.py) ─────────────
    recruiter_name      VARCHAR(200)    NOT NULL DEFAULT '',
    recruiter_role      VARCHAR(200)    NOT NULL DEFAULT '',
    linkedin_profile    TEXT            NOT NULL DEFAULT '',
    email               VARCHAR(200)    NOT NULL DEFAULT '',

    -- ── AI fields (filled by ai/scorer.py) ───────────────────────────
    opportunity_score   SMALLINT
                            CHECK (opportunity_score IS NULL
                                OR (opportunity_score >= 0 AND opportunity_score <= 100)),
    score_breakdown     JSONB,
    outreach_message    TEXT            NOT NULL DEFAULT '',

    -- ── Application tracking (denormalised — source of truth is applications table)
    applied             BOOLEAN         NOT NULL DEFAULT FALSE,
    response_status     VARCHAR(20)     NOT NULL DEFAULT ''
                            CHECK (response_status IN (
                                '', 'No response', 'Viewed', 'Replied', 'Rejected'
                            )),
    interview_stage     VARCHAR(20)     NOT NULL DEFAULT ''
                            CHECK (interview_stage IN (
                                '', 'Phone screen', 'Technical',
                                'Final round', 'Offer', 'Rejected'
                            )),

    updated_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);


-- ═══════════════════════════════════════════════════════════════════════
-- BACKWARD-COMPAT VIEW (ARCH-5)
--
-- Streamlit, db_sync.py, and legacy scripts say FROM opportunities.
-- This view means they never need to change.
-- ═══════════════════════════════════════════════════════════════════════

CREATE OR REPLACE VIEW opportunities AS
    SELECT * FROM jobs;


-- ═══════════════════════════════════════════════════════════════════════
-- TABLE: companies_watchlist
-- ═══════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS companies_watchlist (
    id                  SERIAL          PRIMARY KEY,
    company             VARCHAR(200)    NOT NULL UNIQUE,
    ios_product_desc    TEXT            NOT NULL DEFAULT '',
    company_url         TEXT            NOT NULL DEFAULT '',
    linkedin_url        TEXT            NOT NULL DEFAULT '',
    funding_stage       VARCHAR(50)     NOT NULL DEFAULT '',
    notes               TEXT            NOT NULL DEFAULT '',
    added_at            TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);


-- ═══════════════════════════════════════════════════════════════════════
-- TABLE: scrape_runs
-- ═══════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS scrape_runs (
    id                  SERIAL          PRIMARY KEY,
    started_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    finished_at         TIMESTAMPTZ,
    jobs_found          INTEGER         NOT NULL DEFAULT 0,
    jobs_new            INTEGER         NOT NULL DEFAULT 0,
    jobs_scored         INTEGER         NOT NULL DEFAULT 0,
    errors              TEXT            NOT NULL DEFAULT '',
    triggered_by        VARCHAR(20)     NOT NULL DEFAULT 'manual'
                            CHECK (triggered_by IN ('manual', 'n8n', 'cron'))
);


-- ═══════════════════════════════════════════════════════════════════════
-- TABLE: device_tokens  (v2 — APNs push notifications)
-- ═══════════════════════════════════════════════════════════════════════

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

CREATE TABLE IF NOT EXISTS device_tokens (
    id          SERIAL      PRIMARY KEY,
    token       TEXT        UNIQUE NOT NULL,
    platform    TEXT        NOT NULL DEFAULT 'ios',
    user_id     UUID        REFERENCES users(id) ON DELETE CASCADE,   -- nullable: personal mode
    created_at  TIMESTAMPTZ DEFAULT NOW(),
    updated_at  TIMESTAMPTZ DEFAULT NOW()
);


-- ═══════════════════════════════════════════════════════════════════════
-- TABLE: applications  (v2 — iOS Tracker source of truth)
--
-- ARCH-7: NO global UNIQUE(job_id).
-- Two partial unique indexes handle the constraint correctly for each mode.
-- ═══════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS applications (
    id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    job_id      INTEGER     NOT NULL REFERENCES jobs(id) ON DELETE CASCADE,
    user_id     UUID        REFERENCES users(id) ON DELETE CASCADE,   -- nullable: personal mode
    stage       TEXT        NOT NULL DEFAULT 'applied',
    applied_at  TIMESTAMPTZ DEFAULT NOW(),
    notes       TEXT,
    updated_at  TIMESTAMPTZ DEFAULT NOW()
);

-- Personal-mode uniqueness: one application per job when there is no user
CREATE UNIQUE INDEX IF NOT EXISTS idx_applications_job_id_personal
    ON applications (job_id)
    WHERE user_id IS NULL;

-- Multi-user uniqueness: one application per (user, job) pair
CREATE UNIQUE INDEX IF NOT EXISTS idx_applications_user_job_multiuser
    ON applications (user_id, job_id)
    WHERE user_id IS NOT NULL;


-- ═══════════════════════════════════════════════════════════════════════
-- TABLE: users  (v3 — multi-tenancy foundation)
-- ═══════════════════════════════════════════════════════════════════════

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


-- ═══════════════════════════════════════════════════════════════════════
-- TABLE: api_keys  (v3 — per-user API key auth)
-- ═══════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS api_keys (
    id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    key_hash    TEXT        UNIQUE NOT NULL,
    name        TEXT        NOT NULL DEFAULT 'default',
    last_used   TIMESTAMPTZ,
    revoked     BOOLEAN     NOT NULL DEFAULT FALSE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);


-- ═══════════════════════════════════════════════════════════════════════
-- INDEXES
-- ═══════════════════════════════════════════════════════════════════════

CREATE INDEX IF NOT EXISTS idx_jobs_score
    ON jobs (opportunity_score DESC NULLS LAST);

CREATE INDEX IF NOT EXISTS idx_jobs_applied
    ON jobs (applied);

CREATE INDEX IF NOT EXISTS idx_jobs_date
    ON jobs (date_found DESC);

CREATE INDEX IF NOT EXISTS idx_jobs_source
    ON jobs (job_source);

CREATE INDEX IF NOT EXISTS idx_jobs_hash
    ON jobs (job_hash);

CREATE INDEX IF NOT EXISTS idx_jobs_unscored
    ON jobs (id) WHERE opportunity_score IS NULL;

CREATE INDEX IF NOT EXISTS idx_applications_stage
    ON applications (stage);

CREATE INDEX IF NOT EXISTS idx_applications_user_stage
    ON applications (user_id, stage)
    WHERE user_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_device_tokens_token
    ON device_tokens (token);

CREATE INDEX IF NOT EXISTS idx_device_tokens_user_id
    ON device_tokens (user_id)
    WHERE user_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_users_plan
    ON users (plan);

CREATE INDEX IF NOT EXISTS idx_api_keys_user_id
    ON api_keys (user_id);

CREATE INDEX IF NOT EXISTS idx_api_keys_key_hash
    ON api_keys (key_hash);


-- ═══════════════════════════════════════════════════════════════════════
-- TRIGGER FUNCTION: auto-update updated_at
-- ═══════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Shared alias used by trigger definitions in migration files
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_jobs_updated_at ON jobs;
CREATE TRIGGER trg_jobs_updated_at
    BEFORE UPDATE ON jobs
    FOR EACH ROW
    EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_users_updated_at ON users;
CREATE TRIGGER trg_users_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

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


-- ═══════════════════════════════════════════════════════════════════════
-- TRIGGER: sync applications.stage → jobs legacy columns  (ARCH-3)
-- ═══════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION sync_application_to_opportunity()
RETURNS TRIGGER AS $$
DECLARE
    v_response_status  TEXT;
    v_interview_stage  TEXT;
BEGIN
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
            v_response_status := 'No response';
            v_interview_stage := '';
    END CASE;

    UPDATE jobs
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


-- ═══════════════════════════════════════════════════════════════════════
-- VERIFICATION
-- ═══════════════════════════════════════════════════════════════════════

DO $$
BEGIN
    RAISE NOTICE 'DevSignal schema applied successfully.';
    RAISE NOTICE 'Tables: jobs, companies_watchlist, scrape_runs, device_tokens, applications, users, api_keys';
    RAISE NOTICE 'Views:  opportunities (backward-compat alias for jobs)';
END $$;
