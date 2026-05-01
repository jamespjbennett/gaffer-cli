#!/usr/bin/env ruby
# frozen_string_literal: true

# 10 simulated matches — identical roster stats; home XI always middling morale/form.
# Away XI: grim (:unhappy, form 1) runs 1–5, ecstatic (:ecstatic, form 10) runs 6–10.
# Same reputations → spread comes from morale/form multiplier only.
#
# Usage (repo root):
#   bundle exec ruby test/manual/morale_form_sim_comparison.rb
# Fixed RNG stream:
#   BASE_SEED=500_000 bundle exec ruby test/manual/morale_form_sim_comparison.rb

ROOT = File.expand_path("../..", __dir__)
$LOAD_PATH.unshift File.join(ROOT, "lib")

require "gaffer/domain/match_engine"
require "gaffer/domain/club"
require "gaffer/domain/player"
require "gaffer/domain/lineup"

runs = []
engine = Gaffer::Domain::MatchEngine.new
base_seed =
  case ENV.fetch("BASE_SEED", "").strip
  when ""
    500_000
  else
    Integer(ENV.fetch("BASE_SEED"))
  end

club = lambda do |rep:|
  Gaffer::Domain::Club.new(
    short_name: "TST",
    name: "Test Town",
    league_id: nil,
    reputation: rep,
    budget: 1,
    wage_budget: 1,
    stadium: "Lab",
    chairman_name: "X",
    chairman_mood: :okay,
    board_target: :mid_table
  )
end

same_club = club.call(rep: 68)

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
      form: 5,
      morale: :okay,
      contract_years: 3,
      wage: base_ovr
    )
  end
end

roster_template = builder.call(72)
base_xi = Gaffer::Domain::Lineup.pick_best_xi(roster_template)

def clone_xi_mood(base_xi, morale:, form:)
  base_xi.map do |pl|
    Gaffer::Domain::Player.new(**pl.to_h.merge(morale: morale, form: form))
  end
end

home_always = clone_xi_mood(base_xi, morale: :okay, form: 5)

puts "Morale/form check — #{base_xi.size} each side · rep #{same_club.reputation} · home :okay/form5 always"
puts format(
  "%-4s %-16s %-10s %-10s %-10s %-10s %s",
  "run", "away mood", "λ_home", "λ_away", "Atk(h)", "Atk(a)", "goals(h-a)"
)

(0...10).each do |i|
  away =
    if i < 5
      [:grim, clone_xi_mood(base_xi, morale: :unhappy, form: 1)]
    else
      [:ecstatic_peak, clone_xi_mood(base_xi, morale: :ecstatic, form: 10)]
    end

  seed = base_seed + i
  r = engine.simulate(
    home_club: same_club,
    home_players: home_always,
    away_club: same_club,
    away_players: away[1],
    home_tactic: :balanced,
    away_tactic: :balanced,
    seed: seed
  )

  label = away[0]
  runs << {
    phase: i < 5 ? :low : :high,
    lam_h: r.home_xg_lambda,
    lam_a: r.away_xg_lambda,
    gh: r.home_score,
    ga: r.away_score,
    seed: seed
  }

  puts format(
    "%-4s %-16s %-10.5f %-10.5f %-10.5f %-10.5f %s-%s",
    i + 1,
    label.to_s,
    r.home_xg_lambda,
    r.away_xg_lambda,
    r.home_attack_rating.round(5),
    r.away_attack_rating.round(5),
    r.home_score,
    r.away_score
  )
end

low = runs.select { |x| x[:phase] == :low }
high = runs.select { |x| x[:phase] == :high }
avg_low_lam_a = low.sum { _1[:lam_a] } / low.size
avg_high_lam_a = high.sum { _1[:lam_a] } / high.size

puts "---"
puts "Away λ averaged (grim runs 1–5):   #{avg_low_lam_a.round(6)}"
puts "Away λ averaged (peak runs 6–10):  #{avg_high_lam_a.round(6)}"
puts "Goals (home total / away total):     #{runs.sum { _1[:gh] }}/#{runs.sum { _1[:ga] }}"
puts "Away goals low phase vs high phase: #{low.sum { _1[:ga] }}/#{high.sum { _1[:ga] }}"
