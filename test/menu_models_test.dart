import 'package:flutter_test/flutter_test.dart';

import 'package:evil_space/menu_models.dart';

void main() {
  test('public menu parses groups, optional description and price', () {
    final menu = MenuCatalog.fromJson({
      'version': 3,
      'updatedAt': 100,
      'groups': [
        {
          'id': 'beverages',
          'name': 'Beverages',
          'items': [
            {
              'id': 'cola',
              'name': 'Cola',
              'priceVnd': 30000,
              'description': null,
              'enabled': true,
            },
          ],
        },
      ],
    });

    expect(menu.version, 3);
    expect(menu.groups.single.id, 'beverages');
    expect(menu.groups.single.items.single.name, 'Cola');
    expect(menu.groups.single.items.single.priceVnd, 30000);
    expect(menu.groups.single.items.single.description, isNull);
  });

  test('order status exposes paid lifecycle', () {
    final status = MenuOrderStatus.fromJson({
      'orderCode': 'ABC234',
      'itemId': 'cola',
      'itemName': 'Cola',
      'amountVnd': 30000,
      'paymentMessage': 'EVIL ABC234',
      'status': 'paid',
      'createdAt': 100,
      'expiresAt': 200,
      'paidAt': 150,
    });

    expect(status.paid, isTrue);
    expect(status.pending, isFalse);
    expect(status.paidAt, 150);
  });
}
