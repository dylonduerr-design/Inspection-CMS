import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["indicator", "badge"]
  static values = {
    showBadge: { type: Boolean, default: true }
  }

  connect() {
    this.updateStatus()
    
    window.addEventListener('online', this.onOnline.bind(this))
    window.addEventListener('offline', this.onOffline.bind(this))
    
    // Check for pending syncs
    this.checkPendingSync()
  }

  disconnect() {
    window.removeEventListener('online', this.onOnline.bind(this))
    window.removeEventListener('offline', this.onOffline.bind(this))
  }

  onOnline() {
    this.updateStatus()
    this.showNotification('Back online', 'success')
  }

  onOffline() {
    this.updateStatus()
    this.showNotification('You are offline', 'warning')
  }

  updateStatus() {
    const isOnline = navigator.onLine
    
    if (this.hasIndicatorTarget) {
      this.indicatorTarget.classList.toggle('offline-indicator--online', isOnline)
      this.indicatorTarget.classList.toggle('offline-indicator--offline', !isOnline)
      
      const statusText = this.indicatorTarget.querySelector('.offline-indicator__text')
      if (statusText) {
        statusText.textContent = isOnline ? 'Online' : 'Offline'
      }
    }
  }

  async checkPendingSync() {
    if (!this.showBadgeValue) return
    
    try {
      const db = await this.openDB()
      const tx = db.transaction('pendingReports', 'readonly')
      const store = tx.objectStore('pendingReports')
      const count = await store.count()
      
      if (this.hasBadgeTarget && count > 0) {
        this.badgeTarget.textContent = count
        this.badgeTarget.style.display = 'flex'
      } else if (this.hasBadgeTarget) {
        this.badgeTarget.style.display = 'none'
      }
    } catch (error) {
      console.error('[OfflineIndicator] Failed to check pending sync:', error)
    }
  }

  openDB() {
    return new Promise((resolve, reject) => {
      const request = indexedDB.open('InspectionCMSOffline', 1)
      request.onerror = () => reject(request.error)
      request.onsuccess = () => resolve(request.result)
    })
  }

  showNotification(message, type) {
    // Create temporary notification
    const notification = document.createElement('div')
    notification.className = `offline-notification offline-notification--${type}`
    notification.textContent = message
    document.body.appendChild(notification)
    
    setTimeout(() => {
      notification.classList.add('offline-notification--show')
    }, 100)
    
    setTimeout(() => {
      notification.classList.remove('offline-notification--show')
      setTimeout(() => notification.remove(), 300)
    }, 3000)
  }
}
