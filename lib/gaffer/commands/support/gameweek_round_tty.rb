# frozen_string_literal: true

require_relative "../start_league"
require_relative "../../domain/league_table"
require_relative "../../repositories/league_repository"
require_relative "../../repositories/club_repository"
require_relative "../../repositories/fixture_repository"
require_relative "../../presenters/league_table_tty"
require_relative "../../presenters/league_table_view"
require_relative "gameweek_tactics"

module Gaffer
  module Commands
    module Support
      # Post-round and end-of-season terminal output for gameweek flow.
      module GameweekRoundTty
        module_function

        SUMMARY_BAR_W = 56

        def finalize_already_settled(league:, managed_club_id:, pastel:, out:, prompt:)
          complete_if_still_active(league)
          out.puts pastel.green("Every fixture has a result — season #{league.year} ledger is sealed.")
          print_final_table(league:, managed_club_id:, pastel:, out:)
          offer_next_season(league:, pastel:, out:, prompt:)
          :season_completed
        end

        def print_after_round(
          pastel,
          out,
          summaries:,
          managed_club_id:,
          clubs_by_id:,
          gameweek:,
          league:,
          final_round:,
          manager_shape:
        )
          yours, others = yours_and_others(summaries, managed_club_id, clubs_by_id)
          print_round_header(out, pastel, gameweek, final_round, league)
          print_your_block(out, pastel, yours, clubs_by_id, managed_club_id, manager_shape)
          print_other_lines(out, pastel, others, clubs_by_id)
          out.puts pastel.dim("─" * SUMMARY_BAR_W)
          print_post_match_standings(
            final_round:,
            out:,
            pastel:,
            league_id: league.id,
            league_year: league.year,
            managed_club_id:
          )
          out.puts
        end

        def print_post_match_standings(final_round:, out:, pastel:, league_id:, league_year:, managed_club_id:)
          if final_round
            out.puts pastel.bold.white("Final standings · #{league_year}")
            out.puts Presenters::LeagueTableTty.render_for_season(
              league_id:,
              pastel:,
              managed_club_id:
            )
            out.puts pastel.dim("Season #{league_year} over — trophy cabinet dusted.")
          else
            print_standings_snapshot(out:, pastel:, season_id: league_id, managed_club_id:)
          end
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

        def offer_next_season(league:, pastel:, out:, prompt:)
          tty = prompt_for_offer(prompt)
          return unless tty

          out.puts pastel.dim("#{league.name} · #{league.year} archived in the ledger.")
          next_calendar = Repositories::LeagueRepository.latest_year.to_i + 1
          q = pastel.bold("Start Season #{next_calendar}? ") + pastel.dim("[Y/n]")
          return unless tty.yes?(q, default: true)

          Commands::StartLeague.run(pastel:, out:)
          nil
        end

        def print_full_result(out:, pastel:, summary:, clubs_by_id:, manager_shape:, managed_club_id:)
          fx = summary.fixture
          res = summary.result
          home = clubs_by_id[fx.home_club_id]
          away = clubs_by_id[fx.away_club_id]
          hg = pastel.bold.green(res.home_score.to_s.rjust(2))
          ag = pastel.bold.green(res.away_score.to_s.rjust(2))

          label = GameweekTactics.tactic_label(manager_shape).to_s
          out.puts pastel.dim("Your shape: #{label}")
          out.puts pastel.dim("#{home.name} vs #{away.name}")
          out.puts "  #{pastel.bold(home.name)}  #{hg}#{pastel.dim(" - ")}#{ag}  #{pastel.bold(away.name)}"

          hid = fx.home_club_id.to_i
          aid = fx.away_club_id.to_i
          mid = managed_club_id.to_i
          home_cell = scorer_names_cell(pastel, res.home_scorers, hid == mid && mid.positive?)
          away_cell = scorer_names_cell(pastel, res.away_scorers, aid == mid && mid.positive?)
          out.puts "  #{home_cell}#{pastel.dim("  vs  ")}#{away_cell}"

          out.puts pastel.dim("  λ (expected goals-ish) #{res.home_xg_lambda.round(2)} : #{res.away_xg_lambda.round(2)}")
        end

        def yours_and_others(summaries, managed_club_id, clubs_by_id)
          yours = summaries.find { |s| club_ids_for(s.fixture).include?(managed_club_id) }
          others =
            summaries
              .reject { |s| s.equal?(yours) }
              .sort_by { |s| clubs_by_id[s.fixture.home_club_id].name.to_s.downcase }
          [yours, others]
        end

        def print_round_header(out, pastel, gameweek, final_round, league)
          out.puts
          headline = pastel.bold.white("Gameweek #{gameweek}#{final_round ? " · season closes" : ""}")
          meta = pastel.dim("#{league.name} · #{league.year}")
          out.puts "#{headline}  #{meta}"
          out.puts pastel.dim("─" * SUMMARY_BAR_W)
          out.puts pastel.bold.white("YOUR RESULT")
        end

        def print_your_block(out, pastel, yours, clubs_by_id, managed_club_id, manager_shape)
          if yours
            print_full_result(
              out:, pastel:, summary: yours, clubs_by_id:, manager_shape:, managed_club_id:
            )
          else
            out.puts pastel.red("Could not locate your club in this round — data mismatch.")
          end
        end

        def print_other_lines(out, pastel, others, clubs_by_id)
          return unless others.any?

          out.puts
          out.puts pastel.bold.white("Other scorelines (#{others.size})")
          others.each { |s| out.puts pastel.dim(format_scoreline(s, clubs_by_id)) }
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

        def complete_if_still_active(league)
          return unless Repositories::LeagueRepository.active&.id == league.id

          Repositories::LeagueRepository.complete!(league.id)
        end

        def prompt_for_offer(prompt)
          prompt || tty_prompt_fallback
        end

        def tty_prompt_fallback
          require "tty-prompt"
          TTY::Prompt.new
        rescue LoadError
          nil
        end
      end
    end
  end
end
