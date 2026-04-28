# dashboard/app.py
import streamlit as st
from streamlit_autorefresh import st_autorefresh
import sys, os
sys.path.insert(...)

st.set_page_config(
    page_title="DevSignal",
    page_icon="📡",
    layout="wide",
    initial_sidebar_state="expanded",
)

st_autorefresh(interval=300000, key="dashboard_refresh")


st.markdown("""
<style>
div[data-testid="metric-container"] {
    background: rgba(255,255,255,0.05);
    border: 1px solid rgba(255,255,255,0.1);
    border-radius: 8px;
    padding: 12px 16px;
}
.score-high { color: #22c55e; font-weight: 600; }
.score-mid  { color: #f59e0b; font-weight: 600; }
.score-low  { color: #ef4444; font-weight: 600; }
.block-container { padding-top: 1.5rem; }
</style>
""", unsafe_allow_html=True)

# Sidebar branding — shows on every page
with st.sidebar:
    st.markdown("## 📡 DevSignal")
    st.markdown("*iOS Internship Radar*")
    st.divider()
    st.caption("Refreshes every 5 min")
    st.caption("Built with Python + Groq + n8n")
    if st.button("↻  Refresh data", use_container_width=True):
        from dashboard.db import clear_all_caches
        clear_all_caches()
        st.rerun()

# Default landing page shows Overview
from dashboard.pages.overview import render
render()