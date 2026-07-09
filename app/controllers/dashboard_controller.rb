class DashboardController < ApplicationController
  def index
    @repositories = Repository.alphabetical.to_a
    @overview = Visualizations::RepositoryOverview.new(@repositories)
  end
end
