# Shows pipeline health: run history, per-source stats, system status.
# PLACEMENT: dashboard/pages/system.py

import streamlit as st
import pandas as pd
import plotly.express as px
import sys, os
from datetime import datetime, timezone

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
from dashboard.db import load_scrape_runs, load_source_breakdown, load_stats


def render():
    st.title("⚙️ System")

    stats = load_stats()
    runs  = load_scrape_runs(limit=20)

    # ── Status indicators ─────────────────────────────────────────────────
    st.subheader("System status")

    s1, s2, s3, s4 = st.columns(4)

    with s1:
        db_ok = stats.get("total_jobs", 0) >= 0
        st.metric("Database", "Connected" if db_ok else "Error")

    with s2:
        if not runs.empty and pd.notna(runs.iloc[0]["started_at"]):
            last_run = runs.iloc[0]["started_at"]
            # Make timezone-aware for comparison
            now = datetime.now(timezone.utc)
            if hasattr(last_run, "tzinfo") and last_run.tzinfo:
                hours_ago = (now - last_run).total_seconds() / 3600
            else:
                hours_ago = 999
            freshness = f"{hours_ago:.1f}h ago"
            freshness_ok = hours_ago < 13
            st.metric("Last run", freshness,
                    delta="on schedule" if freshness_ok else "overdue",
                    delta_color="normal" if freshness_ok else "inverse")
        else:
            st.metric("Last run", "Never")

    with s3:
        st.metric("Total jobs", stats.get("total_jobs", 0))

    with s4:
        unscored = stats.get("unscored_count", 0)
        st.metric("Unscored", unscored,
                delta="needs scoring" if unscored > 0 else "all scored",
                delta_color="inverse" if unscored > 0 else "normal")

    st.divider()

    # ── Scrape run history ────────────────────────────────────────────────
    st.subheader("Scrape run history")

    if runs.empty:
        st.info("No runs yet. Run `python run_scraper.py` to start.")
    else:
        # Format for display
        display_runs = runs.copy()
        display_runs["started_at"]  = display_runs["started_at"].dt.strftime("%b %d %H:%M")
        display_runs["finished_at"] = display_runs["finished_at"].dt.strftime("%b %d %H:%M")
        display_runs["duration"]    = (
            (runs["finished_at"] - runs["started_at"])
            .dt.total_seconds()
            .apply(lambda x: f"{int(x//60)}m {int(x%60)}s" if pd.notna(x) else "—")
        )
        display_runs["status"] = display_runs["errors"].apply(
            lambda e: "✓ Success" if (not e or e == "") else "✗ Error"
        )

        st.dataframe(
            display_runs[[
                "id", "started_at", "duration",
                "jobs_found", "jobs_new", "status", "triggered_by"
            ]].rename(columns={
                "id": "#", "started_at": "Started", "duration": "Duration",
                "jobs_found": "Found", "jobs_new": "New",
                "status": "Status", "triggered_by": "Trigger",
            }),
            use_container_width=True,
            hide_index=True,
        )

        # Jobs found per run chart
        if len(runs) > 1:
            st.subheader("Jobs found per run")
            fig = px.bar(
                runs.sort_values("started_at"),
                x="started_at",
                y="jobs_new",
                color_discrete_sequence=["#6366f1"],
                labels={"started_at": "Run time", "jobs_new": "New jobs"},
            )
            fig.update_layout(
                height=200,
                margin=dict(l=0, r=0, t=10, b=0),
                plot_bgcolor="rgba(0,0,0,0)",
                paper_bgcolor="rgba(0,0,0,0)",
            )
            st.plotly_chart(fig, use_container_width=True)

    st.divider()

    # ── Source performance ────────────────────────────────────────────────
    st.subheader("Source performance")

    source_df = load_source_breakdown()

    if not source_df.empty:
        st.dataframe(
            source_df.rename(columns={
                "job_source": "Source",
                "total_jobs": "Total jobs",
                "high_score_jobs": "Score ≥ 70",
                "avg_score": "Avg score",
            }),
            use_container_width=True,
            hide_index=True,
            column_config={
                "Avg score": st.column_config.ProgressColumn(
                    "Avg score", min_value=0, max_value=100, format="%.1f"
                ),
            },
        )

    st.divider()

    # ── Quick actions ─────────────────────────────────────────────────────
    st.subheader("Quick actions")

    qa1, qa2, qa3 = st.columns(3)

    with qa1:
        st.markdown("**Trigger pipeline**")
        st.caption("Calls the FastAPI server to run scrape+score+enrich")
        if st.button("▶ Run pipeline now", use_container_width=True):
            import requests
            from dotenv import load_dotenv
            load_dotenv()
            api_key = os.getenv("PIPELINE_API_KEY", "devsignal-local-key-2024")
            try:
                with st.spinner("Running pipeline (this takes a few minutes)..."):
                    resp = requests.post(
                        "http://localhost:8000/run-pipeline",
                        headers={"X-Api-Key": api_key},
                        timeout=1800,
                    )
                if resp.status_code == 200:
                    st.success("Pipeline completed!")
                    st.cache_data.clear()
                    st.rerun()
                else:
                    st.error(f"Pipeline failed: {resp.status_code}")
            except requests.exceptions.ConnectionError:
                st.error(
                    "Cannot connect to pipeline API.  \n"
                    "Start it with: `python api/pipeline_server.py`"
                )

    with qa2:
        st.markdown("**API health**")
        st.caption("Checks if the FastAPI pipeline server is running")
        if st.button("⚡ Check API", use_container_width=True):
            import requests
            try:
                resp = requests.get("http://localhost:8000/health", timeout=5)
                if resp.status_code == 200:
                    st.success("API is running ✓")
                else:
                    st.error(f"API returned {resp.status_code}")
            except Exception:
                st.error("API not running. Start: `python api/pipeline_server.py`")

    with qa3:
        st.markdown("**Clear cache**")
        st.caption("Forces all dashboard data to reload from database")
        if st.button("↻ Clear cache", use_container_width=True):
            st.cache_data.clear()
            st.success("Cache cleared!")
            st.rerun()