# Microsoft Entra ID SSO Setup Guide

## Overview

This app supports **Single Sign-On (SSO)** via Microsoft Entra ID (Azure AD) using OpenID Connect (OIDC).  
SSO is **optional** — when Entra credentials are not configured the app falls back to standard Devise email/password login.

---

## Architecture

```
User clicks "Sign in with Microsoft"
  → Browser redirected to Microsoft login (MFA, Conditional Access, etc.)
  → Microsoft sends user back to /users/auth/microsoft_graph/callback
  → App verifies identity, links or creates user, signs them in
```

**Provider:** `omniauth-microsoft_graph` gem  
**Identity key:** `preferred_username` (UPN) — primary  
**Secondary key:** `oid` (immutable Entra object ID) — stored for future migration safety  
**Tenant policy:** Single-tenant only (validated at callback)

---

## What IT Needs to Do

### 1. Create an App Registration in Entra ID

Provide the following to the developer:

| Item | Notes |
|------|-------|
| **Tenant ID** (Directory ID) | Found on the App Registration overview page |
| **Client ID** (Application ID) | Found on the App Registration overview page |
| **Client Secret** (value) | Under Certificates & secrets → New client secret → copy the **Value** (not the ID) |

### 2. Configure the App Registration

**Sign-in audience:** Accounts in this organizational directory only (single-tenant)

**Platform:** Web

**Redirect URIs** (must be exact):

| Environment | URI |
|-------------|-----|
| Production | `https://YOUR_DOMAIN/users/auth/microsoft_graph/callback` |
| Local dev | `http://localhost:3000/users/auth/microsoft_graph/callback` |

### 3. Grant Permissions (Delegated)

| Permission | Required? |
|------------|-----------|
| `openid` | Yes — OIDC login |
| `profile` | Yes — basic user profile |
| `email` | Yes — email claim (if available) |
| `User.Read` | Yes — read signed-in user info |

If policy requires it, grant **Admin consent** for the tenant.

### 4. Access Restrictions

Choose one:
- [ ] Any user in the tenant may sign in
- [ ] Restrict sign-in to specific users/groups

---

## Developer: Environment Variables

Set these three values. When **all three are blank/missing**, SSO is disabled and the app works with local Devise login only.

```bash
# .env (local) or hosting platform env vars (production)
AZURE_TENANT_ID=your-tenant-id-here
AZURE_CLIENT_ID=your-client-id-here
AZURE_CLIENT_SECRET=your-client-secret-value-here
```

See `.env.example` for the full template.

---

## How It Works

### Login Flow

1. If `AZURE_CLIENT_ID` is set, the login page shows a **"Sign in with Microsoft"** button below the standard email/password form.
2. Clicking it redirects to Microsoft's login page.
3. After authentication, Microsoft redirects back to `/users/auth/microsoft_graph/callback`.
4. The `Users::OmniauthCallbacksController` handles the callback:
   - **Tenant validation:** verifies the token's `tid` matches `AZURE_TENANT_ID`
   - **User linking:** checks for existing user by `provider + uid`, then by `email` match to `preferred_username`
   - **New user creation:** if no match, creates a new user with role `qc` (default)
5. User is signed in via Devise.

### Account Linking (Phased Migration)

- Existing local users are automatically linked on their **first SSO login** if their local email matches the Entra `preferred_username` (UPN).
- After linking, both SSO and local password login work for that account.
- SSO-only users (no prior local account) get a random password they'll never use.

### Roles

| Role | Value | Access |
|------|-------|--------|
| `inspector` | 0 | Own reports only |
| `qc` | 1 | All reports, can approve/reject |
| `admin` | 2 | All QC permissions + future admin features |

- New SSO users default to `qc`.
- One admin account is manually set at launch.
- Role assignment is controlled by the app, not Entra (for now).

### Email Allowlist (Local Sign-up)

Local Devise registration is restricted to these whitelisted emails:

- `admin@cms.com`
- `tester@cms.com`
- `rachelle@icms.com`
- `chris@icms.com`
- `dd@cms.com`
- `bh@cms.com`
- `dc@cms.com`
- `ja@cms.com`

To modify the allowlist, edit `User::ALLOWED_EMAILS` in `app/models/user.rb`.

---

## Files Changed

| File | Purpose |
|------|---------|
| `Gemfile` | Added `omniauth-microsoft_graph`, `omniauth-rails_csrf_protection` |
| `db/migrate/20260219000000_add_sso_fields_and_admin_role_to_users.rb` | SSO columns: `provider`, `uid`, `oid`, `preferred_username` |
| `app/models/user.rb` | `omniauthable`, `admin` role, `from_microsoft_omniauth`, email allowlist |
| `config/initializers/devise.rb` | Microsoft OmniAuth provider configuration |
| `config/routes.rb` | Custom controllers for OmniAuth callbacks and registrations |
| `app/controllers/users/omniauth_callbacks_controller.rb` | Handles Microsoft callback, tenant validation |
| `app/controllers/users/registrations_controller.rb` | Enforces email allowlist on local sign-up |
| `app/views/devise/sessions/new.html.erb` | "Sign in with Microsoft" button |
| `app/views/devise/registrations/new.html.erb` | Allowlist notice on sign-up page |
| `.env.example` | Entra env var stubs |

---

## Testing

### Without Entra credentials (current default)

Everything works exactly as before — standard email/password Devise login. The Microsoft button does not appear.

### With Entra credentials

1. Set `AZURE_TENANT_ID`, `AZURE_CLIENT_ID`, `AZURE_CLIENT_SECRET` in `.env`
2. Restart the Rails server
3. Go to `/users/sign_in` — the Microsoft button should appear
4. Click it → redirects to Microsoft → redirects back → user is signed in
5. Check the user record: `provider`, `uid`, `oid`, `preferred_username` should be populated

### Phase 2: Full SSO Cutover

When ready to go SSO-only:
1. Remove `:registerable` and `:database_authenticatable` from User model
2. Remove the local login form from the sessions view
3. Remove the email allowlist logic
4. Set `config.sign_in_after_reset_password = false` in Devise config

---

## Troubleshooting

| Issue | Fix |
|-------|-----|
| "Sign-in is restricted to your organization" | Token `tid` doesn't match `AZURE_TENANT_ID` — verify the env var |
| Microsoft button doesn't appear | `AZURE_CLIENT_ID` env var is not set or blank |
| "Unable to sign in with Microsoft" | Check Rails logs for OmniAuth error details |
| User created but wrong role | Update role in Rails console: `User.find_by(email: "...").update!(role: :admin)` |
| Redirect URI mismatch error from Microsoft | Ensure callback URI in Entra matches exactly (including trailing path) |
