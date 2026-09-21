# SwiftData schema migration

`KASANESchemaV1` は App Store へ出荷済みの production schema の snapshot であり、今後変更してはいけません。アプリが使用するバージョンは `CurrentKASANESchema.swift`、移行経路は `KASANEMigrationPlan.swift` で管理します。

V2 以降を追加するときは、次の順序を守ります。

1. V1を変更せず、新しい `KASANESchemaV2` とV2固有モデルを追加する。
2. `KASANEMigrationPlan.schemas` にV2を追加し、V1からV2への `MigrationStage` を追加する。
3. 自動移行できる変更には lightweight migrationを使用し、値変換、補正、重複解消が必要な場合だけ custom migrationを使用する。
4. `CurrentKASANESchema` をV2へ切り替え、safety markerのcurrent versionを2へ進める。
5. V1 disk storeからV2へのテストと、migration失敗時のsnapshot restoreテストを追加する。

Migration前snapshotは、SwiftDataがstoreを変更する前の状態へ戻すためのものです。Migration失敗時にstoreを削除したり、空databaseへfallbackしたりしてはいけません。

Issue #162で追加したJSON BackupはSwiftData migrationとは独立した最後の復旧経路です。Backup DTO、format、Exporter、Importerはschema migrationの都合で変更しません。
