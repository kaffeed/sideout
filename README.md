# Sideout

A volleyball session scheduling and player management platform with intelligent waitlist management.

## Overview

Sideout is a Phoenix LiveView application designed for volleyball trainers and clubs to manage training sessions, player registrations, and capacity constraints. It solves the common problem of manually managing session capacity, waitlists, and fair player prioritization.

Trainers create sessions with flexible capacity rules, share a public link with players, and Sideout automatically assigns players to confirmed spots or waitlists based on availability and attendance history. The platform supports multiple clubs, co-trainer collaboration, and real-time updates across all connected users.

Built with Elixir and Phoenix LiveView, Sideout provides a seamless, real-time experience without requiring players to create accounts - they simply register via shareable links.

## Key Features

- **Flexible Session Scheduling** - Create sessions with customizable capacity constraints (max/min players, even numbers, divisible by N, per-field scaling)
- **Intelligent Waitlist Management** - Automatic priority-based ordering using attendance history and reliability metrics
- **Public Registration Links** - Share sessions via unique URLs; players register without authentication
- **Multi-Club Organization** - Support multiple clubs with membership management, co-trainers, and guest club invitations
- **Real-Time Updates** - LiveView with PubSub for instant capacity updates, waitlist promotions, and notifications
- **Attendance Tracking** - Check-in system with player statistics, no-show tracking, and attendance history
- **Reusable Templates** - Create session templates for recurring training schedules
- **Priority Calculator** - Smart algorithm that ranks waitlist players based on attendance patterns and reliability

## Tech Stack

- **Backend:** Elixir 1.14+, Phoenix Framework 1.7+, PostgreSQL 16
- **Frontend:** Phoenix LiveView, Tailwind CSS 3.4
- **Real-time:** Phoenix PubSub
- **Authentication:** Built-in Phoenix authentication (trainers only)
- **Rate Limiting:** Hammer (ETS-backed)
- **QR Codes:** eqrcode for shareable session links

## Prerequisites

- Elixir 1.14 or higher
- PostgreSQL 16 or higher
- Phoenix 1.7+
- Node.js (for asset compilation)

## Quick Start

```bash
# Clone the repository
git clone <repository-url>
cd sideout

# Install dependencies
mix deps.get

# Setup database (creates, migrates, and seeds)
mix ecto.setup

# Install and setup frontend assets
mix assets.setup

# Start the Phoenix server
mix phx.server
```

Visit [http://localhost:4000](http://localhost:4000) to access the application.

## Development Setup

### Using Docker (Recommended)

Start PostgreSQL and pgAdmin using Docker Compose:

```bash
docker-compose up -d
```

This starts:
- PostgreSQL on port **5434** (username/password: `postgres`)
- pgAdmin on port **5050** (admin@sideout.com / admin)

### Test Accounts

After running `mix ecto.setup`, log in at [http://localhost:4000/users/log_in](http://localhost:4000/users/log_in)

| Email | Password | Role |
|-------|----------|------|
| coach.mike@sideout.com | password1234 | Trainer |
| coach.sarah@sideout.com | password1234 | Trainer |
| coach.alex@sideout.com | password1234 | Trainer |

### Sample Data

The seed file (`priv/repo/seeds.exs`) creates:
- 3 trainer accounts with different specializations
- 30 players with realistic attendance histories
- 5 session templates (Beginner, Intermediate, Advanced, Open, Beach)
- 12 scheduled sessions (past, current week, next week)
- 100+ registrations including confirmed players and waitlists

## Usage

### Creating a Session

1. Log in as a trainer
2. Navigate to **Sessions** > **New Session**
3. Choose a template or create from scratch
4. Set date, time, fields, and capacity constraints
5. Save and share the registration link with players

### Sharing with Players

Each session has a unique shareable link (e.g., `/signup/abc123`) that players can access without logging in. The link includes:
- Session details (date, time, location, skill level)
- Current capacity status
- Registration form
- QR code for easy mobile access

### Managing Registrations

When players register:
- **Confirmed:** Automatically assigned if space is available
- **Waitlisted:** Automatically waitlisted if session is full
- **Priority Ranking:** Waitlist ordered by attendance history

When a player cancels:
- Next waitlisted player is automatically promoted
- All affected players receive status updates

### Capacity Constraints

Define flexible capacity rules using a simple constraint syntax:

```elixir
"max_18"                    # Maximum 18 players
"max_18,min_12"             # Between 12-18 players
"max_18,min_12,even"        # 12-18 players, must be even number
"per_field_9"               # 9 players per field (scales with field count)
"divisible_by_6"            # Must be divisible by 6 (e.g., for 3v3 teams)
```

**Use Cases:**
- `max_20` - Simple capacity limit for space constraints
- `max_16,min_8` - Ensure enough players for effective training
- `even` - Pair up players for partner drills
- `divisible_by_6` - Create balanced 3v3 or 6v6 teams
- `per_field_9` - Allocate 9 players per available court

Constraints are composable and evaluated together using the Specification Pattern.

## Project Structure

```
sideout/
├── lib/
│   ├── sideout/                    # Business logic contexts
│   │   ├── accounts/               # Trainer authentication
│   │   ├── clubs/                  # Multi-club organization
│   │   ├── scheduling/             # Core domain logic
│   │   │   ├── constraints/        # Capacity constraint implementations
│   │   │   ├── player.ex           # Player schema and stats
│   │   │   ├── session.ex          # Training session schema
│   │   │   ├── registration.ex     # Player registrations
│   │   │   └── priority_calculator.ex  # Waitlist algorithm
│   │   └── scheduling.ex           # Scheduling context API
│   │
│   └── sideout_web/                # Web interface
│       ├── live/
│       │   ├── session_signup_live.ex    # Public registration
│       │   ├── cancellation_live.ex      # Registration cancellation
│       │   └── trainer/                  # Authenticated views
│       │       ├── dashboard_live.ex     # Trainer overview
│       │       ├── session_live/         # Session management
│       │       ├── template_live/        # Template CRUD
│       │       ├── player_live/          # Player database
│       │       └── attendance_live.ex    # Check-in system
│       └── components/                   # Reusable UI components
│
├── priv/repo/
│   ├── migrations/                 # Database migrations
│   └── seeds.exs                   # Sample data
│
├── assets/                         # Frontend assets
│   ├── css/app.css                 # Custom styles
│   ├── js/app.js                   # JavaScript hooks
│   └── tailwind.config.js          # Custom theme
│
└── test/                           # Test suite
```

### Context Organization

Sideout follows Phoenix's Context Pattern for clean separation of concerns:

- **Scheduling** - Core domain with sessions, players, registrations, and templates
- **Accounts** - Trainer authentication and user management
- **Clubs** - Multi-tenant organization with memberships and permissions
- **Authorization** - Access control for multi-club features

## Development

### Running Tests

```bash
# Run all tests
mix test

# Run tests with coverage
mix test --cover

# Run specific test file
mix test test/sideout/scheduling_test.exs
```

### Database Commands

```bash
mix ecto.create              # Create database
mix ecto.migrate             # Run migrations
mix ecto.rollback            # Rollback last migration
mix ecto.reset               # Drop, create, migrate, and seed
mix run priv/repo/seeds.exs  # Seed database only
```

### Code Quality

```bash
# Format code (auto-fix)
mix format

# Static analysis
mix credo

# Check formatting without changes
mix format --check-formatted
```

### Asset Commands

```bash
# Build assets for development
mix assets.build

# Deploy assets (minified for production)
mix assets.deploy
```

## Architecture

### Design Patterns

**Specification Pattern**
Capacity constraints are implemented using the Specification Pattern, allowing flexible composition of rules. Each constraint (max, min, even, etc.) implements the `Specification` protocol and can be combined with AND/OR logic.

**Phoenix Context Pattern**
Business logic is organized into bounded contexts (Scheduling, Accounts, Clubs), providing clear API boundaries and separation of concerns.

**PubSub Pattern**
Real-time updates are broadcast via Phoenix.PubSub. When capacity changes occur (new registration, cancellation, waitlist promotion), all connected LiveView clients receive instant updates.

**Share Token System**
Public access without authentication is enabled through unique, time-limited share tokens. Each session generates a nanoid-based token for secure, shareable URLs.

### Database Schema

**Core Entities:**
- `users` - Trainer accounts with authentication
- `clubs` - Organization/club records
- `club_memberships` - User-club relationships with roles
- `players` - Participant records with attendance statistics
- `session_templates` - Reusable session configurations
- `sessions` - Training sessions with capacity constraints
- `registrations` - Player sign-ups with status (confirmed/waitlisted)
- `session_cotrainers` - Co-trainer assignments for shared management
- `session_guest_clubs` - Cross-club session invitations

### Priority Calculator

The waitlist priority system ranks players using a weighted algorithm based on:
- **Attendance Rate** - Percentage of attended sessions vs. registered
- **Recent Activity** - More weight for recent session attendance
- **Reliability** - Lower priority for players with high no-show rates
- **Registration Time** - Tiebreaker for equal priority scores

This ensures fair distribution of session spots and rewards reliable, active players.

### Real-Time Features

LiveView components subscribe to PubSub topics for:
- Capacity updates when registrations change
- Waitlist promotions when spots open
- Session cancellations and modifications
- Attendance check-in updates

All changes are broadcast instantly to connected trainers and players viewing the session.

## Documentation

- **Implementation Plan:** See [plan.md](plan.md) for comprehensive development roadmap and progress tracking
- **Code Documentation:** Inline `@moduledoc` and `@doc` attributes throughout the codebase
- **Migrations:** Database schema history in `priv/repo/migrations/`

## Contributing

This is a personal project, but contributions, issues, and feature requests are welcome.

## License

MIT License

Copyright (c) 2026

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
