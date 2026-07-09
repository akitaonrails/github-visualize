class RepositoriesController < ApplicationController
  WINDOWS = [ 15, 42, 60, 90 ].freeze
  DEFAULT_WINDOW = 42

  before_action :set_repository, only: %i[show destroy]

  def show
    @window_days = WINDOWS.include?(params[:days].to_i) ? params[:days].to_i : DEFAULT_WINDOW
    @heatmap = Visualizations::CommitHeatmap.new(@repository, window_days: @window_days).to_h
    @timeline = Visualizations::CommitTimeline.new(@repository, window_days: @window_days).to_h
    @ci_lanes = Visualizations::CiLanes.new(@repository, window_days: @window_days).to_h
  end

  # Bare names are scoped to GITHUB_OWNER; "owner/name" still works.
  # Turbo submissions update the dashboard in place instead of navigating.
  def create
    input = params.expect(:full_name).strip
    owner, name = input.include?("/") ? input.split("/", 2) : [ Repository.default_owner, input ]
    repository = Repository.new(owner: owner&.strip, name: name&.strip)

    if repository.save
      SyncRepositoryJob.perform_later(repository)
      notice = "#{repository.full_name} added — syncing in the background."
      respond_to do |format|
        format.turbo_stream { render_dashboard_update(notice: notice) }
        format.html { redirect_to root_path, notice: notice }
      end
    else
      alert = repository.errors.full_messages.to_sentence
      respond_to do |format|
        format.turbo_stream { render turbo_stream: flash_stream(alert: alert) }
        format.html { redirect_to root_path, alert: alert }
      end
    end
  end

  def destroy
    @repository.destroy!
    redirect_to root_path, notice: "Removed #{@repository.full_name}.", status: :see_other
  end

  private

  def set_repository
    @repository = Repository.find_by!(owner: params[:owner], name: params[:name])
  end

  def render_dashboard_update(notice:)
    overview = Visualizations::RepositoryOverview.new(Repository.all.to_a)
    sort = DashboardController::DEFAULT_SORT

    render turbo_stream: [
      turbo_stream.update("repo-count", Repository.count.to_s),
      turbo_stream.replace("dashboard-content",
                           partial: "dashboard/content",
                           locals: { repositories: overview.sorted(sort), overview: overview, sort: sort }),
      turbo_stream.replace("add-repo-form", partial: "dashboard/add_form"),
      flash_stream(notice: notice)
    ]
  end

  def flash_stream(notice: nil, alert: nil)
    turbo_stream.update("flash", partial: "shared/flash", locals: { notice: notice, alert: alert })
  end
end
