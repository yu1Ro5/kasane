# Apple Platform Review Guide

KASANEのUIレビューでApple Human Interface GuidelinesおよびApple Developer Documentationを正しく参照するための、証拠ルールとレビュー索引を定義する。

この文書はApple Human Interface Guidelinesのコピー、要約版、または代替ではない。

Apple公式情報へアクセスできる場合は、必ず最新のApple公式情報を確認する。

この文書の役割は、レビュー時に、

- 何をApple公式情報で確認するか
- どの情報をどの強さの根拠として扱うか
- AppleのガイダンスとKASANE独自のデザイン判断をどう区別するか
- ScreenshotやSwiftUIコードから何を断定してよいか

を一貫させることである。

Last reviewed against Apple guidance: 2026-08-31

---

# 1. Source of Truth

Appleプラットフォームに関するレビュー根拠は、原則として次の優先順位で扱う。

```text
1. 最新のApple Human Interface Guidelines
        ↓
2. 最新のApple Developer Documentation
        ↓
3. Appleが提供する公式Design Resources / WWDC等の一次資料
        ↓
4. このApple Platform Review Guide
        ↓
5. KASANE Design Principles
        ↓
6. 一般的なiOS慣習・レビューワーの経験
        ↓
7. 個人的な好み
```

上位の情報が確認できる場合、下位の情報だけを根拠にAppleの推奨内容を断定しない。

個人的な好みだけに基づく指摘はレビューFindingとして報告しない。

---

# 2. Online Review Policy

Apple公式サイトへアクセス可能な場合は、Appleプラットフォームに関する重要な指摘を行う前に、関連する最新のApple公式ページを確認する。

特に次の場合はApple公式情報の確認を優先する。

- Navigation patternを問題として指摘する
- 標準Componentの使い方を問題として指摘する
- Accessibility要件を指摘する
- Dynamic Typeを指摘する
- control size / tap targetを指摘する
- Color / contrastを指摘する
- Material / Liquid Glassを指摘する
- Tab bar / Toolbar / Search / Sheet等の使い方を指摘する
- 「Appleでは推奨されない」と表現する
- OSの新しいデザイン変更に関係する

Apple公式情報が更新されている可能性を考慮し、repository内の過去の記述より最新のApple公式情報を優先する。

---

# 3. Offline Review Policy

Apple公式サイトへアクセスできない場合、このファイルに記載された安定したレビュー観点を利用してよい。

ただし、次のルールを守る。

- このファイルにないガイダンスを推測しない
- 記憶だけで最新HIGの内容を断定しない
- 「Apple HIG違反」と断定しない
- OSバージョン固有の新しいUI仕様を推測しない
- 最新確認が必要な項目は残存リスクとして報告する

例:

```text
NG:
Apple HIGではこのNavigationは禁止されています。

OK:
このNavigationは標準的なNavigationStackの挙動から外れているように見えます。
Apple公式ガイダンスを現在確認できないため、Platform Convention上の懸念として報告します。
```

---

# 4. Evidence Model

UIレビューでは、問題の種類と、その判断に使用した証拠を分離する。

## Finding category

Findingは原則として以下のいずれかに分類する。

### HIG

最新のApple Human Interface Guidelinesに、直接関連するガイダンスが確認できる場合。

### Accessibility

Accessibilityに関する問題。

Apple HIG、Apple Accessibility guidance、SwiftUI Accessibility API等を根拠にする。

### Platform Convention

Apple標準Component、SwiftUI / UIKit API、iOS標準Interaction等から確認できるPlatform上の慣習や期待される挙動。

HIGに明確な記載がない場合に、無理に `HIG` と分類しない。

### KASANE Design

`KASANE_DESIGN_PRINCIPLES.md` に明確に反する場合。

Apple HIG違反ではないことを明確にする。

### Suggestion

現在の実装が誤りとは言えないが、より良い体験になる可能性がある改善候補。

SuggestionはBlocking Findingとして扱わない。

---

# 5. Evidence Types

Finding categoryとは別に、どの証拠を使って確認したかを示す。

利用可能なEvidence:

```text
Apple
Code
Screenshot
Runtime
Issue
KASANE Design
```

## Apple evidence

最新のApple公式Human Interface GuidelinesまたはDeveloper Documentation。

## Code evidence

SwiftUIコード、View hierarchy、modifier、Accessibility設定、Navigation実装等から直接確認できる事実。

## Screenshot evidence

Simulator / 実機Screenshotから実際に確認できるVisualな事実。

## Runtime evidence

UI Test、Simulator操作、実機確認などから確認できるInteraction上の事実。

## Issue evidence

対象IssueのAcceptance Criteriaまたは明示的な設計判断。

## KASANE Design evidence

`KASANE_DESIGN_PRINCIPLES.md` に記載されたプロダクト固有原則。

---

# 6. Evidence Rules

## Screenshotがある場合

Screenshotから実際に確認できる範囲についてレビューしてよい。

例えば:

- text clipping
- hierarchy
- density
- alignment
- spacing
- primary actionの視認性
- Tab barが表示されているか
- Modalが画面を覆っているか
- Dark Mode上の視認性
- Dynamic Typeの代表状態
- control同士が近すぎる
- 不自然な大量のCard
- 色だけに依存しているように見える状態

ただしScreenshotだけから内部実装を断定しない。

例:

```text
NG:
このButtonは固定heightを使っています。

OK:
ScreenshotではDynamic Type時にボタン内のテキストが切れています。
実装原因はコード確認が必要です。
```

## Screenshotがない場合

Visualな状態を想像してFindingにしない。

コードから合理的に確認できるリスクは報告してよいが、

```text
Screenshot未確認
```

であることを残存リスクとして明示する。

例:

```text
.frame(height: 44)
```

を見ただけで、

```text
文字が切れています
```

とは断定しない。

代わりに、

```text
Dynamic Type拡大時に固定heightがcontentを収容できない可能性があります。
ScreenshotまたはSimulatorでの確認が必要です。
```

とする。

---

# 7. Apple Design Principles

レビューを開始するとき、必要に応じてApple Human Interface Guidelinesの `Design principles` を参照する。

2026-08-31時点では次の観点が提示されている。

- Purpose
- Agency
- Responsibility
- Familiarity
- Flexibility
- Simplicity
- Craft
- Delight

これらを機械的なチェックリストとして扱わない。

画面の目的や複数の設計案を比較するときの判断軸として使用する。

特にKASANEでは、次を関連付けて考える。

### Purpose

ユーザーがその画面で達成したい主要目的が明確か。

### Agency

ユーザーが状態を理解し、自分で操作し、誤操作から回復できるか。

### Responsibility

ユーザーのWorkout記録や個人データを尊重し、状態変更を透明に扱っているか。

### Familiarity

iOSで既に理解されているInteractionやComponentを不必要に再発明していないか。

### Flexibility

Dynamic Type、Accessibility、異なる利用状況に適応できるか。

### Simplicity

その画面の目的に不要な情報や操作が残っていないか。

### Craft

細部のSpacing、文言、Alignment、Animation等が一貫しているか。

### Delight

主要タスクを邪魔せず、使っていて満足感のある体験になっているか。

---

# 8. Review Index

以下はKASANEでUIレビューするときに優先して確認するApple公式HIG領域の索引である。

レビュー時には、可能な限り最新のApple公式ページを検索して確認する。

---

## 8.1 Accessibility

Apple HIG:

- Accessibility
- Inclusion

確認対象:

- Dynamic Type
- VoiceOver
- control size
- control spacing
- color contrast
- Increase Contrast
- Dark Mode
- 色だけに依存した情報表現
- motion
- alternative representation
- readable text
- accessibility labels / values / hints

### Stable review guidance

iOSでは十分な大きさのcontrolを使用し、隣接controlとのspacingも考慮する。

AppleのAccessibility guidanceに現在記載されているcontrol sizeを確認したうえで、必要な場合のみ具体的なpt値をFindingへ記載する。

固定値をこのrepositoryで永続的な真実として扱わず、レビュー時に最新情報を優先する。

Dynamic Typeをサポートし、テキスト拡大後も主要機能を利用できることを確認する。

Colorについては、色だけを状態・意味の唯一の表現方法にしない。

---

## 8.2 Navigation and Search

Apple HIG:

- Navigation and search
- Tab bars
- Search fields
- relevant presentation guidance

確認対象:

- TabによるトップレベルNavigation
- NavigationStack内の階層
- back navigation
- Modal presentation
- Search
- dismiss
- full-screen presentation
- Navigation context preservation

### Review approach

特定のNavigation方法が「Appleらしくない」という理由だけでFindingにしない。

次を確認する。

- 情報構造とNavigation patternが一致しているか
- 戻り方が理解できるか
- Modalから抜けられるか
- Top-level destinationsが安定しているか
- 同じ目的へのNavigationが画面ごとに大きく異ならないか
- 独自Navigationを作る必要が本当にあるか

---

## 8.3 Layout and Organization

Apple HIG:

- Layout and organization
- Lists and tables
- Tab views
- Labels
- Boxes
- relevant containers

確認対象:

- hierarchy
- grouping
- alignment
- spacing
- list / section structure
- adaptive layout
- content density
- unnecessary nesting

### Review approach

情報をグループ化するために、すべてをCardやBoxへ入れる必要はない。

AppleのBox guidance等を確認し、

- padding
- alignment
- Section
- List
- Grouping

だけで十分に関係性を伝えられないか確認する。

Box / Cardの入れ子によって画面が過剰に分断されていないかを見る。

---

## 8.4 Typography

Apple HIG:

- Typography
- Accessibility
- Labels

確認対象:

- system Text Styles
- Dynamic Type
- font size
- weight
- hierarchy
- legibility
- truncation
- wrapping
- fixed size

### Review approach

標準Text Styleで目的を達成できる場合は優先する。

custom font / fixed font size / fixed frameがあるだけでFindingにはしない。

実際に、

- Dynamic Typeを妨げる
- hierarchyを理解しづらくする
- contentを読めなくする

場合に指摘する。

---

## 8.5 Color and Appearance

Apple HIG:

- Color
- Accessibility
- Materials

確認対象:

- semantic colors
- custom colors
- light appearance
- dark appearance
- Increase Contrast
- color contrast
- state communication
- tint
- Liquid Glass / Material

### Stable review guidance

system-defined / semantic colorsを利用できる場合は優先する。

custom color自体を問題としない。

custom colorを使用する場合は、

- Light
- Dark
- Increased contrast

等のcontextで意味と視認性を維持できるか確認する。

重要な状態を色だけで伝えない。

MaterialやLiquid Glassへ色や装飾を追加する場合は、重要な操作や状態を強調する目的があるか確認する。

「Appleっぽくするため」だけにGlass表現を増やすことを推奨しない。

---

## 8.6 Controls and Actions

Apple HIG:

- Buttons
- Menus
- relevant Controls
- Accessibility

確認対象:

- primary action
- secondary action
- destructive action
- icon-only controls
- labels
- enabled / disabled state
- confirmation

### Review approach

同一画面で複数の操作をすべてPrimaryに見せない。

Destructive actionは通常操作と区別できるか確認する。

icon-only controlは、視覚的意味だけでなくAccessibility上も目的を理解できるか確認する。

custom controlを作る場合は、標準Button / Menu等では目的を達成できない理由があるか確認する。

---

## 8.7 Presentation

Apple HIGおよび関連Component guidance:

- Sheets
- full-screen presentations
- alerts
- confirmation dialogs
- popovers where relevant

確認対象:

- presentation目的
- dismissal
- destructive confirmation
- focus
- context preservation
- presentation depth

### Review approach

Sheetかfull-screen presentationかを「Appleっぽさ」だけで決めない。

次を確認する。

- 元画面の文脈を残す必要があるか
- 選択操作へ集中する必要があるか
- presentationから安全に戻れるか
- dismiss後に元の状態を継続できるか
- 同じpresentationを多重に重ねていないか

KASANE固有の判断については `KASANE_DESIGN_PRINCIPLES.md` を併用する。

---

## 8.8 Search

Apple HIG:

- Search fields
- Navigation and search

確認対象:

- search entry point
- searchable content
- search field placement
- empty query
- no results
- dismissal
- scope

### Review approach

Searchがあるだけで高度な検索機能を要求しない。

検索対象とユーザーが期待する検索範囲が一致しているかを確認する。

空状態・0件状態が理解できることを確認する。

---

## 8.9 Feedback and State

Apple HIG:

- Feedback-related guidance
- Alerts
- Progress indicators
- Loading
- relevant controls

確認対象:

- successful action feedback
- save failure
- destructive action confirmation
- loading
- disabled state
- state changes

### Review approach

ユーザー操作により状態が変わった場合、その結果を理解できることを確認する。

ただし、すべての操作にalertやtoastを付けることを要求しない。

システム標準の状態変化だけで十分に理解できる場合は、追加Feedbackを要求しない。

---

# 9. SwiftUI Review

SwiftUIコードを確認するときは、見た目だけでなくsystem behaviorを活かしているか確認する。

優先して確認する例:

```text
TabView
NavigationStack
NavigationLink
List
Section
Form
Button
Menu
Picker
searchable
sheet
fullScreenCover
alert
confirmationDialog
ContentUnavailableView
Label
SF Symbols
semantic Color
system Font / Text Styles
accessibilityLabel
accessibilityValue
accessibilityHint
dynamicTypeSize
```

この一覧に存在しないAPIを使用していること自体を問題としない。

目的はSwiftUI標準APIの利用率を上げることではなく、標準Interactionを不必要に再実装していないか確認することである。

---

# 10. Custom UI Review

独自Componentを見つけた場合、即座にFindingにしない。

次の順に確認する。

```text
1. 何の問題を解決しているか
        ↓
2. 標準Componentで達成できるか
        ↓
3. 独自Componentにユーザー価値があるか
        ↓
4. Accessibilityを維持しているか
        ↓
5. Platform behaviorを壊していないか
```

独自Componentが適切な場合は、その存在を問題として報告しない。

---

# 11. Review Language

次の表現を避ける。

```text
Appleっぽくない
iOSっぽくない
ダサい
センスが悪い
普通はこうする
Appleならこうする
```

これらは根拠が不明確で、actionableではない。

代わりに、

```text
HIG
Platform Convention
Accessibility
KASANE Design
Suggestion
```

のどれに該当するかを明確にする。

---

# 12. Claim Strength

Appleに関する表現は証拠の強さに合わせる。

## Apple公式に直接確認できた場合

使用可能:

```text
Apple HIGでは〜を推奨しています。
AppleのAccessibility guidanceでは〜が示されています。
```

可能であれば対象ページ名を併記する。

## Apple Developer Documentationから確認した場合

使用可能:

```text
SwiftUI / Apple Developer Documentation上の標準behaviorでは〜です。
```

HIGの記載でなければ「HIG違反」と呼ばない。

## Platform Conventionの場合

使用:

```text
iOS標準のInteractionから外れるため〜
標準Componentで提供される挙動と異なるため〜
```

## KASANE独自判断の場合

使用:

```text
KASANE Design PrinciplesのRecording Firstに反して〜
```

Appleの要求であるかのように表現しない。

## 好みの場合

原則報告しない。

有用な改善案なら `Suggestion` とする。

---

# 13. Citation Rule for Review Findings

Apple guidanceを根拠にFindingを作る場合は、レビュー時に確認したApple公式ページを特定できる形で示す。

最低限:

```text
Apple reference:
Human Interface Guidelines — Accessibility
```

必要に応じて関連するSection名も記載する。

長いApple文章を転載しない。

Apple公式情報の要点を自分の言葉で簡潔に説明する。

---

# 14. Staleness Rule

このファイルにはAppleの具体的なUI寸法やOS固有仕様を可能な限り固定しない。

具体値がFindingに重要な場合は、レビュー時に最新のApple公式情報を確認する。

Apple公式ページとこのファイルに差異がある場合はApple公式ページを優先し、このファイルの更新候補として報告する。

このファイルの `Last reviewed` 日付が古いことだけを理由にレビューを停止しない。

オンラインアクセス可能なら最新Apple guidanceを確認して続行する。

---

# 15. Review Decision Flow

Appleプラットフォームに関するUI上の違和感を見つけた場合、次の順に判断する。

```text
違和感を発見
    ↓
実際のユーザー影響があるか？
    ├─ No → 原則報告しない / Suggestion
    ↓ Yes
Apple公式情報にアクセス可能？
    ├─ Yes
    │   ↓
    │ 関連する最新HIG / Documentationを確認
    │   ↓
    │ 明確なApple guidanceあり？
    │   ├─ Yes → HIG / Accessibility
    │   └─ No  → Platform Convention等を検討
    │
    └─ No
        ↓
    このGuideに安定した根拠あり？
        ├─ Yes → 根拠の限界を明示して報告
        └─ No  → Apple要求とは断定しない
    ↓
Code / Screenshot / Runtimeで問題を確認
    ↓
KASANE Design Principlesと区別
    ↓
FindingまたはSuggestion
```

---

# 16. Relationship with KASANE Design Principles

Apple guidanceとKASANE Design Principlesは役割が異なる。

```text
Apple Platform Review Guide
→ Appleプラットフォーム上で自然・Accessible・標準的か

KASANE Design Principles
→ KASANEのプロダクト目的に適しているか
```

例えば、

Workout中に大きなStats Cardを表示することがApple HIG上許容されていても、

```text
Recording First
Progressive Disclosure
```

に反する可能性がある。

その場合は `KASANE Design` Findingとして扱い、HIG違反とは表現しない。

---

# 17. Relationship with Screenshot Review

Screenshotは重要なReview Evidenceだが、Apple guidanceそのものではない。

```text
Apple guidance
       +
Code
       +
Screenshot
       +
Runtime
       +
KASANE Design
       ↓
UI Review Finding
```

可能な限り複数のEvidenceを組み合わせる。

Screenshotが利用可能な場合は、UIの見た目に関する重要なFindingをコードだけで完結させず、実際の表示と照合する。

---

# 18. Relationship with kasane-review-pr

`kasane-review-ui` と `kasane-review-pr` は責務を分ける。

```text
kasane-review-pr
→ correctness
→ regression
→ SwiftData
→ architecture
→ security
→ tests

kasane-review-ui
→ Apple HIG
→ Platform Convention
→ Accessibility
→ Visual hierarchy
→ Screenshot
→ KASANE Design Principles
```

同じ根本原因を両方のSkillで重複Findingとして大量に報告しない。

UI上の問題がデータ損失や機能不全にもつながる場合は、より重大な影響を中心に報告する。

---

# 19. Primary Apple Review Areas

KASANEで特に優先するApple公式HIG領域:

```text
Design principles
Accessibility
Inclusion
Navigation and search
Layout and organization
Typography
Color
Materials
Buttons
Menus
Labels
Lists and tables
Tab views / Tab bars
Search fields
Alerts
Presentation-related components
SF Symbols
```

対象PRに関係のないHIGを毎回すべて読む必要はない。

変更内容に関連する領域を選んで確認する。

---

# Summary

KASANEのApple Platform Reviewでは、

1. 最新Apple公式情報を優先する
2. HIGとPlatform Conventionを混同しない
3. Apple guidanceとKASANE Design Principlesを混同しない
4. ScreenshotがないVisual事実を想像しない
5. コードだけで見た目を断定しない
6. 好みをAppleの要求として表現しない
7. Apple公式情報を確認できない場合は断定の強さを下げる
8. Findingにはユーザー影響と証拠を必要とする

ことを原則とする。

目的は「Appleっぽい」という曖昧な評価を行うことではない。

**Appleプラットフォーム上で自然に動作し、Accessibleで、KASANEの目的に適したUIであるかを、説明可能な証拠に基づいてレビューすること**を目的とする。
