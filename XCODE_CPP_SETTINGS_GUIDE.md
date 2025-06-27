# XcodeでC++設定を行う詳細手順

## 手順4: C++設定の詳細

### 1. Xcodeでプロジェクトを開く
```bash
open BodyLapse.xcodeproj
```

### 2. ターゲットを選択
1. Xcodeの左側のナビゲーターで、一番上の「BodyLapse」（青いアイコン）をクリック
2. 中央のエディタエリアで「TARGETS」の下にある「BodyLapse」を選択

### 3. Build Settingsタブに移動
1. 上部のタブバーから「Build Settings」をクリック
2. 「Basic」と「All」のボタンがある場合は「All」を選択
3. 「Combined」と「Levels」のボタンがある場合は「Combined」を選択

### 4. C++ Standard Libraryの設定
1. 右上の検索バーに「C++ Standard Library」と入力
2. 「Apple Clang - Language - C++」セクションの下に「C++ Standard Library」が表示される
3. その行の右側をクリックして、ドロップダウンメニューから「libc++ (LLVM C++ standard library)」を選択

### 5. Enable Modulesの設定
1. 検索バーをクリアして、「Enable Modules」と入力
2. 「Apple Clang - Language - Modules」セクションの下に「Enable Modules (C and Objective-C)」が表示される
3. その行の右側をクリックして「Yes」に設定（チェックマークが付く）

### 6. その他の必要な設定

#### Objective-C++ Automatic Reference Counting
1. 検索バーに「Objective-C++ Automatic Reference Counting」と入力
2. 「Yes」に設定されていることを確認

#### C++ Language Dialect
1. 検索バーに「C++ Language Dialect」と入力
2. 「GNU++17」または「C++17」が選択されていることを確認

## 設定の確認方法

1. すべての設定が完了したら、左上の「▶」ボタンまたは Cmd+B でビルドを実行
2. エラーが発生しなければ設定は成功

## よくある問題と解決方法

### 問題1: 設定項目が見つからない
- 「All」と「Combined」が選択されていることを確認
- 検索時にスペルミスがないか確認

### 問題2: 設定を変更してもビルドエラーが続く
1. Xcode メニューから「Product」→「Clean Build Folder」（Shift+Cmd+K）
2. DerivedDataを削除:
   - Xcode → Settings → Locations → DerivedData の右の矢印をクリック
   - DerivedDataフォルダを削除
3. Xcodeを再起動してビルド

### 問題3: OpenCVのヘッダーファイルが見つからない
1. Framework Search Pathsが正しく設定されているか確認
2. opencv2.frameworkが「Embed & Sign」になっているか確認

## スクリーンショットでの確認ポイント

1. **Build Settings画面**:
   - 上部で「All」と「Combined」が選択されている
   - 検索バーが表示されている

2. **C++ Standard Library設定**:
   - 「libc++ (LLVM C++ standard library)」が選択されている

3. **Enable Modules設定**:
   - 「Yes」にチェックマークが付いている

これらの設定により、OpenCVのC++コードを含むObjective-C++ファイル（.mm）が正しくコンパイルされます。