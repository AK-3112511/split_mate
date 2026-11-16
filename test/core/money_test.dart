import 'package:flutter_test/flutter_test.dart';
import 'package:split_mate/core/utils/initials.dart';
import 'package:split_mate/core/utils/money.dart';

void main() {
  group('Money.parse', () {
    test('accepts plain, grouped and decimal-comma input', () {
      expect(Money.parse('450').value, 450);
      expect(Money.parse('1,200').value, 1200);
      expect(Money.parse('1,20,000.5').value, 120000.5);
      expect(Money.parse('12,5').value, 12.5);
      expect(Money.parse('12,50').value, 12.5);
      expect(Money.parse('₹ 99.99').value, 99.99);
      expect(Money.parse('.5').value, 0.5);
    });

    test('rejects invalid input with a friendly message', () {
      expect(Money.parse('').error, isNotNull);
      expect(Money.parse('-5').error, contains('negative'));
      expect(Money.parse('NaN').isValid, isFalse);
      expect(Money.parse('Infinity').isValid, isFalse);
      expect(Money.parse('1e308').isValid, isFalse);
      expect(Money.parse('12.345').error, contains('2 decimal'));
      expect(Money.parse('0').isValid, isFalse);
      expect(Money.parse('0.001').isValid, isFalse);
      expect(Money.parse('20000000').isValid, isFalse);
      expect(Money.parse('0', allowZero: true).value, 0);
    });
  });

  group('Money.format', () {
    test('uses Indian grouping and trims .00', () {
      expect(Money.format(1234567), '₹12,34,567');
      expect(Money.format(1234.5), '₹1,234.50');
      expect(Money.format(0.4), '₹0.40');
      expect(Money.format(-250), '-₹250');
      expect(Money.format(250, signed: true), '+₹250');
    });

    test('compact labels', () {
      expect(Money.compact(950), '₹950');
      expect(Money.compact(1200), '₹1.2K');
      expect(Money.compact(340000), '₹3.4L');
      expect(Money.compact(11000000), '₹1.1Cr');
    });

    test('plain for input prefill', () {
      expect(Money.plain(1200), '1200');
      expect(Money.plain(12.5), '12.5');
      expect(Money.plain(12.05), '12.05');
    });
  });

  group('initialsOf', () {
    test('never throws and handles odd spacing', () {
      expect(initialsOf('Arham Kansal'), 'AK');
      expect(initialsOf('John  Doe'), 'JD'); // double space crashed v1
      expect(initialsOf('  riya  '), 'RI');
      expect(initialsOf('A'), 'A');
      expect(initialsOf(''), '?');
      expect(initialsOf(null), '?');
      expect(initialsOf('Mary Ann Lee'), 'ML');
    });
  });
}
