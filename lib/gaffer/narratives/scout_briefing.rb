# frozen_string_literal: true

module Gaffer
  module Narratives
    # Plain-text paragraphs for the pre-match scout — no pastel, no I/O (unit-testable strings).
    module ScoutBriefing
      DELTA_MARGIN = 3.5

      module_function

      # @param report [Domain::ScoutReport]
      # @return [Array<String>] plain paragraphs
      def paragraphs(report)
        paras = []

        opp = report.opponent.name.to_s.strip
        opp = "the opposition" if opp.empty?

        mgr = report.managed_club.name.to_s.strip
        mgr_short = mgr.empty? ? "your side" : mgr

        loc =
          report.hosting_managed ? "#{opp} at home" : "you are visiting #{opp}"
        paras << +"Gameweek #{Integer(report.gameweek)} — #{loc}. Here's what we've pieced together."

        paras << league_blurb(report, opp:, mgr_short:)

        fx = form_blurb(report, opp:)
        paras << fx if fx

        st = stylistic_blurb(report, opp:, mgr_short:)
        paras << st if st

        ww = watch_blurb(report)
        paras << ww if ww

        paras << outlook_blurb(report, opp:, mgr_short:)

        paras
      end

      def league_blurb(report, opp:, mgr_short:)
        pos = ordinal(Integer(report.league_position))
        opp_pts = Integer(report.opponent_points)
        played = Integer(report.played)
        our_pts = Integer(report.manager_points)
        our_p = Integer(report.manager_played)
        our_rank = ordinal(Integer(report.manager_league_position))

        opener = +"#{opp} are #{pos} with #{pts_word(opp_pts)} from #{played} played."

        if played.zero? && our_p.zero?
          opener << " New season, let's get stuck in!"
          return opener
        end

        diff = opp_pts - our_pts
        if diff.positive?
          opener << " That's #{diff} point#{diff == 1 ? '' : 's'} ahead of #{mgr_short}, sitting on #{pts_word(our_pts)} #{our_rank}."
        elsif diff.negative?
          ad = diff.abs
          opener << " We're #{ad} point#{ad == 1 ? '' : 's'} better off #{our_rank} with #{pts_word(our_pts)} — they will be looking to close the gap."
        else
          opener << " #{mgr_short} are parked on #{pts_word(our_pts)} too — honours even."
        end

        opener
      end

      def form_blurb(report, opp:)
        played = Integer(report.played)
        return nil if played <= 0

        form = Array(report.recent_form)
        return "" if form.empty?

        w = form.count { |x| x == :w }
        d = form.count { |x| x == :d }
        l_ct = form.count { |x| x == :l }
        sample = form.size

        vibe =
          if l_ct >= w + 2 || l_ct >= 3
            "have not been in great form"
          elsif w >= l_ct + 2 || w >= 3
            "they're looking pretty good right now"
          else
            "form's been a bit patchy"
          end

        +"Looking at form,  #{opp} #{vibe} — #{w} win#{'s' unless w == 1}, #{d} draw#{'s' unless d == 1}, #{l_ct} defeat#{'s' unless l_ct == 1} across their last #{sample}."
      end

      def stylistic_blurb(report, opp:, mgr_short:)
        oa = report.attack_rating.to_f
        od = report.defence_rating.to_f
        ma = report.our_attack_rating.to_f
        md = report.our_defence_rating.to_f

        skew =
          if oa - od >= DELTA_MARGIN
            "#{opp} are likely to be quite attack-minded."
          elsif od - oa >= DELTA_MARGIN
            "#{opp} are pretty solid at the back and don't give much away."
          else
            "#{opp} are pretty balanced, with a decent but not overwhelming attack and defence."
          end

        vs_us = +""
        if oa >= ma + DELTA_MARGIN
          vs_us << " They are little stronger upfront than us."
        elsif ma >= oa + DELTA_MARGIN
          vs_us << " Our attack should be stronger than theirs."
        end

        if od >= md + DELTA_MARGIN
          vs_us << " They've got a strong defence so we'll have to be clinical."
        elsif md >= od + DELTA_MARGIN
          vs_us << " Our defence should be strong enough to keep them out as long as we stay switched on"
        end

        skew + vs_us.to_s
      end

      def watch_blurb(report)
        wf = report.watch_focus
        return nil unless wf && wf[:player]

        ply = wf[:player]
        name = ply.name.to_s.strip
        return nil if name.empty?

        goals = wf[:goals]
        kind = wf[:kind]&.to_sym

        case kind
        when :scorer
          g = goals.to_i
          goal_phr =
            if g.positive?
              "#{g} goal#{g == 1 ? '' : 's'} goals this season"
            else
              "a nose for nuisance in the box"
            end
          +"We'll need to keep an eye on #{name} — #{goal_phr}, let's keep tight on him."
        when :livewire
          +"#{name}'s the one who makes things happen for them, let's get into him early and keep him quiet."
        when :enforcer
          +"#{name} is their enforcer, so let's keep him under control and press high so he can't dictate play."
        else
          +"#{name}'s is one to watch out for."
        end
      end

      def outlook_blurb(report, opp:, mgr_short:)
        opp_rank = Integer(report.league_position)
        our_rank = Integer(report.manager_league_position)
        gap_pts = Integer(report.opponent_points) - Integer(report.manager_points)
        opp_atk = report.attack_rating.to_f
        our_def = report.our_defence_rating.to_f

        tougher = +""
        if opp_rank < our_rank
          tougher << "They're sitting above us in the table "
          tougher <<
            if gap_pts.positive?
              "by a decent margin, we'll have to give it everything we've got."
            else
              "but only just — this is a great chance to close the gap"
            end
          return tougher
        end

        if our_rank < opp_rank
          return +"We're ahead of them in the table, so let's keep the pressure on and not let them get back into it."
        end

        if gap_pts.zero?
          +"League position is neck-and-neck; it's going to be a tight game but this is a great chance to pull away."
        elsif opp_atk >= our_def + DELTA_MARGIN
          +"Their attack is strong, so we shouldn't be going all out attack - let's keep it tight in our half."
        else
          +"On paper it looks 50/50 - starting the game well will be crucial to get the edge. "
        end
      end

      def ordinal(n)
        n = Integer(n)
        suffix =
          case n % 100
          when 11, 12, 13 then "th"
          else
            case n % 10
            when 1 then "st"
            when 2 then "nd"
            when 3 then "rd"
            else "th"
            end
          end
        "#{n}#{suffix}"
      end

      def pts_word(n)
        n = Integer(n)
        "#{n} point#{n == 1 ? '' : 's'}"
      end
    end
  end
end
