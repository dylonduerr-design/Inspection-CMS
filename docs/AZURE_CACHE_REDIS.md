# Azure Cache for Redis — Setup Guide

This guide walks through provisioning Azure Cache for Redis via the Azure Portal and connecting it to the Inspection CMS application.

---

## Why Redis Is Needed

The export system requires Redis for two things:

1. **Sidekiq** — background job queue (processes `ReportExportJob`)
2. **ActionCable** — real-time WebSocket updates (export progress bar)

Without `REDIS_URL` set, the app falls back to in-process `async` adapters, which means:
- Jobs run synchronously in the web process (blocks requests)
- ActionCable pub/sub only works within a single Puma process (unreliable with multiple workers)

---

## Step 1: Create the Redis Cache

1. Sign in to [portal.azure.com](https://portal.azure.com)
2. In the top search bar, type **"Azure Cache for Redis"** and select it
3. Click **+ Create**
4. Fill in the **Basics** tab:

| Setting | Value |
|---------|-------|
| **Subscription** | Your Azure subscription |
| **Resource Group** | Same resource group as your Container App / App Service |
| **DNS Name** | `icms-redis` (or any unique name) |
| **Location** | Same region as your app (e.g., West US 2) |
| **Cache SKU** | **Basic** |
| **Cache Size** | **C0 (250 MB)** — sufficient for job queues and pub/sub |
| **Redis Version** | **6** |

5. Click **Review + Create**, then **Create**
6. Wait for deployment to complete (typically 5–15 minutes)

> **Cost**: Basic C0 is ~$16/month. For production with high availability, consider **Standard C0** (~$40/month) which includes replication.

---

## Step 2: Get the Connection String

1. Once the Redis cache is deployed, navigate to it in the Azure Portal
2. In the left sidebar, go to **Settings → Access keys**
3. Copy the **Primary connection string** — it will look like:
   ```
   icms-redis.redis.cache.windows.net:6380,password=XXXXXXXXXXXXXXXX,ssl=True,abortConnect=False
   ```
4. You need to convert this to a Redis URL format for Rails:
   ```
   rediss://:YOUR_PASSWORD@icms-redis.redis.cache.windows.net:6380/0
   ```

   **Important notes:**
   - Use `rediss://` (double `s`) — this enables TLS/SSL
   - The password goes after the colon in `:PASSWORD@`
   - Port `6380` is the SSL port (not the default `6379`)
   - `/0` at the end selects Redis database 0

---

## Step 3: Configure the Application

### For Azure Container App

1. Go to your **Container App** in the Azure Portal
2. Navigate to **Settings → Environment variables**
3. Add or update the following variable:

| Name | Value |
|------|-------|
| `REDIS_URL` | `rediss://:YOUR_PASSWORD@icms-redis.redis.cache.windows.net:6380/0` |

4. Click **Save** — the container will restart automatically

### For Azure App Service

1. Go to your **App Service** in the Azure Portal
2. Navigate to **Settings → Configuration → Application settings**
3. Click **+ New application setting**:

| Name | Value |
|------|-------|
| `REDIS_URL` | `rediss://:YOUR_PASSWORD@icms-redis.redis.cache.windows.net:6380/0` |

4. Click **Save** and confirm the restart

### For Docker / docker-compose

Add the environment variable to your container:

```yaml
environment:
  REDIS_URL: "rediss://:YOUR_PASSWORD@icms-redis.redis.cache.windows.net:6380/0"
```

Or pass it at runtime:

```bash
docker run -e REDIS_URL="rediss://:YOUR_PASSWORD@icms-redis.redis.cache.windows.net:6380/0" ...
```

---

## Step 4: Verify the Connection

After the app restarts with the new `REDIS_URL`:

### Check Rails Console

```bash
rails console
```

```ruby
# Test Redis connection
Redis.new(url: ENV['REDIS_URL'], ssl_params: { verify_mode: OpenSSL::SSL::VERIFY_NONE }).ping
# => "PONG"

# Check ActionCable adapter
ActionCable.server.config.cable
# Should show: {"adapter"=>"redis", "url"=>"rediss://..."}

# Check Active Job adapter
Rails.application.config.active_job.queue_adapter
# Should show: :sidekiq
```

### Check Sidekiq Dashboard (if enabled)

Navigate to `/sidekiq` in your browser to verify Sidekiq is connected and processing jobs.

### Test an Export

1. Go to any report in the app
2. Click the **Export** button
3. You should see:
   - Progress bar updating in real-time (ActionCable working)
   - Export completing successfully (Sidekiq + Python exporter working)
   - Download link appearing when done

---

## Networking / Firewall

By default, Azure Cache for Redis is accessible from other Azure services in the same subscription. If you have network restrictions:

1. Go to your Redis cache → **Settings → Private endpoint** or **Firewall**
2. Ensure your Container App / App Service can reach the Redis instance
3. For VNet-integrated apps, you may need a **Private Endpoint** for the Redis cache

---

## Troubleshooting

### "Error connecting to Redis on localhost:6379"
- `REDIS_URL` is not set or not being read. Verify the environment variable is saved and the container has restarted.

### "SSL_connect returned=1 errno=0 state=error: certificate verify failed"
- The app's Sidekiq initializer already disables SSL verification for Azure (`verify_mode: OpenSSL::SSL::VERIFY_NONE`). If you still see this, ensure you're using `rediss://` (not `redis://`).

### "NOAUTH Authentication required"
- The password in the connection string is wrong. Re-copy it from **Access keys** in the portal.

### Export starts but no progress updates
- ActionCable may be using the `async` adapter instead of Redis. Check that `REDIS_URL` is set and restart the app.
- Check that your reverse proxy (nginx) is forwarding WebSocket upgrade headers (the included `nginx.conf` already handles this).

### Export stays "queued" forever
- Sidekiq is not running or not connected to Redis. Check container logs for Sidekiq startup messages.
- Verify with: `Sidekiq::Queue.new.size` in the Rails console.
