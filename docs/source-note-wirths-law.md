# Source Note Template

**Essay:** 100 Records Shouldn't Be Hard

**Source title:** Wirth's law

**Author / org:** Wikipedia (summarizing Niklaus Wirth's 1995 article "A Plea for Lean Software")

**URL / citation:** https://en.wikipedia.org/wiki/Wirth%27s_law

**Date accessed:** 2026-09-16

**Source type:** encyclopedia / secondary source (references primary: Wirth, Niklaus. "A Plea for Lean Software." *Computer* 28, no. 2 (February 1995): 64–68.)

## Why I Am Reading This

Not to support my argument directly - just for context. The no-code/low-code pattern looks a lot like Wirth's Law in action. It's the same thing: requirements grow because hardware allows them to.

We don't just need "a workflow" anymore (the old problem). We need a system that laymen can use to *create* workflows - a much more complicated problem, only conceivable because hardware has improved so dramatically.

My main point: people outside tech are ignorant of how much hardware has improved. They think software *has* to be slow. They don't realize their laptop could do vastly more if the software wasn't spending resources on abstractions they may not need.

## What This Source Claims

- "Software is getting slower more rapidly than hardware is becoming faster" (the core law)
- Wirth attributed the observation to Martin Reiser (1991): "The hope is that the progress in hardware will cure all software ills. However, a critical observer may observe that software manages to outgrow hardware in size and sluggishness."
- The trend was "becoming obvious as early as 1987"
- Two contributing factors: "rapidly growing hardware performance" and "customers' ignorance of features that are essential versus nice-to-have"
- "People are increasingly misinterpreting complexity as sophistication"
- "These details are cute but not essential, and they have a hidden cost"
- Gates's Law variant: "The speed of software halves every 18 months" - negating Moore's Law
- Wirth built Oberon (1986-1989) to prove software CAN be lean without sacrificing functionality

## What It Supports

This provides context because:

- Names a pattern people outside tech don't know exists - "oh, this has a name, it's been happening for 30 years"
- Explains *why* it happens: requirements expand to fill available hardware
- "Customers' ignorance of features that are essential versus nice-to-have" - exactly my point about people not knowing what they actually need vs what's being sold to them
- The fact that Wirth built Oberon to prove lean software is *possible* parallels my point: the slowness isn't inevitable, it's a choice (or ignorance)

## What It Complicates

Nothing, really. Workflow builders are just one instance of the general pattern Wirth described. The law already covers this - I'm not stretching it.

Minor notes:
- Wikipedia is a secondary source - for academic rigor, I could cite Wirth's original 1995 paper
- But for a blog post, naming the pattern and linking to Wikipedia is fine

## Useful Quotes / Paraphrases

> "Software is getting slower more rapidly than hardware is becoming faster."

> "The hope is that the progress in hardware will cure all software ills. However, a critical observer may observe that software manages to outgrow hardware in size and sluggishness." — Martin Reiser, 1991

> "People are increasingly misinterpreting complexity as sophistication... these details are cute but not essential, and they have a hidden cost." — Niklaus Wirth, 1995

> "What Intel giveth, Microsoft taketh away" — common 1990s variant

> Gates's Law: "The speed of software halves every 18 months"

## Reliability / Limits

Why I trust or distrust this source:

- Wikipedia is well-sourced here - 11 references including the original IEEE paper
- The core claims are verifiable against Wirth's original 1995 article
- Multiple independent restatements (Page's Law, Gates's Law, Andy and Bill's Law) suggest broad recognition
- This is descriptive (observing a pattern), not prescriptive - doesn't tell me what to do about it

What this source does **not** prove:

- That workflow builders specifically suffer from this (my claim, my evidence)
- That the overhead is architecturally unavoidable (I argue it is for generalized workflows)
- That my specific experience with Twenty CRM is representative
- What the solution should be (Wirth built Oberon; I wrote code; different contexts)

## How I Might Use It

- [x] Background context — "This pattern has a name. It's been recognized since 1995."
- [ ] Direct citation — Maybe the Reiser quote if it fits naturally
- [ ] Counterargument
- [ ] Further reading only

**Usage:** A brief mention, not a deep dive. Something like: "This looks a lot like Wirth's Law - software expanding to consume hardware gains. The difference is that people outside tech don't realize how much room there actually is."

**Primary source to chase (later, if needed):** Wirth, Niklaus. "A Plea for Lean Software." *Computer* 28, no. 2 (February 1995): 64–68. doi:10.1109/2.348001
