import SwiftUI
import StoreKit

struct PremiumView: View {
    @StateObject private var viewModel = PremiumViewModel()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: [Color.bodyLapseTurquoise, Color.bodyLapseTurquoise.opacity(0.8)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        header

                        if viewModel.isPro {
                            activeState(title: "premium.active_pro".localized, icon: "crown.fill")
                        } else {
                            proCard
                            standardCard
                            if viewModel.isPremium {
                                Text("premium.active_standard".localized)
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.9))
                            }
                        }

                        footerLinks
                    }
                    .padding(.bottom, 20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("common.close".localized) { dismiss() }
                        .foregroundColor(.white)
                }
            }
            .alert("premium.purchase_error".localized, isPresented: .constant(viewModel.purchaseError != nil)) {
                Button("common.ok".localized) { viewModel.purchaseError = nil }
            } message: {
                Text(viewModel.purchaseError ?? "")
            }
            .overlay {
                if viewModel.isPurchasing {
                    ZStack {
                        Color.black.opacity(0.5).ignoresSafeArea()
                        ProgressView("common.processing".localized)
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(10)
                    }
                }
            }
        }
        .task {
            await viewModel.loadProducts()
        }
    }

    // MARK: - ヘッダー

    private var header: some View {
        VStack(spacing: 6) {
            Text("BodyLapse")
                .font(.title.bold())
                .foregroundColor(.white)
                .padding(.top, 16)
            Text("premium.choose_plan".localized)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.9))
        }
    }

    // MARK: - Proカード（おすすめ）

    private var proCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("premium.pro.title".localized, systemImage: "crown.fill")
                    .font(.title3.bold())
                    .foregroundColor(.white)
                Spacer()
                Text("premium.recommended".localized)
                    .font(.caption2.bold())
                    .foregroundColor(.bodyLapseTurquoise)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white)
                    .clipShape(Capsule())
            }

            featureRow(icon: "icloud.fill", text: "premium.feature.cloud".localized)
            featureRow(icon: "film.stack.fill", text: "premium.feature.advanced_video".localized)
            featureRow(icon: "rectangle.badge.xmark", text: "premium.feature.no_ads".localized)

            // 年額（プライマリ）
            planButton(
                product: viewModel.proYearlyProduct,
                period: "premium.per_year".localized,
                badge: "premium.best_value".localized,
                primary: true
            )
            // 月額（セカンダリ）
            planButton(
                product: viewModel.proMonthlyProduct,
                period: "premium.per_month".localized,
                badge: nil,
                primary: false
            )
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.18))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white, lineWidth: 1.5))
        )
        .padding(.horizontal)
    }

    // MARK: - Standardカード

    private var standardCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("premium.standard.title".localized)
                .font(.headline)
                .foregroundColor(.white)
            featureRow(icon: "rectangle.badge.xmark", text: "premium.feature.no_ads".localized)
            planButton(
                product: viewModel.standardProduct,
                period: "premium.per_month".localized,
                badge: nil,
                primary: false
            )
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.1))
        )
        .padding(.horizontal)
    }

    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(.white)
                .frame(width: 24)
            Text(text)
                .font(.subheadline)
                .foregroundColor(.white)
            Spacer()
        }
    }

    /// 価格ボタン。productがあればストアの実価格を表示。未取得時は固定価格を出さず「取得中」表記にする。
    private func planButton(product: Product?, period: String, badge: String?, primary: Bool) -> some View {
        Button {
            Task {
                if let product {
                    await viewModel.purchase(product)
                } else {
                    await viewModel.loadProducts()
                }
            }
        } label: {
            HStack {
                if let badge {
                    Text(badge)
                        .font(.caption2.bold())
                        .foregroundColor(primary ? .orange : .white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(primary ? Color.white : Color.white.opacity(0.2))
                        .clipShape(Capsule())
                }
                Spacer()
                if let product {
                    Text(product.displayPrice + " / " + period)
                        .font(.headline.bold())
                } else {
                    Text("premium.price.unavailable".localized)
                        .font(.subheadline.bold())
                }
                Spacer()
            }
            .foregroundColor(primary ? .white : .white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                Group {
                    if primary {
                        LinearGradient(colors: [Color.yellow, Color.orange], startPoint: .leading, endPoint: .trailing)
                    } else {
                        Color.white.opacity(0.18)
                    }
                }
            )
            .cornerRadius(12)
        }
        .disabled(viewModel.isPurchasing || viewModel.isLoadingProducts)
    }

    // MARK: - 加入済み表示

    private func activeState(title: String, icon: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 50))
                .foregroundColor(.yellow)
            Text(title)
                .font(.title3.bold())
                .foregroundColor(.white)
            Button {
                if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                    UIApplication.shared.open(url)
                }
            } label: {
                Text("settings.manage_subscription".localized)
                    .font(.subheadline.bold())
                    .foregroundColor(.bodyLapseTurquoise)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.white)
                    .cornerRadius(12)
            }
        }
        .padding(.vertical, 30)
    }

    // MARK: - フッター（App Store必須情報）

    private var footerLinks: some View {
        VStack(spacing: 8) {
            Button {
                Task { await viewModel.restorePurchases() }
            } label: {
                Text("premium.restore".localized)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
                    .underline()
            }
            .disabled(viewModel.isPurchasing)

            HStack(spacing: 20) {
                Link("premium.terms".localized, destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                Link("premium.privacy".localized, destination: URL(string: "https://kojok120.github.io/bodylapse-legal/privacy_policy.html")!)
            }
            .font(.footnote)
            .foregroundColor(.white)
            .underline()

            Text("premium.auto_renew".localized)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding(.top, 8)
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
