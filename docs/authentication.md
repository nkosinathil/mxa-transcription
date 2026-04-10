# Authentication & Authorization Guide

## Overview

This application uses **Keycloak** as the sole identity provider.
Users never enter a password into the PHP app – all login is handled by Keycloak.

The flow used is **OIDC Authorization Code Flow**, which is the recommended
secure method for browser-based applications.

---

## How Login Works (Step by Step)

```
1.  User visits http://192.168.1.66/
    → PHP checks session; session is empty
    → PHP redirects to /auth/login

2.  /auth/login (PHP KeycloakService::buildLoginUrl())
    → Generates a random "state" value and stores in session (CSRF protection)
    → Redirects browser to:
      http://192.168.1.59:8080/realms/{realm}/protocol/openid-connect/auth
        ?client_id=transcription-web
        &response_type=code
        &scope=openid email profile
        &redirect_uri=http://192.168.1.66/auth/callback
        &state=<random>

3.  Keycloak shows its login page
    → User enters username and password
    → Keycloak validates credentials

4.  Keycloak redirects back to the PHP app:
      http://192.168.1.66/auth/callback?code=<auth_code>&state=<same_random>

5.  /auth/callback (PHP AuthController::callback())
    → Verifies the state matches (CSRF check)
    → POSTs to Keycloak token endpoint to exchange the code for tokens:
        POST /realms/{realm}/protocol/openid-connect/token
        grant_type=authorization_code&code=...&redirect_uri=...
    → Receives: access_token, id_token, refresh_token

6.  PHP decodes the id_token (a JWT):
    → Extracts: sub (user ID), email, name, realm_access.roles
    → Calls UserRepository::upsertFromKeycloak() to create/update local user record
    → Stores user array in PHP session

7.  User is now logged in; redirected to /dashboard
```

---

## Roles

Three application roles are supported:

| Role | Keycloak Role Name | Permissions |
|------|--------------------|-------------|
| `admin` | `admin` or `transcription-admin` | All features + settings |
| `analyst` | `analyst` or `transcription-analyst` | Create cases, upload, process, view results |
| `viewer` | (anything else) | View results only |

The mapping happens in `UserRepository::mapRole()`.
**Adjust the role names to match what your Keycloak realm actually sends.**

To see what roles Keycloak sends, decode the access token at:
https://jwt.io

---

## Session Management

- Sessions are PHP server-side sessions stored in `/var/lib/php/sessions/`
- Session lifetime: `SESSION_LIFETIME` env var (default 7200 seconds = 2 hours)
- Session cookie: `HttpOnly`, `SameSite=Lax`
- On login: `session_regenerate_id(true)` prevents session fixation attacks
- On logout: session is destroyed AND user is redirected to Keycloak logout

---

## CSRF Protection

The OAuth `state` parameter in the login URL doubles as CSRF protection:
- PHP generates a random 32-character hex string
- Stores it in `$_SESSION['oauth_state']`
- After Keycloak redirects back, PHP verifies the state matches
- If it doesn't match, the callback is rejected

Form submissions use standard PHP session CSRF where needed.

---

## Adding Keycloak Client in Admin Console

1. Log into Keycloak admin at `http://192.168.1.59:8080`
2. Select your realm
3. Go to **Clients** → **Create**
4. Set:
   - **Client ID**: `transcription-web`
   - **Client Protocol**: `openid-connect`
   - **Access Type**: `confidential`
5. In **Settings** tab:
   - **Valid Redirect URIs**: `http://192.168.1.66/auth/callback`
   - **Web Origins**: `http://192.168.1.66`
6. In **Credentials** tab: copy the **Secret** → paste into `KEYCLOAK_CLIENT_SECRET`
7. In **Roles** tab: create roles `admin`, `analyst` (viewer is the default)
8. Assign roles to users via **Users** → select user → **Role Mappings**
