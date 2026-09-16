# Twenty CRM Enterprise Feature Bypass

## Overview

Twenty CRM uses a dual-license model. Files marked with `/* @license Enterprise */` are under a commercial license requiring a paid subscription. However, the actual runtime feature gating is minimal.

## What's Actually Gated

Only **SSO features** (OIDC/SAML) are runtime-gated via `EnterpriseFeaturesEnabledGuard`:

- `packages/twenty-server/src/engine/core-modules/sso/sso.resolver.ts` - CRUD for SSO providers
- `packages/twenty-server/src/engine/core-modules/auth/controllers/sso-auth.controller.ts` - SSO login endpoints

The 327 files marked `@license Enterprise` are just commercially licensed code - most runs without any feature check.

## How the Lock Works

1. `EnterpriseFeaturesEnabledGuard` calls `enterprisePlanService.isValid()`
2. `isValid()` checks for a valid `EnterpriseValidityToken` JWT
3. That JWT must be signed by Twenty's private RSA key (public key hardcoded)
4. Token obtained by calling `ENTERPRISE_API_URL/validate` with a paid `ENTERPRISE_KEY`

**Key files:**
- Guard: `packages/twenty-server/src/engine/core-modules/auth/guards/enterprise-features-enabled.guard.ts`
- Service: `packages/twenty-server/src/engine/core-modules/enterprise/services/enterprise-plan.service.ts`

## Bypass Option 1: Always Valid (Simplest)

Edit `enterprise-plan.service.ts` line 169-171:

```typescript
isValid(): boolean {
  return true;  // was: return this.hasValidEnterpriseValidityToken();
}
```

## Bypass Option 2: Remove Guards (Surgical)

Remove `EnterpriseFeaturesEnabledGuard` from the decorator arrays in:
- `sso.resolver.ts` (5 occurrences)
- `sso-auth.controller.ts` (5 occurrences)

## Building Custom Image

After making changes:

```bash
cd forks/twenty
docker build -t twenty-custom:latest -f packages/twenty-docker/prod/twenty/Dockerfile .
```

Then update `apps/twenty/server/deployment.yaml` to use the custom image.

## Legal Note

This is permitted under AGPL for self-hosted use. The commercial license applies if distributing the modified enterprise code to third parties.

## References

- Fork location: `forks/twenty`
- Tag analyzed: `twenty/v2.39.0`
- Related: [SpeculativeTechnologies/CRM fork](https://github.com/SpeculativeTechnologies/CRM) - another org maintaining a Twenty fork
