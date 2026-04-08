import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "button", "form"]
  static values = { expectedString: String }

  connect() {
    this.disable()
  }

  disconnect() {
    this.disable()
  }

  check() {
    const expected = (this.expectedStringValue || "").trim()
    const current = (this.inputTarget.value || "").trim()
    if (expected.length > 0 && current === expected) {
      this.enable()
    } else {
      this.disable()
    }
  }

  disable() {
    if (this.hasButtonTarget) this.buttonTarget.disabled = true
  }

  enable() {
    if (this.hasButtonTarget) this.buttonTarget.disabled = false
  }
}
