# frozen_string_literal: true

# Ten fictional clubs in five loosely paired tiers (similar strength pairs top → bottom).
# bundle exec rake db:seed

Gaffer::Database.connect

clubs_ds = Gaffer::Database.db[:clubs]
ClubRepo = Gaffer::Repositories::ClubRepository
PlayerRepo = Gaffer::Repositories::PlayerRepository
Domain = Gaffer::Domain

# Canonical short codes in descending quality order.
EXPECTED_SHORTS = %w[CRW STB KLF VPK AHU RCT FAB LAN HCY MBW].freeze

# Squad baseline per tier — pairs are close neighbours (tier 2 nudges slightly under tier 1, etc.).
TIER_OVR_CENTER = [76, 74, 70, 68, 64, 62, 57, 55, 51, 49].freeze

TEAMS = [
  {
    short: "CRW",
    name: "Crowden Rovers FC",
    tier: 1,
    reputation: 86,
    budget: 140_000,
    wage_budget: 4800,
    stadium: "Crowden Moor",
    chairman_name: "H. Calder",
    chairman_mood: :delighted,
    board_target: :europe
  },
  {
    short: "STB",
    name: "Staverton Borough",
    tier: 2,
    reputation: 81,
    budget: 95_000,
    wage_budget: 3200,
    stadium: "Borough Park",
    chairman_name: "G. Stavely",
    chairman_mood: :satisfied,
    board_target: :top_half
  },
  {
    short: "KLF",
    name: "Kettleford Town",
    tier: 3,
    reputation: 74,
    budget: 58_000,
    wage_budget: 2100,
    stadium: "Kettleford Road",
    chairman_name: "E. Kettle",
    chairman_mood: :satisfied,
    board_target: :top_half
  },
  {
    short: "VPK",
    name: "Vale Park Athletic",
    tier: 4,
    reputation: 72,
    budget: 48_000,
    wage_budget: 1750,
    stadium: "Vale Park",
    chairman_name: "N. Pemberton",
    chairman_mood: :okay,
    board_target: :mid_table
  },
  {
    short: "AHU",
    name: "Ashton Heath United",
    tier: 5,
    reputation: 69,
    budget: 38_000,
    wage_budget: 1380,
    stadium: "Heath Lane",
    chairman_name: "M. Briggs",
    chairman_mood: :okay,
    board_target: :mid_table
  },
  {
    short: "RCT",
    name: "Riverside Town",
    tier: 6,
    reputation: 67,
    budget: 32_000,
    wage_budget: 1180,
    stadium: "Riverside Park",
    chairman_name: "P. Lowell",
    chairman_mood: :okay,
    board_target: :mid_table
  },
  {
    short: "FAB",
    name: "Fenbury Athletic",
    tier: 7,
    reputation: 61,
    budget: 18_000,
    wage_budget: 650,
    stadium: "Fenbury Meadow",
    chairman_name: "L. Wynne",
    chairman_mood: :concerned,
    board_target: :avoid_relegation
  },
  {
    short: "LAN",
    name: "Langford United",
    tier: 8,
    reputation: 58,
    budget: 14_500,
    wage_budget: 520,
    stadium: "Langbrook Bank",
    chairman_name: "J. Calderwood",
    chairman_mood: :concerned,
    board_target: :avoid_relegation
  },
  {
    short: "HCY",
    name: "Hartwell City",
    tier: 9,
    reputation: 53,
    budget: 10_200,
    wage_budget: 410,
    stadium: "Hartwell Crescent",
    chairman_name: "S. Briggs",
    chairman_mood: :concerned,
    board_target: :avoid_relegation
  },
  {
    short: "MBW",
    name: "Millbrook Wanderers",
    tier: 10,
    reputation: 50,
    budget: 8800,
    wage_budget: 360,
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
  Norwood Brooks Hart Silveira Kerr Duarte Vale Novak Dahl Larsson Pace Morgan Reed Shaw Wells Finn Croft Dale Marsh Young Bishop Cole Hale Price Romano Sokolov Finch Touré Mahmoud Cantu Reese Klein Orchard Hahn Reese Pike Graf Calder Brennan Hart Lang Sund Morley Duval Graf Okoro Graf Rhys Moss Venn Boone Correa Cairns Stavely Pemberton Kettle Briggs Calderwood
].freeze

NATIONS = %w[ENG SCO WAL IRL GER FRA ESP POR NED SWE NOR CZE POL BRA USA AUS BEL ITA ARG NGA MLI GER CRO AUT].freeze

POSITION_SKELETON = (([:gk] * 3) + ([:def] * 7) + ([:mid] * 7) + ([:att] * 6)).freeze

def seeded_rng(team_short, lineup_index)
  seed_val = ("#{team_short}:#{lineup_index}".hash % 2_147_483_647)
  Random.new(seed_val)
end

def build_player(team_short:, tier:, position:, lineup_index:)
  tier_idx = tier - 1
  center = TIER_OVR_CENTER[tier_idx]
  rng = seeded_rng(team_short, lineup_index)
  drift = rng.rand(-6..7) + ((lineup_index % 11) / 4)
  base = center + drift
  lvl = base.clamp(38, 93)

  name = "#{FIRST_NAMES[lineup_index % FIRST_NAMES.size]} #{SURNAMES[(lineup_index * 17 + tier_idx * 31) % SURNAMES.size]}"
  nat = NATIONS[lineup_index % NATIONS.size]
  age = rng.rand((tier <= 4 ? 18 : 17)..(tier <= 4 ? 34 : 35))
  years = rng.rand(1..4)
  wage = rng.rand((tier <= 5 ? 3 : 1)..(tier * 24 + rng.rand(-3..38)))
  wage = wage.clamp(1, tier * 40 + 30)
  form = rng.rand((tier <= 5 ? 5 : 4)..8)
  morale = [:okay, :happy, :unsettled, :okay, :okay].sample(random: rng)
  pot_delta = rng.rand((tier <= 7 ? 2 : 1)..12)

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
  $stderr.puts "Seed skipped: all #{TEAMS.size} fictional clubs #{EXPECTED_SHORTS.join(", ")} already exist."
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
    pair = ((team.fetch(:tier) - 1) / 2) + 1
    $stderr.puts(
      "Seeded #{club.short_name}: #{club.name} — tier #{team.fetch(:tier)} " \
      "(pair #{pair}/5, ~#{team.fetch(:reputation)} rep, #{saved.size} players)."
    )
  end

  $stderr.puts "Ten clubs seeded (five loosely paired tiers, #{EXPECTED_SHORTS.first} → #{EXPECTED_SHORTS.last} spread)."
end
