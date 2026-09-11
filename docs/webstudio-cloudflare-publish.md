# Webstudio Cloudflare Publishing

This document describes the Cloudflare Pages publishing integration for the self-hosted Webstudio instance.

## Implementation Status

A custom `cloudflare-publisher` service has been implemented that allows marketers to click "Publish" in Webstudio and automatically deploy to Cloudflare Pages.

## Overview

Webstudio has **full Cloudflare support already built in** - it's currently marked as internal/not public yet. The codebase includes two complete Cloudflare templates ready for use.

## Existing Cloudflare Templates

| Template | Framework | Runtime | Location |
|----------|-----------|---------|----------|
| `cloudflare` | Remix 2.16.5 | Cloudflare Pages | `packages/cli/templates/cloudflare/` |
| `cloudflare-new` | React Router v7 | Cloudflare Workers | `packages/cli/templates/react-router-cloudflare/` |

## Publish System Architecture

Webstudio has two distinct publish flows:

### SaaS Destination (Custom Domains)
- Published to Webstudio-hosted infrastructure
- Supports staging and production environments
- Requires domain verification and CNAME setup

### Static Destination (Self-Hosted)
- Generates project bundles for deployment to any platform
- Supports multiple deployment targets/templates
- Used for CLI-based static site generation

## Deployment Options

### Option 1: Cloudflare Workers (React Router v7)

**Template:** `cloudflare-new`
**Best for:** Server-side rendering, dynamic content, API routes

```bash
# Templates expanded: react-router + react-router-cloudflare
# Deploy command: react-router build && wrangler deploy
```

**Key files:**
- `workers/app.ts` - Worker fetch handler
- `wrangler.jsonc` - Minimal Wrangler config
- `vite.config.ts` - React Router + Cloudflare config

**Worker handler (`workers/app.ts`):**
```typescript
import { createRequestHandler } from "react-router";

declare module "react-router" {
  export interface AppLoadContext {
    cloudflare: {
      env: Env;
      ctx: ExecutionContext;
    };
  }
}

const requestHandler = createRequestHandler(
  () => import("virtual:react-router/server-build"),
  import.meta.env.MODE
);

export default {
  async fetch(request, env, ctx) {
    return requestHandler(request, {
      EXCLUDE_FROM_SEARCH: false,
      getDefaultActionResource: undefined,
      cloudflare: { env, ctx },
    });
  },
} satisfies ExportedHandler<Env>;
```

**Available Cloudflare bindings:**
- KV Namespaces (persistent storage)
- D1 Databases (serverless SQL)
- R2 Buckets (object storage)
- Durable Objects (stateful compute)
- Workers AI (ML models)
- Queues (task scheduling)

### Option 2: Cloudflare Pages (Remix)

**Template:** `cloudflare`
**Best for:** Hybrid static + serverless functions

```bash
# Templates expanded: defaults + cloudflare
# Deploy command: npm run build && wrangler pages deploy ./build/client
```

**Key files:**
- `functions/[[path]].ts` - Remix Pages Function handler
- `wrangler.toml` - Build output config
- `load-context.ts` - Cloudflare type definitions
- `vite.config.ts` - Remix + Cloudflare Pages config

**Note:** Cloudflare Pages does not use `wrangler.toml` for deployment bindings. Bindings must be configured manually in the Cloudflare dashboard.

### Option 3: Static Site Generation (SSG)

**Template:** `ssg`
**Best for:** Pure static sites, simplest setup

```bash
# Build: vite build && vike prerender
# Deploy: wrangler pages deploy ./dist/client
```

Uses Vike for static prerendering. Output can be deployed to any static host including Cloudflare Pages.

## Enabling Cloudflare in the Fork

The templates are hidden behind `INTERNAL_TEMPLATES` in `packages/cli/src/config.ts`.

To enable, move them to `PROJECT_TEMPLATES`:

```typescript
export const PROJECT_TEMPLATES = [
  // ... existing templates ...
  {
    value: "cloudflare" as const,
    label: "Cloudflare Pages (Remix)",
    expand: ["defaults", "cloudflare"],
  },
  {
    value: "cloudflare-new" as const,
    label: "Cloudflare Workers",
    expand: ["react-router", "react-router-cloudflare"],
  },
];
```

## Template Expansion System

Templates use an "expand" system for composition:

```typescript
{
  value: "cloudflare-new",
  label: "Cloudflare (new)",
  expand: ["react-router", "react-router-cloudflare"]
}
```

This allows:
- Shared base template logic
- Platform-specific overrides
- Modular template composition

## Key Files Reference

| File | Purpose |
|------|---------|
| `packages/sdk/src/schema/deployment.ts` | Deployment type schema |
| `packages/domain/src/trpc/domain.ts` | Publish/unpublish mutations |
| `packages/cli/src/config.ts` | Template definitions |
| `packages/cli/src/commands/build.ts` | Build command entrypoint |
| `packages/cli/src/prebuild.ts` | Code generation engine |
| `packages/cli/templates/cloudflare/` | Remix Pages template |
| `packages/cli/templates/react-router-cloudflare/` | React Router Workers template |

## CLI Workflow

```bash
# Initialize project with Cloudflare target
webstudio init

# Select deploy target (after enabling Cloudflare)
# Link project via Builder API share link
# Sync project data locally

# Development
npm run dev

# Deploy
npm run deploy  # Platform-specific deployment
```

## Deployment Schema

```typescript
// Static Deployment (for Cloudflare)
{
  destination: "static",
  name: string,
  assetsDomain: string,
  templates: ("cloudflare" | "cloudflare-new" | ...)[]
}
```

## Recommendations

1. **For dynamic sites with SSR:** Use `cloudflare-new` (React Router + Workers)
2. **For hybrid static/dynamic:** Use `cloudflare` (Remix + Pages Functions)
3. **For pure static sites:** Use `ssg` and deploy to Cloudflare Pages

The Workers template (`cloudflare-new`) provides the most flexibility with full access to Cloudflare's edge runtime capabilities.

## Implemented Solution: Cloudflare Publisher Service

A custom deployment service has been implemented that integrates with Webstudio's TRPC publish API.

### Architecture

```
Marketer clicks Publish in Webstudio
        ↓
Webstudio Builder → TRPC call (buildId, builderOrigin)
        ↓
cloudflare-publisher service (K8s)
        ↓
Fetch build bundle from Webstudio API
        ↓
Generate static HTML/CSS/JS
        ↓
Deploy to Cloudflare Pages (Direct Upload API)
        ↓
Site live on configured domain
```

### Components

| Component | Location |
|-----------|----------|
| Publisher Service | `forks/webstudio/apps/cloudflare-publisher/` |
| K8s Deployment | `apps/webstudio/cloudflare-publisher/` |
| Config | `config/webstudio/config.yaml` (TRPC_SERVER_URL) |
| Secrets | `config/webstudio/secret.enc.yaml` (CLOUDFLARE_API_TOKEN) |
| SQL Migration | `config/webstudio/migrations/deployment_targets.sql` |
| Migration Runner | `scripts/apply-config-migrations.sh` |

### Database Table

The `deployment_targets` table lives in the **studio** database (same as GoTrue auth).

```sql
CREATE TABLE deployment_targets (
  project_id UUID PRIMARY KEY,
  cloudflare_project_name TEXT NOT NULL,
  cloudflare_account_id TEXT NOT NULL,
  custom_domain TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
```

### Migrations

Migrations are stored in `config/webstudio/migrations/` and applied via:

```bash
nix run .#apply-config-migrations
```

This is idempotent - safe to run multiple times. All SQL uses `IF NOT EXISTS`, `ON CONFLICT DO UPDATE`, etc.

### Configuration

Add deployment target for a project:

```sql
INSERT INTO deployment_targets (project_id, cloudflare_project_name, cloudflare_account_id, custom_domain)
VALUES ('c4a1f6da-aecd-496a-b267-204689d3ea6a', 'holdfastcore', '82d0966d5206cdb74a6b5b84e16b48ab', 'holdfastcore.com');
```

### Environment Variables

The cloudflare-publisher service requires:

| Variable | Description |
|----------|-------------|
| `DATABASE_URL` | PostgreSQL connection string |
| `CLOUDFLARE_API_TOKEN` | Cloudflare API token with Pages:Edit permission |
| `WEBSTUDIO_SERVICE_TOKEN` | Token to fetch builds from Webstudio API |
| `TRPC_SERVER_API_TOKEN` | Token for authenticating TRPC requests |

### Deployment

1. Build the cloudflare-publisher image
2. Apply K8s manifests in `apps/webstudio/cloudflare-publisher/`
3. Run the SQL migration
4. Add `CLOUDFLARE_API_TOKEN` to secrets
5. Restart webstudio-builder to pick up new TRPC_SERVER_URL

### Test Domain

- **holdfastcore.com** configured for project `c4a1f6da-aecd-496a-b267-204689d3ea6a`
- Cloudflare Account: `82d0966d5206cdb74a6b5b84e16b48ab`
