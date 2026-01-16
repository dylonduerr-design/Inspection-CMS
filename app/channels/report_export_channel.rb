class ReportExportChannel < ApplicationCable::Channel
  def subscribed
    export = ReportExport.find(params[:export_id])
    
    # Only allow users to subscribe to their own exports
    if export.user_id == current_user&.id
      stream_from "report_export:#{params[:export_id]}"
    else
      reject
    end
  end

  def unsubscribed
    # Any cleanup needed when channel is unsubscribed
  end
end
