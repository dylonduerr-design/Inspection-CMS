# Offline Mode UI Reference

## Visual Guide to Offline Features

### 1. Offline Indicator (Top Right Corner)

```
┌─────────────────────────────┐
│ 🟢 Online                   │  ← Green = Connected
└─────────────────────────────┘

┌─────────────────────────────┐
│ 🔴 Offline                  │  ← Red (pulsing) = Disconnected
└─────────────────────────────┘

┌─────────────────────────────┐
│ 🟢 Online [3]               │  ← Badge shows pending syncs
└─────────────────────────────┘
```

### 2. Report Form Buttons

```
┌─────────────────────────────────────────────────┐
│                                                 │
│  [Save & Submit Report]  💾 Save Offline  🔄 Sync Now │
│                                                 │
└─────────────────────────────────────────────────┘

Save & Submit Report  = Regular save (needs internet)
💾 Save Offline      = Save locally, sync later
🔄 Sync Now          = Upload pending reports now
```

### 3. Status Messages

```
┌──────────────────────────────────────────────────┐
│ ✓ Draft saved locally                           │  ← Green = Success
└──────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────┐
│ ⚠ You are offline - changes saved locally       │  ← Yellow = Warning
└──────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────┐
│ ✗ Failed to save draft                          │  ← Red = Error
└──────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────┐
│ ℹ Syncing 3 report(s)...                        │  ← Blue = Info
└──────────────────────────────────────────────────┘
```

### 4. Toast Notifications

```
                         ┌─────────────────────┐
                         │ Back online         │
                         └─────────────────────┘
                                  ↑
                         Appears bottom-right
                         Auto-dismisses in 3s
```

### 5. Service Worker Update

```
┌───────────────────────────────────────────┐
│ A new version is available! [Update Now]  │
└───────────────────────────────────────────┘
                  ↑
         Appears bottom-center
```

### 6. PWA Install Button

```
     ┌────────────────┐
     │ 📱 Install App │  ← Floating button
     └────────────────┘      bottom-right
```

### 7. Offline Page (When Navigating to Uncached Page)

```
┌────────────────────────────────────────────┐
│                                            │
│              📡                            │
│                                            │
│         You're Offline                     │
│                                            │
│  This page isn't available offline.        │
│  Your pending changes are saved and        │
│  will sync when you're back online.        │
│                                            │
│          [Try Again]                       │
│                                            │
│  Offline Features Available:               │
│  • Create new reports                      │
│  • Fill out checklists                     │
│  • Take notes                              │
│  • Attach photos                           │
│                                            │
└────────────────────────────────────────────┘
```

## Color Scheme

### Connection Status
- **Green (#22c55e)**: Online, connected
- **Red (#ef4444)**: Offline, disconnected

### Status Messages
- **Success**: Green background (#dcfce7), green border
- **Error**: Red background (#fee2e2), red border
- **Warning**: Yellow background (#fef3c7), orange border
- **Info**: Blue background (#dbeafe), blue border

### Buttons
- **Primary**: Blue (#2563eb)
- **Offline Save**: Orange (#f59e0b)
- **Sync**: Green (#22c55e)

## Animations

### Offline Dot
```
Pulsing animation:
0%   - opacity: 1
50%  - opacity: 0.5
100% - opacity: 1
Duration: 2 seconds, infinite
```

### Toast Notifications
```
Slide up from bottom:
Initial: translateY(100px), opacity: 0
Final:   translateY(0), opacity: 1
Duration: 300ms
```

### Update Notification
```
Appears at bottom center
No animation, just appears
User must click to dismiss
```

## User Flow Examples

### Creating Report Offline

```
1. User opens form
   ┌────────────────────────┐
   │ 🟢 Online              │
   └────────────────────────┘

2. Connection lost
   ┌────────────────────────┐
   │ 🔴 Offline             │
   └────────────────────────┘
   + Toast: "You are offline"

3. User fills form
   (Auto-saves every 2 seconds)
   "Draft saved locally" status

4. User clicks "💾 Save Offline"
   ┌────────────────────────┐
   │ 🔴 Offline [1]         │
   └────────────────────────┘
   Status: "Report saved offline..."

5. Connection restored
   ┌────────────────────────┐
   │ 🟢 Online [1]          │
   └────────────────────────┘
   + Toast: "Back online"
   Status: "Syncing 1 report(s)..."

6. Sync complete
   ┌────────────────────────┐
   │ 🟢 Online              │
   └────────────────────────┘
   + Toast: "Report synced successfully!"
```

### Installing App on Mobile

```
1. Browser shows install banner
   ┌─────────────────────────────┐
   │ Add Inspection CMS          │
   │ to Home screen?             │
   │                             │
   │    [Cancel]  [Add]          │
   └─────────────────────────────┘

2. Or use floating button
   ┌────────────────┐
   │ 📱 Install App │
   └────────────────┘

3. Icon appears on home screen
   ┌────┐
   │ 📋 │ Inspection
   └────┘     CMS
```

## Responsive Behavior

### Desktop (> 1024px)
- Offline indicator: Top right, fixed
- Install button: Bottom right, floating
- Status messages: Full width
- All buttons inline

### Tablet (768px - 1024px)
- Same as desktop
- Slightly smaller buttons

### Mobile (< 768px)
- Offline indicator: Slightly smaller
- Install button: May auto-hide if native prompt available
- Status messages: Full width, smaller padding
- Buttons stack vertically if needed

## Accessibility

### ARIA Labels
```html
<div class="offline-indicator" role="status" aria-live="polite">
  <span aria-label="Connection status">Online</span>
</div>
```

### Keyboard Navigation
- All buttons keyboard accessible
- Tab order: Form fields → Save buttons → Sync button
- Enter/Space to activate

### Screen Reader Announcements
- "Connection lost, working offline"
- "Connection restored, syncing data"
- "Report saved successfully"
- "3 reports pending sync"

## Dark Mode Support

The UI adapts to system dark mode:
- Indicator background: Dark gray
- Text: Light colors
- Buttons: Adjusted contrast
- Maintains color meanings (green=online, red=offline)

## Print Styles

Offline indicators and floating buttons hidden when printing:
```css
@media print {
  .offline-indicator,
  #pwa-install-btn,
  .floating-actions {
    display: none;
  }
}
```

## Browser DevTools View

### Service Worker (Chrome DevTools)
```
Application → Service Workers

Status: ✓ Activated and running
Source: service-worker.js
Scope: https://yoursite.com/

□ Offline
□ Update on reload
[Update] [Unregister]
```

### IndexedDB Structure
```
Application → IndexedDB → InspectionCMSOffline

📁 drafts
  📄 draft-1234567890
    - id: "draft-1234567890"
    - data: { ... form data ... }
    - timestamp: "2026-01-28T12:00:00Z"

📁 pendingReports
  📄 offline-1234567890
    - id: "offline-1234567890"
    - data: { ... report data ... }
    - csrfToken: "..."
    - synced: false

📁 photos
  📄 1
    - reportId: "draft-1234567890"
    - filename: "photo.jpg"
    - data: "data:image/jpeg;base64,..."
    - type: "image/jpeg"
```

## Tips for Testing UI

1. **Test offline indicator**
   - DevTools → Network → Offline
   - Watch dot turn red and pulse

2. **Test auto-save**
   - Type in form
   - Watch "Draft saved locally" message
   - Reload page, data persists

3. **Test offline save**
   - Go offline
   - Fill form
   - Click "💾 Save Offline"
   - Check IndexedDB for data

4. **Test sync**
   - Create pending report
   - Go online
   - Watch badge count decrease
   - See success toast

5. **Test install**
   - Look for browser install prompt
   - Or click floating button
   - Check home screen for icon

---

**Pro Tip**: Use Chrome DevTools "Application" tab to inspect all PWA features in one place!
