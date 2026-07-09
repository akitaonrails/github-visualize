class DashboardController < ApplicationController
  SORTS = %w[updated_desc updated_asc name_asc name_desc created_desc created_asc].freeze
  DEFAULT_SORT = "updated_desc".freeze # most recently worked on first

  def index
    @sort = SORTS.include?(params[:sort]) ? params[:sort] : DEFAULT_SORT
    repositories = Repository.all.to_a
    @overview = Visualizations::RepositoryOverview.new(repositories)
    @repositories = sorted(repositories)
  end

  private

  def sorted(repositories)
    key, direction = @sort.split("_")
    sorted = repositories.sort_by do |repository|
      case key
      when "name" then repository.full_name.downcase
      when "created" then repository.created_at
      else # updated: last commit time, falling back to when the repo was added
        @overview.for(repository).last_committed_at || repository.created_at
      end
    end
    direction == "desc" ? sorted.reverse : sorted
  end
end
