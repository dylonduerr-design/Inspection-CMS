class AuditLog < ApplicationRecord
  self.table_name = 'activity_logs'

  belongs_to :report
  belongs_to :user

  validates :note, presence: true
end