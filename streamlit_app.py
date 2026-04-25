# streamlit_app.py
# Root-level entry point for Streamlit Cloud.
# Streamlit Cloud looks for pages/ relative to THIS file's location.

import streamlit as st

st.set_page_config(
    page_title="DevSignal",
    page_icon="📡",
    layout="wide",
    initial_sidebar_state="expanded",
)

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

with st.sidebar:
    st.markdown("## 📡 DevSignal")
    st.markdown("*iOS Internship Radar*")
    st.divider()
    st.caption("Refreshes every 5 min")
    st.caption("Built with Python + Groq + n8n")
    if st.button("↻  Refresh data", use_container_width=True):
        st.cache_data.clear()
        st.rerun()

# Show overview on the landing page
exec(open("pages/1_Overview.py").read())