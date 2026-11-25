<p align="center">
  <img src="assets/logo.svg" width="380" alt="Kilroy read the manual: a bald head in round glasses peeks over a thick open manual, long nose drooping over the pages">
</p>

<h1 align="center">By the book</h1>

<p align="center">
  <em>Kilroy was here. He read the manual. All of it.</em>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Claude%20Code-plugin-3d5a80?style=flat-square" alt="Claude Code plugin">
  <img src="https://img.shields.io/badge/skills-3-3d5a80?style=flat-square" alt="3 skills">
  <img src="https://img.shields.io/badge/hooks-4-3d5a80?style=flat-square" alt="4 hooks">
  <img src="https://img.shields.io/badge/license-MIT-3d5a80?style=flat-square" alt="MIT license">
</p>

---

Your agent knows a dozen ways to wait for the network. It picks the one that
fits in four lines: a loop that checks every second. The platform has a
callback for this, and the docs show it on the first page. Nobody opened the
docs.

This plugin gives your agent a colleague who did. Before the first line of
code he opens the platform's own documentation, finds what it recommends and
what bites people, and uses that. If the right way costs far more than the
shortcut, he stops and asks you, with both prices. He does not ship a shortcut
with a known limit and a note to fix it later. Later never comes.

He is not a gold-plater. He builds only what you asked for. The manual decides
how a thing works, not how much of it gets built.

## What he catches

| The agent writes | He opens | And writes instead |
|---|---|---|
| `while !online { sleep(1) }` | Apple's Network framework docs | `NWPathMonitor` with a `pathUpdateHandler`: the system calls you |
| `Thread.sleep(500)` in a test | the kotlinx-coroutines-test docs | `runTest { … advanceUntilIdle() }`: virtual time, nothing to wait for |
| `LocalDate.of(2025, 3, 1)` in a test | the `java.time.Clock` docs | `Clock.fixed(…)` handed to the code, every date counted from it |
| "Never sleep in tests" in `CLAUDE.md`, and nothing else | your gate | a lint rule, with one fixture that must fail and one that must pass |

## A test that passed for a year

```kotlin
// Before: green on every run. Then March 2025 came.
val due = LocalDate.of(2025, 3, 1)
assertFalse(invoice.isOverdue(due))   // the code compares with the real today

// After: the test owns "now".
val clock = Clock.fixed(Instant.parse("2025-01-01T00:00:00Z"), ZoneOffset.UTC)
val invoice = Invoice(clock)
assertFalse(invoice.isOverdue(LocalDate.now(clock).plusDays(3)))
```

Nobody touched the code. The calendar did. A test that reads the real clock,
the real network or the real disk fails one day for a reason that has nothing
to do with your change. He asks of every test: will it pass tomorrow?

## Skills

| Skill | When your agent picks it up | The question he asks |
|---|---|---|
| `by-the-book:how-should-it-work` | Before choosing an API, a pattern, a library, a config, the fix for a bug | What does the platform recommend here, and what bites people? |
| `by-the-book:is-it-by-the-book` | Reviewing a diff or auditing code, its own diff included | Would the docs recommend this? First: does this diff decide anything at all? |
| `by-the-book:will-it-pass-tomorrow` | Writing or fixing a test, a test that fails only sometimes | Does the test hold the clock, the network and the disk, or do they hold the test? |

Your agent does not have to remember them: the hooks below bring each one in
at its moment. You can also call a skill yourself:

```
/by-the-book:how-should-it-work how should the app wait for the network
```

The review skill does not burn your limit on a rename. It first asks whether
the diff decides how something works. A move, a rename or a docs change
decides nothing, and the review stops after one line.

## Hooks

Hooks nudge at the right moment and stay silent the rest of the time.

**The core.** A short version of the rules sits in every session and every
subagent, and comes back after each compaction.

**Before the first code change.** An agent about to change code for the
first time, without having loaded `how-should-it-work`, gets one line: if
this change decides how something works, load the skill first.

**Before it finishes.** An agent that changed code since the last practice
check is sent back once to run `is-it-by-the-book` on its diff. A diff that
decides nothing costs one line. A change a subagent left unchecked is
checked by the session before it ends.

**A rule comes with its check.** You write a rule into `CLAUDE.md`. Every
agent reads it. After the next big cleanup, three of them break it, because a
document holds nothing. A lint check in the gate holds. So after each
`git commit` your agent runs, the plugin looks at the files in that commit.
If the commit changed a rule file (`CLAUDE.md`, `AGENTS.md`,
`.claude/rules/`) and no gate file (lint config or lint code, a gate script,
git hooks, CI), the agent finds a sticky note on its desk:

> by-the-book: commit 2b66373 changes rule files (CLAUDE.md) but no gate file.
> If it adds or tightens a rule a machine can check, add that check to the
> gate in a follow-up commit, with one fixture that must fail and one that
> must pass.

## Install

One command:

```bash
claude plugin install by-the-book --marketplace alfabaykal/by-the-book
```

In a session: `/plugin install by-the-book --marketplace alfabaykal/by-the-book`.

The hooks need `git` and `jq` on `PATH`. macOS 15 and later ship `jq`.

## Update

The plugin carries no version number, so every commit here is a new version.
Claude Code does not auto-update third-party marketplaces by default. Turn it
on once in `/plugin` → Marketplaces → `by-the-book`, or update by hand:

```bash
claude plugin update by-the-book@by-the-book
```

## With auto-implement

[`auto-implement`](https://github.com/alfabaykal/skills) lets an agent run
mattpocock's `implement`. It calls all three skills by name:
`how-should-it-work` before code, `will-it-pass-tomorrow` for the tests,
`is-it-by-the-book` as a reviewer next to `/code-review`. Without this plugin
it stops and asks you to install it.

## FAQ

**Isn't reading the docs slow?**
Slower than what? The page takes five minutes. The `sleep(0.5)` that loses
a race on a loaded CI runner takes a week of "flaky, rerun it".

**What if the docs are wrong?**
Then the library's issue tracker says so. He reads that next. Memory comes
last, below a random blog post.

**Will it fill my context with rules?**
A little. The core is about 350 tokens, once per session start, compaction
and subagent. A skill's body loads only when the agent uses it. The other
hooks print nothing until their moment comes.

**Will it build me a framework?**
No. Before writing anything he asks: does this need to exist, is it already
in the codebase, does the standard library do it, does the platform do it.

**He sounds exhausting.**
He is. Your users never meet him, and they never find out what a sleep loop
does to a battery either.

## Develop

```bash
sh tests/core.test.sh
sh tests/practice.test.sh
sh tests/law-gate.test.sh
claude plugin validate .
claude --plugin-dir .
```

## Thanks

[Ponytail](https://github.com/DietrichGebert/ponytail) inspired this plugin.
Thank you for showing how good a set of agent skills can be, and how much
fun its README can have.

## License

MIT
