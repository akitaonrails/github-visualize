class Repository < ApplicationRecord
  SYNC_STATUSES = %w[pending syncing synced failed].freeze
  # Owner/name become path segments in GitHub API URLs; "." and ".." are
  # excluded so a crafted value can never traverse the request path.
  NAME_FORMAT = /\A(?!\.{1,2}\z)[\w.-]+\z/

  has_many :commits, dependent: :delete_all
  has_many :workflow_runs, dependent: :delete_all

  validates :owner, presence: true, format: { with: NAME_FORMAT }
  validates :name, presence: true, format: { with: NAME_FORMAT },
                   uniqueness: { scope: :owner, case_sensitive: false }
  validates :sync_status, inclusion: { in: SYNC_STATUSES }

  # Owner used for bare repo names in the add form and its autocomplete.
  def self.default_owner
    ENV["GITHUB_OWNER"].presence
  end

  def full_name
    "#{owner}/#{name}"
  end

  def github_url
    "https://github.com/#{full_name}"
  end

  def syncing?
    sync_status == "syncing"
  end

  def start_sync!
    update!(sync_status: "syncing", sync_error: nil, sync_progress: "starting")
  end

  def finish_sync!
    update!(sync_status: "synced", sync_error: nil, sync_progress: nil, last_synced_at: Time.current)
  end

  def fail_sync!(error)
    update!(sync_status: "failed", sync_error: error.to_s.truncate(500), sync_progress: nil)
  end
end
