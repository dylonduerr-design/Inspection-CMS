// Service Worker Registration and Management

if ('serviceWorker' in navigator) {
  window.addEventListener('load', () => {
    navigator.serviceWorker.register('/service-worker.js')
      .then(registration => {
        console.log('[SW] Service Worker registered:', registration.scope)
        
        // Check for updates periodically (hourly - SW updates are rare)
        setInterval(() => {
          registration.update()
        }, 3600000) // Check every hour
        
        // Handle service worker updates
        registration.addEventListener('updatefound', () => {
          const newWorker = registration.installing
          
          newWorker.addEventListener('statechange', () => {
            if (newWorker.state === 'installed' && navigator.serviceWorker.controller) {
              // New service worker available
              showUpdateNotification(registration)
            }
          })
        })
      })
      .catch(error => {
        console.error('[SW] Service Worker registration failed:', error)
      })
  })
}

function showUpdateNotification(registration) {
  const notification = document.createElement('div')
  notification.className = 'sw-update-notification'
  notification.innerHTML = `
    <div class="sw-update-content">
      <span>A new version is available!</span>
      <button class="sw-update-btn" onclick="updateServiceWorker()">Update Now</button>
    </div>
  `
  document.body.appendChild(notification)
  
  window.updateServiceWorker = () => {
    if (registration.waiting) {
      registration.waiting.postMessage({ type: 'SKIP_WAITING' })
      window.location.reload()
    }
  }
}

// Install prompt for PWA
let deferredPrompt
window.addEventListener('beforeinstallprompt', (e) => {
  e.preventDefault()
  deferredPrompt = e
  
  // Show custom install button
  const installBtn = document.getElementById('pwa-install-btn')
  if (installBtn) {
    installBtn.style.display = 'block'
    
    installBtn.addEventListener('click', async () => {
      if (deferredPrompt) {
        deferredPrompt.prompt()
        const { outcome } = await deferredPrompt.userChoice
        console.log(`[PWA] User ${outcome} the install prompt`)
        deferredPrompt = null
        installBtn.style.display = 'none'
      }
    })
  }
})

// Track when app is installed
window.addEventListener('appinstalled', () => {
  console.log('[PWA] App was installed')
  deferredPrompt = null
})
