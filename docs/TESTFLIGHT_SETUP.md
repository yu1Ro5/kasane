# TestFlight手動リリースのセットアップ

`.github/workflows/ios-testflight.yml`は、GitHub ActionsからKASANEをArchiveし、App Store Connectへアップロードする手動実行専用のWorkflowです。Appleがアップロードを受理した時点でWorkflowは成功となり、TestFlight上の処理完了までは待ちません。

## 1. Apple側の事前設定

### Apple Developer

1. 「Certificates, Identifiers & Profiles」で、Identifier `com.yu1Ro5.kasane`の明示的なApp IDを作成するか、既存のものを確認します。
2. Membership detailsでTeam IDを確認します。これは`APPLE_DEVELOPMENT_TEAM_ID`に登録します。
3. Account Holderが、組織でCloud-managed certificatesの利用を制限していないことを確認します。本Workflowは固定の`.p12`証明書やProvisioning Profileを保管せず、Xcodeのautomatic signingとcloud signingを利用します。

### App Store Connect

1. 「マイApp」でBundle ID `com.yu1Ro5.kasane`のKASANEアプリレコードを作成します。
2. 「ユーザとアクセス」から「統合」または「App Store Connect API」を開き、Team API Keyを発行します。
3. API Keyには、ビルドをアップロードできる**App Manager**以上のロールを付与します。アクセス対象を限定する場合はKASANEを含めます。
4. 一覧に表示されるKey IDと、同じ画面に表示されるIssuer IDを控えます。
5. 発行時に一度だけダウンロードできる`.p8`秘密鍵を安全な場所へ保存します。秘密鍵をGitへ追加しないでください。

API Keyを使ったautomatic signingには、Developer Portal側のリソースへアクセスできる権限とcloud-managed certificateの利用許可も必要です。組織の権限設定によって署名を完結できない場合は、Account HolderまたはAdminが権限を見直してください。不足を固定証明書やApple IDパスワードのコミットで回避しないでください。

## 2. 秘密鍵をbase64化する

改行を含まない値としてGitHub Secretへ保存します。

macOS:

```sh
base64 -i AuthKey.p8 | tr -d '\n' | pbcopy
```

Linux:

```sh
base64 -w 0 AuthKey.p8
```

コマンド出力をIssue、Pull Request、Actionsログへ貼り付けないでください。登録後も元の秘密鍵はAppleの推奨に従って安全に保管します。

## 3. GitHub EnvironmentとSecretsを設定する

認証情報を信頼できないブランチから隔離するため、Repository SecretsではなくGitHub Environment Secretsを使用します。

1. GitHubリポジトリの **Settings → Environments → New environment** を開き、`app-store` Environmentを作成します。
2. `app-store`の **Deployment branches and tags** で **Selected branches and tags** を選択し、許可するbranchとして`main`だけを追加します。
3. `app-store`の **Environment secrets → Add environment secret** で、次の4項目を登録します。

| Secret | 内容 |
| --- | --- |
| `APP_STORE_CONNECT_KEY_ID` | App Store Connect API Key一覧のKey ID |
| `APP_STORE_CONNECT_ISSUER_ID` | App Store Connect API画面のIssuer ID |
| `APP_STORE_CONNECT_API_KEY_BASE64` | `.p8`をbase64化した値 |
| `APPLE_DEVELOPMENT_TEAM_ID` | Apple Developer Membership detailsのTeam ID |

同名の値をRepository Secretsへ登録済みの場合は、Environment Secretsで動作確認した後にRepository Secretsから4項目を削除できます。Repository Secretsには残さないことを推奨します。

Workflowのリリースjob自体も`main`からの実行だけを許可しています。`main`以外のrefから手動実行した場合はjob全体がskipされ、`app-store` EnvironmentやそのSecretsへアクセスせず、checkoutやbuildも行いません。Environment側のDeployment branches制限は、Workflowファイルが悪意ある内容へ変更された場合にも認証情報を保護する追加の境界になります。

未設定のEnvironment Secretがある場合、WorkflowはArchive前に不足しているSecret名を表示して失敗します。値そのものは表示しません。秘密鍵の値は復元stepだけへ渡し、job内の他のstepへは公開しません。Key ID、Issuer ID、Team IDも、それぞれ必要なstepだけへ渡します。

## 4. Workflowを手動実行する

1. GitHubの **Actions** タブを開きます。
2. **iOS TestFlight Release** を選びます。
3. **Run workflow** で`main`ブランチを選択し、実行します。別のbranchを選ぶとリリースjobはskipされます。

WorkflowはXcode 26を選択し、XcodeGenでプロジェクトを生成して、Release構成をgeneric iOS device向けにArchiveします。Build NumberにはWorkflow固有の`GITHUB_RUN_NUMBER`を渡すため、`project.yml`の`CURRENT_PROJECT_VERSION`を書き換えたり、Build Numberだけのcommitを作ったりしません。

続いて、automatic signingとApp Store Connect API Keyを使って`xcodebuild -exportArchive`を実行します。`Configuration/TestFlightExportOptions.plist`の`destination`は`upload`なので、書き出し処理がApp Store Connectへのアップロードまで行います。

成功後はApp Store ConnectのKASANEのTestFlight画面にBuildが現れ、Apple側のprocessingが始まります。processing完了後、輸出コンプライアンスなど必要な質問へ回答して内部テスターへ配布します。

## よくある失敗

- **Validate release secretsで失敗する**: 表示されたSecretが未登録または空です。Secret名と登録先リポジトリを確認します。
- **API Keyの復元に失敗する**: `APP_STORE_CONNECT_API_KEY_BASE64`が`.p8`全体の正しいbase64ではありません。元ファイルから再作成します。
- **authentication / authorizationエラー**: Key ID、Issuer ID、秘密鍵の組み合わせ、API Keyのロール、KASANEへのアクセス範囲を確認します。失効したKeyは再発行が必要です。
- **No Accounts / provisioning profileエラー**: Team ID、App ID、Bundle IDが一致するか、automatic signingとcloud-managed certificatesを利用できる権限があるか確認します。
- **certificate作成またはcloud signingエラー**: Account Holderがcloud-managed certificateのアクセスを許可し、API Keyのロールが十分か確認します。秘密の証明書をrepositoryへ追加して回避しません。
- **アプリレコードが見つからない**: App Store Connectに`com.yu1Ro5.kasane`のアプリレコードが存在するか確認します。
- **Build Numberの重複**: 同一Workflowでは`GITHUB_RUN_NUMBER`が増加します。過去に同じVersionとBuild Numberを別経路からアップロードした場合は、Actionsのrun numberとApp Store Connect上のBuildを確認します。
- **Upload後にTestFlightへすぐ表示されない**: Workflow成功はAppleによる受理を意味します。processing完了には時間がかかる場合があり、完了後にApp Store Connect上の追加対応が必要なことがあります。

署名またはアップロードが失敗した場合、Workflowも失敗します。API秘密鍵と実行時にTeam IDを追加したExport Optionsは成功・失敗を問わず最後に削除され、artifactには保存されません。
