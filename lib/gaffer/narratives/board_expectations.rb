# frozen_string_literal: true

module Gaffer
  module Narratives
    # First-day note from the board — template copy only, keyed by ambition (`board_target`).
    # Deliberately no LLM calls; body variants rotate deterministically per club id.
    module BoardExpectations
      COPY = {
        avoid_relegation: [
          <<~TXT,
            We need to be playing in this division next season. No heroics required — organisation, fight, and points on the board.
            The supporters have been through a rough patch; give them something to hold onto. We're not asking for pretty football if it costs us our place.
          TXT
          <<~TXT,
            Survival is the job. They want {{club}} hard to beat, picking up results at home, with a dressing room that stays united when the run turns sour.
            Transfer spend is tight — work with what we have and don't promise the moon to the press.
          TXT
          <<~TXT,
            Avoiding the drop is non-negotiable. The board will back sensible decisions, not gambles. Pragmatism wins here.
            If we're still in this league when the curtain falls, {{manager}}, you'll have done what we hired you for.
          TXT
        ],
        mid_table: [
          <<~TXT,
            They're looking for stability and clear progress. Mid-table with a bit of momentum would suit us — no crisis football, no weekly chaos in the papers.
            Build a side the fans recognise: honest effort, a plan at set pieces, and younger players given a fair chance.
          TXT
          <<~TXT,
            Success means {{club}} feeling like a proper club again — competitive most weeks, difficult at home, not flirting with the bottom three by spring.
            There won't be a demand for miracles; there will be a demand for professionalism and a squad that looks like it knows its jobs.
          TXT
          <<~TXT,
            The brief is calm improvement. Finish in the pack, push the top half when the fixture list loosens, and keep the books sensible.
            Represent {{club}} well with the media — confident, not reckless.
          TXT
        ],
        top_half: [
          <<~TXT,
            The squad can finish in the top half if the details land: selection consistency, fitness, and a bit of ruthlessness in both boxes.
            You're not managing a charity case here — {{club}} should look upward more often than over its shoulder.
          TXT
          <<~TXT,
            Respectability has to carry an upward lean: top-half football, cups that don't embarrass us, home form fans can cling to after a bad commute.
            {{manager}}, you'll be judged on the table — and on whether this side has an identity after a few months in your hands.
          TXT
          <<~TXT,
            They want progress you can weigh in points. European chatter stays in the papers until we're nailed on in the top half.
            Win the big games at home; that's where seasons turn for {{club}}.
          TXT
        ],
        europe: [
          <<~TXT,
            The mandate is continental qualification — a squad that handles midweek cycles and a manager who rotates without sermonising about tired legs.
            {{club}} should be the sort of fixture the opposition scouts properly, not one they quietly fancy pinching late on.
          TXT
          <<~TXT,
            Fight for European places every week — consistency against the bottom half and some nerve against those above you.
            Recruit cleverly, not loudly; each signing ought to bump the ceiling, not clutter the payroll.
          TXT
          <<~TXT,
            The board want {{club}} in the conversation deep into spring. Margins decide these races; bottle after a setback decides them louder.
            Be hard to play through, nasty in transitions, boringly professional on Mondays.
          TXT
        ],
        title: [
          <<~TXT,
            Nobody hired {{manager}} to finish fourth — this league is there to win, not decorate the DVD cover in May when someone else lifts the trophy.
            Standards must be ruthless: intensity in training, clarity on the whiteboard, a dressing room terrified of conceding sloppy goals.
          TXT
          <<~TXT,
            A title race is the expectation. Depth at both ends, early goals that bury games, substitutions that feel decisive rather than apologetic.
            The circus outside will chatter; {{club}} needs the football doing the louder talking inside the ropes.
          TXT
          <<~TXT,
            Silverware settles arguments. They've invested believing {{club}} can set the tempo, invite pressure selectively, then hurt teams with quality.
            Win with style whenever it serves the table; steal three points when honesty demands it — frequency matters more than the adjectives.
          TXT
        ]
      }.freeze

      DEFAULT_TARGET = :mid_table

      module_function

      # @param club [Domain::Club]
      # @param manager_name [String]
      # @return [String] opener + paragraphs (blank lines between blocks)
      def message(club:, manager_name:)
        mgr = manager_name.to_s.strip
        mgr_greeting = mgr.empty? ? "Manager" : mgr

        tgt = normalize_target(club&.board_target)
        bank = COPY.fetch(tgt)
        body_template = bank[index_for(club&.id, bank.size)]
        body = interpolate(body_template.strip, club: club, manager_greeting: mgr_greeting)

        [opening_line(club), body].compact.join("\n\n")
      end

      def normalize_target(sym)
        key = sym.respond_to?(:to_sym) ? sym.to_sym : nil
        COPY.key?(key) ? key : DEFAULT_TARGET
      end
      module_function :normalize_target

      def opening_line(club)
        name = club&.chairman_name.to_s.strip
        club_name = club&.name.to_s

        base = +"On your first morning at #{club_name}, "
        suffix =
          if name.empty?
            "the board want their expectations spelled out plainly."
          else
            "#{name} wants expectations spelled out plainly on behalf of the board."
          end

        "#{base}#{suffix}"
      end
      module_function :opening_line

      def interpolate(template, club:, manager_greeting:)
        template.gsub("{{manager}}", manager_greeting).gsub("{{club}}", club&.name.to_s)
      end
      private_class_method :interpolate

      def index_for(club_id, size)
        return 0 if size <= 1

        id = club_id.to_i.abs
        id = 1 if id.zero?
        (id % size)
      end
      private_class_method :index_for
    end
  end
end
