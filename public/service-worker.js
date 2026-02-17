const CACHE_VERSION = 'v1';
const CACHE_NAME = `inspection-cms-${CACHE_VERSION}`;

// Assets to cache immediately on install
const PRECACHE_ASSETS = [
  '/',
  '/offline.html',
  '/assets/application.css',
  '/assets/application.js'
];

// Install event - cache core assets
self.addEventListener('install', (event) => {
  console.log('[ServiceWorker] Install');
  event.waitUntil(
    caches.open(CACHE_NAME)
      .then(async (cache) => {
        console.log('[ServiceWorker] Precaching assets');
        const assets = PRECACHE_ASSETS.map(url => new Request(url, { credentials: 'same-origin' }));
        
        // Use Promise.all with individual catches to ensure SW installs even if one asset fails
        await Promise.all(assets.map(async (request) => {
          try {
            await cache.add(request);
          } catch (err) {
            console.warn('[ServiceWorker] Failed to cache asset:', request.url, err);
          }
        }));
      })
      .catch(err => console.log('[ServiceWorker] Precache failed:', err))
  );
  self.skipWaiting();
});

// Activate event - clean up old caches
self.addEventListener('activate', (event) => {
  console.log('[ServiceWorker] Activate');
  event.waitUntil(
    caches.keys().then((cacheNames) => {
      return Promise.all(
        cacheNames.map((cacheName) => {
          if (cacheName !== CACHE_NAME) {
            console.log('[ServiceWorker] Deleting old cache:', cacheName);
            return caches.delete(cacheName);
          }
        })
      );
    })
  );
  return self.clients.claim();
});

// Fetch event - network first, fall back to cache
self.addEventListener('fetch', (event) => {
  const { request } = event;
  const url = new URL(request.url);

  // Skip chrome-extension and non-http(s) requests
  if (!url.protocol.startsWith('http')) {
    return;
  }

  // Skip AI agent and export endpoints (they require internet)
  if (url.pathname.includes('/ai_agent') || 
      url.pathname.includes('/export') ||
      url.pathname.includes('/cable')) {
    return;
  }

  event.respondWith(
    fetch(request)
      .then((response) => {
        // Only cache successful GET requests
        if (request.method === 'GET' && response.status === 200) {
          const responseClone = response.clone();
          caches.open(CACHE_NAME).then((cache) => {
            cache.put(request, responseClone);
          });
        }
        return response;
      })
      .catch(() => {
        // Network failed, try cache
        return caches.match(request).then((cachedResponse) => {
          if (cachedResponse) {
            return cachedResponse;
          }
          
          // If requesting an HTML page and no cache, show offline page
          const acceptHeader = request.headers.get('accept') || ''
          if (acceptHeader.includes('text/html')) {
            return caches.match('/offline.html');
          }
          
          // For other resources, return a basic error response
          return new Response('Offline - resource not available', {
            status: 503,
            statusText: 'Service Unavailable'
          });
        });
      })
  );
});

// Background sync for offline form submissions
self.addEventListener('sync', (event) => {
  console.log('[ServiceWorker] Background sync:', event.tag);
  
  if (event.tag.startsWith('sync-report-')) {
    event.waitUntil(syncReport(event.tag));
  }
});

async function syncReport(tag) {
  try {
    const reportId = tag.replace('sync-report-', '');
    const db = await openOfflineDB();
    const tx = db.transaction('pendingReports', 'readonly');
    const store = tx.objectStore('pendingReports');
    const report = await store.get(reportId);
    
    if (!report) {
      console.log('[ServiceWorker] No pending report found for', reportId);
      return;
    }

    // Attempt to sync with server
    const response = await fetch('/reports', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': report.csrfToken
      },
      body: JSON.stringify({ report: report.data })
    });

    if (response.ok) {
      // Remove from pending queue
      const deleteTx = db.transaction('pendingReports', 'readwrite');
      await deleteTx.objectStore('pendingReports').delete(reportId);
      console.log('[ServiceWorker] Successfully synced report:', reportId);
      
      // Notify all clients
      const clients = await self.clients.matchAll();
      clients.forEach(client => {
        client.postMessage({
          type: 'SYNC_SUCCESS',
          reportId: reportId
        });
      });
    }
  } catch (error) {
    console.error('[ServiceWorker] Sync failed:', error);
    throw error; // Will retry
  }
}

function openOfflineDB() {
  return new Promise((resolve, reject) => {
    const request = indexedDB.open('InspectionCMSOffline', 1);
    request.onerror = () => reject(request.error);
    request.onsuccess = () => resolve(request.result);
  });
}

// Handle messages from clients
self.addEventListener('message', (event) => {
  if (event.data && event.data.type === 'SKIP_WAITING') {
    self.skipWaiting();
  }
});
