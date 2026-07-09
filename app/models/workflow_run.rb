class WorkflowRun < ApplicationRecord
  belongs_to :repository

  validates :github_id, presence: true, uniqueness: { scope: :repository_id }

  scope :chronological, -> { order(:run_started_at) }

  def green?
    conclusion == "success"
  end

  def red?
    %w[failure timed_out startup_failure].include?(conclusion)
  end
end
