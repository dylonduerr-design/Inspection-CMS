# SharePoint Photo Storage — IT Admin Setup Guide

## What This Is About

The Inspection CMS app lets inspectors attach photos to their reports. Right now, those photos are stored on the web server's hard drive. The problem is that Azure (the cloud service hosting the app) can erase that hard drive during restarts, which means **photos get lost**.

To fix this, we're moving photo storage into your organization's **SharePoint**. SharePoint is Microsoft's cloud-based file storage system — the same place your team stores shared documents. Photos will be uploaded to a specific SharePoint folder (called a "Document Library") via Microsoft's **Graph API** (a set of commands that lets our app talk to SharePoint automatically on behalf of your organization).

For this to work, we need you to set up a couple of things in the Azure Portal and SharePoint, and then send us some configuration values to plug into the app. This guide walks through every step.

---

## What You'll Need Before Starting

- **Admin access** to your organization's [Azure Portal](https://portal.azure.com) (specifically the "Microsoft Entra ID" section, which used to be called "Azure Active Directory")
- **Admin access** to your organization's SharePoint (to create a Document Library)
- About 30 minutes

---

## Step 1: Create a SharePoint Site and Document Library

A **Document Library** is just a folder structure inside SharePoint where files are stored. We need one specifically for inspection photos.

### 1.1 — Go to SharePoint

1. Open your browser and go to your organization's SharePoint. The URL is usually something like `https://yourcompany.sharepoint.com`
2. If you're not sure of the URL, go to [office.com](https://office.com), sign in, and click the SharePoint icon in the app launcher (the grid of dots in the top-left)

### 1.2 — Create a new site (or use an existing one)

If your organization already has a SharePoint site you'd like to use for this app (for example, an "Engineering" or "Inspections" site), you can skip to step 1.3.

To create a new site:
1. Click **"+ Create site"** on the SharePoint home page
2. Choose **"Team site"**
3. Give it a name like **"Inspection CMS"**
4. Set the privacy to **Private** (only members can access)
5. Click **Create**

### 1.3 — Create the Document Library

1. Open the SharePoint site you want to use
2. Click **"+ New"** in the top menu bar → **"Document library"**
3. Name it **"InspectionPhotos"** (no spaces — this makes the technical setup easier)
4. Click **Create**

The app will automatically create subfolders inside this library organized by project name and report, like:
```
InspectionPhotos/
  ├── Highway 101 Reconstruction/
  │     ├── 2026-03-10_Report42/
  │     │     ├── photo1.jpg
  │     │     └── photo2.jpg
  │     └── 2026-03-11_Report43/
  │           └── photo1.jpg
  └── Bridge Deck Repair Project/
        └── ...
```

### 1.4 — Get the Site ID and Drive ID

These are two identifiers the app needs to know *which* SharePoint site and *which* Document Library to upload photos to. You don't have to understand what they mean — just follow these steps to find them.

**To find the Site ID:**
1. In your browser, go to this URL (replace `yourcompany` and `YourSiteName` with your actual values):
   ```
   https://yourcompany.sharepoint.com/sites/YourSiteName/_api/site/id
   ```
   For example, if your company is "acmecorp" and the site is "InspectionCMS":
   ```
   https://acmecorp.sharepoint.com/sites/InspectionCMS/_api/site/id
   ```
2. You'll see a page with some text. Look for a value that looks like this: `d4a5b6c7-8901-2345-6789-abcdef012345`. That's your **Site ID**.
3. Copy it and save it somewhere — you'll send it to us later.

**To find the Drive ID:**
1. This one is a bit trickier. The easiest method is through the **Graph Explorer** tool (a free Microsoft tool for testing API calls):
   - Go to [https://developer.microsoft.com/en-us/graph/graph-explorer](https://developer.microsoft.com/en-us/graph/graph-explorer)
   - Sign in with your admin account (click the person icon on the left sidebar)
   - In the request box at the top, type:
     ```
     https://graph.microsoft.com/v1.0/sites/{your-site-id}/drives
     ```
     Replace `{your-site-id}` with the Site ID you found above.
   - Click **"Run query"**
   - In the results at the bottom, find the drive whose `"name"` matches your Document Library name (e.g., `"InspectionPhotos"`). Copy the `"id"` value from that entry — that's your **Drive ID**.

2. If you have trouble with Graph Explorer, send us the Site ID and the name of the Document Library ("InspectionPhotos"), and we can look up the Drive ID for you.

> **Write these down — you'll provide them to us at the end:**
> - Site ID: `________________________`
> - Drive ID: `________________________`

---

## Step 2: Register the App in Microsoft Entra ID

An **App Registration** is how you give our application permission to talk to SharePoint on behalf of your organization. Think of it like creating an ID badge for the app — it proves who the app is and what it's allowed to do.

You may have already done this step when setting up single sign-on (SSO). **This is a separate app registration** — the SSO one lets *users* sign in, while this one lets the *server* upload files. They need different permissions.

### 2.1 — Go to App Registrations

1. Open the [Azure Portal](https://portal.azure.com)
2. In the search bar at the top, type **"App registrations"** and click on it
3. Click **"+ New registration"**

### 2.2 — Fill in the registration form

| Field | What to enter |
|-------|---------------|
| **Name** | `Inspection CMS - SharePoint Storage` (or any name that helps you remember what this is for) |
| **Supported account types** | Select **"Accounts in this organizational directory only"** (the first option). This means only your organization can use this app registration. |
| **Redirect URI** | Leave this blank. It's not needed because the app talks to SharePoint server-to-server (no user browser is involved). |

4. Click **Register**

### 2.3 — Copy the Tenant ID and Client ID

After registering, you'll land on the app's **Overview** page. You'll see two important values:

| What it's called in Azure | What we call it | What it looks like |
|---------------------------|-----------------|-------------------|
| **Directory (tenant) ID** | Tenant ID | A long string like `a1b2c3d4-e5f6-7890-abcd-ef1234567890` |
| **Application (client) ID** | Client ID | Another long string in the same format |

Copy both of these and save them.

> **Write these down:**
> - Tenant ID: `________________________`
> - Client ID: `________________________`

### 2.4 — Create a Client Secret

A **Client Secret** is like a password that the app uses to prove its identity.

1. In the left sidebar of your app registration, click **"Certificates & secrets"**
2. Click **"+ New client secret"**
3. Enter a description like `SharePoint photo storage`
4. Choose an expiration period — **24 months** is recommended (you'll need to create a new one before it expires)
5. Click **Add**
6. **IMPORTANT**: Copy the **"Value"** column immediately. This is the Client Secret. It will only be shown once — if you leave this page without copying it, you'll have to create a new one.

> **Write this down (and keep it private — treat it like a password):**
> - Client Secret: `________________________`
> - Expiration date: `________________________` (note this so you can rotate it before it expires)

---

## Step 3: Grant API Permissions

Now we need to tell Azure what this app is allowed to do. We need two permissions that let the app read and write files in SharePoint.

### 3.1 — Add the permissions

1. In the left sidebar of your app registration, click **"API permissions"**
2. Click **"+ Add a permission"**
3. Choose **"Microsoft Graph"** (it should be the first option)
4. Choose **"Application permissions"** (NOT "Delegated permissions")
   - **"Delegated"** means "act on behalf of a signed-in user" — that's not what we want
   - **"Application"** means "act on behalf of the app itself" — this is correct because the server uploads photos without a user being signed into Microsoft
5. Search for and check these two permissions:

| Permission | What it allows |
|------------|----------------|
| **Sites.ReadWrite.All** | Read and write files in SharePoint sites |
| **Files.ReadWrite.All** | Read and write files in all drives (Document Libraries) |

6. Click **"Add permissions"**

### 3.2 — Grant admin consent

After adding the permissions, you'll see them listed with a status of **"Not granted"**. Since these are application-level permissions (not user-level), an admin must approve them.

1. Click the **"Grant admin consent for [Your Organization]"** button at the top of the permissions list
2. Click **"Yes"** to confirm
3. The status for both permissions should change to **"Granted"** with a green checkmark

> If you don't see the "Grant admin consent" button, you may not have the **Global Administrator** or **Privileged Role Administrator** role. Ask someone who does to click this button for you.

---

## Step 4: Send Us the Configuration Values

Now that everything is set up, send the following six values to the development team. We'll plug them into the app's secure configuration.

| # | Value | Where you found it | Example |
|---|-------|--------------------|---------|
| 1 | **Tenant ID** | Step 2.3 — App Registration → Overview → "Directory (tenant) ID" | `a1b2c3d4-e5f6-7890-abcd-ef1234567890` |
| 2 | **Client ID** | Step 2.3 — App Registration → Overview → "Application (client) ID" | `f9e8d7c6-b5a4-3210-fedc-ba0987654321` |
| 3 | **Client Secret** | Step 2.4 — Certificates & secrets → Value column | `xYz~AbC123...` |
| 4 | **Site ID** | Step 1.4 — SharePoint site API URL | `d4a5b6c7-8901-2345-6789-abcdef012345` |
| 5 | **Drive ID** | Step 1.4 — Graph Explorer query | `b!abc123def456...` |
| 6 | **Secret Expiration Date** | Step 2.4 — when you created the client secret | `2028-03-10` |

**How to send these securely:** Do NOT send these values over email or chat. Use your organization's approved method for sharing secrets (e.g., a password manager shared vault, an encrypted file, or in-person).

---

## Step 5: Verify It's Working (After We Deploy)

Once we've configured the app with your values and deployed the update, here's how to confirm everything is working:

### 5.1 — Test photo upload
1. Log into the Inspection CMS app
2. Create a new report (or edit an existing one)
3. In the "Photos & Attachments" section, upload a test photo
4. Save the report
5. The photo should appear in the report — if it does, the upload worked

### 5.2 — Verify photos are in SharePoint
1. Go to your SharePoint site
2. Open the **InspectionPhotos** Document Library
3. You should see a folder for the project, and inside it, a folder for the report
4. The test photo should be there

### 5.3 — Test photo persistence after app restart
1. Upload a photo via the app (if you haven't already)
2. Ask us to restart the Azure App Service (or wait for the next deployment)
3. Go back to the report — the photo should still be there (this proves photos survive server restarts)

---

## Ongoing Maintenance

### Client Secret Rotation

The Client Secret you created in Step 2.4 has an expiration date. Before it expires, you'll need to create a new one:

1. Go to [Azure Portal](https://portal.azure.com) → App registrations → "Inspection CMS - SharePoint Storage"
2. Go to **Certificates & secrets**
3. Create a new client secret (same steps as 2.4)
4. Send the new secret value to the development team
5. After we update the app with the new secret, you can delete the old one

> Set a calendar reminder for 2 weeks before the expiration date so you have time to rotate it.

### SharePoint Storage Space

Photos will accumulate over time. SharePoint includes storage as part of your Microsoft 365 plan (typically 1 TB + 10 GB per licensed user). You can check your usage in the SharePoint Admin Center under **"Active sites"** → click your site → see the storage used.

### Access Control

The photos in SharePoint follow your site's access permissions. If you need to restrict who can browse photos directly in SharePoint (outside the app), adjust the Document Library's sharing settings:

1. Open the Document Library in SharePoint
2. Click the gear icon → **Library settings**
3. Under **Permissions for this document library**, configure as needed

---

## Glossary

| Term | What it means |
|------|---------------|
| **Azure Portal** | Microsoft's web dashboard for managing cloud services. Like a control panel for all your Microsoft cloud stuff. |
| **Microsoft Entra ID** | Microsoft's identity service (renamed from "Azure Active Directory" or "Azure AD"). It manages who can sign in and what apps are allowed to do. |
| **App Registration** | A configuration in Entra ID that gives an application an identity — like an ID badge. It includes a Client ID (the badge number) and a Client Secret (the password). |
| **Tenant** | Your organization's space in Microsoft's cloud. Your Tenant ID uniquely identifies your organization. |
| **Client ID** | A unique identifier for the app registration. Think of it as the app's username. |
| **Client Secret** | A password for the app registration. The app uses this to prove it's really itself. |
| **Graph API** | Microsoft's system for letting apps interact with Microsoft 365 services (SharePoint, Outlook, Teams, etc.) through web requests. |
| **Document Library** | A folder structure in SharePoint designed for storing files. |
| **Site ID** | A unique identifier for a specific SharePoint site. |
| **Drive ID** | A unique identifier for a specific Document Library within a SharePoint site. |
| **API Permissions** | Rules that define what the app is allowed to do (e.g., read files, write files). |
| **Admin Consent** | An admin's approval for the app to use certain permissions on behalf of the organization. |
| **Application Permissions** | Permissions that let the app act on its own (server-to-server), without needing a user to be signed in. |
| **Delegated Permissions** | Permissions that let the app act on behalf of a signed-in user. (Not used here.) |
