# PURPOSE:
#   Overview page — KPI cards, score distribution, source breakdown,
#   and recent opportunities feed.
#
# PLACEMENT: dashboard/pages/overview.py

import streamlit as st
import plotly.express as px
import plotly.graph_objects as go
import pandas as pd
from datetime import datetime, timezone, timedelta

import sys, os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))

from dashboard.db import (
    load_stats, load_opportunities,
    load_source_breakdown, load_score_distribution,
)


def render():
    st.title("📡 DevSignal — Overview")

    # ── Load data ─────────────────────────────────────────────────────────
    stats  = load_stats()
    df     = load_opportunities()

    if df.empty:
        st.info("No data yet. Run `python run_scraper.py` to populate the database.")
        return

    # ── KPI row ───────────────────────────────────────────────────────────
    col1, col2, col3, col4, col5, col6 = st.columns(6)

    with col1:
        st.metric("Jobs Found",    stats.get("total_jobs", 0))
    with col2:
        st.metric("Score ≥ 70",    stats.get("high_score_count", 0))
    with col3:
        st.metric("Applied",       stats.get("total_applied", 0))
    with col4:
        st.metric("Responses",     stats.get("total_responses", 0))
    with col5:
        st.metric("Interviews",    stats.get("total_interviews", 0))
    with col6:
        avg = stats.get("avg_score") or 0
        st.metric("Avg Score",     f"{float(avg):.1f}")

    st.divider()

    # ── Charts row ────────────────────────────────────────────────────────
    left, right = st.columns(2)

    # Score distribution
    with left:
        st.subheader("Score distribution")
        score_df = load_score_distribution()

        if not score_df.empty:
            fig = px.histogram(
                score_df,
                x="opportunity_score",
                nbins=20,
                color_discrete_sequence=["#6366f1"],
                labels={"opportunity_score": "Score", "count": "Jobs"},
            )
            fig.update_layout(
                margin=dict(l=0, r=0, t=10, b=0),
                height=260,
                showlegend=False,
                plot_bgcolor="rgba(0,0,0,0)",
                paper_bgcolor="rgba(0,0,0,0)",
                xaxis=dict(range=[0, 100]),
            )
            fig.add_vline(
                x=70, line_dash="dash",
                line_color="#22c55e",
                annotation_text="threshold",
                annotation_position="top right",
            )
            st.plotly_chart(fig, use_container_width=True)
        else:
            st.caption("No scored jobs yet.")

    # Source breakdown
    with right:
        st.subheader("Jobs by source")
        source_df = load_source_breakdown()

        if not source_df.empty:
            fig = px.bar(
                source_df,
                x="total_jobs",
                y="job_source",
                orientation="h",
                color="avg_score",
                color_continuous_scale="Viridis",
                labels={
                    "total_jobs": "Jobs",
                    "job_source": "",
                    "avg_score": "Avg score",
                },
                text="total_jobs",
            )
            fig.update_traces(textposition="outside")
            fig.update_layout(
                margin=dict(l=0, r=0, t=10, b=0),
                height=260,
                plot_bgcolor="rgba(0,0,0,0)",
                paper_bgcolor="rgba(0,0,0,0)",
                coloraxis_showscale=False,
            )
            st.plotly_chart(fig, use_container_width=True)
        else:
            st.caption("No source data yet.")

    st.divider()

    # ── Application funnel ────────────────────────────────────────────────
    st.subheader("Application funnel")

    funnel_data = {
        "Stage":  ["Discovered", "Score ≥ 70", "Applied", "Responded", "Interviewed"],
        "Count":  [
            int(stats.get("total_jobs", 0)),
            int(stats.get("high_score_count", 0)),
            int(stats.get("total_applied", 0)),
            int(stats.get("total_responses", 0)),
            int(stats.get("total_interviews", 0)),
        ],
    }

    fig = go.Figure(go.Funnel(
        y=funnel_data["Stage"],
        x=funnel_data["Count"],
        textinfo="value+percent initial",
        marker_color=["#6366f1", "#8b5cf6", "#a78bfa", "#22c55e", "#16a34a"],
    ))
    fig.update_layout(
        margin=dict(l=0, r=0, t=10, b=0),
        height=220,
        plot_bgcolor="rgba(0,0,0,0)",
        paper_bgcolor="rgba(0,0,0,0)",
    )
    st.plotly_chart(fig, use_container_width=True)

    st.divider()

    # ── Recent high-score jobs ────────────────────────────────────────────
    st.subheader("Recent top opportunities")

    recent = df[df["opportunity_score"].notna()].head(8)

    if recent.empty:
        st.caption("No scored jobs yet.")
    else:
        for _, row in recent.iterrows():
            score = int(row["opportunity_score"]) if pd.notna(row["opportunity_score"]) else 0

            score_color = (
                "score-high" if score >= 70
                else "score-mid" if score >= 50
                else "score-low"
            )

            remote_badge = "🌍 Remote" if row["remote"] == "Yes" else "🏢 On-site"
            visa_badge   = " · ✈️ Visa" if row["visa_sponsorship"] == "Yes" else ""

            col_score, col_info, col_link = st.columns([1, 8, 2])

            with col_score:
                st.markdown(
                    f'<span class="{score_color}">{score}</span>',
                    unsafe_allow_html=True
                )
            with col_info:
                applied_tag = " ✓ Applied" if row["applied"] else ""
                st.markdown(
                    f"**{row['company']}** — {row['role']}  \n"
                    f"<small>{remote_badge}{visa_badge} · {row['job_source']}{applied_tag}</small>",
                    unsafe_allow_html=True,
                )
            with col_link:
                if row["apply_link"]:
                    st.link_button("Apply →", row["apply_link"],
                                use_container_width=True)