# Shows generated outreach messages for top-scored jobs.
# PLACEMENT: dashboard/pages/outreach.py

import streamlit as st
import sys, os

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
from dashboard.db import load_opportunities


def render():
    st.title("✉️ Outreach")
    st.caption("Personalized recruiter messages for your top opportunities.")

    # Load jobs that have outreach messages
    df = load_opportunities(min_score=60)
    df_outreach = df[df["outreach_message"].notna() & (df["outreach_message"] != "")]

    if df_outreach.empty:
        st.info(
            "No outreach messages generated yet.  \n"
            "Run `python run_scorer.py` to generate messages for scored jobs."
        )
        return

    st.markdown(f"**{len(df_outreach)} messages ready**")
    st.divider()

    # Sort by score
    df_outreach = df_outreach.sort_values("opportunity_score", ascending=False)

    for _, job in df_outreach.iterrows():
        score    = int(job["opportunity_score"]) if job["opportunity_score"] else 0
        company  = job["company"]
        role     = job["role"]
        message  = job["outreach_message"]
        recruiter = job.get("recruiter_name", "")
        linkedin  = job.get("linkedin_profile", "")
        email     = job.get("email", "")
        applied   = job.get("applied", False)

        # Card header
        applied_tag = " ✓" if applied else ""
        st.markdown(
            f"### {company}{applied_tag}  \n"
            f"*{role}* · Score: **{score}**"
        )

        # Recruiter info if available
        if recruiter or linkedin or email:
            recruiter_parts = []
            if recruiter:
                recruiter_parts.append(f"👤 {recruiter}")
            if linkedin:
                recruiter_parts.append(f"[LinkedIn]({linkedin})")
            if email:
                recruiter_parts.append(f"📧 `{email}`")
            st.markdown("  ".join(recruiter_parts))

        # Message — copyable code block
        st.code(message, language=None)

        # Action buttons
        btn1, btn2, btn3 = st.columns([2, 2, 6])
        with btn1:
            if job["apply_link"]:
                st.link_button("Apply →", job["apply_link"])
        with btn2:
            if linkedin:
                st.link_button("LinkedIn →", linkedin)

        st.divider()