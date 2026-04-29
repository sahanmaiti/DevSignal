# dashboard/pages/outreach.py
# Clean production version for local + Streamlit Cloud

import os
import sys
import streamlit as st
import pandas as pd

sys.path.insert(
    0,
    os.path.dirname(
        os.path.dirname(
            os.path.dirname(os.path.abspath(__file__))
        )
    )
)

from dashboard.db import (
    load_outreach_jobs,
    load_stats,
    clear_all_caches
)


def render():
    st.title("✉️ Outreach")
    st.caption("Personalized recruiter messages for your top opportunities.")

    # Refresh button
    if st.button("↻ Refresh", key="outreach_refresh"):
        clear_all_caches()
        st.rerun()

    # Stats
    stats = load_stats()
    total_outreach = int(stats.get("outreach_count", 0))

    # No outreach messages yet
    if total_outreach == 0:
        st.warning("No outreach messages found.")

        with st.expander("Debug"):
            st.write(f"Total jobs: {stats.get('total_jobs', 0)}")
            st.write(f"Unscored jobs: {stats.get('unscored_count', 0)}")

        return

    # Load outreach jobs
    df = load_outreach_jobs()

    if df.empty:
        st.info("No outreach jobs returned from database.")
        return

    st.markdown(f"**{len(df)} messages ready**")
    st.divider()

    # Sort highest first
    df = df.sort_values(
        by="opportunity_score",
        ascending=False,
        na_position="last"
    )

    for _, row in df.iterrows():

        company = (
            row["company"]
            if pd.notna(row["company"])
            else "Unknown"
        )

        role = (
            row["role"]
            if pd.notna(row["role"])
            else ""
        )

        score = (
            int(row["opportunity_score"])
            if pd.notna(row["opportunity_score"])
            else 0
        )

        message = (
            row["outreach_message"]
            if pd.notna(row["outreach_message"])
            else ""
        )

        recruiter_name = (
            row["recruiter_name"]
            if "recruiter_name" in row
            and pd.notna(row["recruiter_name"])
            else ""
        )

        linkedin = (
            row["linkedin_profile"]
            if "linkedin_profile" in row
            and pd.notna(row["linkedin_profile"])
            else ""
        )

        email = (
            row["email"]
            if "email" in row
            and pd.notna(row["email"])
            else ""
        )

        apply_link = (
            row["apply_link"]
            if "apply_link" in row
            and pd.notna(row["apply_link"])
            else ""
        )

        applied = False
        if "applied" in row and pd.notna(row["applied"]):
            applied = bool(row["applied"])

        # Skip weak messages
        if not message or len(str(message).strip()) < 10:
            continue

        # Header
        applied_tag = " ✓" if applied else ""

        st.markdown(f"### {company}{applied_tag}")
        st.caption(f"{role} • Score: {score}")

        # Recruiter info
        meta = []

        if recruiter_name:
            meta.append(f"👤 {recruiter_name}")

        if linkedin:
            meta.append(f"[LinkedIn]({linkedin})")

        if email:
            meta.append(f"📧 `{email}`")

        if meta:
            st.markdown(" • ".join(meta))

        # Message
        st.code(message, language=None)

        # Buttons
        col1, col2, _ = st.columns([2, 2, 6])

        if apply_link:
            col1.link_button("Apply →", apply_link)

        if linkedin:
            col2.link_button("LinkedIn →", linkedin)

        st.divider()