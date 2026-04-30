#!/usr/bin/env ruby
# frozen_string_literal: true

# Manual comparison: same squads; each matchup uses paired seeds — only your tactic differs.
#
# Defaults: a fresh random baseline each run (`Random.new_seed`) so totals change between invocations.
#
# Usage (from repo root):
#   bundle exec ruby test/manual/tactics_sim_comparison.rb
# Reproduce one run verbatim:
#   BASE_SEED=384291847 bundle exec ruby test/manual/tactics_sim_comparison.rb

ROOT = File.expand_path("../..", __dir__)
$LOAD_PATH.unshift File.join(ROOT, "lib")

require "gaffer/domain/match_engine"
require "gaffer/domain/club"
require "gaffer/domain/player"

GAMES = 50
OPPONENT_TACTIC = :balanced # league "next" currently uses this for opposition

engine = Gaffer::Domain::MatchEngine.new

base_seed =
  case ENV.fetch("BASE_SEED", "").strip
  when ""
    Random.new_seed
  else
    Integer(ENV.fetch("BASE_SEED"))
  end

builder = lambda do |base_ovr|
  skeleton = ([:gk] * 3) + ([:def] * 7) + ([:mid] * 7) + ([:att] * 6)

  skeleton.map.with_index do |pos, idx|
    ovr = (base_ovr + (idx % 7) - 3).clamp(40, 95)
    gk = pos == :gk ? ovr + 14 : [(ovr / 10.0).to_i, 55].max
    Gaffer::Domain::Player.new(
      name: "#{pos}_#{idx}",
      position: pos,
      age: 24,
      nationality: "ZZ",
      club_id: 1,
      pace: ovr + 10,
      shooting: ovr + 14,
      passing: ovr + 12,
      dribbling: ovr + (pos == :att ? +8 : -4),
      defending: pos == :gk ? 24 : pos == :att ? (ovr - 18).clamp(1, 99) : ovr + 8,
      physical: ovr + 5,
      goalkeeping: gk.to_i.clamp(1, 99),
      overall: ovr + 15,
      potential: ovr + 26,
      form: 6,
      morale: :okay,
      contract_years: 3,
      wage: base_ovr
    )
  end
end

club = lambda do |short:, rep:, name:, board:|
  Gaffer::Domain::Club.new(
    short_name: short,
    name: name,
    league_id: nil,
    reputation: rep,
    budget: 1,
    wage_budget: 1,
    stadium: "Test Ground",
    chairman_name: "X",
    chairman_mood: :okay,
    board_target: board
  )
end

you_club      = club.call(short: "YOU", rep: 88, name: "Your Club", board: :europe)
opp_club      = club.call(short: "OPP", rep: 58, name: "Opponent", board: :avoid_relegation)
you_squad     = builder.call(78)
opp_squad     = builder.call(56)

# You are HOME every game (same matchup as synthetic tests: strong XI vs weaker XI).

run_bucket = lambda do |home_shape|
  gf = ga = 0

  GAMES.times do |i|
    r = engine.simulate(
      home_club: you_club, home_players: you_squad,
      away_club: opp_club, away_players: opp_squad,
      home_tactic: home_shape,
      away_tactic: OPPONENT_TACTIC,
      seed: base_seed + i
    )
    gf += r.home_score
    ga += r.away_score
  end

  [gf, ga]
end

ao_gf, ao_ga = run_bucket.call(:all_out_attack)
pb_gf, pb_ga = run_bucket.call(:park_the_bus)

n = GAMES.to_f

puts "=" * 60
puts "Tactics comparison (#{GAMES} games each)"
puts "Session baseline seed: #{base_seed} (slot i ⇒ seed baseline + i; identical slots for AO vs PTB)"
puts "Reproduce: BASE_SEED=#{base_seed} bundle exec ruby test/manual/#{File.basename(__FILE__)}"
puts "You HOME: #{you_club.name} vs #{opp_club.name} (away tactic #{OPPONENT_TACTIC.inspect})"
puts "=" * 60
puts ""
printf "%-16s  Total GF %3d   Total GA %3d   Per game GF–GA %.2f – %.2f\n",
       "All-out attack", ao_gf, ao_ga, ao_gf / n, ao_ga / n
printf "%-16s  Total GF %3d   Total GA %3d   Per game GF–GA %.2f – %.2f\n",
       "Park the bus", pb_gf, pb_ga, pb_gf / n, pb_ga / n
puts ""
puts "Δ (all-out − bus)  GF #{'%+d' % (ao_gf - pb_gf)}   GA #{'%+d' % (ao_ga - pb_ga)}"
printf "                         Per game #{'%+.3f' % ((ao_gf - pb_gf) / n)}   #{'%+.3f' % ((ao_ga - pb_ga) / n)}\n"
puts "=" * 60
