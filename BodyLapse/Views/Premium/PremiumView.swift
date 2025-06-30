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
                            
                            // Display price prominently with fallback
                            VStack(spacing: 5) {
                                if let product = viewModel.products.first {
                                    Text(product.displayPrice)
                                        .font(.system(size: 36, weight: .bold))
                                        .foregroundColor(.white)
                                    
                                    if let period = product.subscription?.subscriptionPeriod {
                                        Text("\("premium.per".localized) \(period.unit.localizedDescription)")
                                            .font(.body)
                                            .foregroundColor(.white.opacity(0.9))
                                    }
                                } else {
                                    // Fallback price display based on locale
                                    Text("premium.price.fallback".localized)
                                        .font(.system(size: 36, weight: .bold))
                                        .foregroundColor(.white)
                                    
                                    Text("premium.price.period".localized)
                                        .font(.body)
                                        .foregroundColor(.white.opacity(0.9))
                                }
                            }
                            .padding(.top, 10)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color.white.opacity(0.15))
                            .cornerRadius(15)
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
                        }
                        .padding(.horizontal)
                        
                        // Main Subscribe Button
                        Button(action: {
                            Task {
                                if let product = viewModel.products.first {
                                    await viewModel.purchase(product)
                                } else {
                                    await viewModel.loadProducts()
                                }
                            }
                        }) {
                            HStack {
                                if viewModel.isLoadingProducts {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                } else {
                                    Text("premium.subscribe".localized)
                                        .font(.headline)
                                        .fontWeight(.bold)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.yellow, Color.orange]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .foregroundColor(.white)
                            .cornerRadius(15)
                            .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
                        }
                        .padding(.horizontal)
                        .disabled(viewModel.isPurchasing || viewModel.isLoadingProducts)
                        .scaleEffect(viewModel.isPurchasing ? 0.95 : 1.0)
                        .animation(.easeInOut(duration: 0.1), value: viewModel.isPurchasing)
                        
                        // Subscription details (if products loaded)
                        if !viewModel.products.isEmpty && !viewModel.isLoadingProducts {
                            VStack(spacing: 15) {
                                ForEach(viewModel.products, id: \.id) { product in
                                    SubscriptionDetailsView(
                                        product: product,
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
                        
                        // Restore purchases link (smaller, less prominent)
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