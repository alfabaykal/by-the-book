---
name: is-it-by-the-book
description: Use when reviewing a diff or auditing code, your own diff included, for whether each mechanism follows the platform's guidance (the Practice axis of a review). Test code is in scope. Starts by asking whether the diff decides how anything works, skips mechanical changes, and reports where the platform's advice differs from a project rule.
---

# Is it by the book

The Practice axis of a review. It fits any review, whoever runs it: a review
skill, a reviewer agent, or you checking your own diff before you report.

## 1. Does the diff decide how something works?

Answer this first, in the product or in a test. A rename, a move, a
mechanical replacement across files or a change to documents alone decides
nothing: skip the axis and say so in one line. When unsure, run it.

## 2. Check each mechanism

Reviewing a diff or auditing code, ask of each mechanism: would the
platform's documentation recommend this? Read the source the way
`by-the-book:how-should-it-work` ranks them, strongest first, and open the
page, not the search snippet. A claim whose source you did not open is
marked "unverified".

A finding names the place, what is there now, the recommended way with its
source, what the product's user notices, the size of the fix, and whether
the fix changes behavior or only form (a name, an import, the wording of a
comment). Rank findings by what the user notices.

## 3. The platform against the project's rules

Where the project's rules or ADRs require something the platform's
documentation advises against, the rule stands and the code is not a
finding. The difference still goes to the owner: list it in the report
under "Practice differs from a project rule", with the rule, what the
platform recommends instead, and the source. Whoever acts on this review
carries that section into their final report as written, and changes
nothing because of it.

## 4. Tests and rules

Test code is in scope: how a test waits and what it controls is a
mechanism. Judge it by `by-the-book:will-it-pass-tomorrow`. A test that
waits for a product timer on the real clock (a client timeout, a backoff, a
TTL, a scheduler) waits on time: that is a finding.

A rule added to the project's rule files with no check in its gate is a
finding.

## Report

One of three:

- "Practice: skipped, the diff decides nothing" and why, in one line.
- "Practice: clean", with each mechanism checked and its source.
- The findings, ranked, each marked "behavior" or "form".

Add "Practice differs from a project rule" whenever section 3 found
something, whichever of the three it is.
