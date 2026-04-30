# CLAUDE.md — Gaffer

> An AI-native football management CLI built in Ruby.
> You are the gaffer. Your key, your club, your call.

---

## Project Overview

Gaffer is a terminal-based football management game written in Ruby. The player takes charge of a club, manages their squad, navigates a league season, and handles the human drama of the dugout — press conferences, board pressure, transfer negotiations — powered by an LLM narrative layer sitting on top of a deterministic simulation core.

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
- **AI layer**: Anthropic Ruby SDK (`anthropic` gem), modular via adapter pattern
- **Testing**: Minitest + minitest/spec DSL + WebMock for blocking real HTTP in tests
- **Config**: dotenv for local dev; XDG config dir for user installs

---

## API Key Setup (BYOK)

Gaffer never ships with or manages API keys. Users provide their own Anthropic key.

### Resolution order

1. `ANTHROPIC_API_KEY` environment variable
2. `~/.config/gaffer/config.yml` → `anthropic_api_key:`
3. Prompt on first run, offer to save to config

### Implementation

```ruby
# lib/gaffer/config.rb
module Gaffer
  class Config
    CONFIG_PATH = File.expand_path("~/.config/gaffer/config.yml")

    def self.api_key
      ENV["ANTHROPIC_API_KEY"] ||
        saved_config["anthropic_api_key"] ||
        prompt_and_save
    end

    def self.saved_config
      return {} unless File.exist?(CONFIG_PATH)
      YAML.load_file(CONFIG_PATH) || {}
    end

    def self.prompt_and_save
      puts "No Anthropic API key found."
      puts "Get one at https://console.anthropic.com"
      key = TTY::Prompt.new.mask("Enter your API key:")
      save = TTY::Prompt.new.yes?("Save to ~/.config/gaffer/config.yml?")
      if save
        FileUtils.mkdir_p(File.dirname(CONFIG_PATH))
        File.write(CONFIG_PATH, YAML.dump({ "anthropic_api_key" => key }))
      end
      key
    end
  end
end
```

### AI can be disabled entirely

```bash
gaffer play --no-ai   # runs narrative-free, pure simulation
```

When `--no-ai` is passed (or no key is configured), the narrator adapter falls back to `Gaffer::Narrators::Template` — pre-written match report templates with interpolated stats. The game is fully playable without any API calls.

---

## Architecture

```
gaffer/
├── bin/
│   └── gaffer                  # Executable entry point
├── lib/
│   gaffer/
│   ├── cli.rb                  # Thor command definitions
│   ├── config.rb               # API key resolution
│   ├── database.rb             # Sequel connection + migrations
│   │
│   ├── domain/                 # Pure domain objects — no AI, no I/O
│   │   ├── club.rb
│   │   ├── player.rb
│   │   ├── player_availability.rb  # Injury/suspension status per gameweek
│   │   ├── league.rb
│   │   ├── fixture.rb
│   │   ├── match.rb
│   │   ├── match_engine.rb         # Deterministic simulation core
│   │   ├── match_selection.rb      # Chosen XI + tactic for a fixture
│   │   ├── save.rb                 # Root of a game state (manager + club + season)
│   │   ├── manager.rb              # Manager name, club, save
│   │   ├── scout_report.rb         # Derived opponent summary (template-based)
│   │   ├── season.rb
│   │   ├── transfer_market.rb
│   │   └── tactics.rb
│   │
│   ├── narrators/              # AI adapter pattern
│   │   ├── base.rb             # Interface definition
│   │   ├── claude.rb           # Anthropic implementation
│   │   ├── openai.rb           # Optional OpenAI implementation
│   │   └── template.rb         # Fallback — no API required
│   │
│   ├── presenters/             # TTY rendering layer
│   │   ├── league_table.rb
│   │   ├── match_report.rb
│   │   ├── squad_selector.rb       # Interactive XI picker
│   │   ├── scout_report.rb         # Opponent lowdown display
│   │   ├── squad_view.rb
│   │   └── dashboard.rb
│   │
│   └── commands/               # One file per CLI command
│       ├── new_game.rb             # Save setup: name → league → club
│       ├── next_fixture.rb         # Scout → pick team → play
│       ├── play_match.rb           # Match simulation + result display
│       ├── manage_squad.rb
│       ├── transfer_window.rb
│       └── press_conference.rb
│
├── db/
│   ├── migrations/
│   └── seeds/                  # Seed data: leagues, clubs, players
│
├── test/
│   ├── domain/
│   ├── narrators/
│   ├── prompts/
│   └── support/
│       ├── fake_narrator.rb    # Fake narrator for use in tests
│       └── fixtures.rb         # Shared test data helpers
│
└── CLAUDE.md                   # This file
```

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
  form:            Integer   # rolling avg of recent match ratings (1–10)
  morale:          Enum[:unhappy, :unsettled, :okay, :happy, :ecstatic]
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
  home_possession: Integer   # percentage (future)
  home_shots:      Integer   # future
  home_shots_ot:   Integer   # future
  away_shots:      Integer   # future
  away_shots_ot:   Integer   # future
  events:          JSON      # goals, cards, subs — future
  player_ratings:  JSON      # { player_id => rating } — future
  narrative:       Text      # AI-generated match report — future
}
```

> **DB note:** the `fixtures` table has a `season_id` column (from migration 003). We treat this as `league_id` at the Ruby layer and alias it in `FixtureRepository`. A future migration can rename the column once SQLite tooling allows it cleanly.

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

### MatchSelection

The player's chosen XI and tactic for a specific fixture, persisted so past decisions are reviewable.

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

### PlayerAvailability

Tracks injury and suspension state per player per gameweek. Absence is the exception — a missing row means the player is available.

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

Injury logic: after each match, each outfield player has a 7% chance of picking up a knock (1–3 gameweeks out). GKs 4%. Suspensions triggered at 5 yellows or a red card.

---

### ScoutReport

A derived value object — not persisted, computed fresh before each fixture from the opponent's current squad data.

```ruby
ScoutReport {
  opponent:         Club
  overall_rating:   Integer          # avg overall of their best XI
  strengths:        Array<String>    # e.g. ["Dangerous from set pieces", "Strong GK"]
  weaknesses:       Array<String>    # e.g. ["Slow fullbacks", "Poor aerial defending"]
  likely_tactic:    Symbol           # inferred from club reputation + recent form
  key_players:      Array<Player>    # top 3 by overall
  recent_form:      Array<Symbol>    # last 5 results e.g. [:w, :w, :d, :l, :w]
}
```

Scout report generation is purely template-based (no AI). Strengths and weaknesses are derived from attribute comparisons against league averages:

```ruby
module Gaffer
  class ScoutReportBuilder
    THRESHOLDS = {
      pace_threat:      { attribute: :pace,       position: :att, threshold: 78 },
      aerial_strength:  { attribute: :physical,   position: :def, threshold: 75 },
      creative_mid:     { attribute: :passing,    position: :mid, threshold: 76 },
      weak_fullbacks:   { attribute: :defending,  position: :def, threshold: 62 },
      strong_gk:        { attribute: :goalkeeping,position: :gk,  threshold: 76 }
    }

    def build(opponent_squad)
      strengths  = []
      weaknesses = []

      THRESHOLDS.each do |trait, config|
        avg = positional_avg(opponent_squad, config[:position], config[:attribute])
        if avg >= config[:threshold]
          strengths << trait_label(trait, :strength)
        elsif avg <= config[:threshold] - 14
          weaknesses << trait_label(trait, :weakness)
        end
      end

      ScoutReport.new(
        overall_rating: best_xi_avg(opponent_squad),
        strengths:,
        weaknesses:,
        likely_tactic: infer_tactic(opponent_squad),
        key_players: top_players(opponent_squad, 3),
        recent_form: recent_form(opponent_squad)
      )
    end
  end
end
```

---

### Transfer

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

## The Match Engine (Deterministic Core)

The `MatchEngine` produces a statistically plausible result from two squads and their tactics. **No AI involved.** Fast, testable, deterministic given a seed.

```ruby
module Gaffer
  class MatchEngine
    # Returns a MatchResult value object
    def simulate(home_squad, away_squad, home_tactic, away_tactic, seed: nil)
      rng = seed ? Random.new(seed) : Random.new

      home_attack  = squad_attack_rating(home_squad, home_tactic)
      home_defense = squad_defense_rating(home_squad, home_tactic)
      away_attack  = squad_attack_rating(away_squad, away_tactic)
      away_defense = squad_defense_rating(away_squad, away_tactic)

      home_xg = calculate_xg(home_attack, away_defense, home_advantage: true, rng:)
      away_xg = calculate_xg(away_attack, home_defense, home_advantage: false, rng:)

      home_goals = sample_goals(home_xg, rng)
      away_goals = sample_goals(away_xg, rng)

      events      = generate_events(home_goals, away_goals, home_squad, away_squad, rng)
      ratings     = generate_ratings(home_squad, away_squad, home_goals, away_goals, events, rng)

      MatchResult.new(
        home_score: home_goals,
        away_score: away_goals,
        home_possession: calculate_possession(home_attack, away_attack, rng),
        events:,
        player_ratings: ratings
      )
    end

    private

    def calculate_xg(attack, defense, home_advantage:, rng:)
      base    = attack.to_f / (attack + defense)
      base   += 0.05 if home_advantage
      base   += rng.rand(-0.08..0.08)   # variance
      [base * 3.5, 0].max               # scale to realistic xG range
    end

    def sample_goals(xg, rng)
      # Poisson sampling
      l = Math.exp(-xg)
      k, p = 0, 1.0
      loop do
        k += 1
        p *= rng.rand
        break if p <= l
      end
      k - 1
    end
  end
end
```

**Tactic modifiers:**

| Tactic         | Attack modifier | Defense modifier |
|----------------|-----------------|------------------|
| `:all_out_attack` | +15%         | -20%             |
| `:attacking`   | +8%             | -8%              |
| `:balanced`    | —               | —                |
| `:defensive`   | -8%             | +8%              |
| `:park_the_bus`| -20%            | +15%             |

---

## The Narrator Adapter

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

## Prompt Design

Prompts live in `lib/gaffer/prompts/` as dedicated classes. They are version-controlled, testable, and treated as first-class code.

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
| Match report narrative   | ✅  | High value, one call per match, user sees it directly |
| Press conference Q&A     | ✅  | Core fun mechanic, user-initiated                     |
| Transfer negotiation text| ✅  | Flavour, user-initiated                               |
| Opponent manager logic   | ❌  | Rules-based with personality modifiers                |
| League table / stats     | ❌  | Pure data                                             |
| Player morale changes    | ❌  | Formula-based                                         |
| Board confidence updates | ❌  | Formula-based                                         |

---

## CLI Commands

```bash
gaffer new          # Create a new save
gaffer next         # Play your next fixture (main game loop)
gaffer squad        # View current squad + availability
gaffer table        # Current league standings
gaffer fixtures     # Full fixture list with results
gaffer season       # Season overview: form, board mood, targets
gaffer transfers    # Open transfer market (in window)
gaffer press        # Trigger a press conference (uses AI)
gaffer config       # Manage API key and settings
```

---

## Core Game Flow

### `gaffer new` — New Save

```
1. Enter your manager name
2. Pick a league           (TTY select list)
3. Pick a club             (TTY select list, shows reputation + board target)
4. Season fixtures generated automatically (round-robin home/away)
5. Confirmation screen:
   ─────────────────────────────────────────
   Welcome, [Name].
   You've taken charge of [Club].
   The board expect: [target].
   First fixture: [Opponent] — Gameweek 1
   ─────────────────────────────────────────
```

---

### `gaffer next` — Next Fixture (main loop)

```
Step 1 — Fixture header
  "Gameweek 12 · Home · Arsenal vs Chelsea"
  Current league position + last 5 form

Step 2 — Scout report
  Opponent overall rating
  Key strengths (2–3 bullet points)
  Key weaknesses (2–3 bullet points)
  Likely tactic
  Players to watch (top 3 by overall)

Step 3 — Squad selection
  Suggested best XI shown (highest available overall by position)
  Player shows: name / position / overall / form / availability
  Prompt: "Accept this lineup? [Y/n]"
  If no → interactive swap: pick position to change → pick replacement from available squad

Step 4 — Tactic selection
  Select from: All Out Attack / Attacking / Balanced / Defensive / Park the Bus
  Brief description of each shown inline

Step 5 — Confirmation
  Final XI displayed in formation shape
  Tactic shown
  "Ready? [Enter to kick off]"

Step 6 — Match
  Simulates via MatchEngine
  Key events printed as they "happen" (with short sleep between for effect)
  e.g. "⚽ 23' — Saka fires past the keeper. Arsenal 1–0 Chelsea"
       "🟨 45' — Gallagher booked for a late challenge"

Step 7 — Full time
  Final score + match stats (possession, shots, shots on target)
  Player ratings table
  Updated league table snippet (your club ± 2 positions either side)
  "Press [Enter] for next fixture"
```

---

## Seeded Data

The game ships with seed data for one fully playable league:

- **English Premier League** (20 clubs, ~500 players)
- Clubs seeded with reputation, budget, board target
- Players seeded with realistic attribute distributions per club tier
- Fixtures generated programmatically (home/away round robin)

Seed data lives in `db/seeds/` as Ruby scripts (not raw SQL) for readability.

---

## Testing Strategy

Minitest with the `minitest/spec` DSL throughout. No RSpec, no VCR.

**Domain logic — pure unit tests, no mocking needed:**

```ruby
# test/domain/match_engine_test.rb
require "test_helper"

describe Gaffer::MatchEngine do
  let(:engine) { Gaffer::MatchEngine.new }

  it "produces plausible scorelines for evenly matched teams" do
    result = engine.simulate(avg_squad, avg_squad, :balanced, :balanced, seed: 42)
    _(result.home_score + result.away_score).must_be :<=, 10
  end

  it "gives home teams a slight advantage over many simulations" do
    results = 200.times.map { engine.simulate(avg_squad, avg_squad, :balanced, :balanced) }
    home_wins = results.count { |r| r.home_score > r.away_score }
    _(home_wins).must_be :>, 60  # expect >30% home wins
  end

  it "applies park the bus tactic defensively" do
    defensive = engine.simulate(strong_squad, avg_squad, :park_the_bus, :balanced, seed: 42)
    attacking = engine.simulate(strong_squad, avg_squad, :all_out_attack, :balanced, seed: 42)
    _(defensive.home_score).must_be :<=, attacking.home_score
  end
end
```

**Narrator tests — swap in the Fake narrator, block real HTTP with WebMock:**

```ruby
# test/support/fake_narrator.rb
module Gaffer
  module Narrators
    class Fake < Base
      def match_report(fixture:, result:, home_club:, away_club:)
        "#{home_club.name} #{result.home_score}–#{result.away_score} #{away_club.name}. A tightly contested match."
      end

      def press_conference(question:, context:)
        "We gave everything out there. The lads were brilliant."
      end

      def transfer_response(player:, offer:, club:)
        "We appreciate the interest but the player is not for sale."
      end
    end
  end
end

# test/test_helper.rb
require "minitest/autorun"
require "minitest/spec"
require "webmock/minitest"  # blocks all real HTTP — no accidental API calls
require "support/fake_narrator"

# Use fake narrator by default in all tests
Gaffer.narrator = Gaffer::Narrators::Fake.new
```

**Prompt tests — pure string assertions, no HTTP involved:**

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

**The Claude narrator itself is not unit tested** — its behaviour is non-deterministic by nature. Instead, there is a manual smoke test script:

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
- [x] Play game: simulate managed club vs foil, display result
- [x] Match engine: Poisson goal sampling, tactic modifiers, home advantage
- [x] Tests: match engine, league + manager repos, DB migrations

---

### Phase 1b — League & Season (next up)

#### Decisions
- **No separate Season model.** A League row *is* a season. Each year = a new League row.
- **10 seeded clubs** (bye-free weeks). All load from **`db/seeds/fictional_ten_teams.rb`**; league start does **not** add/remove clubs from the roster.
- **18 gameweeks** full home+away (**90** fixtures total, **5** matches per gameweek).
- **User triggers season start** — fixtures are generated at runtime, not by `rake db:seed`.
- **Only the managed club's match is "played"** in the UI; the **other four** gameweek matches auto-simulate silently.
- **All fixtures played → auto end-of-season** (final table + prompt to start next year).

#### Implementation steps (in order)

**Step 1 — Seed data ✅**
- **`db/seeds/fictional_ten_teams.rb`** — ten clubs in five loosely paired tiers (deterministic procedural squads, **23 players** each).
- Canonical short codes: `CRW STB KLF VPK AHU RCT FAB LAN HCY MBW`. Skip/aborted-on-partial behaviour unchanged.

**Step 2 — `leagues` migration + domain model** ✅ (partially: table + repo; `clubs.league_id` already exists from migration 001)
- Migration `006_create_leagues.rb`: `id`, `name`, `year` (integer), `status` (string), `current_gameweek` (integer, default 1)
- ~~Migration `007_add_league_id_to_clubs`~~ — **not needed:** `clubs.league_id` is already in schema 001 (nullable, indexed)
- `Domain::League` struct: `id`, `name`, `year`, `status` (symbol), `current_gameweek`
- `Repositories::LeagueRepository`: `find(id)`, `active`, `save(league)`, `complete!(id)`, `latest_year`

**Step 3 — `Domain::FixtureGenerator` (pure, no DB)**
- Takes `Array<Integer>` of club IDs, returns `Array<Fixture>` with `gameweek`, `home_club_id`, `away_club_id`, `league_id` set, `id: nil`, `played: false`
- Uses standard round-robin rotation: fix one team, rotate the rest across N-1 rounds; repeat reversed for the return leg
- Tested in isolation (no DB, no repos)

**Step 4 — `Commands::StartLeague`**
- Guard: refuse if a league is already `:active`
- Determine year: `LeagueRepository.latest_year + 1` (default 2026 if none)
- Create League row (`:pending`)
- Assign all clubs `league_id` → new league
- Generate fixtures via `FixtureGenerator`, bulk-insert to DB
- Mark league `:active`, `current_gameweek: 1`
- Print: `"Season 2026 is underway. Gameweek 1 of 18. First fixture: [date]"`
- Add "Start new season" to main menu (only shown when no active league)

**Step 5 — `gaffer next` command**
- Find the manager's next unplayed fixture for the active league (`FixtureRepository.next_for_club`)
- If none exists and league is active → trigger end-of-season (see Step 7)
- Simulate the managed club's match; display result to screen
- Auto-simulate the **other four fixtures** in the same gameweek (silent — save results, no output)
- Mark all **five** fixtures in the round `played: true`, save Match rows
- Advance `league.current_gameweek += 1`
- Print: your scoreline + the **other four** results as a brief summary
- Print: your current league position (`gaffer table` inline summary — top 3 + your row)
- Add "Next fixture" to main menu (only shown when a league is active)

**Step 6 — `gaffer table` command**
- Query all played fixtures for the active league
- Build `TableRow` per club (W/D/L/GF/GA/GD/Pts) — pure derived calculation, never persisted
- Sort by points desc, then GD desc, then GF desc
- Render with `tty-table` (columns: Pos · Club · P · W · D · L · GF · GA · GD · Pts)
- Managed club row highlighted (bold or colour marker)

**Step 7 — End-of-season detection**
- After advancing `current_gameweek`, check: `current_gameweek > 18` (all rounds played)
- If complete: `LeagueRepository.complete!(id)`; show full final table with managed club highlighted
- Prompt: `"Start Season [year+1]? [Y/n]"` — Yes → `StartLeague`; No → return to menu

#### Out of scope for Phase 1b
- Tactic selection (all matches use `:balanced`)
- Squad selection / best XI
- Injuries / suspensions
- Board reactions / sack mechanic
- Transfer window

---

### Phase 2 — Match Day Detail
- [ ] Tactic selection before each fixture (All Out Attack / Attacking / Balanced / Defensive / Park the Bus)
- [ ] `gaffer squad` — squad list with position, overall, form
- [ ] `gaffer fixtures` — full fixture list with results for the active league
- [ ] Post-match: brief scoreline + your league position after every result
- [ ] Injury system: 7% chance per outfield player per match (1–3 GW out), 4% for GKs

### Phase 3 — AI Narrative Layer
- [ ] Anthropic client + Claude narrator
- [ ] Match report prompt v1 (replaces plain scoreline output)
- [ ] Press conference command (`gaffer press`)
- [ ] Config / BYOK setup (`gaffer config`)
- [ ] Fake narrator + WebMock wired into test_helper
- [ ] Smoke test script for manual narrator verification

### Phase 4 — Management Depth
- [ ] Transfer market (in/out window, `gaffer transfers`)
- [ ] Player morale + form system
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
- All prompts are classes with a `.build` method returning a plain string
- Never rescue broadly — let errors surface in development
- `bin/gaffer` is the only executable; everything else is `require`-able as a library
