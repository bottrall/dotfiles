---
name: grilling
description: Grill the user relentlessly about a plan, decision, or idea. Use when the user wants to stress-test their thinking, or uses any 'grill' trigger phrases.
---

Interview me relentlessly about every aspect of this until we reach a shared understanding. Walk down each branch of the decision tree, resolving dependencies between decisions one-by-one.

**Every interview question is asked in plain prose, one at a time, and then you stop and wait for my answer.** riffer-rig has no question tool, so the reply *is* the question. Never open with a prose fact-map or summary and wait for a reply — if you have context to share, fold it into the question's framing or the option descriptions.

For each question:

- Ask **one question per reply**. Asking multiple at once is bewildering. End the reply after the question; do not continue working until I answer.
- Give concrete, mutually exclusive options as a numbered list — the actual choices, not "yes / no / other". I can always answer with something not on the list.
- Put your recommended answer **first**, labelled `(Recommended)`, with the reason in its description.
- Say explicitly that more than one option may be chosen only when the choices genuinely aren't exclusive.

If a _fact_ can be found by exploring the environment (filesystem, tools, etc.), look it up rather than asking me. The _decisions_, though, are mine — put each one to me and wait for my answer.
Never ask how the resulting work should be completed. I will give the appropirate direction once the shared understanding has been reached.

Do not act on it until I confirm we have reached a shared understanding. Provide the shared understanding as a html plan outlining what will be done and open the document in the browser (write the file with the write tool, then open it with `xdg-open <file>` on Linux or `open <file>` on macOS via the bash tool). Include visuals when appropriate and use simple language.
