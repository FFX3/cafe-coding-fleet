# Source Note Template

**Essay:** 100 Records Shouldn't Be Hard

**Source title:** Avoid Flow Limits (Flow Implementation I)

**Author / org:** Salesforce Trailhead (official documentation)

**URL / citation:** https://trailhead.salesforce.com/content/learn/modules/flow-implementation-1/avoid-flow-limits

**Date accessed:** 2026-09-16

**Source type:** docs / official training material

## Why I Am Reading This

To understand how Salesforce Flow handles the same problem Twenty crashed on. Salesforce is more sophisticated - they have bulkification patterns and don't charge per action for Flow. But they have hard limits that require developer thinking to work around.

## What This Source Claims

### Per-Transaction Governor Limits

| Type | Limit |
|------|-------|
| SOQL queries | 100 per transaction |
| Records retrieved by SOQL | 50,000 per transaction |
| DML statements | 150 per transaction |
| Records created/updated/deleted | 10,000 per transaction |
| CPU time | 10 seconds per transaction |

### What Causes These Limits to Be Hit

- **Get Records inside a loop**: Each iteration = 1 SOQL query. 100+ iterations = flow fails.
- **Create/Update/Delete inside a loop**: Each iteration = 1 DML statement. 150+ iterations = flow fails.
- **No filters on queries**: Retrieving all records instead of just the ones you need.
- **Flows triggered by other automation**: Limits are shared across the entire transaction chain.

### The Fix (Bulkification)

- Get Records: **before** the loop (query once, loop through collection)
- Create/Update/Delete: **after** the loop (collect changes, then bulk write)
- Use collection variables to accumulate changes
- Use filters to minimize records retrieved

### Transaction Boundaries

A transaction ends at Screen elements or Wait elements. New transaction = fresh limits. This is an escape hatch but requires restructuring your flow.

## What It Supports

This helps my essay because:

- Even Salesforce's more sophisticated system has hard ceilings - "they can bring any flow to a crashing halt without warning"
- The fix requires thinking like a developer: understanding why "query inside loop" is bad, using collection variables, restructuring flow logic
- "You might be thinking, 'There's no way I'll ever come close to hitting those limits.' But it's easier than you think." - exactly my point
- The example flow that "will fail if the org contains more than 10,000 contacts" - and that's considered a *lot* of records to them. I crashed on 100.
- Flows started by other automation share limits - this is exactly what happened with my cascading workflows

## What It Complicates

This challenges or narrows my view because:

- Salesforce Flow is genuinely more capable than Twenty workflows. They have patterns to work around limits.
- The limits are high enough for most use cases (100 queries, 150 DML, 10k records)
- They provide training on how to avoid these issues
- Twenty doesn't have bulkification - it just crashes (or charges credits on cloud)

**Key distinction:** My Twenty crash was architectural (Redis OOM from state management). Salesforce Flow limits are about query/write counts, not memory. Different failure modes. Salesforce is more sophisticated, but the "no-code" promise still breaks down when you need to understand bulkification.

## Useful Quotes / Paraphrases

> "Salesforce calls these governor limits... they apply to every flow, they're easy to exceed if you're not careful, and they can bring any flow to a crashing halt without warning."

> "You might be thinking, 'There's no way I'll ever come close to hitting those limits.' But it's easier than you think."

> "To avoid hitting these limits, don't put Get Records, Create Records, Update Records, or Delete Records elements inside a loop."

> "If a flow is started by another automation, it runs as part of that first automation's transaction." - limits are shared across the chain

> The example: "this flow will fail if the org contains more than 10,000 contacts"

## Reliability / Limits

Why I trust this source:

- Official Salesforce training material
- Primary source for how their platform actually works
- Specific numbers, not vague claims

What this source does **not** prove:

- What happens when you hit limits (does it fail gracefully? roll back?)
- How often real users actually hit these limits
- Whether the 10k record limit is enough for enterprise use cases
- Cost - Flow is included in license but the license itself is expensive

## How I Might Use It

- [x] Background context — "Even Salesforce, which is more sophisticated, has hard limits"
- [x] Direct citation — The specific numbers (100 SOQL, 150 DML, 10 seconds CPU)
- [ ] Counterargument — Salesforce is more capable than Twenty, but still requires dev thinking
- [ ] Further reading only

**Usage:** Show that even the enterprise-grade solution has limits that require developer knowledge. "Salesforce gives you bulkification patterns to work around governor limits - but using those patterns means understanding collection variables, query optimization, and loop restructuring. That's programming, just with a visual interface."

## The Scratch Connection

Salesforce Flow is actually much closer to Scratch than simpler tools like Zapier. Look at what you need to understand to use it properly:

- **Variables** (including collection variables)
- **Loops** (and why you can't put certain operations inside them)
- **Conditionals** (Decision elements)
- **Data structures** (record collections)
- **Query optimization** (filters, bulkification)
- **Transaction boundaries** (when state resets)

This is visual programming. It has all the concepts from a CS 101 class - variables, loops, conditionals, data structures - just represented as blocks instead of syntax.

Nobody claims Scratch isn't programming. They call it "visual programming" and use it to teach computational thinking. Salesforce Flow is the same thing, rebranded for business and called "no-code."

The label is marketing. The skill required is programming.
