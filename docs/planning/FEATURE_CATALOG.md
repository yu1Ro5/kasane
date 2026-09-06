# KASANE Feature Catalog

この文書は、KASANEで検討している機能を整理するための planning document です。

記載されている機能は実装を確約するものではなく、仕様・優先順位・機能ID・内容は今後変更される可能性があります。機能IDが付与されていること自体は、仕様確定や実装予定を意味しません。

個別機能の実装時の要件・Acceptance Criteriaについては対応するGitHub Issueを優先し、現在実際に動作する仕様についてはコードおよびテストを正とします。

## Status

- `Candidate`: アイデア・検討対象。実装決定ではない
- `Planned`: 実装する方針になった
- `In Progress`: Issue化され実装中
- `Implemented`: 実装済み
- `Deferred`: 現時点では見送り
- `Dropped`: 採用しない

## 機能一覧

| 機能ID | 機能名 | 概要 | Status |
| ------ | -------- | ---------- | -------- |
| REC-01 | ワークアウト開始 | 新しいトレーニングを開始・再開・破棄する | Implemented |
| REC-02A | 種目追加・削除 | Workout内の種目を追加・削除する | Implemented |
| REC-02B | 種目並び替え | Workout内の種目を並び替える | Candidate |
| REC-03 | セット記録 | 重量・回数を追加・修正・削除する | Implemented |
| REC-04 | ウォームアップ記録 | セットをウォームアップとして区別する | Candidate |
| REC-05 | ワークアウト終了 | 終了日時を記録してWorkoutを完了する | Implemented |
| REC-06 | ワークアウトメモ | Workout単位でメモを残す | Candidate |
| EXE-01 | 種目選択・検索 | トレーニング種目を選択・検索する | Implemented |
| EXE-02 | カスタム種目管理 | 種目追加・名称変更・非表示化を行う | Candidate |
| HIS-01 | ワークアウト履歴一覧 | 過去のWorkoutを日付順に表示する | Implemented |
| HIS-02 | ワークアウト詳細 | 種目・セットを含む過去Workoutを見る | Implemented |
| HIS-03A | 過去記録編集 | 過去Workoutの種目・セット記録を修正する | Implemented |
| HIS-03B | 過去Workout削除 | 過去Workout全体を削除する | Candidate |
| HIS-04 | 前回記録表示 | 同じ種目の直近重量・回数を表示する | Candidate |
| STA-01 | トレーニング回数集計 | 月間・年間のWorkout回数を算出する | Candidate |
| STA-02 | トレーニング時間集計 | Workout時間を集計する | Candidate |
| STA-03 | 総挙上重量集計 | 重量×回数の合計を算出する | Candidate |
| STA-04 | 最多実施種目 | 最も多く行った種目を算出する | Candidate |
| STA-05 | 部位別集計 | 部位ごとの実績を集計する | Candidate |
| STA-06 | 自己ベスト判定 | 最大重量等のPRを検出する | Candidate |
| STA-07 | 種目別成長 | 過去記録との比較から成長を算出する | Candidate |
| STA-08 | 継続・活動日数 | Workout実施日から継続状況を算出する | Candidate |
| RPL-01 | 月間サマリー | 月単位の振り返りを生成する | Candidate |
| RPL-02 | 年間Replay | 1年間のトレーニングを振り返る | Candidate |
| RPL-03 | シェアカード | Stats / Replayを共有用に表示する | Candidate |

この一覧は現時点の候補を残すためのものであり、記載された `Candidate` は実装決定や、特定Issueの実装範囲を意味しません。
