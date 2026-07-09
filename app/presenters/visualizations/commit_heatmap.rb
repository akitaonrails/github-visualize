module Visualizations
  # Day-by-hour commit heatmap, like the "6,502 commits" grid in the Bun post.
  class CommitHeatmap
    WINDOW_DAYS = 42

    def initialize(repository, window_days: WINDOW_DAYS)
      @repository = repository
      @window_days = window_days
    end

    def to_h
      counts = Hash.new(0)
      times.each do |time|
        local = time.in_time_zone
        counts[[ local.to_date, local.hour ]] += 1
      end

      first_day = counts.keys.map(&:first).min
      rows = (first_day..Date.current).map do |date|
        {
          label: date.strftime("%b %-d"),
          counts: (0..23).map { |hour| counts[[ date, hour ]] }
        }
      end if first_day

      {
        total: times.size,
        max: counts.values.max || 0,
        rows: rows || []
      }
    end

    private

    def times
      @times ||= @repository.commits
        .where(committed_at: @window_days.days.ago.beginning_of_day..)
        .pluck(:committed_at)
    end
  end
end
