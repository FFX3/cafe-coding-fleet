# Lead Generation & ICP

This is the RevOps work. What I'm doing for myself is the actual product.

---

## Two ICPs

### ICP 1: Outlier Retail Operators

**Example:** Les Glaceurs - $10M revenue selling cupcakes, 5 locations, ~50 employees but only 3-5 decision-makers.

**Characteristics:**
- Multi-location retail/food/service
- Unusually high revenue for their industry (outliers)
- Already investing in marketing (email campaigns, FB ads)
- Problem: IT/Marketing disconnect
- Low friction fix - just connect the dots
- Most employees are operational (cashiers, kitchen, retail floor)

**Why they're a fit:**
- Revenue-rich, time-poor
- Few decision-makers juggling operations AND marketing
- Can afford $3.5k/month easily (0.4% of revenue for Les Glaceurs)
- Already trying - just need help executing

### ICP 2: High-Value Product/Service Companies

**Characteristics:**
- Smaller headcount (<15), higher revenue per employee
- Complicated/unique product or service
- Would rather sell/build than manage IT
- B2B or specialized services

**Industries:**
- Consulting, agencies
- SaaS, software
- Professional services
- Specialized manufacturing
- Technical services

**Why they're a fit:**
- Their time is extremely valuable
- IT is a distraction from revenue-generating work
- Small team = no dedicated IT person
- Complex enough to need real help

---

## Finding ICP 1: Systematic Local Search

Can't filter by headcount (50 employees looks wrong, but only 5 are corporate).

**Sources - curated lists of successful local businesses:**
- Chamber of Commerce (Chambre de commerce in Quebec)
- Board of Trade
- "Best of [City]" awards
- Local business awards, industry galas
- Economic Development Corporation
- Small Business Week winners
- BDC (Business Development Bank) awards

Montreal specific:
- Chambre de commerce du Montréal métropolitain
- PME MTL
- Industry "Gala" awards

**The system:**
```
Chamber/award lists (curated successful businesses)
    ↓
Scrape periodically, build local database
    ↓
Cross-reference with Apollo/Clearbit for revenue
    ↓
Filter: $2M+ revenue
    ↓
Run audit (FB ads, no pixel, newsletter, landing pages)
    ↓
Cold email with findings
```

**Visible signals to check:**
| Signal | Tool |
|--------|------|
| Running FB ads | FB Ad Library (public) |
| No Meta pixel | BuiltWith, Wappalyzer, browser extension |
| Has newsletter | Check site for signup form |
| No landing pages | Just product pages, no funnels |
| Multi-location | Google Maps, website |

**Scoring:**
Running ads + no pixel + has newsletter + multi-location = hot lead

**Simple v1 (manual):**
1. FB Ad Library → Montreal → retail/food/service
2. Click through, check each site for pixel (browser extension)
3. If no pixel + has newsletter + running ads = add to list
4. 2-3 hours of manual work = solid prospect list

---

## Finding ICP 2: Apollo Play

Standard filters work here:
- Revenue: $1M+
- Headcount: <15
- Industry: consulting, agencies, SaaS, professional services
- Technologies: Shopify, HubSpot, Zapier (signals they're trying)
- Titles: Owner, Founder, CEO (single decision-maker)

Then run the same audit on their visible tech.

---

## The Audit (Cold Email Payload)

Already built - see Obsidian vault.

What to look for:
- FB ads running with no pixel (wasting ad spend)
- No landing pages (sending traffic to product pages)
- Newsletter exists but no lead magnets
- Multiple tools not integrated (Shopify + Mailchimp + random CRM)
- Visible security issues (exposed admin panels, outdated software)

The audit does two things:
1. **Delivers value** - here's a problem you didn't know about
2. **Creates doubt** - if I found this from outside, what else is broken inside?

---

## Revenue Context (ICP 1)

For outlier retail operators - where headcount is misleading because most employees are operational.

Personal baseline of 40k/year makes revenue feel abstract. Reference points:

| Revenue | What it means |
|---------|---------------|
| $1M | Small but real business, ~$80k profit if healthy |
| $2-5M | 10-30 employees, real operations, budget exists |
| $5-10M | Solid mid-market, can easily afford $3.5k/month |
| $10M+ | Your fee is a rounding error to them |

Les Glaceurs at $10M: $3.5k/month = 0.4% of revenue. Nothing.

A $2M company: $3.5k/month = 2% of revenue. Still reasonable for IT + CTO.

For ICP 2 (high-value product/service), revenue per employee is much higher. A 5-person consulting firm at $1M has completely different economics.

---

## Pricing Position

**Not cheap. Efficient.**

- More expensive than a typical MSP
- Part-time CTO rate (not cheap, just not full-time)
- Lots of services because automation (Nix) + competence, not low margin
- Premium pricing, efficient expert time

**The DIY distinction:**

| Bad DIY | Good DIY |
|---------|----------|
| Cheap, nickel-and-dimes | Wants ownership and control |
| Doesn't want to pay for anything | Willing to invest to get it |
| Rare at high revenue - hard to scale while being that cheap | Values their data, wants to own their stack |

**Good DIY clients should love this service because:**
- Giving them ownership (their accounts, their data, transferable)
- No vendor lock-in
- Building something they COULD run themselves eventually
- Aligned with their values, providing expertise they lack

**The actual ICP filter:**
- Values ownership (not cheapness)
- Has revenue (proved they're good at their thing)
- Doesn't have time to execute on the ownership themselves
- Wants control, needs competent help to achieve it

DIY-minded client who needs execution help - not someone who wants to outsource and forget. They care, they just can't do it all.

---

## This Is The Product

Figuring out lead gen for myself IS the RevOps work. If clients are on Twenty CRM, this is exactly what I'd do:
- Experiment with workflows
- Build systems to find and qualify leads
- Connect the tools
- Iterate until something works

Eating my own food. The process is the proof.
