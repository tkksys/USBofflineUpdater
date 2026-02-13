# USB オフライン Windows Update

ネットワークに接続していない Windows 11 PC に、USB メモリ経由で Windows Update（累積更新）をインストールするためのスクリプト群です。

- **前提**: プログラムは USB メモリに配置して使用します。USB のパスはスクリプトの場所から自動取得します。
- **対象バージョン**: Windows 11 21H2 / 22H2 / 23H2 / 24H2 / 25H2 のすべて
- **ダウンロード**: ネット接続PCで、USB 上のスクリプトを実行すると、同じ USB の所定の場所に直接保存
- **インストール**: オフラインPCで実行時、PCのバージョンを取得し、そのバージョンに合った更新のみをインストール

## 前提条件

- **PowerShell 5.1 以上**（Windows 11 に標準搭載）
- **ダウンロード**: ネットワーク接続が必要。管理者権限は不要
- **インストール**: 管理者権限が必要

## 手順

### 1. ネットワーク接続PCでダウンロード（USBに直接保存）

1. **このフォルダごと** USB メモリにコピーし、ネットワーク接続済みの PC に USB を接続
2. USB 内の `run_download.bat` を実行（内部で `download_updates.ps1` を呼びます）
   - USB のパスは **自動取得**（スクリプトの配置場所 = USB のルートとして使用）
3. 初回は MSCatalogLTS モジュールが自動インストールされます
4. 全バージョン（21H2〜25H2）の最新累積更新が、同じ USB の **所定の場所**（`Updates\Win11_xx\`）にダウンロードされます

**PowerShell から直接実行する場合**（USB 上で実行すればパスは自動）:
```powershell
# USB 上のスクリプトを実行すると自動で USB パスを使用
powershell -ExecutionPolicy Bypass -File "E:\USBofflineUpdater\download_updates.ps1"
# 特定バージョンのみ: -Versions "24H2","23H2"
# 別の保存先を指定する場合のみ: -DestinationPath "D:\Backup"
```

### 2. オフラインPCでインストール

1. USB メモリをオフラインの Windows 11 PC に接続
2. USB 内の **管理者として** `run_install.bat` を実行（内部で `install_updates.ps1` を呼びます）
   - 右クリック → 「管理者として実行」
3. スクリプトが **インストール先PCの Windows バージョン**（21H2/22H2/23H2/24H2/25H2）を自動取得し、対応するフォルダ（例: Win11_24H2）の更新のみをインストール
4. 再起動が必要な場合は案内されます
5. ログは USB 内の `logs\` に保存されます（実行ごとに `install_yyyyMMdd_HHmmss.log` と `install_<PC名>_yyyyMMdd_HHmm.csv` が作成されます）

## USBメモリ上の所定の場所（フォルダ構成）

ダウンロード後、USB には次の構成で保存されます。

```
（USB ルート、例: E:\）
├── download_updates.ps1
├── install_updates.ps1
├── run_download.bat
├── run_install.bat
├── Updates/                ← 所定の保存先（ダウンロード先）
│   ├── Win11_21H2/
│   ├── Win11_22H2/
│   ├── Win11_23H2/
│   ├── Win11_24H2/
│   └── Win11_25H2/
├── logs/                    ← インストールログ（実行ごとにタイムスタンプ付き .log / .csv）
└── README.md
```

- **ダウンロード**: スクリプトの配置場所（USB パス）を自動取得し、その直下に `Updates` フォルダを作成して `Win11_21H2` 〜 `Win11_25H2` を保存します。
- **インストール**: スクリプトと同じ階層の `Updates\Win11_<バージョン>\` を参照します。USB に上記構成で配置し、USB 上で実行してください。

## 対応バージョン

- Windows 11 21H2
- Windows 11 22H2
- Windows 11 23H2
- Windows 11 24H2
- Windows 11 25H2

インストール時は、その PC のバージョンに合わせた更新プログラムのみが適用されます。

**Pro / Home**: 累積更新（LCU）はエディション共通のため、Windows 11 Pro でも Home でも同じスクリプト・同じ更新ファイルでインストールできます。

## WSUS Offline Update を利用する場合（オプション）

LCU（累積更新）以外に .NET Framework、Windows Defender 定義なども含めたい場合は、[WSUS Offline Update](https://wsusoffline.net/) の利用を検討してください。

1. [download.wsusoffline.net](https://download.wsusoffline.net/) から ZIP をダウンロード
2. 解凍後、`UpdateGenerator.exe` で更新をダウンロード
3. オフライン PC では `client\UpdateInstaller.exe` を実行

## トラブルシューティング

- **「該当更新が見つかりません」**: USB 内の `Updates` フォルダに、インストール先の Windows バージョンに対応するフォルダ（Win11_24H2 等）があるか確認してください。
- **「Start-Transcript -Encoding のパラメータが見つからない」**: Windows PowerShell 5.1 では `Start-Transcript -Encoding` が使えません。スクリプトを最新版に更新してください（-Encoding を付けない形に修正済み）。
- **実行ポリシーエラー**: `Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser` を実行
- **MSCatalogLTS のインストール失敗**: ネットワーク接続と PowerShell Gallery へのアクセスを確認
