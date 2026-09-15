import { defineLogicFunction } from 'twenty-sdk/define';
import {
  jsonSchemaToInputSchema,
  type InputJsonSchema,
} from 'twenty-sdk/logic-function';
import { CoreApiClient } from 'twenty-client-sdk/core';

type CompanyResult = {
  id: string;
  name: string;
  domain: string;
  isNew: boolean;
};

type SyncResult = {
  fetched: number;
  created: number;
  updated: number;
  accountsCreated: number;
  companies: CompanyResult[];
  errors: string[];
};

type SearchCriteria = {
  firstSearchedAt: string;
  lastSearchedAt: string;
  searchCount: number;
  technologies: string[];
  keywords: string[];
  employeesMin?: number;
  employeesMax?: number;
  revenueMin?: number;
  revenueMax?: number;
};

function mergeSearchCriteria(
  existing: SearchCriteria | null | undefined,
  current: {
    technologies?: string[];
    keywords?: string[];
    employeesMin?: number;
    employeesMax?: number;
    revenueMin?: number;
    revenueMax?: number;
    searchedAt: string;
  }
): SearchCriteria {
  if (!existing) {
    return {
      firstSearchedAt: current.searchedAt,
      lastSearchedAt: current.searchedAt,
      searchCount: 1,
      technologies: current.technologies ?? [],
      keywords: current.keywords ?? [],
      employeesMin: current.employeesMin,
      employeesMax: current.employeesMax,
      revenueMin: current.revenueMin,
      revenueMax: current.revenueMax,
    };
  }

  // Merge arrays (dedupe)
  const technologies = [
    ...new Set([
      ...(existing.technologies ?? []),
      ...(current.technologies ?? []),
    ]),
  ];
  const keywords = [
    ...new Set([...(existing.keywords ?? []), ...(current.keywords ?? [])]),
  ];

  // Refine ranges: highest MIN, lowest MAX
  const employeesMin =
    Math.max(existing.employeesMin ?? 0, current.employeesMin ?? 0) || undefined;
  const employeesMax = Math.min(
    existing.employeesMax ?? Infinity,
    current.employeesMax ?? Infinity
  );
  const revenueMin =
    Math.max(existing.revenueMin ?? 0, current.revenueMin ?? 0) || undefined;
  const revenueMax = Math.min(
    existing.revenueMax ?? Infinity,
    current.revenueMax ?? Infinity
  );

  return {
    firstSearchedAt: existing.firstSearchedAt ?? current.searchedAt,
    lastSearchedAt: current.searchedAt,
    searchCount: (existing.searchCount ?? 1) + 1,
    technologies,
    keywords,
    employeesMin,
    employeesMax: employeesMax === Infinity ? undefined : employeesMax,
    revenueMin,
    revenueMax: revenueMax === Infinity ? undefined : revenueMax,
  };
}

const inputSchema: InputJsonSchema = {
  type: 'object',
  properties: {
    maxResults: {
      type: 'number',
      label: 'Max Results',
      description: 'Maximum leads to fetch (default: 100)',
    },
    revenueMin: {
      type: 'number',
      label: 'Min Revenue',
      description: 'Minimum revenue filter',
    },
    revenueMax: {
      type: 'number',
      label: 'Max Revenue',
      description: 'Maximum revenue filter',
    },
    employeesMin: {
      type: 'number',
      label: 'Min Employees',
      description: 'Minimum employees filter',
    },
    employeesMax: {
      type: 'number',
      label: 'Max Employees',
      description: 'Maximum employees filter',
    },
    technologies: {
      type: 'string',
      label: 'Technologies',
      description: 'Comma-separated technology names (e.g., Zapier, HubSpot)',
    },
    keywords: {
      type: 'string',
      label: 'Keywords',
      description: 'Comma-separated keywords (e.g., consulting)',
    },
  },
};

const handler = async (params: {
  maxResults?: number;
  revenueMin?: number;
  revenueMax?: number;
  employeesMin?: number;
  employeesMax?: number;
  technologies?: string;
  keywords?: string;
}): Promise<SyncResult> => {
  const apolloApiKey = process.env.APOLLO_API_KEY;
  if (!apolloApiKey) {
    throw new Error('APOLLO_API_KEY not configured');
  }

  const client = new CoreApiClient();
  const result: SyncResult = {
    fetched: 0,
    created: 0,
    updated: 0,
    accountsCreated: 0,
    companies: [],
    errors: [],
  };

  const maxResults = params.maxResults ?? 100;
  const selectedTechnologies = params.technologies
    ?.split(',')
    .map((t) => t.trim())
    .filter(Boolean);
  const keywords = params.keywords?.split(',').map((k) => k.trim());

  console.log('Starting Apollo search with filters:', {
    technologies: selectedTechnologies,
    keywords,
    employeesMin: params.employeesMin,
    employeesMax: params.employeesMax,
    maxResults,
  });

  // Build search criteria object to store with each company
  const searchCriteria = {
    technologies: selectedTechnologies,
    keywords,
    employeesMin: params.employeesMin,
    employeesMax: params.employeesMax,
    revenueMin: params.revenueMin,
    revenueMax: params.revenueMax,
    searchedAt: new Date().toISOString(),
  };

  // Step 1: Fetch organizations from Apollo
  const apolloResponse = await fetch(
    'https://api.apollo.io/api/v1/mixed_companies/search',
    {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-Api-Key': apolloApiKey,
      },
      body: JSON.stringify({
        per_page: Math.min(maxResults, 100),
        organization_num_employees_ranges:
          params.employeesMin || params.employeesMax
            ? [`${params.employeesMin ?? 1},${params.employeesMax ?? 10000}`]
            : undefined,
        revenue_range:
          params.revenueMin || params.revenueMax
            ? { min: params.revenueMin, max: params.revenueMax }
            : undefined,
        currently_using_any_of_technology_uids: selectedTechnologies,
        q_organization_keyword_tags: keywords,
      }),
    }
  );

  if (!apolloResponse.ok) {
    throw new Error(`Apollo API error: ${apolloResponse.status}`);
  }

  const apolloData = (await apolloResponse.json()) as {
    organizations?: Array<{
      id: string;
      name: string;
      primary_domain?: string;
      estimated_num_employees?: number;
    }>;
  };
  const organizations = apolloData.organizations ?? [];
  result.fetched = organizations.length;

  console.log(`Apollo returned ${organizations.length} organizations`);
  if (organizations.length === 0) {
    console.warn('Search exhausted: No organizations found matching filters');
  } else if (organizations.length < maxResults) {
    console.log(
      `Search complete: Found all ${organizations.length} matching organizations (fewer than max ${maxResults})`
    );
  }

  // Step 2: Upsert each organization into Twenty
  const apolloOrgIds: string[] = [];

  for (const org of organizations) {
    try {
      console.log(`Processing: ${org.name} (${org.primary_domain ?? 'no domain'})`);
      // Check if company exists by Apollo org ID or domain
      const existing = await client.query({
        companies: {
          __args: {
            filter: {
              or: [
                { apolloOrgId: { eq: org.id } },
                {
                  domainName: {
                    primaryLinkUrl: { eq: org.primary_domain ?? '' },
                  },
                },
              ],
            },
            first: 1,
          },
          edges: { node: { id: true, apolloSearchCriteria: true } },
        },
      });

      const existingCompany = existing.companies?.edges?.[0]?.node;

      if (existingCompany) {
        // Update existing - merge search criteria
        const mergedCriteria = mergeSearchCriteria(
          existingCompany.apolloSearchCriteria as SearchCriteria | null,
          searchCriteria
        );
        await client.mutation({
          updateCompany: {
            __args: {
              id: existingCompany.id,
              data: {
                apolloOrgId: org.id,
                hasApolloAccount: true,
                apolloSearchCriteria: mergedCriteria,
              },
            },
            id: true,
          },
        });
        console.log(`  -> Updated existing company`);
        result.updated++;
        result.companies.push({
          id: existingCompany.id,
          name: org.name,
          domain: org.primary_domain ?? '',
          isNew: false,
        });
      } else {
        // Create new company
        const newCriteria = mergeSearchCriteria(null, searchCriteria);
        const created = await client.mutation({
          createCompany: {
            __args: {
              data: {
                name: org.name,
                apolloOrgId: org.id,
                hasApolloAccount: true,
                apolloSearchCriteria: newCriteria,
                domainName: {
                  primaryLinkUrl: org.primary_domain ?? '',
                  primaryLinkLabel: org.primary_domain ?? '',
                },
                employees: org.estimated_num_employees,
              },
            },
            id: true,
          },
        });
        console.log(`  -> Created new company`);
        result.created++;
        result.companies.push({
          id: created.createCompany?.id ?? '',
          name: org.name,
          domain: org.primary_domain ?? '',
          isNew: true,
        });
      }

      apolloOrgIds.push(org.id);
    } catch (error) {
      result.errors.push(`Failed to upsert ${org.name}: ${String(error)}`);
    }
  }

  // Step 3: Create accounts in Apollo (excludes from future searches)
  if (apolloOrgIds.length > 0) {
    console.log(`Creating ${apolloOrgIds.length} accounts in Apollo...`);
    try {
      const accountsResponse = await fetch(
        'https://api.apollo.io/api/v1/accounts/bulk_create',
        {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'X-Api-Key': apolloApiKey,
          },
          body: JSON.stringify({
            accounts: apolloOrgIds.map((orgId) => ({
              organization_id: orgId,
            })),
          }),
        }
      );

      if (accountsResponse.ok) {
        result.accountsCreated = apolloOrgIds.length;
        console.log(`Marked ${apolloOrgIds.length} companies as accounts in Apollo`);
      } else {
        result.errors.push(
          `Failed to create Apollo accounts: ${accountsResponse.status}`
        );
      }
    } catch (error) {
      result.errors.push(`Apollo bulk_create error: ${String(error)}`);
    }
  }

  console.log(
    `Completed: ${result.created} created, ${result.updated} updated, ${result.fetched} total`
  );
  if (result.errors.length > 0) {
    console.error(`Encountered ${result.errors.length} error(s):`, result.errors);
  }

  return result;
};

export default defineLogicFunction({
  universalIdentifier: 'f8a2b3c4-d5e6-7890-abcd-123456789abc',
  name: 'get-apollo-leads',
  description:
    'Fetches leads from Apollo and imports them as companies in Twenty',
  timeoutSeconds: 300,
  handler,
  workflowActionTriggerSettings: {
    label: 'Get Apollo Leads',
    icon: 'IconCloudDownload',
    inputSchema: jsonSchemaToInputSchema(inputSchema),
    outputSchema: [
      {
        type: 'object',
        label: 'Result',
        properties: {
          fetched: { type: 'number', label: 'Fetched' },
          created: { type: 'number', label: 'Created' },
          updated: { type: 'number', label: 'Updated' },
          accountsCreated: { type: 'number', label: 'Accounts Created' },
          companies: {
            type: 'array',
            label: 'Companies',
            items: {
              type: 'object',
              properties: {
                id: { type: 'string', label: 'ID' },
                name: { type: 'string', label: 'Name' },
                domain: { type: 'string', label: 'Domain' },
                isNew: { type: 'boolean', label: 'Is New' },
              },
            },
          },
          errors: {
            type: 'array',
            label: 'Errors',
            items: { type: 'string' },
          },
        },
      },
    ],
  },
});
