# FAQ - USB オフライン Windows Update

## 全般

### ダウンロードする更新は、設定の Windows Update で入るものと同じ？

はい、同じ種類の更新です。  
スクリプトは **累積更新（Cumulative Update for Windows 11）** を Microsoft Update カタログから取得しています。設定の「Windows Update」でインストールされる累積更新（KBxxxxxxx）と同じパッケージです。ドライバーやオプションの更新は含みません。

### 対応している Windows 11 のバージョンは？

21H2 / 22H2 / 23H2 / 24H2 / 25H2 です。インストール時は、その PC のバージョンに合ったフォルダ（例: Win11_24H2）の更新のみをインストールします。

### 管理者権限は必要？

- **ダウンロード**: 不要（一般ユーザーで実行可）
- **インストール**: 必要。`run_install.bat` は「管理者として実行」してください。

---

## ダウンロード

### 保存先を変えたい

PowerShell で実行する場合、`-DestinationPath` で指定できます。

```powershell
powershell -ExecutionPolicy Bypass -File "E:\USBofflineUpdater\download_updates.ps1" -DestinationPath "D:\MyUpdates"
```

### 特定バージョンだけダウンロードしたい

`-Versions` で指定できます。

```powershell
powershell -ExecutionPolicy Bypass -File "E:\USBofflineUpdater\download_updates.ps1" -Versions "24H2","25H2"
```

### MSCatalogLTS のインストールに失敗する

ネットワーク接続と PowerShell Gallery（https://www.powershellgallery.com）へのアクセスを確認してください。社内プロキシがある場合は、PowerShell のプロキシ設定が必要な場合があります。

---

## インストール

### 「該当更新が見つかりません」と出る

USB 内の `Updates` フォルダに、その PC の Windows バージョンに対応するフォルダ（Win11_24H2 など）があるか確認してください。フォルダ名は 21H2 / 22H2 / 23H2 / 24H2 / 25H2 に対応しています。

### 「Update not applicable」や「Skipped (not applicable)」と出る

その PC には既にその更新が入っているか、別の理由で適用対象外と判断された場合です。失敗ではなく、スキップとして記録されます。ログの「Overall: Success」であれば問題ありません。

### ログはどこに残る？

USB 内の `logs\` フォルダです。実行ごとに `install_yyyyMMdd_HHmmss.log`（トランスクリプト）と `install_<PC名>_yyyyMMdd_HHmm.csv`（結果一覧）が作成されます。

---

## トラブルシューティング

### Start-Transcript -Encoding のエラー

Windows PowerShell 5.1 では `-Encoding` が使えません。スクリプトを最新版に更新してください（既に `-Encoding` を付けない形に修正済みのバージョンを使用してください）。

### 実行ポリシーエラー（スクリプトが実行できない）

次のいずれかを実行してください。

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

バッチから実行する場合は `-ExecutionPolicy Bypass` が指定されているため、通常は問題になりません。

### 文字化けする

バッチで `chcp 65001` を実行し、スクリプトは UTF-8 BOM で保存されています。メッセージは英語表記に統一しているため、多くの環境で表示が安定します。それでも乱れる場合は、コンソールのフォントを「UTF-8 対応」のものに変更してみてください。
