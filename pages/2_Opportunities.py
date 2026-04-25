import os
import json
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
def load_jobs(min_score=0, remote_only=False, unapplied_only=False):
    conditions = ["1=1"]
    params = {}
    if min_score > 0:
        conditions.append("opportunity_score >= :min_score")
        params["min_score"] = min_score
    if remote_only:
        conditions.append("remote = 'Yes'")
    if unapplied_only:
        conditions.append("applied = false")
    where = " AND ".join(conditions)
    sql = text(f"""
        SELECT id, company, role, location, remote, visa_sponsorship,
               experience_req, tech_stack, job_source, apply_link,
               opportunity_score, score_breakdown, outreach_message,
               recruiter_name, recruiter_role, linkedin_profile, email,
               applied, response_status, interview_stage,
               date_found, description_raw
        FROM opportunities WHERE {where}
        ORDER BY opportunity_score DESC NULLS LAST, date_found DESC
    """)
    with get_engine().connect() as conn:
        df = pd.read_sql(sql, conn, params=params)
    df["date_found"] = pd.to_datetime(df["date_found"], utc=True, errors="coerce")
    return df

def update_status(job_id, applied, response, stage):
    sql = text("""
        UPDATE opportunities SET applied=:applied,
        response_status=:response_status, interview_stage=:interview_stage
        WHERE id=:job_id
    """)
    try:
        with get_engine().begin() as conn:
            conn.execute(sql, {"applied":applied,"response_status":response,
                               "interview_stage":stage,"job_id":job_id})
        load_jobs.clear()
        return True
    except Exception as e:
        st.error(f"Update failed: {e}")
        return False

# ── Page ──────────────────────────────────────────────────────────────────
st.title("🎯 Opportunities")

with st.expander("Filters", expanded=True):
    f1,f2,f3,f4 = st.columns(4)
    min_score      = f1.slider("Min score", 0, 100, 0, step=5)
    remote_only    = f2.checkbox("Remote only")
    unapplied_only = f3.checkbox("Unapplied only")
    source_filter  = f4.selectbox("Source",
        ["All sources","HackerNews","RemoteOK","Remotive","YC WorkAtAStartup"])

try:
    df = load_jobs(min_score, remote_only, unapplied_only)
except Exception as e:
    st.error(f"Database error: {e}")
    st.stop()

if source_filter != "All sources":
    df = df[df["job_source"] == source_filter]

st.caption(f"Showing {len(df)} opportunities")

if df.empty:
    st.info("No opportunities match your filters.")
    st.stop()

disp = df[["company","role","location","remote","visa_sponsorship",
           "opportunity_score","job_source","applied","response_status",
           "date_found"]].copy()
disp["date_found"] = disp["date_found"].dt.strftime("%b %d")
disp["opportunity_score"] = disp["opportunity_score"].fillna("—")
disp.columns = ["Company","Role","Location","Remote","Visa",
                "Score","Source","Applied","Response","Found"]

event = st.dataframe(disp, use_container_width=True, hide_index=True,
    on_select="rerun", selection_mode="single-row",
    column_config={
        "Score": st.column_config.ProgressColumn("Score",min_value=0,max_value=100,format="%d"),
        "Applied": st.column_config.CheckboxColumn("Applied"),
    })

selected = event.selection.rows if hasattr(event,"selection") else []
if selected:
    row    = df.iloc[selected[0]]
    job_id = int(row["id"])
    st.divider()
    st.subheader(f"{row['company']} — {row['role']}")
    d1,d2,d3,d4 = st.columns(4)
    d1.metric("Score",  row["opportunity_score"] or "—")
    d2.metric("Remote", row["remote"])
    d3.metric("Visa",   row["visa_sponsorship"])
    d4.metric("Source", row["job_source"])
    if row["description_raw"]:
        with st.expander("Description"):
            st.write(str(row["description_raw"])[:800])
    if row["outreach_message"]:
        st.markdown("**Outreach message:**")
        st.code(row["outreach_message"], language=None)
    if row["recruiter_name"]:
        parts = [f"👤 {row['recruiter_name']}"]
        if row["linkedin_profile"]:
            parts.append(f"[LinkedIn]({row['linkedin_profile']})")
        if row["email"]:
            parts.append(f"📧 `{row['email']}`")
        st.markdown("  ".join(parts))
    if row["apply_link"]:
        st.link_button("Open application →", row["apply_link"])
    st.divider()
    st.markdown("**Track your application:**")
    tc1,tc2,tc3,tc4 = st.columns([1,2,2,1])
    applied  = tc1.checkbox("Applied", value=bool(row["applied"]), key=f"a_{job_id}")
    response = tc2.selectbox("Response",
        ["","No response","Viewed","Replied","Rejected"],
        index=["","No response","Viewed","Replied","Rejected"].index(row["response_status"] or ""),
        key=f"r_{job_id}")
    stage    = tc3.selectbox("Stage",
        ["","Phone screen","Technical","Final round","Offer","Rejected"],
        index=["","Phone screen","Technical","Final round","Offer","Rejected"].index(row["interview_stage"] or ""),
        key=f"s_{job_id}")
    tc4.markdown("<br>", unsafe_allow_html=True)
    if tc4.button("Save", key=f"sv_{job_id}", type="primary"):
        if update_status(job_id, applied, response, stage):
            st.success("Saved!")
            st.rerun()
    if row["score_breakdown"]:
        with st.expander("Score breakdown"):
            try:
                bd = json.loads(row["score_breakdown"]) if isinstance(row["score_breakdown"],str) else row["score_breakdown"]
                if bd:
                    bd_df = pd.DataFrame([{"Factor":k.replace("_"," ").title(),"Points":v} for k,v in bd.items()])
                    st.bar_chart(bd_df.set_index("Factor"))
            except Exception:
                pass