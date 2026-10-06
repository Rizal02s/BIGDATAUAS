import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:perona_pos/domain.dart';
import 'package:perona_pos/order_submission.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'home_page_test.dart' show DemoRepository;

class SubmissionRepository extends DemoRepository {
  int saves = 0;
  int serverTotal = 30000;
  bool persisted = false, lostSaveResponse = false, rejectSave = false;
  bool lostPaymentResponse = false;
  String? failPhoto;
  final paymentCalls = <Json>[];
  final receipts = <String, Json>{};
  final photoCalls = <String>[];
  Json? savedDraft;

  @override
  Future<void> saveOrder(Json order) async {
    saves++;
    savedDraft = order;
    if (rejectSave) {
      throw const PostgrestException(message: 'Tarif tidak valid.');
    }
    persisted = true;
    if (lostSaveResponse) throw Exception('Save response lost');
  }

  @override
  Future<Json> order(String id) async {
    if (!persisted) {
      throw const PostgrestException(message: 'Not found', code: 'PGRST116');
    }
    return {
      'id': id,
      'total': serverTotal,
      'payments': receipts.values.toList(),
    };
  }

  @override
  Future<void> pay(
    String paymentId,
    String orderId,
    int amount,
    String method, {
    DateTime? paidAt,
  }) async {
    final receipt = {
      'id': paymentId,
      'amount': amount,
      'method': method,
      'voided_at': null,
      'paid_at': paidAt?.toUtc().toIso8601String(),
    };
    paymentCalls.add(receipt);
    receipts.putIfAbsent(paymentId, () => receipt);
    if (lostPaymentResponse) {
      lostPaymentResponse = false;
      throw Exception('Payment response lost');
    }
  }

  @override
  Future<void> uploadPhoto(
    String orderId,
    Uint8List bytes,
    String extension, {
    String? photoId,
  }) async {
    photoCalls.add(photoId!);
    if (photoId == failPhoto) throw Exception('Photo upload failed');
  }
}

Json draft() => {
  'id': 'draft-id',
  'version': 0,
  'customer_name': 'Andi',
  'phone': '',
  'notes': '',
  'discount': 0,
  'items': [
    {'price': 30000, 'labor_fee': 10000, 'quantity': 1},
  ],
};

void main() {
  test(
    'Backdated order and initial payment keep their date after lost response',
    () async {
      final repo = SubmissionRepository()..lostPaymentResponse = true;
      final submission = OrderSubmission(repo, isNew: true);
      final order = draft()..['created_at'] = '2026-10-03T03:15:00.000Z';
      await expectLater(
        submission.submit(order, paymentMethod: 'Tunai'),
        throwsException,
      );
      final changed = draft()..['created_at'] = '2026-10-06T05:30:00.000Z';
      await submission.submit(changed, paymentMethod: 'Tunai');
      expect(repo.savedDraft!['created_at'], order['created_at']);
      expect(repo.saves, 1);
      expect(repo.paymentCalls.length, 2);
      expect(
        repo.paymentCalls.every((p) => p['paid_at'] == order['created_at']),
        true,
      );
      expect(repo.receipts.length, 1);
    },
  );
  for (final method in ['Tunai', 'QRIS']) {
    test('$method settles the confirmed bill', () async {
      final repo = SubmissionRepository();
      final submission = OrderSubmission(repo, isNew: true);
      await submission.submit(draft(), paymentMethod: method);
      expect(repo.receipts.values.single['amount'], 30000);
      expect(repo.receipts.values.single['method'], method);
      expect(submission.step, OrderSaveStep.done);
    });
  }

  test('unpaid order creates no payment and still saves its photos', () async {
    final repo = SubmissionRepository();
    final submission = OrderSubmission(repo, isNew: true);
    await submission.submit(
      draft(),
      photos: [
        PendingOrderPhoto(id: 'photo-a', bytes: Uint8List(1), extension: 'png'),
      ],
    );
    expect(repo.receipts, isEmpty);
    expect(repo.photoCalls, ['photo-a']);
    expect(submission.orderSaved, isTrue);
  });

  test('lost save response recovers the same draft before payment', () async {
    final repo = SubmissionRepository()..lostSaveResponse = true;
    final submission = OrderSubmission(repo, isNew: true);
    await submission.submit(draft(), paymentMethod: 'Tunai');
    expect(repo.saves, 1);
    expect(repo.receipts.length, 1);
  });

  test(
    'lost payment response retries the same ID without another order',
    () async {
      final repo = SubmissionRepository()..lostPaymentResponse = true;
      final submission = OrderSubmission(repo, isNew: true);
      await expectLater(
        submission.submit(draft(), paymentMethod: 'QRIS'),
        throwsException,
      );
      expect(submission.orderSaved, isTrue);
      await submission.submit(draft(), paymentMethod: 'QRIS');
      expect(repo.saves, 1);
      expect(repo.paymentCalls.length, 2);
      expect(repo.paymentCalls[0]['id'], repo.paymentCalls[1]['id']);
      expect(repo.paymentCalls[0]['amount'], repo.paymentCalls[1]['amount']);
      expect(repo.receipts.length, 1);
    },
  );

  test('photo retry skips completed photos and payment', () async {
    final repo = SubmissionRepository()..failPhoto = 'photo-b';
    final submission = OrderSubmission(repo, isNew: true);
    final photos =
        ['photo-a', 'photo-b']
            .map(
              (id) => PendingOrderPhoto(
                id: id,
                bytes: Uint8List(1),
                extension: 'png',
              ),
            )
            .toList();
    await expectLater(
      submission.submit(draft(), paymentMethod: 'Tunai', photos: photos),
      throwsException,
    );
    expect(submission.uploadedPhotos, 1);
    repo.failPhoto = null;
    await submission.submit(draft(), paymentMethod: 'Tunai', photos: photos);
    expect(repo.saves, 1);
    expect(repo.paymentCalls.length, 1);
    expect(repo.photoCalls, ['photo-a', 'photo-b', 'photo-b']);
  });

  test(
    'server rejection permits correcting the form before retrying',
    () async {
      final repo = SubmissionRepository()..rejectSave = true;
      final submission = OrderSubmission(repo, isNew: true);
      await expectLater(
        submission.submit(draft()),
        throwsA(isA<PostgrestException>()),
      );
      expect(submission.locked, isFalse);
      expect(repo.receipts, isEmpty);
    },
  );

  test('editing never settles the bill a second time', () async {
    final repo = SubmissionRepository();
    await OrderSubmission(
      repo,
      isNew: false,
    ).submit(draft(), paymentMethod: 'Tunai');
    expect(repo.saves, 1);
    expect(repo.receipts, isEmpty);
  });

  test('zero-value order records no zero payment', () async {
    final repo = SubmissionRepository()..serverTotal = 0;
    final order = draft();
    (order['items'] as List).first['price'] = 0;
    await OrderSubmission(
      repo,
      isNew: true,
    ).submit(order, paymentMethod: 'Tunai');
    expect(repo.receipts, isEmpty);
  });

  test(
    'a changed tariff requires review before recording a different payment',
    () async {
      final repo = SubmissionRepository()..serverTotal = 45000;
      final submission = OrderSubmission(repo, isNew: true);
      await expectLater(
        submission.submit(draft(), paymentMethod: 'Tunai'),
        throwsA(isA<OrderTotalChanged>()),
      );
      expect(submission.orderSaved, isTrue);
      expect(repo.receipts, isEmpty);
    },
  );
}
