# frozen_string_literal: true

require_relative "../narratives/board_expectations"

module Gaffer
  module Ui
    module Onboarding
      module_function

      # @param clubs [Array<Gaffer::Domain::Club>]
      def run!(prompt:, pastel:, out:, clubs:)
        sorted = clubs.sort_by(&:name)
        raise ArgumentError, "need at least one club" if sorted.empty?

        print "\e[2J\e[H"

        out.puts
        out.puts pastel.bold.white("Set up your save")
        out.puts pastel.dim("You're not managing a club yet — name yourself, then pick who you manage.")
        out.puts

        name_input = prompt.ask("Your name (how it'll appear around the club):") do |q|
          q.required true
          q.modify(:trim)
          q.validate(->(inp) { s = inp.to_s.strip; s.length.positive? && s.length <= 60 }, "1–60 characters, not blank.")
        end

        nm = name_input.to_s.strip
        raise ArgumentError, "blank name" if nm.empty?

        club = prompt.select(pastel.bold("Which club do you manage?"), filter: true, cycle: true) do |menu|
          sorted.each do |c|
            label = "#{c.short_name}: #{c.name}  · rep #{c.reputation}"
            menu.choice label, c
          end
        end

        Repositories::ManagerRepository.activate!(
          display_name: nm,
          managed_club_id: club.id
        )

        note = Narratives::BoardExpectations.message(club: club, manager_name: nm)

        out.puts
        out.puts pastel.green.bold("#{nm}, you're in the hot seat.")
        out.puts
        out.puts pastel.dim("─" * 52)
        out.puts pastel.bold.white("Letter from the board")
        note.split(/\n\n+/).map(&:strip).each do |para|
          out.puts
          out.puts para
        end
        out.puts
        out.puts pastel.dim("─" * 52)
        out.puts
        prompt.keypress(pastel.dim("Press any key for the main menu…"))
      end
    end
  end
end
