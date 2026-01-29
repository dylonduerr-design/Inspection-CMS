import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["start", "end", "buttonLabel", "modal"]

  connect() {
    if (!this.hasStartTarget || !this.hasEndTarget) return

    // Safety net: ensure modal is hidden on page load.
    if (this.hasModalTarget) {
      this.modalTarget.hidden = true
    }
    document.body.style.overflow = ""

    this.syncButtonLabel()
  }

  disconnect() {
    // no-op
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

  apply() {
    this.syncButtonLabel()
    this.close()
  }

  backdropClick(event) {
    if (event.target === this.modalTarget) this.close()
  }

  stopPropagation(event) {
    event.stopPropagation()
  }

  clear() {
    this.startTarget.value = ""
    this.endTarget.value = ""
    this.syncButtonLabel()
  }

  syncButtonLabel() {
    if (!this.hasButtonLabelTarget) return
    const start = (this.startTarget.value || "").trim()
    const end = (this.endTarget.value || "").trim()
    if (!start && !end) {
      this.buttonLabelTarget.textContent = "Any date"
      return
    }

    if (start && end && start !== end) {
      this.buttonLabelTarget.textContent = `${start} to ${end}`
    } else {
      this.buttonLabelTarget.textContent = start || end
    }
  }
}
