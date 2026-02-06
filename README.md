# Sideout - Volleyball Session Scheduling App

A Phoenix LiveView application for managing volleyball training sessions, player registrations, and intelligent waitlist management.

## Features

### ✅ Implemented (Phases 1-4)
- **Trainer Dashboard**: Overview of upcoming sessions with statistics
- **Session Templates**: Reusable templates with flexible capacity constraints
- **Capacity Management**: Configurable constraints (max, min, even numbers, divisible by, per-field)
- **Registration System**: Automatic confirmed/waitlist assignment
- **Priority Queue**: Intelligent waitlist ordering based on attendance history
- **Player Management**: Track attendance, no-shows, and registration history
- **Real-time Updates**: LiveView for instant capacity updates

### 🚧 Coming Soon (Phases 5-9)
- Session calendar view and management
- Public player sign-up (no authentication required)
- Attendance tracking and check-in
- Advanced player statistics
- Comprehensive testing

## Getting Started

### Prerequisites
- Elixir 1.14+
- Phoenix 1.7+
- PostgreSQL

### Installation

1. Clone the repository
2. Install dependencies:
   ```bash
   mix deps.get
   ```

3. Set up the database (creates, migrates, and seeds):
   ```bash
   mix ecto.setup
   ```

4. Start the Phoenix server:
   ```bash
   mix phx.server
   ```

5. Visit [`localhost:4000`](http://localhost:4000)

### Test Accounts

Login at http://localhost:4000/users/log_in

| Email | Password | Role |
|-------|----------|------|
| coach.mike@sideout.com | password1234 | Trainer |
| coach.sarah@sideout.com | password1234 | Trainer |
| coach.alex@sideout.com | password1234 | Trainer |

### Sample Data

The seed file creates:
- 3 trainer accounts
- 30 players with realistic attendance data
- 5 session templates with various constraints
- 12 scheduled sessions
- 100+ registrations including waitlists

## Architecture

### Tech Stack
- **Backend**: Elixir, Phoenix Framework
- **Frontend**: Phoenix LiveView, Tailwind CSS
- **Database**: PostgreSQL
- **Real-time**: Phoenix PubSub

### Key Design Patterns
- **Specification Pattern**: Flexible, composable capacity constraints
- **Context Pattern**: Clean separation of business logic
- **LiveView**: Real-time updates without JavaScript

### Capacity Constraints

Session capacity is managed using a flexible constraint system:

```elixir
# Examples:
"max_18"                  # Maximum 18 players
"max_18,min_12"          # Between 12-18 players
"max_18,min_12,even"     # 12-18 players, must be even
"per_field_9"            # 9 players per field (scales with fields)
"divisible_by_6"         # Must be divisible by 6 (e.g., for 3v3 teams)
```

## Project Structure

```
lib/sideout/
├── accounts/           # User (trainer) authentication
├── scheduling/         # Core domain logic
│   ├── player.ex
│   ├── session_template.ex
│   ├── session.ex
│   ├── registration.ex
│   ├── priority_calculator.ex
│   ├── registration_token.ex
│   └── constraints/   # Capacity constraint implementations
└── scheduling.ex      # Context API

lib/sideout_web/
├── live/
│   └── trainer/       # Trainer-facing LiveViews
│       ├── dashboard_live.ex
│       └── template_live/
└── components/        # Reusable UI components
```

## Development

### Running Tests
```bash
mix test
```

### Database Commands
```bash
mix ecto.create      # Create database
mix ecto.migrate     # Run migrations
mix ecto.reset       # Drop, create, migrate, and seed
mix run priv/repo/seeds.exs  # Seed database
```

### Code Quality
```bash
mix format           # Format code
mix credo           # Static analysis (if configured)
```

## Documentation

See [plan.md](plan.md) for the comprehensive implementation plan and progress tracking.

## License

Copyright © 2026
