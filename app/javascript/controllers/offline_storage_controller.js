import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["form", "status"]
  static values = {
    reportId: String,
    autoSave: { type: Boolean, default: true }
  }

  connect() {
    this.dbName = 'InspectionCMSOffline'
    this.dbVersion = 2  // Incremented to ensure photos object store exists
    this.db = null
    this.autoSaveTimer = null
    this.boundOnOnline = this.onOnline.bind(this)
    this.boundOnOffline = this.onOffline.bind(this)
    this.boundHandleSyncMessage = this.handleSyncMessage.bind(this)
    this.boundScheduleAutoSave = this.scheduleAutoSave.bind(this)
    this.boundHandleFormSubmit = this.handleFormSubmit.bind(this)
    
    this.initDB().then(() => {
      console.log('[OfflineStorage] Database initialized')
      this.loadDraft()
      
      if (this.autoSaveValue) {
        this.startAutoSave()
      }
    })

    // Listen for online/offline events
    window.addEventListener('online', this.boundOnOnline)
    window.addEventListener('offline', this.boundOnOffline)

    if (this.hasFormTarget) {
      this.formTarget.addEventListener('submit', this.boundHandleFormSubmit)
    }
    
    // Listen for sync messages from service worker
    if ('serviceWorker' in navigator) {
      navigator.serviceWorker.addEventListener('message', this.boundHandleSyncMessage)
    }
  }

  disconnect() {
    this.stopAutoSave()
    window.removeEventListener('online', this.boundOnOnline)
    window.removeEventListener('offline', this.boundOnOffline)

    if (this.hasFormTarget) {
      this.formTarget.removeEventListener('submit', this.boundHandleFormSubmit)
    }

    if ('serviceWorker' in navigator) {
      navigator.serviceWorker.removeEventListener('message', this.boundHandleSyncMessage)
    }
  }

  async initDB() {
    return new Promise((resolve, reject) => {
      const request = indexedDB.open(this.dbName, this.dbVersion)

      request.onerror = () => {
        console.error('[OfflineStorage] Database error:', request.error)
        reject(request.error)
      }

      request.onsuccess = (event) => {
        this.db = event.target.result
        console.log('[OfflineStorage] Database opened successfully')
        resolve(this.db)
      }

      request.onupgradeneeded = (event) => {
        console.log('[OfflineStorage] Upgrading database schema...')
        const db = event.target.result

        // Store for draft reports (auto-save)
        if (!db.objectStoreNames.contains('drafts')) {
          const draftsStore = db.createObjectStore('drafts', { keyPath: 'id' })
          draftsStore.createIndex('timestamp', 'timestamp', { unique: false })
          console.log('[OfflineStorage] Created drafts object store')
        }

        // Store for pending reports (waiting to sync)
        if (!db.objectStoreNames.contains('pendingReports')) {
          const pendingStore = db.createObjectStore('pendingReports', { keyPath: 'id' })
          pendingStore.createIndex('timestamp', 'timestamp', { unique: false })
          console.log('[OfflineStorage] Created pendingReports object store')
        }

        // Store for cached photos
        if (!db.objectStoreNames.contains('photos')) {
          const photosStore = db.createObjectStore('photos', { keyPath: 'id', autoIncrement: true })
          photosStore.createIndex('reportId', 'reportId', { unique: false })
          photosStore.createIndex('timestamp', 'timestamp', { unique: false })
          console.log('[OfflineStorage] Created photos object store')
        }
      }
    })
  }

  async saveDraft() {
    if (!this.hasFormTarget) return

    if (!this.db) {
      console.warn('[OfflineStorage] Database not initialized, skipping draft save')
      return
    }

    const formData = new FormData(this.formTarget)
    const data = this.formDataToObject(formData)

    const draft = {
      id: this.reportIdValue || `draft-${Date.now()}`,
      data: data,
      timestamp: new Date().toISOString(),
      url: window.location.pathname
    }

    try {
      const tx = this.db.transaction('drafts', 'readwrite')
      const store = tx.objectStore('drafts')
      await store.put(draft)

      this.showStatus('Draft saved locally', 'success')
      console.log('[OfflineStorage] Draft saved:', draft.id)
    } catch (error) {
      console.error('[OfflineStorage] Failed to save draft:', error)
      this.showStatus('Failed to save draft', 'error')
    }
  }

  async loadDraft() {
    const draftId = this.reportIdValue || this.getDraftIdFromUrl()
    if (!draftId) return

    if (!this.db) {
      console.warn('[OfflineStorage] Database not initialized, skipping draft load')
      return
    }

    try {
      const tx = this.db.transaction('drafts', 'readonly')
      const store = tx.objectStore('drafts')
      const draft = await store.get(draftId)

      if (draft && this.hasFormTarget) {
        this.populateForm(draft.data)
        this.showStatus('Draft loaded', 'info')
        console.log('[OfflineStorage] Draft loaded:', draftId)
      }
    } catch (error) {
      console.error('[OfflineStorage] Failed to load draft:', error)
    }
  }

  async saveOfflineReport(event = null) {
    if (event) {
      event.preventDefault()
    }
    
    if (!this.hasFormTarget) return

    const formData = new FormData(this.formTarget)
    const data = this.formDataToObject(formData)
    
    const reportId = `offline-${Date.now()}`
    const pendingReport = {
      id: reportId,
      data: data,
      timestamp: new Date().toISOString(),
      csrfToken: this.getCSRFToken(),
      synced: false
    }

    try {
      const tx = this.db.transaction('pendingReports', 'readwrite')
      const store = tx.objectStore('pendingReports')
      await store.put(pendingReport)
      
      this.showStatus('Report saved offline. Will sync when online.', 'success')
      console.log('[OfflineStorage] Report queued for sync:', reportId)
      
      // Request background sync if available
      if ('serviceWorker' in navigator && 'sync' in navigator.serviceWorker) {
        const registration = await navigator.serviceWorker.ready
        await registration.sync.register(`sync-report-${reportId}`)
        console.log('[OfflineStorage] Background sync registered')
      }
      
      // Redirect or show success
      setTimeout(() => {
        window.location.href = '/reports'
      }, 2000)
      
    } catch (error) {
      console.error('[OfflineStorage] Failed to save offline report:', error)
      this.showStatus('Failed to save report offline', 'error')
    }
  }

  handleFormSubmit(event) {
    if (navigator.onLine) return
    this.saveOfflineReport(event)
  }

  async syncPendingReports() {
    if (!navigator.onLine) {
      this.showStatus('Cannot sync - you are offline', 'warning')
      return
    }

    try {
      const tx = this.db.transaction('pendingReports', 'readonly')
      const store = tx.objectStore('pendingReports')
      const reports = await store.getAll()
      
      if (reports.length === 0) {
        this.showStatus('No pending reports to sync', 'info')
        return
      }

      this.showStatus(`Syncing ${reports.length} report(s)...`, 'info')
      
      let syncedCount = 0
      for (const report of reports) {
        try {
          const response = await fetch('/reports', {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
              'X-CSRF-Token': report.csrfToken
            },
            body: JSON.stringify({ report: report.data })
          })

          if (response.ok) {
            // Remove from pending
            const deleteTx = this.db.transaction('pendingReports', 'readwrite')
            await deleteTx.objectStore('pendingReports').delete(report.id)
            syncedCount++
          }
        } catch (error) {
          console.error('[OfflineStorage] Failed to sync report:', report.id, error)
        }
      }

      this.showStatus(`Synced ${syncedCount} of ${reports.length} reports`, 'success')
    } catch (error) {
      console.error('[OfflineStorage] Sync failed:', error)
      this.showStatus('Sync failed', 'error')
    }
  }

  async savePhoto(file, reportId) {
    if (!this.db) {
      console.error('[OfflineStorage] Database not initialized')
      return Promise.reject(new Error('Database not initialized'))
    }

    return new Promise((resolve, reject) => {
      const reader = new FileReader()

      reader.onload = async (e) => {
        const photo = {
          reportId: reportId || 'temp',
          filename: file.name,
          data: e.target.result,
          type: file.type,
          size: file.size,
          timestamp: new Date().toISOString()
        }

        try {
          const tx = this.db.transaction('photos', 'readwrite')
          const store = tx.objectStore('photos')
          const id = await store.add(photo)
          console.log('[OfflineStorage] Photo saved:', id)
          resolve(id)
        } catch (error) {
          console.error('[OfflineStorage] Failed to save photo:', error)
          reject(error)
        }
      }

      reader.onerror = reject
      reader.readAsDataURL(file)
    })
  }

  async getPendingCount() {
    try {
      const tx = this.db.transaction('pendingReports', 'readonly')
      const store = tx.objectStore('pendingReports')
      const count = await store.count()
      return count
    } catch (error) {
      console.error('[OfflineStorage] Failed to get pending count:', error)
      return 0
    }
  }

  // Event Handlers
  onOnline() {
    console.log('[OfflineStorage] Connection restored')
    this.showStatus('Back online - syncing...', 'success')
    this.syncPendingReports()
  }

  onOffline() {
    console.log('[OfflineStorage] Connection lost')
    this.showStatus('You are offline - changes will be saved locally', 'warning')
  }

  handleSyncMessage(event) {
    if (event.data.type === 'SYNC_SUCCESS') {
      this.showStatus('Report synced successfully!', 'success')
    }
  }

  // Auto-save functionality
  startAutoSave() {
    this.stopAutoSave()
    
    if (this.hasFormTarget) {
      this.formTarget.addEventListener('input', this.boundScheduleAutoSave)
      this.formTarget.addEventListener('change', this.boundScheduleAutoSave)
    }
  }

  stopAutoSave() {
    if (this.autoSaveTimer) {
      clearTimeout(this.autoSaveTimer)
    }
    
    if (this.hasFormTarget) {
      this.formTarget.removeEventListener('input', this.boundScheduleAutoSave)
      this.formTarget.removeEventListener('change', this.boundScheduleAutoSave)
    }
  }

  scheduleAutoSave() {
    if (this.autoSaveTimer) {
      clearTimeout(this.autoSaveTimer)
    }
    
    this.autoSaveTimer = setTimeout(() => {
      this.saveDraft()
    }, 2000) // Save 2 seconds after last change
  }

  // Helper methods
  formDataToObject(formData) {
    const object = {}
    formData.forEach((value, key) => {
      // Handle nested attributes
      if (key.includes('[')) {
        const matches = key.match(/([^\[]+)\[([^\]]+)\]/)
        if (matches) {
          const [, parent, child] = matches
          if (!object[parent]) object[parent] = {}
          object[parent][child] = value
        }
      } else {
        object[key] = value
      }
    })
    return object
  }

  populateForm(data) {
    Object.keys(data).forEach(key => {
      const element = this.formTarget.querySelector(`[name="${key}"]`)
      if (element) {
        element.value = data[key]
      }
    })
  }

  getCSRFToken() {
    const token = document.querySelector('meta[name="csrf-token"]')
    return token ? token.content : ''
  }

  getDraftIdFromUrl() {
    const match = window.location.pathname.match(/\/reports\/(\d+)/)
    return match ? match[1] : null
  }

  showStatus(message, type = 'info') {
    if (this.hasStatusTarget) {
      this.statusTarget.textContent = message
      this.statusTarget.className = `offline-status offline-status--${type}`
      this.statusTarget.style.display = 'block'
      
      setTimeout(() => {
        this.statusTarget.style.display = 'none'
      }, 5000)
    } else {
      console.log(`[OfflineStorage] ${type.toUpperCase()}: ${message}`)
    }
  }
}
