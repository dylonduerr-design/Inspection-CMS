import { Controller } from "@hotwired/stimulus"
import { subscribeToExport } from "../channels/report_export_channel"

// Connects to data-controller="report-export"
export default class extends Controller {
  static targets = ["button", "progress", "progressBar", "progressText", "message", "download"]
  static values = { reportId: Number }

  connect() {
    console.log("ReportExport controller connected")
  }

  startExport(event) {
    event.preventDefault()
    
    // Hide button, show progress
    this.buttonTarget.classList.add("d-none")
    this.progressTarget.classList.remove("d-none")
    
    // Start the export
    fetch(`/reports/${this.reportIdValue}/start_export`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
      }
    })
    .then(response => response.json())
    .then(data => {
      console.log("Export started:", data)
      this.subscribeToProgress(data.export_id)
    })
    .catch(error => {
      console.error("Error starting export:", error)
      this.showError("Failed to start export. Please try again.")
    })
  }

  subscribeToProgress(exportId) {
    this.subscription = subscribeToExport(exportId, {
      received: (data) => {
        console.log("Progress update:", data)
        
        if (data.status === 'failed') {
          this.showError(data.error || "Export failed")
        } else if (data.status === 'completed') {
          this.showComplete(exportId)
        } else {
          this.updateProgress(data.progress, data.message)
        }
      }
    })
  }

  updateProgress(percent, message) {
    this.progressBarTarget.style.width = `${percent}%`
    this.progressBarTarget.setAttribute('aria-valuenow', percent)
    this.progressTextTarget.textContent = `${percent}%`
    
    if (message) {
      this.messageTarget.textContent = message
    }
  }

  showComplete(exportId) {
    this.updateProgress(100, "Export completed!")
    
    // Show download button
    setTimeout(() => {
      this.progressTarget.classList.add("d-none")
      this.downloadTarget.classList.remove("d-none")
      
      // Set the download URL
      const downloadLink = this.downloadTarget.querySelector('a')
      if (downloadLink) {
        downloadLink.href = `/reports/${this.reportIdValue}/report_exports/${exportId}/download`
      }
    }, 500)
    
    // Unsubscribe from channel
    if (this.subscription) {
      this.subscription.unsubscribe()
    }
  }

  showError(errorMessage) {
    this.progressTarget.classList.remove("d-none")
    this.progressBarTarget.style.width = "0%"
    this.progressBarTarget.classList.remove("progress-bar-animated")
    this.messageTarget.textContent = `Error: ${errorMessage}`
    this.messageTarget.classList.remove("text-muted")
    this.messageTarget.classList.add("text-danger")
    this.buttonTarget.classList.remove("d-none")
    this.buttonTarget.textContent = "Retry Export"
    this.downloadTarget.classList.add("d-none")
    
    // Unsubscribe from channel
    if (this.subscription) {
      this.subscription.unsubscribe()
    }
  }

  disconnect() {
    // Clean up subscription when controller disconnects
    if (this.subscription) {
      this.subscription.unsubscribe()
    }
  }
}
