# Milestone 4: Frappe Bench

Deploy Frappe with ERPNext and CRM sites.

## Complexity

Each Frappe "site" requires:
- Its own database in PostgreSQL
- Hostname-based routing (Frappe reads Host header)
- Shared bench process serving multiple sites

## Goals

- [ ] Build Frappe image from fork (https://github.com/FFX3/crm)
- [ ] Deploy Frappe bench (gunicorn + socketio + workers)
- [ ] Create ERPNext site with dedicated DB
- [ ] Create CRM site with dedicated DB
- [ ] Configure nginx ingress for both hostnames
- [ ] Redis for cache/queue

## Sites

| Hostname | Site | Database |
|----------|------|----------|
| erp.justinmcintyre.com | ERPNext | erpnext_db |
| crm.justinmcintyre.com | CRM | crm_db |

## Deferred

Details TBD - this milestone is more complex and will be planned after milestone 3.
