import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["display", "form", "toggleBtn"]

  toggle() {
    const isEditing = !this.formTarget.classList.contains("d-none")
    this.formTarget.classList.toggle("d-none", isEditing)
    this.displayTarget.classList.toggle("d-none", !isEditing)
    if (this.hasToggleBtnTarget) {
      const label = this.toggleBtnTarget.dataset.editLabel || "Edit Details"
      this.toggleBtnTarget.textContent = isEditing ? label : "Cancel"
    }
  }
}
