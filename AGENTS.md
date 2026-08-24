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

## フォーマットとCI

変更を提出する前に、リポジトリの設定を使ってSwiftコードを整形します。

```sh
swift-format format --in-place --configuration .swift-format --recursive Sources Tests
```

インデントには半角スペース4つを使用し、ファイル末尾の改行を維持し、import文を並べ替えてください。Pull Requestでは、`.github/workflows/ios-build.yml`に定義されたXcodeGenによるプロジェクト生成、シミュレーター向けビルド、ユニットテストがすべて成功する必要があります。

## セキュリティ

シークレット、認証情報、APIキー、証明書、プロビジョニングプロファイル、秘密の署名素材は絶対にコミットしないでください。CIのシミュレーター向けビルドではコード署名を無効にします。
