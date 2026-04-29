# dashboard/app.py

import streamlit as st
from streamlit_autorefresh import st_autorefresh
import os
import sys

# ─────────────────────────────────────────────────────────────
# ADD PROJECT ROOT TO PYTHON PATH
# ─────────────────────────────────────────────────────────────
sys.path.insert(
    0,
    os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
)

# ─────────────────────────────────────────────────────────────
# PAGE CONFIG
# ─────────────────────────────────────────────────────────────
st.set_page_config(
    page_title="DevSignal",
    page_icon="📡",
    layout="wide",
    initial_sidebar_state="expanded",
    menu_items=None
)

# ─────────────────────────────────────────────────────────────
# HIDE DEFAULT STREAMLIT MULTIPAGE NAV
# ─────────────────────────────────────────────────────────────
st.markdown("""
<style>
[data-testid="stSidebarNav"] {
    display: none;
}
</style>
""", unsafe_allow_html=True)

# ─────────────────────────────────────────────────────────────
# AUTO REFRESH EVERY 5 MINUTES
# ─────────────────────────────────────────────────────────────
st_autorefresh(interval=300000, key="dashboard_refresh")

# ─────────────────────────────────────────────────────────────
# GLOBAL CUSTOM STYLING
# ─────────────────────────────────────────────────────────────
st.markdown("""
<style>

/* Main spacing */
.block-container {
    padding-top: 1.5rem;
    padding-bottom: 2rem;
}

/* Metric cards */
div[data-testid="metric-container"] {
    background: rgba(255,255,255,0.04);
    border: 1px solid rgba(255,255,255,0.08);
    border-radius: 12px;
    padding: 14px 18px;
}

/* Score colors */
.score-high {
    color: #22c55e;
    font-weight: 700;
}

.score-mid {
    color: #f59e0b;
    font-weight: 700;
}

.score-low {
    color: #ef4444;
    font-weight: 700;
}

/* Sidebar spacing */
section[data-testid="stSidebar"] .block-container {
    padding-top: 1rem;
}

/* Buttons */
.stButton > button {
    border-radius: 10px;
}

/* Radio labels */
div[role="radiogroup"] label {
    margin-bottom: 0.35rem;
}

</style>
""", unsafe_allow_html=True)

# ─────────────────────────────────────────────────────────────
# SIDEBAR
# ─────────────────────────────────────────────────────────────
with st.sidebar:
    st.markdown("## 📡 DevSignal")
    st.markdown("*iOS Internship Radar*")
    st.divider()

    page = st.radio(
        "Navigation",
        [
            "Overview",
            "Opportunities",
            "Outreach",
            "System"
        ]
    )

    st.divider()

    st.caption("Refreshes every 5 min")
    st.caption("Built with Python + Groq + n8n")

    if st.button("↻ Refresh data", use_container_width=True):
        from dashboard.db import clear_all_caches
        clear_all_caches()
        st.rerun()

# ─────────────────────────────────────────────────────────────
# PAGE ROUTER
# ─────────────────────────────────────────────────────────────
try:
    if page == "Overview":
        import dashboard.pages.overview as p
        p.render()

    elif page == "Opportunities":
        import dashboard.pages.opportunities as p
        p.render()

    elif page == "Outreach":
        import dashboard.pages.outreach as p
        p.render()

    elif page == "System":
        import dashboard.pages.system as p
        p.render()

except Exception as e:
    st.error("This page failed to load.")
    st.exception(e)