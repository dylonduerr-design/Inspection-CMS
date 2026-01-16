import { Controller } from "@hotwired/stimulus"

// Sets the width of a progress bar based on a provided percent value.
export default class extends Controller {
  static targets = ["bar"]
  static values = { percent: Number }

  connect() {
    this.apply()
  }

  apply() {
    const raw = this.percentValue
    const pct = Number.isFinite(raw) ? raw : 0
    // Keep within a sensible range; allow slight overrun if provided.
    const clamped = Math.max(0, Math.min(pct, 150))
    if (this.hasBarTarget) {
      this.barTarget.style.width = `${clamped}%`
    }
  }
}
