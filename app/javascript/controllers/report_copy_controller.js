import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["modal", "inspector", "date", "reportSelect", "copyButton", "statusText"]

  static values = {
    candidatesUrl: String,
    newReportUrl: String,
    projectId: String
  }

  connect() {
    if (this.hasModalTarget) {
      this.modalTarget.hidden = true
    }
    this.toggleCopyButton()
  }

  open() {
    if (!this.hasModalTarget) return
    this.modalTarget.hidden = false
    document.body.style.overflow = "hidden"
  }

  close() {
    if (!this.hasModalTarget) return
    this.modalTarget.hidden = true
    document.body.style.overflow = ""
  }

  backdropClick(event) {
    if (event.target === this.modalTarget) this.close()
  }

  stopPropagation(event) {
    event.stopPropagation()
  }

  async loadCandidates() {
    if (!this.hasInspectorTarget || !this.hasDateTarget || !this.hasReportSelectTarget) return

    const inspectorId = (this.inspectorTarget.value || "").trim()
    const date = (this.dateTarget.value || "").trim()

    if (!this.projectIdValue) {
      this.setStatus("Select a project first to copy from past reports.")
      this.resetOptions("Project is required")
      return
    }

    if (!inspectorId || !date) {
      this.resetOptions("Select inspector and date first")
      this.setStatus("Choose inspector and date to find matching reports.")
      return
    }

    this.resetOptions("Loading reports...")
    this.setStatus("Searching for matching reports...")

    const query = new URLSearchParams({
      project_id: this.projectIdValue,
      inspector_id: inspectorId,
      date: date
    })

    try {
      const response = await fetch(`${this.candidatesUrlValue}?${query.toString()}`, {
        headers: { "Accept": "application/json" }
      })

      if (!response.ok) {
        throw new Error("Failed to load report candidates")
      }

      const data = await response.json()
      const reports = Array.isArray(data.reports) ? data.reports : []

      this.reportSelectTarget.innerHTML = ""
      const defaultOption = document.createElement("option")
      defaultOption.value = ""
      defaultOption.textContent = reports.length > 0 ? "Select report" : "No reports found"
      this.reportSelectTarget.appendChild(defaultOption)

      reports.forEach((report) => {
        const option = document.createElement("option")
        option.value = report.id
        option.textContent = report.label
        this.reportSelectTarget.appendChild(option)
      })

      this.reportSelectTarget.disabled = reports.length === 0
      this.setStatus(reports.length > 0 ? `Found ${reports.length} report(s). Select one to copy.` : "No matching reports found.")
      this.toggleCopyButton()
    } catch (error) {
      console.error(error)
      this.resetOptions("Unable to load reports")
      this.setStatus("Unable to load reports. Try again.")
    }
  }

  toggleCopyButton() {
    if (!this.hasCopyButtonTarget || !this.hasReportSelectTarget) return
    this.copyButtonTarget.disabled = !this.reportSelectTarget.value
  }

  copy() {
    if (!this.hasReportSelectTarget || !this.reportSelectTarget.value) return

    const query = new URLSearchParams({
      copy_from_report_id: this.reportSelectTarget.value
    })

    if (this.projectIdValue) {
      query.set("project_id", this.projectIdValue)
    }

    window.location.href = `${this.newReportUrlValue}?${query.toString()}`
  }

  resetOptions(label) {
    if (!this.hasReportSelectTarget) return
    this.reportSelectTarget.innerHTML = ""
    const option = document.createElement("option")
    option.value = ""
    option.textContent = label
    this.reportSelectTarget.appendChild(option)
    this.reportSelectTarget.disabled = true
    this.toggleCopyButton()
  }

  setStatus(message) {
    if (!this.hasStatusTextTarget) return
    this.statusTextTarget.textContent = message
  }
}
