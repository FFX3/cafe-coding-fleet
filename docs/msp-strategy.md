# MSP Business Strategy

Fractional CTO ($3.5k/month) + done-for-you IT.

> **Note**: $3.5k/month might actually be too cheap. Low pricing can signal low confidence or attract clients who don't value the work. Revisit.

---

## Core Principle

**Build around client stacks, don't rip and replace.**

The pitch: "Keep everything that works. I'll fill the gaps."

Clients don't want a migration project. They want outcomes. Each gap filled builds trust, and trust leads to more of the stack over time. You're not selling rip-and-replace - you're selling incremental upside with controlled risk.

---

## What to Own vs Leave Alone

| Own | Leave Alone |
|-----|-------------|
| CRM (Twenty) | ERP (Shopify) |
| Landing pages (Webstudio) | Accounting (QuickBooks) |
| Password management (Passbolt) | Core business systems |
| AI/automation (Hermes) | Anything with years of process baked in |

**Why own these?**
- CRM, landing pages, passwords, automation - these are "standard stuff" every business has
- They're often SaaS wrappers around open source with margin on top
- Owning them means direct control: no ticket queues, no roadmap to wait for, no permission needed

**Why leave ERP/accounting alone?**
- High risk, low upside. Years of business process baked into these systems
- Migrations are nightmares (auditors, integrations, data)
- The ROI isn't there - focus energy elsewhere

---

## Cloudflare as Routing Layer

**DNS control is the leverage point.**

With Cloudflare Workers/Rules, you can route by path on the same domain:

```
example.com
├── /campaign-spring  → Webstudio (your stack)
├── /offer            → Webstudio
├── /*                → WordPress (origin)
```

Same domain, no subdomain, SEO stays intact, client's visitors see no difference.

This means:
- Insert landing pages without touching WordPress
- A/B test outside their CMS
- No migration risk
- WordPress admin keeps doing their thing, you build around them

Just need DNS through Cloudflare. Then you control the routing layer.

---

## WordPress Strategy

**Don't migrate. Don't fight it. Let it become legacy.**

WordPress is built for a weird market: people who "kinda want to learn web but not really." Too technical for pure business users, not flexible enough for real developers. Configuring WordPress is a waste of time.

The strategy:
- Year 1: WordPress handles everything
- Year 2: New campaigns → Webstudio, WordPress untouched
- Year 3: WordPress is just legacy static pages
- Year 4: Maybe sunset, maybe not - who cares, it works

No risky migration. No "we need to rebuild the site" conversation. Just gradual irrelevance. The WordPress admin becomes read-only maintenance. All new work happens in your stack.

---

## CRM as Strategic Play

**The big exception where you DO replace: Salesforce → Twenty.**

Salesforce is:
- Per-seat licensing that punishes growth
- API access paywalled
- Every integration needs a meeting
- AI features are upsells, not capabilities

Twenty under your control:
- Direct database access
- Add AI tooling yourself
- Integrate with Hermes for automation
- No permission needed, no roadmap to wait for

CRM is customer data. Own that and you're not IT - you're driving RevOps. That's CTO territory, not vendor territory. It puts you in position to integrate AI tooling and drive revenue operations forward without requiring meetings with external teams.

---

## Nix Investment

**Not over-engineering - buying yourself out of ops work.**

```
┌─────────────────────────────────────────────┐
│  Client sees: Shopify, WordPress, familiar  │
│  tools they already know                    │
└──────────────────┬──────────────────────────┘
                   │ plugins/integrations
┌──────────────────▼──────────────────────────┐
│  Your stack: Nix derivations, reproducible, │
│  one command deploys, self-healing          │
└──────────────────┬──────────────────────────┘
                   │ your time
┌──────────────────▼──────────────────────────┐
│  CTO work: strategy, decisions, value       │
└─────────────────────────────────────────────┘
```

The more automated the middle layer, the more hours you have for the $3.5k work instead of firefighting servers.

Future state: each app as a Nix derivation enables reproducible security testing. Spin up isolated test environments trivially, run red team against exact production configs, diff changes between versions.

The alarm bell about over-engineering comes from experience working on ONE application. But MSP complexity is inherently a complicated problem - orchestrating 10+ services, keeping them updated safely, reproducing environments per client. That complexity exists whether you manage it or not.

---

## Ownership Model

**No lock-in by design.**

Legal ownership is the client's:
- Cloudflare account under their vendor email (you manage, they own)
- Dedicated GCP project per client (transferable if they leave)
- AGPL licensing means source code is shared anyway

Practical dependency is on expertise, not lock-in:
- They COULD run it themselves - all assets are theirs
- But they won't, because they need someone to drive it forward
- Same as any company needing a CTO - not because they're trapped

If they want to leave, they take everything. The relationship is based on value, not hostage-taking. This is a differentiator from typical agencies/MSPs that hold assets hostage.

The code was never part of the value equation. The value is judgment, execution, and availability.

---

## Migration + Onboarding

**You ARE doing migrations - strategic ones.**

The "build around, don't replace" philosophy applies to high-risk, low-upside systems (ERP, accounting, legacy WordPress). But for CRM, landing pages, passwords - you're actively migrating them to better tools.

The deliverable isn't just "working systems":
- Better tools (Webstudio, Twenty, Passbolt)
- Client trained to use them
- You handle migration complexity
- Ongoing CTO support

You're not a vendor they depend on forever - you're making them more capable. This justifies more time per client and the pricing.

---

## Value Proposition

**Not selling cheaper tools. Selling competence and ownership.**

**What a $50/month SaaS gives you:**
- Tool access
- Ticket queue
- "We'll look into it"
- Status page

**What $3.5k/month from you gives them:**
- Someone who can actually fix it
- Direct line, not a queue
- Their IT is someone's actual priority
- No owner time wasted on vendor wrangling

Most "fractional CTOs" become expensive email routers:
```
Client → CTO → Vendor A → wait
              → Vendor B → wait
              → Vendor C → wait
              → Meeting to align vendors
              → Still waiting
```

You're building:
```
Client → You → Your stack → Done
```

The on-call burden is a feature, not a bug. You WANT to be on-call because you can actually fix things. No waiting on vendor support, no status reports and email chains - direct control means faster resolution.

The vendors you push out become hours you get back. Every SaaS you replace with your stack is one less email chain, one less "we'll escalate this."

---

## Gaps Analysis

Holes that were considered and addressed:

| Concern | Resolution |
|---------|------------|
| Sales pipeline | Cold email campaign with free audit (see Obsidian vault). Show visible problems like missing Meta pixel on sites running FB ads. |
| Time math | 5 clients = ~300k CAD. Can afford to be generous with time. |
| Scope creep | Target small headcount companies that don't need full IT team. When they grow, offboard and help hire replacement. |
| Upstream bugs | At 44k USD/client, that's standard dev salary. Can afford to fix upstream issues. |
| Trust gap | Free audit in cold email shows value before asking. Creates doubt in their current setup: "If he found this from outside, what else are we missing?" |
| Client concentration | Even losing a client is still massive improvement from current income. |
| Scaling ceiling | 300k solo is a good problem. Figure out hiring then. |

**The only real remaining gap is trust** - and that closes with results. First 2-3 clients are hardest, then referrals and proof points compound.

### How the Audit Closes the Trust Gap

The free audit does two things at once:

1. **Delivers value** - here's a problem you didn't know about
2. **Creates doubt** - if I missed this, what else am I missing?

The prospect's internal monologue: "Our IT guy/agency didn't catch this. This random person did. From outside. For free."

You're not asking them to trust you - you're showing them they can't fully trust what they have. "Imagine what he could do embedded in the company."

This is execution anxiety, not strategy flaw. The logic holds. Send the emails.

---

## Overthinking (Read When Doubting)

**"Am I over-engineering?"**
No. You're building an MSP. The complexity isn't in any one app - it's in orchestrating 10+ services, keeping them updated safely, reproducing environments per client. That complexity exists whether you manage it or not.

**"Can I really replace all these vendors?"**
You're not replacing AWS. You're replacing $50-500/month SaaS tools that are just wrappers around open source with margin and support tickets. The vendors you push out become hours you get back.

**"Too much time on tools?"**
The time on tools feels weird because it's not "client work." But it's buying you: root access to fix things yourself, no vendor ticket queues, no "that's not on our roadmap," actual authority to make things happen. Tool time now is the cost of not being a middleman later.

**"Bus factor?"**
Valid concern, have plans. But most companies don't audit their SaaS vendor's bus factor either.

**"Is this arbitrage?"**
No. You cost MORE than the tools. The value is: owner time saved, someone who can actually fix things, direct line instead of ticket queue. Business owner's time is worth more than $3.5k/month.

**"This is expensive!"**
Personal budget thinking. You're replacing: technical staff, multiple vendors, and a CTO who can drive RevOps. $3.5k/month is cheap for that.

**"This is too cheap!"**
Maybe. Low pricing signals low confidence and attracts clients who don't value the work. If you're replacing a CTO + IT staff + vendors, $3.5k might undersell it. Revisit pricing once you have proof points.

**Imposter syndrome**
The stack works. You built it. You're eating your own food. The doubts don't match the evidence.

**Why does making money feel scary?**
- *Identity mismatch* - Your self-concept is "person who makes 40k." Making 300k means becoming someone else. That's destabilizing even when it's good.
- *Unfamiliar problems* - You've never navigated 300k problems: taxes, what to do with money, lifestyle creep, people treating you differently. Unknown feels risky.
- *Fear of loss* - At 40k, not much to lose. At 300k, you have something to protect. Staying small feels safe.
- *Deserving* - The quiet question: "Am I the kind of person who makes this?"
- *Visibility* - Success is visible. People notice. Some celebrate, some resent. Staying small is staying invisible.

The fear is normal. It doesn't mean the plan is wrong - it means the plan is big enough to matter. The execution anxiety is just your nervous system catching up to what your brain already decided.
