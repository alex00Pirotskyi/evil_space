import 'package:flutter_test/flutter_test.dart';

import 'package:evil_space/menu_models.dart';

void main() {
  test('public menu parses localized groups, optional description and price', () {
    final menu = MenuCatalog.fromJson({
      'version': 3,
      'updatedAt': 100,
      'groups': [
        {
          'id': 'beverages',
          'name': {
            'en': 'Drinks',
            'ru': 'Напитки',
            'vi': 'Đồ uống',
          },
          'items': [
            {
              'id': 'cola',
              'name': {
                'en': 'Cola',
                'ru': 'Кола',
                'vi': 'Cola',
              },
              'priceVnd': 30000,
              'description': {
                'en': 'Cold can',
                'ru': 'Холодная банка',
                'vi': 'Lon lạnh',
              },
              'enabled': true,
            },
          ],
        },
      ],
    });

    expect(menu.version, 3);
    expect(menu.groups.single.id, 'beverages');
    expect(menu.groups.single.name.resolve('en'), 'Drinks');
    expect(menu.groups.single.name.resolve('ru'), 'Напитки');
    expect(menu.groups.single.name.resolve('vi'), 'Đồ uống');
    expect(menu.groups.single.items.single.nameFor('en'), 'Cola');
    expect(menu.groups.single.items.single.nameFor('ru'), 'Кола');
    expect(menu.groups.single.items.single.nameFor('vi'), 'Cola');
    expect(menu.groups.single.items.single.priceVnd, 30000);
    expect(menu.groups.single.items.single.descriptionFor('en'), 'Cold can');
    expect(menu.groups.single.items.single.descriptionFor('ru'), 'Холодная банка');
    expect(menu.groups.single.items.single.descriptionFor('vi'), 'Lon lạnh');
  });

  test('legacy string group name remains compatible', () {
    final group = MenuGroup.fromJson({
      'id': 'snacks',
      'name': 'Snacks',
      'items': const [],
    });

    expect(group.name.resolve('en'), 'Snacks');
    expect(group.name.resolve('ru'), 'Snacks');
    expect(group.name.resolve('vi'), 'Snacks');
  });

  test('legacy string item text remains compatible', () {
    final item = MenuItem.fromJson({
      'id': 'water',
      'name': 'Water',
      'priceVnd': 25000,
      'description': 'Cold',
      'enabled': true,
    });

    expect(item.nameFor('en'), 'Water');
    expect(item.nameFor('ru'), 'Water');
    expect(item.nameFor('vi'), 'Water');
    expect(item.descriptionFor('ru'), 'Cold');
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
