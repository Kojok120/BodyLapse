import SwiftUI
import StoreKit

struct PremiumView: View {
    @StateObject private var viewModel = PremiumViewModel()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                // 背景グラデーション
                LinearGradient(
                    gradient: Gradient(colors: [Color.bodyLapseTurquoise, Color.bodyLapseTurquoise.opacity(0.8)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // 必須 App Store情報 - 常に上部に表示
                    VStack(spacing: 10) {
                        // サブスクリプションタイトル（App Store必須） - 全言語で固定
                        Text("BodyLapse Premium")
                            .font(.title.bold())
                            .foregroundColor(.white)
                            .padding(.top, 20)
                        
                        // 価格（App Store必須） - 最も目立つ表示
                        if let product = viewModel.products.first {
                            Text(product.displayPrice + "/" + "date.month".localized)
                                .font(.largeTitle.bold())
                                .foregroundColor(.white)
                        } else {
                            Text("premium.price.fallback".localized + "/" + "date.month".localized)
                                .font(.largeTitle.bold())
                                .foregroundColor(.white)
                        }
                        
                        // サブスクリプション期間（従属的）
                        Text("premium.subscription_length".localized)
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.9))
                        
                        // リンク（App Store必須）
                        HStack(spacing: 20) {
                            Link("premium.terms".localized, destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                                .font(.footnote.bold())
                                .foregroundColor(.white)
                                .underline()
                            
                            Link("premium.privacy".localized, destination: URL(string: "https://kojok120.github.io/bodylapse-legal/privacy_policy.html")!)
                                .font(.footnote.bold())
                                .foregroundColor(.white)
                                .underline()
                        }
                        .padding(.top, 8)
                    }
                    
                    ScrollView {
                        VStack(spacing: 15) {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.yellow)
                                .padding(.top, 15)
                        
                            // 機能リスト
                            VStack(alignment: .leading, spacing: 10) {
                                CompactPremiumFeatureRowView(
                                    icon: "xmark.circle.fill",
                                    title: "premium.feature.no_ads".localized,
                                    description: "premium.feature.no_ads_desc".localized
                                )

                                CompactPremiumFeatureRowView(
                                    icon: "hand.thumbsup.fill",
                                    title: "premium.feature.support".localized,
                                    description: "premium.feature.support_desc".localized
                                )
                            }
                            .padding(.horizontal)
                            
                            Spacer(minLength: 10)
                            
                            // メイン購読ボタン
                            Button(action: {
                                Task {
                                    if let product = viewModel.products.first {
                                        await viewModel.purchase(product)
                                    } else {
                                        await viewModel.loadProducts()
                                    }
                                }
                            }) {
                                Group {
                                    if viewModel.isLoadingProducts {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                            .scaleEffect(0.8)
                                    } else {
                                        Text("premium.subscribe_now".localized)
                                            .font(.headline.bold())
                                    }
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    LinearGradient(
                                        gradient: Gradient(colors: [Color.yellow, Color.orange]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(14)
                                .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
                            }
                            .padding(.horizontal)
                            .disabled(viewModel.isPurchasing || viewModel.isLoadingProducts)
                            .scaleEffect(viewModel.isPurchasing ? 0.95 : 1.0)
                            .animation(.easeInOut(duration: 0.1), value: viewModel.isPurchasing)
                            
                            // 下部リンク - コンパクトだが読みやすく
                            VStack(spacing: 6) {
                                Button(action: {
                                    Task {
                                        await viewModel.restorePurchases()
                                    }
                                }) {
                                    Text("premium.restore".localized)
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.7))
                                        .underline()
                                }
                                .disabled(viewModel.isPurchasing)
                                
                                Text("premium.auto_renew".localized)
                                    .font(.caption2)
                                    .foregroundColor(.white.opacity(0.6))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                            }
                            .padding(.bottom, 10)
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("common.close".localized) {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
            .alert("premium.purchase_error".localized, isPresented: .constant(viewModel.purchaseError != nil)) {
                Button("common.ok".localized) {
                    viewModel.purchaseError = nil
                }
            } message: {
                Text(viewModel.purchaseError ?? "")
            }
            .overlay {
                if viewModel.isPurchasing {
                    Color.black.opacity(0.5)
                        .ignoresSafeArea()
                    ProgressView("common.processing".localized)
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(10)
                }
            }
        }
        .task {
            await viewModel.loadProducts()
        }
    }
}

// MARK: - コンパクトプレミアム機能行
struct CompactPremiumFeatureRowView: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(.white)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
                    .lineLimit(1)
            }
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.1))
        .cornerRadius(10)
    }
}

// MARK: - サブスクリプション詳細ビュー
struct SubscriptionDetailsView: View {
    let product: Product
    let action: () -> Void
    
    var body: some View {
        VStack(spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text(product.displayName)
                        .font(.subheadline)
                        .foregroundColor(.white)
                    
                    Text(product.description)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 5) {
                    Text(product.displayPrice)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    if let period = product.subscription?.subscriptionPeriod {
                        Text("\("premium.per".localized) \(period.unit.localizedDescription)")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.9))
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - プレビュー
struct PremiumView_Previews: PreviewProvider {
    static var previews: some View {
        PremiumView()
    }
}
