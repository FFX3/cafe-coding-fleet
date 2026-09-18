# Why This Essay Exists

**Essay:** 100 Records Shouldn't Be Hard

## Why This Essay Exists

**Business/brand reason:**

Position myself as the alternative to hiring a Salesforce admin. My ICP (1-5mil revenue, <20 employees) is overloaded and thinking about hiring someone to manage their tools. I want them to find this essay and realize: there's a middle path. $42k/year for an embedded partner who manages the whole business suite, vs $75k+ for a junior admin who only knows Salesforce.

**Personal/intellectual reason:**

I'm frustrated by the "no-code is simple" narrative. I've cleaned up low-code messes. I watch people feel stupid when they struggle with tools that were supposed to be easy. The wizards who master these tools are discounting their own learning curve - the weekends they spent figuring it out. I want to validate the people who are struggling: you're not stupid, this is genuinely hard.

**What I am trying to understand:**

Why do people keep falling for the "no-code is simple" pitch? Is it marketing? Is it survivorship bias from the wizards? Is it that people don't know what they don't know about how computers actually work?

**What I want the reader to leave believing or questioning:**

- Believing: If you're struggling with low-code, that's normal. The tools are harder than advertised.
- Questioning: If I'm going to invest time learning these tools anyway, what's the real difference between that and learning to work with a developer? And if I'm going to hire someone, why limit myself to Salesforce when I could get someone who manages everything?

## Core Thesis

One-sentence thesis:

> Low-code tools are visual programming with extra constraints - if you can master them, you've already done the hard part, and if you're going to hire help anyway, there's a better path than a Salesforce admin.

Short version in plain English:

> The "no-code is simple" pitch is marketing. The people who master these tools are programmers who learned a visual syntax. If you're struggling, you're not stupid - the tools are genuinely hard. And if you're at the point of hiring someone to manage Salesforce, consider an embedded partner who handles your whole business suite for less.

## Boundaries

What I am **not** claiming:

- That everyone should learn to code
- That low-code has no value (it's better than nothing for people with no technical option)
- That Salesforce is a scam (they're passing real infrastructure costs to you)
- That my way is the only way (it's one option for a specific ICP)
- That I'm the budget option (I'm the premium option that happens to cost less than a full-time hire)

Who this essay is **not** for:

- Low-code wizards who've already mastered the tools (they're coders now, good for them)
- Enterprises with dedicated Salesforce teams (different economics)
- People who just need a basic contact database (Salesforce Starter or HubSpot Free is fine)
- Tinkerers who enjoy building workflows (have fun, this isn't for you)

## Personal Material

Relevant anecdotes:

- Crashed Twenty CRM importing 100 companies from Apollo
- Found 100,000+ Redis entries for 100 records (cascading workflows)
- Rewrote the same logic in one TypeScript file - 45MB vs 2GB, finished instantly
- Spent hours debugging before discovering Twenty's app system
- I find low-code tools HARDER than actual code, despite being a professional

Emotional center / irritation:

- People feeling stupid when they struggle with tools that were supposed to be "simple"
- Low-code wizards discounting their own learning curve
- The "anyone can do it" pitch that sets people up to feel like failures
- 100 records. One hundred. My laptop could do that while playing music.

Concrete examples I can use:

- 2GB Redis vs 45MB coded solution (same task, 40x difference)
- Salesforce governor limits: 100 SOQL queries, 10 sec CPU, flow crashes if exceeded
- "Don't put Get Records inside a loop" - that's programming knowledge
- $160/month for one workflow vs paying someone to do it manually
- $42k retainer vs $75k+ Salesforce admin salary
- Scratch (MIT's visual programming for kids) - same paradigm, different branding

## Research Questions

- Why do workflow builders need to store state for every step? (Answered: pause/resume/debug/retry)
- Is this inefficiency universal or specific to certain tools? (Answered: architectural reality, Salesforce handles it better but still has limits)
- At what scale does automation clearly beat manual labor? (Partially answered: enterprise scale with 20+ VAs, but that's not my ICP)
- What does a Salesforce admin actually cost? (Answered: $75k-119k + benefits)
- How do Salesforce Flow and Agentforce differ? (Answered: Flow is traditional workflows with governor limits, Agentforce is AI agents with per-action credits)

## Source Queue

| Source | Type | Why it matters | Status |
|---|---|---|---|
| Wirth's Law - Wikipedia | encyclopedia | Historical context, "software slower faster than hardware faster" | done |
| Eleken - Low-Code Future | essay | Mainstream view with Gartner/Forrester stats, good for pushback | done |
| Trailhead - Flow Limits | docs | Official Salesforce governor limits, proves even enterprise tools require dev thinking | done |
| Leadhaste - Salesforce Pricing | essay | Pricing breakdown for small business comparison | done |
| ZipRecruiter/Glassdoor | data | Salesforce admin salary ($75k-119k) for hiring comparison | done |
| Reflex.dev - Low-Code Limitations | essay | Practitioner perspective on portability, customization ceilings | queued |
| BullMQ Production Architecture | docs | Technical explanation of Redis state management | queued (maybe cut - too technical) |

## Parking Lot

Interesting, but maybe not this essay:

- Deep dive on BullMQ/Redis architecture (too technical for ICP)
- AI agents (Hermes, Agentforce) - separate essay about AI readiness
- Kubernetes/Talos/Nix setup details - mentioned briefly, not the point
- Twenty vs Salesforce feature comparison - not the argument
- Apollo.io integration specifics - context only
- Zapier/Make comparison - keep focus on Salesforce as enterprise benchmark
- The $10/month Kubernetes overhead story - good color but might distract
- Wirth's Law deep dive - just context, don't overdo it
