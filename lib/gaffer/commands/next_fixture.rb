# frozen_string_literal: true

require "pastel"

module Gaffer
  module Commands
    # Runs every fixture in the current gameweek for the active league (your XI match with flair,
    # everything else muted), persists results, advances `current_gameweek` (Step 5), and wraps the
    # campaign (Step 7): final round prints full tty standings, confirms `LeagueRepository.complete!`,
    # then prompts `Start Season [year+1]? [Y/n]` → `StartLeague`.
    module NextFixture
      SUMMARY_BAR_W = 56

      Summary = Struct.new(:fixture, :result, keyword_init: true)

      class << self
        # @param pastel [Pastel]
        # @param out [IO]
        # @param prompt [#yes?,nil] end-of-season `TTY::Prompt` from the interactive menu when available.
        #
        # @return [Symbol] `:ok`, `:no_active_league`, `:no_manager`, `:squads_incomplete`,
        #   `:fixture_data_error`, or `:season_completed`
        def run(pastel: Pastel.new, out: $stdout, prompt: nil)
          ensure_db_connected

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

          engine = Domain::MatchEngine.new
          summaries = []

          Gaffer::Database.db.transaction do
            round_fixtures.each do |fx|
              result = simulate_with_squads(fx:, clubs_by_id:, engine:, seed: fx.id.to_i)
              Repositories::MatchRepository.save(build_match(fixture_id: fx.id, result:))
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
            final_round: final_round
          )

          offer_next_season(league:, pastel:, out:, prompt:) if final_round

          final_round ? :season_completed : :ok
        rescue KeyError => e
          out.puts pastel.red("Squads incomplete for this gameweek (#{e.message}). Run db:seed.")
          :squads_incomplete
        end

        private

        def ensure_db_connected
          Gaffer::Database.connect
          Gaffer::Database.migrate
        end

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

        def simulate_with_squads(fx:, clubs_by_id:, engine:, seed:)
          home_club = clubs_by_id.fetch(fx.home_club_id)
          away_club = clubs_by_id.fetch(fx.away_club_id)
          home_players = Repositories::PlayerRepository.for_club(home_club.id)
          away_players = Repositories::PlayerRepository.for_club(away_club.id)

          raise KeyError, "home squad empty" if home_players.empty?
          raise KeyError, "away squad empty" if away_players.empty?

          engine.simulate(
            home_club: home_club,
            home_players: home_players,
            away_club: away_club,
            away_players: away_players,
            home_tactic: :balanced,
            away_tactic: :balanced,
            seed: seed
          )
        end

        def print_after_play(pastel, out, summaries:, managed_club_id:, clubs_by_id:, gameweek:, league:, final_round:)
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
            print_full_result(out:, pastel:, summary: yours, clubs_by_id:)
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

        def print_full_result(out:, pastel:, summary:, clubs_by_id:)
          fx = summary.fixture
          res = summary.result
          home = clubs_by_id[fx.home_club_id]
          away = clubs_by_id[fx.away_club_id]
          hg = pastel.bold.green(res.home_score.to_s.rjust(2))
          ag = pastel.bold.green(res.away_score.to_s.rjust(2))

          out.puts pastel.dim("#{home.name} vs #{away.name}")
          out.puts "  #{pastel.bold(home.name)}  #{hg}#{pastel.dim(" - ")}#{ag}  #{pastel.bold(away.name)}"
          out.puts pastel.dim("  λ (expected goals-ish) #{res.home_xg_lambda.round(2)} : #{res.away_xg_lambda.round(2)}")
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
      end
    end
  end
end
