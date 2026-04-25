import os
import streamlit as st
import pandas as pd
import plotly.express as px
import plotly.graph_objects as go
from sqlalchemy import create_engine, text

# ── DB connection ─────────────────────────────────────────────────────────
def get_engine():
    try:
        url = st.secrets["database"]["url"]
    except Exception:
        from dotenv import load_dotenv
        load_dotenv()
        url = os.getenv("DATABASE_URL",
                        "postgresql://radar:radar_pass@localhost:5432/devsignal")
    return create_engine(url, pool_pre_ping=True)

@st.cache_data(ttl=300)
def load_stats():
    sql = text("""
        SELECT
            COUNT(*)                                              AS total_jobs,
            COUNT(*) FILTER (WHERE applied = true)               AS total_applied,
            COUNT(*) FILTER (WHERE response_status = 'Replied')  AS total_responses,
            COUNT(*) FILTER (WHERE interview_stage != '')         AS total_interviews,
            ROUND(AVG(opportunity_score)::numeric, 1)            AS avg_score,
            COUNT(*) FILTER (WHERE opportunity_score >= 70)      AS high_score_count,
            COUNT(*) FILTER (WHERE opportunity_score IS NULL)    AS unscored_count
        FROM opportunities
    """)
    with get_engine().connect() as conn:
        row = conn.execute(sql).fetchone()
    return dict(row._mapping) if row else {}

@st.cache_data(ttl=300)
def load_scores():
    sql = text("SELECT opportunity_score FROM opportunities WHERE opportunity_score IS NOT NULL")
    with get_engine().connect() as conn:
        return pd.read_sql(sql, conn)

@st.cache_data(ttl=300)
def load_sources():
    sql = text("""
        SELECT job_source,
            COUNT(*) AS total_jobs,
            ROUND(AVG(opportunity_score)::numeric,1) AS avg_score
        FROM opportunities GROUP BY job_source ORDER BY total_jobs DESC
    """)
    with get_engine().connect() as conn:
        return pd.read_sql(sql, conn)

@st.cache_data(ttl=300)
def load_recent():
    sql = text("""
        SELECT company, role, remote, visa_sponsorship, job_source,
            opportunity_score, apply_link, applied
        FROM opportunities
        WHERE opportunity_score IS NOT NULL
        ORDER BY opportunity_score DESC NULLS LAST
        LIMIT 10
    """)
    with get_engine().connect() as conn:
        return pd.read_sql(sql, conn)

# ── Page ──────────────────────────────────────────────────────────────────
st.title("📡 DevSignal — Overview")

try:
    stats = load_stats()
except Exception as e:
    st.error(f"Database connection failed: {e}")
    st.stop()

c1,c2,c3,c4,c5,c6 = st.columns(6)
c1.metric("Jobs Found",  int(stats.get("total_jobs", 0)))
c2.metric("Score ≥ 70",  int(stats.get("high_score_count", 0)))
c3.metric("Applied",     int(stats.get("total_applied", 0)))
c4.metric("Responses",   int(stats.get("total_responses", 0)))
c5.metric("Interviews",  int(stats.get("total_interviews", 0)))
c6.metric("Avg Score",   f"{float(stats.get('avg_score') or 0):.1f}")

st.divider()
left, right = st.columns(2)

with left:
    st.subheader("Score distribution")
    score_df = load_scores()
    if not score_df.empty:
        fig = px.histogram(score_df, x="opportunity_score", nbins=20,
                        color_discrete_sequence=["#6366f1"],
                        labels={"opportunity_score": "Score"})
        fig.update_layout(height=260, margin=dict(l=0,r=0,t=10,b=0),
                        plot_bgcolor="rgba(0,0,0,0)",
                        paper_bgcolor="rgba(0,0,0,0)", showlegend=False)
        fig.add_vline(x=70, line_dash="dash", line_color="#22c55e",
                    annotation_text="threshold")
        st.plotly_chart(fig, use_container_width=True)

with right:
    st.subheader("Jobs by source")
    src_df = load_sources()
    if not src_df.empty:
        fig = px.bar(src_df, x="total_jobs", y="job_source", orientation="h",
                    color="avg_score", color_continuous_scale="Viridis",
                    text="total_jobs",
                    labels={"total_jobs":"Jobs","job_source":"","avg_score":"Avg"})
        fig.update_traces(textposition="outside")
        fig.update_layout(height=260, margin=dict(l=0,r=0,t=10,b=0),
                        plot_bgcolor="rgba(0,0,0,0)",
                        paper_bgcolor="rgba(0,0,0,0)",
                        coloraxis_showscale=False)
        st.plotly_chart(fig, use_container_width=True)

st.divider()
st.subheader("Application funnel")
fig = go.Figure(go.Funnel(
    y=["Discovered","Score ≥ 70","Applied","Responded","Interviewed"],
    x=[int(stats.get("total_jobs",0)), int(stats.get("high_score_count",0)),
    int(stats.get("total_applied",0)), int(stats.get("total_responses",0)),
    int(stats.get("total_interviews",0))],
    textinfo="value+percent initial",
    marker_color=["#6366f1","#8b5cf6","#a78bfa","#22c55e","#16a34a"],
))
fig.update_layout(height=220, margin=dict(l=0,r=0,t=10,b=0),
                plot_bgcolor="rgba(0,0,0,0)", paper_bgcolor="rgba(0,0,0,0)")
st.plotly_chart(fig, use_container_width=True)

st.divider()
st.subheader("Recent top opportunities")
recent = load_recent()
if recent.empty:
    st.caption("No scored jobs yet.")
else:
    for _, row in recent.iterrows():
        score = int(row["opportunity_score"]) if pd.notna(row["opportunity_score"]) else 0
        cls   = "score-high" if score>=70 else "score-mid" if score>=50 else "score-low"
        remote_badge = "🌍 Remote" if row["remote"]=="Yes" else "🏢 On-site"
        visa_badge   = " · ✈️ Visa" if row["visa_sponsorship"]=="Yes" else ""
        applied_tag  = " ✓" if row["applied"] else ""
        sc, info, lnk = st.columns([1,8,2])
        sc.markdown(f'<span class="{cls}">{score}</span>', unsafe_allow_html=True)
        info.markdown(
            f"**{row['company']}** — {row['role']}{applied_tag}  \n"
            f"<small>{remote_badge}{visa_badge} · {row['job_source']}</small>",
            unsafe_allow_html=True)
        if row["apply_link"]:
            lnk.link_button("Apply →", row["apply_link"], use_container_width=True)