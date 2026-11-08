import SwiftUI

extension Color {
    // 新デザインのプライマリーカラー。
    // 元の #00AFCC は白との対比が 2.62:1 しかなく、白い文字を載せたボタンやチップ、白地の文字が読みにくかった。
    // 白地の文字・白文字の地・黒地の文字のどれでも 4.5:1 を超える #007F99 にする (アイコンと起動画面の色はそのまま)
    static let bodyLapseTurquoise = Color(red: 0.0, green: 0.498, blue: 0.6) // #007F99
    static let bodyLapseYellow = Color(red: 1.0, green: 0.843, blue: 0.0) // #FFD700
    static let bodyLapseLightGray = Color(red: 0.961, green: 0.961, blue: 0.961) // #F5F5F5
}
