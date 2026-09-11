# Funnel Builder Onboarding

Self-onboarding as first client. Build templates organically from real landing pages.

## Stack

| Layer | Tool | Status |
|-------|------|--------|
| Pages | Webstudio (self-hosted) | Running |
| Automation | Webstudio MCP | Working |
| Copy | Hermes + wiki | In progress |
| Design | Design tokens | Not started |

## Workflow

1. **Need a landing page** for something real
2. **Build it** in Webstudio (manually or with MCP assist)
3. **Extract reusable parts** as templates when patterns repeat
4. **Wire up copy generation** when the structure is stable

Templates emerge from real work, not upfront planning.

## Design Tokens (Do First)

Before building pages, set up basic tokens so everything stays consistent:

```
Colors:
- primary, primary-hover
- neutral-900, neutral-700, neutral-500, neutral-300, neutral-100
- background, surface
- error, success

Typography:
- heading-1, heading-2, heading-3
- body, body-small
- (pick 1-2 font families)

Spacing:
- xs: 8px, sm: 16px, md: 24px, lg: 32px, xl: 48px, 2xl: 64px
```

These can evolve but having something beats picking values ad-hoc.

## First Landing Page

Pick something real:
- [ ] What's the offer?
- [ ] Who's it for?
- [ ] What's the CTA?

Build it. See what sections you actually need.

## Template Extraction

When you build a second page and think "this is like that other one":

1. Identify the reusable structure
2. Save as page template in Webstudio
3. Note what varies (headlines, images, colors) vs what's fixed

## Copy Integration (Later)

Once page structures stabilize:

1. Document what copy each section needs
2. Set up Hermes prompts using frameworks (PAS, AIDA, etc.)
3. Test generating copy for existing pages
4. Refine prompts based on what needs editing

## Notes

_Add learnings as you go_

---

## Future: Hermes Landing Page Agent

**Goal**: Marketing team describes what they need, agent builds the page.

```
User: "I need a landing page for the new webinar on kubernetes security"

Agent:
1. Pulls context from wiki (product info, audience, brand voice)
2. Selects appropriate funnel template
3. Generates copy using frameworks (PAS, AIDA, etc.)
4. Scaffolds page via Webstudio MCP
5. Returns preview link for review
```

**Components**:
- Hermes with RAG over company wiki/knowledge base
- Webstudio MCP for page operations
- Library of proven section/funnel templates
- Design tokens enforcing brand constraints

**What the agent handles**:
- Copy generation from wiki context
- Template selection based on funnel type
- Section assembly and content placement
- First draft ready for human review

**What humans handle**:
- Final copy tweaks (tone, specifics)
- Image selection
- Approval and publish
- Edge cases / custom layouts

**Prerequisites** (build up through self-onboarding):
- [ ] Design tokens locked in
- [ ] 5-10 battle-tested section templates
- [ ] 2-3 funnel templates that actually convert
- [ ] Wiki with sufficient product/brand context
- [ ] Hermes prompts tuned for each section type
