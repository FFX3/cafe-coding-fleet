# 100 Records Shouldn't Be Hard

## The Problem with Salesforce Workflow Pricing

Salesforce has **three simultaneous pricing models** for automation and AI features, making costs nearly impossible to predict:

### 1. Flex Credits ($0.005 per credit)
- **Standard action**: 20 credits = **$0.10 per action**
- **Voice action**: 30 credits = **$0.15 per action**
- **Sandbox action**: 16 credits = **$0.08 per action**
- Sold in blocks of 100,000 credits for $500

### 2. Per-Conversation Pricing
- **$2.00 per AI conversation**
- No volume discounts at lower tiers

### 3. Per-User Licensing
- **Agentforce add-ons**: $125-$150/user/month
- **Agentforce Service Edition**: $550/user/month
- **Einstein Bots**: Additional $75/user/month
- Base Enterprise tier: $165-$175/user/month

### Free Tier Limits
- 100,000-200,000 credits/org/year (Enterprise+)
- **Credits do not roll over**

---

## The Hidden Complexity

Building automations on Salesforce means juggling:

1. **Technical constraints** - memory limits, execution timeouts, governor limits
2. **Performance trade-offs** - bulkification vs. readability
3. **Credit consumption** - now every action has a dollar cost attached

### Why Credits Exist (It's Not Just Greed)

Salesforce's credit system reflects a real problem: **generalized workflow builders are expensive to run**.

A visual workflow tool doesn't know in advance how data will be processed. It needs to:
- Store intermediate state for every step
- Handle arbitrary branching and error recovery
- Keep execution context in memory (likely Redis or similar)
- Support pause/resume for long-running flows

We saw this firsthand with Twenty CRM. The task: **import 100 companies from Apollo.io**.

The workflow approach required:
1. HTTP Request node to call Apollo API
2. Loop node to iterate through results
3. For each company: check if exists, then create or update
4. Store search metadata with each record
5. Call Apollo API again to mark as "account" (prevents duplicates in future searches)

### The Debugging Nightmare

The workflow got stuck at 34 inserts. Redis was OOM-killed repeatedly. We spent hours debugging:

**Initial theory:** Job payloads must be huge. But checking the code revealed jobs only store IDs:
```typescript
export type RunWorkflowJobData = {
  workspaceId: string;
  workflowRunId: string;
  lastExecutedStepId?: string;
};
```

**What we actually found** using `redis-cli --bigkeys`:
```
bull:trigger-queue:events         - 10,075 entries
bull:entity-events-to-db-queue:events - 10,061 entries
bull:webhook-queue:events         - 10,033 entries
12 lists with 100,802 items total
```

**100,000+ items** for 100 companies. Each workflow step generates:
- BullMQ job metadata
- Completion events (never trimmed)
- Failed job retention (7 days)
- Completed job retention (4 hours × 1000 jobs)

Even with tiny payloads, the sheer volume of state overwhelmed Redis. At one point we saw:
- `used_memory_human: 914.62M` (for 38 workflow runs)
- Peaked at **1.7-2+ GB** before OOM crashes

### The Math That Broke Us

A generalized workflow system doesn't know in advance what operations you'll perform. It must:
- Store intermediate state for every step
- Keep execution context for pause/resume
- Track events for debugging and retry logic
- Handle arbitrary branching

For our 100 companies, with ~5 steps each, plus triggered child workflows:
```
100 companies × 5 steps × event retention × child workflows
= tens of thousands of Redis entries
= 800MB+ memory for 100 records
```

**Results:**
- **Workflow-based approach**: Redis grew to **2+ GB**, repeatedly crashing with OOM errors
- **Coded solution (Twenty App)**: Redis sits at **45 MB** doing the same work

That's a **40-60x difference** in memory usage for importing 100 records. The coded solution also completed almost instantly, while the workflow approach was noticeably slower due to the overhead of state management between steps. Salesforce has to pass those infrastructure costs on somehow - credits are how they keep the model viable.

The "mobile game monetization" framing still applies though: by converting dollars to "credits," the actual cost becomes abstract. A workflow that makes 200 API calls doesn't feel like $20 - it feels like "200 credits."

### Real Example: Lead Enrichment

A typical lead enrichment workflow might:
- Trigger on new lead (1 action)
- Query external API (1 action)
- Update 5 fields (5 actions)
- Create a task (1 action)
- Send notification (1 action)

That's **9 actions = $0.90 per lead**. Process 1,000 leads/month = **$900/month** just for one workflow.

With the free tier of 200,000 credits, you'd burn through your annual allocation in ~2.5 months.

---

## The Custom App Alternative

### What We Built
An Apollo.io integration for Twenty CRM that:
- Searches Apollo for leads by technology, keywords, revenue, employee count
- Creates/updates Company records automatically
- Tracks search metadata across multiple queries
- Marks companies as accounts in Apollo to prevent duplicates

**Development time**: Less than 1 day

### Cost Comparison

| Metric | Salesforce | Custom Twenty App |
|--------|------------|-------------------|
| Per workflow run | $0.10-$2.00+ | $0 |
| Monthly automation cost | Unpredictable | Fixed hosting |
| Speed | Credit-throttled | Instant |
| Customization | Limited by platform | Full code control |
| Vendor lock-in | High | None |

### What You Get
- **No per-action charges** - run workflows unlimited times
- **Full optimization control** - fix memory issues in code, not by paying more
- **Instant execution** - no artificial throttling
- **Predictable costs** - hosting is a fixed monthly cost

---

## Honest Caveats

This approach isn't free:

1. **AI features still cost money** - if we add GPT-based enrichment, that's billed per-use (passed through to client)
2. **External API limits exist** - Apollo has 2,000 credits/month on our plan
3. **Requires development capability** - you need someone who can write code
4. **Self-hosted infrastructure** - you manage the servers (or pay for managed hosting)

The difference: these costs are **transparent and predictable**, not hidden behind virtual currency.

---

## For Non-Technical Readers: Why This Happens

You don't need to understand code to understand why workflow builders are so expensive. Here's the simplest explanation:

### The Cookbook Analogy

**When you cook from a recipe**, you don't write down what you're doing after every single step:

1. Crack eggs into bowl *(you don't photograph the bowl)*
2. Add flour *(you don't write "flour added" in a notebook)*
3. Mix together *(you don't save the spoon position)*
4. Pour into pan *(you don't record the pour angle)*

You just... do it. Your brain holds the context. When you're done, the only thing that exists is the finished dish.

**A workflow builder is like a cook who must document everything** - in case they get interrupted, in case someone else needs to take over, in case something goes wrong and they need to undo it:

1. Crack eggs into bowl → *photograph bowl, save to filing cabinet*
2. Add flour → *photograph bowl, save to filing cabinet*
3. Mix together → *photograph bowl, save to filing cabinet*
4. Pour into pan → *photograph bowl, save to filing cabinet*

Now imagine doing this for 100 dishes simultaneously. Your kitchen fills up with filing cabinets. That's what happened to our Redis database.

### What Actually Happens: Workflow vs Code

**Workflow approach** (what Salesforce/visual builders do):

```
Step 1: "Get 100 companies from Apollo"
        → Save result to memory: "Here are 100 companies"
        → Save state: "I completed step 1"

Step 2: "Loop through each company"
        → For company #1:
            → Save state: "I'm on company #1"
            → Save state: "I'm about to check if it exists"
            → Save result: "It doesn't exist"
            → Save state: "I'm about to create it"
            → Save result: "Created successfully"
            → Save state: "Moving to company #2"
        → For company #2:
            → (repeat all the saves...)
        → ... 98 more times
```

Each "save" goes into a database. The system doesn't know if you'll pause, if you'll want to debug later, or if you'll undo. So it saves *everything*.

**Code approach** (what we built):

```
Get 100 companies from Apollo
For each company:
    Does it exist? Create or update it.
Done.
```

The computer's processor just... does it. No saving intermediate state. No filing cabinets. When it's done, the only thing that exists is the result in your CRM.

### The Low-Code Promise vs Reality

This is the story of "low-code" and "no-code" tools everywhere:

| The Promise | The Reality |
|------------|-------------|
| "Anyone can build automations!" | Anyone can build *simple* automations |
| "No developers needed!" | Until you hit limits, then you need expensive consultants |
| "Faster than coding!" | Faster to start, slower to run, impossible to optimize |
| "Enterprise-ready!" | Enterprise-priced, because the inefficiency has to be paid for somehow |

Visual workflow builders trade **execution efficiency for ease of creation**. That's a valid trade-off for simple tasks. But when you're processing thousands of records, the inefficiency compounds.

Salesforce isn't being greedy with credits (well, not *only* greedy). They're passing on real infrastructure costs. Their servers genuinely use more resources to run a visual workflow than to run equivalent code.

### The Punchline

We didn't use any special tricks. No AI magic. No proprietary algorithms. Just:

- A programming language (TypeScript)
- A web framework (Next.js)
- Basic programming concepts taught in every CS 101 class

The workflow builder needed **2+ GB of memory** and crashed repeatedly.

Our code needed **45 MB** and finished instantly.

Same task. Same result. 40x less resources.

The "low-code tax" is real, and Salesforce is just honest enough to itemize it on your bill.

### The Irony: Code Has Fewer Constraints

Engineering, at its core, is building solutions within constraints. The irony is that as a trained professional, I find code *easier* to work with - not harder. Why? Because there are **fewer constraints**, not more.

With a visual workflow builder:
- You can only do what the boxes allow
- You can't optimize what you can't see
- You're constrained by someone else's abstraction

With code:
- If the computer can do it, you can write it
- You see exactly what's happening
- You control every trade-off

This isn't elitism. It's the opposite. The "easy" tool has more walls. The "hard" tool has more freedom.

### Let's Talk About Scale

Here's what made me question everything: **the system choked on 100 records**.

In IT, when we talk about "scale," we're talking about:
- Millions of records (normal)
- Hundreds of thousands (small-to-medium)
- Tens of thousands (trivial)

**One hundred** is not a scale problem. One hundred is a rounding error. My laptop could process 100 records in memory while running a video call, playing music, and rendering a 3D game.

When I saw Twenty CRM's Redis crash on 100 company imports, my trained mind went somewhere dark: *"Is this product even production-ready?"*

I was evaluating Twenty as part of choosing my tech stack - eating my own dog food. This failure seemed so absurd that I nearly wrote off the entire platform.

Then I discovered Twenty's "app" system - a way to create custom workflow blocks with actual code. One TypeScript file later, the same task that crashed the workflow builder ran instantly with 45MB of memory.

The platform wasn't broken. The workflow abstraction was just that inefficient.

### Your Computer Is More Capable Than You Think

Here's what frustrates me: modern computers are *incredibly* powerful. Your phone has more processing power than the computers that sent humans to the moon. Your laptop could simulate entire economies, render photorealistic worlds, or process millions of database records per second.

But you'd never know it from using modern software.

Hardware has gotten exponentially better over decades. But software has gotten... sloppier. We've traded performance for developer convenience. We've added layers of abstraction that eat resources. We've built systems that assume infinite memory and infinite patience.

The hardware engineers held up their end of the bargain. The software industry spent that dividend on complexity instead of capability.

### A Pragmatic Note

I'm not saying "code everything yourself." That would be absurd.

Modern software genuinely does more than it used to. Websites have tracking pixels, A/B testing, personalization, accessibility features, security headers, GDPR consent flows. There's real capability behind the bloat - not all of it is waste.

Developers are expensive. Saving their time is a legitimate business concern. That's why I'm using Twenty CRM instead of building my own from scratch. (Though it's open source, and I'm maintaining a fork to vet upstream commits for security - because trade-offs.)

The issue isn't abstraction. Abstraction is good. The issue is **where the abstraction breaks down**.

Here's an example of abstraction done right: I run Kubernetes on a single node. A full control plane for one server is objectively silly - it's overhead I don't need. But here's what I get:

Configuring servers imperatively is a mess. You need to check where things are installed, figure out what distro you're on, what version, what packages are available. This is already chaotic for humans. For AI, it's a recipe for getting lost.

By using Talos Linux (which has no SSH) and Kubernetes (which is entirely declarative), I've made a decision: **the code is the source of truth**. If the server state doesn't match the code, that's a bug - not a "let me poke around and figure out what's happening" situation.

What this means for AI tools:
- They don't need to SSH in and explore to find current state
- They know Talos doesn't have SSH, so they don't bother trying
- Everything they need is in the manifests - text files they can read and modify
- Code and current state are always in parity

I'm not having AI work *on* my servers. I'm having AI work on the *factory that creates my servers*. The entire infrastructure becomes **text** - something LLMs can process without external tools.

Trade-off? Instead of a small GCP instance, I need a medium. About **$10/month** extra. But I'm paying for **clarity and maintainability**, not for inefficiency.

Ten dollars a month to make my entire infrastructure AI-readable and drift-proof.

Compare that to Salesforce's workflow pricing. Our 100-company Apollo import had roughly:
- 1 API call to fetch companies
- 100 iterations, each with: existence check, create/update, metadata save
- 100 API calls to mark as accounts in Apollo

That's **~400 actions × $0.10 = $40 per run**. Run it weekly to find new leads? **$160/month** - just for one workflow that crashed anyway.

My Kubernetes "overhead" costs $10/month and makes everything work better. Salesforce's workflow "convenience" costs $160/month and couldn't handle 100 records.

**A practical note for business owners:** If your LTV-to-CAC is crazy good, maybe you don't care about workflow bills - and that's fine. But consider what else that $160/month could buy.

Controlling your own system isn't just about avoiding Salesforce costs - it lets you optimize SOPs in ways workflow builders can't touch. Imagine storing email templates in a knowledge base like Outline, tagged by use case. Your system pulls the right template automatically based on context. Your team uses Outline as a general note-taking tool to build SOPs, save templates, document processes. Down the line, you point AI at it - now it's a new employee coach trained on *your* actual procedures.

(Notice how many people would jump straight to AI for this. AI is cool and I use it. But people underestimate what you can get done with old-fashioned code. When you add AI to a highly deterministic system - plugging very narrow holes instead of doing everything - two things happen: you get reliable results, and your token spending plummets. You probably don't even need the fancy new models at that point. I'm not saying don't use AI. I'm saying there are many ways to approach these problems, and depending on *your* constraints, there's probably a better solution you haven't considered - or didn't know was possible.)

The point is: if $160/month for one workflow feels cheap to you, I'm saying you could get *so much more* for that same $160.

And at $160/month for a workflow that imports 100 leads weekly? You could pay someone $160/month to manually search Apollo and copy-paste the leads into your CRM. The "automation" costs the same as doing it by hand.

(To be fair: Salesforce probably wouldn't crash - they've sized their infrastructure for the inefficiency. My self-hosted Twenty instance crashed because I didn't expect memory usage to climb so fast. Salesforce just passes that infrastructure cost to you as credits. Same inefficiency, different failure mode.)

A CRM that handles users, permissions, data models, and UI? Worth the trade-off. I don't want to rebuild that.

A workflow system that chokes on 100 records? That's where I draw the line.

And here's the thing: even if it had been **10,000 records**, I'd be asking the same questions. Ten thousand is still trivial. My laptop processes more data than that loading a single web page.

The bar for "this system is struggling" should be somewhere in the hundreds of thousands, minimum. When a system struggles at double digits, something has gone fundamentally wrong with our expectations of what computers can do.

### The Bigger Picture

This isn't just a Salesforce problem. It's everywhere:

- **Operating systems** that need 8GB of RAM to show you a desktop
- **Web pages** that load 20MB of JavaScript to display text
- **Mobile apps** that drain your battery doing nothing
- **AI tools** that made this worse, generating bloated code faster than ever

It's why I use Linux for work. Not because I enjoy configuring things, but because I'm not forced into problematic updates, mysterious slowdowns, or systems that fight me. I control it. I understand it.

The trade-off is real: **you can let the system control you, or you can understand the system**. There's no free lunch. The "easy" path puts you at the mercy of someone else's constraints - and someone else's pricing.

---

## Summary

Salesforce's credit system adds a tax on every automation. But this isn't really about Salesforce - they're just the most honest about charging for inefficiency.

The real story is about a choice that every business faces:

**Option A: The "Easy" Path**
- Visual tools that anyone can use
- Hidden complexity, hidden costs
- You're limited by what the vendor anticipated
- When it breaks, you call support and wait

**Option B: The "Hard" Path**
- Code that does exactly what you need
- Transparent complexity, predictable costs
- You're limited only by what computers can do
- When it breaks, you fix it

We built an Apollo.io integration in less than a day. It runs unlimited times for $0 per execution. The same workflow in Salesforce would cost $0.10+ per run and crash on 100 records.

The upfront investment in understanding your tools pays dividends forever. The "easy" path extracts rent forever.

**The trade-off isn't complexity vs simplicity. It's control vs convenience.**

Choose wisely.

---

## Sources

- [Salesforce Agentforce Credits & Cost Model: Complete Guide 2026](https://www.jitendrazaa.com/blog/salesforce/salesforce-agentforce-credits-cost-model-complete-guide-2026/)
- [The New Salesforce Agentforce Pricing Model: From $2 Conversations to $0.10 Actions](https://www.concret.io/blog/new-agentforce-pricing-model)
- [Salesforce Agentforce Pricing 2026](https://coworker.ai/blog/salesforce-agentforce-pricing)
- [Agentforce Pricing Explained: Flex Credits, Real Costs & Hidden Fees](https://www.getclientell.com/guides/agentforce-pricing-explained)
- [Salesforce Agentforce Pricing Breakdown: $125-$650 Per User Reality Check](https://www.oliv.ai/blog/salesforce-agentforce-pricing-breakdown)
- [Salesforce Einstein chatbot pricing in 2026](https://www.eesel.ai/blog/salesforce-einstein-chatbot-pricing)
