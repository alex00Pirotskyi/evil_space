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

  test('menu item parses configurable choices and dot settings', () {
    final item = MenuItem.fromJson({
      'id': 'americano',
      'name': {
        'en': 'Americano',
        'ru': 'Американо',
        'vi': 'Americano',
      },
      'priceVnd': 45000,
      'enabled': true,
      'options': [
        {
          'id': 'size',
          'type': 'single',
          'name': {'en': 'Size', 'ru': 'Размер', 'vi': 'Kích cỡ'},
          'required': true,
          'default': '020',
          'values': [
            {
              'id': '020',
              'name': {'en': '0.2 L', 'ru': '0.2 л', 'vi': '0.2 L'},
              'priceDeltaVnd': 0,
            },
            {
              'id': '030',
              'name': {'en': '0.3 L', 'ru': '0.3 л', 'vi': '0.3 L'},
              'priceDeltaVnd': 15000,
            },
          ],
        },
        {
          'id': 'strength',
          'type': 'dots',
          'name': {'en': 'Strength', 'ru': 'Крепость', 'vi': 'Độ đậm'},
          'min': 1,
          'max': 3,
          'default': 1,
          'pricePerStepVnd': 20000,
        },
      ],
    });

    expect(item.hasOptions, isTrue);
    expect(item.hasVariablePrice, isTrue);
    expect(item.options.first.defaultChoice, '020');
    expect(item.options.first.values.last.priceDeltaVnd, 15000);
    expect(item.options.last.defaultDots, 1);
    expect(item.options.last.pricePerStepVnd, 20000);
    expect(item.toJson()['options'], isNotEmpty);
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
