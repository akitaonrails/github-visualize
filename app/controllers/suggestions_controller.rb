class SuggestionsController < ApplicationController
  LIMIT = 8
  CACHE_TTL = 10.minutes

  def index
    query = params[:q].to_s.strip.downcase
    monitored = Repository.pluck(:owner, :name).map { |owner, name| "#{owner}/#{name}".downcase }.to_set

    candidates = user_repositories.reject { |repo| monitored.include?(repo[:full_name].downcase) }
    suggestions = rank(candidates.select { |repo| matches?(repo, query) }, query)
      .first(LIMIT)
      .map { |repo| repo.merge(display_name: display_name(repo)) }

    render json: suggestions
  rescue Github::Client::Error
    render json: []
  end

  private

  # A repo matches when the query is a substring of its name ("eop"), or a
  # prefix of its owner ("blue3" → BLUE3-ISP's repos). Owner is matched as a
  # prefix, not a substring, so a common owner ("akitaonrails") doesn't match
  # every stray query ("ai"). "owner/name" narrows both segments at once.
  def matches?(repo, query)
    return true if query.blank?

    owner, name = repo[:full_name].downcase.split("/", 2)
    if query.include?("/")
      query_owner, query_name = query.split("/", 2)
      owner.start_with?(query_owner) && name.to_s.include?(query_name)
    else
      name.to_s.include?(query) || owner.start_with?(query)
    end
  end

  # Rank repos matching on the name segment above those matching only on the
  # owner, so typing a repo name surfaces it even when an org shares the text.
  # partition is stable, so each group keeps the pushed-recency order.
  def rank(repos, query)
    return repos if query.blank?

    name_query = query.split("/", 2).last
    name_matches, owner_only = repos.partition { |repo| repo_name(repo).include?(name_query) }
    name_matches + owner_only
  end

  def repo_name(repo)
    repo[:full_name].downcase.split("/", 2).last.to_s
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
