import { Controller } from "@hotwired/stimulus"

/**
 * AI Generation Controller
 * 
 * Handles triggering AI generation for work summaries and commentary,
 * polling for status updates, and updating the form fields.
 */
export default class extends Controller {
  static targets = ["workSummaryBtn", "commentaryBtn", "workSummaryField", "commentaryField"]
  static values = { reportId: Number }

  connect() {
    this.pollInterval = null
    this.generationRequestedInSession = false
    this.checkStatus()
  }

  disconnect() {
    this.stopPolling()
  }

  async generateWorkSummary(event) {
    event.preventDefault()
    await this.triggerGeneration('work_summary')
  }

  async generateCommentary(event) {
    event.preventDefault()
    await this.triggerGeneration('commentary')
  }

  async triggerGeneration(intent) {
    const url = intent === 'work_summary' 
      ? `/reports/${this.reportIdValue}/generate_work_summary`
      : `/reports/${this.reportIdValue}/generate_commentary`

    this.setButtonsDisabled(true)
    this.generationRequestedInSession = true
    this.showStatus('⏳ Queuing AI generation...')

    try {
      const response = await fetch(url, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': this.csrfToken
        }
      })

      const data = await response.json()

      if (!response.ok) {
        this.showError(data.error || 'Failed to start generation')
        this.setButtonsDisabled(false)
        return
      }

      this.showStatus('⏳ AI generation in progress...')
      this.startPolling()

    } catch (error) {
      console.error('AI generation error:', error)
      this.showError('Network error. Please try again.')
      this.setButtonsDisabled(false)
    }
  }

  startPolling() {
    this.stopPolling()
    this.pollInterval = setInterval(() => this.checkStatus(), 5000) // 5s interval for LLM tasks
  }

  stopPolling() {
    if (this.pollInterval) {
      clearInterval(this.pollInterval)
      this.pollInterval = null
    }
  }

  async checkStatus() {
    try {
      const response = await fetch(`/reports/${this.reportIdValue}/ai_status`, {
        headers: {
          'Accept': 'application/json'
        }
      })

      if (!response.ok) return

      const data = await response.json()

      if (data.status === 'queued' || data.status === 'running') {
        this.showStatus('⏳ AI generation in progress...')
        if (!this.pollInterval) {
          this.startPolling()
        }
      } else if (data.status === 'success') {
        this.stopPolling()
        this.hideStatus()
        this.setButtonsDisabled(false)
        
        // Update fields with generated content
        if (data.ai_work_summary && this.hasWorkSummaryFieldTarget) {
          this.workSummaryFieldTarget.value = data.ai_work_summary
        }
        if (data.ai_generated_commentary && this.hasCommentaryFieldTarget) {
          this.commentaryFieldTarget.value = data.ai_generated_commentary
        }

        this.showSuccess('✅ AI generation completed!')
        setTimeout(() => this.hideStatus(), 3000)

      } else if (data.status === 'failed') {
        this.stopPolling()
        this.setButtonsDisabled(false)
        if (this.generationRequestedInSession) {
          this.showError(data.ai_error || 'Generation failed')
        } else {
          this.hideStatus()
        }

      } else {
        // idle state
        this.stopPolling()
        this.hideStatus()
        this.setButtonsDisabled(false)
      }

    } catch (error) {
      console.error('Status check error:', error)
    }
  }

  setButtonsDisabled(disabled) {
    if (this.hasWorkSummaryBtnTarget) {
      this.workSummaryBtnTarget.disabled = disabled
    }
    if (this.hasCommentaryBtnTarget) {
      this.commentaryBtnTarget.disabled = disabled
    }
  }

  showStatus(message) {
    const container = document.getElementById('ai-status-container')
    const text = document.getElementById('ai-status-text')
    if (container && text) {
      container.classList.remove('d-none')
      container.querySelector('.alert').className = 'alert alert-info'
      text.textContent = message
    }
  }

  showSuccess(message) {
    const container = document.getElementById('ai-status-container')
    const text = document.getElementById('ai-status-text')
    if (container && text) {
      container.classList.remove('d-none')
      container.querySelector('.alert').className = 'alert alert-success'
      text.textContent = message
    }
  }

  showError(message) {
    const container = document.getElementById('ai-status-container')
    const text = document.getElementById('ai-status-text')
    if (container && text) {
      container.classList.remove('d-none')
      container.querySelector('.alert').className = 'alert alert-danger'
      text.textContent = `❌ Error: ${message}`
    }
  }

  hideStatus() {
    const container = document.getElementById('ai-status-container')
    if (container) {
      container.classList.add('d-none')
    }
  }

  get csrfToken() {
    return document.querySelector('meta[name="csrf-token"]')?.content
  }
}
