# Apollo Integration

Search Apollo.io for leads and import them as Companies into Twenty CRM.

## Features

- **Get Apollo Leads** workflow action - search Apollo by technology, keywords, revenue, and employee count
- Automatically creates or updates Company records in Twenty
- Stores search criteria with each company for tracking how leads were found
- Marks imported companies as accounts in Apollo to prevent duplicates

## Custom Fields

This app adds the following fields to the Company object:

- **Apollo Org ID** - Apollo's organization identifier for deduplication
- **Has Apollo Account** - Whether this company has been added as an account in Apollo
- **Apollo Search Criteria** - JSON field storing the search filters that found this company

## Setup

1. Get your Apollo.io API key from [Apollo Settings](https://app.apollo.io/#/settings/integrations/api)
2. In Twenty, go to **Settings → Applications → Apollo Integration → Settings**
3. Enter your Apollo API key

## Usage

1. Create a new Workflow
2. Add the **Get Apollo Leads** action
3. Configure your search filters:
   - Keywords (e.g., "consulting")
   - Technologies (e.g., "Zapier, HubSpot")
   - Employee range
   - Revenue range
   - Max results
4. Run the workflow

The action returns a list of companies that were created or updated, which can be used in subsequent workflow steps.
