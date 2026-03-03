class MpPreference {
  final String? additionalInfo;
  final String? autoReturn;
  final MpBackUrls? backUrls;
  final bool? binaryMode;
  final String? clientId;
  final int? collectorId;
  final String? couponCode;
  final dynamic couponLabels;
  final DateTime? dateCreated;
  final DateTime? dateOfExpiration;
  final DateTime? expirationDateFrom;
  final DateTime? expirationDateTo;
  final bool? expires;
  final String? externalReference;
  final String? id;
  final String? initPoint;
  final dynamic internalMetadata;
  final List<MpItem> items;
  final String? marketplace;
  final num? marketplaceFee;
  final Map<String, dynamic>? metadata;
  final String? notificationUrl;
  final String? operationType;
  final MpPayer? payer;
  final MpPaymentMethods? paymentMethods;
  final dynamic processingModes;
  final dynamic productId;
  final bool? preferenceExpired;
  final MpBackUrls? redirectUrls;
  final String? sandboxInitPoint;
  final String? siteId;
  final MpShipments? shipments;
  final num? totalAmount;
  final DateTime? lastUpdated;
  final String? financingGroup;

  const MpPreference({
    this.additionalInfo,
    this.autoReturn,
    this.backUrls,
    this.binaryMode,
    this.clientId,
    this.collectorId,
    this.couponCode,
    this.couponLabels,
    this.dateCreated,
    this.dateOfExpiration,
    this.expirationDateFrom,
    this.expirationDateTo,
    this.expires,
    this.externalReference,
    this.id,
    this.initPoint,
    this.internalMetadata,
    this.items = const [],
    this.marketplace,
    this.marketplaceFee,
    this.metadata,
    this.notificationUrl,
    this.operationType,
    this.payer,
    this.paymentMethods,
    this.processingModes,
    this.productId,
    this.preferenceExpired,
    this.redirectUrls,
    this.sandboxInitPoint,
    this.siteId,
    this.shipments,
    this.totalAmount,
    this.lastUpdated,
    this.financingGroup,
  });

  factory MpPreference.fromMap(Map<String, dynamic> map) {
    return MpPreference(
      additionalInfo: map['additional_info'],
      autoReturn: map['auto_return'],
      backUrls: map['back_urls'] is Map<String, dynamic>
          ? MpBackUrls.fromMap(map['back_urls'] as Map<String, dynamic>)
          : null,
      binaryMode: map['binary_mode'],
      clientId: map['client_id'],
      collectorId: (map['collector_id'] as num?)?.toInt(),
      couponCode: map['coupon_code'],
      couponLabels: map['coupon_labels'],
      dateCreated: tryParseDate(map['date_created']),
      dateOfExpiration: tryParseDate(map['date_of_expiration']),
      expirationDateFrom: tryParseDate(map['expiration_date_from']),
      expirationDateTo: tryParseDate(map['expiration_date_to']),
      expires: map['expires'],
      externalReference: map['external_reference'],
      id: map['id'],
      initPoint: map['init_point'],
      internalMetadata: map['internal_metadata'],
      items:
          (map['items'] as List?)
              ?.whereType<Map>()
              .map((e) => MpItem.fromMap(e.cast<String, dynamic>()))
              .toList() ??
          const [],
      marketplace: map['marketplace'],
      marketplaceFee: map['marketplace_fee'],
      metadata: map['metadata'] is Map<String, dynamic>
          ? (map['metadata'] as Map<String, dynamic>)
          : null,
      notificationUrl: map['notification_url'],
      operationType: map['operation_type'],
      payer: map['payer'] is Map<String, dynamic>
          ? MpPayer.fromMap(map['payer'] as Map<String, dynamic>)
          : null,
      paymentMethods: map['payment_methods'] is Map<String, dynamic>
          ? MpPaymentMethods.fromMap(
              map['payment_methods'] as Map<String, dynamic>,
            )
          : null,
      processingModes: map['processing_modes'],
      productId: map['product_id'],
      preferenceExpired: map['preference_expired'],
      redirectUrls: map['redirect_urls'] is Map<String, dynamic>
          ? MpBackUrls.fromMap(map['redirect_urls'] as Map<String, dynamic>)
          : null,
      sandboxInitPoint: map['sandbox_init_point'],
      siteId: map['site_id'],
      shipments: map['shipments'] is Map<String, dynamic>
          ? MpShipments.fromMap(map['shipments'] as Map<String, dynamic>)
          : null,
      totalAmount: map['total_amount'],
      lastUpdated: tryParseDate(map['last_updated']),
      financingGroup: map['financing_group'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'additional_info': additionalInfo,
      'auto_return': autoReturn,
      'back_urls': backUrls?.toMap(),
      'binary_mode': binaryMode,
      'client_id': clientId,
      'collector_id': collectorId,
      'coupon_code': couponCode,
      'coupon_labels': couponLabels,
      'date_created': dateCreated?.toIso8601String(),
      'date_of_expiration': dateOfExpiration?.toIso8601String(),
      'expiration_date_from': expirationDateFrom?.toIso8601String(),
      'expiration_date_to': expirationDateTo?.toIso8601String(),
      'expires': expires,
      'external_reference': externalReference,
      'id': id,
      'init_point': initPoint,
      'internal_metadata': internalMetadata,
      'items': items.map((e) => e.toMap()).toList(),
      'marketplace': marketplace,
      'marketplace_fee': marketplaceFee,
      'metadata': metadata,
      'notification_url': notificationUrl,
      'operation_type': operationType,
      'payer': payer?.toMap(),
      'payment_methods': paymentMethods?.toMap(),
      'processing_modes': processingModes,
      'product_id': productId,
      'preference_expired': preferenceExpired,
      'redirect_urls': redirectUrls?.toMap(),
      'sandbox_init_point': sandboxInitPoint,
      'site_id': siteId,
      'shipments': shipments?.toMap(),
      'total_amount': totalAmount,
      'last_updated': lastUpdated?.toIso8601String(),
      'financing_group': financingGroup,
    };
  }

  static DateTime? tryParseDate(dynamic value) {
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }
}

class MpBackUrls {
  final String? failure;
  final String? pending;
  final String? success;

  const MpBackUrls({this.failure, this.pending, this.success});

  factory MpBackUrls.fromMap(Map<String, dynamic> map) {
    return MpBackUrls(
      failure: map['failure'],
      pending: map['pending'],
      success: map['success'],
    );
  }

  Map<String, dynamic> toMap() {
    return {'failure': failure, 'pending': pending, 'success': success};
  }
}

class MpItem {
  final String? id;
  final String? categoryId;
  final String? currencyId;
  final String? description;
  final String? title;
  final int? quantity;
  final num? unitPrice;

  const MpItem({
    this.id,
    this.categoryId,
    this.currencyId,
    this.description,
    this.title,
    this.quantity,
    this.unitPrice,
  });

  factory MpItem.fromMap(Map<String, dynamic> map) {
    return MpItem(
      id: map['id'],
      categoryId: map['category_id'],
      currencyId: map['currency_id'],
      description: map['description'],
      title: map['title'],
      quantity: (map['quantity'] as num?)?.toInt(),
      unitPrice: map['unit_price'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'category_id': categoryId,
      'currency_id': currencyId,
      'description': description,
      'title': title,
      'quantity': quantity,
      'unit_price': unitPrice,
    };
  }
}

class MpPayer {
  final MpPhone? phone;
  final MpPayerAddress? address;
  final String? email;
  final MpIdentification? identification;
  final String? name;
  final String? surname;
  final DateTime? dateCreated;
  final DateTime? lastPurchase;

  const MpPayer({
    this.phone,
    this.address,
    this.email,
    this.identification,
    this.name,
    this.surname,
    this.dateCreated,
    this.lastPurchase,
  });

  factory MpPayer.fromMap(Map<String, dynamic> map) {
    return MpPayer(
      phone: map['phone'] is Map<String, dynamic>
          ? MpPhone.fromMap(map['phone'] as Map<String, dynamic>)
          : null,
      address: map['address'] is Map<String, dynamic>
          ? MpPayerAddress.fromMap(map['address'] as Map<String, dynamic>)
          : null,
      email: map['email'],
      identification: map['identification'] is Map<String, dynamic>
          ? MpIdentification.fromMap(
              map['identification'] as Map<String, dynamic>,
            )
          : null,
      name: map['name'],
      surname: map['surname'],
      dateCreated: MpPreference.tryParseDate(map['date_created']),
      lastPurchase: MpPreference.tryParseDate(map['last_purchase']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'phone': phone?.toMap(),
      'address': address?.toMap(),
      'email': email,
      'identification': identification?.toMap(),
      'name': name,
      'surname': surname,
      'date_created': dateCreated?.toIso8601String(),
      'last_purchase': lastPurchase?.toIso8601String(),
    };
  }
}

class MpPhone {
  final String? areaCode;
  final String? number;

  const MpPhone({this.areaCode, this.number});

  factory MpPhone.fromMap(Map<String, dynamic> map) {
    return MpPhone(areaCode: map['area_code'], number: map['number']);
  }

  Map<String, dynamic> toMap() {
    return {'area_code': areaCode, 'number': number};
  }
}

class MpPayerAddress {
  final String? zipCode;
  final String? streetName;
  final dynamic streetNumber;

  const MpPayerAddress({this.zipCode, this.streetName, this.streetNumber});

  factory MpPayerAddress.fromMap(Map<String, dynamic> map) {
    return MpPayerAddress(
      zipCode: map['zip_code'],
      streetName: map['street_name'],
      streetNumber: map['street_number'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'zip_code': zipCode,
      'street_name': streetName,
      'street_number': streetNumber,
    };
  }
}

class MpIdentification {
  final String? number;
  final String? type;

  const MpIdentification({this.number, this.type});

  factory MpIdentification.fromMap(Map<String, dynamic> map) {
    return MpIdentification(number: map['number'], type: map['type']);
  }

  Map<String, dynamic> toMap() {
    return {'number': number, 'type': type};
  }
}

class MpPaymentMethods {
  final dynamic defaultCardId;
  final dynamic defaultPaymentMethodId;
  final List<MpExcludedMethod> excludedPaymentMethods;
  final List<MpExcludedMethod> excludedPaymentTypes;
  final dynamic installments;
  final dynamic defaultInstallments;

  const MpPaymentMethods({
    this.defaultCardId,
    this.defaultPaymentMethodId,
    this.excludedPaymentMethods = const [],
    this.excludedPaymentTypes = const [],
    this.installments,
    this.defaultInstallments,
  });

  factory MpPaymentMethods.fromMap(Map<String, dynamic> map) {
    return MpPaymentMethods(
      defaultCardId: map['default_card_id'],
      defaultPaymentMethodId: map['default_payment_method_id'],
      excludedPaymentMethods:
          (map['excluded_payment_methods'] as List?)
              ?.whereType<Map>()
              .map((e) => MpExcludedMethod.fromMap(e.cast<String, dynamic>()))
              .toList() ??
          const [],
      excludedPaymentTypes:
          (map['excluded_payment_types'] as List?)
              ?.whereType<Map>()
              .map((e) => MpExcludedMethod.fromMap(e.cast<String, dynamic>()))
              .toList() ??
          const [],
      installments: map['installments'],
      defaultInstallments: map['default_installments'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'default_card_id': defaultCardId,
      'default_payment_method_id': defaultPaymentMethodId,
      'excluded_payment_methods': excludedPaymentMethods
          .map((e) => e.toMap())
          .toList(),
      'excluded_payment_types': excludedPaymentTypes
          .map((e) => e.toMap())
          .toList(),
      'installments': installments,
      'default_installments': defaultInstallments,
    };
  }
}

class MpExcludedMethod {
  final String? id;

  const MpExcludedMethod({this.id});

  factory MpExcludedMethod.fromMap(Map<String, dynamic> map) {
    return MpExcludedMethod(id: map['id']);
  }

  Map<String, dynamic> toMap() {
    return {'id': id};
  }
}

class MpShipments {
  final dynamic defaultShippingMethod;
  final MpReceiverAddress? receiverAddress;

  const MpShipments({this.defaultShippingMethod, this.receiverAddress});

  factory MpShipments.fromMap(Map<String, dynamic> map) {
    return MpShipments(
      defaultShippingMethod: map['default_shipping_method'],
      receiverAddress: map['receiver_address'] is Map<String, dynamic>
          ? MpReceiverAddress.fromMap(
              map['receiver_address'] as Map<String, dynamic>,
            )
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'default_shipping_method': defaultShippingMethod,
      'receiver_address': receiverAddress?.toMap(),
    };
  }
}

class MpReceiverAddress {
  final String? zipCode;
  final String? streetName;
  final dynamic streetNumber;
  final String? floor;
  final String? apartment;
  final dynamic cityName;
  final dynamic stateName;
  final dynamic countryName;
  final dynamic neighborhood;

  const MpReceiverAddress({
    this.zipCode,
    this.streetName,
    this.streetNumber,
    this.floor,
    this.apartment,
    this.cityName,
    this.stateName,
    this.countryName,
    this.neighborhood,
  });

  factory MpReceiverAddress.fromMap(Map<String, dynamic> map) {
    return MpReceiverAddress(
      zipCode: map['zip_code'],
      streetName: map['street_name'],
      streetNumber: map['street_number'],
      floor: map['floor'],
      apartment: map['apartment'],
      cityName: map['city_name'],
      stateName: map['state_name'],
      countryName: map['country_name'],
      neighborhood: map['neighborhood'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'zip_code': zipCode,
      'street_name': streetName,
      'street_number': streetNumber,
      'floor': floor,
      'apartment': apartment,
      'city_name': cityName,
      'state_name': stateName,
      'country_name': countryName,
      'neighborhood': neighborhood,
    };
  }
}
