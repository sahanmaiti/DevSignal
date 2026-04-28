# PURPOSE:
#   Database query layer for the Streamlit dashboard.
#   All queries are cached with a 5-minute TTL so the dashboard
#   stays fast without hitting Postgres on every page interaction.
#
# DUAL DATABASE SUPPORT:
#   Local development → reads from local Docker Postgres
#   Streamlit Cloud   → reads from Neon.tech cloud Postgres
#   Automatically detects which to use via st.secrets or DATABASE_URL env var
#
# PLACEMENT: dashboard/db.py

import os
import sys
import pandas as pd
from sqlalchemy import create_engine, text
from streamlit_autorefresh import st_autorefresh

import streamlit as st

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def get_database_url() -> str:
    """
    Returns the database connection URL.
    Checks Streamlit secrets first (for Cloud deployment),
    then falls back to local .env DATABASE_URL.
    """
    # Streamlit Cloud: secrets are in st.secrets["database"]["url"]
    try:
        return st.secrets["database"]["url"]
    except Exception:
        pass

    # Local dev: read from environment
    from dotenv import load_dotenv
    load_dotenv()
    return os.getenv(
        "DATABASE_URL",
        "postgresql://radar:radar_pass@localhost:5432/devsignal"
    )


@st.cache_resource
def get_engine():
    """
    Creates a SQLAlchemy engine (connection pool).
    Cached as a resource — created once, reused across all sessions.
    """
    url = get_database_url()
    return create_engine(url, pool_pre_ping=True)


@st.cache_data(ttl=300)   # refresh every 5 minutes
def load_opportunities(min_score: int = 0,
                        remote_only: bool = False,
                        unapplied_only: bool = False) -> pd.DataFrame:
    """Loads all opportunities with optional filters."""
    conditions = ["1=1"]
    params     = {}

    if min_score > 0:
        conditions.append("opportunity_score >= :min_score")
        params["min_score"] = min_score

    if remote_only:
        conditions.append("remote = 'Yes'")

    if unapplied_only:
        conditions.append("applied = false")

    where = " AND ".join(conditions)

    sql = text(f"""
        SELECT
            id, company, role, location, remote, visa_sponsorship,
            experience_req, tech_stack, job_source, apply_link,
            opportunity_score, score_breakdown, outreach_message,
            recruiter_name, recruiter_role, linkedin_profile, email,
            applied, response_status, interview_stage,
            date_found, updated_at
        FROM opportunities
        WHERE {where}
        ORDER BY opportunity_score DESC NULLS LAST, date_found DESC
    """)

    engine = get_engine()
    with engine.connect() as conn:
        df = pd.read_sql(sql, conn, params=params)

    # Parse dates
    for col in ["date_found", "updated_at"]:
        if col in df.columns:
            df[col] = pd.to_datetime(df[col], utc=True, errors="coerce")

    return df


@st.cache_data(ttl=300)
def load_stats() -> dict:
    """Loads aggregate KPI stats for the overview cards."""
    sql = text("""
        SELECT
            COUNT(*)                                              AS total_jobs,
            COUNT(*) FILTER (WHERE applied = true)               AS total_applied,
            COUNT(*) FILTER (WHERE response_status = 'Replied')  AS total_responses,
            COUNT(*) FILTER (WHERE interview_stage != '')         AS total_interviews,
            COUNT(*) FILTER (WHERE interview_stage = 'Offer')    AS total_offers,
            ROUND(AVG(opportunity_score)::numeric, 1)            AS avg_score,
            COUNT(*) FILTER (WHERE remote = 'Yes')               AS remote_count,
            COUNT(*) FILTER (WHERE opportunity_score >= 70)      AS high_score_count,
            COUNT(*) FILTER (WHERE opportunity_score IS NULL)    AS unscored_count,
            COUNT(*) FILTER (WHERE recruiter_name != '')         AS enriched_count
        FROM opportunities
    """)

    engine = get_engine()
    with engine.connect() as conn:
        result = conn.execute(sql).fetchone()

    if result:
        return dict(result._mapping)
    return {}


@st.cache_data(ttl=300)
def load_scrape_runs(limit: int = 20) -> pd.DataFrame:
    """Loads recent scrape run history."""
    sql = text("""
        SELECT id, started_at, finished_at, jobs_found,
            jobs_new, jobs_scored, errors, triggered_by
        FROM scrape_runs
        ORDER BY started_at DESC
        LIMIT :limit
    """)

    engine = get_engine()
    with engine.connect() as conn:
        df = pd.read_sql(sql, conn, params={"limit": limit})

    for col in ["started_at", "finished_at"]:
        if col in df.columns:
            df[col] = pd.to_datetime(df[col], utc=True, errors="coerce")

    return df


@st.cache_data(ttl=300)
def load_source_breakdown() -> pd.DataFrame:
    """Jobs count grouped by source."""
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

    engine = get_engine()
    with engine.connect() as conn:
        return pd.read_sql(sql, conn)


@st.cache_data(ttl=300)
def load_score_distribution() -> pd.DataFrame:
    """Score distribution for histogram."""
    sql = text("""
        SELECT opportunity_score
        FROM opportunities
        WHERE opportunity_score IS NOT NULL
        ORDER BY opportunity_score
    """)

    engine = get_engine()
    with engine.connect() as conn:
        return pd.read_sql(sql, conn)


@st.cache_data(ttl=300)
def load_watchlist() -> pd.DataFrame:
    """Companies watchlist."""
    sql = text("""
        SELECT company, ios_product_desc, funding_stage,
            company_url, linkedin_url, notes, added_at
        FROM companies_watchlist
        ORDER BY added_at DESC
    """)

    engine = get_engine()
    with engine.connect() as conn:
        return pd.read_sql(sql, conn)


def update_application_status(job_id: int, applied: bool,
                            response_status: str,
                            interview_stage: str) -> bool:
    """Updates application tracking fields directly from the dashboard."""
    sql = text("""
        UPDATE opportunities
        SET applied         = :applied,
            response_status = :response_status,
            interview_stage = :interview_stage
        WHERE id = :job_id
    """)

    try:
        engine = get_engine()
        with engine.begin() as conn:
            conn.execute(sql, {
                "applied":          applied,
                "response_status":  response_status,
                "interview_stage":  interview_stage,
                "job_id":           job_id,
            })
        # Clear the cache so the table refreshes
        load_opportunities.clear()
        load_stats.clear()
        return True
    except Exception as e:
        st.error(f"Failed to update: {e}")
        return False