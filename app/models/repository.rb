class Repository < ApplicationRecord
  SYNC_STATUSES = %w[pending syncing synced failed].freeze
  NAME_FORMAT = /\A[\w.-]+\z/

  has_many :commits, dependent: :delete_all
  has_many :workflow_runs, dependent: :delete_all

  validates :owner, presence: true, format: { with: NAME_FORMAT }
  validates :name, presence: true, format: { with: NAME_FORMAT },
                   uniqueness: { scope: :owner, case_sensitive: false }
  validates :sync_status, inclusion: { in: SYNC_STATUSES }

  scope :alphabetical, -> { order(:owner, :name) }

  def self.find_by_full_name!(full_name)
    owner, name = full_name.to_s.split("/", 2)
    find_by!(owner: owner, name: name)
  end

  def full_name
    "#{owner}/#{name}"
  end

  def to_param
    full_name
  end

  def github_url
    "https://github.com/#{full_name}"
  end

  def syncing?
    sync_status == "syncing"
  end

  def start_sync!
    update!(sync_status: "syncing", sync_error: nil)
  end

  def finish_sync!
    update!(sync_status: "synced", sync_error: nil, last_synced_at: Time.current)
  end

  def fail_sync!(error)
    update!(sync_status: "failed", sync_error: error.to_s.truncate(500))
  end
end
