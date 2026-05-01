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
          report.hosting_managed ? "#{opp} roll into your patch" : "you trek to #{opp}"
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
          opener << " It's early doors — everyone's still trading on reputation."
          return opener
        end

        diff = opp_pts - our_pts
        if diff.positive?
          opener << " That's #{diff} point#{diff == 1 ? '' : 's'} ahead of #{mgr_short}, sitting on #{pts_word(our_pts)} #{our_rank}."
        elsif diff.negative?
          ad = diff.abs
          opener << " We're #{ad} point#{ad == 1 ? '' : 's'} better off #{our_rank} with #{pts_word(our_pts)} — they trail and know it."
        else
          opener << " #{mgr_short} are parked on #{pts_word(our_pts)} too — honours even."
        end

        opener
      end

      def form_blurb(report, opp:)
        played = Integer(report.played)
        return nil if played <= 0

        form = Array(report.recent_form)
        if form.empty?
          return +"League ledger's thin on them yet — treat their tape with a pinch of salt."
        end

        w = form.count { |x| x == :w }
        d = form.count { |x| x == :d }
        l_ct = form.count { |x| x == :l }
        sample = form.size

        vibe =
          if l_ct >= w + 2 || l_ct >= 3
            "they've looked leg-heavy and short on belief"
          elsif w >= l_ct + 2 || w >= 3
            "they've been in confident touch"
          else
            "form's been middling rather than flashy"
          end

        +"Recent mood? #{opp} #{vibe} — #{w} win#{'s' unless w == 1}, #{d} draw#{'s' unless d == 1}, #{l_ct} defeat#{'s' unless l_ct == 1} across their last #{sample}."
      end

      def stylistic_blurb(report, opp:, mgr_short:)
        oa = report.attack_rating.to_f
        od = report.defence_rating.to_f
        ma = report.our_attack_rating.to_f
        md = report.our_defence_rating.to_f

        skew =
          if oa - od >= DELTA_MARGIN
            "#{opp}'s scouts lean on attacking punch — forwards get serviced."
          elsif od - oa >= DELTA_MARGIN
            "#{opp} lock in through the spine first; they're bred for clean sheets."
          else
            "#{opp} aren't lopsided — danger comes from clever rotation at both ends."
          end

        vs_us = +""
        if oa >= ma + DELTA_MARGIN
          vs_us << " Numerically they've got a sharper forward unit than #{mgr_short} right now."
        elsif ma >= oa + DELTA_MARGIN
          vs_us << " Our front line stacks up bolder on paper if we keep the tempo honest."
        end

        if od >= md + DELTA_MARGIN
          vs_us << " Their rearguard's weighted heavier than ours in the previews."
        elsif md >= od + DELTA_MARGIN
          vs_us << " #{mgr_short}'s defensive steel edges theirs — they'll need flashes of genius."
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
              "#{g} goal#{g == 1 ? '' : 's'} chalked already this campaign"
            else
              "a nose for nuisance in the box"
            end
          +"Train one eye on #{name} — #{goal_phr}, so don't concede silly second balls."
        when :livewire
          +"#{name}'s the live-wire type who drags defenders out of shape — choke their supply early."
        when :enforcer
          +"#{name} tidies transitions from deep; spoil their rhythm there and lanes open up."
        else
          +"#{name}'s flagged on the clipboard."
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
          tougher << "They're sitting above #{mgr_short} in the table "
          tougher <<
            if gap_pts.positive?
              "with breathing room — treat it like a heavyweight round."
            else
              "but only just — nip complacency early and the crowd turns."
            end
          return tougher
        end

        if our_rank < opp_rank
          return +"We start with the league ladder on #{mgr_short}'s collar — pedigree doesn't score goals unless we sharpen the details."
        end

        if gap_pts.zero?
          +"Table neck-and-neck; whoever lands the cleaner moments nicks momentum."
        elsif opp_atk >= our_def + DELTA_MARGIN
          +"Their forward unit can fray us if we're passive — squeeze the midfield and defenders breathe easier."
        else
          +"Could swing fast either way — first goal probably drags them one way mentally."
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
