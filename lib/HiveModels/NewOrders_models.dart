// orders_response.dart
class OrdersResponse {
  final int orderTotalCount;
  final int page;
  final int perPage;
  final List<OrderData> ordersData;

  OrdersResponse({
    required this.orderTotalCount,
    required this.page,
    required this.perPage,
    required this.ordersData,
  });

  factory OrdersResponse.fromJson(Map<String, dynamic> json) {
    return OrdersResponse(
      orderTotalCount: json['order_total_count'] ?? 0,
      page: json['page'] ?? 0,
      perPage: json['per_page'] ?? 0,
      ordersData: (json['orders_data'] as List? ?? [])
          .map((e) => OrderData.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}

class OrderData {
  final int id;
  final String status;
  final String dateCreated;
  final String dateModified;
  final String currency;
  final bool pricesIncludeTax;
  final String discountTotal;
  final String discountTax;
  final String shippingTotal;
  final String shippingTax;
  final String cartTax;
  final String total;
  final String totalTax;
  final String orderKey;
  final String? paymentMethod;
  final String? paymentMethodTitle;
  final String? transactionId;
  final String createdVia;
  final String author;
  final String? dateCompleted;
  final String? datePaid;
  final String number;
  final List<CouponLine> couponLines;
  final List<LineItem> lineItems;
  final List<dynamic> feeLines;
  final List<dynamic> refunds;

  OrderData({
    required this.id,
    required this.status,
    required this.dateCreated,
    required this.dateModified,
    required this.currency,
    required this.pricesIncludeTax,
    required this.discountTotal,
    required this.discountTax,
    required this.shippingTotal,
    required this.shippingTax,
    required this.cartTax,
    required this.total,
    required this.totalTax,
    required this.orderKey,
    this.paymentMethod,
    this.paymentMethodTitle,
    this.transactionId,
    required this.createdVia,
    required this.author,
    this.dateCompleted,
    this.datePaid,
    required this.number,
    required this.couponLines,
    required this.lineItems,
    required this.feeLines,
    required this.refunds,
  });

  factory OrderData.fromJson(Map<String, dynamic> json) {
    return OrderData(
      id: json['id'] ?? 0,
      status: json['status'] ?? "",
      dateCreated: json['date_created'] ?? "",
      dateModified: json['date_modified'] ?? "",
      currency: json['currency'] ?? "",
      pricesIncludeTax: json['prices_include_tax'] ?? false,
      discountTotal: json['discount_total'] ?? "0",
      discountTax: json['discount_tax'] ?? "0",
      shippingTotal: json['shipping_total'] ?? "0",
      shippingTax: json['shipping_tax'] ?? "0",
      cartTax: json['cart_tax'] ?? "0",
      total: json['total'] ?? "0",
      totalTax: json['total_tax'] ?? "0",
      orderKey: json['order_key'] ?? "",
      paymentMethod: json['payment_method'],
      paymentMethodTitle: json['payment_method_title'],
      transactionId: json['transaction_id'],
      createdVia: json['created_via'] ?? "",
      author: json['author'] ?? "",
      dateCompleted: json['date_completed'],
      datePaid: json['date_paid'],
      number: json['number'] ?? "",
      couponLines: (json['coupon_lines'] as List? ?? [])
          .map((e) => CouponLine.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      lineItems: (json['line_items'] as List? ?? [])
          .map((e) => LineItem.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      feeLines: json['fee_lines'] as List? ?? [],
      refunds: json['refunds'] as List? ?? [],
    );
  }
}

class CouponLine {
  final int id;
  final String code;
  final String discount;
  final String discountTax;
  final String discountType;
  final int nominalAmount;
  final bool freeShipping;

  CouponLine({
    required this.id,
    required this.code,
    required this.discount,
    required this.discountTax,
    required this.discountType,
    required this.nominalAmount,
    required this.freeShipping,
  });

  factory CouponLine.fromJson(Map<String, dynamic> json) {
    return CouponLine(
      id: json['id'] ?? 0,
      code: json['code'] ?? "",
      discount: json['discount'] ?? "0",
      discountTax: json['discount_tax'] ?? "0",
      discountType: json['discount_type'] ?? "",
      nominalAmount: json['nominal_amount'] ?? 0,
      freeShipping: json['free_shipping'] ?? false,
    );
  }
}

class LineItem {
  final int id;
  final String name;
  final int productId;
  final int variationId;
  final int quantity;
  final String subtotal;
  final String subtotalTax;
  final String total;
  final String totalTax;
  final Map<String, dynamic>? taxes;
  final ImageData? image;
  final List<MetaData> metaData;
  final ProductData? productData;

  LineItem({
    required this.id,
    required this.name,
    required this.productId,
    required this.variationId,
    required this.quantity,
    required this.subtotal,
    required this.subtotalTax,
    required this.total,
    required this.totalTax,
    this.taxes,
    this.image,
    required this.metaData,
    this.productData,
  });

  factory LineItem.fromJson(Map<String, dynamic> json) {
    return LineItem(
      id: json['id'] ?? 0,
      name: json['name'] ?? "",
      productId: json['product_id'] ?? 0,
      variationId: json['variation_id'] ?? 0,
      quantity: json['quantity'] ?? 0,
      subtotal: json['subtotal'] ?? "0",
      subtotalTax: json['subtotal_tax'] ?? "0",
      total: json['total'] ?? "0",
      totalTax: json['total_tax'] ?? "0",
      taxes: json['taxes'] != null
          ? Map<String, dynamic>.from(json['taxes'])
          : null,
      image:
      json['image'] != null ? ImageData.fromJson(json['image']) : null,
      metaData: (json['meta_data'] as List? ?? [])
          .map((e) => MetaData.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      productData: json['product_data'] != null
          ? ProductData.fromJson(Map<String, dynamic>.from(json['product_data']))
          : null,
    );
  }
}

class ProductData {
  final int id;
  final String name;
  final String slug;
  final String permalink;
  final String price;
  final String regularPrice;
  final String? salePrice;
  final bool onSale;
  final bool purchasable;
  final List<Category> categories;
  final List<ImageData> images;

  ProductData({
    required this.id,
    required this.name,
    required this.slug,
    required this.permalink,
    required this.price,
    required this.regularPrice,
    this.salePrice,
    required this.onSale,
    required this.purchasable,
    required this.categories,
    required this.images,
  });

  factory ProductData.fromJson(Map<String, dynamic> json) {
    return ProductData(
      id: json['id'] ?? 0,
      name: json['name'] ?? "",
      slug: json['slug'] ?? "",
      permalink: json['permalink'] ?? "",
      price: json['price'] ?? "0",
      regularPrice: json['regular_price'] ?? "0",
      salePrice: json['sale_price'],
      onSale: json['on_sale'] ?? false,
      purchasable: json['purchasable'] ?? false,
      categories: (json['categories'] as List? ?? [])
          .map((e) => Category.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      images: (json['images'] as List? ?? [])
          .map((e) => ImageData.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}

class Category {
  final int id;
  final String name;
  final String slug;

  Category({required this.id, required this.name, required this.slug});

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] ?? 0,
      name: json['name'] ?? "",
      slug: json['slug'] ?? "",
    );
  }
}

class ImageData {
  final int id;
  final String src;
  final String? name;
  final String? alt;

  ImageData({required this.id, required this.src, this.name, this.alt});

  factory ImageData.fromJson(Map<String, dynamic> json) {
    return ImageData(
      id: json['id'] ?? 0,
      src: json['src'] ?? "",
      name: json['name'],
      alt: json['alt'],
    );
  }
}

class MetaData {
  final int id;
  final String key;
  final dynamic value;

  MetaData({required this.id, required this.key, this.value});

  factory MetaData.fromJson(Map<String, dynamic> json) {
    return MetaData(
      id: json['id'] ?? 0,
      key: json['key'] ?? "",
      value: json['value'],
    );
  }
}
