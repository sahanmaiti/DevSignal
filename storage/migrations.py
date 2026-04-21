# storage/migrations.py
#
# PURPOSE:
#   Applies schema.sql to the database.
#   Safe to run multiple times — IF NOT EXISTS clauses prevent errors.
#
# WHEN TO RUN:
#   - First time setting up on a new machine
#   - After any change to storage/schema.sql
#   - If the Docker auto-init didn't run schema.sql for any reason
#
# USAGE:
#   python storage/migrations.py
#
# PLACEMENT: storage/migrations.py

import psycopg2
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from config.settings import DATABASE_URL


def run_migrations():
    # Build the path to schema.sql relative to this file's location
    schema_path = os.path.join(os.path.dirname(__file__), "schema.sql")

    print("=" * 50)
    print("DevSignal — Database Migrations")
    print("=" * 50)
    print(f"\nSchema file: {schema_path}")
    print(f"Database:    {DATABASE_URL[:45]}...\n")

    # Verify the schema file exists before trying to connect
    if not os.path.exists(schema_path):
        print(f"ERROR: schema.sql not found at {schema_path}")
        print("Make sure you're running this from the project root.")
        sys.exit(1)

    # Connect directly (not through the pool — migrations run once, not repeatedly)
    try:
        conn = psycopg2.connect(DATABASE_URL)
        # autocommit=True means each SQL statement commits immediately.
        # DDL statements (CREATE TABLE, CREATE INDEX, etc.) are auto-committed
        # in Postgres anyway, but this makes the behaviour explicit.
        conn.autocommit = True
        print("Connected to PostgreSQL successfully.\n")
    except psycopg2.OperationalError as e:
        print(f"ERROR: Could not connect to database.")
        print(f"Details: {e}")
        print("\nIs Docker running? Try: docker compose up -d")
        sys.exit(1)

    # Read and execute the schema file
    try:
        with open(schema_path, "r") as f:
            schema_sql = f.read()

        with conn.cursor() as cur:
            print("Applying schema.sql...")
            cur.execute(schema_sql)

        print("\nMigration complete. Tables created/verified:")

        # List what's in the database now
        with conn.cursor() as cur:
            cur.execute("""
                SELECT tablename
                FROM pg_tables
                WHERE schemaname = 'public'
                ORDER BY tablename
            """)
            tables = cur.fetchall()
            for (table_name,) in tables:
                print(f"  ✓ {table_name}")

        print("\nAll done.")

    except psycopg2.Error as e:
        print(f"\nERROR during migration: {e}")
        sys.exit(1)
    finally:
        conn.close()


if __name__ == "__main__":
    run_migrations()