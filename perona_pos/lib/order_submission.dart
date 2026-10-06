import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'domain.dart';
import 'repository.dart';

class PendingOrderPhoto {
  final String id, extension;
  final Uint8List bytes;
  PendingOrderPhoto({required this.bytes, required this.extension, String? id})
    : id = id ?? const Uuid().v4();
}

enum OrderSaveStep { order, payment, photos, done }

class OrderTotalChanged implements Exception {
  final int total;
  const OrderTotalChanged(this.total);
}

/// Keeps stable IDs and completed steps when payment/photo requests are retried.
/// The existing server RPCs remain authoritative for prices and permissions.
class OrderSubmission {
  final Repository repo;
  final bool isNew;
  final paymentId = const Uuid().v4();
  Json? _snapshot;
  List<PendingOrderPhoto> _photos = [];
  String? _method;
  int? _paymentAmount;
  bool orderSaved = false, paymentSaved = false;
  int uploadedPhotos = 0;
  OrderSaveStep step = OrderSaveStep.order;

  OrderSubmission(this.repo, {required this.isNew});
  bool get locked => _snapshot != null;
  String? get orderId => _snapshot?['id'] as String?;

  Future<void> submit(
    Json order, {
    String? paymentMethod,
    List<PendingOrderPhoto> photos = const [],
  }) async {
    if (!locked) {
      _snapshot = {
        ...order,
        'items':
            (order['items'] as List)
                .map((item) => Json.from(item as Map))
                .toList(),
      };
      _photos = List.of(photos);
      _method = paymentMethod;
    }
    final id = orderId!;
    if (!orderSaved) {
      step = OrderSaveStep.order;
      try {
        await repo.saveOrder(_snapshot!);
        orderSaved = true;
      } catch (error) {
        // New IDs belong to this draft. Recover an acknowledged or lost save
        // before trying again, so a payment failure never creates a new order.
        if (isNew) {
          try {
            await repo.order(id);
            orderSaved = true;
          } catch (_) {}
        }
        if (!orderSaved) {
          if (error is PostgrestException) _snapshot = null;
          rethrow;
        }
      }
    }
    if (isNew && !paymentSaved && _method != null) {
      step = OrderSaveStep.payment;
      if (_paymentAmount == null) {
        final saved = await repo.order(id);
        final quoted =
            Totals.fromItems(
              (_snapshot!['items'] as List).cast<Json>(),
              money(_snapshot!['discount']),
              includeLabor: repo.canViewWages,
            ).revenue;
        if (money(saved['total']) != quoted) {
          throw OrderTotalChanged(money(saved['total']));
        }
        final paid = ((saved['payments'] as List?) ?? [])
            .where((payment) => payment['voided_at'] == null)
            .fold<int>(0, (sum, payment) => sum + money(payment['amount']));
        _paymentAmount = money(saved['total']) - paid;
      }
      if (_paymentAmount! > 0) {
        final orderAt = _snapshot!['created_at'] as String?;
        await repo.pay(
          paymentId,
          id,
          _paymentAmount!,
          _method!,
          paidAt: orderAt == null ? null : DateTime.parse(orderAt),
        );
      }
      paymentSaved = true;
    }
    step = OrderSaveStep.photos;
    while (uploadedPhotos < _photos.length) {
      final photo = _photos[uploadedPhotos];
      await repo.uploadPhoto(
        id,
        photo.bytes,
        photo.extension,
        photoId: photo.id,
      );
      uploadedPhotos++;
    }
    step = OrderSaveStep.done;
  }
}
