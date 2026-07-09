class Commit < ApplicationRecord
  belongs_to :repository

  validates :sha, presence: true, uniqueness: { scope: :repository_id }
  validates :committed_at, presence: true

  scope :chronological, -> { order(:committed_at) }

  def summary
    message.to_s.strip.truncate(100)
  end
end
