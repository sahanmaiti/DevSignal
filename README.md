DevSignal

AI-powered iOS Internship Opportunity Radar

DevSignal is an automated opportunity discovery system built for aspiring iOS developers. It continuously scans job platforms, detects relevant iOS / Swift internships and junior roles, stores them in PostgreSQL, removes duplicates, and evolves into a full intelligence engine for scoring, outreach, and application tracking.

Instead of manually checking job boards every day, DevSignal is designed to do the searching for you.

⸻

Why I Built This

Breaking into iOS development is competitive.

Many strong opportunities are missed because:

* Jobs are posted briefly and disappear fast
* Listings are spread across multiple platforms
* Manual searching is repetitive and time-consuming
* Tracking applications becomes messy
* Great roles are hard to prioritize quickly

DevSignal solves this by creating a personal job radar focused on iOS careers.

⸻

Core Features

Current (Completed)

* Multi-module Python project architecture
* RemoteOK scraper for iOS-relevant roles
* PostgreSQL database with persistent storage
* Dockerized local infrastructure
* Duplicate prevention using job hashing
* Migration system for schema updates
* Scrape run logging + analytics-ready tables
* GitHub-based progress tracking

In Progress

* Additional scrapers (HackerNews, YC, Indeed, more)
* Advanced filtering engine
* Better metadata extraction

Planned

* AI opportunity scoring
* Recruiter enrichment
* Personalized outreach generation
* Telegram alerts
* n8n workflow automation
* Streamlit dashboard
* Portfolio-grade UI

⸻

Tech Stack

Layer	Tools
Language	Python 3.12
Database	PostgreSQL
Containers	Docker + Docker Compose
Automation	n8n
AI Layer	Claude API (planned)
Dashboard	Streamlit (planned)
Notifications	Telegram Bot API (planned)

⸻

Project Roadmap

Phase	Status	Description
Phase 1	✅ Complete	Environment setup + project structure + first scraper
Phase 2	✅ Complete	PostgreSQL + Docker + persistence layer
Phase 3	🔄 Next	More scrapers + filters
Phase 4	⬜ Planned	Telegram notifications
Phase 5	⬜ Planned	AI opportunity scoring
Phase 6	⬜ Planned	Recruiter enrichment + outreach
Phase 7	⬜ Planned	n8n automation
Phase 8	⬜ Planned	Dashboard + final polish

⸻

Current Architecture

Job Platforms
   ↓
Scrapers
   ↓
Normalizer + Deduplicator
   ↓
PostgreSQL Database
   ↓
(Upcoming)
AI Scoring Engine
Recruiter Finder
Alerts
Dashboard

⸻

Local Setup

1. Clone the repository

git clone https://github.com/sahanmaiti/DevSignal.git
cd DevSignal

2. Create virtual environment

python3 -m venv venv
source venv/bin/activate

3. Install dependencies

pip install -r requirements.txt

4. Start infrastructure

docker compose up -d

5. Run database migrations

python storage/migrations.py

6. Run scraper pipeline

python run_scraper.py

⸻

Example Workflow

1. Scrape jobs from sources
2. Detect relevant iOS roles
3. Remove duplicates
4. Save only new opportunities
5. Score jobs (future)
6. Send alerts (future)
7. Track applications

⸻

Repository Structure

DevSignal/
├── ai/
├── config/
├── notifications/
├── processors/
├── scrapers/
├── storage/
├── tests/
├── docker-compose.yml
├── run_scraper.py
└── README.md

⸻

Current Progress Snapshot

* Persistent database working
* Containers healthy
* Schema migrations working
* GitHub deployment active
* Phase 2 completed successfully

⸻

Vision

DevSignal is more than a scraper.

The long-term goal is to build an intelligent career operating system for iOS developers:

* Discover hidden opportunities early
* Prioritize best-fit roles automatically
* Generate outreach that gets replies
* Track the full job hunt pipeline
* Reduce randomness in career growth

⸻

About Me

Built by Sahan Maiti — aspiring iOS developer focused on Swift, SwiftUI, automation, and building real systems that solve practical problems.

GitHub: https://github.com/sahanmaiti

⸻

Support / Feedback

If you have ideas, suggestions, or want to collaborate, feel free to open an issue or connect.

⸻

Star the Repo ⭐

If you like the concept or want to follow the build journey, consider starring the repository.
