# run_watchlist.py
#
# PURPOSE:
#   Manages the companies watchlist — iOS companies that haven't
#   posted internships yet. When they do, you'll be first to apply.
#
# USAGE:
#   python run_watchlist.py add "Stripe" "Mobile banking iOS app"
#   python run_watchlist.py list
#   python run_watchlist.py check   (checks if watchlist companies now have jobs)
#
# PLACEMENT: project root

import sys
import os
import argparse

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from storage.db_client import db


def add_company(company: str, description: str,
                url: str = "", linkedin: str = "",
                funding: str = ""):
    """Adds a company to the watchlist."""
    db.add_to_watchlist(
        company=company,
        ios_product_desc=description,
        company_url=url,
        linkedin_url=linkedin,
        funding_stage=funding,
    )
    print(f"Added '{company}' to watchlist.")


def list_companies():
    """Lists all companies on the watchlist."""
    companies = db.get_watchlist()
    if not companies:
        print("Watchlist is empty.")
        print("Add companies with: python run_watchlist.py add 'Company' 'Description'")
        return

    print(f"\n{'Company':<25} {'iOS Product':<40} {'Funding'}")
    print(f"{'─'*25} {'─'*40} {'─'*15}")
    for c in companies:
        print(
            f"{c['company'][:23]:<25} "
            f"{c['ios_product_desc'][:38]:<40} "
            f"{c.get('funding_stage', '')}"
        )
    print(f"\nTotal: {len(companies)} companies on watchlist")


def check_watchlist():
    """
    Checks if any watchlist companies now have jobs in the opportunities table.
    """
    companies = db.get_watchlist()
    if not companies:
        print("Watchlist is empty.")
        return

    print("Checking watchlist companies for new job postings...\n")
    found_any = False

    for c in companies:
        company_name = c["company"]

        # Check if this company appears in opportunities table
        jobs = db.get_all_opportunities()
        matches = [
            j for j in jobs
            if company_name.lower() in j.get("company", "").lower()
        ]

        if matches:
            found_any = True
            print(f"  {company_name}: {len(matches)} job(s) found!")
            for j in matches[:2]:
                print(f"    - {j['role']} (score: {j.get('opportunity_score', 'unscored')})")
                print(f"      {j['apply_link']}")

    if not found_any:
        print("  No watchlist companies have posted jobs yet.")
        print("  Keep running the pipeline — they'll appear here when they do.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="DevSignal Watchlist")
    subparsers = parser.add_subparsers(dest="command")

    # add command
    add_parser = subparsers.add_parser("add", help="Add company to watchlist")
    add_parser.add_argument("company",     help="Company name")
    add_parser.add_argument("description", help="What iOS product they build")
    add_parser.add_argument("--url",       default="", help="Company website")
    add_parser.add_argument("--linkedin",  default="", help="Company LinkedIn URL")
    add_parser.add_argument("--funding",   default="", help="Funding stage")

    # list command
    subparsers.add_parser("list", help="List all watchlist companies")

    # check command
    subparsers.add_parser("check", help="Check if any companies have posted jobs")

    args = parser.parse_args()

    if args.command == "add":
        add_company(
            args.company, args.description,
            url=args.url, linkedin=args.linkedin, funding=args.funding,
        )
    elif args.command == "list":
        list_companies()
    elif args.command == "check":
        check_watchlist()
    else:
        parser.print_help()