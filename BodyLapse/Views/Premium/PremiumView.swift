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
                    gradient: Gradient(colors: [Color.purple.opacity(0.8), Color.blue.opacity(0.8)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 30) {
                        // Header
                        VStack(spacing: 15) {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.yellow)
                            
                            Text("premium.title".localized)
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            Text("premium.subtitle".localized)
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.9))
                        }
                        .padding(.top, 40)
                        
                        // Features list
                        VStack(alignment: .leading, spacing: 20) {
                            PremiumFeatureRowView(
                                icon: "chart.line.uptrend.xyaxis",
                                title: "premium.feature.tracking".localized,
                                description: "premium.feature.tracking_desc".localized
                            )
                            
                            PremiumFeatureRowView(
                                icon: "xmark.circle.fill",
                                title: "premium.feature.no_ads".localized,
                                description: "premium.feature.no_ads_desc".localized
                            )
                            
                            PremiumFeatureRowView(
                                icon: "drop.fill",
                                title: "premium.feature.no_watermark".localized,
                                description: "premium.feature.no_watermark_desc".localized
                            )
                            
                            PremiumFeatureRowView(
                                icon: "bell.badge.fill",
                                title: "premium.feature.reminders".localized,
                                description: "premium.feature.reminders_desc".localized
                            )
                        }
                        .padding(.horizontal)
                        
                        // Subscription options
                        if viewModel.isLoadingProducts {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(1.5)
                                .padding()
                        } else {
                            VStack(spacing: 15) {
                                ForEach(viewModel.products, id: \.id) { product in
                                    SubscriptionOptionView(
                                        product: product,
                                        isSelected: false,
                                        action: {
                                            Task {
                                                await viewModel.purchase(product)
                                            }
                                        }
                                    )
                                    .disabled(viewModel.isPurchasing)
                                }
                            }
                            .padding(.horizontal)
                        }
                        
                        // Restore purchases button
                        Button(action: {
                            Task {
                                await viewModel.restorePurchases()
                            }
                        }) {
                            Text("premium.restore".localized)
                                .foregroundColor(.white.opacity(0.8))
                                .underline()
                        }
                        .disabled(viewModel.isPurchasing)
                        
                        // Terms and Privacy
                        VStack(spacing: 10) {
                            Text("premium.auto_renew".localized)
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.6))
                                .multilineTextAlignment(.center)
                            
                            HStack(spacing: 20) {
                                Link("premium.terms".localized, destination: URL(string: "https://example.com/terms")!)
                                Link("premium.privacy".localized, destination: URL(string: "https://example.com/privacy")!)
                            }
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 30)
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

// MARK: - Premium Feature Row
struct PremiumFeatureRowView: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.white)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
            }
            
            Spacer()
        }
        .padding()
        .background(Color.white.opacity(0.1))
        .cornerRadius(15)
    }
}

// MARK: - Subscription Option View
struct SubscriptionOptionView: View {
    let product: Product
    let isSelected: Bool
    let action: () -> Void
    
    private var savings: String? {
        if product.id.contains("yearly") {
            return "premium.save_percent".localized
        }
        return nil
    }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(product.displayName)
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Text(product.description)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 5) {
                        Text(product.displayPrice)
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        if let period = product.subscription?.subscriptionPeriod {
                            Text("\("premium.per".localized) \(period.unit.localizedDescription)")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                }
                
                if let savings = savings {
                    Text(savings)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.green.opacity(0.2))
                        .cornerRadius(10)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 15)
                    .fill(Color.white.opacity(0.2))
                    .overlay(
                        RoundedRectangle(cornerRadius: 15)
                            .stroke(isSelected ? Color.yellow : Color.clear, lineWidth: 2)
                    )
            )
        }
    }
}

// MARK: - Preview
struct PremiumView_Previews: PreviewProvider {
    static var previews: some View {
        PremiumView()
    }
}