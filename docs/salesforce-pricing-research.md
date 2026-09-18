# Research Questions Template

**Essay:** 100 Records Shouldn't Be Hard

## Main Question

The essay is really asking:

> Why do visual workflow builders struggle with tasks that code handles trivially, and is the convenience trade-off actually worth it for most businesses?

## Subquestions

1. How does Salesforce actually price workflow automation (Flex Credits, per-conversation, per-user)?
2. Why do workflow builders need to store state for every step? Is this architecturally unavoidable?
3. Is this inefficiency universal across workflow tools (Zapier, Make, Salesforce, Twenty) or specific to certain implementations?
4. At what scale does workflow automation become clearly cheaper than manual labor, despite the inefficiency?
5. What's the actual cost of an embedded developer vs Salesforce credits for a typical SMB?

## Terms I Need to Understand

| Term | My current understanding | Need to verify? |
|---|---|---|
| Flex Credits | Salesforce's pricing unit - $0.005/credit, 20 credits per action = $0.10 | yes - confirm current pricing |
| BullMQ | Redis-based job queue used by Twenty for workflow state | no - you experienced it |
| Governor limits | Salesforce's execution constraints (CPU, memory, queries) | yes - relevant context |
| LTV:CAC | Lifetime value to customer acquisition cost ratio | no - standard term |
| Workflow state management | Storing intermediate results for pause/resume/debug | no - you diagnosed this |

## Claims That Need Support

| Claim | What kind of support would be enough? | Possible source type |
|---|---|---|
| Salesforce charges $0.10 per action | Official pricing | Salesforce docs or pricing page |
| 200,000 free credits/year, no rollover | Official pricing | Salesforce docs |
| Workflow builders must store state for every step | Architectural explanation | Practitioner blog, docs, or logical argument |
| $160/month approaches VA cost for same task | Rough cost comparison | Anecdote + common knowledge (VA rates) |
| Twenty cloud also uses credits | Confirms pattern isn't Twenty-specific | Twenty pricing page |
| Hardware has improved faster than software efficiency | Industry observation | Could cite Wirth's Law or similar |

## Claims That Can Be Personal Experience

- Redis hit 2+ GB for 100 companies (your monitoring data)
- 100,000+ entries in Redis for 100 records (your `redis-cli --bigkeys` output)
- Coded solution used 45 MB (your observation)
- Workflow got stuck at 34 inserts (your experience)
- Development time was less than 1 day (your experience)
- Kubernetes overhead costs ~$10/month (your infra costs)
- Cascading workflows caused the explosion (your architecture)

## Counterarguments I Need to Take Seriously

- Salesforce probably wouldn't crash - they've sized their infrastructure (acknowledged in essay)
- Visual workflows provide audit trails and compliance benefits
- Developer time is genuinely expensive for most companies
- At enterprise scale (20+ VAs), credits become cheaper than headcount
- AI is making low-code tools more capable
- Some businesses don't have access to developers at any price

## Search Phrases

- "Salesforce Agentforce pricing 2026"
- "Salesforce Flex Credits cost per action"
- "workflow builder memory usage architecture"
- "BullMQ Redis memory consumption"
- "low-code hidden costs enterprise"
- "Zapier pricing vs custom development"
- "Wirth's Law software bloat"
- "Twenty CRM cloud pricing credits"
