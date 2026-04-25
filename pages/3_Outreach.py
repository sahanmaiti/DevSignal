import os
import streamlit as st
import pandas as pd
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
def load_outreach():
    sql = text("""
        SELECT company, role, opportunity_score, outreach_message,
            recruiter_name, linkedin_profile, email, apply_link, applied
        FROM opportunities
        WHERE outreach_message IS NOT NULL AND outreach_message != ''
        ORDER BY opportunity_score DESC NULLS LAST
    """)
    with get_engine().connect() as conn:
        return pd.read_sql(sql, conn)

# ── Page ──────────────────────────────────────────────────────────────────
st.title("✉️ Outreach")
st.caption("Personalized recruiter messages for your top opportunities.")

try:
    df = load_outreach()
except Exception as e:
    st.error(f"Database error: {e}")
    st.stop()

if df.empty:
    st.info("No outreach messages yet. Run `python run_scorer.py` to generate them.")
    st.stop()

st.markdown(f"**{len(df)} messages ready**")
st.divider()

for _, row in df.iterrows():
    score   = int(row["opportunity_score"]) if pd.notna(row["opportunity_score"]) else 0
    applied = " ✓" if row["applied"] else ""
    st.markdown(f"### {row['company']}{applied}  \n*{row['role']}* · Score: **{score}**")

    parts = []
    if row["recruiter_name"]: parts.append(f"👤 {row['recruiter_name']}")
    if row["linkedin_profile"]: parts.append(f"[LinkedIn]({row['linkedin_profile']})")
    if row["email"]: parts.append(f"📧 `{row['email']}`")
    if parts:
        st.markdown("  ".join(parts))

    st.code(row["outreach_message"], language=None)

    b1, b2, _ = st.columns([2,2,6])
    if row["apply_link"]:
        b1.link_button("Apply →", row["apply_link"])
    if row["linkedin_profile"]:
        b2.link_button("LinkedIn →", row["linkedin_profile"])
    st.divider()