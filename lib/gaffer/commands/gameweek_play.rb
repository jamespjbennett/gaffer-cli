# frozen_string_literal: true

require "pastel"

require_relative "start_league"
require_relative "../domain/lineup"
require_relative "support/scout_report_builder"
require_relative "../ui/dugout_lineup"
require_relative "../presenters/scout_briefing_tty"
require_relative "../presenters/league_table_tty"
require_relative "../presenters/league_table_view"

module Gaffer
  module Commands
    # One full league round: validate schedule and squads, scout → dugout → tactic,
    # simulate and persist every fixture in the gameweek, then post-round TTY and
    # optional next-season offer. Assumes SQLite is already connected (and migrated).
    module GameweekPlay
      SUMMARY_BAR_W = 56

      Summary = Struct.new(:fixture, :result, keyword_init: true)

      # Rows for `TTY::Prompt#select` — labels must mirror `Domain::MatchEngine::TACTIC_MODIFIERS` keys.
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

      class << self
        # @param pastel [Pastel]
        # @param out [IO]
        # @param prompt [#yes?, #select, nil] interactive TTY from the menu where available.
        # @param manager_tactic [Symbol, nil] when set (e.g. tests), skips the tactic menu and uses this shape.
        # @param manager_lineup [Array<Domain::Player>, nil] eleven players from your club to skip dugout UI & validation
        # @return [Symbol] `:ok`, `:no_active_league`, `:no_manager`, `:squads_incomplete`,
        #   `:fixture_data_error`, or `:season_completed`
        def run(pastel:, out:, prompt: nil, manager_tactic: nil, manager_lineup: nil)
          league = Repositories::LeagueRepository.active
          unless league
            out.puts pastel.dim("There is no active league — choose “Start new season” from the menu.")
            return :no_active_league
          end

          manager = Repositories::ManagerRepository.current
          managed_club_id = manager&.managed_club_id.to_i

          unless manager && managed_club_id.positive?
            out.puts pastel.red("No manager profile — complete onboarding first.")
            return :no_manager
          end

          clubs = Repositories::ClubRepository.for_league(league.id)
          if clubs.empty?
            out.puts pastel.red("No clubs linked to this league.")
            return :fixture_data_error
          end

          clubs_by_id = clubs.each_with_object({}) { |c, h| h[c.id] = c }
          managed_next = Repositories::FixtureRepository.next_for_club(season_id: league.id, club_id: managed_club_id)

          unless managed_next
            return finish_already_settled(league, managed_club_id, pastel, out, prompt) if schedule_exhausted?(league.id)

            remaining = Repositories::FixtureRepository.unplayed_count(league.id)
            out.puts pastel.red("#{remaining} unplayed fixtures remain but none involve your squad — corrupt schedule.")
            return :fixture_data_error
          end

          gameweek = managed_next.gameweek.to_i
          round_fixtures = Repositories::FixtureRepository.for_season_and_gameweek(season_id: league.id, gameweek:)

          unless round_fixtures.any?
            out.puts pastel.red("Gameweek #{gameweek} scheduled nothing in SQLite.")
            return :fixture_data_error
          end

          if round_fixtures.any?(&:played?)
            out.puts pastel.red("Gameweek #{gameweek} partially played — refusing to rewind.")
            return :fixture_data_error
          end

          max_gw = Repositories::FixtureRepository.max_gameweek(league.id)
          if max_gw <= 0
            out.puts pastel.red("Fixture list empty for this league.")
            return :fixture_data_error
          end

          full_squad = Repositories::PlayerRepository.for_club(managed_club_id)

          if full_squad.empty?
            out.puts pastel.red("Your club has zero players loaded — rerun db seed.")
            return :squads_incomplete
          end

          suggested = Domain::Lineup.pick_best_xi(full_squad)
          if suggested.size != 11
            out.puts pastel.red("Not enough registered players (#{full_squad.size}) to stitch an XI.")
            return :squads_incomplete
          end

          mid_tmp = managed_club_id.to_i
          opp_id_tmp =
            managed_next.home_club_id.to_i == mid_tmp ? managed_next.away_club_id : managed_next.home_club_id
          opp_name_short = clubs_by_id.fetch(opp_id_tmp.to_i).name.to_s.strip
          hosting_tmp = managed_next.home_club_id.to_i == mid_tmp

          managed_club = clubs_by_id.fetch(managed_club_id)

          scout_report =
            Support::ScoutReportBuilder.build(
              opponent_club: clubs_by_id.fetch(opp_id_tmp.to_i),
              managed_club: managed_club,
              league_id: league.id,
              gameweek: gameweek,
              hosting_managed: hosting_tmp
            )

          Presenters::ScoutBriefingTty.present(scout_report, pastel: pastel, out: out, prompt: prompt)

          user_xi =
            Ui::DugoutLineup.resolve(
              preset: manager_lineup,
              suggested_xi: suggested,
              full_squad: full_squad,
              club: managed_club,
              prompt: prompt,
              pastel: pastel,
              out: out,
              gameweek: gameweek,
              opponent: opp_name_short,
              hosting: hosting_tmp
            )

          unless user_xi&.size == 11
            out.puts pastel.red("Pick a legal XI (11 outfield + keeper distribution) before kicking off.")
            return :squads_incomplete
          end

          manager_shape =
            resolve_manager_shape(
              manager_tactic:, prompt:, pastel:, out:,
              managed_fixture: managed_next, clubs_by_id:, managed_club_id:
            )

          engine = Domain::MatchEngine.new
          summaries = []

          Gaffer::Database.db.transaction do
            round_fixtures.each do |fx|
              home_tac, away_tac = tactics_pair_for(fixture: fx, managed_id: managed_club_id, shape: manager_shape)
              result = simulate_with_squads(
                fx:, clubs_by_id:, engine:, seed: fx.id.to_i,
                home_tactic: home_tac, away_tactic: away_tac,
                managed_club_id:, managed_xi: user_xi
              )
              Repositories::MatchRepository.save(build_match(fixture_id: fx.id, result:))
              Repositories::GoalEventRepository.save_batch(goal_events_for_fixture(fx, result))
              Repositories::FixtureRepository.save(fixture_played(fx))
              summaries << Summary.new(fixture: fx, result:)
            end

            Repositories::LeagueRepository.save(
              Domain::League.new(
                id: league.id,
                name: league.name,
                year: league.year,
                status: gameweek >= max_gw ? :complete : :active,
                current_gameweek: gameweek + 1
              )
            )
            Repositories::LeagueRepository.complete!(league.id) if gameweek >= max_gw
          end

          final_round = gameweek >= max_gw

          print_after_play(
            pastel, out,
            summaries: summaries,
            managed_club_id: managed_club_id,
            clubs_by_id: clubs_by_id,
            gameweek: gameweek,
            league: league,
            final_round: final_round,
            manager_shape: manager_shape
          )

          offer_next_season(league:, pastel:, out:, prompt:) if final_round

          final_round ? :season_completed : :ok
        rescue KeyError => e
          out.puts pastel.red("Squads incomplete for this gameweek (#{e.message}). Run db:seed.")
          :squads_incomplete
        end

        private

        def schedule_exhausted?(league_id)
          Repositories::FixtureRepository.unplayed_count(league_id).zero?
        end

        def finish_already_settled(league, managed_club_id, pastel, out, prompt)
          if Repositories::LeagueRepository.active&.id == league.id
            Repositories::LeagueRepository.complete!(league.id)
          end

          out.puts pastel.green("Every fixture has a result — season #{league.year} ledger is sealed.")
          print_final_table(league:, managed_club_id:, pastel:, out:)

          offer_next_season(league:, pastel:, out:, prompt: prompt)

          :season_completed
        end

        def fixture_played(fx)
          Domain::Fixture.new(
            id: fx.id,
            season_id: fx.season_id,
            gameweek: fx.gameweek,
            home_club_id: fx.home_club_id,
            away_club_id: fx.away_club_id,
            played: true
          )
        end

        def goal_events_for_fixture(fx, result)
          hid = fx.home_club_id.to_i
          aid = fx.away_club_id.to_i
          fid = fx.id.to_i

          home =
            result.home_scorers.filter_map do |p|
              pid = p&.id.to_i
              next if pid <= 0

              Domain::GoalEvent.new(id: nil, fixture_id: fid, player_id: pid, club_id: hid, side: "home")
            end
          away =
            result.away_scorers.filter_map do |p|
              pid = p&.id.to_i
              next if pid <= 0

              Domain::GoalEvent.new(id: nil, fixture_id: fid, player_id: pid, club_id: aid, side: "away")
            end

          home + away
        end

        def build_match(fixture_id:, result:)
          Domain::Match.new(
            id: nil,
            fixture_id: fixture_id.to_i,
            home_score: result.home_score,
            away_score: result.away_score,
            home_possession: nil,
            home_shots: nil,
            home_shots_ot: nil,
            away_shots: nil,
            away_shots_ot: nil,
            events: [],
            player_ratings: {},
            narrative: nil
          )
        end

        def simulate_with_squads(fx:, clubs_by_id:, engine:, seed:, home_tactic:, away_tactic:, managed_club_id:, managed_xi:)
          home_club = clubs_by_id.fetch(fx.home_club_id)
          away_club = clubs_by_id.fetch(fx.away_club_id)

          hid = fx.home_club_id.to_i
          aid = fx.away_club_id.to_i
          mid = managed_club_id.to_i

          home_full = Repositories::PlayerRepository.for_club(hid)
          away_full = Repositories::PlayerRepository.for_club(aid)

          raise KeyError, "home XI empty" if home_full.empty?
          raise KeyError, "away XI empty" if away_full.empty?

          home_pick =
            hid == mid ? managed_xi : Domain::Lineup.pick_best_xi(home_full)
          away_pick =
            aid == mid ? managed_xi : Domain::Lineup.pick_best_xi(away_full)

          unless home_pick.size == 11 && away_pick.size == 11
            raise KeyError, "XI must be eleven each side"
          end

          engine.simulate(
            home_club: home_club,
            home_players: home_pick,
            away_club: away_club,
            away_players: away_pick,
            home_tactic: home_tactic,
            away_tactic: away_tactic,
            seed: seed
          )
        end

        # @return [Symbol] validated tactic consumed by MatchEngine for *your* side this gameweek
        def coerce_manager_shape(raw)
          return :balanced if raw.nil?

          sym = raw.respond_to?(:to_sym) ? raw.to_sym : :balanced
          Domain::MatchEngine::TACTIC_MODIFIERS.key?(sym) ? sym : :balanced
        end

        def resolve_manager_shape(manager_tactic:, prompt:, pastel:, out:, managed_fixture:, clubs_by_id:, managed_club_id:)
          return coerce_manager_shape(manager_tactic) unless manager_tactic.nil?

          return :balanced unless prompt.respond_to?(:select)

          mid = managed_club_id.to_i
          opp_id =
            managed_fixture.home_club_id.to_i == mid ? managed_fixture.away_club_id : managed_fixture.home_club_id
          opp_name = clubs_by_id.fetch(opp_id).name.to_s.strip
          home_or_away =
            managed_fixture.home_club_id.to_i == mid ? "Hosting" : "Visiting"

          banner = +"#{pastel.bold("Pick your tactical shape")}"
          banner << pastel.dim("  · #{home_or_away} #{opp_name}")
          out.puts
          sel = prompt.select(
            banner,
            APPROACH_CHOICES.map { |label, sym| { name: label, value: sym } }
          )

          coerce_manager_shape(sel)
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

        def print_after_play(pastel, out, summaries:, managed_club_id:, clubs_by_id:, gameweek:, league:, final_round:, manager_shape: :balanced)
          yours = summaries.find { |s| club_ids_for(s.fixture).include?(managed_club_id) }
          others =
            summaries
              .reject { |s| s.equal?(yours) }
              .sort_by { |s| clubs_by_id[s.fixture.home_club_id].name.to_s.downcase }

          out.puts
          headline = pastel.bold.white("Gameweek #{gameweek}#{final_round ? " · season closes" : ""}")
          meta = pastel.dim("#{league.name} · #{league.year}")
          out.puts "#{headline}  #{meta}"
          out.puts pastel.dim("─" * SUMMARY_BAR_W)
          out.puts pastel.bold.white("YOUR RESULT")
          if yours
            print_full_result(
              out:, pastel:, summary: yours, clubs_by_id:, manager_shape: manager_shape,
              managed_club_id: managed_club_id
            )
          else
            out.puts pastel.red("Could not locate your club in this round — data mismatch.")
          end

          if others.any?
            out.puts
            out.puts pastel.bold.white("Other scorelines (#{others.size})")
            others.each do |s|
              out.puts pastel.dim(format_scoreline(s, clubs_by_id))
            end
          end

          out.puts pastel.dim("─" * SUMMARY_BAR_W)

          print_post_match_standings(
            final_round: final_round,
            out: out,
            pastel: pastel,
            league_id: league.id,
            league_year: league.year,
            managed_club_id: managed_club_id
          )

          out.puts
        end

        def print_post_match_standings(final_round:, out:, pastel:, league_id:, league_year:, managed_club_id:)
          if final_round
            out.puts pastel.bold.white("Final standings · #{league_year}")
            out.puts Presenters::LeagueTableTty.render_for_season(
              league_id: league_id,
              pastel: pastel,
              managed_club_id: managed_club_id
            )
            out.puts pastel.dim("Season #{league_year} over — trophy cabinet dusted.")
          else
            print_standings_snapshot(out:, pastel:, season_id: league_id, managed_club_id:)
          end
        end

        def print_full_result(out:, pastel:, summary:, clubs_by_id:, manager_shape: :balanced, managed_club_id:)
          fx = summary.fixture
          res = summary.result
          home = clubs_by_id[fx.home_club_id]
          away = clubs_by_id[fx.away_club_id]
          hg = pastel.bold.green(res.home_score.to_s.rjust(2))
          ag = pastel.bold.green(res.away_score.to_s.rjust(2))

          label = tactic_label(manager_shape).to_s
          out.puts pastel.dim("Your shape: #{label}")
          out.puts pastel.dim("#{home.name} vs #{away.name}")
          out.puts "  #{pastel.bold(home.name)}  #{hg}#{pastel.dim(" - ")}#{ag}  #{pastel.bold(away.name)}"

          mid = managed_club_id.to_i
          hid = fx.home_club_id.to_i
          aid = fx.away_club_id.to_i
          home_hi = mid.positive? && hid == mid
          away_hi = mid.positive? && aid == mid
          home_cell = scorer_names_cell(pastel, res.home_scorers, home_hi)
          away_cell = scorer_names_cell(pastel, res.away_scorers, away_hi)
          out.puts "  #{home_cell}#{pastel.dim("  vs  ")}#{away_cell}"

          out.puts pastel.dim("  λ (expected goals-ish) #{res.home_xg_lambda.round(2)} : #{res.away_xg_lambda.round(2)}")
        end

        def scorer_names_cell(pastel, players, highlight)
          return pastel.dim("—") if players.nil? || players.empty?

          text = players.map { |p| p.name.to_s.strip }.join(", ")
          highlight ? pastel.bold(text) : pastel.dim(text)
        end

        def format_scoreline(summary, clubs_by_id)
          fx = summary.fixture
          res = summary.result
          h = clubs_by_id[fx.home_club_id]&.short_name.to_s
          a = clubs_by_id[fx.away_club_id]&.short_name.to_s
          "#{h} #{res.home_score}–#{res.away_score} #{a}"
        end

        def club_ids_for(fx)
          [fx.home_club_id.to_i, fx.away_club_id.to_i]
        end

        def print_standings_snapshot(out:, pastel:, season_id:, managed_club_id:)
          clubs = Repositories::ClubRepository.for_league(season_id)
          results = Repositories::FixtureRepository.settled_scores_for_season(season_id)
          rows = Domain::LeagueTable.standings_for(clubs:, results: results)
          pos = Domain::LeagueTable.positions_by_club(rows)
          Presenters::LeagueTableView.print_snippet(out:, pastel:, rows:, positions_by_club: pos, managed_club_id:)
        end

        def print_final_table(league:, managed_club_id:, pastel:, out:)
          out.puts pastel.bold.white("Final standings · #{league.year}")
          out.puts Presenters::LeagueTableTty.render_for_season(
            league_id: league.id,
            pastel: pastel,
            managed_club_id: managed_club_id
          )
          out.puts
        end

        # Step 7: default **Yes** on [Y/n] — declining returns to caller (menu resumes).
        def offer_next_season(league:, pastel:, out:, prompt:)
          tty =
            prompt || begin
              require "tty-prompt"
              TTY::Prompt.new
            rescue LoadError
              nil
            end

          return unless tty

          out.puts pastel.dim("#{league.name} · #{league.year} archived in the ledger.")
          next_calendar = Repositories::LeagueRepository.latest_year.to_i + 1
          q = pastel.bold("Start Season #{next_calendar}? ") + pastel.dim("[Y/n]")
          return unless tty.yes?(q, default: true)

          Commands::StartLeague.run(pastel:, out:)
          nil
        end

        def tactic_label(sym)
          TACTIC_HEADLINE.fetch(coerce_manager_shape(sym))
        end
      end
    end
  end
end
