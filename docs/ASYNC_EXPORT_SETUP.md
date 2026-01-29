# Async Word Export - Setup Guide

## Overview
The Word export functionality has been upgraded to use background jobs with real-time progress updates. When a user clicks "Export Word", the button transforms into a progress bar showing the export stages, and then becomes a download button when complete.

## What Was Added

### Backend Components
1. **ReportExport Model** - Tracks export status, progress, and stores the generated DOCX file
2. **ReportExportJob** - Background job that runs the export and broadcasts progress
3. **ReportExportsController** - Handles export status checks and downloads
4. **ReportExportChannel** - ActionCable channel for real-time progress updates

### Frontend Components
1. **Stimulus Controller** (`report_export_controller.js`) - Manages UI state and progress updates
2. **ActionCable Consumer** - Connects to the WebSocket channel for real-time updates

### Configuration
1. **Sidekiq** - Background job processor
2. **Redis** - Message queue and ActionCable adapter
3. **ActiveStorage** - Stores generated DOCX files

## How to Run

### Development

You need to run **3 processes** simultaneously:

#### 1. Redis Server
```bash
redis-server
```

If Redis is not installed:
- **macOS**: `brew install redis && brew services start redis`
- **Ubuntu/Debian**: `sudo apt-get install redis-server && sudo systemctl start redis`
- **Or use Docker**: `docker run -p 6379:6379 redis:latest`

#### 2. Rails Web Server
```bash
bundle exec rails server
```

#### 3. Sidekiq Worker
In a separate terminal:
```bash
bundle exec sidekiq
```

### Production Deployment

You'll need to run these as separate services/processes:

#### Using Docker Compose (Recommended)
Create a `docker-compose.yml`:
```yaml
version: '3.8'
services:
  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data

  web:
    build: .
    command: bundle exec puma -C config/puma.rb
    ports:
      - "3000:3000"
    environment:
      REDIS_URL: redis://redis:6379/0
      DATABASE_URL: ${DATABASE_URL}
    depends_on:
      - redis
      - db

  worker:
    build: .
    command: bundle exec sidekiq
    environment:
      REDIS_URL: redis://redis:6379/0
      DATABASE_URL: ${DATABASE_URL}
    depends_on:
      - redis
      - db

  db:
    image: postgres:15
    environment:
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
    volumes:
      - postgres_data:/var/lib/postgresql/data

volumes:
  redis_data:
  postgres_data:
```

Then run:
```bash
docker-compose up
```

#### Using Procfile (for Heroku/Render)
Create a `Procfile`:
```
web: bundle exec puma -C config/puma.rb
worker: bundle exec sidekiq
```

And configure the Redis add-on in your platform dashboard.

#### Using systemd (Linux VPS)
Create service files:

**/etc/systemd/system/inspection-cms-web.service**:
```ini
[Unit]
Description=Inspection CMS Web
After=network.target

[Service]
Type=simple
User=deploy
WorkingDirectory=/var/www/inspection_cms
Environment=RAILS_ENV=production
Environment=REDIS_URL=redis://localhost:6379/0
ExecStart=/usr/local/bin/bundle exec puma -C config/puma.rb
Restart=always

[Install]
WantedBy=multi-user.target
```

**/etc/systemd/system/inspection-cms-worker.service**:
```ini
[Unit]
Description=Inspection CMS Sidekiq Worker
After=network.target redis.service

[Service]
Type=simple
User=deploy
WorkingDirectory=/var/www/inspection_cms
Environment=RAILS_ENV=production
Environment=REDIS_URL=redis://localhost:6379/0
ExecStart=/usr/local/bin/bundle exec sidekiq
Restart=always

[Install]
WantedBy=multi-user.target
```

Enable and start:
```bash
sudo systemctl enable inspection-cms-web
sudo systemctl enable inspection-cms-worker
sudo systemctl start inspection-cms-web
sudo systemctl start inspection-cms-worker
```

## Environment Variables

Set these in your environment:

- `REDIS_URL` - Redis connection string (default: `redis://localhost:6379/0`)
- `RAILS_ENV` - Set to `production` in production

## How It Works (User Flow)

1. User clicks "Export Word" button on a report
2. Button transforms into a progress bar
3. Progress updates in real-time:
   - 5%: Starting export
   - 20%: Preparing report data
   - 40%: Generating Word document (Python/Ruby exporter runs)
   - 80%: Saving document to ActiveStorage
   - 100%: Complete
4. Progress bar transforms into a "Download Export" button
5. User clicks to download the generated DOCX file

## Monitoring

### View Sidekiq Dashboard (Optional)
Add to your `config/routes.rb`:
```ruby
require 'sidekiq/web'
mount Sidekiq::Web => '/sidekiq' # Protect this in production!
```

Access at: `http://localhost:3000/sidekiq`

### Check Job Status
```bash
# Rails console
bundle exec rails console

# Check recent exports
ReportExport.recent.limit(10)

# Check failed exports
ReportExport.where(status: 'failed')
```

## Cleanup

Old export files can accumulate. Add a cleanup task:

**lib/tasks/cleanup.rake**:
```ruby
namespace :exports do
  desc "Delete exports older than 7 days"
  task cleanup: :environment do
    ReportExport.where("created_at < ?", 7.days.ago).find_each do |export|
      export.file.purge if export.file.attached?
      export.destroy
    end
  end
end
```

Run manually:
```bash
bundle exec rake exports:cleanup
```

Or schedule with cron:
```
0 2 * * * cd /var/www/inspection_cms && bundle exec rake exports:cleanup RAILS_ENV=production
```

## Troubleshooting

### "Can't connect to Redis"
- Ensure Redis is running: `redis-cli ping` (should return `PONG`)
- Check `REDIS_URL` environment variable

### "Export stuck at 0%"
- Ensure Sidekiq worker is running: `ps aux | grep sidekiq`
- Check Sidekiq logs for errors

### "Progress bar not updating"
- Check browser console for WebSocket connection errors
- Ensure ActionCable is configured correctly in `config/cable.yml`
- Verify Redis is running (ActionCable uses it for pub/sub)

### "Export failed" error
- Check Sidekiq logs: `tail -f log/sidekiq.log` (if configured)
- Check Rails logs: `tail -f log/production.log`
- Common issues:
  - Missing template file
  - Python script errors
  - File permission issues

## Performance Tuning

### Sidekiq Concurrency
By default, Sidekiq runs multiple jobs concurrently. For photo-heavy exports, limit concurrency:

**config/sidekiq.yml**:
```yaml
:concurrency: 1  # Only 1 export at a time
:queues:
  - default
```

Then run: `bundle exec sidekiq -C config/sidekiq.yml`

### Storage Location
For production with multiple servers, use S3 instead of local disk:

**config/storage.yml**:
```yaml
amazon:
  service: S3
  access_key_id: <%= ENV['AWS_ACCESS_KEY_ID'] %>
  secret_access_key: <%= ENV['AWS_SECRET_ACCESS_KEY'] %>
  region: us-east-1
  bucket: your-bucket-name
```

**config/environments/production.rb**:
```ruby
config.active_storage.service = :amazon
```

## Cost Estimates (for ~30 users, 15 exports/day)

### Using managed services:
- **Redis** (Heroku/AWS): $15-30/month (small instance)
- **S3 Storage**: ~$1-2/month (22GB retention @ $0.023/GB)
- **Worker dyno/instance**: $25-50/month (same size as web server)

### Using single VPS:
- **Everything on one server**: No additional cost
- Just need slightly more RAM (4-8 GB total recommended)

## Next Steps

1. Test the export in development
2. Monitor performance and adjust Sidekiq concurrency if needed
3. Set up export cleanup task (7-14 day retention recommended)
4. Consider adding retry limits and better error messages
5. Add email notifications for completed/failed exports (optional)
