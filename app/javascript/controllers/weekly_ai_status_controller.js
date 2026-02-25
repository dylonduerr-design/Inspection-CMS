import { Controller } from "@hotwired/stimulus"

/**
 * Weekly AI Status Controller
 *
 * Polls the weekly report ai_status endpoint and reloads the page
 * when AI generation completes (or fails).
 */
export default class extends Controller {
  static values = { weeklyReportId: Number, aiStatus: String }

  connect() {
    this.pollInterval = null
    if (this.shouldPoll()) {
      this.startPolling()
    }
  }

  disconnect() {
    this.stopPolling()
  }

  shouldPoll() {
    return this.aiStatusValue === 'queued' || this.aiStatusValue === 'running'
  }

  startPolling() {
    this.stopPolling()
    this.pollInterval = setInterval(() => this.checkStatus(), 4000)
  }

  stopPolling() {
    if (this.pollInterval) {
      clearInterval(this.pollInterval)
      this.pollInterval = null
    }
  }

  async checkStatus() {
    try {
      const response = await fetch(`/weekly_reports/${this.weeklyReportIdValue}/ai_status`, {
        headers: { 'Accept': 'application/json' }
      })

      if (!response.ok) return

      const data = await response.json()

      if (data.ai_status === 'success' || data.ai_status === 'failed') {
        this.stopPolling()
        // Reload the page to show populated sections
        window.location.reload()
      }
    } catch (error) {
      console.error('[WeeklyAiStatus] Poll error:', error)
    }
  }
}
