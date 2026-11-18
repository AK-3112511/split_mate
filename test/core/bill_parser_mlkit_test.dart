import 'package:flutter_test/flutter_test.dart';
import 'package:split_mate/features/bill_scan/domain/bill_parser.dart';

/// Real ML Kit output (Android, OPPO CPH2467) for a tilted photo of a GST bill,
/// in the order ML Kit returned it. Note "240.0e" for 240.00.
const _spiceGarden = [
  OcrLine('Table: 7', left: 163, top: 431, right: 294, bottom: 458, angle: -1.5044423341751099),
  OcrLine('Bill No: 2231', left: 162, top: 387, right: 377, bottom: 419, angle: -2.2791213989257812),
  OcrLine('Item', left: 167, top: 512, right: 230, bottom: 534, angle: -0.8142428398132324),
  OcrLine('12, MG Road, Bengaluru 560001', left: 311, top: 231, right: 799, bottom: 280, angle: -2.418757677078247),
  OcrLine('Paneer Tikka', left: 169, top: 579, right: 368, bottom: 613, angle: -3.048980474472046),
  OcrLine('Butter Naan', left: 171, top: 623, right: 352, bottom: 650, angle: -1.7192423343658447),
  OcrLine('Pax: 3', left: 350, top: 424, right: 447, bottom: 453, angle: -3.1956379413604736),
  OcrLine('Dal Makhani', left: 172, top: 660, right: 353, bottom: 690, angle: -1.9338828325271606),
  OcrLine('SPICE GARDEN', left: 404, top: 178, right: 701, bottom: 222, angle: -1.9397106170654297),
  OcrLine('Sub Total', left: 178, top: 819, right: 327, bottom: 846, angle: -1.2683361768722534),
  OcrLine('GSTIN: 29AABCS1234K1Z9', left: 370, top: 280, right: 740, bottom: 317, angle: -2.1932661533355713),
  OcrLine('Veg Biryani', left: 173, top: 699, right: 356, bottom: 737, angle: -2.6819751262664795),
  OcrLine('Fresh Lime Soda', left: 176, top: 737, right: 425, bottom: 770, angle: -2.258073091506958),
  OcrLine('CGST @ 2.5%', left: 179, top: 854, right: 364, bottom: 890, angle: -2.4837281703948975),
  OcrLine('TAX INVOICE', left: 466, top: 329, right: 648, bottom: 357, angle: -2.1268999576568604),
  OcrLine('SGST @ 2.5%', left: 181, top: 895, right: 365, bottom: 929, angle: -2.4117209911346436),
  OcrLine('Service Charge 5%', left: 183, top: 932, right: 468, bottom: 968, angle: -1.5735102891921997),
  OcrLine('Grand Total', left: 185, top: 1009, right: 457, bottom: 1055, angle: -1.9773932695388794),
  OcrLine('Qty', left: 585, top: 498, right: 633, bottom: 523, angle: 0.0),
  OcrLine('Rate', left: 689, top: 493, right: 753, bottom: 515, angle: 0.0),
  OcrLine('1 320.00', left: 623, top: 567, right: 755, bottom: 593, angle: -1.809940218925476),
  OcrLine('4', left: 623, top: 613, right: 637, bottom: 632, angle: 0.0),
  OcrLine('60.00', left: 676, top: 606, right: 754, bottom: 630, angle: -1.5380158424377441),
  OcrLine('1 280.00', left: 625, top: 646, right: 755, bottom: 673, angle: -2.0796773433685303),
  OcrLine('1 260.00', left: 627, top: 687, right: 760, bottom: 713, angle: -1.3826050758361816),
  OcrLine('2 90.00', left: 629, top: 727, right: 760, bottom: 752, angle: -0.6009059548377991),
  OcrLine('18/11/26', left: 826, top: 366, right: 957, bottom: 395, angle: -1.039570689201355),
  OcrLine('20:41', left: 878, top: 408, right: 959, bottom: 431, angle: -1.34917151927948),
  OcrLine('Thank you! Visit again', left: 401, top: 1067, right: 770, bottom: 1107, angle: -1.88120436668396),
  OcrLine('Amount', left: 863, top: 482, right: 962, bottom: 507, angle: 0.5625551342964172),
  OcrLine('320.00', left: 868, top: 559, right: 962, bottom: 583, angle: -1.1478155851364136),
  OcrLine('240.0e', left: 869, top: 598, right: 964, bottom: 623, angle: -1.8758851289749146),
  OcrLine('280.00', left: 870, top: 639, right: 967, bottom: 663, angle: -1.6804460287094116),
  OcrLine('260.00', left: 872, top: 678, right: 968, bottom: 703, angle: -1.935360074043274),
  OcrLine('180.00', left: 874, top: 718, right: 969, bottom: 743, angle: -1.6532611846923828),
  OcrLine('1,280.00', left: 842, top: 792, right: 973, bottom: 824, angle: -3.064420223236084),
  OcrLine('32.00', left: 895, top: 834, right: 975, bottom: 858, angle: -1.1998196840286255),
  OcrLine('32.00', left: 897, top: 875, right: 976, bottom: 898, angle: -1.8575637340545654),
  OcrLine('64.00', left: 898, top: 914, right: 978, bottom: 938, angle: -1.594902753829956),
  OcrLine('Rs.1,408.00', left: 712, top: 991, right: 982, bottom: 1041, angle: -2.500382900238037),
];

void main() {
  test('real ML Kit output: every item, tax and total', () {
    final b = BillParser.parse(_spiceGarden);
    expect(b.merchant, 'Spice Garden');
    expect(b.items.map((i) => '${i.name}=${i.amount}'), [
      'Paneer Tikka=320.0',
      'Butter Naan ×4=240.0',
      'Dal Makhani=280.0',
      'Veg Biryani=260.0',
      'Fresh Lime Soda ×2=180.0',
    ]);
    expect(b.charges, 128);
    expect(b.billTotal, 1408);
    expect(b.matchesBill, isTrue);
  });

  test('an amount OCR mangles beyond repair still keeps the item', () {
    // qty × rate fills it in…
    final withRate = [..._spiceGarden.where((l) => l.text != '240.0e'), _mangled('24?.?0')];
    final a = BillParser.parse(withRate).items.firstWhere((i) => i.name.startsWith('Butter'));
    expect(a.amount, 240);

    // …and without a rate, the printed subtotal does.
    final noRate = [
      ..._spiceGarden.where((l) => l.text != '240.0e' && l.text != '60.00' && l.text != '4'),
      _mangled('24?.?0'),
    ];
    final b = BillParser.parse(noRate);
    expect(b.items.firstWhere((i) => i.name.startsWith('Butter')).amount, 240);
    expect(b.matchesBill, isTrue);
  });

  test('unreadable price with nothing to infer it from is left blank, not dropped', () {
    final b = BillParser.parse([
      const OcrLine('Masala Dosa', left: 10, top: 40, right: 120, bottom: 60),
      const OcrLine('12?.?0', left: 400, top: 40, right: 460, bottom: 60),
      const OcrLine('Coffee', left: 10, top: 70, right: 80, bottom: 90),
      const OcrLine('60.00', left: 400, top: 70, right: 460, bottom: 90),
    ]);
    expect(b.items.map((i) => i.name), ['Masala Dosa', 'Coffee']);
    expect(b.items.first.amount, isNull);
    expect(b.matchesBill, isFalse);
  });
}

/// The Butter Naan amount box with different (unreadable) text.
OcrLine _mangled(String text) =>
    OcrLine(text, left: 869, top: 598, right: 964, bottom: 623, angle: -1.8758851289749146);
