# Filterable job table with inline application tracking.
# PLACEMENT: dashboard/pages/opportunities.py

import streamlit as st
import pandas as pd
import json
import sys, os

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
from dashboard.db import load_opportunities, update_application_status


def render():
    st.title("🎯 Opportunities")

    # ── Filters sidebar ───────────────────────────────────────────────────
    with st.expander("Filters", expanded=True):
        fcol1, fcol2, fcol3, fcol4 = st.columns(4)

        with fcol1:
            min_score = st.slider("Min score", 0, 100, 0, step=5)
        with fcol2:
            remote_only = st.checkbox("Remote only")
        with fcol3:
            unapplied_only = st.checkbox("Unapplied only")
        with fcol4:
            source_filter = st.selectbox(
                "Source",
                ["All sources", "HackerNews", "RemoteOK",
                "Remotive", "YC WorkAtAStartup"],
            )

    # ── Load + filter ─────────────────────────────────────────────────────
    df = load_opportunities(
        min_score=min_score,
        remote_only=remote_only,
        unapplied_only=unapplied_only,
    )

    if source_filter != "All sources":
        df = df[df["job_source"] == source_filter]

    st.caption(f"Showing {len(df)} opportunities")

    if df.empty:
        st.info("No opportunities match your filters.")
        return

    # ── Display columns ───────────────────────────────────────────────────
    display_df = df[[
        "company", "role", "location", "remote",
        "visa_sponsorship", "opportunity_score",
        "job_source", "applied", "response_status",
        "date_found",
    ]].copy()

    display_df["date_found"] = display_df["date_found"].dt.strftime("%b %d")
    display_df["opportunity_score"] = display_df["opportunity_score"].fillna("—")
    display_df.columns = [
        "Company", "Role", "Location", "Remote",
        "Visa", "Score", "Source", "Applied",
        "Response", "Found",
    ]

    # ── Render table with selection ───────────────────────────────────────
    event = st.dataframe(
        display_df,
        use_container_width=True,
        hide_index=True,
        on_select="rerun",
        selection_mode="single-row",
        column_config={
            "Score": st.column_config.ProgressColumn(
                "Score", min_value=0, max_value=100, format="%d"
            ),
            "Applied": st.column_config.CheckboxColumn("Applied"),
        },
    )

    # ── Detail panel for selected row ─────────────────────────────────────
    selected_rows = event.selection.rows if hasattr(event, "selection") else []

    if selected_rows:
        idx    = selected_rows[0]
        job    = df.iloc[idx]
        job_id = int(job["id"])

        st.divider()
        st.subheader(f"{job['company']} — {job['role']}")

        d1, d2, d3, d4 = st.columns(4)
        d1.metric("Score",  job["opportunity_score"] or "—")
        d2.metric("Remote", job["remote"])
        d3.metric("Visa",   job["visa_sponsorship"])
        d4.metric("Source", job["job_source"])

        # Description
        if job["description_raw"]:
            with st.expander("Job description"):
                st.write(job["description_raw"][:800])

        # Outreach message
        if job["outreach_message"]:
            st.markdown("**Generated outreach message:**")
            st.code(job["outreach_message"], language=None)

        # Recruiter
        if job["recruiter_name"]:
            st.markdown(
                f"**Recruiter:** {job['recruiter_name']}  \n"
                f"**Role:** {job.get('recruiter_role', '')}  \n"
                + (f"**LinkedIn:** [{job['linkedin_profile']}]({job['linkedin_profile']})"
                   if job["linkedin_profile"] else "")
            )

        # Apply button
        if job["apply_link"]:
            st.link_button("Open application →", job["apply_link"])

        # ── Application tracking ──────────────────────────────────────────
        st.divider()
        st.markdown("**Track your application:**")

        tc1, tc2, tc3, tc4 = st.columns([1, 2, 2, 1])

        with tc1:
            applied = st.checkbox(
                "Applied", value=bool(job["applied"]), key=f"applied_{job_id}"
            )
        with tc2:
            response = st.selectbox(
                "Response",
                ["", "No response", "Viewed", "Replied", "Rejected"],
                index=["", "No response", "Viewed",
                    "Replied", "Rejected"].index(
                    job["response_status"] or ""
                ),
                key=f"response_{job_id}",
            )
        with tc3:
            stage = st.selectbox(
                "Interview stage",
                ["", "Phone screen", "Technical",
                "Final round", "Offer", "Rejected"],
                index=["", "Phone screen", "Technical",
                    "Final round", "Offer", "Rejected"].index(
                    job["interview_stage"] or ""
                ),
                key=f"stage_{job_id}",
            )
        with tc4:
            st.markdown("<br>", unsafe_allow_html=True)
            if st.button("Save", key=f"save_{job_id}", type="primary"):
                if update_application_status(job_id, applied, response, stage):
                    st.success("Saved!")
                    st.rerun()

        # Score breakdown
        if job["score_breakdown"]:
            with st.expander("Score breakdown"):
                try:
                    breakdown = (
                        json.loads(job["score_breakdown"])
                        if isinstance(job["score_breakdown"], str)
                        else job["score_breakdown"]
                    )
                    if breakdown:
                        bd_df = pd.DataFrame([
                            {"Factor": k.replace("_", " ").title(), "Points": v}
                            for k, v in breakdown.items()
                        ])
                        st.bar_chart(bd_df.set_index("Factor"))
                except Exception:
                    pass