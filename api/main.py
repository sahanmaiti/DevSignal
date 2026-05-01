# PURPOSE: The main FastAPI application for the DevSignal iOS backend.
#
# This file does NOT contain any business logic. It is thin wiring:
#   1. Receive an HTTP request
#   2. Call an existing db_client method
#   3. Return the result as JSON
#
# The heavy lifting (DB queries, data structure) stays in db_client.py.
# This keeps concerns separated — if you change the DB schema, you only
# update db_client.py. The endpoints here stay the same.

import sys
import os
from datetime import datetime, timezone
from typing import Optional

from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

# Add project root to path so imports work regardless of where you run from
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from api.middleware import APIKeyMiddleware
from storage.db_client import db_client      # your existing singleton
from config.settings import PIPELINE_API_KEY

# ─────────────────────────────────────────────────────────────────────────────
# APP SETUP
# FastAPI() creates the application object. The title/description appear
# in the auto-generated docs page at http://localhost:8000/docs
# ─────────────────────────────────────────────────────────────────────────────
app = FastAPI(
    title="DevSignal API",
    description="iOS backend for DevSignal — AI-powered iOS job radar",
    version="2.0.0",
)

# CORS Middleware
# CORS = Cross-Origin Resource Sharing.
# This tells the server "it's okay to accept requests from these origins."
# During development we allow everything ("*"). In production you'd lock
# this down to your specific app bundle ID or domain.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# API Key Middleware — must be added AFTER CORSMiddleware
# Every request (except /health and /docs) must include X-API-Key header
app.add_middleware(APIKeyMiddleware)


# ─────────────────────────────────────────────────────────────────────────────
# PYDANTIC MODELS (Request/Response shapes)
#
# Pydantic models define the *shape* of JSON that comes IN or goes OUT.
# FastAPI uses these to:
#   - Automatically validate incoming request bodies (400 if wrong shape)
#   - Automatically generate the /docs documentation
#   - Serialize Python objects to JSON for responses
# ─────────────────────────────────────────────────────────────────────────────

class ApplyRequest(BaseModel):
    """Body for POST /jobs/{job_id}/apply"""
    # stage must be one of these exact strings — Pydantic validates this
    stage: str  # "applied" | "waiting" | "replied" | "interview" | "offer" | "rejected"

    def validate_stage(self):
        valid = {"applied", "waiting", "replied", "interview", "offer", "rejected"}
        if self.stage not in valid:
            raise ValueError(f"stage must be one of {valid}")


class UpdateApplicationRequest(BaseModel):
    """Body for PATCH /applications/{application_id}"""
    stage: Optional[str] = None   # Optional — can update just the stage
    notes: Optional[str] = None   # Optional — can update just the notes


class DeviceRegistrationRequest(BaseModel):
    """Body for POST /devices"""
    device_token: str
    platform: str = "ios"


# ─────────────────────────────────────────────────────────────────────────────
# HELPER FUNCTION
# ─────────────────────────────────────────────────────────────────────────────

def serialize_job(row: dict) -> dict:
    """
    Converts a raw database row (dict) into a clean JSON-serializable dict
    that the iOS app expects.
    
    Why needed? Raw psycopg2 rows may contain:
    - datetime objects (not JSON-serializable → must convert to ISO string)
    - None values (fine, maps to null in JSON)
    - Extra columns the iOS app doesn't need (we can omit them)
    
    We keep only the fields the iOS app actually uses — smaller payload,
    less data over the network, clearer contract.
    """
    def dt_to_str(val):
        """Convert datetime to ISO 8601 string, or return None if already None"""
        if isinstance(val, datetime):
            return val.isoformat()
        return val
    
    return {

        "id":                   row.get("id"),
        "title":                row.get("role"),                
        "company":              row.get("company"),
        "source":               row.get("job_source"),          
        "url":                  row.get("apply_link"),          
        "score":                row.get("opportunity_score"),   
        "score_breakdown":      row.get("score_breakdown"),
        "score_explanation":    None,
        "is_remote":            row.get("remote") == "Yes",
        "visa_sponsorship":     row.get("visa_sponsorship"),
        "is_ios_product":       None,
        "experience_required":  row.get("experience_req") or None,
        "location":             row.get("location"),
        "salary":               None,
        "posted_at":            None,
        "discovered_at":        dt_to_str(row.get("date_found")),
        "application_status":   row.get("response_status") or None,
    }


# ─────────────────────────────────────────────────────────────────────────────
# ENDPOINT 1: GET /health
# The simplest possible endpoint. No auth required (it's in PUBLIC_PATHS).
# The iOS app calls this during onboarding to verify the server is reachable
# and the API key is valid (if you call /health WITH the key header and it
# returns 200, you know both the server is up AND the key works — wait, 
# /health is public so the key isn't checked. To validate the key, the iOS
# app should call /stats instead, which IS protected.)
# ─────────────────────────────────────────────────────────────────────────────

@app.get("/health")
def health_check():
    return {
        "status": "ok",
        "service": "devsignal-api",
        "timestamp": datetime.now(timezone.utc).isoformat()
    }


# ─────────────────────────────────────────────────────────────────────────────
# ENDPOINT 2: GET /jobs
#
# The main job list endpoint. The iOS Discover tab calls this.
#
# Query parameters (all optional — everything has a sensible default):
#   min_score  — only return jobs with score >= this value (default: 0)
#   remote     — if true, only remote jobs; if false, only on-site; if omitted, all
#   visa       — same pattern for visa sponsorship
#   source     — filter by scraper name e.g. "remoteok", "hackernews"
#   applied    — if false, exclude already-applied jobs (useful for "fresh" view)
#   days_fresh — only jobs discovered in the last N days (default: 30)
#   page       — page number for pagination (default: 1)
#   per_page   — results per page (default: 25, max: 50)
#
# Response: { jobs: [...], total: int, page: int, has_more: bool }
# ─────────────────────────────────────────────────────────────────────────────

@app.get("/jobs")
def get_jobs(
    min_score: int = Query(default=0, ge=0, le=100),
    remote: Optional[bool] = Query(default=None),
    visa: Optional[bool] = Query(default=None),
    source: Optional[str] = Query(default=None),
    applied: Optional[bool] = Query(default=None),
    days_fresh: int = Query(default=30, ge=1, le=365),
    page: int = Query(default=1, ge=1),
    per_page: int = Query(default=25, ge=1, le=50),
):
    """
    Returns a paginated list of jobs matching the given filters.
    The iOS Discover tab calls this on launch and on pull-to-refresh.
    """
    try:
        # Build filter dict — only include keys that were actually provided
        filters = {
            "min_score": min_score,
            "days_fresh": days_fresh,
        }
        if remote is not None:
            filters["is_remote"] = "Yes" if remote else "No"
        if visa is not None:
            filters["visa_sponsorship"] = visa
        if source is not None:
            filters["source"] = source
        if applied is not None:
            # applied=False means "exclude jobs with application_status set"
            filters["exclude_applied"] = not applied

        # Pagination: calculate offset from page number
        # Page 1 → offset 0 (skip 0 rows)
        # Page 2 → offset 25 (skip first 25 rows)
        # Page 3 → offset 50, etc.
        offset = (page - 1) * per_page

        # Call the existing db_client to get jobs
        # We fetch per_page + 1 rows: if we get more than per_page back,
        # we know there's a next page (has_more = True)
        jobs_raw = db_client.get_jobs_filtered(
            filters=filters,
            limit=per_page + 1,
            offset=offset
        )

        has_more = len(jobs_raw) > per_page
        jobs_page = jobs_raw[:per_page]  # trim the extra row we fetched

        # Get total count for the pagination UI
        total = db_client.count_jobs_filtered(filters=filters)

        return {
            "jobs": [serialize_job(j) for j in jobs_page],
            "total": total,
            "page": page,
            "per_page": per_page,
            "has_more": has_more,
        }

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")


# ─────────────────────────────────────────────────────────────────────────────
# ENDPOINT 3: GET /jobs/{job_id}
#
# Returns the full record for a single job, including the score_breakdown JSONB.
# The iOS Job Detail sheet calls this when a user taps a job card.
#
# {job_id} in the URL path is the MD5 hash string that your deduplicator
# uses as the primary key. Example:
#   GET /jobs/a1b2c3d4e5f6...
# ─────────────────────────────────────────────────────────────────────────────

@app.get("/jobs/{job_id}")
def get_job(job_id: str):
    """Returns full details for a single job by its MD5 hash ID."""
    try:
        job = db_client.get_job_by_id(job_id)
        
        if job is None:
            raise HTTPException(status_code=404, detail=f"Job {job_id} not found")
        
        return serialize_job(job)

    except HTTPException:
        raise  # re-raise HTTP exceptions as-is
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")


# ─────────────────────────────────────────────────────────────────────────────
# ENDPOINT 4: GET /jobs/{job_id}/outreach
#
# Returns the pre-generated recruiter outreach message for a job.
# Also returns recruiter contact info if the enricher found it.
# The iOS Outreach tab calls this.
#
# Note: The outreach message was already generated by outreach_generator.py
# and stored in the database. We're just reading it here — no AI call happens.
# ─────────────────────────────────────────────────────────────────────────────

@app.get("/jobs/{job_id}/outreach")
def get_outreach(job_id: str):
    """Returns the recruiter outreach message and contact details for a job."""
    try:
        job = db_client.get_job_by_id(job_id)
        
        if job is None:
            raise HTTPException(status_code=404, detail=f"Job {job_id} not found")
        
        # These fields come from the enricher and outreach_generator
        # They may be None if the job wasn't enriched (score < 45)
        return {
            "job_id":          job_id,
            "message":         job.get("outreach_message"),
            "recruiter_name":  job.get("recruiter_name"),
            "recruiter_email": job.get("recruiter_email"),
            "linkedin_url":    job.get("recruiter_linkedin"),
        }

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")


# ─────────────────────────────────────────────────────────────────────────────
# ENDPOINT 5: POST /jobs/{job_id}/apply
#
# Records that the user has applied to a job, with a given stage.
# Called when the user taps "Mark as Applied" in the iOS app.
#
# What this does:
#   1. Creates a row in the new `applications` table
#   2. Also updates the denormalized `application_status` column on the job
#      (so your existing Streamlit dashboard still shows application status)
#
# "Upsert" = INSERT if no application exists for this job, UPDATE if one does.
# This way tapping "Applied" twice doesn't create duplicate rows.
# ─────────────────────────────────────────────────────────────────────────────

@app.post("/jobs/{job_id}/apply")
def apply_to_job(job_id: str, body: ApplyRequest):
    """Creates or updates an application record for a job."""
    
    # Validate the stage string is one of the allowed values
    valid_stages = {"applied", "waiting", "replied", "interview", "offer", "rejected"}
    if body.stage not in valid_stages:
        raise HTTPException(
            status_code=400,
            detail=f"Invalid stage '{body.stage}'. Must be one of: {valid_stages}"
        )
    
    try:
        # Make sure the job exists first
        job = db_client.get_job_by_id(job_id)
        if job is None:
            raise HTTPException(status_code=404, detail=f"Job {job_id} not found")
        
        # Upsert into the applications table
        application = db_client.upsert_application(
            job_id=job_id,
            stage=body.stage
        )
        
        # Also update the denormalized status on the job row
        # This keeps your existing Streamlit dashboard working without changes
        db_client.update_application_status(job_id, body.stage)
        
        return {
            "application_id": str(application.get("id")),
            "job_id":         job_id,
            "stage":          body.stage,
            "updated_at":     datetime.now(timezone.utc).isoformat(),
        }

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")


# ─────────────────────────────────────────────────────────────────────────────
# ENDPOINT 6: GET /applications
#
# Returns all applications the user has created, ordered by most recent first.
# Powers the Tracker tab in the iOS app.
# ─────────────────────────────────────────────────────────────────────────────

@app.get("/applications")
def get_applications():
    """Returns all application records with joined job info."""
    try:
        applications = db_client.get_all_applications()
        
        # Format each application for the iOS app
        result = []
        for app_row in applications:
            result.append({
                "application_id": str(app_row.get("id")),
                "job_id":         app_row.get("job_id"),
                "company":        app_row.get("company"),
                "title":          app_row.get("title"),
                "score":          app_row.get("score"),
                "source":         app_row.get("source"),
                "stage":          app_row.get("stage"),
                "applied_at":     app_row.get("applied_at").isoformat() if app_row.get("applied_at") else None,
                "notes":          app_row.get("notes"),
                "updated_at":     app_row.get("updated_at").isoformat() if app_row.get("updated_at") else None,
            })
        
        return result

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")


# ─────────────────────────────────────────────────────────────────────────────
# ENDPOINT 7: PATCH /applications/{application_id}
#
# Updates an existing application's stage or notes.
# Called when the user drags a card to a new column in the Tracker Kanban.
# "PATCH" means partial update — you only send the fields you want to change.
# ─────────────────────────────────────────────────────────────────────────────

@app.patch("/applications/{application_id}")
def update_application(application_id: str, body: UpdateApplicationRequest):
    """Updates stage and/or notes for an existing application."""
    
    if body.stage is not None:
        valid_stages = {"applied", "waiting", "replied", "interview", "offer", "rejected"}
        if body.stage not in valid_stages:
            raise HTTPException(status_code=400, detail=f"Invalid stage '{body.stage}'")
    
    try:
        updated = db_client.update_application(
            application_id=application_id,
            stage=body.stage,
            notes=body.notes
        )
        
        if updated is None:
            raise HTTPException(status_code=404, detail=f"Application {application_id} not found")
        
        return {
            "application_id": application_id,
            "stage":          updated.get("stage"),
            "notes":          updated.get("notes"),
            "updated_at":     updated.get("updated_at").isoformat() if updated.get("updated_at") else None,
        }

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")


# ─────────────────────────────────────────────────────────────────────────────
# ENDPOINT 8: GET /stats
#
# Returns aggregated statistics for the iOS Analytics tab and the onboarding
# key-validation flow (calling /stats with a key header confirms the key works).
# ─────────────────────────────────────────────────────────────────────────────

@app.get("/stats")
def get_stats():
    """Returns aggregated pipeline and application statistics."""
    try:
        stats = db_client.get_dashboard_stats()
        
        return {
            "total_jobs":       stats.get("total_jobs", 0),
            "avg_score":        round(stats.get("avg_score", 0.0), 1),
            "jobs_above_70":    stats.get("jobs_above_70", 0),
            "applied_count":    stats.get("applied_count", 0),
            "reply_rate":       round(stats.get("reply_rate", 0.0), 2),
            "interview_count":  stats.get("interview_count", 0),
            "pipeline_last_run": stats.get("pipeline_last_run").isoformat() 
                                if stats.get("pipeline_last_run") else None,
            "score_distribution": stats.get("score_distribution", []),
            "top_sources":        stats.get("top_sources", []),
        }

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")


# ─────────────────────────────────────────────────────────────────────────────
# ENDPOINT 9: POST /devices
#
# Registers an iOS device's APNs push token.
# Called on first app launch and whenever the token refreshes.
# We'll use these tokens in Phase 4 to send push notifications.
# ─────────────────────────────────────────────────────────────────────────────

@app.post("/devices")
def register_device(body: DeviceRegistrationRequest):
    """Registers or updates an iOS push notification token."""
    try:
        db_client.upsert_device_token(
            token=body.device_token,
            platform=body.platform
        )
        return {"registered": True, "platform": body.platform}

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Registration error: {str(e)}")


# ─────────────────────────────────────────────────────────────────────────────
# ENDPOINT 10: POST /run-pipeline  (preserve existing n8n webhook)
#
# This already exists in pipeline_server.py. We keep it here too so this
# file becomes the single FastAPI app. If you prefer, you can import the
# handler from pipeline_server.py — but redefining it here is simpler.
# ─────────────────────────────────────────────────────────────────────────────

@app.post("/run-pipeline")
def run_pipeline():
    """Triggers the full scrape → score → enrich → notify pipeline."""
    import subprocess
    
    script_path = os.path.join(
        os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
        "run_pipeline.sh"
    )
    
    if not os.path.exists(script_path):
        raise HTTPException(status_code=404, detail="Pipeline script not found")
    
    try:
        result = subprocess.Popen(
            ["bash", script_path],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE
        )
        return {
            "status": "started",
            "pid": result.pid,
            "message": "Pipeline triggered successfully"
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to start pipeline: {str(e)}")