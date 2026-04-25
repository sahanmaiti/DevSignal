# PURPOSE:
#   Main entry point for the DevSignal Streamlit dashboard.
#   Handles page routing via sidebar navigation.
#
# RUN LOCALLY:
#   streamlit run dashboard/app.py
#
# PLACEMENT: dashboard/app.py

import streamlit as st
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# ── Page config — must be the very first Streamlit call ──────────────────
st.set_page_config(
    page_title="DevSignal",
    page_icon="📡",
    layout="wide",
    initial_sidebar_state="expanded",
)

# ── Minimal custom CSS ────────────────────────────────────────────────────
st.markdown("""
<style>
    /* Tighten up metric card padding */
    div[data-testid="metric-container"] {
        background: rgba(255,255,255,0.05);
        border: 1px solid rgba(255,255,255,0.1);
        border-radius: 8px;
        padding: 12px 16px;
    }
    /* Score badge colours */
    .score-high   { color: #22c55e; font-weight: 600; }
    .score-mid    { color: #f59e0b; font-weight: 600; }
    .score-low    { color: #ef4444; font-weight: 600; }
    /* Remove default padding on main block */
    .block-container { padding-top: 1.5rem; }
</style>
""", unsafe_allow_html=True)


# ── Sidebar navigation ────────────────────────────────────────────────────
with st.sidebar:
    st.markdown("## 📡 DevSignal")
    st.markdown("*iOS Internship Radar*")
    st.divider()

    page = st.radio(
        "Navigate",
        options=[
            "Overview",
            "Opportunities",
            "Outreach",
            "System",
        ],
        label_visibility="collapsed",
    )

    st.divider()
    st.caption("Refreshes every 5 min")
    st.caption("Built with Python + Groq + n8n")

    # Manual refresh button
    if st.button("↻  Refresh data", use_container_width=True):
        st.cache_data.clear()
        st.rerun()


# ── Page routing ──────────────────────────────────────────────────────────
if page == "Overview":
    from dashboard.pages.overview import render
    render()

elif page == "Opportunities":
    from dashboard.pages.opportunities import render
    render()

elif page == "Outreach":
    from dashboard.pages.outreach import render
    render()

elif page == "System":
    from dashboard.pages.system import render
    render()