# Azure OpenAI Model Setup Guide

**Audience:** IT Administrator
**Purpose:** Step-by-step instructions to deploy a new Azure OpenAI model for the Inspection CMS application.
**Current state:** GPT 5mini is deployed and working. We are adding a GPT 5.3 deployment to replace it.

---

## What you'll be doing

The Inspection CMS app calls Azure OpenAI to generate AI-assisted content in inspection reports. The app connects to a specific **model deployment** in your Azure OpenAI resource. To switch models, you will:

1. Create a new deployment of GPT 5.3 in the Azure portal
2. Update one environment variable on the server (`AZURE_OPENAI_DEPLOYMENT_NAME`)
3. Optionally update the API version
4. Verify the new model is working

The endpoint URL and API key stay the same — they belong to the Azure OpenAI **resource**, not the individual model deployment.

---

## Prerequisites

- Access to the [Azure Portal](https://portal.azure.com)
- **Owner** or **Contributor** role on the Azure OpenAI resource that currently hosts the GPT 5mini deployment
- Access to the server or hosting environment where the app's environment variables are configured
- GPT 5.3 must be available in your Azure OpenAI resource's region. If it's not listed when you try to deploy, you may need to request access or use a different region.

---

## Step 1: Open your Azure OpenAI resource

1. Sign in to the [Azure Portal](https://portal.azure.com).
2. In the search bar at the top, type **"Azure OpenAI"** and select **Azure OpenAI** from the results.
3. Click on the resource that currently hosts your GPT 5mini deployment.
   - If you're not sure which one, check the current `AZURE_OPENAI_ENDPOINT` environment variable on the server. The resource name is the subdomain (e.g., `https://my-resource.openai.azure.com/` means the resource is called `my-resource`).

---

## Step 2: Create the GPT 5.3 deployment

1. In the left sidebar of your Azure OpenAI resource, click **Model deployments** (under "Resource Management").
2. Click **+ Create new deployment**.
3. Fill in the deployment form:

   | Field | Value | Notes |
   |-------|-------|-------|
   | **Model** | `gpt-5.3` | Select from the dropdown. If you don't see it, check region availability. |
   | **Deployment name** | `gpt-53` | This is the name the app will reference. Use something short and clear — no spaces. |
   | **Deployment type** | Standard | Use "Standard" unless you have a specific reason for "Provisioned". |
   | **Tokens per Minute (TPM)** | 80K+ recommended | The app sends large payloads (full inspection reports). 80K TPM should handle typical usage. You can increase this later if you see throttling (HTTP 429 errors). |
   | **Content filter** | Default | Leave the default content filter. The app sends construction inspection data, so it should not trigger filters. |

4. Click **Create** and wait for the deployment to complete (usually under a minute).

> **Do not delete the old GPT 5mini deployment yet.** Keep it as a fallback until you've verified GPT 5.3 is working correctly.

---

## Step 3: Update the application environment variable

You only need to change **one** environment variable:

```
AZURE_OPENAI_DEPLOYMENT_NAME=gpt-53
```

Replace `gpt-53` with whatever deployment name you chose in Step 2.

### Where to change it

This depends on how the app is hosted:

- **Docker / docker-compose:** Update the `.env` file on the server, then restart the containers (`docker-compose down && docker-compose up -d`).
- **Azure App Service:** Go to the App Service in the Azure Portal > **Configuration** > **Application settings** > find `AZURE_OPENAI_DEPLOYMENT_NAME` > update the value > click **Save** (this will restart the app).
- **Linux server (systemd / manual):** Edit the `.env` file in the app directory, then restart the Rails server and Sidekiq.

### What NOT to change

These existing environment variables stay the same:

| Variable | Why it doesn't change |
|----------|----------------------|
| `AZURE_OPENAI_ENDPOINT` | This is the resource URL, not deployment-specific |
| `AZURE_OPENAI_API_KEY` | The API key belongs to the resource, not the deployment |
| `AZURE_OPENAI_API_VERSION` | Current value (`2024-12-01-preview`) works with GPT 5.3. Only update if Azure documentation recommends a newer version for 5.3 features. |

### Optional: Update the API version

If you want to use a newer API version (check [Azure OpenAI API version docs](https://learn.microsoft.com/en-us/azure/ai-services/openai/api-version-deprecation) for the latest stable version):

```
AZURE_OPENAI_API_VERSION=2025-04-01-preview
```

This is optional. The current version will continue to work.

---

## Step 4: Restart the application

After changing the environment variable, restart both services:

1. **Rails web server** (Puma) — so the new deployment name is picked up on next AI request
2. **Sidekiq** (background jobs) — AI generation runs as background jobs through Sidekiq

If using Docker:
```bash
docker-compose restart web sidekiq
```

If using systemd:
```bash
sudo systemctl restart inspection-cms inspection-cms-sidekiq
```

---

## Step 5: Verify it's working

1. **Log in** to the Inspection CMS app as an inspector.
2. Open any report that is in **"In Progress"** or **"Revise"** status.
3. Click **Edit**, scroll to the **AI-Assisted Content** section.
4. Click **"Generate Commentary"**.
5. Wait for the generation to complete (status will show "running" then "success").
6. Verify the generated text appears in the commentary field.

### If it fails

Check the Rails logs for error details:

```bash
# Docker
docker-compose logs web --tail=50

# Linux server
tail -50 /path/to/app/log/production.log
```

Common issues:

| Error | Cause | Fix |
|-------|-------|-----|
| `Azure API error (404): DeploymentNotFound` | Deployment name doesn't match | Double-check `AZURE_OPENAI_DEPLOYMENT_NAME` matches exactly what you named it in Step 2 |
| `Azure API error (401): Access denied` | API key issue | Verify `AZURE_OPENAI_API_KEY` hasn't changed — regenerate from the Azure Portal if needed |
| `Azure API error (429): Rate limit exceeded` | TPM too low | Increase the Tokens Per Minute quota on the deployment in Azure Portal |
| `Azure API error (400): model not available` | Model not deployed in region | Confirm the deployment completed successfully in Azure Portal |
| `Response exceeded token limit` | Output too large | This is a known edge case with very large reports — not model-related |
| App falls back to fake/test data | Env vars not loaded | Restart both Puma and Sidekiq; check logs for the `[ReportAi] Azure OpenAI not configured` warning |

---

## Step 6: Clean up the old deployment (optional, after validation)

Once you've confirmed GPT 5.3 is working in production for a few days:

1. Go back to your Azure OpenAI resource in the Azure Portal.
2. Click **Model deployments**.
3. Find the old GPT 5mini deployment.
4. Click the **...** menu > **Delete deployment**.

This frees up the TPM quota allocated to the old deployment.

---

## Quick reference: All environment variables

For reference, here are all the AI-related environment variables and their current expected values after the switch:

```
AZURE_OPENAI_ENDPOINT=https://your-resource.openai.azure.com/
AZURE_OPENAI_API_KEY=(unchanged — your existing key)
AZURE_OPENAI_DEPLOYMENT_NAME=gpt-53
AZURE_OPENAI_API_VERSION=2024-12-01-preview
```

---

## Questions?

If you run into issues not covered here, the full AI architecture documentation is in `docs/AI_AGENT.md`. For application-level troubleshooting, see `docs/DEPLOYMENT_CHECKLIST.md`.
