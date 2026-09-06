---
name: kasane-review-pr
description: Review a KASANE Pull Request, branch diff, or uncommitted diff for concrete correctness bugs, regressions, data-integrity risks, security issues, and missing tests, then report evidence-based findings in Japanese. Use when asked to review, inspect, or audit changes made to the KASANE repository. Do not use to implement fixes, perform design or UX critique, conduct a broad audit unrelated to a specific change, or review work outside KASANE.
---

# KASANE Pull Request Review

Review a specific KASANE change without modifying the implementation.

Follow the applicable `AGENTS.md` instructions throughout the review.

## 1. Establish the review target

Identify:

- the base and head revisions;
- the Pull Request description;
- the linked Issue and acceptance criteria;
- the changed files;
- the commits or uncommitted changes included in the review.

Choose the comparison base for the review target:

- for uncommitted changes, compare the index and worktree with `HEAD`;
- for a single commit, compare the commit with its first parent;
- for a Pull Request or branch diff, use the specified base revision or the Pull Request base branch;
- use `main` for a Pull Request or branch diff only when no other base can be determined.

If the diff cannot be obtained, stop and request the Pull Request, branch, commit range, or diff. Do not review only from a summary or Pull Request description.

If the linked Issue or acceptance criteria cannot be obtained, continue reviewing concrete implementation risks when possible, but clearly state that compliance with the acceptance criteria could not be verified.

Do not use external web access to reconstruct missing requirements.

## 2. Read the applicable context

Before evaluating the diff:

- read the applicable `AGENTS.md`;
- read the complete diff;
- read the surrounding code needed to understand each changed execution path;
- read related Models, ViewModels, Services, Views, and tests;
- read architecture documentation only when it explains the current implementation;
- do not treat `docs/planning/` as confirmed requirements.

Trace behavior beyond the changed lines when necessary. Do not assume that a locally reasonable change is correct without checking its callers, state transitions, persistence behavior, and tests.

## 3. Review by priority

Prioritize concrete problems introduced or exposed by the change.

### Requirements and behavior

- Compare the implementation with each available acceptance criterion.
- Check normal, empty, error, cancellation, repeated-operation, and boundary paths when relevant.
- Check whether partial input or interrupted operations can leave inconsistent state.
- Check whether existing behavior changed unintentionally.
- Check whether the implementation silently broadens the Issue scope.

### Data integrity and SwiftData

When relevant, verify:

- `WorkoutSession`, `ExerciseEntry`, and `SetEntry` relationships;
- insertion, deletion, ordering, and inverse-relationship behavior;
- optionality and default values;
- duplicate or orphaned records;
- save, fetch, and delete failure handling;
- behavior after application restart or context recreation;
- migrations or compatibility risks caused by model changes.

Treat plausible data loss, corruption, or unrecoverable inconsistency as high priority.

### Architecture and Swift correctness

- Check that Views remain focused on presentation and user interaction.
- Check that business logic and persistence behavior remain testable.
- Check dependency direction and ownership of state.
- Check error propagation and avoid silent failure.
- Check unsafe force unwraps and forced error handling.
- Check Swift 6 concurrency, actor isolation, and shared mutable state when the change introduces concurrent behavior.
- Check lifecycle and cancellation behavior for asynchronous work.

### Tests and validation

- Check that changed business behavior has focused tests.
- Check that tests exercise failure and boundary paths where relevant.
- Check whether tests would fail if the reviewed defect were introduced.
- Check for assertions that only mirror implementation details.
- Check whether required validation was actually run.
- Do not treat an unexecuted build or test as successful.
- If Xcode is unavailable, record that macOS CI is still required.

### Project and security

- Confirm that `project.yml` remains the source of truth for project configuration.
- Flag committed generated `.xcodeproj` changes.
- Check for credentials, API keys, certificates, signing material, or sensitive data.
- Check workflow changes for excessive permissions or unintended secret exposure.
- Check privacy manifest and application metadata changes when relevant.

## 4. Validate every finding

Report a finding only when all of the following are true:

- it is caused or materially exposed by the reviewed change;
- it has a concrete effect on behavior, data, security, reliability, or test coverage;
- the affected execution path can be explained;
- the location can be identified precisely;
- the author can act on the finding.

Before reporting, verify the finding against the surrounding code and existing tests.

Do not report:

- formatting issues already enforced by tooling;
- personal style preferences;
- speculative concerns without a plausible trigger;
- unrelated pre-existing problems that the change does not worsen;
- broad architectural proposals that are unnecessary for the Issue;
- multiple comments for the same root cause.

Group findings that share one root cause.

## 5. Assign severity

Use only the following severity levels.

### P0 — Critical

Use when the change can cause widespread or unrecoverable data loss, a critical security incident, or a failure that requires work to stop immediately.

### P1 — Blocking

Use when the change causes a reproducible functional regression, crash, data corruption, security problem, or failure of a core acceptance criterion in a normal or likely path.

### P2 — Important

Use when the change causes an actionable defect in a limited or edge path, creates a meaningful reliability risk, or lacks a test necessary to protect changed behavior.

Do not create a finding for low-value suggestions that do not meet P0, P1, or P2.

## 6. Write findings in Japanese

Write the review result, GitHub review body, and inline review comments in Japanese, except for code, API names, file paths, and other identifiers.

For each finding, use this structure:

```markdown
[P1] 指摘内容を表す簡潔なタイトル

対象: `path/to/File.swift:行番号`

問題となる条件と、現在の実装で何が起きるかを説明する。
ユーザー、保存データ、既存機能、またはテストへ与える影響を示す。
可能な場合は、安全な修正方針を簡潔に示す。
```

Keep the referenced line range as small as possible. Use the changed line that best demonstrates the problem.

Do not write a long general explanation in an inline comment when a short, actionable explanation is sufficient.

## 7. Report the review result

Return the review in Japanese using the following structure.

### 指摘事項

List findings in severity order: P0, P1, then P2.

If no qualifying finding exists, write:

`重大な指摘はありません。`

### 確認範囲

Summarize:

- the base and head revisions;
- the files and execution paths reviewed;
- the acceptance criteria checked;
- relevant surrounding code and tests examined.

### 検証

List:

- commands and tests that were actually run;
- their results;
- checks that could not run and the reason.

### 残存リスク

Describe:

- behavior that could not be verified;
- unavailable Issue or acceptance criteria;
- environment limitations;
- areas that require macOS CI or manual confirmation.

Write `特になし` when no material residual risk is known.

## 8. Preserve review-only behavior

Do not edit source code, tests, documentation, configuration, or generated files while using this Skill.

Do not commit, push, approve, request changes, merge, post GitHub comments, or update the Issue unless the user explicitly requests that external action.

If the user asks to fix a finding, stop using this review-only workflow and use `kasane-implement-issue` for the agreed fix.
