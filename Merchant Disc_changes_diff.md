# Git Diff of Changes in order_summary_screen.dart

Here are the exact changes (additions and deletions) made to [order_summary_screen.dart](file:///c:/Projects/Customer-Display_Convenience_V2/lib/Screens/Home/order_summary_screen.dart).

```diff
--- lib/Screens/Home/order_summary_screen.dart
+++ lib/Screens/Home/order_summary_screen.dart
@@ -3269,6 +3269,18 @@
     totalTax = double.parse(totalTax.toStringAsFixed(4));
 
+    // Recalculate percentage merchant discount dynamically based on Gross Total (coupon has no impact)
+    final String mdType =
+        offlineOrder?['merchantDiscountType']?.toString() ?? 'fixed';
+    if (mdType == 'percentage' && merchantDiscountPercentage > 0) {
+      double base = totalLineGross - totalLineDiscount;
+      if (base > 0) {
+        merchantDiscount = -((base * merchantDiscountPercentage) / 100.0);
+      } else {
+        merchantDiscount = 0.0;
+      }
+    }
+
     final double serverTax = widget.orderTax;
 
     final double netAfterDiscount =
@@ -3275,15 +3287,17 @@
     double finalTax;
 
     if (!anyItemHasDiscountOrTaxRate) {
-      // ── ONLY scale tax by coupon ratio when coupon was applied in THIS session.
-      // For pending/reloaded orders, isCouponAppliedFromApi is false,
-      // so we skip scaling and return the server tax as-is (e.g. $6.36).
-      if (serverTax > 0 && discount < 0 && isCouponAppliedFromApi) {
-        final double originalGross = widget.grossTotal;
+      // ── Scale tax by coupon/merchant discount ratio when coupon was applied in THIS session or merchant discount is active.
+      if (serverTax > 0 && (discount < 0 || merchantDiscount < 0)) {
+        final double originalGross = widget.grossTotal > 0 ? widget.grossTotal : (totalLineGross - totalLineDiscount);
         if (originalGross > 0) {
+          final double baseForTaxScaling = isCouponAppliedFromApi
+              ? originalGross
+              : (originalGross + discount).clamp(0.01, double.infinity);
           final double taxableNet =
-              (originalGross + discount).clamp(0.0, double.infinity);
-          finalTax = serverTax * (taxableNet / originalGross);
+              (originalGross + discount + merchantDiscount).clamp(0.0, double.infinity);
+          finalTax = serverTax * (taxableNet / baseForTaxScaling);
+          finalTax = roundTaxHalfUp(finalTax);
         } else {
           finalTax = 0.0;
         }
@@ -3303,16 +3317,15 @@
             '── TAX: Recalc=0, server=$serverTax, net=$netAfterDiscount → finalTax=$finalTax');
       }
     } else {
-      if (discount < 0 && totalLineGross > 0) {
-        final double postCouponBase =
-            (totalLineGross - totalLineDiscount + discount)
-                .clamp(0.0, double.infinity);
-        final double preCouponBase =
-            (totalLineGross - totalLineDiscount).clamp(0.01, double.infinity);
-        totalTax = totalTax * (postCouponBase / preCouponBase);
+      final double originalBase = totalLineGross - totalLineDiscount;
+      if (originalBase > 0) {
+        final double finalBase =
+            (originalBase + discount + merchantDiscount).clamp(0.0, double.infinity);
+        totalTax = totalTax * (finalBase / originalBase);
         totalTax = double.parse(totalTax.toStringAsFixed(4));
       }
       finalTax = totalTax;
+      finalTax = roundTaxHalfUp(finalTax);
       if (kDebugMode) {
         print('── TAX: Using recalculated value: $finalTax');
       }
@@ -3328,45 +3341,7 @@
       print('   Final Tax Used     : $finalTax');
     }
 
-    // Recalculate percentage merchant discount dynamically
-    final String mdType =
-        offlineOrder?['merchantDiscountType']?.toString() ?? 'fixed';
-    if (mdType == 'percentage' && merchantDiscountPercentage > 0) {
-      double base = totalLineGross - totalLineDiscount + discount;
-      if (base > 0) {
-        merchantDiscount = -((base * merchantDiscountPercentage) / 100.0);
-      } else {
-        merchantDiscount = 0.0;
-      }
-    }
-
-    double calculatedPerc = 0.0;
-    if (mdType == 'percentage' && merchantDiscountPercentage > 0) {
-      calculatedPerc = merchantDiscountPercentage;
-    } else if (mdType == 'fixed' && merchantDiscount.abs() > 0) {
-      double base = totalLineGross - totalLineDiscount + discount;
-      if (base > 0) {
-        calculatedPerc = (merchantDiscount.abs() / base) * 100.0;
-      }
-    }
-
-    if (calculatedPerc > 0) {
-      finalTax = finalTax * (1 - calculatedPerc / 100.0);
-      finalTax = roundTaxHalfUp(finalTax);
-    }
-
-    // final double newNetTotal = grossTotal + discount + merchantDiscount;
-
-    
-    // ✅ CORRECT: NetTotal should be Gross + Coupon/Order Discount ONLY
-    // Merchant Discount is shown separately after NetTotal
-    ////final double newNetTotal = grossTotal + discount;
-
-    ////final double newNetPayable = newNetTotal + finalTax + cashbackFee + merchantDiscount;
-    
-
-    ////Raghu--**
-    ///Merchant discount again added to NetTotal
+    // ✅ NetTotal should be Gross + Coupon/Order Discount + Merchant Discount
     final double newNetTotal = grossTotal + discount + merchantDiscount;
 
     final double newNetPayable = newNetTotal + finalTax + cashbackFee;

@@ -3737,7 +3712,7 @@
         grossTotal: grossTotal,
         discount: discount,
         merchantDiscount: merchantDiscount,
-        netTotal: grossTotal - discount.abs(), // Net before merchant discount
+        netTotal: NetTotal,
         tax: tax,
         netPayable: computedNetPayable,

@@ -6332,8 +6307,7 @@
 
                                 merchantDiscount: merchantDiscount,
 
-                                // ✅ FIX NET TOTAL
-                                netTotal: grossTotal - discount.abs(),
+                                netTotal: NetTotal,
 
                                 tax: tax,

@@ -10189,7 +10163,7 @@
 
       // ================= FINAL TOTAL RECALC =================
       setState(() {
-        NetTotal = grossTotal + discount ;   ////bala
+        NetTotal = grossTotal + discount + merchantDiscount;
 
         computedNetPayable = NetTotal + tax + cashbackFee;

@@ -10265,7 +10239,7 @@
 
         merchantDiscount: merchantDiscount,
 
-        netTotal: grossTotal - discount.abs(),
+        netTotal: NetTotal,
 
         tax: tax,

@@ -10626,7 +10600,7 @@
         tax = newTax;
 
         // Recalculate NetTotal and computedNetPayable with same formula
-        NetTotal = grossTotal + discount;
+        NetTotal = grossTotal + discount + merchantDiscount;
         computedNetPayable = NetTotal + tax + cashbackFee;
         orderTotal = newTotal;
         balanceAmount = computedNetPayable - tenderAmount;
@@ -10652,7 +10626,7 @@
 
       // ✅ Final recalculation
       setState(() {
-        NetTotal = grossTotal + discount;
+        NetTotal = grossTotal + discount + merchantDiscount;
         computedNetPayable = NetTotal + tax + cashbackFee;
         orderTotal = computedNetPayable;
         balanceAmount = computedNetPayable - tenderAmount;
@@ -10675,7 +10649,7 @@
           grossTotal: grossTotal,
           discount: discount,
           merchantDiscount: merchantDiscount,
-          netTotal: grossTotal - discount.abs(),
+          netTotal: NetTotal,
           tax: tax,
           netPayable: computedNetPayable,

@@ -10738,8 +10712,8 @@
     final String mdType = offlineOrder?['merchantDiscountType']?.toString() ?? 'fixed';
     final num mdPercentage = offlineOrder?['merchantDiscountPercentage'] as num? ?? merchantDiscountPercentage;
 
-    // Calculate current base (Gross + Coupon/Order Discount)
-    final double baseAmount = grossTotal + discount;
+    // Calculate current base (Gross)
+    final double baseAmount = grossTotal;
 
     if (mdType == 'percentage' && mdPercentage > 0) {
       // Recalculate merchant discount based on new base amount
@@ -10746,7 +10720,7 @@
 
       if (kDebugMode) {
         print('🔄 Recalculating merchant discount:');
-        print('   Base Amount (Gross + Coupon): $baseAmount');
+        print('   Base Amount (Gross): $baseAmount');
         print('   Percentage: $mdPercentage%');
         print('   New Merchant Discount: $newMerchantDiscount');
         print('   Old Merchant Discount: $merchantDiscount');
```
