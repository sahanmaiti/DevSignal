# dashboard/db.py — full cloud/local compatible version

import os
import sys
import pandas as pd
from sqlalchemy import create_engine, text
import streamlit as st

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


# ─────────────────────────────────────────────
# DATABASE URL RESOLUTION
# Priority:
# 1. Streamlit secrets (Cloud)
# 2. .env file (Local)
# 3. localhost fallback
# ─────────────────────────────────────────────
def get_database_url() -> str:
    # Streamlit Cloud secret
    try:
        if "DATABASE_URL" in st.secrets:
            return st.secrets["DATABASE_URL"]

        if "database" in st.secrets:
            return st.secrets["database"]["url"]
    except Exception:
        pass

    # Local .env
    try:
        from dotenv import load_dotenv
        load_dotenv()
    except Exception:
        pass

    return os.getenv(
        "DATABASE_URL",
        "postgresql://radar:radar_pass@localhost:5432/devsignal"
    )


# ─────────────────────────────────────────────
# ENGINE
# ─────────────────────────────────────────────
@st.cache_resource
def get_engine():
    url = get_database_url()
    return create_engine(
        url,
        pool_pre_ping=True,
        pool_recycle=300
    )


# ─────────────────────────────────────────────
# CACHE RESET
# ─────────────────────────────────────────────
def clear_all_caches():
    load_stats.clear()
    load_opportunities.clear()
    load_outreach_jobs.clear()
    load_scrape_runs.clear()
    load_source_breakdown.clear()
    load_score_distribution.clear()
    load_watchlist.clear()


# ─────────────────────────────────────────────
# DASHBOARD STATS
# ─────────────────────────────────────────────
@st.cache_data(ttl=60)
def load_stats() -> dict:
    sql = text("""
        SELECT
            COUNT(*)                                            AS total_jobs,
            COUNT(*) FILTER (WHERE applied = true)              AS total_applied,
            COUNT(*) FILTER (WHERE response_status = 'Replied') AS total_responses,
            COUNT(*) FILTER (WHERE interview_stage != '')       AS total_interviews,
            COUNT(*) FILTER (WHERE interview_stage = 'Offer')   AS total_offers,
            ROUND(AVG(opportunity_score)::numeric, 1)           AS avg_score,
            COUNT(*) FILTER (WHERE remote = 'Yes')              AS remote_count,
            COUNT(*) FILTER (WHERE opportunity_score >= 70)     AS high_score_count,
            COUNT(*) FILTER (WHERE opportunity_score IS NULL)   AS unscored_count,
            COUNT(*) FILTER (WHERE recruiter_name != '')        AS enriched_count,
            COUNT(*) FILTER (WHERE outreach_message != '')      AS outreach_count
        FROM opportunities
    """)

    try:
        with get_engine().connect() as conn:
            row = conn.execute(sql).fetchone()

        return dict(row._mapping) if row else {}

    except Exception as e:
        st.error(f"Stats query failed: {e}")
        return {}


# ─────────────────────────────────────────────
# JOB TABLE
# ─────────────────────────────────────────────
@st.cache_data(ttl=60)
def load_opportunities(
    min_score: int = 0,
    remote_only: bool = False,
    unapplied_only: bool = False
) -> pd.DataFrame:

    conditions = ["1=1"]
    params = {}

    if min_score > 0:
        conditions.append("opportunity_score >= :min_score")
        params["min_score"] = min_score

    if remote_only:
        conditions.append("remote = 'Yes'")

    if unapplied_only:
        conditions.append("applied = false")

    where_clause = " AND ".join(conditions)

    sql = text(f"""
        SELECT
            id,
            company,
            role,
            location,
            remote,
            visa_sponsorship,
            experience_req,
            tech_stack,
            job_source,
            apply_link,
            opportunity_score,
            score_breakdown,
            outreach_message,
            recruiter_name,
            recruiter_role,
            linkedin_profile,
            email,
            applied,
            response_status,
            interview_stage,
            date_found,
            updated_at,
            description_raw
        FROM opportunities
        WHERE {where_clause}
        ORDER BY opportunity_score DESC NULLS LAST, date_found DESC
    """)

    try:
        with get_engine().connect() as conn:
            df = pd.read_sql(sql, conn, params=params)

        for col in ["date_found", "updated_at"]:
            if col in df.columns:
                df[col] = pd.to_datetime(df[col], errors="coerce", utc=True)

        return df

    except Exception as e:
        st.error(f"Load opportunities failed: {e}")
        return pd.DataFrame()


# ─────────────────────────────────────────────
# OUTREACH PAGE
# ─────────────────────────────────────────────
@st.cache_data(ttl=60)
def load_outreach_jobs() -> pd.DataFrame:
    sql = text("""
        SELECT
            id,
            company,
            role,
            opportunity_score,
            outreach_message,
            recruiter_name,
            recruiter_role,
            linkedin_profile,
            email,
            apply_link,
            applied,
            date_found,
            job_source
        FROM opportunities
        WHERE outreach_message IS NOT NULL
          AND outreach_message != ''
          AND LENGTH(TRIM(outreach_message)) > 10
        ORDER BY opportunity_score DESC NULLS LAST
    """)

    try:
        with get_engine().connect() as conn:
            return pd.read_sql(sql, conn)

    except Exception as e:
        st.error(f"Outreach query failed: {e}")
        return pd.DataFrame()


# ─────────────────────────────────────────────
# SCRAPE HISTORY
# ─────────────────────────────────────────────
@st.cache_data(ttl=60)
def load_scrape_runs(limit: int = 20) -> pd.DataFrame:
    sql = text("""
        SELECT
            id,
            started_at,
            finished_at,
            jobs_found,
            jobs_new,
            jobs_scored,
            errors,
            triggered_by
        FROM scrape_runs
        ORDER BY started_at DESC
        LIMIT :limit
    """)

    try:
        with get_engine().connect() as conn:
            df = pd.read_sql(sql, conn, params={"limit": limit})

        for col in ["started_at", "finished_at"]:
            df[col] = pd.to_datetime(df[col], errors="coerce", utc=True)

        return df

    except Exception:
        return pd.DataFrame()


# ─────────────────────────────────────────────
# SOURCE BREAKDOWN
# ─────────────────────────────────────────────
@st.cache_data(ttl=60)
def load_source_breakdown() -> pd.DataFrame:
    sql = text("""
        SELECT
            job_source,
            COUNT(*) AS total_jobs,
            COUNT(*) FILTER (WHERE opportunity_score >= 70) AS high_score_jobs,
            ROUND(AVG(opportunity_score)::numeric, 1) AS avg_score
        FROM opportunities
        GROUP BY job_source
        ORDER BY total_jobs DESC
    """)

    try:
        with get_engine().connect() as conn:
            return pd.read_sql(sql, conn)
    except Exception:
        return pd.DataFrame()


# ─────────────────────────────────────────────
# SCORE HISTOGRAM
# ─────────────────────────────────────────────
@st.cache_data(ttl=60)
def load_score_distribution() -> pd.DataFrame:
    sql = text("""
        SELECT opportunity_score
        FROM opportunities
        WHERE opportunity_score IS NOT NULL
    """)

    try:
        with get_engine().connect() as conn:
            return pd.read_sql(sql, conn)
    except Exception:
        return pd.DataFrame()


# ─────────────────────────────────────────────
# WATCHLIST
# ─────────────────────────────────────────────
@st.cache_data(ttl=60)
def load_watchlist() -> pd.DataFrame:
    sql = text("""
        SELECT
            company,
            ios_product_desc,
            funding_stage,
            company_url,
            notes,
            added_at
        FROM companies_watchlist
        ORDER BY added_at DESC
    """)

    try:
        with get_engine().connect() as conn:
            return pd.read_sql(sql, conn)
    except Exception:
        return pd.DataFrame()


# ─────────────────────────────────────────────
# UPDATE JOB STATUS
# ─────────────────────────────────────────────
def update_application_status(
    job_id: int,
    applied: bool,
    response_status: str,
    interview_stage: str
) -> bool:

    sql = text("""
        UPDATE opportunities
        SET
            applied = :applied,
            response_status = :response_status,
            interview_stage = :interview_stage
        WHERE id = :job_id
    """)

    try:
        with get_engine().begin() as conn:
            conn.execute(sql, {
                "applied": applied,
                "response_status": response_status,
                "interview_stage": interview_stage,
                "job_id": job_id
            })

        clear_all_caches()
        return True

    except Exception as e:
        st.error(f"Update failed: {e}")
        return False