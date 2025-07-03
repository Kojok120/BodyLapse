import SwiftUI
import StoreKit

struct PremiumView: View {
    @StateObject private var viewModel = PremiumViewModel()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                LinearGradient(
                    gradient: Gradient(colors: [Color.bodyLapseTurquoise, Color.bodyLapseTurquoise.opacity(0.8)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 12) {
                    // Header with Free Trial Badge
                    VStack(spacing: 8) {
                        // Free Trial Badge - PROMINENT
                        HStack {
                            Image(systemName: "gift.fill")
                                .font(.title2)
                            Text("premium.first_month_free".localized)
                                .font(.title3.bold())
                        }
                        .foregroundColor(.black)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(Color.yellow)
                                .shadow(color: .yellow.opacity(0.5), radius: 10, x: 0, y: 5)
                        )
                        .padding(.top, 10)
                        
                        Image(systemName: "crown.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.yellow)
                        
                        // Subscription title (REQUIRED by App Store)
                        Text("premium.title".localized)
                            .font(.headline.bold())
                            .foregroundColor(.white)
                        
                        // Subscription length and price (REQUIRED by App Store)
                        VStack(spacing: 4) {
                            Text("premium.subscription_length".localized)
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.9))
                            
                            HStack(spacing: 6) {
                                if let product = viewModel.products.first {
                                    Text(product.displayPrice + "/" + "date.month".localized)
                                        .font(.title3.bold())
                                        .foregroundColor(.white)
                                } else {
                                    Text("premium.price.fallback".localized)
                                        .font(.title3.bold())
                                        .foregroundColor(.white)
                                }
                                
                                Text("(" + "premium.after_trial".localized + ")")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                        }
                    }
                        
                    // Features list - balanced size
                    VStack(alignment: .leading, spacing: 10) {
                        CompactPremiumFeatureRowView(
                            icon: "chart.line.uptrend.xyaxis",
                            title: "premium.feature.tracking".localized,
                            description: "premium.feature.tracking_desc".localized
                        )
                        
                        CompactPremiumFeatureRowView(
                            icon: "photo.stack",
                            title: "premium.feature.advanced_tracking".localized,
                            description: "premium.feature.advanced_tracking_desc".localized
                        )
                        
                        CompactPremiumFeatureRowView(
                            icon: "xmark.circle.fill",
                            title: "premium.feature.no_ads".localized,
                            description: "premium.feature.no_ads_desc".localized
                        )
                        
                        CompactPremiumFeatureRowView(
                            icon: "drop.fill",
                            title: "premium.feature.no_watermark".localized,
                            description: "premium.feature.no_watermark_desc".localized
                        )
                    }
                    .padding(.horizontal)
                        
                    Spacer(minLength: 10)
                    
                    // Main Subscribe Button with Free Trial emphasis
                    Button(action: {
                        Task {
                            if let product = viewModel.products.first {
                                await viewModel.purchase(product)
                            } else {
                                await viewModel.loadProducts()
                            }
                        }
                    }) {
                        VStack(spacing: 6) {
                            if viewModel.isLoadingProducts {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                Text("premium.start_free_trial".localized)
                                    .font(.headline.bold())
                                Text("premium.then_per_month".localized)
                                    .font(.caption)
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
                        
                    // Bottom links - compact but readable
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
                        
                        // Terms and Privacy (REQUIRED by App Store)
                        HStack(spacing: 20) {
                            Link("premium.terms".localized, destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                            Link("premium.privacy".localized, destination: URL(string: "https://kojok120.github.io/bodylapse-legal/privacy_policy.html")!)
                        }
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                    }
                    .padding(.bottom, 10)
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

// MARK: - Compact Premium Feature Row
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

// MARK: - Subscription Details View
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

// MARK: - Preview
struct PremiumView_Previews: PreviewProvider {
    static var previews: some View {
        PremiumView()
    }
}