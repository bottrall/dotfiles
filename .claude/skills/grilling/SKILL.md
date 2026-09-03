---
name: grilling
description: Grill the user relentlessly about a plan, decision, or idea. Use when the user wants to stress-test their thinking, or uses any 'grill' trigger phrases.
---

Interview me relentlessly about every aspect of this until we reach a shared understanding. Walk down each branch of the decision tree, resolving dependencies between decisions one-by-one.

**Every question goes through the AskUserQuestion tool.** Never ask in prose, and never open with a prose fact-map or summary and wait for a reply — if you have context to share, fold it into the question's description or the option descriptions.

For each question:

- Ask **one question per call**. Asking multiple at once is bewildering.
- Give concrete, mutually exclusive options — the actual choices, not "yes / no / other".
- Put your recommended answer **first**, labelled `(Recommended)`, with the reason in its description.
- Use `multiSelect` only when the choices genuinely aren't exclusive.

If a _fact_ can be found by exploring the environment (filesystem, tools, etc.), look it up rather than asking me. The _decisions_, though, are mine — put each one to me and wait for my answer.

Do not act on it until I confirm we have reached a shared understanding.
