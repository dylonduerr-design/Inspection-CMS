#!/bin/bash

# Offline Functionality Testing Script
# Run this to verify offline features are working

echo "🧪 Testing Offline Functionality Implementation"
echo "=============================================="
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Counter
passed=0
failed=0

# Test function
test_file() {
    if [ -f "$1" ]; then
        echo -e "${GREEN}✓${NC} $2"
        ((passed++))
    else
        echo -e "${RED}✗${NC} $2 - File not found: $1"
        ((failed++))
    fi
}

test_content() {
    if grep -q "$2" "$1" 2>/dev/null; then
        echo -e "${GREEN}✓${NC} $3"
        ((passed++))
    else
        echo -e "${RED}✗${NC} $3"
        ((failed++))
    fi
}

echo "1. Checking PWA Files..."
test_file "public/manifest.json" "PWA manifest exists"
test_file "public/service-worker.js" "Service worker exists"
test_file "public/offline.html" "Offline fallback page exists"
test_file "public/icon.svg" "App icon exists"
echo ""

echo "2. Checking JavaScript Controllers..."
test_file "app/javascript/controllers/offline_storage_controller.js" "Offline storage controller exists"
test_file "app/javascript/controllers/offline_indicator_controller.js" "Offline indicator controller exists"
test_file "app/javascript/pwa.js" "PWA registration script exists"
echo ""

echo "3. Checking Configuration..."
test_content "config/importmap.rb" 'pin "pwa"' "PWA script pinned in importmap"
test_content "app/views/layouts/application.html.erb" 'manifest.json' "Manifest linked in layout"
test_content "app/views/layouts/application.html.erb" 'offline-indicator' "Offline indicator in layout"
echo ""

echo "4. Checking Form Integration..."
test_content "app/views/reports/_form.html.erb" 'offline-storage' "Offline storage controller in form"
test_content "app/views/reports/_form.html.erb" 'Save Report' "Primary save action in form"
test_content "app/views/reports/_form.html.erb" 'syncPendingReports' "Sync capability present in form (may be disabled in MVP)"
echo ""

echo "5. Checking CSS..."
test_content "app/assets/stylesheets/application.css" '.offline-indicator' "Offline indicator styles exist"
test_content "app/assets/stylesheets/application.css" '.offline-save-btn' "Offline button styles exist"
test_content "app/assets/stylesheets/application.css" '.pwa' "PWA styles exist"
echo ""

echo "6. Checking Documentation..."
test_file "docs/OFFLINE_FUNCTIONALITY.md" "Offline functionality documentation exists"
echo ""

echo "=============================================="
echo -e "Results: ${GREEN}${passed} passed${NC}, ${RED}${failed} failed${NC}"
echo ""

if [ $failed -eq 0 ]; then
    echo -e "${GREEN}✓ All tests passed!${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Start Rails server: rails s"
    echo "2. Open browser to http://localhost:3000"
    echo "3. Open DevTools (F12) → Application tab"
    echo "4. Check Service Worker registration"
    echo "5. Go to Network tab → set to 'Offline'"
    echo "6. Test creating a report offline"
    echo "7. Return to 'Online' and verify sync"
    exit 0
else
    echo -e "${RED}✗ Some tests failed. Please review the output above.${NC}"
    exit 1
fi
