module ApplicationHelper
  # Purple-to-yellow heat ramp shared with the canvas charts
  # (keep in sync with the JS ramp in heatmap_controller.js).
  HEAT_STOPS = [
    [ 45, 27, 78 ], [ 126, 34, 206 ], [ 192, 38, 211 ],
    [ 236, 72, 153 ], [ 249, 115, 22 ], [ 250, 204, 21 ]
  ].freeze
  HEAT_EMPTY = "#17131f".freeze

  def heat_color(value, max)
    return HEAT_EMPTY if value.zero? || max.zero?

    t = Math.sqrt(value.to_f / max) * (HEAT_STOPS.size - 1)
    index = [ t.floor, HEAT_STOPS.size - 2 ].min
    fraction = t - index
    channels = HEAT_STOPS[index].zip(HEAT_STOPS[index + 1]).map do |from, to|
      (from + (to - from) * fraction).round
    end
    format("#%02x%02x%02x", *channels)
  end

  # Owner shown next to the app title: GITHUB_OWNER, or the token's login.
  def configured_github_owner
    Repository.default_owner || token_login
  end

  # The owner is already scoped app-wide (header badge), so repos belonging
  # to it render as bare names; foreign repos keep the owner/ prefix.
  def repository_display_name(repository)
    repository.owner == configured_github_owner ? repository.name : repository.full_name
  end

  def token_login
    return if ENV["GITHUB_TOKEN"].blank?

    Rails.cache.fetch("github/token_login", expires_in: 1.hour) do
      Github::Client.new.authenticated_login
    end
  rescue Github::Client::Error
    nil
  end

  def ci_dot_class(conclusion)
    case conclusion
    when "success" then "bg-emerald-400"
    when "failure", "timed_out", "startup_failure" then "bg-red-500"
    when nil then "bg-neutral-700"
    else "bg-amber-400"
    end
  end

  def sync_status_class(status)
    case status
    when "synced" then "text-emerald-400 border-emerald-900"
    when "syncing" then "text-amber-300 border-amber-900"
    when "failed" then "text-red-400 border-red-900"
    else "text-neutral-400 border-neutral-700"
    end
  end
end
