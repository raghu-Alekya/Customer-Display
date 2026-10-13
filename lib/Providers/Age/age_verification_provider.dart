import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pinaka_pos/Constants/text.dart';
import 'package:pinaka_pos/Models/Search/product_by_sku_model.dart' as SKU;
import 'package:pinaka_pos/Widgets/widget_age_verification_popup_dialog.dart';

import '../../Widgets/widget_order_panel.dart';

class AgeVerificationProvider {
  /// Checks if a product is age-restricted and shows the verification dialog if it is.
  ///
  /// Returns true if the age is verified or if the product is not restricted.
  /// Returns false if the verification is cancelled or fails.
  Future<bool> ageRestrictedProduct(BuildContext context, SKU.ProductBySkuResponse product) async {
    var isVerified = false;
    isOrderInForeground = false; // hold scanning untill age verify popup is dismissed
    if (kDebugMode) {
      print("##### AgeVerificationProvider.ageRestrictedProduct: before age verification isOrderInForeground = $isOrderInForeground");
    }
    // Check if the product has the "Age Restricted" tag.
    final ageRestrictedTag = product.tags?.firstWhere(
          (element) => element.name == TextConstants.age_restricted,
      orElse: () => SKU.Tags(),
    );

    //final hasAgeRestriction = ageRestrictedTag?.name != null;
    final hasAgeRestriction = ageRestrictedTag?.name?.contains(TextConstants.age_restricted);

    if (kDebugMode) {
      print("AgeVerificationProvider.ageRestrictedProduct: Product has age restriction: $hasAgeRestriction");
    }

    if (hasAgeRestriction ?? false) {
      final minimumAgeSlug = ageRestrictedTag?.slug;
      if (minimumAgeSlug == null || minimumAgeSlug.isEmpty) {
        // If the tag exists but the minimum age (slug) is missing, deny the sale for safety.
        if (kDebugMode) {
          print("AgeVerificationProvider.ageRestrictedProduct: Age restricted tag is missing a minimum age value");
        }
        isOrderInForeground = true; // resume scanning in order panel again
        return isVerified;
      }

      // Show the age verification dialog and wait for the user's input.
      await AgeVerificationHelper.showAgeVerification(
        context: context,
        minimumAge: int.tryParse(minimumAgeSlug) ?? 0, // Default to 18 if slug is not a valid number
        onManualVerify: () {
          // Add product to cart - manually verified
          isVerified = true;
        },
        onAgeVerified: () {
          // Add product to cart - age verified
          isVerified = true;
        },
        onCancel: () {
          // User cancelled - don't add to cart
          isVerified = false;
          Navigator.pop(context);
        },
      );
    } else {
      // If there's no age restriction, the product is considered "verified".
      // No age restriction - add directly
      isVerified = true;
    }
    isOrderInForeground = true; // resume scanning in order panel again
    if (kDebugMode) {
      print("##### AgeVerificationProvider.ageRestrictedProduct: after age verification, isVerified=$isVerified, isOrderInForeground = $isOrderInForeground");
    }
    return isVerified;
  }

  Future<bool> verifyAge(BuildContext context, {int minAge = 0}) async {
    ///@
    // ANSI 636026100102DL00410277ZA03180012DLDAQD05848559 DCSBELE SHRAVAN DDEN DACKUMAR DDFNvDADNONEaDDGNrDCAD DCBNONEtDCDNONEaDBD02052025gDBB07181978gDBA09032030 DBC1=DAU070 in DAYBROpDAG233 W FELLARS DRrDAIPHOENIXoDAJAZdDAK850237501  uDCF003402EB0B124005cDCGUSAtDCK48102972534.DDAFtDDB02282023aDDD1gDAZBLKsDAW196?DDK1
    //     ZAZAAN.ZACN

    var isVerified = false;
    isOrderInForeground = false; // hold scanning untill age verify popup is dismissed
    if (kDebugMode) {
      print("##### AgeVerificationProvider.verifyAge: before age verification, hasAgeRestriction = $minAge isOrderInForeground = $isOrderInForeground");
    }

    var hasAgeRestriction = minAge != 0;
    if (hasAgeRestriction) {
      await AgeVerificationHelper.showAgeVerification(
        context: context,
        // productName: product.name,
        minimumAge: minAge,
        onManualVerify: () {
          // Add product to cart - manually verified
          // _addToCart(product);
          isVerified = true;
        },
        onAgeVerified: () {
          // Add product to cart - age verified
          // _addToCart(product);
          isVerified = true;
        },
        onCancel: () {
          // User cancelled - don't add to cart
          isVerified = false;
          Navigator.pop(context);
        },
      );
    } else {
      isVerified = true;
    }
    isOrderInForeground = true; // resume scanning in order panel again
    if (kDebugMode) {
      print("##### AgeVerificationProvider.verifyAge: after age verification, isVerified = $isVerified, isOrderInForeground = $isOrderInForeground");
    }
    return isVerified;
  }
}