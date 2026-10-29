# Edit.or.lynx Pro Key Server & Admin Control Center

Full-featured licensing backend, public giveaway landing page, and admin management dashboard for **Edit.or.lynx** on macOS.

---

## 🚀 Quick Start (Local Node.js Server)

Zero external dependencies required (runs on native Node.js).

```bash
cd /Users/sivasoft/Downloads/temp/lynk/EditOrLynx/server
npm start
# or: node server.js
```

### URLs
- **Public Pro Key Site:** [http://localhost:3000/get-pro-key#pro](http://localhost:3000/get-pro-key#pro)
- **Admin Control Center:** [http://localhost:3000/admin](http://localhost:3000/admin)
- **License Validation API:** `POST http://localhost:3000/api/license/validate`

---

## 🔐 Credentials & Master Keys

- **Admin Password:** `sivaadminpro2026`
- **Master Lifetime Pro Key:** `ELNK-PRO9-LIF7-SIVA-2026`
- **Instagram Campaign Pro Key:** `ELNK-INST-GRAM-SIVA-PRO7`
- **VIP Giveaway Keys:**
  - `ELNK-8K4X-N29M-QR7T-Z56V`
  - `ELNK-W73P-B65K-TY28-M49X`
  - `ELNK-5P8Z-D47R-VX26-K93N`

---

## ⚡ Cloudflare Worker Deployment

The server is pre-configured and bundled for 1-click deployment to Cloudflare Workers at `https://edit-orlynk.sivasoft.workers.dev`:

```bash
cd /Users/sivasoft/Downloads/temp/lynk/EditOrLynx/server
npx wrangler deploy
```

---

## 🛠️ Features

### 1. Public Pro Key Landing Page (`/` and `/get-pro-key`)
- Dark obsidian visionOS glass aesthetic matching macOS design language.
- Instagram giveaway campaign integration (`@edit.or.siva`).
- 1-click **Get Free Lifetime Pro Key** generator.
- 1-click **Copy Key** button with animated clipboard feedback.
- Direct **Activate in Edit.or.lynx** macOS deep linking (`editorlynx://activate?key=...`).
- Comprehensive Free vs Pro feature comparison table.

### 2. Admin Control Dashboard (`/admin`)
- Secure password authentication (`sivaadminpro2026`).
- Real-time stat metrics:
  - Total Keys Generated
  - Active Licenses
  - Redeemed / Used Machines
  - Revoked Keys
- **Key Generator:**
  - Batch generation (1 to 100 keys per click).
  - Durations: Lifetime (Year 2100), 1 Year, 6 Months, 30 Days.
  - Multi-Mac Redemptions: 1, 3, 5, 50, or 100 Macs.
  - Custom campaign tags & notes.
- **Inventory & Key Actions:**
  - Instant live search by key, tag, or note.
  - Status filters (All, Active, Revoked).
  - One-click actions: Revoke, Reactivate, Delete.
  - Export database to **CSV** or raw keys to **TXT**.

### 3. macOS App API Contract (`/api/license/validate`)
Fully compatible with `LicenseService.swift`:
- Validates Crockford Base32 keys (`^ELNK-[A-Z2-7]{4}-[A-Z2-7]{4}-[A-Z2-7]{4}-[A-Z2-7]{4}$`).
- Returns HTTP 200 with `{ plan: "pro", token: "...", expiresAt: 4102444800, keyId: "..." }`.
- Returns HTTP 409 Conflict with `{ reason: "revoked" | "expired" | "limit" }`.
