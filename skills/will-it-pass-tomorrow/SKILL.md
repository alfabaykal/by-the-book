---
name: will-it-pass-tomorrow
description: Use before writing or fixing a test, when a test fails only sometimes, only under load or takes seconds, and when reviewing test code. The test controls the clock, network, disk, timers and system components its code depends on, and waits for a state, never for time.
---

# Will it pass tomorrow

A test is a mechanism too, and the platform's guidance holds for it the same
way. Ask of each test: will it pass tomorrow, next year, on a loaded
machine, with the network down? If the answer depends on something the test
does not hold, the test fails one day with no change to the code.

## 1. Test what the source warns about

Each failure the platform's documentation warns about for the mechanism gets
a test: cancellation, interruption, a dependency that fails, load.

## 2. The test holds what its code depends on

A unit test controls what its code depends on: the clock, the network, the
disk, another service, a system component (a codec, the camera, the
keychain), randomness. Give the code a seam for that dependency and let the
test hold and release it. Look up how in the docs of the platform and of the
test framework: many ship a clock the test can drive.

Dates count. A test that writes `2025-03-01` compares it with the real today
and breaks the day that date passes. Set "now" in the test and derive every
date from it: now plus three days.

## 3. Wait for a state, never for time

No sleep, no "wait two seconds, then check". A test that needs a real
dependency on purpose (an integration test) waits for its state: the server
answered, the file appeared. A timeout stops a hung test. It is not a way to
wait for the result.

A timer inside the product is time too. A client timeout, a retry backoff, a
TTL, a scheduler, a deadline: when the test waits for one of them to fire on
the real clock, the test waits on time, even though it waits "for an event".
Hand that component a clock or a scheduler the test drives, and advance it.
Most clients take one: look for the executor, scheduler or clock option in
the client's configuration and its source. If the component has no seam for
it, stop and ask whoever gave you the task. Do not ship the real wait.

For example, a test of an API call timeout with a slow fake server. Wrong:
the fake sleeps, the client's real 15-second timer fires, the test takes 15
seconds and passes. Right: the client gets a scheduler the test holds, the
test advances it past the timeout, and the test takes milliseconds.

## 4. A rule about tests comes with its check

When the work produces a rule for tests ("no sleep in tests"), the same
change adds a check that fails the gate: a lint rule or a script, with one
fixture that must fail and one that must pass. A rule that only a document
holds comes back after the next cleanup.

## Signs the test will not pass tomorrow

| Thought | What it means |
|---|---|
| "`sleep(0.1)` is enough here" | Not on a loaded machine. Wait for the event. |
| "The network is local, it is fast" | Under load it is not. Let the test hold the network. |
| "A longer timeout and it passes" | The timeout hides a wait on time. Wait for the state. |
| "The product's own timer is the clock" | That timer runs on real time. Give the test its scheduler and advance it. |
| "I'll use the date 2025-03-01" | It fails once that day passes. Set "now" in the test and count from it. |
| "The rule is in `CLAUDE.md`" | Without a check in the gate it will not hold. |
