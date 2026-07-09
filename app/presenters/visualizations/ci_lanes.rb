module Visualizations
  # One lane per workflow with a tick per run, like the
  # "race to green, by platform" chart in the Bun post.
  class CiLanes
    WINDOW_DAYS = 42

    def initialize(repository, window_days: WINDOW_DAYS)
      @repository = repository
      @window_days = window_days
    end

    def to_h
      lanes = runs.group_by(&:workflow_name).sort.map do |name, workflow_runs|
        {
          name: name,
          green: workflow_runs.last.green?,
          runs: workflow_runs.map do |run|
            { t: run.run_started_at.to_i * 1000, state: state_for(run) }
          end
        }
      end

      {
        lanes: lanes,
        green_lanes: lanes.count { |lane| lane[:green] },
        total_lanes: lanes.size,
        from: runs.first&.run_started_at&.then { |time| time.to_i * 1000 },
        to: runs.last&.run_started_at&.then { |time| time.to_i * 1000 },
        from_label: runs.first&.run_started_at&.in_time_zone&.strftime("%b %-d"),
        to_label: runs.last&.run_started_at&.in_time_zone&.strftime("%b %-d")
      }
    end

    private

    def runs
      @runs ||= @repository.workflow_runs
        .where(run_started_at: @window_days.days.ago.beginning_of_day..)
        .chronological.to_a
    end

    def state_for(run)
      if run.green? then "green"
      elsif run.red? then "red"
      else "other"
      end
    end
  end
end
