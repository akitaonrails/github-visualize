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

  def create
    owner, name = params.expect(:full_name).split("/", 2)
    repository = Repository.new(owner: owner&.strip, name: name&.strip)

    if repository.save
      SyncRepositoryJob.perform_later(repository)
      redirect_to repository_path(owner: repository.owner, name: repository.name),
                  notice: "Repository added. First sync is running in the background."
    else
      redirect_to root_path, alert: repository.errors.full_messages.to_sentence
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
end
