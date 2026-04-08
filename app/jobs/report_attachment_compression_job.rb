class ReportAttachmentCompressionJob < ApplicationJob
  queue_as :default

  def perform(report_attachment_id)
    attachment = ReportAttachment.find_by(id: report_attachment_id)
    return unless attachment

    attachment.compress_image!
  rescue => e
    Rails.logger.error("ReportAttachmentCompressionJob failed for attachment #{report_attachment_id}: #{e.message}")
  end
end
