# PURPOSE:
#   The main FastAPI application for the DevSignal iOS backend.

import sys
import os
from datetime import datetime, timezone
from typing import Optional

from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from api.middleware import APIKeyMiddleware
from storage.async_db import async_db          # ← async wrapper (BUG-4 fix)
from storage.db_client import db_client        # kept for pipeline trigger only
from config.settings import PIPELINE_API_KEY

# ─────────────────────────────────────────────────────────────────────────────
# APP SETUP
# ─────────────────────────────────────────────────────────────────────────────
app = FastAPI(
    title="DevSignal API",
    description="iOS backend for DevSignal — AI-powered iOS job radar",
    version="2.1.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.add_middleware(APIKeyMiddleware)


# ─────────────────────────────────────────────────────────────────────────────
# REQUEST / RESPONSE MODELS
# ─────────────────────────────────────────────────────────────────────────────

class ApplyRequest(BaseModel):
    stage: str  # applied | waiting | replied | interview | offer | rejected


class UpdateApplicationRequest(BaseModel):
    stage: Optional[str] = None
    notes: Optional[str] = None


class DeviceRegistrationRequest(BaseModel):
    device_token: str
    platform: str = "ios"


# ─────────────────────────────────────────────────────────────────────────────
# HELPERS
# ─────────────────────────────────────────────────────────────────────────────

def extract_title_from_url(url: str) -> str:
    if not url:
        return "Untitled Job"
    slug = url.split("/")[-1]
    slug = slug.replace("-", " ")
    words = slug.split()
    clean_words = [w for w in words if len(w) > 2]
    return " ".join(clean_words[:6]).title() or "Untitled Job"


def serialize_job(row: dict) -> dict:
    def dt_to_str(val):
        if isinstance(val, datetime):
            return val.isoformat()
        return val

    def to_bool(val):
        if isinstance(val, bool):
            return val
        if isinstance(val, str):
            return val.lower() in ("yes", "true", "1")
        return None

    return {
        "id":               row.get("id"),
        "title": (
            row.get("title")
            or row.get("job_title")
            or row.get("role")
            or extract_title_from_url(row.get("url") or "")
        ),
        "company":           row.get("company") or "Unknown Company",
        "source":            row.get("source") or row.get("job_source"),
        "url":               row.get("url") or row.get("apply_link"),
        "score":             row.get("score") or row.get("opportunity_score"),
        "score_breakdown":   row.get("score_breakdown"),
        "score_explanation": row.get("score_explanation"),
        "is_remote":         to_bool(row.get("is_remote") or row.get("remote")),
        "visa_sponsorship":  to_bool(row.get("visa_sponsorship")),
        "is_ios_product":    row.get("is_ios_product"),
        "experience_required": row.get("experience_required") or row.get("experience_req"),
        "location":          row.get("location"),
        "salary":            row.get("salary"),
        "posted_at":         dt_to_str(row.get("posted_at") or row.get("date_found")),
        "discovered_at":     dt_to_str(row.get("discovered_at") or row.get("date_found")),
        "application_status": row.get("application_status"),
    }


# ─────────────────────────────────────────────────────────────────────────────
# ENDPOINTS
# All handlers are async def — BUG-4 fix.
# All DB calls use await async_db.method() — never blocks the event loop.
# ─────────────────────────────────────────────────────────────────────────────

@app.get("/health")
async def health_check():
    return {
        "status":    "ok",
        "service":   "devsignal-api",
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }


@app.get("/jobs")
async def get_jobs(
    min_score:  int            = Query(default=0,  ge=0,  le=100),
    remote:     Optional[bool] = Query(default=None),
    visa:       Optional[bool] = Query(default=None),
    source:     Optional[str]  = Query(default=None),
    applied:    Optional[bool] = Query(default=None),
    days_fresh: int            = Query(default=30, ge=1,  le=365),
    page:       int            = Query(default=1,  ge=1),
    per_page:   int            = Query(default=25, ge=1,  le=50),
):
    try:
        filters: dict = {"min_score": min_score, "days_fresh": days_fresh}
        if remote  is not None: filters["is_remote"]       = "Yes" if remote else "No"
        if visa    is not None: filters["visa_sponsorship"] = visa
        if source  is not None: filters["source"]           = source
        if applied is not None: filters["exclude_applied"]  = not applied

        offset = (page - 1) * per_page

        # Both DB calls run concurrently — saves a full round-trip latency
        import asyncio
        jobs_raw, total = await asyncio.gather(
            async_db.get_jobs_filtered(filters, limit=per_page + 1, offset=offset),
            async_db.count_jobs_filtered(filters),
        )

        has_more  = len(jobs_raw) > per_page
        jobs_page = jobs_raw[:per_page]

        return {
            "jobs":     [serialize_job(j) for j in jobs_page],
            "total":    total,
            "page":     page,
            "per_page": per_page,
            "has_more": has_more,
        }

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")


@app.get("/jobs/{job_id}")
async def get_job(job_id: str):
    try:
        job = await async_db.get_job_by_id(job_id)
        if job is None:
            raise HTTPException(status_code=404, detail=f"Job {job_id} not found")
        return serialize_job(job)
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")


@app.get("/jobs/{job_id}/outreach")
async def get_outreach(job_id: str):
    try:
        job = await async_db.get_job_by_id(job_id)
        if job is None:
            raise HTTPException(status_code=404, detail=f"Job {job_id} not found")
        return {
            "job_id":          job_id,
            "message":         job.get("outreach_message"),
            "recruiter_name":  job.get("recruiter_name"),
            "recruiter_email": job.get("email"),
            "linkedin_url":    job.get("linkedin_profile"),
        }
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")


@app.post("/jobs/{job_id}/apply")
async def apply_to_job(job_id: str, body: ApplyRequest):
    valid_stages = {"applied", "waiting", "replied", "interview", "offer", "rejected"}
    if body.stage not in valid_stages:
        raise HTTPException(
            status_code=400,
            detail=f"Invalid stage '{body.stage}'. Must be one of: {valid_stages}",
        )
    try:
        job = await async_db.get_job_by_id(job_id)
        if job is None:
            raise HTTPException(status_code=404, detail=f"Job {job_id} not found")

        # Both writes in parallel — they touch different tables
        import asyncio
        application, _ = await asyncio.gather(
            async_db.upsert_application(job_id=job_id, stage=body.stage),
            async_db.update_application_status(job_id, body.stage),
        )

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


@app.get("/applications")
async def get_applications():
    try:
        applications = await async_db.get_all_applications()
        return [
            {
                "application_id": str(app.get("id")),
                "job_id":         app.get("job_id"),
                "company":        app.get("company"),
                "title":          app.get("title"),
                "score":          app.get("opportunity_score"),
                "source":         app.get("job_source"),
                "stage":          app.get("stage", "applied"),
                "applied_at":     app.get("applied_at").isoformat()
                                if app.get("applied_at") else None,
                "notes":          app.get("notes"),
                "updated_at":     app.get("updated_at").isoformat()
                                if app.get("updated_at") else None,
            }
            for app in applications
        ]
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")


@app.patch("/applications/{application_id}")
async def update_application(application_id: str,
                            body: UpdateApplicationRequest):
    if body.stage is not None:
        valid_stages = {"applied", "waiting", "replied",
                        "interview", "offer", "rejected"}
        if body.stage not in valid_stages:
            raise HTTPException(
                status_code=400, detail=f"Invalid stage '{body.stage}'"
            )
    try:
        updated = await async_db.update_application(
            application_id=application_id,
            stage=body.stage,
            notes=body.notes,
        )
        if updated is None:
            raise HTTPException(
                status_code=404,
                detail=f"Application {application_id} not found",
            )
        return {
            "application_id": application_id,
            "stage":          updated.get("stage"),
            "notes":          updated.get("notes"),
            "updated_at":     updated.get("updated_at").isoformat()
                            if updated.get("updated_at") else None,
        }
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")


@app.get("/stats")
async def get_stats():
    try:
        stats = await async_db.get_dashboard_stats()
        return {
            "total_jobs":          stats.get("total_jobs", 0),
            "avg_score":           round(stats.get("avg_score", 0.0), 1),
            "jobs_above_70":       stats.get("jobs_above_70", 0),
            "applied_count":       stats.get("applied_count", 0),
            "reply_rate":          round(stats.get("reply_rate", 0.0), 2),
            "interview_count":     stats.get("interview_count", 0),
            "pipeline_last_run":   stats.get("pipeline_last_run").isoformat()
                                if stats.get("pipeline_last_run") else None,
            "score_distribution":  stats.get("score_distribution", []),
            "top_sources":         stats.get("top_sources", []),
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")


@app.post("/devices")
async def register_device(body: DeviceRegistrationRequest):
    try:
        await async_db.upsert_device_token(
            token=body.device_token, platform=body.platform
        )
        return {"registered": True, "platform": body.platform}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Registration error: {str(e)}")


@app.post("/run-pipeline")
async def run_pipeline():
    """
    Triggers the pipeline as a background subprocess.
    Non-blocking: returns immediately with the PID.
    """
    import subprocess

    script_path = os.path.join(
        os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
        "run_pipeline.sh",
    )
    if not os.path.exists(script_path):
        raise HTTPException(status_code=404, detail="Pipeline script not found")

    try:
        result = subprocess.Popen(
            ["bash", script_path],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
        return {
            "status":  "started",
            "pid":     result.pid,
            "message": "Pipeline triggered successfully",
        }
    except Exception as e:
        raise HTTPException(
            status_code=500, detail=f"Failed to start pipeline: {str(e)}"
        )


@app.get("/n8n-ping")
async def n8n_ping():
    return {"reachable": True, "service": "devsignal-api"}