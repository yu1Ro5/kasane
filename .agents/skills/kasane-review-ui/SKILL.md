---
name: kasane-review-ui
description: Review KASANE SwiftUI changes, screens, screenshots, or Pull Requests for Apple Human Interface Guidelines, Apple platform conventions, accessibility, visual hierarchy, interaction quality, and KASANE Design Principles, then report evidence-based findings in Japanese. Use when asked to review, inspect, audit, or evaluate KASANE UI/UX, SwiftUI presentation, navigation, accessibility, or screenshots. Do not use to implement fixes, redesign screens, review only business logic or data integrity, conduct generic visual preference critique, or review work outside KASANE.
---

# KASANE UI Review

Review KASANE UI and UX using evidence from:

- the latest Apple Human Interface Guidelines and Apple Developer Documentation;
- SwiftUI implementation;
- available Simulator or device screenshots;
- runtime behavior when available;
- the target Issue and its acceptance criteria;
- `KASANE_DESIGN_PRINCIPLES.md`.

The purpose of this Skill is not to judge whether a screen merely “looks like Apple.”

The purpose is to determine whether the UI:

- behaves naturally on Apple platforms;
- follows applicable Apple guidance;
- remains accessible;
- has a clear information and action hierarchy;
- preserves the user’s current context;
- supports fast Workout recording;
- follows KASANE’s product-specific design principles.

Follow all applicable `AGENTS.md` instructions throughout the review.

This is a review-only Skill.

Do not modify implementation files while using it.

---

# 1. Read the review references

Before reviewing UI, read:

1. the applicable `AGENTS.md`;
2. this `SKILL.md`;
3. `references/KASANE_DESIGN_PRINCIPLES.md`;
4. `references/APPLE_PLATFORM_REVIEW_GUIDE.md`.

If either reference file is unavailable, continue only for review areas that can still be supported by reliable evidence and clearly report the limitation.

Do not recreate missing design rules from memory.

Do not treat `docs/planning/` as confirmed product requirements.

---

# 2. Establish the review target

Determine what is actually being reviewed.

Possible targets include:

- a Pull Request;
- a branch diff;
- an individual SwiftUI screen;
- a group of related Views;
- an Issue implementation;
- one or more screenshots;
- a runtime interaction;
- uncommitted UI changes.

Identify, when available:

- the target Issue and acceptance criteria;
- the base and head revisions;
- changed files;
- affected screens;
- affected navigation or presentation paths;
- screenshots associated with the change;
- UI Test / Screenshot scenarios associated with the change.

Do not assume a Pull Request is the target unless one was provided or can be unambiguously determined.

---

# 3. Determine available evidence

Before writing findings, classify the evidence available for this review.

Use these evidence types:

- `Apple`
- `Code`
- `Screenshot`
- `Runtime`
- `Issue`
- `KASANE Design`

Record which types are available.

## Code only

When only source code is available:

You may review:

- SwiftUI architecture;
- Navigation structure;
- Presentation APIs;
- system vs custom components;
- accessibility modifiers;
- text styles;
- semantic colors;
- fixed sizing risks;
- focus handling;
- state ownership;
- interaction implementation.

Do not claim visual defects that require rendering confirmation.

For example, do not claim that text is visibly clipped without visual evidence.

Instead report a concrete risk when the code supports it.

Example:

```text
固定heightによりDynamic Type拡大時にcontentを収容できない可能性があります。
実表示の確認が必要です。
```

## Screenshot only

When only screenshots are available:

You may review observable facts such as:

- clipping;
- visual hierarchy;
- information density;
- alignment;
- spacing;
- control prominence;
- whether a Tab bar is visible;
- whether a modal covers the intended area;
- obvious contrast problems;
- excessive repeated card containers;
- visual competition between primary and secondary information.

Do not infer SwiftUI implementation details.

Do not claim that a specific API or modifier caused a visual problem unless code evidence is also available.

## Code and Screenshot

When both are available:

Use both.

Prefer confirming important visual findings against the implementation instead of guessing their cause.

## Runtime evidence

When Simulator, UI Test, device behavior, or reliable execution results are available, use them for interaction findings such as:

- focus movement;
- dismissal behavior;
- state preservation;
- keyboard behavior;
- repeated presentation;
- navigation behavior;
- animation behavior;
- accessibility interaction.

Do not claim runtime verification when the current environment cannot perform it.

---

# 4. Read the affected implementation path

For implementation-based reviews, do not inspect only the changed lines.

Read enough surrounding code to understand the real interaction.

When relevant, inspect:

- parent View;
- child components;
- `TabView`;
- `NavigationStack`;
- `NavigationLink`;
- `sheet`;
- `fullScreenCover`;
- `alert`;
- `confirmationDialog`;
- `searchable`;
- toolbar configuration;
- focus state;
- ViewModel state;
- state bindings;
- accessibility configuration;
- reusable UI components;
- relevant UI tests and screenshot fixtures.

Trace the actual route users follow through the changed UI.

For example:

```text
AppRootTabView
→ WorkoutRootView
→ WorkoutSessionView
→ ExercisePickerView
→ WorkoutSessionView
```

A View that appears correct in isolation may still create a poor experience because of its surrounding navigation or state transitions.

---

# 5. Read the Issue requirements

When the review is associated with an Issue:

- read the complete Issue;
- read its acceptance criteria;
- identify explicit UI decisions;
- identify behavior that must remain unchanged;
- identify explicitly out-of-scope functionality.

Treat the Issue acceptance criteria as requirements for that change.

Do not report a design preference that contradicts an explicitly agreed Issue decision unless:

- it violates a higher-priority platform or accessibility requirement; or
- it creates a concrete major usability problem.

In that case, report the conflict explicitly instead of silently overriding the Issue.

---

# 6. Consult current Apple guidance

When Apple official documentation is accessible, verify current guidance before making an important Apple-specific claim.

Follow `references/APPLE_PLATFORM_REVIEW_GUIDE.md`.

Search only the Apple guidance areas relevant to the changed UI.

Common review areas include:

- Design principles;
- Accessibility;
- Inclusion;
- Navigation and search;
- Layout and organization;
- Typography;
- Color;
- Materials;
- Buttons;
- Menus;
- Labels;
- Lists and tables;
- Tab bars / Tab views;
- Search fields;
- Alerts;
- presentation patterns;
- SF Symbols.

Do not read every HIG section for every review.

Use targeted research based on the affected interface.

---

# 7. Apple evidence rules

Do not use “Apple-like” as evidence.

Do not state that something violates Apple HIG unless relevant Apple guidance was actually confirmed.

Use the following distinction.

## HIG

Use `HIG` only when current Apple Human Interface Guidelines directly support the concern.

## Accessibility

Use `Accessibility` when the issue concerns accessibility behavior or guidance, including:

- Dynamic Type;
- VoiceOver;
- accessible labels and values;
- readable content;
- control sizing;
- spacing;
- contrast;
- Dark Mode where relevant;
- Reduce Motion where relevant;
- color-independent communication.

## Platform Convention

Use `Platform Convention` when:

- standard SwiftUI or iOS interaction provides an established behavior;
- the implementation unnecessarily reimplements a standard pattern;
- the behavior differs from normal system component behavior;

but there is no sufficiently direct HIG statement to justify labeling it `HIG`.

## KASANE Design

Use `KASANE Design` when the concern derives from `KASANE_DESIGN_PRINCIPLES.md`.

Do not imply Apple requires the KASANE-specific decision.

## Suggestion

Use `Suggestion` for a non-required improvement.

Suggestions are not blocking findings.

---

# 8. Review the Apple design principles where useful

Do not mechanically score every screen against every Apple Design Principle.

Use relevant principles when evaluating ambiguous design decisions.

Current principles may include:

- Purpose;
- Agency;
- Responsibility;
- Familiarity;
- Flexibility;
- Simplicity;
- Craft;
- Delight.

Verify the latest Apple guidance when relying on these principles.

Examples:

## Purpose

Is the primary purpose of the screen clear?

## Agency

Can the user understand state, choose actions, cancel, and recover from mistakes?

## Familiarity

Does the UI unnecessarily replace a familiar platform interaction?

## Flexibility

Does it adapt to Dynamic Type and different accessibility or content conditions?

## Simplicity

Does the screen contain information that does not help its current purpose?

## Craft

Are details such as spacing, labels, alignment, and transitions internally consistent?

Use these principles to support reasoning, not as automatic defect generators.

---

# 9. Review against KASANE Design Principles

Use `references/KASANE_DESIGN_PRINCIPLES.md`.

Pay particular attention to the following principles.

## Reflect and Act

Determine whether the screen is primarily for:

- reflecting on previous training; or
- acting during the current Workout.

Check whether information from the opposite mode unnecessarily competes with the screen’s primary purpose.

## Recording First

For Workout-related UI, evaluate:

- number of taps;
- input speed;
- focus behavior;
- reachability of frequent actions;
- repeated unnecessary actions;
- ability to use the interface one-handed;
- whether analysis or decoration takes space away from recording.

## Quiet Intelligence

For recommendations, previous records, trends, or stats:

- do not let advisory information dominate current recording;
- avoid unnecessary coaching;
- avoid suggestions when evidence is insufficient;
- preserve user choice.

## Native Before Custom

Check whether custom UI replaces standard SwiftUI behavior without clear user benefit.

Do not automatically flag every custom component.

## Hierarchy Before Decoration

Check whether:

- typography;
- spacing;
- grouping;
- alignment;
- standard containers

already communicate hierarchy before cards, backgrounds, materials, borders, shadows, or gradients are added.

Repeated use of cards is not automatically a defect.

Report it only when it weakens information hierarchy or materially increases visual complexity.

## Preserve Context

Check whether navigation or presentation can:

- reset Workout state;
- lose user input;
- regenerate drafts;
- interrupt an active task;
- return the user to an unexpected state.

## Accessible by Default

Accessibility is part of normal UI quality, not a separate optional review.

## Progressive Disclosure

Check whether secondary information is shown only when appropriate and does not compete with the primary task.

---

# 10. Review navigation and presentation

Review relevant use of:

- `TabView`;
- `NavigationStack`;
- `NavigationLink`;
- `sheet`;
- `fullScreenCover`;
- toolbar;
- alerts;
- confirmation dialogs;
- search presentation.

Check:

- whether top-level destinations are stable;
- whether navigation hierarchy matches information hierarchy;
- whether the user understands how to return;
- whether dismissal is available when needed;
- whether modal presentation matches the task;
- whether repeated modal layers create unnecessary complexity;
- whether state is preserved across navigation;
- whether tabs remain visible or hidden according to the intended interaction.

Do not prefer `sheet` or `fullScreenCover` solely because one appears more Apple-like.

Evaluate the task and current context.

---

# 11. Review information hierarchy

Review:

- primary screen purpose;
- title hierarchy;
- section hierarchy;
- primary information;
- secondary information;
- metadata;
- primary action;
- secondary actions;
- destructive actions.

Ask:

- What should the user notice first?
- What should the user do next?
- Is secondary information visually stronger than the main task?
- Are too many elements presented with equal emphasis?
- Are containers used where hierarchy alone would be sufficient?

Do not report minor spacing taste differences as findings.

---

# 12. Review native components

Look for opportunities where standard components provide the required behavior.

Examples include:

- `List`;
- `Section`;
- `Form`;
- `Button`;
- `Menu`;
- `Picker`;
- `.searchable`;
- `ContentUnavailableView`;
- `alert`;
- `confirmationDialog`;
- SF Symbols;
- semantic colors.

Do not require standard components when custom behavior has clear functional value.

When reporting unnecessary custom UI, explain the user impact.

Bad:

```text
独自コンポーネントなのでAppleらしくありません。
```

Better:

```text
[P2 / Platform Convention]

この独自Controlは標準Buttonが提供するpressed stateとVoiceOver上のbutton traitを再実装しておらず、
操作状態が分かりにくくなっています。
```

---

# 13. Review typography and Dynamic Type

Inspect relevant use of:

- system Text Styles;
- fixed font sizes;
- font weights;
- fixed frames;
- truncation;
- `lineLimit`;
- `minimumScaleFactor`;
- layout assumptions;
- numeric alignment where relevant.

Prefer system Text Styles when they satisfy the design.

Do not flag fixed font size or custom typography merely because it exists.

Report only concrete usability or accessibility effects.

When visual evidence is unavailable, distinguish confirmed defects from implementation risks.

---

# 14. Review color, materials, and appearance

Inspect:

- semantic colors;
- custom colors;
- tint usage;
- Light Mode;
- Dark Mode;
- Increased Contrast where relevant;
- state communicated through color;
- Material;
- Liquid Glass or similar system visual effects.

Do not require every color to be a system color.

Check whether custom colors preserve meaning and readability across appearance settings.

Do not recommend adding glass, materials, gradients, cards, or shadows simply to make the app look more Apple-like.

Decoration must have a purpose.

---

# 15. Review accessibility

Accessibility findings are first-class review findings.

Review relevant code and screenshots for:

- Dynamic Type;
- VoiceOver labels;
- VoiceOver values;
- accessibility traits;
- icon-only controls;
- meaningful reading order;
- control size;
- spacing;
- contrast;
- color-independent state communication;
- truncation;
- content scaling;
- Reduce Motion when animation is material to the feature.

When a precise Apple numeric threshold is important, verify the current official guidance before citing the value.

Do not rely on remembered values when Apple documentation is accessible.

---

# 16. Review Workout interaction quality

KASANE is used while exercising.

For active Workout screens, explicitly review:

- one-handed use;
- tap count;
- visibility of the current exercise;
- weight/reps entry speed;
- keyboard behavior;
- focus movement;
- adding a set;
- adding an exercise;
- finishing a Workout;
- canceling a Workout;
- returning from a picker;
- accidental data loss risk;
- whether secondary information competes with current input.

Treat unnecessary repeated actions as meaningful UX problems when they materially slow common recording behavior.

Do not invent optimization work outside the target Issue.

---

# 17. Screenshot review procedure

When screenshots are available:

1. identify the exact scenario;
2. identify device and appearance when known;
3. identify relevant state:
   - normal;
   - empty;
   - loading;
   - input;
   - keyboard;
   - error;
   - Dynamic Type;
   - Dark Mode;
4. inspect the screenshot without assuming code behavior;
5. compare it with the corresponding implementation when available;
6. record only observable visual evidence.

Check for:

- clipped text;
- overlapping content;
- poor hierarchy;
- overly dense content;
- inconsistent action prominence;
- unnecessary repeated containers;
- visually hidden primary action;
- obvious alignment problems;
- unwanted Tab bar visibility;
- presentation not covering the intended context;
- empty/error states that are difficult to understand.

Do not perform pixel-perfect comparison against Apple Health or Apple Fitness.

Apple apps are references for interaction thinking, not golden screenshots.

---

# 18. Review screenshot availability honestly

If a UI change should be visually reviewed but no relevant screenshot exists, record this as residual risk.

Do not automatically create a finding solely because a screenshot is missing unless:

- the Issue or repository rules explicitly require a screenshot scenario; or
- the changed behavior cannot reasonably be reviewed without one.

When the screenshot infrastructure exists, check whether an existing scenario already covers the changed UI before suggesting a new one.

Avoid unnecessary screenshot catalog growth.

---

# 19. Validate every finding

Before reporting a finding, verify all of the following.

The issue must:

- have a concrete user impact;
- be supported by available evidence;
- be attributable to the reviewed change or reviewed UI;
- have an identifiable location or screen;
- be actionable.

Do not report:

- personal aesthetic preferences;
- formatting issues handled by tooling;
- speculative rendering defects without evidence;
- unrelated pre-existing UI issues unless the change materially worsens them;
- generic redesign ideas;
- “Apple would probably do this” reasoning;
- duplicate findings with the same root cause.

Group findings that share the same root cause.

---

# 20. Severity

Use the following severity levels for actionable findings.

## P0 — Critical

Use rarely.

Examples:

- a UI change can cause widespread irreversible user data loss;
- a severe accessibility or interaction defect makes a critical function effectively unusable for a broad affected group;
- a security or privacy issue is exposed through the UI.

Most UI findings are not P0.

## P1 — Blocking

Use when the change causes a major failure in a normal or likely user path.

Examples:

- the primary Workout action cannot be completed;
- navigation traps the user;
- a major control is unreachable;
- Workout input is lost during a normal flow;
- a critical accessibility issue prevents the primary task;
- a core Issue acceptance criterion is visibly violated.

## P2 — Important

Use when there is a concrete but more limited usability, accessibility, hierarchy, or platform-convention defect.

Examples:

- Dynamic Type fails at larger sizes;
- secondary information materially obscures the recording workflow;
- an icon-only action lacks necessary accessibility identification;
- a custom interaction removes expected system behavior;
- information hierarchy makes a normal action unnecessarily difficult to find.

## Suggestion

Suggestions do not receive P0/P1/P2 severity.

They are optional improvements.

Do not use severity for purely subjective visual polish.

---

# 21. Finding categories

Each actionable UI finding must use one primary category.

Allowed categories:

- `HIG`
- `Accessibility`
- `Platform Convention`
- `KASANE Design`

Optional improvements use:

- `Suggestion`

Do not create a `Visual observation` category.

Visual observation is evidence, not the reason the behavior is incorrect.

---

# 22. Finding format

Write each actionable finding in Japanese.

Use this structure:

```markdown
[P2 / Accessibility] Dynamic Typeで主要操作が利用しづらくなる

対象: `Sources/Views/ExampleView.swift:42`

条件:
Accessibility Extra Extra Extra Largeなど、大きなDynamic Typeで表示した場合。

問題:
固定された高さに対してボタンラベルの拡大余地がなく、主要操作が切れたり圧縮されたりする可能性があります。

影響:
Workout中に主要操作を判別・実行しづらくなります。

Evidence:
- Code: `.frame(height: 44)` が設定されている
- Screenshot: 未確認
- Apple: Human Interface Guidelines — Accessibility

修正方針:
固定heightを前提にせず、Dynamic Typeでcontentが拡張できるlayoutにすることを検討してください。
```

Keep findings concise.

Do not add every possible field when it does not add value.

---

# 23. Apple references in findings

When Apple guidance materially supports a finding, identify the Apple source.

Example:

```text
Apple reference:
Human Interface Guidelines — Accessibility
```

or:

```text
Apple reference:
Human Interface Guidelines — Navigation and search
```

If a specific section is relevant, include it.

Do not paste long excerpts from Apple documentation.

Paraphrase the relevant guidance.

Do not fabricate URLs, page titles, or quotations.

---

# 24. Suggestion format

Suggestions should be clearly separated from defects.

Example:

```markdown
[Suggestion] 補助情報の強調を一段下げる

現在の表示でも操作不能ではありませんが、
前回記録をsecondary text styleにすると今回入力との階層がより明確になる可能性があります。
```

Do not let a large suggestion list overwhelm actual findings.

If there are many low-value suggestions, report only the most useful ones.

---

# 25. Interaction with kasane-review-pr

`kasane-review-ui` and `kasane-review-pr` have different primary responsibilities.

## kasane-review-pr

Primary focus:

- correctness;
- regression;
- SwiftData;
- persistence;
- architecture;
- security;
- business logic;
- tests.

## kasane-review-ui

Primary focus:

- HIG;
- Apple platform conventions;
- accessibility;
- navigation UX;
- visual hierarchy;
- screenshot evidence;
- Workout interaction quality;
- KASANE Design Principles.

When one root cause affects both areas, do not generate duplicate comments merely because both Skills could report it.

Prefer the category that describes the most important user impact.

Example:

If returning from a full-screen picker deletes an unsaved Workout draft, this is primarily a correctness/data-state issue and should be treated with the seriousness appropriate to that behavior, not reduced to a visual navigation observation.

---

# 26. Do not redesign during review

This Skill is review-only.

Do not:

- edit Swift files;
- edit tests;
- edit screenshots;
- edit documentation;
- change project configuration;
- create new design components;
- rewrite the screen;
- implement the suggested fix.

You may provide a concise safe fix direction for a finding.

Do not provide a full replacement implementation unless explicitly requested after the review.

If asked to fix findings, stop this review-only workflow and use the implementation workflow for the agreed changes.

---

# 27. Do not perform speculative redesign

Do not broaden a UI review into:

- complete information architecture redesign;
- new feature ideation;
- new Stats;
- new Replay functionality;
- new Workout recommendation logic;
- new Routine functionality;
- unrelated UI modernization.

Keep the review scoped to the target.

If a broader design question is discovered, report it as a separate follow-up consideration only when material.

---

# 28. Self-check findings before finishing

Before producing the final review, inspect every finding again.

Ask:

1. Is this a real user impact?
2. Is there evidence?
3. Am I confusing KASANE preference with Apple guidance?
4. Am I claiming a visual fact without a screenshot?
5. Am I claiming implementation details from a screenshot?
6. Did I verify current Apple guidance when necessary?
7. Is the severity proportional?
8. Is this actually introduced or relevant to the review target?
9. Is it actionable?
10. Is it a duplicate of another finding?

Remove findings that fail this check.

---

# 29. Review completion output

Return the final review in Japanese.

Use the following structure.

## 指摘事項

List actionable findings in severity order:

- P0
- P1
- P2

Within the same severity, prioritize:

1. Accessibility / task completion;
2. navigation and state preservation;
3. primary interaction;
4. information hierarchy;
5. platform convention.

If there are no qualifying findings, write:

```text
重大なUI指摘はありません。
```

## Suggestions

List only useful optional improvements.

If none:

```text
特になし。
```

## 確認範囲

Summarize:

- target Issue / PR / screen;
- revisions when applicable;
- Views reviewed;
- navigation paths reviewed;
- screenshots reviewed;
- relevant Apple guidance checked;
- KASANE Design Principles considered.

## Evidence

State which evidence was available:

```text
Apple: あり
Code: あり
Screenshot: あり
Runtime: なし
Issue: あり
KASANE Design: あり
```

Do not claim evidence that was unavailable.

## 検証

List any commands, runtime checks, screenshot scenarios, or other checks that were actually performed.

Do not describe unexecuted checks as passed.

## 残存リスク

Describe anything that could not be verified.

Examples:

- Simulator screenshot unavailable;
- Dynamic Type scenario unavailable;
- Dark Mode screenshot unavailable;
- runtime navigation not executed;
- Apple official documentation unavailable;
- UI Test result pending macOS CI.

Write:

```text
特になし。
```

when no material residual risk remains.

---

# 30. UI review quality bar

A good KASANE UI review should allow an implementer to answer:

- What is wrong?
- Under what condition?
- Who is affected?
- Is this Apple guidance, accessibility, platform convention, or KASANE-specific?
- What evidence proves it?
- How important is it?
- What is the smallest safe direction for fixing it?

A poor review contains statements such as:

```text
Appleっぽくない
もう少しモダンにした方がいい
カードを増やした方がいい
Apple Healthみたいにした方がいい
この方がかっこいい
```

without concrete evidence or user impact.

---

# 31. Final principle

Do not review KASANE by asking:

> Apple would have designed this how?

Review KASANE by asking:

> Does this interface use Apple platform conventions appropriately, remain accessible, preserve the user’s context, support the task efficiently, and follow KASANE’s own design principles?

The goal is not to imitate Apple applications.

The goal is to build a high-quality KASANE experience that feels native to Apple platforms.
