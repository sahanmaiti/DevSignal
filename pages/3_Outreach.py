# dashboard/pages/outreach.py — fixed

import os, sys
import streamlit as st
import pandas as pd

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
from dashboard.db import load_outreach_jobs, load_stats, clear_all_caches


def render():
    st.title("✉️ Outreach")
    st.caption("Personalized recruiter messages for your top opportunities.")

    # Force refresh button at the top
    if st.button("↻ Refresh", key="outreach_refresh"):
        clear_all_caches()
        st.rerun()

    stats = load_stats()
    total_outreach = int(stats.get("outreach_count", 0))

    if total_outreach == 0:
        st.warning("No outreach messages in the database yet.")
        st.markdown("""
        **To generate outreach messages:**
```bash
        python run_scorer.py
```
        Messages are generated automatically for all jobs scoring ≥ 65.
        """)

        # Show diagnostic info
        with st.expander("Debug: what's in the database?"):
            total  = int(stats.get("total_jobs", 0))
            unscored = int(stats.get("unscored_count", 0))
            st.write(f"Total jobs stored: **{total}**")
            st.write(f"Unscored jobs: **{unscored}**")
            if total > 0 and unscored == total:
                st.error("All jobs are unscored. Run `python run_scorer.py` first.")
            elif total > 0 and unscored == 0:
                st.info("All jobs are scored but none have outreach messages. "
                        "This means scores were written before outreach generation was added. "
                        "Run `python run_scorer.py` again to regenerate with outreach.")
            elif total == 0:
                st.error("No jobs in database. Run `python run_scraper.py` first.")
        return

    df = load_outreach_jobs()

    if df.empty:
        st.info("No outreach messages found.")
        return

    st.markdown(f"**{len(df)} messages ready**")
    st.divider()

    for _, row in df.iterrows():
        score    = int(row["opportunity_score"]) if pd.notna(row["opportunity_score"]) else 0
        applied  = " ✓" if row.get("applied") else ""
        company  = row.get("company", "Unknown")
        role     = row.get("role", "")
        message  = row.get("outreach_message", "")

        if not message or len(message.strip()) < 10:
            continue

        st.markdown(f"### {company}{applied}")
        st.markdown(f"*{role}* · Score: **{score}**")

        recruiter_parts = []
        if row.get("recruiter_name"):
            recruiter_parts.append(f"👤 {row['recruiter_name']}")
        if row.get("linkedin_profile"):
            recruiter_parts.append(f"[LinkedIn]({row['linkedin_profile']})")
        if row.get("email"):
            recruiter_parts.append(f"📧 `{row['email']}`")
        if recruiter_parts:
            st.markdown("  ".join(recruiter_parts))

        st.code(message, language=None)

        b1, b2, _ = st.columns([2, 2, 6])
        if row.get("apply_link"):
            b1.link_button("Apply →", row["apply_link"])
        if row.get("linkedin_profile"):
            b2.link_button("LinkedIn →", row["linkedin_profile"])

        st.divider()