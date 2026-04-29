# frozen_string_literal: true

# Fictional two-club starter data for match simulation (make-believe names & venues).
# Crowden Rovers (CRW) — higher reputation and squad ratings.
# Millbrook Wanderers (MBW) — noticeably weaker on average (lower skill bars + budgets).
#
# bundle exec rake db:seed

Gaffer::Database.connect

clubs_ds = Gaffer::Database.db[:clubs]
ClubRepo = Gaffer::Repositories::ClubRepository
PlayerRepo = Gaffer::Repositories::PlayerRepository
Domain = Gaffer::Domain

STRONG = "CRW"
WEAK   = "MBW"

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

have_strong = clubs_ds.where(short_name: STRONG).any?
have_weak = clubs_ds.where(short_name: WEAK).any?

if have_strong && have_weak
  $stderr.puts "Seed skipped: #{STRONG} and #{WEAK} already exist."
elsif have_strong || have_weak
  $stderr.puts <<-MSG

    Seed aborted: incomplete state (found one of #{STRONG}/#{WEAK} without the other).
    Use a fresh database (delete your SQLite file or point GAFFER_DB_PATH elsewhere) and run:

      bundle exec rake db:seed

  MSG
else
  # --- Crowden Rovers (strong side) ---
  crowden_rows = [
    { name: "Alex Norwood", age: 28, nationality: "ENG", position: :gk, gk: 84, pace: 42, shoot: 12, pass: 38, drib: 40, defn: 18, phys: 72, ovr: 82, pot: 84, form: 7, morale: :happy, years: 3, wage: 180 },
    { name: "Sam Vale", age: 22, nationality: "ENG", position: :gk, gk: 68, pace: 48, shoot: 15, pass: 35, drib: 34, defn: 20, phys: 66, ovr: 66, pot: 78, form: 6, morale: :okay, years: 4, wage: 45 },

    { name: "Logan Brooks", age: 26, nationality: "ENG", position: :def, gk: 18, pace: 76, shoot: 38, pass: 68, drib: 62, defn: 82, phys: 80, ovr: 79, pot: 82, form: 7, morale: :happy, years: 3, wage: 160 },
    { name: "Marco Silveira", age: 29, nationality: "POR", position: :def, gk: 15, pace: 72, shoot: 35, pass: 62, drib: 58, defn: 84, phys: 78, ovr: 80, pot: 81, form: 6, morale: :okay, years: 2, wage: 175 },
    { name: "Theo Hart", age: 24, nationality: "ENG", position: :def, gk: 16, pace: 78, shoot: 42, pass: 70, drib: 65, defn: 78, phys: 76, ovr: 76, pot: 84, form: 7, morale: :happy, years: 4, wage: 120 },
    { name: "Nils Larsson", age: 27, nationality: "SWE", position: :def, gk: 14, pace: 69, shoot: 40, pass: 66, drib: 60, defn: 80, phys: 82, ovr: 77, pot: 79, form: 6, morale: :okay, years: 3, wage: 110 },

    { name: "Jamie Cole", age: 25, nationality: "ENG", position: :mid, gk: 12, pace: 77, shoot: 72, pass: 83, drib: 80, defn: 62, phys: 74, ovr: 81, pot: 86, form: 8, morale: :ecstatic, years: 3, wage: 220 },
    { name: "Rafael Duarte", age: 23, nationality: "BRA", position: :mid, gk: 10, pace: 80, shoot: 68, pass: 79, drib: 86, defn: 58, phys: 72, ovr: 79, pot: 88, form: 7, morale: :happy, years: 5, wage: 140 },
    { name: "Ben Kerr", age: 28, nationality: "SCO", position: :mid, gk: 11, pace: 74, shoot: 78, pass: 81, drib: 76, defn: 66, phys: 78, ovr: 80, pot: 81, form: 6, morale: :okay, years: 2, wage: 165 },
    { name: "Emil Novak", age: 21, nationality: "CZE", position: :mid, gk: 9, pace: 78, shoot: 70, pass: 76, drib: 82, defn: 55, phys: 70, ovr: 75, pot: 86, form: 6, morale: :unsettled, years: 4, wage: 55 },

    { name: "Owen Blake", age: 24, nationality: "ENG", position: :att, gk: 12, pace: 86, shoot: 84, pass: 74, drib: 85, defn: 42, phys: 76, ovr: 83, pot: 89, form: 8, morale: :happy, years: 4, wage: 240 },
    { name: "Viktor Hale", age: 26, nationality: "NOR", position: :att, gk: 10, pace: 82, shoot: 80, pass: 72, drib: 80, defn: 45, phys: 80, ovr: 81, pot: 83, form: 7, morale: :okay, years: 3, wage: 190 },
    { name: "Ethan Price", age: 20, nationality: "ENG", position: :att, gk: 8, pace: 88, shoot: 76, pass: 70, drib: 83, defn: 38, phys: 72, ovr: 76, pot: 87, form: 6, morale: :happy, years: 5, wage: 35 },

    { name: "Henrik Dahl", age: 34, nationality: "NOR", position: :gk, gk: 74, pace: 36, shoot: 10, pass: 34, drib: 32, defn: 16, phys: 64, ovr: 72, pot: 73, form: 5, morale: :okay, years: 1, wage: 28 },
    { name: "Desmond Finch", age: 33, nationality: "ENG", position: :def, gk: 14, pace: 64, shoot: 32, pass: 58, drib: 54, defn: 76, phys: 74, ovr: 72, pot: 72, form: 5, morale: :okay, years: 2, wage: 55 },
    { name: "Luca Romano", age: 18, nationality: "ITA", position: :def, gk: 10, pace: 78, shoot: 28, pass: 56, drib: 62, defn: 64, phys: 70, ovr: 62, pot: 83, form: 6, morale: :happy, years: 4, wage: 8 },
    { name: "Haris Mahmoud", age: 19, nationality: "ENG", position: :def, gk: 9, pace: 75, shoot: 30, pass: 61, drib: 60, defn: 66, phys: 78, ovr: 64, pot: 82, form: 6, morale: :unsettled, years: 4, wage: 10 },
    { name: "Yuri Sokolov", age: 32, nationality: "POL", position: :mid, gk: 8, pace: 66, shoot: 64, pass: 74, drib: 66, defn: 71, phys: 76, ovr: 71, pot: 72, form: 5, morale: :okay, years: 1, wage: 48 },
    { name: "Kieron Moss", age: 17, nationality: "ENG", position: :mid, gk: 6, pace: 75, shoot: 58, pass: 66, drib: 73, defn: 52, phys: 64, ovr: 61, pot: 84, form: 6, morale: :happy, years: 5, wage: 4 },
    { name: "Malik Touré", age: 20, nationality: "MLI", position: :mid, gk: 7, pace: 80, shoot: 62, pass: 70, drib: 78, defn: 48, phys: 70, ovr: 65, pot: 82, form: 6, morale: :unsettled, years: 4, wage: 12 },
    { name: "Callum Reese", age: 31, nationality: "ENG", position: :att, gk: 10, pace: 76, shoot: 74, pass: 62, drib: 71, defn: 40, phys: 74, ovr: 72, pot: 73, form: 5, morale: :okay, years: 2, wage: 65 },
    { name: "Jonah Klein", age: 17, nationality: "GER", position: :att, gk: 6, pace: 85, shoot: 60, pass: 58, drib: 73, defn: 32, phys: 64, ovr: 61, pot: 82, form: 6, morale: :happy, years: 5, wage: 4 },
    { name: "Raul Cantu", age: 18, nationality: "ESP", position: :att, gk: 8, pace: 81, shoot: 64, pass: 66, drib: 75, defn: 36, phys: 66, ovr: 63, pot: 81, form: 6, morale: :happy, years: 4, wage: 6 }
  ]

  millbrook_rows = [
    { name: "Soren Bekker", age: 28, nationality: "NED", position: :gk, gk: 68, pace: 40, shoot: 10, pass: 32, drib: 36, defn: 16, phys: 64, ovr: 69, pot: 72, form: 6, morale: :okay, years: 2, wage: 18 },
    { name: "Felix Orchard", age: 21, nationality: "WAL", position: :gk, gk: 56, pace: 44, shoot: 12, pass: 30, drib: 30, defn: 18, phys: 60, ovr: 53, pot: 66, form: 5, morale: :unsettled, years: 4, wage: 5 },

    { name: "Cedric Hahn", age: 26, nationality: "GER", position: :def, gk: 12, pace: 64, shoot: 30, pass: 54, drib: 50, defn: 68, phys: 70, ovr: 65, pot: 70, form: 6, morale: :okay, years: 2, wage: 22 },
    { name: "Dante Reese", age: 28, nationality: "FRA", position: :def, gk: 10, pace: 60, shoot: 28, pass: 50, drib: 48, defn: 71, phys: 66, ovr: 66, pot: 68, form: 5, morale: :okay, years: 2, wage: 20 },
    { name: "Jonah Pike", age: 23, nationality: "ENG", position: :def, gk: 10, pace: 64, shoot: 32, pass: 56, drib: 56, defn: 65, phys: 70, ovr: 61, pot: 72, form: 6, morale: :happy, years: 3, wage: 12 },
    { name: "Willem Graf", age: 26, nationality: "AUT", position: :def, gk: 8, pace: 58, shoot: 28, pass: 54, drib: 50, defn: 69, phys: 72, ovr: 63, pot: 65, form: 5, morale: :okay, years: 2, wage: 15 },

    { name: "Luis Calder", age: 27, nationality: "ESP", position: :mid, gk: 6, pace: 64, shoot: 58, pass: 68, drib: 69, defn: 50, phys: 64, ovr: 67, pot: 72, form: 6, morale: :okay, years: 2, wage: 28 },
    { name: "Milo Brennan", age: 21, nationality: "IRL", position: :mid, gk: 5, pace: 66, shoot: 56, pass: 65, drib: 73, defn: 46, phys: 60, ovr: 65, pot: 74, form: 7, morale: :happy, years: 4, wage: 9 },
    { name: "Ivo Hart", age: 29, nationality: "CRO", position: :mid, gk: 6, pace: 60, shoot: 64, pass: 68, drib: 70, defn: 54, phys: 70, ovr: 66, pot: 68, form: 5, morale: :okay, years: 1, wage: 24 },
    { name: "Piers Lang", age: 21, nationality: "ENG", position: :mid, gk: 4, pace: 64, shoot: 58, pass: 62, drib: 70, defn: 44, phys: 58, ovr: 61, pot: 73, form: 5, morale: :unsettled, years: 3, wage: 7 },

    { name: "Niko Sund", age: 24, nationality: "SWE", position: :att, gk: 6, pace: 72, shoot: 70, pass: 60, drib: 71, defn: 36, phys: 66, ovr: 69, pot: 75, form: 6, morale: :happy, years: 3, wage: 18 },
    { name: "Jasper Morley", age: 26, nationality: "ENG", position: :att, gk: 4, pace: 68, shoot: 66, pass: 58, drib: 72, defn: 34, phys: 70, ovr: 67, pot: 70, form: 6, morale: :okay, years: 2, wage: 22 },
    { name: "Efe Okoro", age: 18, nationality: "NGA", position: :att, gk: 4, pace: 74, shoot: 60, pass: 54, drib: 71, defn: 28, phys: 60, ovr: 60, pot: 72, form: 5, morale: :happy, years: 5, wage: 3 },

    { name: "Pat Rhys", age: 34, nationality: "WAL", position: :gk, gk: 58, pace: 32, shoot: 8, pass: 28, drib: 28, defn: 14, phys: 58, ovr: 57, pot: 58, form: 4, morale: :okay, years: 1, wage: 4 },
    { name: "Gil Moss", age: 34, nationality: "ENG", position: :def, gk: 8, pace: 50, shoot: 24, pass: 44, drib: 42, defn: 63, phys: 62, ovr: 58, pot: 59, form: 4, morale: :okay, years: 1, wage: 6 },
    { name: "Taylor Venn", age: 17, nationality: "ENG", position: :def, gk: 4, pace: 64, shoot: 22, pass: 44, drib: 54, defn: 50, phys: 58, ovr: 49, pot: 68, form: 5, morale: :happy, years: 5, wage: 1 },
    { name: "Robin Saxe", age: 17, nationality: "SCO", position: :def, gk: 4, pace: 60, shoot: 20, pass: 48, drib: 50, defn: 53, phys: 64, ovr: 50, pot: 67, form: 5, morale: :unsettled, years: 4, wage: 1 },
    { name: "Mauricio Vigo", age: 34, nationality: "ARG", position: :mid, gk: 4, pace: 52, shoot: 50, pass: 61, drib: 54, defn: 58, phys: 64, ovr: 58, pot: 59, form: 4, morale: :okay, years: 1, wage: 6 },
    { name: "Danny Firth", age: 17, nationality: "ENG", position: :mid, gk: 4, pace: 64, shoot: 48, pass: 56, drib: 61, defn: 40, phys: 56, ovr: 52, pot: 72, form: 5, morale: :happy, years: 5, wage: 1 },
    { name: "Aaron Duval", age: 21, nationality: "BEL", position: :mid, gk: 4, pace: 66, shoot: 50, pass: 60, drib: 63, defn: 36, phys: 60, ovr: 54, pot: 70, form: 5, morale: :unsettled, years: 3, wage: 3 },
    { name: "Stef Boone", age: 31, nationality: "USA", position: :att, gk: 4, pace: 62, shoot: 60, pass: 50, drib: 61, defn: 34, phys: 66, ovr: 58, pot: 60, form: 5, morale: :okay, years: 2, wage: 8 },
    { name: "Lyle Correa", age: 17, nationality: "POR", position: :att, gk: 2, pace: 70, shoot: 48, pass: 46, drib: 61, defn: 24, phys: 56, ovr: 48, pot: 68, form: 5, morale: :happy, years: 5, wage: 1 },
    { name: "Hugo Cairns", age: 17, nationality: "AUS", position: :att, gk: 4, pace: 66, shoot: 52, pass: 54, drib: 62, defn: 24, phys: 54, ovr: 51, pot: 69, form: 5, morale: :happy, years: 4, wage: 1 }
  ]

  crowden = ClubRepo.save(
    Domain::Club.new(
      name: "Crowden Rovers FC",
      short_name: STRONG,
      league_id: nil,
      reputation: 88,
      budget: 150_000,
      wage_budget: 5_000,
      stadium: "Crowden Moor",
      chairman_name: "H. Calder",
      chairman_mood: :satisfied,
      board_target: :europe
    )
  )

  millbrook = ClubRepo.save(
    Domain::Club.new(
      name: "Millbrook Wanderers",
      short_name: WEAK,
      league_id: nil,
      reputation: 61,
      budget: 9_500,
      wage_budget: 420,
      stadium: "River End Ground",
      chairman_name: "R. Finch",
      chairman_mood: :concerned,
      board_target: :avoid_relegation
    )
  )

  s1 = persist_players.call(crowden, crowden_rows)
  s2 = persist_players.call(millbrook, millbrook_rows)

  $stderr.puts "Seeded #{crowden.short_name}: #{crowden.name} (#{s1.size} players, rep #{crowden.reputation})."
  $stderr.puts "Seeded #{millbrook.short_name}: #{millbrook.name} (#{s2.size} players, rep #{millbrook.reputation}) — weaker on average than #{STRONG} for testing."
end
