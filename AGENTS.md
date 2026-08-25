# KASANE エージェントガイド

このファイルでは、このリポジトリで作業するAIコーディングエージェント向けのルールを説明します。

## プロジェクト概要

KASANEは、月間・年間のReplay形式のまとめを特徴とするiOS向けワークアウト記録アプリです。UIにはSwiftUIを使用し、データモデルの追加に合わせてSwiftDataを採用します。アーキテクチャはMVVMを基本とし、`project.yml`からXcodeGenで`KASANE.xcodeproj`を生成します。

## リポジトリ構成

- `Sources/App/`: アプリのライフサイクルと依存関係の構築
- `Sources/Models/`: SwiftDataモデルとドメインモデル
- `Sources/Services/`: データ永続化や外部サービスとの連携
- `Sources/ViewModels/`: 画面状態とビジネス上の操作
- `Sources/Views/`: SwiftUIの画面
- `Sources/Assets.xcassets/`: アプリで使用する画像や色などのアセット
- `Tests/`: ユニットテスト
- `project.yml`: Xcodeプロジェクト設定の正本
- `.github/workflows/`: 継続的インテグレーション

`docs/planning/` は将来候補を含む計画資料であり、確定仕様として扱わないでください。現在の実装はコードとテストを正とし、`docs/architecture/` はその設計を説明する補助資料として更新してください。

空のディレクトリをGitへ登録する必要はありません。各レイヤーが必要になった時点で、適切なディレクトリへファイルを追加してください。

## XcodeGenの運用

生成された`.xcodeproj`を直接編集したり、Gitへコミットしたりしないでください。ソースファイルを追加、削除、移動した場合は、次のコマンドでプロジェクトを再生成します。

```sh
brew install xcodegen
xcodegen generate
open KASANE.xcodeproj
```

## ビルドとテスト

ローカルにインストールされているiOS 26シミュレーターを指定して実行します。

```sh
xcodegen generate
xcodebuild -project KASANE.xcodeproj \
  -scheme KASANE \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -configuration Debug \
  CODE_SIGNING_ALLOWED=NO \
  build
xcodebuild -project KASANE.xcodeproj \
  -scheme KASANE \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -configuration Debug \
  CODE_SIGNING_ALLOWED=NO \
  test
```

利用できるシミュレーター名はXcodeのバージョンによって異なります。`xcrun simctl list devices available`で確認し、必要に応じて指定を変更してください。CIでは生成したプロジェクトのビルドとテストを必ず実行し、固定されたシミュレーターUUIDに依存してはいけません。

## アーキテクチャと命名規則

- ViewはUIの表示とユーザー操作の受け渡しに集中させます。
- 状態管理やビジネスロジックはViewへ直接記述せず、テスト可能なViewModel、Model、Serviceへ配置します。
- SwiftUIの画面は`SomethingView`、ViewModelは`SomethingViewModel`という形式で命名します。
- グローバルな状態よりも、責務の小さい型と依存性注入を優先します。
- 強制アンラップ（`!`）と強制的なエラー無視（`try!`）は使用せず、失敗を明示的に処理します。
- ビジネス上の振る舞いに対して、目的の明確なユニットテストを追加します。意味のない大規模なテスト用コードは作成しません。

## 実装時の作業規約

- 1つのIssueでは、受け入れ条件を満たすために必要な変更だけを行ってください。
- 関係のないリファクタリング、機能追加、ファイル変更を同じPull Requestへ含めないでください。
- 新しい外部依存の追加や、既存アーキテクチャの大幅な変更は、明示的な合意を得てから行ってください。
- Issue、コード、テスト、補助資料の間に矛盾がある場合は、推測で解決せず、矛盾する内容と影響を報告してください。
- `docs/planning/`は将来候補を含む計画資料であり、確定仕様として扱わないでください。
- 現在の実装はコードとテストを正とし、Issueの受け入れ条件を対象タスクの要求として扱ってください。
- 一時的な機能仕様をこのファイルへ重複して記載しないでください。繰り返し適用する開発規約だけを残してください。

## フォーマットとCI

変更を提出する前に、リポジトリの設定を使ってSwiftコードを整形します。

```sh
swift-format format --in-place --configuration .swift-format --recursive Sources Tests
```

インデントには半角スペース4つを使用し、ファイル末尾の改行を維持し、import文を並べ替えてください。Pull Requestでは、`.github/workflows/ios-build.yml`に定義されたXcodeGenによるプロジェクト生成、シミュレーター向けビルド、ユニットテストがすべて成功する必要があります。

## 完了条件

変更内容と実行環境に応じて、必要な検証を行ってください。

### Swiftコードを変更した場合

- リポジトリの`.swift-format`を使用して、変更したSwiftコードを整形してください。
- 追加または変更したビジネスロジックに必要なユニットテストを追加・更新してください。
- `xcodegen generate`を実行してください。
- Debugビルドとユニットテストを実行してください。

### `project.yml`を変更した場合

- `xcodegen generate`を実行してください。
- Debugビルドとユニットテストを実行してください。

### Markdown、`AGENTS.md`、Skillだけを変更した場合

- Markdownの構造、リンク、重複、記述間の矛盾を確認してください。
- Skillを変更した場合は、frontmatter、名称、配置、発火条件、非対象条件を確認してください。
- `git diff --check`を実行してください。

### 検証コマンドを実行できない場合

- macOS、Xcode、シミュレーター、その他の必要なツールを利用できない場合は、実行できなかったコマンドと理由を明記してください。
- 実行していない検証を、成功または確認済みとして報告しないでください。
- ローカルで実行できないiOSビルドとテストは、macOS上のCI結果をマージ条件として扱ってください。

### 作業完了時の報告

- Issueの受け入れ条件を満たしているか確認してください。
- 関係のないファイルが変更されていないことを確認してください。
- 実施内容、実行した検証、実行できなかった検証、残課題を明確に報告してください。

## Code Review Rules

- レビュー結果、GitHubのレビュー本文、インラインレビューコメントは、固有名詞、コード、API名を除いて日本語で記述してください。
- 仕様違反、クラッシュ、データ消失、状態不整合、セキュリティ問題を優先して確認してください。
- `WorkoutSession`、`ExerciseEntry`、`SetEntry`の関連、順序、追加、削除の整合性を確認してください。
- SwiftDataの保存、取得、削除の失敗を黙って無視していないか確認してください。
- Viewにビジネスロジックや永続化処理が入り込んでいないか確認してください。
- 変更された振る舞いに対して、必要なテストが不足していないか確認してください。
- 指摘には、重大度、対象箇所、根拠、影響を含めてください。可能な場合は、再現条件または安全な修正方針も示してください。
- フォーマットなどCIで機械的に判定できる内容は、実際の不具合につながる場合を除き、レビューコメントにしないでください。
- 根拠のない推測、変更範囲外への不要な提案、好みだけに基づく指摘を避けてください。
- 問題が見つからない場合は、確認した範囲と残存リスクを日本語で報告してください。

## サブエージェントの利用

- サブエージェントは、調査、テスト観点の洗い出し、ログ解析、レビューなど、独立した読み取り中心の作業に使用してください。
- 同じファイルを複数のエージェントが同時に編集する構成を避けてください。
- 依存関係のある実装Issueを無理に並列化しないでください。
- メインエージェントが要求、判断、変更内容、検証結果を最終的に統合してください。

## セキュリティ

シークレット、認証情報、APIキー、証明書、プロビジョニングプロファイル、秘密の署名素材は絶対にコミットしないでください。CIのシミュレーター向けビルドではコード署名を無効にします。

## UI Screenshotレビュー

- UI表示を変更するIssueでは、既存のScreenshot scenarioで対象状態を再現できる場合、その結果をPull Request上で確認してください。
- 既存scenarioで必要な状態を再現できない場合に限り、目的を限定したScreenshot scenarioを追加してください。
- Screenshotは自動的な正しさの証明ではなく、人間によるUIレビュー資料として扱ってください。
- Codex CloudではiOS Simulatorを利用できないため、Simulatorで確認済みと報告しないでください。
- Repository visibilityが変更された場合は、Screenshotのinline表示方式がそのvisibilityに適しているか再確認してください。
