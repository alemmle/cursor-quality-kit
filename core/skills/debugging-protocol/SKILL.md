---
name: debugging-protocol
description: Systematic debugging - reproduce, isolate, form one hypothesis at a time, prove the root cause, then fix with a regression test. Use when something fails and the cause is not obvious, before changing code to "try things".
---

# Debugging protocol

Do not change production code until step 4. Random edits are the main source of AI-introduced regressions.

## 1. Reproduce

- Write the exact steps, inputs, environment (simulator/device, OS, SDK version, branch), expected and actual result.
- Get the real error: full stack trace, failing test output, Metro/Xcode/`flutter run` logs, server logs. Read the whole trace, not the first line.
- If you cannot reproduce it, stop and say what you tried and what information is missing.

## 2. Isolate

- Find the smallest scope that still fails: one test, one screen, one request.
- If it worked before, find when it broke: `git log -p -- <file>` or `git bisect start; git bisect bad; git bisect good <ref>` with the failing test as the check.
- Check recent changes to dependencies (`git diff <good> -- package.json package-lock.json pubspec.lock`).

## 3. Hypothesize and prove, one at a time

For each hypothesis write: "I think X happens because Y. If true, Z will show it." Then gather evidence (a log line, a debugger value, a focused test) without changing behavior. Keep a short list:

```text
H1: token refresh races with the cart request -> evidence: log order shows request before refresh -> CONFIRMED
H2: ... -> REJECTED because ...
```

Temporary logging is fine; remove it before finishing.

## 4. Fix the root cause

Continue with the `fix-bug-with-regression-test` skill: failing test that encodes the confirmed cause, smallest fix, full gate.

## Stop conditions

- Three hypotheses rejected, or the gate fails twice for the same reason: stop and report the evidence collected so far. Ask a human or hand over to a stronger model.
- The fix needs changes outside the declared scope, to native config, auth, payments, or data: stop and ask.

## Never

- Wrap the failure in try/catch, add retries, add `?.`/`!` everywhere, or increase timeouts to make the symptom disappear.
- Change a test's expectation to match the buggy behavior.
