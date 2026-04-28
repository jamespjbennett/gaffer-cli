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
│   │   ├── league.rb
│   │   ├── fixture.rb
│   │   ├── match.rb
│   │   ├── match_engine.rb     # Deterministic simulation core
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
│   │   ├── squad_view.rb
│   │   └── dashboard.rb
│   │
│   └── commands/               # One file per CLI command
│       ├── new_game.rb
│       ├── play_match.rb
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

```ruby
League {
  id:           Integer
  name:         String
  country:      String
  tier:         Integer
  club_ids:     Array<Integer>
}

# League table entry (derived, not persisted)
TableRow {
  club:         Club
  played:       Integer
  won:          Integer
  drawn:        Integer
  lost:         Integer
  gf:           Integer
  ga:           Integer
  gd:           Integer
  points:       Integer
}
```

---

### Fixture & Match

```ruby
Fixture {
  id:           Integer
  season_id:    Integer
  gameweek:     Integer
  home_club_id: Integer
  away_club_id: Integer
  played:       Boolean
  match_id:     Integer    # null until played
}

Match {
  id:              Integer
  fixture_id:      Integer
  home_score:      Integer
  away_score:      Integer
  home_possession: Integer   # percentage
  home_shots:      Integer
  home_shots_ot:   Integer
  away_shots:      Integer
  away_shots_ot:   Integer
  events:          JSON       # goals, cards, subs as structured array
  player_ratings:  JSON       # { player_id => rating }
  narrative:       Text       # AI-generated match report (nullable)
}
```

---

### Season & Gameweek

```ruby
Season {
  id:           Integer
  league_id:    Integer
  year:         Integer     # e.g. 2024
  current_gw:   Integer
  status:       Enum[:pre_season, :active, :complete]
}
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
gaffer new          # Start a new save: pick league, club, difficulty
gaffer play         # Play next fixture (simulates + narrates)
gaffer squad        # View and manage your squad
gaffer table        # Current league standings
gaffer fixtures     # Upcoming and recent fixtures
gaffer transfers    # Open transfer market (in window)
gaffer press        # Trigger a press conference (uses AI)
gaffer season       # Season overview: form, board mood, targets
gaffer config       # Manage API key and settings
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

### Phase 1 — Playable Core (no AI)
- [ ] Domain models: Player, Club, League, Fixture, Season
- [ ] SQLite schema + migrations
- [ ] Seed data: Premier League
- [ ] Match engine: simulate() with Poisson goal sampling
- [ ] CLI game loop: `new`, `play`, `table`, `squad`
- [ ] Template narrator fallback

### Phase 2 — AI Narrative Layer
- [ ] Anthropic client + Claude narrator
- [ ] Match report prompt v1
- [ ] Press conference command
- [ ] Config / BYOK setup
- [ ] Fake narrator + WebMock wired into test_helper
- [ ] Smoke test script for manual narrator verification

### Phase 3 — Management Depth
- [ ] Transfer market (in/out window)
- [ ] Player morale + form system
- [ ] Board confidence + sack mechanic
- [ ] Tactic selection before each match

### Phase 4 — Polish
- [ ] TTY rich UI (tables, boxes, colour)
- [ ] Multiple save slots
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
