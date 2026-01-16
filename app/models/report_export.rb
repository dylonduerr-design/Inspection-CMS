class ReportExport < ApplicationRecord
  belongs_to :report
  belongs_to :user
  
  has_one_attached :file
  
  # Status values: queued, running, completed, failed
  validates :status, presence: true, inclusion: { in: %w[queued running completed failed] }
  validates :progress, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
  
  scope :recent, -> { order(created_at: :desc) }
  scope :for_user, ->(user) { where(user: user) }
  
  def broadcast_progress(progress_value, message = nil)
    update!(progress: progress_value)
    ActionCable.server.broadcast(
      "report_export:#{id}",
      {
        export_id: id,
        progress: progress_value,
        status: status,
        message: message
      }
    )
  end
  
  def mark_completed!
    update!(status: 'completed', progress: 100)
    broadcast_progress(100, 'Export completed')
  end
  
  def mark_failed!(error)
    update!(status: 'failed', error_message: error)
    ActionCable.server.broadcast(
      "report_export:#{id}",
      {
        export_id: id,
        status: 'failed',
        error: error
      }
    )
  end
end
