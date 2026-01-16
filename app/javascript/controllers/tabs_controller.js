import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["tab", "panel"]
  static values = { active: String }

  connect() {
    const initialTab = this.activeValue || this.tabTargets[0]?.dataset.tab
    if (initialTab) {
      this.show(initialTab)
    }
  }

  switch(event) {
    event.preventDefault()
    const tabId = event.currentTarget.dataset.tab
    if (!tabId) return
    this.show(tabId)
  }

  show(tabId) {
    this.activeValue = tabId
    this.tabTargets.forEach((tab) => {
      tab.classList.toggle("is-active", tab.dataset.tab === tabId)
    })
    this.panelTargets.forEach((panel) => {
      panel.classList.toggle("d-none", panel.dataset.tab !== tabId)
    })
  }
}
