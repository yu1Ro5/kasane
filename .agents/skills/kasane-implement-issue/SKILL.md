---
name: kasane-implement-issue
description: Implement a scoped KASANE Issue from acceptance criteria through repository changes, tests, validation, self-review, and a Japanese completion report. Use when asked to implement, fix, or complete a concrete KASANE Issue or an agreed task that requires repository changes. Do not use for review-only requests, design or UX exploration, requirement planning without implementation, or work outside the KASANE repository.
---

# KASANE Issue Implementation

Implement one agreed KASANE Issue as a focused, reviewable change.

Follow the applicable `AGENTS.md` instructions throughout the task.

## 1. Confirm the task

- Read the complete Issue body, acceptance criteria, comments containing decisions, and explicitly linked repository documents.
- If the Issue content is unavailable, request the Issue body or acceptance criteria instead of guessing.
- Treat the Issue acceptance criteria as the requirements for the current task.
- Treat the current code and tests as the source of truth for existing behavior.
- Do not treat `docs/planning/` as confirmed requirements.
- Identify any contradiction between the Issue, code, tests, and supporting documents.
- If a contradiction could change the implementation, stop and report:
  - the conflicting statements;
  - the affected behavior or files;
  - the decision required to continue.

## 2. Define the scope

Before editing, identify:

- the behavior that must change;
- the acceptance criteria that prove completion;
- the files and execution paths likely to be affected;
- the tests that need to be added or updated;
- the validation commands required by `AGENTS.md`.

Keep the change limited to one Issue.

Do not include:

- unrelated refactoring;
- speculative features;
- cleanup unrelated to the acceptance criteria;
- new dependencies or major architectural changes without explicit approval;
- edits to generated `.xcodeproj` files.

## 3. Implement the smallest complete change

- Follow the existing architecture, naming conventions, and dependency direction.
- Keep SwiftUI Views focused on presentation and user interaction.
- Place business logic and persistence behavior in testable Models, ViewModels, or Services.
- Handle errors explicitly.
- Preserve data relationships, ordering, and deletion behavior.
- Add or update focused tests for changed business behavior.
- Avoid tests that only reproduce implementation details without verifying behavior.
- Update architecture documentation only when the implemented architecture has actually changed.
- Do not copy temporary Issue requirements into `AGENTS.md`.

## 4. Validate the change

Inspect the final diff and run the checks required for the changed files.

### When Swift code changed

- Run the repository’s `swift-format` command.
- Run `xcodegen generate`.
- Run the Debug build.
- Run the unit tests.

### When `project.yml` changed

- Run `xcodegen generate`.
- Run the Debug build.
- Run the unit tests.

### When only Markdown, `AGENTS.md`, or Skills changed

- Check Markdown structure, links, duplication, and contradictions.
- For Skills, check the frontmatter, name, directory, trigger conditions, and exclusions.
- Run `git diff --check`.

### When a required check cannot run

- Record the exact command that was not run.
- State why the environment cannot run it.
- Do not describe an unexecuted check as passed or verified.
- If Xcode is unavailable, state that the macOS CI result remains required before merge.
- Do not use external network access as a substitute for unavailable local tools.

## 5. Self-review the diff

Before finishing:

- Compare the result with every acceptance criterion.
- Confirm that no unrelated file or behavior changed.
- Check for crashes, silent failures, data loss, and inconsistent state transitions.
- Check SwiftData save, fetch, relationship, ordering, and deletion behavior when relevant.
- Confirm that changed business behavior has appropriate tests.
- Confirm that generated project files, credentials, signing material, and secrets were not added.
- Review the full diff rather than only the files intentionally edited.

Fix issues found during self-review when they are within the agreed scope. Report out-of-scope findings without implementing them.

## 6. Report the result

Report the outcome in Japanese using the following structure:

### 実施内容

- Summarize the behavior and files changed.

### 受け入れ条件

- List each acceptance criterion and whether it was satisfied.

### 検証

- List every command that ran and its result.
- Separately list commands that could not run and the reason.

### 残課題

- List remaining risks or follow-up work.
- Write `なし` when there are no known remaining items.

Do not claim completion when a blocking acceptance criterion is unsatisfied.

Do not commit, push, merge, create a Pull Request, or update the Issue unless explicitly requested.
