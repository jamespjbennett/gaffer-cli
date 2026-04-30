# frozen_string_literal: true

# Five fictional clubs at different strength tiers (make-believe names & venues).
# Strongest tier is closest to Crowden-style ratings; weakest to Millbrook-style.
#
# bundle exec rake db:seed

Gaffer::Database.connect

clubs_ds = Gaffer::Database.db[:clubs]
ClubRepo = Gaffer::Repositories::ClubRepository
PlayerRepo = Gaffer::Repositories::PlayerRepository
Domain = Gaffer::Domain

# Canonical short codes in quality order (1 = strongest approximate tier).
EXPECTED_SHORTS = %w[CRW AHU RCT FAB MBW].freeze

# tier 1=highest baseline skill drift; tier 5=lowest
TIER_OVR_CENTER = [78, 70, 64, 58, 51].freeze

TEAMS = [
  {
    short: "CRW",
    name: "Crowden Rovers FC",
    tier: 1,
    reputation: 88,
    budget: 150_000,
    wage_budget: 5000,
    stadium: "Crowden Moor",
    chairman_name: "H. Calder",
    chairman_mood: :satisfied,
    board_target: :europe
  },
  {
    short: "AHU",
    name: "Ashton Heath United",
    tier: 2,
    reputation: 78,
    budget: 72_000,
    wage_budget: 2800,
    stadium: "Heath Lane",
    chairman_name: "M. Briggs",
    chairman_mood: :satisfied,
    board_target: :top_half
  },
  {
    short: "RCT",
    name: "Riverside Town",
    tier: 3,
    reputation: 70,
    budget: 35_000,
    wage_budget: 1200,
    stadium: "Riverside Park",
    chairman_name: "P. Lowell",
    chairman_mood: :okay,
    board_target: :mid_table
  },
  {
    short: "FAB",
    name: "Fenbury Athletic",
    tier: 4,
    reputation: 63,
    budget: 16_500,
    wage_budget: 580,
    stadium: "Fenbury Meadow",
    chairman_name: "L. Wynne",
    chairman_mood: :concerned,
    board_target: :avoid_relegation
  },
  {
    short: "MBW",
    name: "Millbrook Wanderers",
    tier: 5,
    reputation: 56,
    budget: 8500,
    wage_budget: 380,
    stadium: "River End Ground",
    chairman_name: "R. Finch",
    chairman_mood: :concerned,
    board_target: :avoid_relegation
  }
].freeze

FIRST_NAMES = %w[
  Alex Jamie Sam Theo Marco Ben Rafael Owen Viktor Ethan Nils Luca Haris Malik Kieron Jonah Raul Cedric Dante Luis Milo Luis Niko Jasper Efe Willem Jonah Piers Stef Robin Mauricio Danny Aaron Lyle Hugo Desmond Malik Callum Luca Yuri Malik
].freeze

SURNAMES = %w[
  Norwood Brooks Hart Silveira Kerr Duarte Vale Novak Dahl Larsson Pace Morgan Reed Shaw Wells Finn Croft Dale Marsh Young Bishop Cole Hale Price Romano Sokolov Finch Touré Mahmoud Cantu Reese Klein Orchard Hahn Reese Pike Graf Calder Brennan Hart Lang Sund Morley Duval Graf Okoro Graf Rhys Moss Venn Boone Correa Cairns
].freeze

NATIONS = %w[ENG SCO WAL IRL GER FRA ESP POR NED SWE NOR CZE POL BRA USA AUS BEL ITA ARG NGA MLI GER CRO AUT].freeze

POSITION_SKELETON = (([:gk] * 3) + ([:def] * 7) + ([:mid] * 7) + ([:att] * 6)).freeze

def seeded_rng(team_short, lineup_index)
  # Deterministic-but-noisy RNG per squad slot so every run yields identical saves.
  seed_val = ("#{team_short}:#{lineup_index}".hash % 2_147_483_647)
  Random.new(seed_val)
end

def build_player(team_short:, tier:, position:, lineup_index:)
  tier_idx = tier - 1
  center = TIER_OVR_CENTER[tier_idx]
  rng = seeded_rng(team_short, lineup_index)
  drift = rng.rand(-6..7) + ((lineup_index % 11) / 4) # XI slightly above bench noise
  base = center + drift
  lvl = base.clamp(38, 93)

  name = "#{FIRST_NAMES[lineup_index % FIRST_NAMES.size]} #{SURNAMES[(lineup_index * 17 + tier_idx * 31) % SURNAMES.size]}"
  nat = NATIONS[lineup_index % NATIONS.size]
  age = rng.rand((tier <= 2 ? 18 : 17)..(tier <= 2 ? 33 : 35))
  years = rng.rand(1..4)
  wage = rng.rand((tier <= 2 ? 4 : 1)..(tier * 42 + rng.rand(-3..28)))
  wage = wage.clamp(1, tier * 60 + 20)
  form = rng.rand((tier <= 2 ? 5 : 4)..8)
  morale = [:okay, :happy, :unsettled, :okay, :okay].sample(random: rng)
  pot_delta = rng.rand((tier <= 3 ? 3 : 2)..12)

  pace = (lvl + rng.rand(-10..14)).clamp(28, 95)
  phys = (lvl + rng.rand(-6..14)).clamp(28, 95)

  attrs =
    case position
    when :gk
      gk = (lvl + rng.rand(5..22)).clamp(40, 95)
      sho = rng.rand((lvl - 50).clamp(10, 30)..(lvl - 44).clamp(12, 40))
      pa = rng.rand((lvl - 52).clamp(18, 40)..(lvl - 42).clamp(22, 50))
      dr = rng.rand((lvl - 48).clamp(20, 40)..(lvl - 42).clamp(24, 50))
      de = rng.rand((lvl - 72).clamp(10, 30)..(lvl - 58).clamp(14, 40))
      ov = compute_overall_flat(:gk, pace, sho, pa, dr, de, phys, gk).clamp(40, 95)
      { gk: gk, pace: pace, shoot: sho, pass: pa, drib: dr, defn: de, phys: phys, ovr: ov, pot: (ov + pot_delta).clamp(41, 95) }

    when :def
      gk_seed = rng.rand(10..26)
      sho = rng.rand((lvl - 52).clamp(15, 40)..(lvl - 38).clamp(22, 50))
      pa = rng.rand((lvl - 28).clamp(28, 60)..(lvl - 22).clamp(35, 70))
      dr = rng.rand((lvl - 30).clamp(28, 60)..(lvl - 24).clamp(32, 70))
      de = (lvl + rng.rand(-8..14)).clamp(28, 95)
      ov = compute_overall_flat(:def, pace, sho, pa, dr, de, phys, gk_seed).clamp(40, 95)
      { gk: gk_seed, pace: pace, shoot: sho, pass: pa, drib: dr, defn: de, phys: phys, ovr: ov, pot: (ov + pot_delta).clamp(41, 95) }

    when :mid
      gk_seed = rng.rand(5..22)
      sho = rng.rand((lvl - 22).clamp(28, 70)..(lvl - 12).clamp(36, 80))
      pa = rng.rand((lvl - 18).clamp(35, 75)..(lvl - 10).clamp(40, 85))
      dr = rng.rand((lvl - 20).clamp(32, 75)..(lvl - 12).clamp(38, 85))
      de = rng.rand((lvl - 36).clamp(22, 70)..(lvl - 22).clamp(30, 80))
      ov = compute_overall_flat(:mid, pace, sho, pa, dr, de, phys, gk_seed).clamp(40, 95)
      { gk: gk_seed, pace: pace, shoot: sho, pass: pa, drib: dr, defn: de, phys: phys, ovr: ov, pot: (ov + pot_delta).clamp(41, 95) }

    when :att
      gk_seed = rng.rand(4..16)
      sho = rng.rand((lvl - 12).clamp(38, 80)..(lvl + 2).clamp(45, 95))
      pa = rng.rand((lvl - 28).clamp(28, 75)..(lvl - 18).clamp(35, 80))
      dr = rng.rand((lvl - 22).clamp(32, 80)..(lvl - 12).clamp(38, 90))
      de = rng.rand((lvl - 58).clamp(14, 50)..(lvl - 38).clamp(22, 60))
      ov = compute_overall_flat(:att, pace, sho, pa, dr, de, phys, gk_seed).clamp(40, 95)
      { gk: gk_seed, pace: pace, shoot: sho, pass: pa, drib: dr, defn: de, phys: phys, ovr: ov, pot: (ov + pot_delta).clamp(41, 95) }

    end

  attrs.merge(
    name: name,
    age: age,
    nationality: nat,
    position: position,
    form: form,
    morale: morale,
    years: years,
    wage: wage
  )
end

def compute_overall_flat(pos, pace, sho, pas, drib, defn, phys, gkk)
  # Rough single-number parity with handwritten seeds — match engine ignores this field anyway.
  u = pace + sho + pas + drib + defn + phys + (pos == :gk ? gkk * 4 : gkk / 10)
  (u / 7.15).to_i.clamp(40, 95)
end

persist_players = lambda do |club, rows|
  rows.map do |p|
    PlayerRepo.save(
      Domain::Player.new(
        name: p.fetch(:name),
        age: p.fetch(:age),
        nationality: p.fetch(:nationality),
        position: p.fetch(:position),
        club_id: club.id,
        pace: p.fetch(:pace),
        shooting: p.fetch(:shoot),
        passing: p.fetch(:pass),
        dribbling: p.fetch(:drib),
        defending: p.fetch(:defn),
        physical: p.fetch(:phys),
        goalkeeping: p.fetch(:gk),
        overall: p.fetch(:ovr),
        potential: p.fetch(:pot),
        form: p.fetch(:form),
        morale: p.fetch(:morale),
        contract_years: p.fetch(:years),
        wage: p.fetch(:wage)
      )
    )
  end
end

existing = clubs_ds.where(short_name: EXPECTED_SHORTS.to_a).select_map(:short_name).to_a
already_all = EXPECTED_SHORTS.all? { |code| existing.include?(code) }

if already_all
  $stderr.puts "Seed skipped: all five fictional clubs #{EXPECTED_SHORTS.join(", ")} already exist."
elsif existing.any?
  $stderr.puts <<-MSG


    Seed aborted: fictional league preview is incomplete (present: #{existing.sort.join(", ")} expected: #{EXPECTED_SHORTS.join(", ")}).
    Delete your SQLite DB or set GAFFER_DB_PATH to a new file and run:

      bundle exec rake db:seed

  MSG
else
  TEAMS.each do |team|
    club = ClubRepo.save(
      Domain::Club.new(
        name: team.fetch(:name),
        short_name: team.fetch(:short),
        league_id: nil,
        reputation: team.fetch(:reputation),
        budget: team.fetch(:budget),
        wage_budget: team.fetch(:wage_budget),
        stadium: team.fetch(:stadium),
        chairman_name: team.fetch(:chairman_name),
        chairman_mood: team.fetch(:chairman_mood),
        board_target: team.fetch(:board_target)
      )
    )

    rows = POSITION_SKELETON.each_with_index.map do |pos, idx|
      build_player(
        team_short: team.fetch(:short),
        tier: team.fetch(:tier),
        position: pos,
        lineup_index: idx
      )
    end

    saved = persist_players.call(club, rows)
    tier_label = "#{team.fetch(:tier)} / #{TEAMS.size}"
    $stderr.puts(
      "Seeded #{club.short_name}: #{club.name} — tier #{tier_label} (~#{team.fetch(:reputation)} rep, " \
      "#{saved.size} players)."
    )
  end

  $stderr.puts "Five clubs seeded ( #{EXPECTED_SHORTS.join(" → ")} quality spread ) — fixtures/league wiring next."
end
