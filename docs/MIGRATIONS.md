# DevSignal — Migration Strategy

## Current authoritative source of truth

**`storage/schema.sql`** is the single authoritative schema definition as of
Phase 0. It is:
- Mounted directly into Postgres's init directory by `docker-compose.yml`
  (`./storage/schema.sql:/docker-entrypoint-initdb.d/01_schema.sql:ro`)
- Executed by `storage/migrations.py` for manual/re-applied setups
- The only file containing every table, index, trigger, and function in
  correct dependency order (`users` before `device_tokens`/`applications`)

## Deprecated / historical files

| File | Status | Notes |
|---|---|---|
| `storage/migrate_v2.py` | **Superseded** | Added `device_tokens` + `applications` pre-multitenancy. Fully folded into `storage/schema.sql`. Kept for historical reference only — do not run against a fresh DB that already has `schema.sql` applied. |
| `storage/migrate_v3.py` | **Superseded** | Added `users`, `api_keys`, FK columns. Fully folded into `storage/schema.sql`. Same caveat as above. |
| `docker/initdb/01_schema.sql` | **Removed (B1)** | Was a stale, broken copy with incorrect FK ordering. Never used by docker-compose. |

## Alembic

`alembic/` contains a single migration (`0001_rename_to_jobs_fix_applications.py`)
that assumes a pre-ARCH-5 starting schema (a table literally named
`opportunities`). It is **not currently wired into the deployment or setup
flow** — fresh installs go through `storage/schema.sql` directly, which
already reflects the post-rename (`jobs` table + `opportunities` view) state.

### Decision (per project roadmap, Phase 1)

Alembic is the designated **going-forward** migration mechanism. This means:

1. `storage/schema.sql` remains the baseline for fresh installs (Docker
   init, new dev machines) until Phase 1 migration work is complete.
2. All **new** schema changes from this point forward must be expressed as
   Alembic migrations under `alembic/versions/`, not as ad-hoc scripts like
   `migrate_v2.py`/`migrate_v3.py`.
3. Before Phase 1 sign-off, run the Alembic-vs-manual schema comparison
   (diff `alembic upgrade head` output against `storage/schema.sql`) to
   confirm they produce an identical schema, then retire `storage/schema.sql`
   in favor of `alembic upgrade head` as the setup path.
4. `storage/migrations.py` will be retired once step 3 is complete and
   replaced with `alembic upgrade head` in setup docs and `docker-compose.yml`.

## For new contributors

- Setting up a fresh dev environment: `docker compose up -d` (schema
  auto-applies) or `python storage/migrations.py`.
- Do **not** run `migrate_v2.py` or `migrate_v3.py` against a database that
  already has `schema.sql` applied — they will no-op safely (all statements
  use `IF NOT EXISTS`) but should not be treated as part of the setup flow.
- Any new column/table/trigger: add it to `storage/schema.sql` for now, and
  flag Alembic migration work in the next Phase 1 session.

## Known behavior: JWT_SECRET fallback

`config/settings.py` currently does:
```python
JWT_SECRET = os.getenv("JWT_SECRET", secrets.token_hex(32))
```
If `JWT_SECRET` is not set in `.env`, a random secret is generated fresh on
every process start. This means:
- Fine for local single-session dev/testing.
- **Breaking** for anything long-running: every restart invalidates all
  previously issued JWTs, logging every user out.
- Flagged for Phase 3 (per roadmap's "non-persistent JWT secret fallback"
  stability fix) to either require the env var (matching the
  `PIPELINE_API_KEY` pattern, which already raises `RuntimeError` if unset)
  or persist a generated secret to disk/DB on first run.
