# CONTEXT — Gaffer domain glossary

Vocabulary for architecture and product discussions. Authoritative game rules and file layout remain in **CLAUDE.md**.

## Season and competition

- **League** — A single season instance: name, calendar **year**, **status** (`pending` / `active` / `complete`), and **current_gameweek**. There is no separate Season model; advancing years creates a new League row.
- **Gameweek** — One full round of fixtures: every club in the league plays once (even club count; no byes). The schedule is generated when the season starts.
- **Fixture** — A scheduled pairing (home club, away club, gameweek, played flag). DB column `season_id` is the league id at the Ruby layer.
- **Match** — Persisted result for a played fixture: scores, optional stats fields, reserved JSON for future events/ratings/narrative.

## Clubs and people

- **Club** — Squad container: linked to the active **League** via `league_id`, **reputation**, **board_target**, budgets, stadium, chairman fields.
- **Managed club** — The club assigned to the **Manager** save; the interactive side in league and friendly flows.
- **Manager** — Save slot identity: display name and `managed_club_id`.
- **Player** — Position, attributes, form/morale, contract; **overall** is position-weighted from attributes.

## Match day (league loop)

- **Scout briefing** — Pre-match dossier: **ScoutReport** from DB-only **ScoutReportBuilder**, rendered by template narrative + **ScoutBriefingTty** (before dugout).
- **Dugout** — **Ui::DugoutLineup** runs the XI prompts and edit loop; **Presenters::MatchdaySquad** only renders tables/lines; suggested XI from **Lineup.pick_best_xi**.
- **Tactic** / **shape** — One of **MatchEngine** tactic keys (e.g. balanced, park the bus); CPU sides use balanced in the league loop today.
- **Gameweek play** — One transaction: simulate every fixture in the round, persist **matches** and **goal_events**, mark fixtures played, bump **current_gameweek** (and complete the league on the final round). Orchestrated by **GameweekPlay**; **NextFixture** is the CLI entry that ensures DB bootstrap then delegates.

## Simulation and data

- **Match engine** — Deterministic Poisson sim: XIs, club reputation, tactic multipliers, shared RNG for scoreline and **ScorerPicker** goal scorers → **MatchResult**.
- **Goal event** — One row per goal for auditing and top scorers.
- **League table** — Derived from settled fixtures (**LeagueTable** + **TableRow**), not a persisted table.

## Code organisation (high level)

- **Domain** — Plain Ruby objects and pure logic; no ORM types in model structs (repositories map rows ↔ domain).
- **Repositories** — Sequel-backed persistence for clubs, players, fixtures, matches, leagues, etc.
- **Database.prepare** — Default app bootstrap (`Gaffer::Database.prepare`): connects to SQLite (ENV path, default file, or optional Sequel URL when not yet connected) and runs migrations. Use at CLI/menu/console/command entry unless you deliberately need a lighter path (e.g. tests that only `#disconnect`).
- **Commands** — User-facing operations (Thor tasks and menu): **StartLeague**, **NextFixture**, **PlayMatch**, standings/fixtures/scorers, etc.
- **Presenters** — TTY formatting (tables, scout screen, matchday squad).
- **Narrators** *(planned)* — LLM adapter seam for match copy; not shipped yet.

## Planned / not in DB yet

- **MatchSelection** — Persisted XI + tactic per fixture.
- **PlayerAvailability** — Injuries and suspensions per gameweek.
- **Transfer** — Fee, clubs, season/gameweek.
