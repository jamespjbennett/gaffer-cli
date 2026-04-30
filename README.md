# Gaffer

Terminal-based football management game in Ruby: league seasons, squads, fixtures, and (later) LLM-driven narrative on top of a deterministic match core. This repo is under active development; the playable loop and AI layer are still being built.

Full design notes and conventions live in [`CLAUDE.md`](CLAUDE.md).

## Requirements

- Ruby (version in [`.ruby-version`](.ruby-version); 3.4.x is used in development)
- [Bundler](https://bundler.io/)

## Setup

```bash
cd gaffer_cli
bundle install
bundle exec rake db:seed
```

First launch of `./bin/gaffer` runs **migrations** automatically, then asks you to **pick a manager name** and **which seeded club you manage** (stored in the `managers` table). Clearing the SQLite file or switching `GAFFER_DB_PATH` resets that choice.

`db:seed` runs migrations first, then inserts **ten** fictional clubs in **five loosely paired tiers** (strongest → weakest: `CRW`, `STB`, `KLF`, `VPK`, `AHU`, `RCT`, `FAB`, `LAN`, `HCY`, `MBW`). Each club has **23 players** plus reputation, budget, stadium, and board metadata.

Re-running skips if **all ten** short codes already exist. If you have a partial seed or old dev data from an earlier checkout, delete `db/gaffer.sqlite` or point `GAFFER_DB_PATH` at a new file before seeding again.

By default the SQLite file is `db/gaffer.sqlite` (the directory is created if needed). Override with:

```bash
export GAFFER_DB_PATH=/absolute/path/to/your.sqlite
```

To apply migrations only:

```bash
bundle exec rake db:migrate
```

## CLI

From the `gaffer_cli` directory:

```bash
chmod +x bin/gaffer   # once, if your checkout doesn’t mark it executable yet
./bin/gaffer           # opens the interactive menu (same as `./bin/gaffer start`)
./bin/gaffer version    # prints the version string
./bin/gaffer console    # IRB + DB + repos; `./bin/gaffer c` works too
```

Or:

```bash
bundle exec rake console
```

In the shell, `db` is the Sequel database (`db.tables`, `db[:clubs]`, …). Domain types live under `Gaffer::Domain`, persistence under `Gaffer::Repositories`.

## Architecture (short)

- **Domain** (`lib/gaffer/domain/`) — plain Ruby structs/value objects (no Sequel), including **`MatchEngine`** / **`MatchResult`** for simulation (see below).
- **Persistence** (`lib/gaffer/repositories/`) — Sequel adapters that map rows ↔ domain objects.
- **Database** — SQLite via Sequel; migrations in [`db/migrations/`](db/migrations/).

See [`CLAUDE.md`](CLAUDE.md) for the full stack, phased roadmap (AI/BYOK, commands), and modelling details.

## Match engine (current behaviour)

`Gaffer::Domain::MatchEngine` ([`lib/gaffer/domain/match_engine.rb`](lib/gaffer/domain/match_engine.rb)) is **pure Ruby** — no DB or CLI. You call **`simulate`** with two **`Club`** records and their **`Player`** arrays (e.g. from `PlayerRepository`), plus optional **`home_tactic` / `away_tactic`** (defaults `:balanced`; see **`TACTIC_MODIFIERS`** in code).

Rough flow:

1. **Strength** — For each squad, compute mean *attack* and *defence* numbers from player attributes (position-weighted; goalkeepers affect defence more than attack).
2. **Club + tactics** — Multiply by a **reputation** factor, then by the chosen tactic’s attack/defence multipliers (e.g. attacking vs park the bus).
3. **Expected goals (λ)** — For each side, combine *this* team’s attack with the *opponent’s* defence into a share of “threat”, add a small **home** edge for the hosts, a bit of **random jitter**, then scale to a Poisson rate (λ). That value is stored on the result as `home_xg_lambda` / `away_xg_lambda` for inspection.
4. **Scoreline** — Sample **goals** for each team from a **Poisson** distribution with that λ (Knuth-style sampler, as in [`CLAUDE.md`](CLAUDE.md)).

The result is a **`MatchResult`**: final scores, λ values, and the effective attack/defence ratings used. There are **no** scorers, cards, or possession in this layer yet.

**RNG:** omit **`seed:`** to get **different scorelines each call**; pass an **integer seed** when you want the **same outcome** twice (tests, debugging).

Try it after seeding/clubs loading in **`bundle exec rake console`** — [`test/domain/match_engine_test.rb`](test/domain/match_engine_test.rb) has examples using synthetic squads.

## Tests

```bash
bundle exec rake test
```

Uses Minitest; WebMock is required in `test/test_helper.rb` so tests do not hit the network.
