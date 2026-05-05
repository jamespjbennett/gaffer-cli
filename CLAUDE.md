# CLAUDE.md — Gaffer

> A football management CLI built in Ruby — sim core and league play today; AI narrative (BYOK) on the roadmap.

---

## Project Overview

Gaffer is a terminal-based football management CLI in Ruby: **deterministic match engine** (with **persistent morale + form** skewing XI contributions), **league loop**, dugout XI + tactics, **template scout + coaching notes + board copy** — with **optional LLM narrative** planned later (BYOK patterns below).

Design goals include clean domain modelling and a narrator adapter boundary **when** Phase 3 lands.

The project is designed to demonstrate:
- Clean Ruby domain modelling
- Thoughtful AI integration (not AI for everything)
- A modular adapter pattern for swappable AI backends
- Engineering discipline around prompt design and LLM output handling
- A bring-your-own-key (BYOK) model for open source sustainability

---

## Tech Stack

- **Language**: Ruby 3.x
- **CLI framework**: Thor (commands) + TTY toolkit (`tty-prompt`, `tty-table`, `tty-box`, `pastel`) for rich terminal UI
- **Persistence**: SQLite via Sequel ORM (lightweight, file-based, no setup required)
- **AI layer** *(planned)*: Anthropic Ruby SDK + narrator adapter — not yet in `Gemfile` or `lib/`
- **Testing**: Minitest + minitest/spec DSL + WebMock for blocking real HTTP in tests
- **Config**: `dotenv` for local dev; BYOK file resolution described below is **roadmap** (no `lib/gaffer/config.rb` yet)

---

## API Key Setup (BYOK) — *roadmap*

The shipped game is **fully offline**: match sim, scout briefing, board letter, and tables use DB + template copy only.

When the narrator layer lands, the intended pattern is:

1. `ANTHROPIC_API_KEY` environment variable
2. `~/.config/gaffer/config.yml` → `anthropic_api_key:`
3. Optional first-run prompt to save the key (see sketch in older commits / Phase 3)

There is **no** `gaffer config` command, **`--no-ai` flag**, or Anthropic client in this tree yet.

---

## Architecture

```
gaffer/
├── bin/
│   └── gaffer                  # Executable entry point
├── lib/
│   gaffer/
│   ├── cli.rb                  # Thor: table, fixtures, scorers, next, start, console, version
│   ├── database.rb             # Sequel connection + migrations
│   ├── console.rb              # IRB entry
│   │
│   ├── domain/                 # Pure domain — no ORM, no LLM calls
│   │   ├── club.rb, player.rb, manager.rb, league.rb
│   │   ├── fixture.rb, fixture_generator.rb, match.rb, match_result.rb
│   │   ├── league_table.rb, table_row.rb
│   │   ├── lineup.rb           # best XI (4-3-3) for sim + scout ratings
│   │   ├── match_engine.rb     # Poisson sim, morale/form multipliers on contributions, scout rating helper
│   │   ├── morale_form_multiplier.rb  # per-player contrib band from morale + form (1–10)
│   │   ├── morale_updater.rb   # aggregates post-round deltas (calls domain/morale/*)
│   │   ├── morale_round_row.rb # fixture + result + home/away XI for rollup
│   │   ├── morale/             # SideLine, ConcedeHits, DefenderPick, FixtureRoll, FormNorm, MoraleStep
│   │   ├── scorer_picker.rb    # weighted goal scorers (same RNG as match)
│   │   ├── goal_event.rb
│   │   ├── scout_report.rb     # opponent dossier value object
│   │   ├── coaching_context.rb # suggested-XI notable moods for coach briefing
│   │
│   ├── narratives/             # Template copy only (no API)
│   │   ├── board_expectations.rb    # onboarding board letter (`board_target`)
│   │   ├── scout_briefing.rb        # conversational paragraphs from ScoutReport
│   │   ├── coach_training_matrix.rb # worry vs cheer phrases (GK vs outfield buckets)
│   │   └── coach_training_report.rb # CoachingContext → strings (On the up / Cause for concern)
│   │
│   ├── presenters/             # TTY output
│   │   ├── matchday_squad.rb, league_table_tty.rb, league_table_view.rb
│   │   ├── season_fixtures_tty.rb, top_scorers_tty.rb
│   │   └── scout_briefing_tty.rb   # scout + coaching section + keypress before dugout
│   │
│   ├── repositories/           # Sequel persistence
│   │   └── … club, player (form/morale batch + season age + soft reset), manager, league, fixture, match, goal_event
│   │
│   ├── commands/
│   │   ├── start_league.rb, next_fixture.rb, play_match.rb
│   │   ├── league_standings.rb, season_fixtures.rb, top_scorers.rb
│   │   └── support/season_lookup.rb, scout_report_builder.rb, scout_coaching_notables.rb, league_reads.rb, gameweek_* …
│   │
│   └── ui/
│       ├── menu.rb             # Interactive loop
│       └── onboarding.rb       # First-run manager + club
│
├── db/
│   ├── migrations/             # 001–007 incl. leagues, managers, goal_events
│   └── seeds/                  # fictional_ten_teams.rb (10 clubs)
│
├── test/
│   ├── domain/, commands/, narratives/, …
│   └── manual/
│
└── CLAUDE.md                   # This file
```

> **Roadmap artifacts not in-repo yet:** `lib/gaffer/narrators/`, `lib/gaffer/config.rb`, AI prompts folder — Claude.md still describes intended patterns for those.

---

## Domain Model

### Player

```ruby
# Core attributes
Player {
  id:              Integer
  name:            String
  age:             Integer
  nationality:     String
  position:        Enum[:gk, :def, :mid, :att]
  club_id:         Integer

  # Attributes (1–100)
  pace:            Integer
  shooting:        Integer
  passing:         Integer
  dribbling:       Integer
  defending:       Integer
  physical:        Integer
  goalkeeping:     Integer   # meaningful only for GKs

  # Derived
  overall:         Integer   # weighted avg by position
  potential:       Integer   # ceiling, used for youth/transfer interest
  form:            Integer   # 1–10, 5 = neutral; updates after each played gameweek (+ decay / match events)
  morale:          Enum[:unhappy, :unsettled, :okay, :happy, :ecstatic]  # DB string; drives contribution band with form
  contract_years:  Integer
  wage:            Integer   # weekly, in £k
}
```

**Overall calculation is position-weighted:**
```ruby
WEIGHTS = {
  gk:  { goalkeeping: 0.6, physical: 0.2, passing: 0.2 },
  def: { defending: 0.4, physical: 0.25, pace: 0.2, passing: 0.15 },
  mid: { passing: 0.35, dribbling: 0.25, physical: 0.2, shooting: 0.2 },
  att: { shooting: 0.4, pace: 0.25, dribbling: 0.25, physical: 0.1 }
}
```

---

### Club

```ruby
Club {
  id:            Integer
  name:          String
  short_name:    String      # e.g. "MCI"
  league_id:     Integer
  reputation:    Integer     # 1–100, affects transfer pull
  budget:        Integer     # transfer budget in £k
  wage_budget:   Integer     # weekly wage budget remaining
  stadium:       String
  chairman_name: String
  chairman_mood: Enum[:furious, :concerned, :satisfied, :delighted]
  board_target:  Enum[:avoid_relegation, :mid_table, :top_half, :europe, :title]
}
```

---

### League

A League **is** a season. Each calendar year has a new League row. There is no separate Season model — the League carries year, status, and the current gameweek pointer. Clubs reference the active League via `league_id`; when a new season starts, a new League row is created and all clubs are re-linked to it.

```ruby
League {
  id:               Integer
  name:             String            # e.g. "Fictional League One"
  year:             Integer           # 2026, 2027, …
  status:           Enum[:pending, :active, :complete]
  current_gameweek: Integer           # 1-indexed; advances after each full round
}

# League table entry — derived from played fixtures, never persisted
TableRow {
  club:    Club
  played:  Integer
  won:     Integer
  drawn:   Integer
  lost:    Integer
  gf:      Integer
  ga:      Integer
  gd:      Integer
  points:  Integer
}
```

**Fixture scheduling:** requires an **even number of clubs** so every team plays every gameweek (no byes). With **10 clubs**, full home-and-away is **90 fixtures** (each pair meets twice): **5 matches per gameweek** × **18 gameweeks**. Fixture order uses the standard round-robin rotation algorithm.

---

### Fixture & Match

```ruby
Fixture {
  id:           Integer
  league_id:    Integer   # references leagues(id)  [stored as season_id in the DB column]
  gameweek:     Integer
  home_club_id: Integer
  away_club_id: Integer
  played:       Boolean   # false until result saved
}

Match {
  id:              Integer
  fixture_id:      Integer
  home_score:      Integer
  away_score:      Integer
  home_possession: Integer   # percentage (unused in UI yet)
  home_shots:      Integer   # future
  home_shots_ot:   Integer   # future
  away_shots:      Integer   # future
  away_shots_ot:   Integer   # future
  events:          JSON      # reserved — future cards/subs timeline
  player_ratings:  JSON      # future
  narrative:       Text      # future AI layer
}

# goal_events — migration 007; one row per goal (scorer auditing + top scorers)
GoalEvent {
  id:         Integer
  fixture_id: Integer
  player_id:  Integer
  club_id:    Integer       # scorer's club when the ball hit the net
  side:       String       # "home" | "away"
}
```

> **DB note:** the `fixtures` table has a `season_id` column (from migration 003). We treat this as `league_id` at the Ruby layer and alias it in `FixtureRepository`. A future migration can rename the column once SQLite tooling allows it cleanly.

Goal **scorers** for each match come from **`Domain::ScorerPicker`** (weighted by shooting / pace / dribbling × position) and persist via **`Repositories::GoalEventRepository`** alongside the `matches` row. `MatchResult` carries `home_scorers` / `away_scorers` as `Array<Player>` for UI.

---

### Manager

```ruby
Manager {
  id:               Integer
  display_name:     String    # shown in the header and match reports
  managed_club_id:  Integer   # references clubs(id)
}
```

One manager row per SQLite file (single-save slot for now). The active league is derived from `Club#league_id` rather than stored on the manager directly.

---

### MatchSelection *(planned — not in DB or CLI persistence yet)*

The player's chosen XI and tactic for a specific fixture — **reviewable snapshots** once implemented.

```ruby
MatchSelection {
  id:          Integer
  fixture_id:  Integer
  save_id:     Integer
  tactic:      Enum[:all_out_attack, :attacking, :balanced, :defensive, :park_the_bus]
  player_ids:  JSON    # ordered array of 11 player IDs [GK, DEF x4, MID x3, ATT x3]
  confirmed:   Boolean
}
```

---

### PlayerAvailability *(planned)*

Tracks injury and suspension state per player per gameweek. Absence would be the exception — a missing row means available **when this exists**.

```ruby
PlayerAvailability {
  id:          Integer
  player_id:   Integer
  save_id:     Integer
  gameweek:    Integer
  status:      Enum[:injured, :suspended]
  return_gw:   Integer   # gameweek they become available again
}
```

**Not implemented yet.** Intended injury logic sketch: ~7% per outfield knock (1–3 GW), ~4% GKs; suspensions from cards.

---

### Scout report (implemented)

Pre-match dossier assembled from **SQLite only** — no LLM.

**Building blocks**

- **`Commands::Support::ScoutReportBuilder`** — **`build`** assembles dossier; **`build_coaching_context`** delegates to **`Support::ScoutCoachingNotables`** (suggested **`managed_xi`** → up to **3** rising `form > 5`, up to **3** falling `form < 5`, morale only colours copy in **`CoachTrainingReport`**).
  - Table: **`LeagueTable`** + **`FixtureRepository#settled_scores_for_season`** → opponent **position**, **points**, **games played**, same for **managed** club for comparison copy.
  - **Form**: last five **`:w`/`:d`/`:l`** for the opponent, chronological subset of settled results (`recent_form_for`).
  - **Ratings**: best XI (`Lineup.pick_best_xi`) → **`MatchEngine#attack_defense_rating_for_xi`** (same contrib path as sim incl. morale/form multipliers — no tactics or RNG **here**).
  - **Goals**: **`GoalEventRepository#totals_by_player`** scoped to opponent → **`top_scorer`** `{ player:, goals: }` or nil.
  - **`watch_focus`**: if they have league goals → top scorer; else best **live-wire** outfield (shooting/pace/dribbling) or **enforcer** defender fallback.

```ruby
# Core fields on Domain::ScoutReport — see scout_report.rb
ScoutReport {
  opponent:, managed_club:, gameweek:, hosting_managed:,
  league_position:, league_size:, played:,
  manager_league_position:, manager_played:, manager_points:, opponent_points:,
  recent_form:,           # [:w/:d/:l …] oldest→newest inside last five
  attack_rating:, defence_rating:,              # opponent XI
  our_attack_rating:, our_defence_rating:,    # managed XI same formula
  top_scorer:,            # Hash or nil
  watch_focus:            # Hash { player:, kind: (:scorer | :livewire | :enforcer), goals: }
}
```

**Narrative layer**

- **`Gaffer::Narratives::ScoutBriefing.paragraphs(report)`** — rule-based conversational paragraphs (league narrative, form band, stylistic tilt, watch-player line, outlook).
- **`Gaffer::Narratives::CoachTrainingReport`** + **`coach_training_matrix.rb`** — **`Domain::CoachingContext`** (suggested XI + notables) → **Coach ·** block: rising-band **cheer** (morale×form matrix), falling-band **worry** (form-led; GK vs outfield phrasing via matrix).
- **`Presenters::ScoutBriefingTty.present(report:, coaching:)`** — clears screen, headings + pastel body — opponent dossier → coach strip → **`TTY::Prompt#keypress`** (skip line under non-interactive tests).

**Flow in `gaffer next`** (see Commands::GameweekPlay / **`NextFixture`**)

1. Validates league + fixture + squad.  
2. Builds **`Domain::ScoutReport`** + **`CoachingContext`**, renders **`ScoutBriefingTty`** (**opponent** brief + **coach** strip **before** dugout).  
3. **`Ui::DugoutLineup`** — dugout XI prompts + compact refresh before tactics.  
4. Tactic picker (managed side); sim whole gameweek; **`Support::GameweekRoundPersist`** — persist matches + **`goal_events`** + morale/form batch (+ age +1 league-wide on **final GW** completion).

---

### Onboarding — board expectations (implemented)

First hire uses **`Gaffer::Narratives::BoardExpectations`** — template letters keyed by **`Club#board_target`** (`avoid_relegation` … `:title`), no AI. Driven from **`Ui::Onboarding`** after manager row is saved.

---

### Transfer *(planned — no `transfers` table)*

```ruby
Transfer {
  id:             Integer
  player_id:      Integer
  from_club_id:   Integer
  to_club_id:     Integer
  fee:            Integer     # in £k, 0 for free transfers
  season_id:      Integer
  gameweek:       Integer
}
```

---

## Seeded Data

The default seed is **`db/seeds/fictional_ten_teams.rb`**: **10 fictional clubs** (short codes `CRW` … `MBW`), **~23 players per club**, tiered reputation / `board_target` / chairman fields. **`rake db:seed`** loads clubs + players only — **league start** (`StartLeague` / menu) generates fixtures at runtime and links `clubs.league_id` to the new league row.

---

## The Match Engine (Deterministic Core)

See **`lib/gaffer/domain/match_engine.rb`**. Summary:

- **Entry:** `simulate(home_club:, home_players:, away_club:, away_players:, home_tactic:, away_tactic:, seed:)` — keyword args, **11-player XIs** required.
- **Flow:** per-player attack/defence **raw** contributions (`raw_contribution_attack` / `raw_contribution_defense`) → multiplied by **`MoraleFormMultiplier`** (morale sets a band; form 1–10 slides within it) → squad means → **club reputation** scaling → **tactic multipliers** → Poisson goal counts from λ → **`ScorerPicker.pick`** fills **`MatchResult#home_scorers` / `away_scorers`** from the same `Random` stream.
- **Public helper:** `attack_defense_rating_for_xi(club:, players:)` — uses the same contribution path (morale/form included) as sim; no tactics, no RNG — scouting / UI.

```ruby
MatchResult = Data.define(
  :home_score, :away_score,
  :home_xg_lambda, :away_xg_lambda,
  :home_attack_rating, :home_defense_rating,
  :away_attack_rating, :away_defense_rating,
  :home_scorers, :away_scorers   # Array<Player>
)
```

**Tactic modifiers** (attack / defence multipliers):

| Tactic         | Attack | Defence |
|----------------|--------|---------|
| `:all_out_attack` | ×1.28 | ×0.72 |
| `:attacking`   | ×1.12 | ×0.88 |
| `:balanced`    | ×1.0  | ×1.0  |
| `:defensive`   | ×0.88 | ×1.12 |
| `:park_the_bus`| ×0.72 | ×1.28 |

---

### Morale & form (implemented)

Stored on **`players`** (`form` integer, `morale` string → symbol in Ruby). **League rounds only:** after every fixture in a gameweek is persisted (`Support::GameweekRoundPersist`), **`Domain::MoraleUpdater`** applies rule-based deltas to every player who appeared in that round’s XI (all clubs — managed + CPU): results, scoring, clean sheets, conceded goals (weighted defender + GK penalties), passive form decay toward neutral. Updates run in the **same SQLite transaction** as matches + goal events; deltas written via **`Repositories::PlayerRepository#update_morale_form_batch`**.

- **Season end:** **`Repositories::PlayerRepository#increment_age_for_league!`** adds **+1 age** for all players whose club was linked to the completed league (triggered when the final GW is saved).
- **New season start:** **`StartLeague`** calls **`#soft_reset_morale_form_for_club_ids!`** — form drifts halfway toward **5**, morale steps one level toward **`Okay`** (before fixtures roll).
- **Friendly `PlayMatch`:** no morale/form persistence (engine still reads current DB traits if reused elsewhere).

Supporting types: **`MoraleRoundRow`**, **`Support::GameweekRoundSim::SimulateOutcome`** (XI + result for rollup), **`Domain::Morale`** collaborators (`fixture_roll`, `concede_hits`, `defender_pick`, `form_norm`, `morale_step`, `side_line`).

Manual sanity script: **`test/manual/morale_form_sim_comparison.rb`** (paired morale swings vs λ).

**`PlayMatch` friendlies:** no post-match morale/form writes (league GW only).

---

## The Narrator Adapter *(planned / not wired in this repo yet)*

The blocks below describe the **intended** AI adapter layout. There is no `lib/gaffer/narrators/` in the tree today — match output is template + data.

```ruby
# lib/gaffer/narrators/base.rb
module Gaffer
  module Narrators
    class Base
      def match_report(fixture:, result:, home_club:, away_club:)
        raise NotImplementedError
      end

      def press_conference(question:, context:)
        raise NotImplementedError
      end

      def transfer_response(player:, offer:, club:)
        raise NotImplementedError
      end
    end
  end
end
```

```ruby
# lib/gaffer/narrators/claude.rb
module Gaffer
  module Narrators
    class Claude < Base
      MODEL    = "claude-sonnet-4-20250514"
      MAX_TOKENS = 600

      def initialize(api_key:)
        @client = Anthropic::Client.new(api_key:)
      end

      def match_report(fixture:, result:, home_club:, away_club:)
        prompt = MatchReportPrompt.build(fixture:, result:, home_club:, away_club:)
        call(prompt)
      end

      def press_conference(question:, context:)
        prompt = PressConferencePrompt.build(question:, context:)
        call(prompt)
      end

      private

      def call(prompt)
        response = @client.messages.create(
          model: MODEL,
          max_tokens: MAX_TOKENS,
          messages: [{ role: "user", content: prompt }]
        )
        response.content.first.text
      rescue Anthropic::Error => e
        "[Narrative unavailable: #{e.message}]"
      end
    end
  end
end
```

---

## Prompt Design *(planned — `lib/gaffer/prompts/` not in-repo yet)*

When narrators ship, prompts should live under `lib/gaffer/prompts/` as dedicated classes — version-controlled, testable strings.

### Match Report Prompt

```ruby
module Gaffer
  module Prompts
    class MatchReport
      def self.build(fixture:, result:, home_club:, away_club:)
        <<~PROMPT
          You are a football match reporter writing for a British broadsheet.
          Write a short match report (3–4 paragraphs) in a dry, wry, authoritative tone.

          Match: #{home_club.name} #{result.home_score}–#{result.away_score} #{away_club.name}
          Possession: #{result.home_possession}% / #{100 - result.home_possession}%
          Home shots (on target): #{result.home_shots} (#{result.home_shots_ot})
          Away shots (on target): #{result.away_shots} (#{result.away_shots_ot})

          Key events:
          #{format_events(result.events)}

          Player of the match ratings (top 3):
          #{format_top_ratings(result.player_ratings)}

          Rules:
          - Do not invent player names not listed above
          - Do not include a headline
          - Keep it under 200 words
          - British English throughout
        PROMPT
      end
    end
  end
end
```

**Prompt versioning convention:**

```
lib/gaffer/prompts/
  match_report_v1.rb    ← production
  match_report_v2.rb    ← in test
```

---

## AI Decision Points (What Uses AI, What Doesn't)

| Feature                  | AI? | Rationale                                              |
|--------------------------|-----|--------------------------------------------------------|
| Match simulation         | ❌  | Deterministic, fast, testable, free                   |
| Match report narrative   | 🔜  | Planned narrator call per match                       |
| Press conference Q&A     | 🔜  | Planned; no `gaffer press` yet                        |
| Transfer negotiation text| 🔜  | Planned with transfer market                         |
| Opponent manager logic   | ❌  | Rules-based with personality modifiers (future)       |
| League table / stats / fixtures / scorers (`gaffer table`, `fixtures`, `scorers`) | ❌ | Pure data |
| Pre-match scout briefing, coach strip & board letter | ❌ | Template / rules from DB + `board_target` + form/morale |
| Player morale + form changes (league) | ❌  | Formula-based batch after each GW                      |
| Board confidence updates | ❌  | Formula-based                                         |

---

## CLI Commands

```bash
gaffer start        # Default — main menu (TTY); onboarding on first run
gaffer next         # Play upcoming league gameweek (full round simulated)
gaffer table        # Standings — `--previous` / `--year` for archives
gaffer fixtures     # Fixtures & results — same archive flags
gaffer scorers      # Top 20 scorers chart — same archive flags
gaffer console      # IRB + DB
gaffer version
```

The menu also exposes **Play game** (`Commands::PlayMatch`) — friendly vs foil club, not the league loop.

---

## Core Game Flow

### First run / menu — onboarding

On **`gaffer start`** (or default Thor task), if no manager row exists:

```
1. Enter manager display name
2. Pick a club (from DB — seeded clubs with reputation on the label)
3. Manager row saved; board letter from BoardExpectations (board_target copy, no AI)
4. Keypress → main menu
```

There is no separate `gaffer new` Thor task today — save creation is this onboarding path.

---

### `gaffer next` — Next gameweek (league loop)

```
1. Validate active league, unplayed round, squads (11+ players for managed club).
2. Scout screen (clears terminal)
   • Opponent dossier: table vs you, form band, attack/defence read, watch player
   • Coach block: morale/form-led lines for suggested-XI rising / falling players
   • Keypress → continue
3. Dugout (MatchdaySquad)
   • Gameweek header, opposition name, full roster table, suggested XI
   • "Start with this XI? [Y/n]" or slot-by-slot edits
   • After confirm: screen refresh — compact XI only ("Squad list hidden")
4. Tactic picker (managed side only; CPU uses :balanced in league sims today)
5. Transaction: simulate every fixture in the gameweek
   • Managed match: user XI + chosen tactic
   • Others: best XI + balanced
   • Persist matches, goal_events, **morale + form deltas** (`MoraleUpdater` + batched repo write), mark fixtures played, bump league.current_gameweek (final GW → **increment_age_for_league!** then complete league)
6. Post-round UI: your result (scoreline, scorers, λ), other scorelines, standings snapshot or final table
7. End of season: complete league, optional Start Season [Y+1]
```

**Not yet in `gaffer next`:** live event ticker with sleeps, possession/shots in match output (engine focuses on score + scorers + λ today).

---

## Testing Strategy

Minitest with the `minitest/spec` DSL throughout. No RSpec, no VCR.

**Domain logic — pure unit tests, no mocking needed:**

```ruby
# Real coverage: test/domain/match_engine_test.rb — keyword args, Domain:: namespace, 23-player XIs.
# Typical call:
engine.simulate(
  home_club: home_club, home_players: home_xi,
  away_club: away_club, away_players: away_xi,
  home_tactic: :balanced, away_tactic: :park_the_bus,
  seed: 12_341
)
# Assertions include: same seed → identical MatchResult#to_h; scorer array lengths == goals; tactic ordering.
```

**Narrator tests** — when narrators ship: swap in a Fake implementation, block real HTTP with WebMock (`test_helper` already requires WebMock).

```ruby
# Intended pattern — not wired in test_helper today
module Gaffer
  module Narrators
    class Fake < Base
      def match_report(fixture:, result:, home_club:, away_club:)
        "#{home_club.name} #{result.home_score}–#{result.away_score} #{away_club.name}."
      end
    end
  end
end
```

**Prompt tests** *(when prompt classes exist)* — pure string assertions, no HTTP:

```ruby
# test/prompts/match_report_test.rb
describe Gaffer::Prompts::MatchReport do
  it "includes both club names" do
    prompt = Gaffer::Prompts::MatchReport.build(
      fixture: mock_fixture, result: mock_result,
      home_club: build_club("Arsenal"), away_club: build_club("Chelsea")
    )
    _(prompt).must_include "Arsenal"
    _(prompt).must_include "Chelsea"
  end

  it "includes the scoreline" do
    result = build_result(home_score: 2, away_score: 1)
    prompt = Gaffer::Prompts::MatchReport.build(fixture: mock_fixture, result:,
      home_club: build_club("Arsenal"), away_club: build_club("Chelsea"))
    _(prompt).must_include "2"
    _(prompt).must_include "1"
  end
end
```

**Manual** — `test/manual/morale_form_sim_comparison.rb` optional λ sanity vs morale swings (not CI).

**Smoke test** *(when Claude narrator + Config exist)* — not run in CI:

```ruby
# test/smoke/narrator_test.rb  (not run in CI)
# Run manually: ruby test/smoke/narrator_test.rb
# Requires a real ANTHROPIC_API_KEY to be set
narrator = Gaffer::Narrators::Claude.new(api_key: Gaffer::Config.api_key)
report = narrator.match_report(fixture: ..., result: ..., ...)
puts report
raise "Report too short" if report.length < 50
puts "Smoke test passed."
```

---

## Development Phases

### Phase 1a — Foundation ✅ (done)
- [x] Domain models: Club, Player, Fixture, Match, MatchResult, MatchEngine, Manager, **League**
- [x] `LeagueRepository` (persist league / season rows)
- [x] SQLite schema + migrations (clubs, players, fixtures, matches, managers, **leagues**)
- [x] Seed data: 10 fictional clubs in paired tiers (`db/seeds/fictional_ten_teams.rb`; short codes `CRW … MBW`)
- [x] First-run onboarding: name + club selection persisted in `managers` table
- [x] Manager identity shown in CLI header
- [x] `bin/gaffer` opens interactive menu with GAFFER block-font hero
- [x] Play test game: simulate managed club vs foil, display result
- [x] Match engine: Poisson goal sampling, tactic modifiers, home advantage
- [x] Tests: match engine, **`FixtureGenerator`**, league + manager repos, DB migrations

---

### Phase 1b — League & season ✅ (core loop shipped)

#### Decisions *(unchanged)*

- **No separate Season model.** A League row *is* a season. Each year = a new League row.
- **10 seeded clubs**. **`db/seeds/fictional_ten_teams.rb`**; league start does **not** add/remove clubs.
- **18 gameweeks** full home+away (**90** fixtures, **5** per round).
- **User triggers season start** — fixtures generated at runtime via **`StartLeague`**, not `rake db:seed`.
- **Managed match** is interactive (scout → XI → tactic); **other four** in the round auto-sim (best XI, `:balanced`).
- **All rounds played** → end-of-season flow (complete league, optional next year).

#### Implementation status

| Step | Status | Notes |
|------|--------|--------|
| Seed + leagues + `FixtureGenerator` | ✅ | Migrations through **`007`** (`goal_events` for scorers) |
| **`Commands::StartLeague`** | ✅ | Menu when no active league |
| **`gaffer next`** | ✅ | Scout + coach strip → dugout → tactic → `GameweekRoundPersist` (`goal_events`, morale/form, optional season age) |
| **`gaffer table` / `fixtures` / `scorers`** | ✅ | Archive flags `--previous` / `--year` |
| End-of-season + roll forward | ✅ | As in `NextFixture` / `LeagueRepository` |

**Still intentionally out of scope here:** transfers table, **board confidence / sack** loop, persisted `match_selections`, injuries.

---

### Phase 2 — Match-day depth *(partial)*

- [x] Tactic selection before the managed fixture (`gaffer next`)
- [x] Interactive XI in dugout (`MatchdaySquad`), refresh after lock-in
- [x] Pre-match **coach** strip (form/morale notables on suggested XI)
- [x] `gaffer fixtures` for the active / archived league
- [x] Post-round standings snippet + top scorers command (`gaffer scorers`, cap 20)
- [ ] Standalone **`gaffer squad`** (browse roster outside match loop)
- [ ] Injury / suspension system (`PlayerAvailability` + match hooks)
- [ ] Live event ticker, possession/shots in post-match UI (columns exist on `matches`, mostly unused)

### Phase 3 — AI narrative layer *(not started)*

- [ ] Add `anthropic` gem + `Gaffer::Config` resolution
- [ ] Match report prompt v1 (replaces plain scoreline output)
- [ ] Press conference command (`gaffer press`)
- [ ] Config / BYOK setup (`gaffer config`)
- [ ] Fake narrator + WebMock wired into test_helper
- [ ] Smoke test script for manual narrator verification

### Phase 4 — Management Depth
- [ ] Transfer market (in/out window, `gaffer transfers`)
- [x] Player morale + form (league sim skew + GW batch persist + season soft reset + age bump)
- [ ] Board confidence + sack mechanic
- [ ] Multiple save slots

### Phase 5 — Polish
- [ ] Full TTY rich UI (tty-box panels, colour theming)
- [ ] OpenAI adapter (alternative narrator)
- [ ] README with demo GIF

---

## README Structure (for portfolio impact)

The README should lead with:
1. A demo GIF of a match being played
2. One-line install instructions
3. The BYOK explanation (friendly, not apologetic)
4. A brief "How the AI works" section — explaining the hybrid approach
5. An `AI_PROCESS.md` link — what was built with AI assistance and what decisions were made manually

---

## Conventions

- No Rails. Pure Ruby + Sequel. Keep dependencies minimal and intentional.
- Domain objects are plain Ruby — no ORM coupling in `domain/`
- Sequel repositories handle persistence separately from domain logic
- When prompt classes exist, prefer a **`.build` → String`** API
- Never rescue broadly — let errors surface in development
- `bin/gaffer` is the only executable; everything else is `require`-able as a library
