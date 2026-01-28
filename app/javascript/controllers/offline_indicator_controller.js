import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["indicator", "badge"]
  static values = {
    showBadge: { type: Boolean, default: true }
  }

  connect() {
    // Initial state assumption
    this.isServerReachable = navigator.onLine
    this.updateStatus()
    
    // Bind event listeners properly so they can be removed
    this.boundOnOnline = this.onOnline.bind(this)
    this.boundOnOffline = this.onOffline.bind(this)
    this.boundCheckConnection = this.checkConnection.bind(this)

    window.addEventListener('online', this.boundOnOnline)
    window.addEventListener('offline', this.boundOnOffline)
    
    // Start heartbeat to check actual server reachability
    this.startHeartbeat()
    
    // Check for pending syncs
    this.checkPendingSync()
  }

  disconnect() {
    window.removeEventListener('online', this.boundOnOnline)
    window.removeEventListener('offline', this.boundOnOffline)
    this.stopHeartbeat()
  }

  startHeartbeat() {
    // Check immediately
    this.checkConnection()
    // Check every 30 seconds to reduce server load
    this.heartbeatInterval = setInterval(this.boundCheckConnection, 30000)
  }

  stopHeartbeat() {
    if (this.heartbeatInterval) clearInterval(this.heartbeatInterval)
  }

  async checkConnection() {
    // If browser thinks it's offline, we are definitely offline
    if (!navigator.onLine) {
      if (this.isServerReachable) {
        this.onOffline()
      }
      return
    }

    try {
      // Try to hit the lightweight health check endpoint
      const controller = new AbortController()
      const timeoutId = setTimeout(() => controller.abort(), 5000) // 5s timeout check

      const response = await fetch("/health_check", { 
        method: "HEAD", 
        cache: "no-store", 
        signal: controller.signal
      })
      clearTimeout(timeoutId)

      if (response.ok) {
        if (!this.isServerReachable) {
          this.isServerReachable = true
          this.updateStatus()
          this.showNotification('Connected to server', 'success')
        }
      } else {
        throw new Error("Server error")
      }
    } catch (error) {
      // Fetch failed or timed out -> Server unreachable
      if (this.isServerReachable) {
         this.onOffline()
      }
    }
  }

  onOnline() {
    // When network comes back, verify server immediately
    this.checkConnection()
  }

  onOffline() {
    this.isServerReachable = false
    this.updateStatus()
    this.showNotification('You are offline', 'warning')
  }

  updateStatus() {
    const isOnline = this.isServerReachable
    
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
