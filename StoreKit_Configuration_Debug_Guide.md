# StoreKit Configuration Debug Guide

## Issue
The StoreKit configuration file exists but products are not loading, showing "No active subscriptions found" even though the configuration appears correct.

## Debug Logging Added
I've added comprehensive debug logging to help diagnose the issue:

1. **StoreKit.swift** - Added logging for:
   - Bundle ID verification
   - Product request details
   - Success/failure states with detailed error information
   - Warning messages when no products are returned

2. **SubscriptionManagerService.swift** - Added logging for:
   - Service initialization
   - Product loading process
   - Transaction verification
   - Subscription status updates

3. **BodyLapseApp.swift** - Added logging for:
   - App launch initialization
   - Product loading completion
   - Subscription status after refresh

4. **DebugSettingsView.swift** - Added StoreKit diagnostics section showing:
   - Bundle ID
   - Number of products loaded
   - Product details (if any)
   - Reload products button
   - Error messages

## Steps to Debug

### 1. Check Console Output
Run the app and look for these log messages in the console:
```
[BodyLapseApp] App launched - initializing StoreKit...
[SubscriptionManager] Initializing SubscriptionManagerService...
[StoreKit] StoreManager initialized
[StoreKit] Starting to load products...
[StoreKit] Bundle ID: com.J.BodyLapse
[StoreKit] Requesting products with IDs: [com.J.BodyLapse.premium.monthly]
```

### 2. Common Issues and Solutions

#### Issue: No products returned (0 products loaded)
**Possible causes:**
1. **StoreKit configuration not added to project target**
   - In Xcode, select the `BodyLapse.storekit` file
   - Check the Target Membership in the right panel
   - Ensure "BodyLapse" target is checked

2. **StoreKit configuration not set in scheme**
   - Edit Scheme → Run → Options
   - Set StoreKit Configuration to "BodyLapse.storekit"

3. **Running on device instead of simulator**
   - StoreKit configuration files only work in the simulator
   - For device testing, you need sandbox testing with App Store Connect

#### Issue: Product IDs mismatch
**Debug output will show:**
```
[StoreKit] WARNING: No products returned from App Store
[StoreKit] This could mean:
[StoreKit] 1. StoreKit configuration file is not properly set up
[StoreKit] 2. Product IDs don't match between code and App Store Connect
```

**Solution:**
- Verify product ID in code: `com.J.BodyLapse.premium.monthly`
- Matches StoreKit configuration: ✓ (confirmed in file)
- If testing on device, ensure product is created in App Store Connect

### 3. Using Debug Settings

1. Open Settings → Debug Settings in the app
2. Check the "StoreKit Diagnostics" section:
   - Bundle ID should be: `com.J.BodyLapse`
   - Products Loaded should show: 1 (if working)
   - Product details should display the premium subscription

3. Tap "Reload Products" to manually trigger product loading
4. Watch for error messages in the diagnostics section

### 4. Xcode Setup Checklist

- [ ] BodyLapse.storekit file is added to project navigator
- [ ] Target membership is set for BodyLapse target
- [ ] Scheme is configured to use StoreKit configuration
- [ ] Running in simulator (not device) for testing
- [ ] Deployment target is iOS 17.0 or later

### 5. Testing Purchases

Once products load successfully:
1. Use Debug Settings to test as free/premium user
2. Or attempt a real purchase in the simulator
3. Check subscription status in Debug Settings

## Next Steps

1. Run the app and check console output
2. Go to Settings → Debug Settings → StoreKit Diagnostics
3. If no products load, follow the Xcode Setup Checklist
4. If products load but purchases fail, check for additional error messages

The debug logging will provide specific information about what's failing in the StoreKit pipeline.