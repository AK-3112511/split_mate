import 'package:flutter_test/flutter_test.dart';
import 'package:split_mate/features/categories/domain/category_guesser.dart';
import 'package:split_mate/features/categories/domain/category_model.dart';

void main() {
  const cats = CategoryModel.defaults;
  final now = DateTime(2026, 11, 18, 12);
  CategoryHint h(String d, String cat, {double amount = 100, int daysAgo = 1}) => CategoryHint(
    description: d,
    categoryId: cat,
    amount: amount,
    date: now.subtract(Duration(days: daysAgo)),
  );

  String? guess(String text, {List<CategoryHint> history = const [], List<CategoryModel> categories = cats}) =>
      CategoryGuesser(categories: categories, history: history).guess(text)?.category.id;

  group('built-in words', () {
    test('common merchants', () {
      expect(guess('Uber'), 'travel');
      expect(guess('ola to airport'), 'travel');
      expect(guess('Swiggy'), 'food');
      expect(guess("Domino's"), 'food');
      expect(guess('Blinkit order'), 'groceries');
      expect(guess('D-Mart'), 'groceries');
      expect(guess('Netflix'), 'entertainment');
      expect(guess('Airtel recharge'), 'utilities');
      expect(guess('Apollo pharmacy'), 'health');
      expect(guess('Myntra'), 'shopping');
      expect(guess('PG rent'), 'rent');
    });

    test('phrases win over single words', () {
      expect(guess('Uber Eats'), 'food');
      expect(guess('Amazon Prime'), 'entertainment');
      expect(guess('Swiggy Instamart'), 'groceries');
    });

    test('nothing to go on → no guess', () {
      expect(guess('Rahul'), isNull);
      expect(guess(''), isNull);
      expect(guess('a'), isNull);
    });

    test('works with renamed or missing default categories', () {
      const custom = [
        CategoryModel(id: 'c1', name: 'Transport', iconCode: 'directions_car', colorHex: '06B6D4'),
        CategoryModel(id: 'c2', name: 'Eating out', iconCode: 'restaurant', colorHex: 'F97316'),
      ];
      expect(guess('Rapido', categories: custom), 'c1');
      expect(guess('Zomato', categories: custom), 'c2');
      expect(guess('Netflix', categories: custom), isNull);
    });
  });

  group('category name in the text', () {
    test('picks a custom category by name', () {
      const withCoffee = [
        ...cats,
        CategoryModel(id: 'cof', name: 'Coffee', iconCode: 'local_cafe', colorHex: '8B5CF6'),
      ];
      expect(guess('Coffee at Third Wave', categories: withCoffee), 'cof');
      expect(guess('Rent for May'), 'rent');
    });
  });

  group('learning from history', () {
    test('exact description repeats the last category', () {
      final history = [h('Chai', 'health')];
      expect(guess('chai', history: history), 'health');
    });

    test('history beats built-in words', () {
      final history = [h('Uber', 'shopping', daysAgo: 1), h('Uber', 'shopping', daysAgo: 3)];
      expect(guess('Uber', history: history), 'shopping');
    });

    test('most used wins; a tie goes to the most recent', () {
      expect(
        guess(
          'Lunch',
          history: [h('Lunch', 'food', daysAgo: 5), h('Lunch', 'food', daysAgo: 4), h('Lunch', 'rent', daysAgo: 1)],
        ),
        'food',
      );
      expect(guess('Lunch', history: [h('Lunch', 'food', daysAgo: 5), h('Lunch', 'rent', daysAgo: 1)]), 'rent');
    });

    test('a word seen twice for one category carries over', () {
      final history = [h('Gym fees Anytime', 'rent', daysAgo: 30), h('Anytime protein bar', 'rent', daysAgo: 2)];
      expect(guess('Anytime monthly', history: history), 'rent');
    });

    test('a word seen once does not', () {
      final history = [h('Dinner with Rahul', 'food')];
      expect(guess('Rahul birthday', history: history), isNull);
    });

    test('ignores history pointing at deleted categories', () {
      final history = [h('Chai', 'gone'), h('Chai', 'gone')];
      expect(guess('Chai', history: history), 'food');
    });
  });

  group('quick picks', () {
    test('frequent descriptions, steady amount filled', () {
      final history = [
        h('Metro', 'travel', amount: 40, daysAgo: 1),
        h('metro', 'travel', amount: 40, daysAgo: 2),
        h('Metro', 'travel', amount: 40, daysAgo: 3),
        h('Chai', 'food', amount: 20, daysAgo: 1),
        h('Chai', 'food', amount: 25, daysAgo: 2),
        h('Once', 'food', amount: 99, daysAgo: 1),
        h('Old', 'food', amount: 10, daysAgo: 200),
        h('Old', 'food', amount: 10, daysAgo: 201),
      ];
      final picks = CategoryGuesser(categories: cats, history: history).quickPicks(now: now);
      expect(picks.map((p) => p.description), ['Metro', 'Chai']);
      expect(picks[0].category.id, 'travel');
      expect(picks[0].amount, 40);
      expect(picks[1].amount, isNull);
    });
  });
}
