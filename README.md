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

`db:seed` runs migrations first, then inserts two fictional clubs (**Crowden Rovers**, short `CRW`) and (**Millbrook Wanderers**, short `MBW`), each with 23 players — **Crowden’s squad is rated noticeably higher** so home/away simulations favour them.

Re-running is safe only when **both** exist: seed skips if `CRW` **and** `MBW` are already present. If you previously seeded the old Manchester United data or only one club, **use a new SQLite file** (or delete `db/gaffer.sqlite`) before seeding again.

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
./bin/gaffer version  # prints the version (default when no args)
./bin/gaffer console  # IRB + DB + repos; `./bin/gaffer c` works too
```

Or:

```bash
bundle exec rake console
```

In the shell, `db` is the Sequel database (`db.tables`, `db[:clubs]`, …). Domain types live under `Gaffer::Domain`, persistence under `Gaffer::Repositories`.

## Architecture (short)

- **Domain** (`lib/gaffer/domain/`) — plain Ruby structs/value objects (no Sequel).
- **Persistence** (`lib/gaffer/repositories/`) — Sequel adapters that map rows ↔ domain objects.
- **Database** — SQLite via Sequel; migrations in [`db/migrations/`](db/migrations/).

See [`CLAUDE.md`](CLAUDE.md) for the full stack, phased roadmap (AI/BYOK, commands), and modelling details.

## Tests

```bash
bundle exec rake test
```

Uses Minitest; WebMock is required in `test/test_helper.rb` so tests do not hit the network.
