# frozen_string_literal: true

require_relative "../../domain/match_engine"

module Gaffer
  module Commands
    module Support
      # Tactic labels, coercion, and interactive pick for the managed side.
      module GameweekTactics
        extend self

        # Rows for `TTY::Prompt#select` — keys match `Domain::MatchEngine::TACTIC_MODIFIERS`.
        APPROACH_CHOICES = [
          ["All-out attack — lash forward; pray at the back", :all_out_attack],
          ["Attacking — positive without total chaos", :attacking],
          ["Balanced — steady Eddy", :balanced],
          ["Defensive — spoil and frustrate", :defensive],
          ["Park the bus — low blocks; invite pressure", :park_the_bus]
        ].freeze

        TACTIC_HEADLINE = {
          all_out_attack: "All-out attack",
          attacking:      "Attacking",
          balanced:       "Balanced",
          defensive:      "Defensive",
          park_the_bus:   "Park the bus"
        }.freeze

        def coerce_manager_shape(raw)
          return :balanced if raw.nil?

          sym = raw.respond_to?(:to_sym) ? raw.to_sym : :balanced
          Domain::MatchEngine::TACTIC_MODIFIERS.key?(sym) ? sym : :balanced
        end

        def tactics_pair_for(fixture:, managed_id:, shape:)
          tactical = coerce_manager_shape(shape)
          hid = fixture.home_club_id.to_i
          aid = fixture.away_club_id.to_i
          mid = managed_id.to_i

          case mid
          when hid then [tactical, :balanced]
          when aid then [:balanced, tactical]
          else            [:balanced, :balanced]
          end
        end

        def resolve_manager_shape(manager_tactic:, prompt:, pastel:, out:, managed_fixture:, clubs_by_id:, managed_club_id:)
          return coerce_manager_shape(manager_tactic) unless manager_tactic.nil?

          return :balanced unless prompt.respond_to?(:select)

          pick_interactive_shape(pastel:, out:, prompt:, managed_fixture:, clubs_by_id:, managed_club_id:)
        end

        def tactic_label(sym)
          TACTIC_HEADLINE.fetch(coerce_manager_shape(sym))
        end

        def pick_interactive_shape(pastel:, out:, prompt:, managed_fixture:, clubs_by_id:, managed_club_id:)
          mid = managed_club_id.to_i
          opp_id = opponent_id_for(managed_fixture, mid)
          opp_name = clubs_by_id.fetch(opp_id).name.to_s.strip
          role = managed_fixture.home_club_id.to_i == mid ? "Hosting" : "Visiting"
          banner = +"#{pastel.bold("Pick your tactical shape")}"
          banner << pastel.dim("  · #{role} #{opp_name}")
          out.puts
          sel = prompt.select(
            banner,
            APPROACH_CHOICES.map { |label, sym| { name: label, value: sym } }
          )
          coerce_manager_shape(sel)
        end

        def opponent_id_for(managed_fixture, mid)
          managed_fixture.home_club_id.to_i == mid ? managed_fixture.away_club_id : managed_fixture.home_club_id
        end
      end
    end
  end
end
