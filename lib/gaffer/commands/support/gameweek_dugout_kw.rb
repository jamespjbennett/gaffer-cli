# frozen_string_literal: true

module Gaffer
  module Commands
    module Support
      # Keyword pack for [`Ui::DugoutLineup.resolve`] from GW preflight state — testable seam.
      module GameweekDugoutKw
        module_function

        def resolve_args(state:, scout:, coaching:, manager_lineup: nil)
          {
            preset: manager_lineup,
            suggested_xi: state.suggested_xi,
            full_squad: state.full_squad,
            club: state.managed_club,
            gameweek: state.gameweek,
            opponent: state.opponent_name_short,
            hosting: state.hosting_managed,
            scout: scout,
            coaching: coaching
          }
        end
      end
    end
  end
end
