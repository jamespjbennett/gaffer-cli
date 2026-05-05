# Gaffer

Terminal-based football management game in Ruby. Build a squad, run a league season, and manage your club through a full home-and-away campaign — all from the command line.

Full design notes and conventions live in [`CLAUDE.md`](CLAUDE.md).

---

## Requirements

- Ruby 3.4.x (see [`.ruby-version`](.ruby-version))
- [Bundler](https://bundler.io/)

## Setup

```bash
cd gaffer_cli
bundle install
bundle exec rake db:seed
```

First launch of `./bin/gaffer` runs **migrations** automatically, then guides you through onboarding: pick a manager name and choose which seeded club you manage. That choice is stored in the `managers` table; delete `db/gaffer.sqlite` or point `GAFFER_DB_PATH` at a fresh file to reset.

`db:seed` inserts **ten** fictional clubs in **five loosely paired tiers**:

| Tier | Clubs |
|------|-------|
| Top | CRW, STB |
| Upper mid | KLF, VPK |
| Mid | AHU, RCT |
| Lower mid | FAB, LAN |
| Bottom | HCY, MBW |

Each club has **23 players** plus reputation, budget, stadium, and board metadata.

Re-running seed skips if all ten short codes already exist. If you have a partial seed or old dev data, delete `db/gaffer.sqlite` or point `GAFFER_DB_PATH` at a new file first.

By default the SQLite file lives at `db/gaffer.sqlite` (the directory is created if missing). Override with:

```bash
export GAFFER_DB_PATH=/absolute/path/to/your.sqlite
```

To apply migrations only:

```bash
bundle exec rake db:migrate
```

---

## CLI

From the **`gaffer_cli`** directory:

```bash
chmod +x bin/gaffer   # once, if checkout doesn't mark it executable
./bin/gaffer           # interactive menu (same as `./bin/gaffer start`)
./bin/gaffer next      # play the next league gameweek
./bin/gaffer table     # league standings
./bin/gaffer fixtures  # all fixtures and results
./bin/gaffer scorers   # top 20 goal scorers
./bin/gaffer version   # version string
./bin/gaffer console   # IRB + DB (alias: ./bin/gaffer c)
```

Archive flags (`table`, `fixtures`, `scorers`):

```bash
./bin/gaffer table --previous     # last completed season
./bin/gaffer table --year 2025    # a specific year
```

Ruby console via Rake (from repo root):

```bash
bundle exec rake console
```

Inside IRB, `db` is the Sequel connection (`db.tables`, `db[:clubs].all`, …); domain objects live under `Gaffer::Domain`, persistence under `Gaffer::Repositories`.

---

## Game loop

### First run — onboarding

1. Enter your manager name.
2. Pick a club from the seeded ten (reputation shown alongside each).
3. A board letter is generated based on the club's target (`avoid_relegation` → `title`).
4. Press any key → main menu.

### `./bin/gaffer next` — league gameweek

Each call plays **one full round** (all five fixtures in the gameweek):

1. **Scout screen** — opponent table position, form, attack/defence read, and a watch-player line. Below that, a coach strip flags any rising or falling players in your suggested XI.
2. **Dugout** — review your proposed XI for the fixture. Accept it or swap slots individually.
3. **Tactic picker** — choose from *All-Out Attack → Park the Bus* (five settings).
4. **Simulate** — your match uses your XI and tactic; the other four fixtures auto-sim (best XI, balanced tactic).
5. **Post-round** — your scoreline and scorers, the other results, a standings snapshot. A board note appears reflecting the result, the scoreline, and your chairman's mood.

Repeat through all 18 gameweeks. The final round increments every player's age, marks the season complete, and offers a new season.

### End of season

When the last gameweek is saved:

- Every player ages by one year.
- On the next season start, form drifts halfway back to neutral and morale steps one level toward *okay*.
- A new league row is created and fixtures are regenerated.

---

## Match engine

`Gaffer::Domain::MatchEngine` ([`lib/gaffer/domain/match_engine.rb`](lib/gaffer/domain/match_engine.rb)) is **pure Ruby** with no database or CLI coupling.

**Flow:**

1. **Contributions** — Per-player attack and defence scores, position-weighted (e.g. attackers weight shooting/pace/dribbling; goalkeepers weight goalkeeping).
2. **Morale × form multiplier** — Each player's morale sets a contribution band (unhappy → ecstatic); form 1–10 slides within that band.
3. **Club + tactics** — Squad means are scaled by reputation, then by the chosen tactic's attack/defence multipliers.
4. **Poisson λ** — Home advantage + opponent defence → expected goals rate per side. Stored as `home_xg_lambda` / `away_xg_lambda`.
5. **Scoreline** — Goals sampled from Poisson(λ) via a Knuth-style sampler.
6. **Scorers** — `ScorerPicker` weights each player by shooting/pace/dribbling and picks from the same `Random` stream, so a fixed seed reproduces the exact same scorers.

**Tactic modifiers (attack × / defence ×):**

| Tactic | Attack | Defence |
|---|---|---|
| All-Out Attack | ×1.28 | ×0.72 |
| Attacking | ×1.12 | ×0.88 |
| Balanced | ×1.0 | ×1.0 |
| Defensive | ×0.88 | ×1.12 |
| Park the Bus | ×0.72 | ×1.28 |

Pass an integer **`seed:`** to get a reproducible result; omit it for a fresh scoreline each call.

---

## Morale & form

Every player carries `form` (1–10, neutral = 5) and `morale` (`:unhappy` → `:ecstatic`). After each gameweek:

- Match outcomes, goals scored, and clean sheets apply deltas.
- Defenders and the goalkeeper take extra hits for goals conceded.
- Form decays passively toward 5 when not involved.

All updates run in the same SQLite transaction as the matches and goal events.

---

## Narratives (template-based)

All copy is rule-based — no external services or API keys required.

| Narrative | Source |
|---|---|
| Pre-season board letter | `board_target` field on the club |
| Pre-match scout briefing | Live table, recent form, attack/defence ratings, top scorer |
| Coach strip | Morale × form notables in your suggested XI |
| Post-match board reaction | Result, scoreline, margin, chairman mood |

---

## Architecture

```
lib/gaffer/
├── domain/          # Pure Ruby — no ORM, no I/O (MatchEngine, Lineup, ScorerPicker, …)
├── repositories/    # Sequel adapters (clubs, players, fixtures, matches, goal_events, …)
├── commands/        # Thor command implementations
├── narratives/      # Template copy (board_reaction, scout_briefing, coach_training_*)
├── presenters/      # TTY output (tables, scout brief, matchday squad, board reaction)
└── ui/              # Menu loop + onboarding
```

Migrations live in [`db/migrations/`](db/migrations/); seeds in [`db/seeds/`](db/seeds/).

---

## Tests

```bash
bundle exec rake test
```

Minitest with the `minitest/spec` DSL throughout. WebMock is loaded in `test_helper.rb` so tests never hit the network. The suite covers the match engine, fixture generator, morale/form logic, all repositories, CLI commands, and narrative templates.
