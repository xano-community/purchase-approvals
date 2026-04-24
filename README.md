# ProcureFlow

Purchase requisition and multi-step approval workflow built on Xano. Backend is XanoScript you push to your own Xano instance; frontend is a single-file HTML app that asks for your instance's base URL the first time it loads.

A requester drafts a purchase request with line items and an ordered list of approvers, submits it, and each approver in sequence either approves or rejects. A single rejection kills the whole request; all approvals must pass for the request to reach `approved` status. Totals roll up from line items automatically.

## Repo layout

```
backend/            # XanoScript — push to your Xano workspace
  workspace/
  table/            # user, pf_vendor, pf_purchase_request,
                    # pf_request_line_item, pf_approval_step
  api/
    enterprise_auth/  # signup, login, me, users
    procureflow/      # vendors, requests (with submit/decide/my-pending), stats, seed
frontend/
  index.html        # single-file static app
```

## Quick start

### 1. Push the backend

```bash
npm install -g @xano/cli
xano profile:wizard

cd backend
xano workspace:push
```

### 2. Seed demo data

```bash
curl -X POST https://YOUR-INSTANCE.n7d.xano.io/api:procureflow/seed \
  -d '{}' -H 'Content-Type: application/json'
```

Creates 8 users, 8 real-world vendors (Apple Business, Dell, AWS, Atlassian, WeWork, Cisco…), and 10 purchase requests in varied states (draft, submitted, in_review, approved, rejected) with line items and multi-step approval chains. All seeded users share password `DemoPass1`. Idempotent.

Log in as `grace.sullivan@acme.enterprise` / `DemoPass1` — Grace sits on most approval chains, so her "My Pending Approvals" tab has plenty to act on out of the box.

### 3. Run the frontend

```bash
cd frontend
python3 -m http.server 8000
# open http://localhost:8000
```

On first load the page asks for your **Xano base URL** (e.g. `https://xxsw-1d5c-nopq.n7d.xano.io`). Stored in `localStorage`; reconfigure any time.

## State transitions

```
draft ─submit──▶ submitted ─first approval──▶ in_review ─all approvals──▶ approved
                                                      └──any rejection──▶ rejected
```

`POST /requests/{id}/decide` scopes to the caller's own pending approval step, records their decision, and rolls the request forward (or terminally rejects it).

## API surface

All endpoints except `/seed` require `Authorization: Bearer <token>`.

```
POST   /api:enterprise-auth/signup         { name, email, password }
POST   /api:enterprise-auth/login          { email, password }
GET    /api:enterprise-auth/me
GET    /api:enterprise-auth/users

POST   /api:procureflow/seed
GET    /api:procureflow/vendors            ?status&q&page&per_page
POST   /api:procureflow/vendors
GET    /api:procureflow/requests           ?status&vendor_id&requester_id&page&per_page
POST   /api:procureflow/requests           { title, vendor_id?, department?, line_items?, approver_ids? }
GET    /api:procureflow/requests/my-pending
GET    /api:procureflow/requests/{id}
POST   /api:procureflow/requests/{id}/submit
POST   /api:procureflow/requests/{id}/decide   { decision: "approve"|"reject", notes? }
GET    /api:procureflow/stats/dashboard
```

## Schema

- **`user`** — id, name, email (unique), password, created_at — shared auth table with `auth = true`
- **`pf_vendor`** — id, name, contact_email, contact_phone, address, tax_id, status
- **`pf_purchase_request`** — id, title, justification, requester_id → user, vendor_id → pf_vendor, status, total_amount, department, submitted_at, decided_at
- **`pf_request_line_item`** — id, request_id → pf_purchase_request, description, quantity, unit_price, line_total
- **`pf_approval_step`** — id, request_id → pf_purchase_request, approver_id → user, sequence, status, notes, acted_at

## Frontend features

- Dashboard with spend roll-up for approved requests
- "All Requests" tab with status filter, pagination, and per-request detail modal showing line items + approval chain
- "My Pending Approvals" tab listing every request awaiting the signed-in user's decision
- Create-request modal with dynamic line items and ordered approver selection
- Inline approve/reject with notes when viewing a request you're an approver on
- Configurable Xano instance URL (no hardcoded endpoints)

## License

MIT.
