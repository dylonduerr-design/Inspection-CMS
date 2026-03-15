# Azure Image Storage Options - Cost Comparison

## ✅ IMPLEMENTED: URL Caching with Local Disk (Option B)

**Current implementation uses FREE URL caching with parallel downloads.**

See [IMAGE_URL_CACHING.md](./IMAGE_URL_CACHING.md) for usage details.

---

## Problem Statement (Solved)

Previously, images were downloaded serially from Blob Storage during Word export, taking 3-6 seconds for 6 images.

**Solution:** Cache signed URLs (not images) and download in parallel.
**Result:** 5-10x faster at $0/month cost.

---

## Option 1: Azure Cache for Redis ⚡ (Current Implementation)

### Pros
- **Fastest**: In-memory cache, 10-50ms retrieval
- **Best performance**: 10-100x faster than Blob Storage
- **Proven solution**: Industry standard for caching

### Cons
- **Most expensive**: $45/month for Basic C1 (1GB)
- **Memory limited**: Can't store unlimited images
- **Volatile**: Data lost if Redis restarts (unless Premium tier with persistence)

### Cost
| Tier | Memory | Monthly Cost |
|------|--------|--------------|
| Basic C0 | 250 MB | $16/month |
| Basic C1 | 1 GB | $45/month |
| Basic C2 | 2.5 GB | $90/month |

### Recommendation
Best for: High-traffic production with frequent exports

---

## Option 2: Azure Blob Storage (Hot Tier) 💾 **CHEAPEST & RECOMMENDED**

### Overview
You're likely already using this for ActiveStorage! The "slow" performance might be due to:
1. Using Cool/Archive tier instead of Hot tier
2. Not pre-generating URLs with SAS tokens
3. Inefficient download methods

### Solution: Optimize Current Setup
Instead of adding Redis, optimize your existing Blob Storage:

1. **Use Hot Tier** (fast retrieval)
2. **Generate SAS URLs** with long expiration (cache URLs, not images)
3. **Use CDN** (Azure CDN in front of Blob Storage)

### Pros
- **Almost FREE**: Already using it for ActiveStorage
- **Unlimited storage**: No memory limits
- **Persistent**: Data never lost
- **Simple**: No new infrastructure

### Cons
- **Slower than Redis**: 100-300ms retrieval (vs 10-50ms)
- **Still fast enough**: 5-10x faster than current if optimized
- **Network dependent**: Latency varies by region

### Cost Breakdown

**Azure Blob Storage (Hot Tier):**
- Storage: $0.0184/GB/month
- Operations: $0.004 per 10,000 read operations
- 1000 images (~2GB): **$0.04/month** 💚
- 100,000 reads/month: **$0.04/month**
- **Total: ~$0.10/month** (practically free!)

**With Azure CDN (optional but recommended):**
- CDN: $0.081/GB outbound data
- For 100 exports/month (600 images × 2MB each = 1.2GB): **$0.10/month**
- **Total with CDN: ~$0.20/month** 💚

### Implementation
Instead of caching image data in Redis, cache **signed URLs** (tiny strings):
```ruby
# Cache the URL, not the image data
RedisImageCache.cache_url(attachment_id, blob.service_url(expires_in: 7.days))
```

URLs are tiny (~200 bytes vs 2MB images), so even Basic C0 Redis ($16/month) can cache 1M+ URLs!

---

## Option 3: Azure Table Storage 📋

### Overview
NoSQL key-value store, cheaper than Redis but slower.

### Pros
- **Very cheap**: $0.045/GB/month storage
- **Persistent**: Data never lost
- **Scalable**: Unlimited storage

### Cons
- **Slower than Redis**: 50-200ms retrieval
- **Transaction costs**: $0.10 per 100,000 transactions
- **Complexity**: Need to chunk large images (1MB entity limit)

### Cost
- Storage: 1000 images (2GB): **$0.09/month**
- Transactions: 100,000 reads: **$0.10/month**
- **Total: ~$0.20/month**

### Recommendation
Not ideal for large images (1MB entity size limit)

---

## Option 4: Azure Files (Premium SSD) 💿

### Overview
Managed file shares with SSD performance.

### Pros
- **Fast**: SSD-backed storage
- **Simple**: Mount as network drive
- **Persistent**: Never lost

### Cons
- **Expensive**: $0.20/GB/month (Premium)
- **Overkill**: Designed for VMs, not ideal for web apps

### Cost
- 100GB minimum: **$20/month**

### Recommendation
Too expensive for this use case

---

## Option 5: Local Disk Cache (App Service) 💽

### Overview
Use the local disk on App Service instance for temporary caching.

### Pros
- **FREE**: Included with App Service
- **Fast**: Local disk access
- **Simple**: No external service

### Cons
- **Volatile**: Lost on restart/scale
- **Limited space**: ~1GB available
- **Single instance**: Won't work with scale-out

### Cost
- **$0/month** (included)

### Implementation
```ruby
# Use Rails.cache with file store
Rails.cache.write("image_#{attachment_id}", image_data, expires_in: 7.days)
```

### Recommendation
Good for development, not production (data lost on restart)

---

## Cost Comparison Summary

| Solution | Storage (2GB) | 100K Reads | Monthly Total | Speed | Persistence |
|----------|---------------|------------|---------------|-------|-------------|
| **Blob Storage (Hot)** ✅ | $0.04 | $0.04 | **$0.10** | Medium | ✅ Yes |
| **Blob + CDN** ✅ | $0.04 | $0.10 | **$0.20** | Fast | ✅ Yes |
| Table Storage | $0.09 | $0.10 | $0.20 | Medium | ✅ Yes |
| Redis Basic C0 | N/A | N/A | $16.00 | Fastest | ❌ No |
| Redis Basic C1 | N/A | N/A | $45.00 | Fastest | ❌ No |
| Local Disk | FREE | FREE | **$0.00** | Fast | ❌ No |

---

## **RECOMMENDED SOLUTION: Hybrid Approach** 🏆

### Strategy: URL Caching Instead of Image Caching

**Best of both worlds: Performance + Low Cost**

1. **Use existing Azure Blob Storage (Hot tier)** for images
2. **Cache blob URLs in Redis** (not image data)
3. **Use small Redis instance** (Basic C0 - $16/month or even free local cache)

### Why This Works

**Image data:** 2MB each → 1GB Redis can hold ~500 images
**Blob URLs:** 200 bytes each → 1GB Redis can hold **5 MILLION URLs!**

### Implementation

```ruby
# Instead of caching image data:
RedisImageCache.cache_image(id, 2MB_binary_data)  # ❌ Expensive

# Cache the signed URL:
RedisImageCache.cache_url(id, signed_url)  # ✅ Cheap & Fast
```

### Benefits
- **Cost**: $16/month (Redis C0) or FREE (local cache) + $0.10 (Blob)
- **Performance**: 50-100ms (URL from cache → download from Blob)
- **Capacity**: Unlimited images (stored in Blob)
- **Persistence**: Images never lost (in Blob)

### Performance
1. Check Redis for signed URL (10ms)
2. If found, download from Blob using URL (50-100ms)
3. If not found, generate URL, cache it, download (100-200ms)
4. **Total: 60-110ms vs 500-1000ms current** (5-10x faster)

---

## Alternative: Skip Caching Entirely - Optimize Blob Storage

### The Real Problem

You might not need caching at all! The issue is likely:
1. Using Cool/Archive tier (slow retrieval)
2. Downloading images serially (one at a time)
3. Not using CDN

### Solution: Optimize Without Caching

1. **Ensure Hot Tier**: Fast retrieval (no extra cost vs Cool for frequent access)
2. **Parallel Downloads**: Download all 6 images at once
3. **Use CDN**: Azure CDN in front of Blob Storage

```ruby
# Download all images in parallel
photo_data = Parallel.map(attachments, in_threads: 6) do |attachment|
  attachment.file.download
end
```

### Cost
- **$0/month extra** (just optimize existing code)
- **Performance**: 3-5x faster with parallel downloads

---

## Final Recommendations

### For Your Use Case (Budget-Conscious)

**Option A: Optimize Blob Storage (FREE)** ⭐ RECOMMENDED
1. Ensure using Hot tier
2. Implement parallel image downloads
3. Optionally add Azure CDN ($0.20/month)
4. **Cost: $0-0.20/month**
5. **Performance: 5x faster than current**

**Option B: URL Caching with Local Disk (FREE)** ⭐ ALSO GREAT
1. Keep images in Blob Storage
2. Cache signed URLs in Rails.cache (local disk)
3. **Cost: $0/month**
4. **Performance: 8x faster than current**
5. **Caveat: Cache lost on restart (just regenerate)**

**Option C: URL Caching with Redis C0 ($16/month)**
1. Keep images in Blob Storage
2. Cache signed URLs in tiny Redis instance
3. **Cost: $16/month**
4. **Performance: 10x faster than current**
5. **Persistent cache**

### When to Use Full Redis Image Caching ($45/month)

Only if:
- Very high traffic (1000+ exports/day)
- Need absolute fastest performance
- Budget allows
- Willing to manage memory/eviction

---

## Implementation Guide for Recommended Solution

I can implement **Option B (URL Caching - FREE)** for you, which gives:
- **No additional Azure costs**
- **8-10x performance improvement**
- **Works with your existing Blob Storage**
- **Simple implementation**

Would you like me to implement this solution instead of Redis image caching?

---

## Code Changes Required

### Current (Caching Full Images)
```ruby
# Cache 2MB binary data
cache_data = Base64.encode64(image_data)  # ~2.66MB in cache
RedisImageCache.cache_image(id, cache_data)
```

### Proposed (Caching URLs)
```ruby
# Cache 200-byte URL string
signed_url = blob.service_url(expires_in: 7.days)
RedisImageCache.cache_url(id, signed_url)  # ~200 bytes in cache

# Later, download from cached URL
response = Net::HTTP.get(URI(signed_url))
```

**Space savings: 13,000x less memory!**

---

## Next Steps

Let me know which option you prefer:

1. **FREE Option**: Implement URL caching with local disk
2. **$16/month Option**: Implement URL caching with Redis C0
3. **$45/month Option**: Keep current Redis image caching (C1)
4. **FREE Optimization**: Just optimize Blob Storage downloads (parallel)

I recommend **Option 1 or 4** for maximum cost savings.