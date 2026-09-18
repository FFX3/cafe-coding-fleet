**Essay:** 100 Records Shouldn't Be Hard

## Source Mix Goal

Try to collect:

- [x] 1 historical/context source
- [x] 1 practitioner essay/talk
- [x] 1 source that explains the mainstream/default view
- [x] 1 source that disagrees with or complicates me
- [x] 1 precise technical source if needed

## Candidate Sources

| Source                                                                                                                                                                                                     | Why it might matter                                                                                                | Keep? |
| ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------ | ----- |
| [Wirth's Law - Wikipedia](https://en.wikipedia.org/wiki/Wirth's_law)                                                                                                                                       | Historical context for "software is getting slower faster than hardware gets faster" - coined 1995, still relevant | yes   |
| [Wirth's Law and the Story of 'Fatware'](https://laptopretrospective.com/laptops/wirths-law-and-the-story-of-fatware/)                                                                                     | More narrative version of the history, includes Office 2000 vs 2007 example                                        | maybe |
| [Low-Code Limitations and When to Own the Code - Reflex.dev](https://reflex.dev/blog/low-code-limitations)                                                                                                 | Practitioner perspective on portability, customization ceilings, cost at scale                                     | yes   |
| [10 Challenges of Enterprise Low-code - Kyanon Digital](https://kyanon.digital/blog/10-challenges-of-enterprise-low-code/)                                                                                 | Lists vendor lock-in, performance tax, hidden costs - validates my claims                                          | yes   |
| [Why Low-Code Platforms Eventually Face Limitations - BayTech](https://www.baytechconsulting.com/blog/why-most-low-code-platforms-eventually-face-limitations-and-strategic-considerations-for-the-future) | "Performance tax becomes visible only during peak loads" - exactly my experience                                   | yes   |
| [6 Reasons Why Low-Code Is the Future - Medium](https://medium.com/@eastgate/6-reasons-why-low-code-no-code-is-the-future-of-software-development-f493f8491112)                                            | Mainstream pro-low-code view - speed, cost reduction, accessibility                                                | yes   |
| [Gartner: 65% of apps will be low-code by 2024](https://www.eleken.co/blog-posts/is-low-code-no-code-the-future-of-software-development)                                                                   | Cites Forrester (83% flexibility, 63% speed) and Gartner projections                                               | yes   |
| [Business Process Automation with Salesforce: 8 Benefits - TechForce](https://www.techforceservices.com/blog/business-process-automation-salesforce/)                                                      | Defense of Salesforce automation ROI, cites "$3 trillion in manual error costs"                                    | yes   |
| [BullMQ Redis: Backbone of High-Performance Job Queues - Medium](https://medium.com/@raza78749/bullmq-redis-the-backbone-of-high-performance-job-queues-a3a3090e3807)                                      | Technical explanation of how Redis stores job state                                                                | yes   |
| [BullMQ Production Architecture at 500 Jobs/Second - Markaicode](https://markaicode.com/architecture/bullmq-production-system-design-architecture/)                                                        | Production patterns, explains why state management is expensive                                                    | yes   |
| [Salesforce Agentforce Credits Guide 2026 - Jitendra Zaa](https://www.jitendrazaa.com/blog/salesforce/salesforce-agentforce-credits-cost-model-complete-guide-2026/)                                       | Primary source for Flex Credits pricing ($0.10/action)                                                             | yes   |
| [Salesforce Agentforce Pricing Breakdown - Oliv.ai](https://www.oliv.ai/blog/salesforce-agentforce-pricing-breakdown)                                                                                      | $125-$650/user reality check                                                                                       | yes   |
| [Salesforce Flow Limits - Trailhead](https://trailhead.salesforce.com/content/learn/modules/flow-implementation-1/avoid-flow-limits)                                                                       | Official docs on governor limits - 100 SOQL queries, 10 sec CPU, 50k records                                       | yes   |
| [Governor Limits Explained - Salesforce Decoded](https://sfdecoded.github.io/guides/governor-limits.html)                                                                                                   | Clear breakdown of all governor limits with examples                                                               | yes   |
| [Salesforce Pricing 2026 - Redress Compliance](https://redresscompliance.com/salesforce-pricing-2026-complete-enterprise-guide.html)                                                                       | Enterprise $175/user/month, Professional $100-200/user/month                                                       | yes   |
| [Invoke Agentforce from Flow - Salesforce Developers](https://developer.salesforce.com/blogs/2025/04/invoke-agentforce-agents-with-apex-and-flow)                                                          | Shows Flow and Agentforce interop - they're separate but connected                                                 | yes   |

## Important Distinction: Salesforce Flow vs Agentforce

**Salesforce Flow** (traditional workflows) - included in your Salesforce license ($100-175/user/month). No per-action credits. But has **governor limits** - hard caps that fail your flow:
- 100 SOQL queries per transaction
- 10 seconds CPU time (sync)
- 50,000 records retrieved
- 150 DML operations

Put a "Get Records" inside a loop? 100 iterations = 100 queries = flow fails. Same problem as Twenty crashing on Redis, different failure mode.

**Agentforce** (AI agents) - this is where the $0.10/action Flex Credits apply. Newer AI platform, not traditional workflows.

**They interop:** You can invoke Agentforce agents from Flows, and Agentforce uses Flows as "Actions."

**For the essay:** The $0.10/action math applies to Agentforce (AI). Traditional Flow automation doesn't charge per action but hits governor limits instead - still forces you to think like a developer (bulkification, query optimization). The "no-code" promise breaks down either way.

## Best Sources So Far

1. **[Wirth's Law - Wikipedia](https://en.wikipedia.org/wiki/Wirth's_law)** - Historical anchor. "Software is getting slower more rapidly than hardware is becoming faster." Coined 1995, restated by Larry Page 2009. Perfect context for the hardware-vs-software argument.

2. **[Low-Code Limitations - Reflex.dev](https://reflex.dev/blog/low-code-limitations)** - Practitioner essay that names the exact problems: portability, customization ceilings, cost at scale. Written by people who build dev tools.

3. **[Is Low-Code/No-Code the Future? - Eleken](https://www.eleken.co/blog-posts/is-low-code-no-code-the-future-of-software-development)** - Mainstream view with Gartner/Forrester stats (83% flexibility, 63% speed, $14B market). Good for acknowledging what the industry believes, then pushing back.

4. **[BullMQ Production Architecture - Markaicode](https://markaicode.com/architecture/bullmq-production-system-design-architecture/)** - Technical source explaining why workflow engines need so much Redis state. Validates the architectural reality.

5. **[Salesforce Agentforce Credits Guide - Jitendra Zaa](https://www.jitendrazaa.com/blog/salesforce/salesforce-agentforce-credits-cost-model-complete-guide-2026/)** - Primary pricing source. $0.10/action, credit tiers, the math.

## Sources to Ignore

**Source:** Generic "low-code is amazing" marketing content from low-code vendors
**Reason to ignore:** Obvious bias, no new information, doesn't engage with limitations

**Source:** Salesforce's own marketing materials
**Reason to ignore:** Need third-party sources for pricing claims, not vendor spin

**Source:** Reddit/forum complaints without specifics
**Reason to ignore:** Anecdotes without data aren't better than my own anecdote with data

## Follow-Up Trails

People/books/talks/papers mentioned by sources:

- **Niklaus Wirth** - "A Plea for Lean Software" (1995) - the original paper behind Wirth's Law
- **Martin Reiser** - credited with the original observation that Wirth named
- **Oberon operating system** - Wirth's attempt to prove software could be lean (1986-1989)
- **Forrester research on low-code** - cited by multiple sources for enterprise adoption stats
- **Gartner low-code projections** - "65% of app development by 2024" claim worth verifying

