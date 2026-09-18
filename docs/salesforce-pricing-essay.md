# The Thing I Think

I currently think:

> The "low-code tax" is real. Visual workflow builders - tools like Salesforce Flow, Zapier, Make, and the workflow features in CRMs - trade execution efficiency for ease of creation. That inefficiency has to be paid for somewhere: either as crashed servers or as per-action "credits." At scale, this cost approaches or exceeds the cost of just doing things manually, negating the entire point of automation.

## Why I Think This

Personal experiences that pushed me here:

1. **I crashed a CRM importing 100 leads.** I was evaluating Twenty CRM (an open-source Salesforce alternative) for my business. I built a workflow to import companies from Apollo.io - a standard lead generation task. The workflow had five steps: fetch from API, loop through results, check if each company exists, create or update it, then mark it as imported in Apollo. Simple stuff. The workflow got stuck at 34 records. Redis (the in-memory database storing workflow state) hit 2+ GB of memory and crashed repeatedly. I spent hours debugging. Eventually I discovered Twenty has an "app" system where you can write actual code instead of using visual workflows. I rewrote the same logic in one TypeScript file. Same task, same result - but 45 MB of memory instead of 2 GB. It finished instantly instead of crashing.

2. **I did the math on what this would cost in Salesforce.** Salesforce charges "Flex Credits" for workflow automation - $0.10 per action. My 100-company import had roughly 400 actions (1 API fetch + 100 iterations × 3-4 actions each). That's $40 per workflow run. If I ran this weekly to find new leads, that's $160/month - for one workflow, on one tool. I'd have dozens of these. And here's the kicker: for $160/month, I could pay someone to manually search Apollo and copy-paste leads into my CRM. The "automation" costs the same as doing it by hand.

3. **I compared this to overhead that actually helps.** I run Kubernetes on a single server - objectively silly, a full control plane for one node. It costs me about $10/month extra versus a simpler setup. But that $10 buys me something real: my entire infrastructure is declarative (defined in text files), my servers can't drift from their intended state, and AI tools can help me manage everything because it's all just YAML manifests - no SSH-ing into servers to poke around. I'm paying for capability and clarity. The workflow overhead was paying for... the privilege of being slower and less capable.

## What Felt Wrong Before

The assumption/advice/pattern that now feels suspect:

> "No-code and low-code tools democratize automation. Anyone can build workflows without developers. It's faster than coding."

Why it bothered me:

- I watched a "simple" import workflow choke on 100 records while the coded version finished instantly. That's not faster.
- "No developers needed" works until you hit platform limits. Then you need expensive consultants who specialize in working around those constraints.
- The abstraction hides real resource costs. Those costs eventually surface as either crashes (if you're self-hosting) or bills (if you're on Salesforce).
- In IT, when we talk about "scale," we mean millions of records. Hundreds of thousands is small. Tens of thousands is trivial. **One hundred is a rounding error.** My laptop could process 100 records while running a video call and playing music. When a system struggles at double digits, something has gone fundamentally wrong with our expectations of what computers should do.

## What Changed My Mind

The turning point / contradiction / discovery:

- **I assumed the workflow was storing huge payloads.** Wrong. I checked the code - job data was just IDs, a few bytes each. The data wasn't the problem.

- **I found where the memory actually went.** Using `redis-cli --bigkeys`, I discovered 100,000+ entries in Redis for my 100 companies. How? I had another workflow that triggered whenever a company was created - it would create a contact for that company. Standard pattern. My import workflow was triggering the contact workflow, which was storing its own state, which cascaded. This is just how you design systems normally: small, composable pieces that trigger each other. But applying this general pattern to visual workflows broke everything. The state management infrastructure for each workflow step, times the cascade, dwarfed the actual work.

- **I realized why this happens.** A visual workflow builder doesn't know what you'll do in advance. It has to support: pausing mid-workflow, resuming later, debugging what happened, retrying failed steps, undoing changes. So it saves everything, at every step, just in case. My coded solution didn't need any of that - it just ran. When it finished, the only thing that existed was the result in my database.

- **I understood the business model.** Salesforce isn't being greedy (well, not *only* greedy). They've sized their infrastructure for this inefficiency. They're passing that real infrastructure cost to you as credits. Same underlying problem, different failure mode: I got crashes, Salesforce customers get bills.

## The Strongest Version of My Claim

If I say this boldly:

> Low-code workflow builders are a tax on people who don't understand that computers are capable of so much more. Your phone has more processing power than the computers that sent humans to the moon. Your laptop could simulate economies, render photorealistic worlds, or process millions of records per second. A system that charges you $0.10 per action and struggles with 100 records is not "enterprise-ready" - it's enterprise-priced for covering up architectural inefficiency. The "easy" path extracts rent forever; learning to work with code pays dividends forever.

## The More Careful Version

If I say this defensibly:

> Visual workflow builders trade execution efficiency for ease of creation. That's a valid trade-off for simple, low-volume tasks - a form submission that triggers an email, a weekly report, a handful of records updated on a schedule. But when you're processing thousands of records, the inefficiency compounds into real costs.

> Modern software genuinely does more than it used to: tracking pixels, A/B testing, GDPR flows, accessibility features. Not all bloat is waste. Developers are expensive, and saving their time matters. I use Twenty CRM instead of building my own for exactly this reason.

> The question is: where does the abstraction break down? A CRM that handles users, permissions, and data models? Worth it. A workflow system that costs $160/month for one automation and approaches the cost of just hiring someone to do it manually? That's where it's a little silly.

## What Would Change My Mind?

Evidence or argument that would weaken this essay - and why I'm not fully convinced:

- **Price drops:** Even at $16/month instead of $160, someone still needs to understand how the workflow works to update it as your company's SOPs change. The cost isn't just credits - it's the cognitive overhead of maintaining something you don't fully understand.

- **Architectural improvements:** If workflow builders managed memory properly, they'd need users to declare what data they need, when state should be saved, what can be discarded. At that point... you're coding. Welcome to the world of development. What I do is learnable - you probably just don't care to learn it, and that's fine. But if they made workflows efficient enough to compete with code, they'd be too complicated for untrained users. That's the fundamental trade-off.

- **Scale breakpoints:** The "VA doing it manually" comparison breaks down at scale - but not how you'd expect. It's much easier to buy more credits than to hire your 20th VA. That's why Salesforce credits work for enterprise. That's the arbitrage: workflow automation isn't actually that much more efficient than humans, but it scales without HR headaches. For large enterprises with money to burn, that's worth paying for.

- **Development cost reality:** Dev costs go up when the developer needs to learn your business from scratch. The math changes dramatically when the developer is *already embedded* and actively looking for RevOps optimization opportunities. That's my arbitrage. A retainer-based developer who understands your operations can spot inefficiencies you didn't know existed.

- **Twenty-specific bug:** Twenty CRM's cloud plans use credits too. The fact that Salesforce does the same thing is telling - this isn't a Twenty bug, it's an architectural reality of workflow systems. They all have the same underlying resource problem. Self-hosted crashes; cloud-hosted bills.

- **Hidden workflow benefits:** The ability for non-technical people to create workflows is genuinely cool. And my clients can still use workflows themselves - I'm not taking that away. The difference is: when they run into an issue like I did, their workflow becomes the *blueprint* I use to quickly create an optimized coded version. Their visual workflow isn't wasted work; it's a spec.

## Why Salesforce Still Wins (For Most Companies)

This arrangement - a developer embedded in your operations, converting workflows to code when needed - is rare. It's specific to how I run my practice. Most companies don't have this.

For the broader market, Salesforce is competitive because:
- They don't have a developer on retainer
- They don't want to manage infrastructure
- They'd rather pay credits than think about any of this
- The inefficiency is someone else's problem

That's a valid choice. I'm not saying it's wrong.

But let's be honest about what "expensive" means. It's not just the credits. It's:
- Time in meetings with Salesforce consultants
- Time learning the platform's quirks and limitations
- Time onboarding new staff on workflows that were supposed to be "simple"
- Time debugging why something broke when it worked last week
- Time waiting for support tickets to be resolved

Salesforce is expensive in dollars *and* in time. The credits are just the part that shows up on an invoice.

My retainer is expensive too - I'm not the budget option. For most of my clients, I'm the *premium* option. But what I'm selling is time. Faster implementation. No meetings about meetings. No learning curve for your team. No onboarding new hires on a complex system.

You email me what you need. I build it. It works. You move on with your day.

And I work directly with frontline staff - the people actually doing the work. That's how I know what workflows are needed. That's why I don't need boardroom meetings to gather requirements. The people clicking the buttons tell me what's slow, what's broken, what's annoying. I fix it. No telephone game through three layers of management.

This is why I work on retainer. The owner doesn't get a billing surprise when employees ask me for help - that's the whole point. Staff can reach out directly without worrying about budget approval for every small fix. The friction disappears. Problems get solved before they become formal "projects."

**That's the trade-off:** Salesforce costs money and time. I cost money and save time. For companies where the founder's time is the bottleneck, the math works out.
