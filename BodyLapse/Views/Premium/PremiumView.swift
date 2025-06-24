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
                            
                            Text("BodyLapse Premium")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            Text("Unlock all features and track your journey")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.9))
                        }
                        .padding(.top, 40)
                        
                        // Features list
                        VStack(alignment: .leading, spacing: 20) {
                            PremiumFeatureRowView(
                                icon: "chart.line.uptrend.xyaxis",
                                title: "Weight & Body Fat Tracking",
                                description: "Track your progress with detailed charts"
                            )
                            
                            PremiumFeatureRowView(
                                icon: "xmark.circle.fill",
                                title: "No Ads",
                                description: "Enjoy an ad-free experience"
                            )
                            
                            PremiumFeatureRowView(
                                icon: "drop.fill",
                                title: "No Watermark",
                                description: "Export videos without watermark"
                            )
                            
                            PremiumFeatureRowView(
                                icon: "bell.badge.fill",
                                title: "Advanced Reminders",
                                description: "Customize notification times"
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
                            Text("Restore Purchases")
                                .foregroundColor(.white.opacity(0.8))
                                .underline()
                        }
                        .disabled(viewModel.isPurchasing)
                        
                        // Terms and Privacy
                        VStack(spacing: 10) {
                            Text("Subscriptions will automatically renew unless cancelled")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.6))
                                .multilineTextAlignment(.center)
                            
                            HStack(spacing: 20) {
                                Link("Terms of Service", destination: URL(string: "https://example.com/terms")!)
                                Link("Privacy Policy", destination: URL(string: "https://example.com/privacy")!)
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
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
            .alert("Purchase Error", isPresented: .constant(viewModel.purchaseError != nil)) {
                Button("OK") {
                    viewModel.purchaseError = nil
                }
            } message: {
                Text(viewModel.purchaseError ?? "")
            }
            .overlay {
                if viewModel.isPurchasing {
                    Color.black.opacity(0.5)
                        .ignoresSafeArea()
                    ProgressView("Processing...")
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
            return "Save 17%"
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
                            Text("per \(period.unit.localizedDescription)")
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