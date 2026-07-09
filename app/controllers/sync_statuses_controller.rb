class SyncStatusesController < ApplicationController
  def show
    repository = Repository.find_by!(owner: params[:owner], name: params[:name])

    render json: {
      status: repository.sync_status,
      progress: repository.sync_progress,
      error: repository.sync_error,
      commits: repository.commits.count,
      workflow_runs: repository.workflow_runs.count
    }
  end
end
