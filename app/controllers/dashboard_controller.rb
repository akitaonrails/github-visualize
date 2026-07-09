class DashboardController < ApplicationController
  SORTS = %w[updated_desc updated_asc name_asc name_desc created_desc created_asc].freeze
  DEFAULT_SORT = "updated_desc".freeze # most recently worked on first

  def index
    @sort = SORTS.include?(params[:sort]) ? params[:sort] : DEFAULT_SORT
    @overview = Visualizations::RepositoryOverview.new(Repository.all.to_a)
    @repositories = @overview.sorted(@sort)
  end
end
