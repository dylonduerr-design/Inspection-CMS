# Azure Production Setup Requirements

This document covers every service, environment variable, and configuration change
required to make all features of the app work correctly on Azure App Service.
Work through each section in order — later sections depend on earlier ones.

---

## Table of Contents

1. [Required Environment Variables — App Settings](#1-required-environment-variables--app-settings)
2. [Azure OpenAI — AI Commentary & Work Summaries](#2-azure-openai--ai-commentary--work-summaries)
3. [Redis — Background Jobs & Real-Time Progress](#3-redis--background-jobs--real-time-progress)
4. [Sidekiq — Background Worker Process](#4-sidekiq--background-worker-process)
5. [Python Runtime — Word Document Export](#5-python-runtime--word-document-export)
6. [Active Storage — Uploaded Files & Exported Docs](#6-active-storage--uploaded-files--exported-docs)
7. [Azure Entra ID (SSO) — Optional Microsoft Login](#7-azure-entra-id-sso--optional-microsoft-login)
8. [Feature → Dependency Matrix](#8-feature--dependency-matrix)
9. [Verifying Everything Is Working](#9-verifying-everything-is-working)

---

## 1. Required Environment Variables — App Settings

These environment variables must be set in the Azure App Service under
**Settings → Environment Variables** (previously called "Application Settings").

Navigate there in the Azure Portal:
> App Service → Your App → Settings → Environment Variables → App Settings

| Variable | Required | Description |
|---|---|---|
| `RAILS_ENV` | ✅ | Must be `production` |
| `SECRET_KEY_BASE` | ✅ | Random 128-char hex string — see below |
| `DATABASE_URL` | ✅ | Full PostgreSQL connection string |
| `RAILS_SERVE_STATIC_FILES` | ✅ | Set to `true` |
| `RAILS_LOG_TO_STDOUT` | ✅ | Set to `true` |
| `WEBSITES_PORT` | ✅ | Set to `80` (nginx listens on 80) |
| `AZURE_OPENAI_ENDPOINT` | ✅ for AI | See Section 2 |
| `AZURE_OPENAI_API_KEY` | ✅ for AI | See Section 2 |
| `AZURE_OPENAI_DEPLOYMENT_NAME` | ✅ for AI | See Section 2 |
| `AZURE_OPENAI_API_VERSION` | ✅ for AI | See Section 2 |
| `REDIS_URL` | ✅ for jobs/exports | See Section 3 |
| `AZURE_TENANT_ID` | Optional | See Section 7 |
| `AZURE_CLIENT_ID` | Optional | See Section 7 |
| `AZURE_CLIENT_SECRET` | Optional | See Section 7 |

### Generating SECRET_KEY_BASE

Run this locally and copy the output:

```bash
openssl rand -hex 64
```

Or use the Azure CLI one-liner when deploying:

```bash
export SECRET_KEY_BASE=$(openssl rand -hex 64)
```

### Setting All Variables via Azure CLI

```bash
az webapp config appsettings set \
  --name $APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --settings \
    RAILS_ENV=production \
    RAILS_SERVE_STATIC_FILES=true \
    RAILS_LOG_TO_STDOUT=true \
    WEBSITES_PORT=80 \
    WEBSITES_CONTAINER_START_TIME_LIMIT=600 \
    SECRET_KEY_BASE="<your-generated-key>" \
    DATABASE_URL="<your-database-url>" \
    REDIS_URL="<your-redis-url>" \
    AZURE_OPENAI_ENDPOINT="<your-endpoint>" \
    AZURE_OPENAI_API_KEY="<your-key>" \
    AZURE_OPENAI_DEPLOYMENT_NAME="<your-deployment>" \
    AZURE_OPENAI_API_VERSION="2024-12-01-preview"
```

---

## 2. Azure OpenAI — AI Commentary & Work Summaries

**Affected features:** Generate Commentary, Generate Work Summary, all Weekly Report
AI sections (weather, lab testing, materials, problem areas, work summary).

**What happens without it:** The app falls back to `FakeGenerator`, which returns
placeholder text instead of real AI output. No error is thrown, but the output
will not be meaningful.

### Required Env Vars

| Variable | Example Value | Where to Find It |
|---|---|---|
| `AZURE_OPENAI_ENDPOINT` | `https://your-resource.openai.azure.com/` | Azure Portal → Azure OpenAI resource → Keys and Endpoint |
| `AZURE_OPENAI_API_KEY` | `abc123...` | Same page — Key 1 or Key 2 |
| `AZURE_OPENAI_DEPLOYMENT_NAME` | `gpt-5-nano` | Azure OpenAI Studio → Deployments tab |
| `AZURE_OPENAI_API_VERSION` | `2024-12-01-preview` | Match the API version your deployment supports |

### Important Notes

- The `AZURE_OPENAI_ENDPOINT` must be the **base resource URL only** —
  no `/openai/...` path, no `?api-version=` query string.
  ✅ Correct: `https://your-resource.openai.azure.com/`
  ❌ Wrong:   `https://your-resource.openai.azure.com/openai/deployments/...`

- The deployment must support chat completions (the `/chat/completions` endpoint).
  Standard GPT-3.5/GPT-4/GPT-4o models all work. Verify the deployment exists
  and is live in **Azure OpenAI Studio → Deployments**.

- AI calls have a 180-second timeout. If the Azure OpenAI resource is in a
  different region from the App Service, latency may cause timeouts on long reports.
  Place both in the same Azure region (e.g., `westus3`).

---

## 3. Redis — Background Jobs & Real-Time Progress

**Affected features:** ALL background jobs (AI generation, Word document export),
AND real-time export progress bar via ActionCable.

**What happens without it:** Attempting to generate AI content or export a report
will fail immediately with:
```
❌ Error: Cannot assign requested address - connect(2) for [::1]:6379 (redis://localhost:6379)
```
This is because `REDIS_URL` is not set, so the code falls back to
`redis://localhost:6379`, but Redis is not running in the container.

### Step 1 — Create Azure Cache for Redis

```bash
az redis create \
  --name geometrics-icms-redis \
  --resource-group $RESOURCE_GROUP \
  --location $LOCATION \
  --sku Basic \
  --vm-size C0
```

This takes 10–15 minutes to provision.

### Step 2 — Get the Connection String

```bash
# Get the primary key
REDIS_KEY=$(az redis list-keys \
  --name geometrics-icms-redis \
  --resource-group $RESOURCE_GROUP \
  --query primaryKey -o tsv)

# Build the connection URL (Azure Redis requires SSL on port 6380)
REDIS_URL="rediss://:${REDIS_KEY}@geometrics-icms-redis.redis.cache.windows.net:6380"

echo $REDIS_URL
```

> **Note:** Azure Cache for Redis uses `rediss://` (with two s's) for SSL on port
> **6380**, not `redis://` on 6379. Using the wrong scheme will fail.

### Step 3 — Add to App Settings

```bash
az webapp config appsettings set \
  --name $APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --settings REDIS_URL="$REDIS_URL"
```

---

## 4. Sidekiq — Background Worker Process

**Affected features:** ALL AI generation, ALL Word document exports.

**What happens without it:** Even with Redis running, jobs get enqueued into
Redis but nothing processes them. The UI will show "pending" status forever — no
AI text will be generated, no .docx files will be created.

Sidekiq is already configured to run as a third Supervisor process in
[Dockerfile.combined](../Dockerfile.combined) alongside nginx and Rails.
Ensure `REDIS_URL` is set in App Settings before deploying — Sidekiq will
fail to start without it.

### Verifying Sidekiq Is Running

After the container restarts, SSH in and check supervisor:

```bash
az webapp ssh --name $APP_NAME --resource-group $RESOURCE_GROUP
# Inside the container:
supervisorctl status
```

You should see all three processes as `RUNNING`:
```
nginx     RUNNING   pid 12, uptime 0:01:23
rails     RUNNING   pid 34, uptime 0:01:21
sidekiq   RUNNING   pid 56, uptime 0:01:20
```

---

## 5. Python Runtime — Word Document Export

**Affected features:** Export Report to Word (.docx), Export Weekly Report.

**What happens without it:** The export job runs, calls Python, and fails with an
error like `python3: command not found` or `ModuleNotFoundError: No module named 'docxtpl'`.

### How It Works

The `PythonDocxExporter` service calls `python3 python/export_report.py` directly
inside the container. It requires:

1. `python3` to be installed in the container OS
2. Three Python packages: `docxtpl`, `python-docx`, `Pillow`
3. The Word template file at `app/assets/documents/inspection_template.docx`

### The Problem

The current `Dockerfile.combined` does **not** install Python or its packages.

### Fix 1 — Install Python in Dockerfile.combined

In the runtime stage of [Dockerfile.combined](../Dockerfile.combined), add `python3`,
`python3-pip`, and `python3-venv` to the `apt-get install` line:

```dockerfile
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
    curl libvips postgresql-client nginx openssl supervisor \
    python3 python3-pip python3-venv && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives
```

### Fix 2 — Install Python Packages in Dockerfile.combined

After the Python install, add a step to set up the venv and install packages.
Add this after the `apt-get install` block:

```dockerfile
# Install Python packages for docx export
RUN python3 -m venv /rails/.venv && \
    /rails/.venv/bin/pip install --no-cache-dir \
    docxtpl==0.18.0 \
    "python-docx>=1.1.1" \
    "Pillow==10.2.0"
```

The `PythonDocxExporter` service already looks for `.venv/bin/python3` first
and falls back to system `python3` — so the venv path is handled automatically.

### Fix 3 — Verify the Template Exists

The template file must be present in the image. Confirm it exists locally before
building:

```bash
ls app/assets/documents/inspection_template.docx
```

Since the Dockerfile copies the entire application (`COPY . .`), it will be
included automatically as long as it is committed to the repository and not in
`.gitignore` or `.dockerignore`.

---

## 6. Active Storage — Uploaded Files & Exported Docs

**Affected features:** Report photos, exported .docx file downloads.

**What happens without it (current state):** Files are stored on the container's
local disk (`storage/` directory). Azure App Service containers have an
**ephemeral filesystem** — all local files are wiped whenever the container
restarts or redeploys. This means:
- Previously uploaded photos will disappear after a restart
- Exported .docx files will be lost before users can download them

### Recommended Fix — Azure Blob Storage

#### Step 1 — Create a Storage Account

```bash
az storage account create \
  --name geometricsicmsstorage \
  --resource-group $RESOURCE_GROUP \
  --location $LOCATION \
  --sku Standard_LRS
```

#### Step 2 — Create a Container

```bash
az storage container create \
  --name cms-uploads \
  --account-name geometricsicmsstorage \
  --public-access off
```

#### Step 3 — Get the Access Key

```bash
STORAGE_KEY=$(az storage account keys list \
  --account-name geometricsicmsstorage \
  --resource-group $RESOURCE_GROUP \
  --query "[0].value" -o tsv)
```

#### Step 4 — Add Azure Storage Gem

In [Gemfile](../Gemfile), uncomment or add:

```ruby
gem "azure-storage-blob", require: false
```

Then run `bundle install`.

#### Step 5 — Configure storage.yml

In [config/storage.yml](../config/storage.yml), uncomment and fill in the
`microsoft` block:

```yaml
microsoft:
  service: AzureStorage
  storage_account_name: geometricsicmsstorage
  storage_access_key: <%= ENV.fetch("AZURE_STORAGE_ACCESS_KEY") %>
  container: cms-uploads
```

#### Step 6 — Switch production.rb to use it

In [config/environments/production.rb](../config/environments/production.rb),
change:

```ruby
config.active_storage.service = :local
```
to:
```ruby
config.active_storage.service = :microsoft
```

#### Step 7 — Add the env var

```bash
az webapp config appsettings set \
  --name $APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --settings AZURE_STORAGE_ACCESS_KEY="$STORAGE_KEY"
```

---

## 7. Azure Entra ID (SSO) — Optional Microsoft Login

**Affected features:** "Sign in with Microsoft" button on the login page.

**What happens without it:** The Microsoft SSO button will not appear on the login
page. Users can still log in normally with email and password. This is safe to
leave unconfigured if SSO is not needed.

### Step 1 — Create an App Registration in Entra ID

1. Go to **Azure Portal → Microsoft Entra ID → App registrations → New registration**
2. Set the **Name** to something like `Geometrics ICMS`
3. Under **Supported account types**, choose:
   - **Single tenant** if only your organization's accounts should be allowed
   - **Multitenant** if users from any organization can log in
4. Set the **Redirect URI** to:
   ```
   https://<your-app>.azurewebsites.net/users/auth/microsoft_graph/callback
   ```
5. Click **Register**

### Step 2 — Get the Required Values

After registration, from the **Overview** page:

| Value | Where to Find It | Env Var |
|---|---|---|
| **Application (client) ID** | Overview → Application (client) ID | `AZURE_CLIENT_ID` |
| **Directory (tenant) ID** | Overview → Directory (tenant) ID | `AZURE_TENANT_ID` |
| **Client Secret** | Certificates & secrets → New client secret | `AZURE_CLIENT_SECRET` |

> For the Client Secret: go to **Certificates & secrets → Client secrets →
> New client secret**. Copy the **Value** (not the Secret ID) immediately —
> it is only shown once.

### Step 3 — Grant API Permissions

In the App Registration, go to **API permissions → Add a permission →
Microsoft Graph → Delegated permissions** and add:

- `User.Read`
- `email`
- `profile`
- `openid`

Click **Grant admin consent** (requires admin privileges).

### Step 4 — Add to App Settings

```bash
az webapp config appsettings set \
  --name $APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --settings \
    AZURE_TENANT_ID="<directory-tenant-id>" \
    AZURE_CLIENT_ID="<application-client-id>" \
    AZURE_CLIENT_SECRET="<client-secret-value>"
```

### Tenant Lock-Down Note

The app enforces single-tenant login — the `AZURE_TENANT_ID` is checked against
the token's `tid` claim. Only users from the configured tenant can authenticate
via SSO. Users from other tenants will see: _"Sign-in is restricted to your
organization."_

---

## 8. Feature → Dependency Matrix

Use this table to quickly identify what must be set up to enable a given feature.

| Feature | Redis | Sidekiq | Azure OpenAI Vars | Python + venv | Azure Blob | SSO Vars |
|---|:---:|:---:|:---:|:---:|:---:|:---:|
| Login (email/password) | — | — | — | — | — | — |
| Login with Microsoft | — | — | — | — | — | ✅ |
| View / edit reports | — | — | — | — | — | — |
| Upload photos | — | — | — | — | ⚠️* | — |
| Generate AI Commentary | ✅ | ✅ | ✅ | — | — | — |
| Generate AI Work Summary | ✅ | ✅ | ✅ | — | — | — |
| Generate Weekly Report AI | ✅ | ✅ | ✅ | — | — | — |
| Export Report to .docx | ✅ | ✅ | — | ✅ | ⚠️* | — |
| Download exported .docx | — | — | — | — | ⚠️* | — |
| Real-time export progress bar | ✅ | ✅ | — | — | — | — |

> ⚠️ *Without Azure Blob Storage, uploads and exports work but are lost on container restart.

---

## 9. Verifying Everything Is Working

### Check Overall App Health

```bash
az webapp log tail --name $APP_NAME --resource-group $RESOURCE_GROUP
```

Look for the Puma startup line:
```
Listening on http://0.0.0.0:3000
```

### Check Sidekiq Is Running

```bash
az webapp ssh --name $APP_NAME --resource-group $RESOURCE_GROUP
supervisorctl status
```

All three should show `RUNNING`: nginx, rails, sidekiq.

### Check Redis Connection

Inside the container SSH session:

```bash
cd /rails
bundle exec rails runner "Redis.new(url: ENV['REDIS_URL']).ping"
```

Expected output: `PONG`

### Check Azure OpenAI Configuration

Inside the container:

```bash
cd /rails
bundle exec rails runner "puts ReportAi::Generator.azure_configured?"
```

Expected output: `true`

### Check Python Export Works

Inside the container:

```bash
cd /rails
python3 --version
.venv/bin/python3 -c "import docxtpl; print('docxtpl OK')"
```

### Check Active Storage

Upload a photo to a report and restart the container:

```bash
az webapp restart --name $APP_NAME --resource-group $RESOURCE_GROUP
```

If the photo is still there after restart, Azure Blob Storage is working.
If it is gone, the app is still using local disk storage.

---

*Document Version: 1.0 — Last Updated: 2026-03-02*
