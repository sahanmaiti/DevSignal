import asyncio
import sys
import os
from contextlib import asynccontextmanager
from datetime import datetime, timezone
from typing import Optional

from fastapi import FastAPI, HTTPException, Query, Request, Depends, status
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

# ── SEC-4: slowapi ────────────────────────────────────────────────────────────
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.util import get_remote_address
from slowapi.errors import RateLimitExceeded

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from api.middleware import APIKeyMiddleware
from api.auth import (
    verify_password,
    create_access_token,
    create_user,
    get_user_by_email,
    create_api_key_for_user,
    list_api_keys_for_user,
    revoke_api_key,
    require_user,
)
from api.worker import get_arq_pool
from storage.async_db import async_db
from config.settings import APP_ENV, ALLOWED_ORIGINS, PUBLIC_PATHS


# ─────────────────────────────────────────────────────────────────────────────
# LIMITER
#
# get_remote_address reads X-Forwarded-For first, then falls back to the
# direct connection IP — correct behind any reverse proxy / CDN.
# ─────────────────────────────────────────────────────────────────────────────

limiter = Limiter(key_func=get_remote_address)


# ─────────────────────────────────────────────────────────────────────────────
# LIFESPAN
# ─────────────────────────────────────────────────────────────────────────────

_arq_pool = None


@asynccontextmanager
async def lifespan(app: FastAPI):
    global _arq_pool
    try:
        _arq_pool = await get_arq_pool()
        print("[API] ARQ Redis pool ready")
    except Exception as exc:
        print(f"[API] WARNING: could not connect to Redis: {exc}")
        print("[API] /run-pipeline will use legacy subprocess fallback.")
    yield
    if _arq_pool:
        await _arq_pool.close()


# ─────────────────────────────────────────────────────────────────────────────
# APP
# ─────────────────────────────────────────────────────────────────────────────

_docs_url    = None if APP_ENV == "production" else "/docs"
_redoc_url   = None if APP_ENV == "production" else "/redoc"
_openapi_url = None if APP_ENV == "production" else "/openapi.json"

app = FastAPI(
    title="DevSignal API",
    description="iOS backend for DevSignal — AI-powered iOS job radar",
    version="3.0.0",
    lifespan=lifespan,
    docs_url=_docs_url,
    redoc_url=_redoc_url,
    openapi_url=_openapi_url,
)

app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

# SEC-1: CORS — no wildcard
app.add_middleware(
    CORSMiddleware,
    allow_origins=ALLOWED_ORIGINS,
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
    allow_headers=["Authorization", "Content-Type", "X-API-Key"],
    max_age=600,
)

app.add_middleware(APIKeyMiddleware)


# ─────────────────────────────────────────────────────────────────────────────
# MODELS
# ─────────────────────────────────────────────────────────────────────────────

class RegisterRequest(BaseModel):
    email: str
    password: str

class LoginRequest(BaseModel):
    email: str
    password: str

class CreateAPIKeyRequest(BaseModel):
    name: str = "default"

class ApplyRequest(BaseModel):
    stage: str

class UpdateApplicationRequest(BaseModel):
    stage: Optional[str] = None
    notes: Optional[str] = None

class DeviceRegistrationRequest(BaseModel):
    device_token: str
    platform: str = "ios"


# ─────────────────────────────────────────────────────────────────────────────
# HELPERS
# ─────────────────────────────────────────────────────────────────────────────

VALID_STAGES = {"applied", "waiting", "replied", "interview", "offer", "rejected"}


def extract_title_from_url(url: str) -> str:
    if not url:
        return "Untitled Job"
    slug = url.split("/")[-1]
    words = slug.replace("-", " ").split()
    clean = [w for w in words if len(w) > 2]
    return " ".join(clean[:6]).title() or "Untitled Job"


def serialize_job(row: dict) -> dict:
    def dt_to_str(val):
        return val.isoformat() if isinstance(val, datetime) else val

    def to_bool(val):
        if isinstance(val, bool):
            return val
        if isinstance(val, str):
            return val.lower() in ("yes", "true", "1")
        return None

    return {
        "id":                 row.get("id"),
        "title": (
            row.get("title")
            or row.get("job_title")
            or row.get("role")
            or extract_title_from_url(row.get("url") or "")
        ),
        "company":             row.get("company") or "Unknown Company",
        "source":              row.get("source") or row.get("job_source"),
        "url":                 row.get("url") or row.get("apply_link"),
        "score":               row.get("score") or row.get("opportunity_score"),
        "score_breakdown":     row.get("score_breakdown"),
        "score_explanation":   row.get("score_explanation"),
        "is_remote":           to_bool(row.get("is_remote") or row.get("remote")),
        "visa_sponsorship":    to_bool(row.get("visa_sponsorship")),
        "is_ios_product":      row.get("is_ios_product"),
        "experience_required": row.get("experience_required") or row.get("experience_req"),
        "location":            row.get("location"),
        "salary":              row.get("salary"),
        "posted_at":           dt_to_str(row.get("posted_at") or row.get("date_found")),
        "discovered_at":       dt_to_str(row.get("discovered_at") or row.get("date_found")),
        "application_status":  row.get("application_status"),
    }


# ─────────────────────────────────────────────────────────────────────────────
# UTILITY  (no rate limit — must always respond for health probes)
# ─────────────────────────────────────────────────────────────────────────────

@app.get("/health", tags=["utility"])
async def health_check():
    return {
        "status":    "ok",
        "service":   "devsignal-api",
        "version":   "3.0.0",
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }


@app.get("/n8n-ping", tags=["utility"])
async def n8n_ping():
    return {"reachable": True, "service": "devsignal-api"}


# ─────────────────────────────────────────────────────────────────────────────
# AUTH
# ─────────────────────────────────────────────────────────────────────────────

@app.post("/auth/register", tags=["auth"], status_code=201)
@limiter.limit("5/hour")
async def register(request: Request, body: RegisterRequest):
    user  = create_user(email=body.email, password=body.password)
    token = create_access_token(user_id=user["id"], email=user["email"])
    return {"user": user, "access_token": token, "token_type": "bearer"}


@app.post("/auth/login", tags=["auth"])
@limiter.limit("10/minute")
async def login(request: Request, body: LoginRequest):
    user = get_user_by_email(body.email)
    if user is None or not verify_password(body.password, user["hashed_password"]):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email or password.",
        )
    if not user.get("is_active"):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Account is inactive.",
        )
    token = create_access_token(user_id=user["id"], email=user["email"])
    return {
        "access_token": token,
        "token_type":   "bearer",
        "user": {"id": user["id"], "email": user["email"], "plan": user["plan"]},
    }


@app.get("/auth/me", tags=["auth"])
async def me(user: dict = Depends(require_user)):
    return {"id": user["id"], "email": user["email"], "plan": user["plan"]}


@app.post("/auth/api-keys", tags=["auth"], status_code=201)
@limiter.limit("5/hour")
async def create_api_key(
    request: Request,
    body: CreateAPIKeyRequest,
    user: dict = Depends(require_user),
):
    raw_key = create_api_key_for_user(user_id=user["id"], name=body.name)
    return {
        "api_key": raw_key,
        "name":    body.name,
        "message": "Store this key securely. It will not be shown again.",
    }


@app.get("/auth/api-keys", tags=["auth"])
async def get_api_keys(user: dict = Depends(require_user)):
    return list_api_keys_for_user(user_id=user["id"])


@app.delete("/auth/api-keys/{key_id}", tags=["auth"])
async def delete_api_key(key_id: str, user: dict = Depends(require_user)):
    revoked = revoke_api_key(key_id=key_id, user_id=user["id"])
    if not revoked:
        raise HTTPException(status_code=404, detail="API key not found.")
    return {"revoked": True, "key_id": key_id}


# ─────────────────────────────────────────────────────────────────────────────
# JOBS
# ─────────────────────────────────────────────────────────────────────────────

@app.get("/jobs", tags=["jobs"])
@limiter.limit("30/minute")
async def get_jobs(
    request: Request,
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
        raise HTTPException(status_code=500, detail=f"Database error: {e}")


@app.get("/jobs/{job_id}", tags=["jobs"])
@limiter.limit("60/minute")
async def get_job(request: Request, job_id: str):
    try:
        job = await async_db.get_job_by_id(job_id)
        if job is None:
            raise HTTPException(status_code=404, detail=f"Job {job_id} not found")
        return serialize_job(job)
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Database error: {e}")


@app.get("/jobs/{job_id}/outreach", tags=["jobs"])
@limiter.limit("60/minute")
async def get_outreach(request: Request, job_id: str):
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
        raise HTTPException(status_code=500, detail=f"Database error: {e}")


# ─────────────────────────────────────────────────────────────────────────────
# APPLICATIONS
# ─────────────────────────────────────────────────────────────────────────────

@app.post("/jobs/{job_id}/apply", tags=["applications"])
@limiter.limit("20/minute")
async def apply_to_job(request: Request, job_id: str, body: ApplyRequest):
    if body.stage not in VALID_STAGES:
        raise HTTPException(
            status_code=400,
            detail=f"Invalid stage '{body.stage}'. Must be one of: {VALID_STAGES}",
        )
    try:
        job = await async_db.get_job_by_id(job_id)
        if job is None:
            raise HTTPException(status_code=404, detail=f"Job {job_id} not found")

        application = await async_db.upsert_application(
            job_id=int(job_id), stage=body.stage
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
        raise HTTPException(status_code=500, detail=f"Database error: {e}")


@app.get("/applications", tags=["applications"])
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
                "applied_at":     app["applied_at"].isoformat() if app.get("applied_at") else None,
                "notes":          app.get("notes"),
                "updated_at":     app["updated_at"].isoformat() if app.get("updated_at") else None,
            }
            for app in applications
        ]
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Database error: {e}")


@app.patch("/applications/{application_id}", tags=["applications"])
@limiter.limit("30/minute")
async def update_application(
    request: Request,
    application_id: str,
    body: UpdateApplicationRequest,
):
    if body.stage is not None and body.stage not in VALID_STAGES:
        raise HTTPException(status_code=400, detail=f"Invalid stage '{body.stage}'")
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
            "updated_at":     updated["updated_at"].isoformat()
                            if updated.get("updated_at") else None,
        }
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Database error: {e}")


# ─────────────────────────────────────────────────────────────────────────────
# STATS
# ─────────────────────────────────────────────────────────────────────────────

@app.get("/stats", tags=["analytics"])
@limiter.limit("30/minute")
async def get_stats(request: Request):
    try:
        stats = await async_db.get_dashboard_stats()
        return {
            "total_jobs":         stats.get("total_jobs", 0),
            "avg_score":          round(stats.get("avg_score", 0.0), 1),
            "jobs_above_70":      stats.get("jobs_above_70", 0),
            "applied_count":      stats.get("applied_count", 0),
            "reply_rate":         round(stats.get("reply_rate", 0.0), 2),
            "interview_count":    stats.get("interview_count", 0),
            "pipeline_last_run":  stats["pipeline_last_run"].isoformat()
                                if stats.get("pipeline_last_run") else None,
            "score_distribution": stats.get("score_distribution", []),
            "top_sources":        stats.get("top_sources", []),
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Database error: {e}")


# ─────────────────────────────────────────────────────────────────────────────
# DEVICES
# ─────────────────────────────────────────────────────────────────────────────

@app.post("/devices", tags=["notifications"])
@limiter.limit("10/hour")
async def register_device(request: Request, body: DeviceRegistrationRequest):
    try:
        await async_db.upsert_device_token(
            token=body.device_token, platform=body.platform
        )
        return {"registered": True, "platform": body.platform}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Registration error: {e}")


# ─────────────────────────────────────────────────────────────────────────────
# PIPELINE
# ─────────────────────────────────────────────────────────────────────────────

@app.post("/run-pipeline", tags=["pipeline"])
@limiter.limit("1/10minute")
async def run_pipeline(request: Request):
    """
    Triggers the full DevSignal pipeline (scrape → score → enrich → notify).

    Rate limit: 1 request per 10 minutes per IP.
    This is the most important limit in the whole API — one actor calling
    this in a tight loop would exhaust your entire Groq free quota within
    minutes and cause scraping races against the DB.
    """
    global _arq_pool

    if _arq_pool is not None:
        try:
            job = await _arq_pool.enqueue_job(
                "run_pipeline",
                _job_id="pipeline_singleton",
            )
            if job is None:
                return {
                    "status":  "already_running",
                    "job_id":  "pipeline_singleton",
                    "message": "A pipeline run is already in progress.",
                }
            return {
                "status":  "queued",
                "job_id":  job.job_id,
                "message": "Pipeline enqueued. Poll /pipeline/status/pipeline_singleton for updates.",
            }
        except Exception as exc:
            print(f"[API] ARQ enqueue failed: {exc} — falling back to Popen")

    import subprocess
    from pathlib import Path

    script_path = Path(__file__).parent.parent / "run_pipeline.sh"
    if not script_path.exists():
        raise HTTPException(status_code=404, detail="Pipeline script not found")

    try:
        proc = subprocess.Popen(
            ["bash", str(script_path)],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
        return {
            "status":  "started",
            "pid":     proc.pid,
            "message": "Pipeline started (legacy mode — Redis unavailable).",
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to start pipeline: {e}")


@app.get("/pipeline/status/{job_id}", tags=["pipeline"])
async def pipeline_status(job_id: str):
    # No rate limit — cheap Redis read, no side effects
    global _arq_pool
    if _arq_pool is None:
        raise HTTPException(
            status_code=503,
            detail="Redis is not available. Pipeline status tracking is disabled.",
        )

    try:
        from arq.jobs import Job, JobStatus

        job     = Job(job_id=job_id, redis=_arq_pool)
        jstatus = await job.status()

        if jstatus == JobStatus.not_found:
            return {"job_id": job_id, "status": "not_found"}

        result = await job.result(timeout=0)
        return {"job_id": job_id, "status": jstatus.value, "result": result}
    except Exception as exc:
        return {"job_id": job_id, "status": "unknown", "error": str(exc)}