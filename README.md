# KASANE

KASANEは、積み重ねたトレーニング履歴を、月間・年間の楽しいReplay形式のまとめに変えるiOS向けワークアウト記録アプリです。

現在は、プロジェクトの初期構築およびMVP開発の段階です。SwiftUI、XcodeGen、テスト、継続的インテグレーションの基盤を整えるため、アプリの機能は意図的に最小限にしています。Replay体験をプロダクトの差別化要素として開発する予定ですが、現時点ではまだ実装していません。

## 必要な環境

- Xcode 26をインストールしたmacOS
- XcodeGen（`brew install xcodegen`でインストール）
- iOS 26シミュレーター

## セットアップ

リポジトリに含まれる設定ファイルからXcodeプロジェクトを生成し、Xcodeで開きます。

```sh
xcodegen generate
open KASANE.xcodeproj
```

プロジェクト設定の正本は`project.yml`です。生成されるXcodeプロジェクトはGitの管理対象に含めません。

## ビルドとテスト

ローカルにインストールされているiOS 26シミュレーターを指定して、次のコマンドを実行します。

```sh
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

利用できるシミュレーター名が異なる場合は、`xcrun simctl list devices available`で確認し、`-destination`の値を変更してください。GitHub Actionsでは利用可能なiPhoneシミュレーターを動的に検出するため、固定されたシミュレーターUUIDには依存しません。

## TestFlightへの手動リリース

Apple Developer、App Store Connect、`main`のみに制限したGitHub Environment Secretsを準備した後、手動WorkflowからTestFlightへアップロードできます。Environmentの保護設定、必要な権限、Secret、実行方法、トラブルシューティングは[TestFlight手動リリースのセットアップ](docs/TESTFLIGHT_SETUP.md)を参照してください。

## リポジトリ構成

- `Sources/App/`: アプリのエントリーポイントと依存関係の構築
- `Sources/Views/`: SwiftUIの画面
- `Sources/Models/`: 今後追加するドメインモデルおよびSwiftDataモデル
- `Sources/Services/`: 外部連携やデータ永続化などのサービス
- `Sources/ViewModels/`: テスト可能な画面状態と操作
- `Tests/`: ユニットテスト
- `project.yml`: XcodeGenのプロジェクト定義
- `.github/workflows/`: 継続的インテグレーションのワークフロー
