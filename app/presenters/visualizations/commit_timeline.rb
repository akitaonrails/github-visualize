module Visualizations
  # Full-history commit timeline: additions/deletions per time bucket plus a
  # commit log feed, like the "+1,780,453 lines written" replay in the Bun post.
  class CommitTimeline
    BUCKETS = 160
    LOG_SIZE = 150
    WINDOW_DAYS = 42

    def initialize(repository, buckets: BUCKETS, window_days: WINDOW_DAYS)
      @repository = repository
      @bucket_count = buckets
      @window_days = window_days
    end

    def to_h
      return empty if commits.empty?

      first_at = commits.first[0]
      last_at = commits.last[0]
      span = [ last_at - first_at, 1 ].max
      buckets = Array.new(@bucket_count) { { count: 0, additions: 0, deletions: 0 } }

      commits.each do |committed_at, additions, deletions|
        index = [ ((committed_at - first_at) / span * @bucket_count).floor, @bucket_count - 1 ].min
        bucket = buckets[index]
        bucket[:count] += 1
        bucket[:additions] += additions
        bucket[:deletions] += deletions
      end

      peak = buckets.max_by { |bucket| bucket[:count] }

      {
        total_commits: commits.size,
        total_additions: commits.sum { |commit| commit[1] },
        total_deletions: commits.sum { |commit| commit[2] },
        started_at: first_at.in_time_zone.strftime("%b %-d, %Y"),
        ended_at: last_at.in_time_zone.strftime("%b %-d, %Y"),
        peak: "#{peak[:count]} commits in #{duration_label(span / @bucket_count)}",
        buckets: buckets,
        log: log_entries
      }
    end

    private

    def window
      @window_days.days.ago.beginning_of_day..
    end

    def commits
      @commits ||= @repository.commits.where(committed_at: window)
        .chronological.pluck(:committed_at, :additions, :deletions)
    end

    def log_entries
      @repository.commits.where(committed_at: window)
        .order(committed_at: :desc).limit(LOG_SIZE).map do |commit|
        {
          at: commit.committed_at.in_time_zone.strftime("%b %-d %H:%M"),
          message: commit.summary,
          additions: commit.additions,
          deletions: commit.deletions
        }
      end.reverse
    end

    def duration_label(seconds)
      case seconds
      when ...90 then "one minute"
      when ...5400 then "#{(seconds / 60.0).round} minutes"
      when ...129_600 then "#{(seconds / 3600.0).round} hours"
      else "#{(seconds / 86_400.0).round} days"
      end
    end

    def empty
      { total_commits: 0, total_additions: 0, total_deletions: 0,
        started_at: nil, ended_at: nil, peak: nil, buckets: [], log: [] }
    end
  end
end
