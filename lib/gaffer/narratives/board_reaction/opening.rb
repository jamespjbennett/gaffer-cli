# frozen_string_literal: true

require_relative "tone"
require_relative "vibes"

module Gaffer
  module Narratives
    module BoardReaction
      # Scoreline + venue + opponent + board sentiment; optional second paragraph.
      module Opening
        extend self

        def block(ctx)
          [opening_paragraph(ctx), rider_line(ctx)].compact.join("\n\n")
        end

        private

        def opening_paragraph(ctx)
          "#{Tone.lede(ctx)}The board #{feel_for(ctx)} today's #{digits(ctx)} #{adj(ctx)} " \
          "#{kind(ctx)} against #{club_line(ctx)}."
        end

        def rider_line(ctx)
          rk = rider_key(ctx)
          return nil if rk == :none

          RIDERS[rk].call(ctx)
        end

        def rider_key(ctx)
          return :grim_regroup if ctx.managed_loss? && Vibes.grim_loss?(ctx)
          return :soft_context if ctx.managed_loss? && Vibes.forgiving_loss?(ctx)
          return :boom_run if ctx.managed_win? && ctx.margin >= 3
          return :tight_garden if narrow_home_pathetic?(ctx)
          return :square_stale if tepid_square?(ctx)

          :none
        end

        def narrow_home_pathetic?(ctx)
          ctx.margin == 1 && ctx.hosting_managed && ctx.opponent_weak?
        end

        def tepid_square?(ctx)
          Vibes.tepid_draw?(ctx)
        end

        def digits(ctx)
          "#{ctx.home_score}-#{ctx.away_score}"
        end

        def adj(ctx)
          ctx.hosting_managed ? "home" : "away"
        end

        def kind(ctx)
          return "victory" if ctx.managed_win?

          Vibes.drawn?(ctx) ? "draw" : "defeat"
        end

        def club_line(ctx)
          nm = ctx.opponent_club.name.to_s.strip
          short = ctx.opponent_club.short_name.to_s.strip
          return "the opposition" if nm.empty?
          return nm if short.empty? || short.casecmp(nm).zero?

          "#{nm} (#{short})"
        end

        def feel_for(ctx)
          return win_feel(ctx) if ctx.managed_win?
          return loss_feel(ctx) if ctx.managed_loss?

          draw_feel(ctx)
        end

        def win_feel(ctx)
          row = WIN_FEELS.fetch(win_grade(ctx))
          elev = row[:elevated]

          delight?(ctx) && elev ? elev : row.fetch(:stable)
        end

        def delight?(ctx)
          ctx.managed_club.chairman_mood&.to_sym == :delighted
        end

        def win_grade(ctx)
          return :routed if ctx.margin >= 3
          return :giant if !ctx.hosting_managed && ctx.opponent_strong?
          return :strong if ctx.margin >= 2
          return :nervy if narrow_home_pathetic?(ctx)

          :standard
        end

        def loss_feel(ctx)
          mood = ctx.managed_club.chairman_mood&.to_sym
          row = LOSS_FEELS.fetch(loss_grade(ctx))

          furious?(mood, row[:furious], row[:stable])
        end

        def furious?(sym, fiery, sane)
          return fiery if sym == :furious && fiery
          sane
        end # fiery may be nil => fall back to sane

        def loss_grade(ctx)
          return :tank if ctx.margin >= 3
          return :away_brave if Vibes.forgiving_loss?(ctx)
          return :sneaky if slender_away?(ctx)

          home_soft_miss?(ctx) ? :house : :neutral
        end

        def slender_away?(ctx)
          !ctx.hosting_managed && !ctx.opponent_weak? && ctx.margin == 1
        end

        def home_soft_miss?(ctx)
          ctx.hosting_managed && ctx.opponent_weak?
        end

        def draw_feel(ctx)
          return DRAW_FEELS.fetch(:borrowed) if !ctx.hosting_managed && ctx.opponent_strong?
          return DRAW_FEELS.fetch(:stutter) if Vibes.tepid_draw?(ctx)

          DRAW_FEELS.fetch(:steady)
        end

        WIN_FEELS = {
          routed: { stable: "are thrilled by", elevated: "are delighted by" },
          giant: { stable: "are delighted by", elevated: "are over the moon about" },
          strong: { stable: "are very pleased by", elevated: "are ecstatic about" },
          nervy: { stable: "are relieved by", elevated: nil },
          standard: { stable: "are pleased by", elevated: nil }
        }.freeze

        LOSS_FEELS = {
          tank: {
            stable: "are deeply unhappy with",
            furious: "are furious about"
          },
          away_brave: {
            stable: "are pragmatic yet disappointed by",
            furious: nil
          },
          sneaky: {
            stable: "are frustrated by",
            furious: "are irritated by"
          },
          house: {
            stable: "are bitterly disappointed by",
            furious: nil
          },
          neutral: {
            stable: "are unhappy with",
            furious: "are furious about"
          }
        }.freeze

        DRAW_FEELS = {
          borrowed: "are broadly satisfied by",
          stutter: "are restless after",
          steady: "are content with"
        }.freeze

        RIDERS = {
          grim_regroup:
            lambda do |_c|
              "They expect far sharper defending and sharper finishing before kick-off rolls around again."
            end,
          soft_context:
            lambda do |_c|
              "They're parking crisis talk tonight but want a bolder response soon."
            end,
          boom_run:
            lambda do |_c|
              "They're pushing for momentum and ruthless standards to carry straight into training."
            end,
          tight_garden:
            lambda do |_c|
              "They banked three points yet pressed for sharper patterns around the eighteen-yard box."
            end,
          square_stale:
            lambda do |_c|
              "They feel two points vanished on home turf and won't accept a repeat anytime soon."
            end
        }.freeze
      end
    end
  end
end
