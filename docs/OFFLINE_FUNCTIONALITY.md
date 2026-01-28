# Offline Functionality Guide

## Overview

The Inspection CMS now supports full offline functionality, allowing inspectors to work without internet connection. This Progressive Web App (PWA) implementation enables creating reports, filling out checklists, taking notes, and attaching photos even when offline.

## Features

### ✅ Available Offline
- Create new inspection reports
- Fill out all report fields (general info, compliance, workforce, equipment)
- Complete specification checklists
- Add notes and observations
- Attach photos and documents
- Auto-save drafts
- Queue reports for automatic syncing

### ❌ Not Available Offline
- AI Agent assistance
- Report export (Word/PDF generation)
- Real-time collaboration
- Photo uploads to server (queued until online)

## How It Works

### 1. Progressive Web App (PWA)
The application can be installed on mobile devices and desktops as a standalone app:
- **Mobile**: Tap "Add to Home Screen" in browser menu
- **Desktop**: Click "Install" in browser address bar or the "📱 Install App" button

### 2. Service Worker
Caches essential assets and pages for offline access:
- Application CSS and JavaScript
- Frequently accessed pages
- Network-first strategy with cache fallback

### 3. IndexedDB Storage
Local database stores:
- **Drafts**: Auto-saved form data (every 2 seconds after changes)
- **Pending Reports**: Complete reports waiting to sync
- **Photos**: Cached images for offline attachment

### 4. Background Sync
When internet connection returns:
- Automatically syncs pending reports to server
- Uploads queued photos
- Shows sync status notifications

## User Guide

### Working Offline

1. **Offline Indicator**
   - Green dot = Online
   - Red pulsing dot = Offline
   - Badge shows number of pending syncs

2. **Creating a Report**
   - Fill out form normally
   - Click "💾 Save Offline" button
   - Report is stored locally and queued for sync

3. **Auto-Save**
   - Forms automatically save drafts every 2 seconds
   - Drafts persist even if browser closes
   - Load draft when returning to form

4. **Attaching Photos**
   - Photos stored locally in IndexedDB
   - Compressed to base64 format
   - Synced when connection available

5. **Syncing Data**
   - Automatic sync when connection restored
   - Manual sync with "🔄 Sync Now" button
   - Status messages show sync progress

### Installing as App

#### On Mobile (iOS/Android)
1. Open site in Safari (iOS) or Chrome (Android)
2. iOS: Tap Share → "Add to Home Screen"
3. Android: Tap Menu → "Install App" or "Add to Home Screen"
4. Icon appears on home screen like native app

#### On Desktop (Chrome/Edge)
1. Look for install icon in address bar
2. Or click "📱 Install App" button in floating actions
3. Confirm installation
4. App opens in standalone window

## Technical Details

### Architecture

```
┌─────────────────────────────────────────────┐
│          User Interface (Browser)           │
├─────────────────────────────────────────────┤
│       Stimulus Controllers                  │
│  - offline_storage_controller.js            │
│  - offline_indicator_controller.js          │
├─────────────────────────────────────────────┤
│          Service Worker                     │
│  - Caching Strategy                         │
│  - Background Sync                          │
├─────────────────────────────────────────────┤
│          IndexedDB                          │
│  - drafts (auto-save)                       │
│  - pendingReports (sync queue)              │
│  - photos (cached images)                   │
└─────────────────────────────────────────────┘
```

### Files Added

1. **PWA Configuration**
   - `/public/manifest.json` - PWA manifest
   - `/public/service-worker.js` - Service worker
   - `/public/offline.html` - Offline fallback page
   - `/public/icon.svg` - App icon

2. **JavaScript Controllers**
   - `app/javascript/controllers/offline_storage_controller.js`
   - `app/javascript/controllers/offline_indicator_controller.js`
   - `app/javascript/pwa.js`

3. **Styles**
   - Added offline/PWA styles to `app/assets/stylesheets/application.css`

4. **Views Updated**
   - `app/views/layouts/application.html.erb` - Added PWA meta tags
   - `app/views/reports/_form.html.erb` - Added offline controls

### Database Schema (IndexedDB)

```javascript
// Database: InspectionCMSOffline v1

ObjectStore: drafts
  - keyPath: id
  - indexes: timestamp
  - stores: Auto-saved form data

ObjectStore: pendingReports
  - keyPath: id
  - indexes: timestamp
  - stores: Complete reports awaiting sync

ObjectStore: photos
  - keyPath: id (auto-increment)
  - indexes: reportId, timestamp
  - stores: Cached photo data
```

### Service Worker Caching Strategy

**Network First, Cache Fallback**
1. Try to fetch from network
2. Cache successful responses
3. If network fails, serve from cache
4. If no cache, show offline page

**Excluded from Cache**
- `/ai_agent/*` - Requires internet
- `/export/*` - Server-side processing needed
- `/cable` - WebSocket connections

### Background Sync

Uses Background Sync API when available:
```javascript
// Register sync
registration.sync.register('sync-report-{id}')

// Service worker handles sync
self.addEventListener('sync', event => {
  if (event.tag.startsWith('sync-report-')) {
    event.waitUntil(syncReport(event.tag))
  }
})
```

## Testing Offline Functionality

### In Chrome DevTools

1. Open DevTools (F12)
2. Go to "Network" tab
3. Change throttling to "Offline"
4. Test offline features
5. Return to "Online" to test sync

### In Application Tab

1. Open DevTools → Application
2. **Service Workers**: Check registration status
3. **Storage → IndexedDB**: Inspect stored data
4. **Cache Storage**: View cached assets

### Real Device Testing

1. Install app on mobile device
2. Enable airplane mode
3. Create test report offline
4. Disable airplane mode
5. Verify automatic sync

## Troubleshooting

### Service Worker Not Registering

**Issue**: Console shows SW registration failed

**Solutions**:
- Ensure HTTPS (required for SW, localhost exempt)
- Check browser compatibility
- Clear browser cache and reload
- Check for JavaScript errors

### Data Not Syncing

**Issue**: Reports stay in pending queue

**Solutions**:
- Check network connection
- Verify CSRF token validity
- Check browser console for errors
- Try manual sync with "🔄 Sync Now"
- Inspect IndexedDB for pending items

### Photos Not Saving

**Issue**: Photos fail to store offline

**Solutions**:
- Check file size (IndexedDB has limits)
- Verify browser storage quota
- Clear old cached data
- Check console for storage errors

### App Not Installing

**Issue**: Install prompt doesn't appear

**Solutions**:
- Verify manifest.json is accessible
- Check all manifest requirements met
- Ensure HTTPS connection
- Try different browser
- Clear cache and reload

## Browser Support

| Feature | Chrome | Firefox | Safari | Edge |
|---------|--------|---------|--------|------|
| Service Worker | ✅ | ✅ | ✅ | ✅ |
| IndexedDB | ✅ | ✅ | ✅ | ✅ |
| Background Sync | ✅ | ❌ | ❌ | ✅ |
| PWA Install | ✅ | ❌ | ✅* | ✅ |

*Safari: Add to Home Screen instead of install prompt

## Performance Considerations

### Storage Limits

- **Chrome/Edge**: ~60% of disk space
- **Firefox**: Up to 2GB per origin
- **Safari**: Up to 1GB per origin

### Photo Optimization

Photos stored as base64 strings:
- Increases size by ~33%
- Consider compressing before storage
- Implement cleanup of old cached photos

### Auto-Save Throttling

- 2 second debounce prevents excessive saves
- Only modified data triggers save
- Reduces IndexedDB write operations

## Future Enhancements

1. **Photo Compression**: Automatically compress images before storage
2. **Selective Sync**: Allow users to choose which reports to sync
3. **Conflict Resolution**: Handle concurrent edits gracefully
4. **Storage Management**: UI to view/clear cached data
5. **Push Notifications**: Notify when sync completes
6. **Offline Analytics**: Track offline usage patterns

## Security Notes

- All data stored in browser's origin-isolated storage
- No sensitive data should be stored unencrypted
- CSRF tokens cached for form submissions
- Consider adding encryption for sensitive reports
- Clear storage on logout recommended

## Maintenance

### Updating Service Worker

When updating SW, increment cache version:
```javascript
const CACHE_VERSION = 'v2'; // Increment this
```

Users will see update notification:
- "A new version is available!"
- Click "Update Now" to reload

### Clearing Old Caches

Service worker automatically removes old cache versions on activation.

### Monitoring Storage Usage

Check storage quota:
```javascript
navigator.storage.estimate().then(estimate => {
  console.log(`Using ${estimate.usage} of ${estimate.quota} bytes`)
})
```

## Support

For issues or questions:
1. Check browser console for errors
2. Verify service worker registration in DevTools
3. Inspect IndexedDB for data integrity
4. Test in incognito mode to rule out extensions
5. Document steps to reproduce and report

## Changelog

### Version 1.0 (January 2026)
- Initial offline functionality
- PWA manifest and service worker
- IndexedDB storage implementation
- Auto-save drafts
- Background sync
- Offline indicators
- Install prompts
