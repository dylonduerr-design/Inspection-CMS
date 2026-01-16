import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["divisionSelect", "specItemSelect"]

  connect() {
    if (!this.hasDivisionSelectTarget || !this.hasSpecItemSelectTarget) return

    this.blankOptionHTML = this.specItemSelectTarget.querySelector('option[value=""]')?.outerHTML || ""
    this.allSpecOptions = Array.from(this.specItemSelectTarget.querySelectorAll("option"))
      .filter((opt) => opt.value !== "")
      .map((opt) => ({
        value: opt.value,
        text: opt.textContent,
        division: opt.dataset.division || ""
      }))

    this.applyDivisionFilter()
  }

  divisionChanged() {
    this.applyDivisionFilter(true)
  }

  applyDivisionFilter(clearInvalidSelection = false) {
    const selectedDivision = (this.divisionSelectTarget.value || "").toString()
    const currentSpecItemId = (this.specItemSelectTarget.value || "").toString()

    const filtered = selectedDivision
      ? this.allSpecOptions.filter((opt) => opt.division === selectedDivision)
      : this.allSpecOptions

    const optionsHTML = [this.blankOptionHTML]
      .concat(
        filtered.map((opt) => {
          const escapedText = this.escapeHtml(opt.text)
          return `<option value="${opt.value}" data-division="${this.escapeHtml(opt.division)}">${escapedText}</option>`
        })
      )
      .join("")

    this.specItemSelectTarget.innerHTML = optionsHTML

    if (!clearInvalidSelection && currentSpecItemId) {
      const stillExists = filtered.some((opt) => opt.value === currentSpecItemId)
      if (stillExists) this.specItemSelectTarget.value = currentSpecItemId
    }
  }

  escapeHtml(value) {
    return (value ?? "")
      .toString()
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/\"/g, "&quot;")
      .replace(/'/g, "&#039;")
  }
}
