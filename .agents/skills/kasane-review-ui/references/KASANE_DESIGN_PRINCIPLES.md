# KASANE Design Principles

KASANEのUI/UXを設計・実装・レビューするときに、継続的に適用するプロダクト固有のデザイン原則を定義する。

この文書はApple Human Interface Guidelinesの代替ではない。

Appleプラットフォーム上のUI、Navigation、Accessibility、標準コンポーネント等については、最新のApple公式Human Interface Guidelinesおよび関連するApple Developer Documentationを優先する。

この文書は、その上でKASANEとしてどのような体験を目指すかを判断するための補助原則である。

特定画面の一時的な仕様や、個別IssueのAcceptance Criteriaはこの文書へ記載しない。

---

## Product Direction

KASANEは、Apple Healthの「自分の記録や状態を振り返る体験」と、Apple Fitnessの「今から運動することに集中する体験」の中間を目指す。

概念的には次の役割分担とする。

```text
Apple Health的
────────────────
概要
履歴
検索
Stats
傾向
PR
Replay
「最近どうだったか」
        ↓
      KASANE
        ↑
「今から何をするか」
Workout開始
種目選択
セット記録
Workout終了
────────────────
Apple Fitness的
```

Apple純正アプリの外観を模倣すること自体を目的としない。

SwiftUIとiOS標準UIを尊重しながら、筋力トレーニングを記録するアプリとして、操作速度、視認性、継続利用しやすさを優先する。

---

# 1. Reflect and Act

KASANEには大きく2つの利用モードがある。

- 過去や現在の状態を振り返る
- 今行っているWorkoutを記録する

この2つを明確に区別する。

## Reflect

概要、履歴、Stats、Trend、Replayなどでは、ユーザーが自分のトレーニングを理解できることを優先する。

情報を急いで操作させる必要はなく、必要に応じて詳細へ掘り下げられる構造とする。

## Act

Workout開始、種目選択、セット入力、Workout終了などでは、ユーザーが現在行っている操作に集中できることを優先する。

振り返り用の情報や分析結果を過剰に表示して、現在の記録操作を邪魔しない。

### Review question

> この画面は「振り返る」ための画面か、「今行動する」ための画面か。その目的に不要な情報や操作が混ざっていないか。

---

# 2. Recording First

Workout中は、記録そのものを最優先する。

KASANEはトレーニング中に頻繁に操作されるため、通常の情報閲覧アプリ以上に操作速度を重視する。

特に次を優先する。

- 重量と回数を素早く入力できる
- 次に行う操作が予測できる
- 同じ操作を不必要に繰り返さなくてよい
- 主要操作へ少ないタップで到達できる
- 入力中のフォーカスやDraftを意図せず失わない
- アプリ内NavigationによってWorkoutの文脈を失わない
- 片手で操作する状況を考慮する

機能追加によって記録画面の情報量や操作数が増える場合、その機能がWorkout中に本当に必要かを再検討する。

### Review question

> この変更によってWorkout中の記録が以前より遅く、迷いやすく、操作しづらくなっていないか。

---

# 3. Quiet Intelligence

KASANEは記録データから有用な意味を見つけても、常にユーザーへ話しかけるコーチにはならない。

前回記録、直近傾向、停滞、自己ベスト、次の挑戦などの情報は、ユーザーの判断を補助するために使用する。

次を原則とする。

- 意味のある情報だけを表示する
- データ不足の場合は無理に結論を出さない
- 同じ提案を常時表示しない
- ユーザーへ命令しない
- 不確実な判断を確定的に表現しない
- 提案よりもユーザー自身の記録を主役にする
- 必要なときに詳細を確認できるようにする

例えば、

```text
次は42.5kgにしてください
```

よりも、

```text
3回続けて達成しています
次は42.5kgを試してみてもよさそうです
```

のように、判断理由を示しつつ選択をユーザーへ残す。

### Review question

> この情報は今表示する価値があるか。ユーザー自身の判断を助けているか、それとも不要に指示しているか。

---

# 4. Native Before Custom

Appleプラットフォームの標準的なUIで目的を達成できる場合は、独自実装より標準UIを優先する。

例えば次を優先的に検討する。

- `TabView`
- `NavigationStack`
- `List`
- `Section`
- `Form`
- `Button`
- `Menu`
- `Picker`
- `.searchable`
- `sheet`
- `fullScreenCover`
- `alert`
- `confirmationDialog`
- `ContentUnavailableView`
- SF Symbols
- semantic colors
- Dynamic Type対応のText Style

独自UIを禁止するものではない。

ただし、独自実装を採用する場合は、少なくとも次のいずれかを説明できる必要がある。

- 標準UIではWorkout中の操作速度を満たせない
- KASANE固有の情報構造を適切に表現できない
- 明確なユーザー価値がある
- Apple標準のInteraction modelを損なわずに拡張できる

「Appleっぽく見せるため」だけを理由に独自Navigation、独自TabBar、独自Controlを作らない。

### Review question

> iOS標準のコンポーネントやInteractionで同じ目的を達成できないか。

---

# 5. Hierarchy Before Decoration

情報の重要度は、まず構造、余白、Typography、配置によって表現する。

装飾を情報階層の代わりにしない。

優先順位は概ね次のとおりとする。

1. Information architecture
2. Grouping / Section
3. Typography
4. Spacing
5. Alignment
6. Standard component behavior
7. Color
8. Material / Shadow / Decoration

カード、背景色、枠線、影、Gradient、Glass表現などを追加する前に、標準的なSectionやTypographyだけで情報を整理できないか検討する。

特に、すべての情報を同じ形のCardへ入れることを避ける。

Cardは重要な情報をまとめるための手段であり、画面上の全要素に境界を付けるためのものではない。

### Review question

> このCard、背景色、Material、影を取り除いても、情報の重要度とまとまりを理解できるか。

---

# 6. Preserve Context

ユーザーが行っているWorkoutや入力操作の文脈を、不必要に失わせない。

特に次を避ける。

- 画面を開閉しただけでDraftを再生成する
- Navigationによって入力内容を失う
- 種目選択から戻ったときにWorkout状態が変わる
- タブ切替で進行中Workoutを終了または再作成する
- UI更新のために画面全体を不必要に再構築する
- 一時的な状態変化を永続データへ混ぜる

モーダル、Navigation、Tabを利用するときは、ユーザーが戻った際に「続きから自然に再開できる」ことを重視する。

### Review question

> この画面遷移の前後で、ユーザーは自分が何をしていたかを失わずに続けられるか。

---

# 7. Accessible by Default

Accessibilityは後から追加する品質項目ではなく、通常のUI品質の一部として扱う。

少なくとも以下を考慮する。

- Dynamic Type
- VoiceOver
- 十分なtap target
- semantic colors
- Dark Mode
- 色だけに依存しない状態表現
- icon-only controlのAccessibility label
- 読み上げ順
- テキスト切れ
- Reduce Motion等、該当するsystem accessibility setting

特定のアクセシビリティ要件や数値基準については、この文書ではなく最新のApple公式Human Interface Guidelinesを優先する。

### Review question

> フォントサイズ、読み上げ、表示モード、操作方法が変わっても、この機能の目的を達成できるか。

---

# 8. Progressive Disclosure

最初からすべての情報と操作を表示しない。

ユーザーがその時点で必要な情報を優先し、補助情報や高度な操作は必要に応じて確認できる構造にする。

例えばWorkout中であれば、

優先:

- 種目名
- 重量
- 回数
- Set
- 次の操作

補助:

- 前回記録
- 傾向
- Stats
- 詳細分析

とする。

補助情報が重要であっても、主要操作より強く表示しない。

Overviewでも同様に、すべてのStatsを同じ優先度で並べない。

### Review question

> ユーザーがこの瞬間に判断するために必要な情報だけが、最も見つけやすくなっているか。

---

# Design Decision Order

UI上の判断に迷った場合、原則として次の順に判断する。

```text
1. Issueの目的とユーザーストーリー
        ↓
2. 最新のApple Human Interface Guidelines
        ↓
3. iOS / SwiftUIの標準Interaction
        ↓
4. KASANE Design Principles
        ↓
5. 現在のKASANEとの一貫性
        ↓
6. 見た目上の好み
```

上位の判断を、下位の理由だけで覆さない。

例えば「こちらの方が格好いい」という理由だけで標準Navigationを変更しない。

---

# Relationship with Apple HIG

Apple Human Interface Guidelinesは、Appleプラットフォーム上での設計判断における最上位の外部ガイダンスとして扱う。

レビュー時にApple公式情報へアクセス可能な場合は、最新のApple公式情報を確認する。

この文書とApple公式ガイダンスが衝突する場合は、原則としてApple公式ガイダンスを優先する。

ただし、Apple HIGが複数の有効な設計を許容している場合、その中からKASANEの利用状況に最も適したものを、このDesign Principlesを使って判断する。

---

# Relationship with Issues

個別IssueのAcceptance Criteriaは、その実装における要求として扱う。

この文書は個別Issueの仕様書ではない。

IssueとこのDesign Principlesが明確に矛盾する場合は、勝手にどちらかを無視せず、矛盾を報告する。

UIレビューでは、

- Issue違反
- Apple platform guidance
- Accessibility
- KASANE Design Principles
- Optional suggestion

を可能な限り区別する。

---

# What This Document Does Not Define

この文書では、以下を固定しない。

- 特定画面のLayout
- 固定padding値
- 固定corner radius
- 固定font size
- 特定の色
- Card componentの見た目
- Liquid Glassの使用方法
- 個別画面のNavigation仕様
- 特定IssueのAcceptance Criteria
- Statsの具体的な表示内容
- Trend判定ロジック
- Replayの演出

これらはAppleの最新ガイダンス、現在の実装、個別Issueの目的に応じて判断する。

---

# Summary

KASANEのデザイン判断では、次を重視する。

```text
Reflect and Act
Recording First
Quiet Intelligence
Native Before Custom
Hierarchy Before Decoration
Preserve Context
Accessible by Default
Progressive Disclosure
```

KASANEらしさは、Apple純正アプリの外観をコピーすることではない。

Appleプラットフォームの自然なInteractionを尊重しながら、

**「トレーニングを素早く記録でき、その積み重ねを必要なときに自然に振り返れること」**

を一貫して実現することをKASANEのデザイン品質とする。
