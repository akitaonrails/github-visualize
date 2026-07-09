class SyncsController < ApplicationController
  def create
    repository = Repository.find_by!(owner: params[:owner], name: params[:name])
    SyncRepositoryJob.perform_later(repository)
    redirect_to repository_path(owner: repository.owner, name: repository.name),
                notice: "Sync queued for #{repository.full_name}."
  end
end
