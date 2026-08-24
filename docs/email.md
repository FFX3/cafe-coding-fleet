# Email

SMTP relay for system emails (password resets, notifications, marketing).

## Architecture

```
┌─────────────┐     ┌─────────────────┐     ┌─────────┐
│  Passbolt   │────▶│  email pod      │────▶│  Resend │
│  Listmonk   │     │  (Postfix relay)│     │  (SMTP) │
│  etc.       │     │  :587           │     └─────────┘
└─────────────┘     └─────────────────┘
```

Apps connect to `smtp.email.svc.cluster.local:587`. The relay forwards to Resend.

## Adding Email to an App

```yaml
env:
  - name: SMTP_HOST
    value: "smtp.email.svc.cluster.local"
  - name: SMTP_PORT
    value: "587"
  - name: SMTP_FROM
    value: "app@justinmcintyre.com"
```

No auth needed for internal services (relay handles Resend auth).

## Resend Setup

1. Create account at https://resend.com
2. Add domain, verify DNS (DKIM, SPF, DMARC)
3. Generate API key
4. Update `apps/email/secret.yaml`, encrypt with sops

## Per-User Email (CRM)

Twenty CRM handles per-user OAuth internally. Users connect their own Gmail/Outlook. That's separate from this system email infrastructure.

## Troubleshooting

Check relay logs:
```bash
kubectl logs -n email deploy/email
```

Test send:
```bash
kubectl exec -n email deploy/email -- sendmail -v test@example.com <<< "Subject: Test"
```
