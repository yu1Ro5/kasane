# 概要画面のAdMobテストバナー

確認日 2026-11-06。Issue #235。実広告、外部テスター配布、App Store公開の承認はこのPRに含まない。

## SDKと配置

- Google Mobile Ads 13.12.0、UMP 3.1.0をSPMで固定する。公式Package.swiftのGMA側UMP制約は1.1.0以上4.0.0未満で、採用版は範囲内。iOS 26、Swift 6、Xcode 27の既存設定を使用する。
- 設定の正本はproject.yml。生成したxcodeprojは登録しない。
- App IDはInfo.plistの `ca-app-pub-3940256099942544~1458002511`。バナーの広告ユニットIDは `ca-app-pub-3940256099942544/2435281174`。上書き機能は設けない。
- OverviewViewのスクロール内容の最後に1枠を置く。Inline adaptive bannerの幅は利用可能なコンテナ幅、高さの上限は60pt。成功後の実サイズで表示し、読み込み中・失敗時は高さを0にする。
- SDKへ渡すのはテストID、表示サイズ、プライバシー設定、空の広告Requestのみ。Workout、HealthKit、種目名、重量、回数、履歴、Stats、Replayは渡さない。
- 同意フォームのロード後にもタスクのキャンセルを検査する。概要から移動した場合はフォームの提示を中止する。

[導入](https://developers.google.com/admob/ios/quick-start)、
[バナー](https://developers.google.com/admob/ios/banner)、
[サイズAPI](https://developers.google.com/admob/ios/api/reference/Functions)、
[公式テストID](https://developers.google.com/admob/ios/test-ads)、
[GMA Package.swift](https://github.com/googleads/swift-package-manager-google-mobile-ads/blob/13.12.0/Package.swift)、
[UMP Package.swift](https://github.com/googleads/swift-package-manager-google-user-messaging-platform/blob/3.1.0/Package.swift)

## 有効化と同意

初期設定はOFF。DebugのXcode SchemeのRun引数に `--enable-admob-test-banner` を指定した場合だけUMPを呼ぶ。Releaseは引数にかかわらずOFF。テスト実施者自身がSDKの情報取扱いを確認したローカル開発に限定する。

UMP更新、必要なフォームのロード・提示、canRequestAds確認、SDK設定・初期化、バナー取得の順に実行する。更新やフォームでエラーになった場合は、過去の同意が残っていても広告を取得しない。必要な場合は概要末尾に「広告のプライバシー設定」を表示する。再選択開始時に広告を外し、結果を再評価する。

パーソナライズとPublisher first-party IDを初期化前に無効化する。ATTを要求するAPIおよびNSUserTrackingUsageDescriptionは追加しない。年齢適合性の補助として広告コンテンツ評価をgeneralに制限する。IDFAの許可を求めず、SDKへのユーザー識別子やターゲティング情報の設定も行わない。SKAdNetworkによるコンバージョン計測は今回の対象外のため、その一覧は追加しない。

[UMP](https://developers.google.com/admob/ios/privacy)、
[フォームAPI](https://developers.google.com/admob/ios/privacy/api/reference/Classes/UMPConsentForm)、
[パーソナライズ制御](https://developers.google.com/admob/ios/targeting)、
[ATTとfirst-party ID](https://developers.google.com/admob/ios/privacy/strategies)

## プライバシーと配布条件

Googleのデータ開示資料には、診断ログ、性能情報、端末識別子、広告データ、概略位置、操作情報が列挙されている。テスト広告でもこれらが収集されないとは判断しない。非パーソナライズ設定も、SDKの全通信停止を意味しない。

既存のPrivacyInfo.xcprivacyはアプリ自身の収集項目が空でTrackingがfalse。今回アプリ独自の収集は増やさないため維持する。SDKのマニフェストをこのファイルで代替してはいけない。既存ポリシーの「広告SDKを使用していない」という説明は、配布版の挙動と開発用テスト機能を区別する文章に更新する。

配布前に次を完了する。今回の環境では未完了のため、SDKを含むビルドを無条件に配布可能とは判断していない。

1. 実際のアーカイブでGMA・UMPの署名、PrivacyInfo.xcprivacy、Required Reason API、Xcode Privacy Reportを検査する。
2. App Store Connectで端末ID、概略位置、広告データ・操作、クラッシュ・性能情報の各項目について、実際の収集、第三者広告・分析等の目的、ユーザーとの関連付け、Trackingを確認して申告する。「データ収集なし」の継続は自動的に判断しない。
3. Releaseの通信確認を行い、初期化前のSDK動作も含めて申告と公開ポリシーを照合する。
4. AdMob側の地域別メッセージ設定と同意フォームを検証する。公式共通App IDでUMPが設定エラーを返す場合は広告を止める。本番App IDへ差し替えて回避しない。
5. 年齢レーティング、健康データ利用禁止、不適切広告の報告手段を確認する。外部ユーザー向けの広告報告導線は#236で用意する。

Googleのマニフェスト対応はGMA 11.2.0以降。Appleは第三者SDKの挙動も開発者の責任として扱い、健康・フィットネスデータの広告利用を制限する。SDKの組み込みだけで審査要件を満たしたとは判断しない。

[Googleデータ開示](https://developers.google.com/admob/ios/privacy/data-disclosure)、
[Apple App Privacy](https://developer.apple.com/app-store/app-privacy-details/)、
[第三者SDK要件](https://developer.apple.com/support/third-party-SDK-requirements/)、
[審査ガイドライン 2.5.18、5.1.3](https://developer.apple.com/app-store/review/guidelines/)

## 検証

UIテストの `--ui-testing` は実広告の有効化引数より優先する。さらに `--stub-overview-banner` がある場合だけ決定的なバナーを表示する。通常のScreenshot CIはOFFで、既存の5枚・1テストを維持する。回帰テストに1件を追加し、末尾の広告1枠、Workoutでの非表示、UIテストでの実広告OFFを確認する。

Unit Testは機能フラグ、同意更新失敗時の遮断、同意前のSDK未初期化、再選択後の許可・撤回、初期化の重複防止を確認する。

ローカルのXcodeGen生成、swift-format、plist構文、git diff --checkは成功。AdConfiguration単体のSwift実行でDebugの明示ON、Releaseの強制OFF、UIテスト優先を確認した。Observableを含む同意処理の単体実行は、マクロの子プロセスを起動するsandbox-execがOperation not permittedとなり停止した。Xcode 27でDebugビルドとUnit/UI Testを試行したが、SwiftPMの診断キャッシュへの書き込みがOperation not permittedとなり、依存解決で停止した。CoreSimulatorServiceにも接続できない。SDK配布zipの直接取得もHTTP 403となった。iOSビルド・テスト・実画面・実広告表示の成功は未確認。

再実行手順は次のとおり。

```sh
xcodegen generate --spec project.yml
xcrun simctl list devices available
xcodebuild -project KASANE.xcodeproj -scheme KASANE -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro' CODE_SIGNING_ALLOWED=NO build
xcodebuild -project KASANE.xcodeproj -scheme KASANE -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro' CODE_SIGNING_ALLOWED=NO \
  -only-testing:KASANETests \
  -only-testing:KASANEUITests/KASANEUIRegressionTests/testOverviewTestBanner test
```

実機では広告ON/OFF、公式Test Ad表示、機内モード、広告読み込み中の画面移動、再選択・撤回、再起動を確認する。小画面、縦横、Light/Dark、最大Dynamic Type、VoiceOverで末尾までスクロールし、カードとタブバーを覆わないことを確認する。通信観測でOFF・UIテスト・Releaseが広告取得しないことも確認する。

TestFlightは未実施。配布前条件を満たすまでは送信しない。#236では本番用設定、配布審査、同意設定、広告報告、申告とポリシーの最終照合を扱う。
