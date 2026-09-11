-- Create deployment_targets table for mapping Webstudio projects to Cloudflare Pages
-- This table is used by the cloudflare-publisher service to know where to deploy each project

CREATE TABLE IF NOT EXISTS deployment_targets (
  project_id UUID PRIMARY KEY,
  cloudflare_project_name TEXT NOT NULL,
  cloudflare_account_id TEXT NOT NULL,
  custom_domain TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index for quick lookups by Cloudflare project name (useful for unpublish)
CREATE INDEX IF NOT EXISTS idx_deployment_targets_cf_project
ON deployment_targets(cloudflare_project_name);

-- Trigger to auto-update updated_at timestamp
CREATE OR REPLACE FUNCTION update_deployment_targets_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS deployment_targets_updated_at ON deployment_targets;
CREATE TRIGGER deployment_targets_updated_at
  BEFORE UPDATE ON deployment_targets
  FOR EACH ROW
  EXECUTE FUNCTION update_deployment_targets_updated_at();

-- Insert initial deployment target for holdfastcore.com
-- Project ID: c4a1f6da-aecd-496a-b267-204689d3ea6a
-- Cloudflare Account: 82d0966d5206cdb74a6b5b84e16b48ab
INSERT INTO deployment_targets (project_id, cloudflare_project_name, cloudflare_account_id, custom_domain)
VALUES ('c4a1f6da-aecd-496a-b267-204689d3ea6a', 'holdfastcore', '82d0966d5206cdb74a6b5b84e16b48ab', 'holdfastcore.com')
ON CONFLICT (project_id) DO UPDATE SET
  cloudflare_project_name = EXCLUDED.cloudflare_project_name,
  cloudflare_account_id = EXCLUDED.cloudflare_account_id,
  custom_domain = EXCLUDED.custom_domain;
