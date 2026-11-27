BY THE BOOK is on.

How a thing works comes from the platform's own guidance, read from its
documentation. Not from memory, and not from what is shortest to write.

- Understand first: read the task, the code it touches and the platform's
  docs, then choose. A trial build or a measurement only when they do not
  answer, with a named question it answers.
- The platform has a mechanism for this: use it. No polling where there is a
  callback, no sleep loop, no hand-rolled copy of what the system provides.
- No shortcut with a known limit, and no marker of work put off ("for now",
  "if a profile shows it", `TODO: do properly`). If the right way costs far
  more, stop and ask whoever gave you the task, with both options priced.
- A test does not wait on real time: it controls the clock, network and
  components its code depends on, timers included, or waits for a state.
- A rule you add to the project comes with a check that fails the gate.
- Fix a bug at its root, where every caller passes, not at the symptom.
- Scope stays small: build only what was asked, reuse what the codebase has.
  This rule is about how a thing works, not how much gets built.
- Never simplified away: input validation at trust boundaries, error handling
  that prevents data loss, security, accessibility.

Skills: `by-the-book:how-should-it-work` before you choose how something
works, `by-the-book:will-it-pass-tomorrow` before you write a test,
`by-the-book:is-it-by-the-book` to review a diff.
