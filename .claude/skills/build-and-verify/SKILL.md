---
name: build-and-verify
description: ccui macOS アプリをビルド・起動・スクリーンショット撮影して UI を目視確認する。UI 変更後の動作確認、レイアウト検証、ビジュアルリグレッションチェックに使う。「ビルドして確認」「動作確認して」「スクショ撮って」「UI 見せて」のような依頼で発動する。
---

# ccui ビルド＆動作確認

ccui macOS アプリをビルドし、起動してスクリーンショットを撮影し、UI の状態を目視確認するためのスキル。

## ワークフロー

### Step 1: 既存プロセスの終了

```bash
pkill -x ccui 2>/dev/null || true
```

### Step 2: ビルド

```bash
/Users/nova/ghq/github.com/yuta24/ccui/scripts/build.sh
```

ビルドが失敗した場合はエラーを表示して停止する。成功時はアプリパスが最終行に表示される。

### Step 3: アプリの起動

```bash
open /Users/nova/ghq/github.com/yuta24/ccui/.build/Build/Products/Debug/ccui.app
```

### Step 4: スクリーンショット撮影

起動後 3 秒待ってからウィンドウ領域を取得しスクリーンショットを撮る。すべてワンライナーで実行する:

```bash
sleep 3 && osascript -e 'tell application "ccui" to activate' && sleep 1 && screencapture -x -R "$(osascript -e '
tell application "System Events"
    tell process "ccui"
        set frontmost to true
        set winPos to position of window 1
        set winSize to size of window 1
    end tell
end tell
return (item 1 of winPos as text) & "," & (item 2 of winPos as text) & "," & (item 1 of winSize as text) & "," & (item 2 of winSize as text)
')" /tmp/ccui-screenshot.png
```

撮影後、Read ツールで `/tmp/ccui-screenshot.png` を読み込んで表示する。

### Step 5: UI 操作（オプション）

特定の UI 要素をクリックして追加のスクリーンショットを撮りたい場合:

**サイドバーの行を選択する:**

```bash
osascript -e '
tell application "System Events"
    tell process "ccui"
        set frontmost to true
        set selected of row N of outline 1 of scroll area 1 of group 1 of splitter group 1 of group 1 of window 1 to true
    end tell
end tell
'
```

N は行番号（1始まり）。選択後 1 秒待ってから Step 4 と同じ方法でスクリーンショットを撮る。

**UI 階層の調査:**

UI 要素のパスが不明な場合:

```bash
osascript -e '
tell application "System Events"
    tell process "ccui"
        entire contents of window 1
    end tell
end tell
'
```

## 注意事項

- screencapture にはシステム設定の「画面収録」権限が必要
- AppleScript の UI 操作にはアクセシビリティ権限が必要
- ビルドには `scripts/build.sh` を使う。出力先は `.build/` ディレクトリ
- スクリーンショットのパスは毎回上書きされる。比較が必要なら `/tmp/ccui-screenshot-<suffix>.png` のようにサフィックスをつける
