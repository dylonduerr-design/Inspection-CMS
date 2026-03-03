import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["barView", "donutView", "barBtn", "donutBtn"]

  connect() {
    this.showBar()
  }

  showBar() {
    this.barViewTarget.classList.remove("d-none")
    this.donutViewTarget.classList.add("d-none")
    this.barBtnTarget.classList.add("chart-toggle-btn--active")
    this.donutBtnTarget.classList.remove("chart-toggle-btn--active")
  }

  showDonut() {
    this.barViewTarget.classList.add("d-none")
    this.donutViewTarget.classList.remove("d-none")
    this.barBtnTarget.classList.remove("chart-toggle-btn--active")
    this.donutBtnTarget.classList.add("chart-toggle-btn--active")
  }
}
