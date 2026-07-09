module Visualizations
  # Per-repository stats for the dashboard: daily activity chips,
  # commit totals, and latest CI state — computed in bulk to avoid N+1.
  class RepositoryOverview
    CHIP_DAYS = 21

    Stats = Data.define(:total_commits, :total_additions, :total_deletions,
                        :daily_counts, :max_daily, :ci_conclusion, :last_committed_at)

    def initialize(repositories)
      @repositories = repositories
    end

    def for(repository)
      stats_by_repository_id.fetch(repository.id)
    end

    def chip_dates
      @chip_dates ||= ((CHIP_DAYS - 1).days.ago.to_date..Date.current).to_a
    end

    private

    def stats_by_repository_id
      @stats_by_repository_id ||= @repositories.index_by(&:id).transform_values do |repository|
        daily = daily_counts.fetch(repository.id, {})
        Stats.new(
          total_commits: commit_counts.fetch(repository.id, 0),
          total_additions: addition_sums.fetch(repository.id, 0),
          total_deletions: deletion_sums.fetch(repository.id, 0),
          daily_counts: chip_dates.map { |date| daily.fetch(date, 0) },
          max_daily: daily.values.max || 0,
          ci_conclusion: latest_ci_conclusions[repository.id],
          last_committed_at: last_commit_times[repository.id]
        )
      end
    end

    def commit_counts
      @commit_counts ||= Commit.group(:repository_id).count
    end

    def addition_sums
      @addition_sums ||= Commit.group(:repository_id).sum(:additions)
    end

    def deletion_sums
      @deletion_sums ||= Commit.group(:repository_id).sum(:deletions)
    end

    def daily_counts
      @daily_counts ||= Commit
        .where(committed_at: chip_dates.first.beginning_of_day..)
        .pluck(:repository_id, :committed_at)
        .group_by(&:first)
        .transform_values do |rows|
          rows.map { |row| row[1].in_time_zone.to_date }.tally
        end
    end

    def last_commit_times
      @last_commit_times ||= Commit.group(:repository_id).maximum(:committed_at)
    end

    def latest_ci_conclusions
      @latest_ci_conclusions ||= WorkflowRun
        .where.not(run_started_at: nil)
        .order(:run_started_at)
        .pluck(:repository_id, :conclusion)
        .to_h
    end
  end
end
