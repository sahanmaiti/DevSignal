import os
import streamlit as st
import pandas as pd
import plotly.express as px
from datetime import datetime, timezone
from sqlalchemy import create_engine, text

def get_engine():
    try:
        url = st.secrets["database"]["url"]
    except Exception:
        from dotenv import load_dotenv; load_dotenv()
        url = os.getenv("DATABASE_URL",
                        "postgresql://radar:radar_pass@localhost:5432/devsignal")
    return create_engine(url, pool_pre_ping=True)

@st.cache_data(ttl=300)
def load_runs():
    sql = text("""
        SELECT id, started_at, finished_at, jobs_found,
            jobs_new, jobs_scored, errors, triggered_by
        FROM scrape_runs ORDER BY started_at DESC LIMIT 20
    """)
    with get_engine().connect() as conn:
        df = pd.read_sql(sql, conn)
    for c in ["started_at","finished_at"]:
        df[c] = pd.to_datetime(df[c], utc=True, errors="coerce")
    return df

@st.cache_data(ttl=300)
def load_source_stats():
    sql = text("""
        SELECT job_source, COUNT(*) AS total,
            COUNT(*) FILTER (WHERE opportunity_score>=70) AS high,
            ROUND(AVG(opportunity_score)::numeric,1) AS avg_score
        FROM opportunities GROUP BY job_source ORDER BY total DESC
    """)
    with get_engine().connect() as conn:
        return pd.read_sql(sql, conn)

@st.cache_data(ttl=300)
def load_stats():
    sql = text("""
        SELECT COUNT(*) AS total_jobs,
            ROUND(AVG(opportunity_score)::numeric,1) AS avg_score,
            COUNT(*) FILTER (WHERE opportunity_score IS NULL) AS unscored
        FROM opportunities
    """)
    with get_engine().connect() as conn:
        row = conn.execute(sql).fetchone()
    return dict(row._mapping) if row else {}

# ── Page ──────────────────────────────────────────────────────────────────
st.title("⚙️ System")

try:
    stats = load_stats()
    runs  = load_runs()
except Exception as e:
    st.error(f"Database error: {e}")
    st.stop()

s1,s2,s3,s4 = st.columns(4)
s1.metric("Database", "Connected ✓")
s3.metric("Total jobs", int(stats.get("total_jobs", 0)))
s4.metric("Unscored",   int(stats.get("unscored", 0)))

if not runs.empty and pd.notna(runs.iloc[0]["started_at"]):
    last = runs.iloc[0]["started_at"]
    now  = datetime.now(timezone.utc)
    hrs  = (now - last.to_pydatetime()).total_seconds() / 3600 if last.tzinfo else 999
    s2.metric("Last run", f"{hrs:.1f}h ago",
            delta="on schedule" if hrs<13 else "overdue",
            delta_color="normal" if hrs<13 else "inverse")
else:
    s2.metric("Last run", "Never")

st.divider()
st.subheader("Scrape run history")

if runs.empty:
    st.info("No runs yet.")
else:
    disp = runs.copy()
    disp["started_at"]  = disp["started_at"].dt.strftime("%b %d %H:%M")
    disp["finished_at"] = disp["finished_at"].dt.strftime("%b %d %H:%M")
    disp["duration"] = (
        (runs["finished_at"] - runs["started_at"])
        .dt.total_seconds()
        .apply(lambda x: f"{int(x//60)}m {int(x%60)}s" if pd.notna(x) and x>0 else "—")
    )
    disp["status"] = disp["errors"].apply(
        lambda e: "✓" if (not e or e=="") else "✗ Error")

    st.dataframe(
        disp[["id","started_at","duration","jobs_found","jobs_new","status","triggered_by"]]
        .rename(columns={"id":"#","started_at":"Started","duration":"Duration",
                        "jobs_found":"Found","jobs_new":"New",
                        "status":"Status","triggered_by":"Trigger"}),
        use_container_width=True, hide_index=True)

    if len(runs) > 1:
        fig = px.bar(runs.sort_values("started_at"),
                    x="started_at", y="jobs_new",
                    color_discrete_sequence=["#6366f1"],
                    labels={"started_at":"Run","jobs_new":"New jobs"})
        fig.update_layout(height=200, margin=dict(l=0,r=0,t=10,b=0),
                        plot_bgcolor="rgba(0,0,0,0)",
                        paper_bgcolor="rgba(0,0,0,0)")
        st.plotly_chart(fig, use_container_width=True)

st.divider()
st.subheader("Source performance")
src = load_source_stats()
if not src.empty:
    st.dataframe(src.rename(columns={"job_source":"Source","total":"Total",
                                    "high":"Score ≥ 70","avg_score":"Avg Score"}),
                use_container_width=True, hide_index=True)