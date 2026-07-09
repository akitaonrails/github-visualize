class SuggestionsController < ApplicationController
  LIMIT = 8
  CACHE_TTL = 10.minutes

  def index
    query = params[:q].to_s.strip.downcase
    monitored = Repository.pluck(:owner, :name).map { |owner, name| "#{owner}/#{name}".downcase }.to_set

    suggestions = user_repositories
      .reject { |repo| monitored.include?(repo[:full_name].downcase) }
      .select { |repo| matches?(repo, query) }
      .first(LIMIT)
      .map { |repo| repo.merge(display_name: display_name(repo)) }

    render json: suggestions
  rescue Github::Client::Error
    render json: []
  end

  private

  # Matches on the repo name segment — the owner prefix would match every
  # repo (e.g. "ai" is a substring of "akitaonrails").
  def matches?(repo, query)
    return true if query.blank?

    owner, name = repo[:full_name].downcase.split("/", 2)
    name.include?(query.delete_prefix("#{owner}/"))
  end

  def display_name(repo)
    owner, name = repo[:full_name].split("/", 2)
    owner == Repository.default_owner ? name : repo[:full_name]
  end

  def user_repositories
    Rails.cache.fetch("github/user_repositories", expires_in: CACHE_TTL) do
      Github::Client.new.user_repositories
    end
  end
end
