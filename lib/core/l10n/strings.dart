// Generated from one table (English, Hindi, Hinglish). Keep the three in step.
// ignore_for_file: lines_longer_than_80_chars
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import '../theme/theme_mode_provider.dart';

/// App text language. Hinglish = Hindi in English letters.
enum AppLanguage {
  en('English', 'English'),
  hi('हिन्दी', 'Hindi'),
  hinglish('Hinglish', 'Hindi in English letters');

  final String label;
  final String hint;
  const AppLanguage(this.label, this.hint);

  static AppLanguage fromKey(String? key) =>
      AppLanguage.values.firstWhere((l) => l.name == key, orElse: () => AppLanguage.en);
}

final appLanguageProvider = StateNotifierProvider<AppLanguageNotifier, AppLanguage>((ref) {
  return AppLanguageNotifier(ref);
});

class AppLanguageNotifier extends StateNotifier<AppLanguage> {
  static const _key = 'app_language';
  final Ref _ref;
  AppLanguageNotifier(this._ref) : super(_read(_ref));

  static AppLanguage _read(Ref ref) {
    try {
      return AppLanguage.fromKey(ref.read(sharedPreferencesProvider)?.getString(_key));
    } catch (_) {
      return AppLanguage.en;
    }
  }

  Future<void> set(AppLanguage lang) async {
    state = lang;
    try {
      await _ref.read(sharedPreferencesProvider)?.setString(_key, lang.name);
    } catch (_) {}
  }
}

/// Puts the current strings in the tree; `context.s` reads them (and
/// rebuilds the widget when the language changes).
class StringsScope extends InheritedWidget {
  final S strings;
  const StringsScope({super.key, required this.strings, required super.child});

  @override
  bool updateShouldNotify(StringsScope old) => old.strings.lang != strings.lang;
}

extension StringsContext on BuildContext {
  S get s => dependOnInheritedWidgetOfExactType<StringsScope>()?.strings ?? S.current;
}

/// The app's text in the chosen language. Screens not translated yet keep
/// their English text in place.
class S {
  final AppLanguage lang;
  const S(this.lang);

  /// For code without a BuildContext (toasts, helpers). Set by the app.
  static S current = const S(AppLanguage.en);

  String _t(String key) =>
      (switch (lang) { AppLanguage.en => _en, AppLanguage.hi => _hi, AppLanguage.hinglish => _hinglish })[key] ??
      _en[key] ??
      key;

  String get navHome => _t('navHome');
  String get navGroups => _t('navGroups');
  String get navFriends => _t('navFriends');
  String get navProfile => _t('navProfile');
  String get ok => _t('ok');
  String get cancel => _t('cancel');
  String get save => _t('save');
  String get close => _t('close');
  String get edit => _t('edit');
  String get more => _t('more');
  String get search => _t('search');
  String get today => _t('today');
  String get yesterday => _t('yesterday');
  String get pickDate => _t('pickDate');
  String get takePhoto => _t('takePhoto');
  String get chooseGallery => _t('chooseGallery');
  String get noMatches => _t('noMatches');
  String get decline => _t('decline');
  String get accept => _t('accept');
  String get join => _t('join');
  String get youOwe => _t('youOwe');
  String get youAreOwed => _t('youAreOwed');
  String get settled => _t('settled');
  String get allSettledUp => _t('allSettledUp');
  String youOweAmount(String amount) => _t('youOweAmount').replaceAll('{amount}', amount);
  String youAreOwedAmount(String amount) => _t('youAreOwedAmount').replaceAll('{amount}', amount);
  String owedAmount(String amount) => _t('owedAmount').replaceAll('{amount}', amount);
  String get youreAllSettled => _t('youreAllSettled');
  String get addExpense => _t('addExpense');
  String get you => _t('you');
  String get youLent => _t('youLent');
  String get youBorrowed => _t('youBorrowed');
  String get yourShare => _t('yourShare');
  String get notInvolved => _t('notInvolved');
  String namePaid(String name, String amount) => _t('namePaid').replaceAll('{name}', name).replaceAll('{amount}', amount);
  String get notifications => _t('notifications');
  String get greetLate => _t('greetLate');
  String get greetMorning => _t('greetMorning');
  String get greetAfternoon => _t('greetAfternoon');
  String get greetEvening => _t('greetEvening');
  String spentIn(String month) => _t('spentIn').replaceAll('{month}', month);
  String get startTracking => _t('startTracking');
  String get startTrackingBody => _t('startTrackingBody');
  String get nothingThisPeriod => _t('nothingThisPeriod');
  String get trends => _t('trends');
  String vsLastMonth(String pct) => _t('vsLastMonth').replaceAll('{pct}', pct);
  String get last6Months => _t('last6Months');
  String get expenses => _t('expenses');
  String get noExpensesYet => _t('noExpensesYet');
  String get noExpensesToday => _t('noExpensesToday');
  String get tryAnotherRange => _t('tryAnotherRange');
  String get rangeAllTime => _t('rangeAllTime');
  String get rangeWeek => _t('rangeWeek');
  String get rangeMonth => _t('rangeMonth');
  String get rangeCustom => _t('rangeCustom');
  String get chooseDates => _t('chooseDates');
  String get allCategories => _t('allCategories');
  String get manage => _t('manage');
  String get budgets => _t('budgets');
  String get setBudget => _t('setBudget');
  String get setBudgetBody => _t('setBudgetBody');
  String recapReady(String month) => _t('recapReady').replaceAll('{month}', month);
  String get recapBody => _t('recapBody');
  String get newExpense => _t('newExpense');
  String get newRecurring => _t('newRecurring');
  String get editExpense => _t('editExpense');
  String get editRecurring => _t('editRecurring');
  String get whatFor => _t('whatFor');
  String get addDescription => _t('addDescription');
  String get category => _t('category');
  String get autoPicked => _t('autoPicked');
  String get newLabel => _t('newLabel');
  String get date => _t('date');
  String get startsOn => _t('startsOn');
  String get repeatExpense => _t('repeatExpense');
  String get repeatHint => _t('repeatHint');
  String get notes => _t('notes');
  String get addNote => _t('addNote');
  String get saveExpense => _t('saveExpense');
  String get saveChanges => _t('saveChanges');
  String get setUpRecurring => _t('setUpRecurring');
  String get addReceipt => _t('addReceipt');
  String get attachReceipt => _t('attachReceipt');
  String get receiptAttached => _t('receiptAttached');
  String get expenseAdded => _t('expenseAdded');
  String get changesSaved => _t('changesSaved');
  String get description => _t('description');
  String get paidBy => _t('paidBy');
  String get split => _t('split');
  String get splitEqual => _t('splitEqual');
  String get splitShares => _t('splitShares');
  String get splitExact => _t('splitExact');
  String get splitItems => _t('splitItems');
  String get scanBill => _t('scanBill');
  String get otherCurrency => _t('otherCurrency');
  String get notesOptional => _t('notesOptional');
  String get groups => _t('groups');
  String get joinWithCode => _t('joinWithCode');
  String get invitations => _t('invitations');
  String get noGroupsYet => _t('noGroupsYet');
  String get noGroupsBody => _t('noGroupsBody');
  String get createGroup => _t('createGroup');
  String get yourGroups => _t('yourGroups');
  String get newGroup => _t('newGroup');
  String get noOneOwes => _t('noOneOwes');
  String get tabExpenses => _t('tabExpenses');
  String get tabBalances => _t('tabBalances');
  String get tabStats => _t('tabStats');
  String get tabMembers => _t('tabMembers');
  String get activity => _t('activity');
  String get shareInvite => _t('shareInvite');
  String get exportPdf => _t('exportPdf');
  String get recurringExpenses => _t('recurringExpenses');
  String get tripSummary => _t('tripSummary');
  String get makeItTrip => _t('makeItTrip');
  String get tripSettings => _t('tripSettings');
  String get renameGroup => _t('renameGroup');
  String get leaveGroup => _t('leaveGroup');
  String get deleteGroup => _t('deleteGroup');
  String get searchGroup => _t('searchGroup');
  String groupEmptyBody(String group) => _t('groupEmptyBody').replaceAll('{group}', group);
  String get overallOwed => _t('overallOwed');
  String get overallOwe => _t('overallOwe');
  String get whoOwesWhom => _t('whoOwesWhom');
  String get fewestPayments => _t('fewestPayments');
  String get simplify => _t('simplify');
  String get simplifyHelp => _t('simplifyHelp');
  String get directHelp => _t('directHelp');
  String get allSettledUpParty => _t('allSettledUpParty');
  String get nobodyOwes => _t('nobodyOwes');
  String get betweenOthers => _t('betweenOthers');
  String youOweName(String name) => _t('youOweName').replaceAll('{name}', name);
  String nameOwesYou(String name) => _t('nameOwesYou').replaceAll('{name}', name);
  String nameOwesName(String a, String b) => _t('nameOwesName').replaceAll('{a}', a).replaceAll('{b}', b);
  String get payViaUpi => _t('payViaUpi');
  String get showMyQr => _t('showMyQr');
  String get remind => _t('remind');
  String get record => _t('record');
  String get received => _t('received');
  String get shareBalances => _t('shareBalances');
  String get allCaughtUp => _t('allCaughtUp');
  String get markAllRead => _t('markAllRead');
  String get clearAll => _t('clearAll');
  String get clearAllQ => _t('clearAllQ');
  String get clearAllBody => _t('clearAllBody');
  String get notifEmptyBody => _t('notifEmptyBody');
  String get friends => _t('friends');
  String get addFriend => _t('addFriend');
  String get yourFriendCode => _t('yourFriendCode');
  String get friendCode => _t('friendCode');
  String get settledLower => _t('settledLower');
  String get owesYouLower => _t('owesYouLower');
  String get youOweLower => _t('youOweLower');
  String get shareCodeHint => _t('shareCodeHint');
  String get requests => _t('requests');
  String get yourFriends => _t('yourFriends');
  String get searchFriends => _t('searchFriends');
  String get noFriendsYet => _t('noFriendsYet');
  String get noFriendsBody => _t('noFriendsBody');
  String get addAFriend => _t('addAFriend');
  String get sentRequests => _t('sentRequests');
  String get waitingAccept => _t('waitingAccept');
  String get sendRequest => _t('sendRequest');
  String get profile => _t('profile');
  String get statGroups => _t('statGroups');
  String get statFriends => _t('statFriends');
  String get statThisMonth => _t('statThisMonth');
  String get account => _t('account');
  String get personalInfo => _t('personalInfo');
  String get personalInfoSub => _t('personalInfoSub');
  String get changePassword => _t('changePassword');
  String get privacyPolicy => _t('privacyPolicy');
  String get money => _t('money');
  String get categoriesBudgets => _t('categoriesBudgets');
  String get receipts => _t('receipts');
  String get monthlyRecap => _t('monthlyRecap');
  String monthInReview(String month) => _t('monthInReview').replaceAll('{month}', month);
  String get exportData => _t('exportData');
  String get appearance => _t('appearance');
  String get theme => _t('theme');
  String get themeAuto => _t('themeAuto');
  String get themeLight => _t('themeLight');
  String get themeDark => _t('themeDark');
  String get language => _t('language');
  String get signOut => _t('signOut');
  String get signOutQ => _t('signOutQ');
  String get signOutBody => _t('signOutBody');
  String get deleteAccount => _t('deleteAccount');
  String get privacySecurity => _t('privacySecurity');
  String get appLock => _t('appLock');
  String get appLockSub => _t('appLockSub');
  String get appLockNoDevice => _t('appLockNoDevice');
  String get appLockOn => _t('appLockOn');
  String get appLockOff => _t('appLockOff');
  String get crashReports => _t('crashReports');
  String get crashReportsSub => _t('crashReportsSub');
  String get lockedTitle => _t('lockedTitle');
  String get lockedBody => _t('lockedBody');
  String get unlock => _t('unlock');
  String get unlockReason => _t('unlockReason');
  String get getStarted => _t('getStarted');
  String get getStartedBody => _t('getStartedBody');
  String get stepGroup => _t('stepGroup');
  String get stepGroupSub => _t('stepGroupSub');
  String get stepExpense => _t('stepExpense');
  String get stepExpenseSub => _t('stepExpenseSub');
  String get stepInvite => _t('stepInvite');
  String get stepInviteSub => _t('stepInviteSub');
  String get allDone => _t('allDone');
  String get hideGuide => _t('hideGuide');
}

const Map<String, String> _en = {
  'navHome': 'Home',
  'navGroups': 'Groups',
  'navFriends': 'Friends',
  'navProfile': 'Profile',
  'ok': 'OK',
  'cancel': 'Cancel',
  'save': 'Save',
  'close': 'Close',
  'edit': 'Edit',
  'more': 'More',
  'search': 'Search',
  'today': 'Today',
  'yesterday': 'Yesterday',
  'pickDate': 'Pick a date',
  'takePhoto': 'Take a photo',
  'chooseGallery': 'Choose from gallery',
  'noMatches': 'No matches',
  'decline': 'Decline',
  'accept': 'Accept',
  'join': 'Join',
  'youOwe': 'You owe',
  'youAreOwed': 'You\'re owed',
  'settled': 'Settled',
  'allSettledUp': 'All settled up',
  'youOweAmount': 'You owe {amount}',
  'youAreOwedAmount': 'You\'re owed {amount}',
  'owedAmount': 'Owed {amount}',
  'youreAllSettled': 'You\'re all settled',
  'addExpense': 'Add expense',
  'you': 'You',
  'youLent': 'you lent',
  'youBorrowed': 'you borrowed',
  'yourShare': 'your share',
  'notInvolved': 'not involved',
  'namePaid': '{name} paid {amount}',
  'notifications': 'Notifications',
  'greetLate': 'Up late',
  'greetMorning': 'Good morning',
  'greetAfternoon': 'Good afternoon',
  'greetEvening': 'Good evening',
  'spentIn': 'SPENT IN {month}',
  'startTracking': 'Start tracking your spending',
  'startTrackingBody': 'Add your first expense — charts, budgets and trends appear here as you go.',
  'nothingThisPeriod': 'Nothing spent in this period',
  'trends': 'Trends',
  'vsLastMonth': '{pct} vs last month',
  'last6Months': 'Last 6 months',
  'expenses': 'Expenses',
  'noExpensesYet': 'No expenses yet',
  'noExpensesToday': 'No expenses today',
  'tryAnotherRange': 'Try another range or add one now.',
  'rangeAllTime': 'All time',
  'rangeWeek': 'This week',
  'rangeMonth': 'This month',
  'rangeCustom': 'Custom',
  'chooseDates': 'Choose dates',
  'allCategories': 'All',
  'manage': 'Manage',
  'budgets': 'Budgets',
  'setBudget': 'Set a monthly budget',
  'setBudgetBody': 'Get a nudge at 80% and when you go over',
  'recapReady': 'Your {month} recap is ready',
  'recapBody': 'See where your money went',
  'newExpense': 'New expense',
  'newRecurring': 'New recurring expense',
  'editExpense': 'Edit expense',
  'editRecurring': 'Edit recurring',
  'whatFor': 'What was it for?',
  'addDescription': 'Add a short description',
  'category': 'Category',
  'autoPicked': 'Auto-picked',
  'newLabel': 'New',
  'date': 'Date',
  'startsOn': 'Starts on',
  'repeatExpense': 'Repeat this expense',
  'repeatHint': 'Rent, subscriptions, bills…',
  'notes': 'Notes',
  'addNote': 'Add a note',
  'saveExpense': 'Save expense',
  'saveChanges': 'Save changes',
  'setUpRecurring': 'Set up recurring',
  'addReceipt': 'Add a receipt',
  'attachReceipt': 'Attach receipt',
  'receiptAttached': 'Receipt attached',
  'expenseAdded': 'Expense added',
  'changesSaved': 'Changes saved',
  'description': 'Description',
  'paidBy': 'Paid by',
  'split': 'Split',
  'splitEqual': 'Equal',
  'splitShares': 'Shares',
  'splitExact': 'Exact',
  'splitItems': 'Items',
  'scanBill': 'Scan a bill',
  'otherCurrency': 'Paid in another currency?',
  'notesOptional': 'Notes (optional)',
  'groups': 'Groups',
  'joinWithCode': 'Join with a code',
  'invitations': 'Invitations',
  'noGroupsYet': 'No groups yet',
  'noGroupsBody': 'Create one for your flat, a trip or office lunches — or join with a code.',
  'createGroup': 'Create a group',
  'yourGroups': 'Your groups',
  'newGroup': 'New group',
  'noOneOwes': 'No one owes anyone. Nice.',
  'tabExpenses': 'Expenses',
  'tabBalances': 'Balances',
  'tabStats': 'Stats',
  'tabMembers': 'Members',
  'activity': 'Activity',
  'shareInvite': 'Share invite',
  'exportPdf': 'Export PDF',
  'recurringExpenses': 'Recurring expenses',
  'tripSummary': 'Trip summary',
  'makeItTrip': 'Make it a trip',
  'tripSettings': 'Trip dates & currency',
  'renameGroup': 'Rename group',
  'leaveGroup': 'Leave group',
  'deleteGroup': 'Delete group',
  'searchGroup': 'Search this group',
  'groupEmptyBody': 'Tap "Add expense" — everyone in {group} sees it instantly.',
  'overallOwed': 'Overall, you\'re owed',
  'overallOwe': 'Overall, you owe',
  'whoOwesWhom': 'Who owes whom',
  'fewestPayments': 'Fewest payments',
  'simplify': 'Simplify',
  'simplifyHelp': 'Suggests the fewest transfers to clear the whole group. People may pay someone they didn\'t share with directly.',
  'directHelp': 'Direct balances from expenses you actually shared. Settling these keeps everyone\'s personal ledger accurate.',
  'allSettledUpParty': 'All settled up',
  'nobodyOwes': 'Nobody owes anybody in this group.',
  'betweenOthers': 'Between others',
  'youOweName': 'You owe {name}',
  'nameOwesYou': '{name} owes you',
  'nameOwesName': '{a} owes {b}',
  'payViaUpi': 'Pay via UPI',
  'showMyQr': 'Show my UPI QR',
  'remind': 'Remind',
  'record': 'Record',
  'received': 'Received',
  'shareBalances': 'Share balances',
  'allCaughtUp': 'All caught up',
  'markAllRead': 'Mark all as read',
  'clearAll': 'Clear all',
  'clearAllQ': 'Clear all notifications?',
  'clearAllBody': 'This removes them from your inbox.',
  'notifEmptyBody': 'Expense updates, payments and invites will show up here.',
  'friends': 'Friends',
  'addFriend': 'Add friend',
  'yourFriendCode': 'YOUR FRIEND CODE',
  'friendCode': 'Friend code',
  'settledLower': 'settled',
  'owesYouLower': 'owes you',
  'youOweLower': 'you owe',
  'shareCodeHint': 'Share it so friends can add you',
  'requests': 'Requests',
  'yourFriends': 'Your friends',
  'searchFriends': 'Search friends',
  'noFriendsYet': 'No friends yet',
  'noFriendsBody': 'Add friends with their code to split expenses together.',
  'addAFriend': 'Add a friend',
  'sentRequests': 'Sent requests',
  'waitingAccept': 'Waiting for them to accept',
  'sendRequest': 'Send request',
  'profile': 'Profile',
  'statGroups': 'Groups',
  'statFriends': 'Friends',
  'statThisMonth': 'This month',
  'account': 'Account',
  'personalInfo': 'Personal info',
  'personalInfoSub': 'Name, friend code, UPI ID',
  'changePassword': 'Change password',
  'privacyPolicy': 'Privacy policy',
  'money': 'Money',
  'categoriesBudgets': 'Categories & budgets',
  'receipts': 'Receipts',
  'monthlyRecap': 'Monthly recap',
  'monthInReview': 'Your {month} in review',
  'exportData': 'Export my data',
  'appearance': 'Appearance',
  'theme': 'Theme',
  'themeAuto': 'Auto',
  'themeLight': 'Light',
  'themeDark': 'Dark',
  'language': 'Language',
  'signOut': 'Sign out',
  'signOutQ': 'Sign out?',
  'signOutBody': 'Your data stays safe in your account.',
  'deleteAccount': 'Delete account',
  'privacySecurity': 'Privacy & security',
  'appLock': 'App lock',
  'appLockSub': 'Fingerprint or phone PIN to open SplitMate',
  'appLockNoDevice': 'Set a screen lock on your phone first',
  'appLockOn': 'App lock is on',
  'appLockOff': 'App lock is off',
  'crashReports': 'Send crash reports',
  'crashReportsSub': 'Helps fix bugs. No names, emails or amounts.',
  'lockedTitle': 'SplitMate is locked',
  'lockedBody': 'Unlock with your fingerprint or phone PIN.',
  'unlock': 'Unlock',
  'unlockReason': 'Unlock SplitMate',
  'getStarted': 'Get started',
  'getStartedBody': 'Three steps and you\'re splitting bills with friends.',
  'stepGroup': 'Create a group',
  'stepGroupSub': 'Flatmates, a trip, office lunches',
  'stepExpense': 'Add your first expense',
  'stepExpenseSub': 'Dinner, cab, groceries: who paid and for whom',
  'stepInvite': 'Invite your friends',
  'stepInviteSub': 'Share the link on WhatsApp',
  'allDone': 'You\'re all set',
  'hideGuide': 'Hide',
};

const Map<String, String> _hi = {
  'navHome': 'होम',
  'navGroups': 'ग्रुप',
  'navFriends': 'दोस्त',
  'navProfile': 'प्रोफ़ाइल',
  'ok': 'ठीक है',
  'cancel': 'रद्द करें',
  'save': 'सेव करें',
  'close': 'बंद करें',
  'edit': 'बदलें',
  'more': 'और',
  'search': 'खोजें',
  'today': 'आज',
  'yesterday': 'कल',
  'pickDate': 'तारीख़ चुनें',
  'takePhoto': 'फ़ोटो लें',
  'chooseGallery': 'गैलरी से चुनें',
  'noMatches': 'कुछ नहीं मिला',
  'decline': 'मना करें',
  'accept': 'मंज़ूर करें',
  'join': 'जुड़ें',
  'youOwe': 'आपको देना है',
  'youAreOwed': 'आपको मिलना है',
  'settled': 'चुकता',
  'allSettledUp': 'सब चुकता',
  'youOweAmount': 'आपको {amount} देना है',
  'youAreOwedAmount': 'आपको {amount} मिलना है',
  'owedAmount': '{amount} मिलना है',
  'youreAllSettled': 'आपका सब चुकता है',
  'addExpense': 'ख़र्च जोड़ें',
  'you': 'आप',
  'youLent': 'आपने दिए',
  'youBorrowed': 'आपको देने हैं',
  'yourShare': 'आपका हिस्सा',
  'notInvolved': 'शामिल नहीं',
  'namePaid': '{name} ने {amount} भरे',
  'notifications': 'सूचनाएँ',
  'greetLate': 'देर तक जाग रहे हैं',
  'greetMorning': 'सुप्रभात',
  'greetAfternoon': 'नमस्ते',
  'greetEvening': 'शुभ संध्या',
  'spentIn': '{month} में ख़र्च',
  'startTracking': 'अपना ख़र्च लिखना शुरू करें',
  'startTrackingBody': 'पहला ख़र्च जोड़ें। चार्ट, बजट और ट्रेंड यहाँ अपने आप दिखेंगे।',
  'nothingThisPeriod': 'इस दौरान कोई ख़र्च नहीं',
  'trends': 'ट्रेंड',
  'vsLastMonth': 'पिछले महीने से {pct}',
  'last6Months': 'पिछले 6 महीने',
  'expenses': 'ख़र्च',
  'noExpensesYet': 'अभी कोई ख़र्च नहीं',
  'noExpensesToday': 'आज कोई ख़र्च नहीं',
  'tryAnotherRange': 'कोई और समय चुनें या अभी ख़र्च जोड़ें।',
  'rangeAllTime': 'अब तक',
  'rangeWeek': 'इस हफ़्ते',
  'rangeMonth': 'इस महीने',
  'rangeCustom': 'अपनी तारीख़ें',
  'chooseDates': 'तारीख़ें चुनें',
  'allCategories': 'सब',
  'manage': 'संभालें',
  'budgets': 'बजट',
  'setBudget': 'महीने का बजट तय करें',
  'setBudgetBody': '80% पर और बजट पार होने पर याद दिलाएँगे',
  'recapReady': 'आपका {month} का हिसाब तैयार है',
  'recapBody': 'देखें पैसा कहाँ गया',
  'newExpense': 'नया ख़र्च',
  'newRecurring': 'नया दोहराने वाला ख़र्च',
  'editExpense': 'ख़र्च बदलें',
  'editRecurring': 'दोहराने वाला ख़र्च बदलें',
  'whatFor': 'किस चीज़ पर?',
  'addDescription': 'छोटा सा विवरण लिखें',
  'category': 'श्रेणी',
  'autoPicked': 'अपने आप चुना',
  'newLabel': 'नया',
  'date': 'तारीख़',
  'startsOn': 'शुरू होगा',
  'repeatExpense': 'यह ख़र्च दोहराएँ',
  'repeatHint': 'किराया, सब्सक्रिप्शन, बिल…',
  'notes': 'नोट',
  'addNote': 'नोट जोड़ें',
  'saveExpense': 'ख़र्च सेव करें',
  'saveChanges': 'बदलाव सेव करें',
  'setUpRecurring': 'दोहराना शुरू करें',
  'addReceipt': 'रसीद जोड़ें',
  'attachReceipt': 'रसीद लगाएँ',
  'receiptAttached': 'रसीद लगी है',
  'expenseAdded': 'ख़र्च जुड़ गया',
  'changesSaved': 'बदलाव सेव हो गए',
  'description': 'विवरण',
  'paidBy': 'किसने भरा',
  'split': 'बँटवारा',
  'splitEqual': 'बराबर',
  'splitShares': 'हिस्से',
  'splitExact': 'सटीक',
  'splitItems': 'चीज़ें',
  'scanBill': 'बिल स्कैन करें',
  'otherCurrency': 'किसी और करेंसी में भरा?',
  'notesOptional': 'नोट (ज़रूरी नहीं)',
  'groups': 'ग्रुप',
  'joinWithCode': 'कोड से जुड़ें',
  'invitations': 'न्योते',
  'noGroupsYet': 'अभी कोई ग्रुप नहीं',
  'noGroupsBody': 'फ़्लैट, ट्रिप या ऑफ़िस लंच के लिए ग्रुप बनाएँ, या कोड से जुड़ें।',
  'createGroup': 'ग्रुप बनाएँ',
  'yourGroups': 'आपके ग्रुप',
  'newGroup': 'नया ग्रुप',
  'noOneOwes': 'किसी का किसी पर कुछ बाकी नहीं। बढ़िया।',
  'tabExpenses': 'ख़र्च',
  'tabBalances': 'हिसाब',
  'tabStats': 'आँकड़े',
  'tabMembers': 'सदस्य',
  'activity': 'गतिविधि',
  'shareInvite': 'न्योता भेजें',
  'exportPdf': 'PDF बनाएँ',
  'recurringExpenses': 'दोहराने वाले ख़र्च',
  'tripSummary': 'ट्रिप का हिसाब',
  'makeItTrip': 'इसे ट्रिप बनाएँ',
  'tripSettings': 'ट्रिप की तारीख़ें और करेंसी',
  'renameGroup': 'ग्रुप का नाम बदलें',
  'leaveGroup': 'ग्रुप छोड़ें',
  'deleteGroup': 'ग्रुप मिटाएँ',
  'searchGroup': 'इस ग्रुप में खोजें',
  'groupEmptyBody': '"ख़र्च जोड़ें" दबाएँ, {group} में सबको तुरंत दिखेगा।',
  'overallOwed': 'कुल मिलाकर आपको मिलना है',
  'overallOwe': 'कुल मिलाकर आपको देना है',
  'whoOwesWhom': 'किसे किसको देना है',
  'fewestPayments': 'सबसे कम लेन-देन',
  'simplify': 'आसान करें',
  'simplifyHelp': 'पूरा ग्रुप चुकता करने के लिए सबसे कम लेन-देन। हो सकता है किसी को ऐसे व्यक्ति को पैसे देने पड़ें जिसके साथ सीधा ख़र्च नहीं था।',
  'directHelp': 'जिन ख़र्चों में आप सच में साथ थे, उनका सीधा हिसाब। इन्हें चुकाने से सबका निजी हिसाब सही रहता है।',
  'allSettledUpParty': 'सब चुकता',
  'nobodyOwes': 'इस ग्रुप में किसी का कुछ बाकी नहीं।',
  'betweenOthers': 'दूसरों के बीच',
  'youOweName': 'आपको {name} को देना है',
  'nameOwesYou': '{name} को आपको देना है',
  'nameOwesName': '{a} को {b} को देना है',
  'payViaUpi': 'UPI से भरें',
  'showMyQr': 'मेरा UPI QR दिखाएँ',
  'remind': 'याद दिलाएँ',
  'record': 'दर्ज करें',
  'received': 'मिल गया',
  'shareBalances': 'हिसाब भेजें',
  'allCaughtUp': 'सब पढ़ लिया',
  'markAllRead': 'सब पढ़ा हुआ करें',
  'clearAll': 'सब हटाएँ',
  'clearAllQ': 'सारी सूचनाएँ हटाएँ?',
  'clearAllBody': 'ये आपके इनबॉक्स से हट जाएँगी।',
  'notifEmptyBody': 'ख़र्च, भुगतान और न्योते यहाँ दिखेंगे।',
  'friends': 'दोस्त',
  'addFriend': 'दोस्त जोड़ें',
  'yourFriendCode': 'आपका फ़्रेंड कोड',
  'friendCode': 'फ़्रेंड कोड',
  'settledLower': 'चुकता',
  'owesYouLower': 'आपको मिलेंगे',
  'youOweLower': 'आपको देने हैं',
  'shareCodeHint': 'भेजें ताकि दोस्त आपको जोड़ सकें',
  'requests': 'रिक्वेस्ट',
  'yourFriends': 'आपके दोस्त',
  'searchFriends': 'दोस्त खोजें',
  'noFriendsYet': 'अभी कोई दोस्त नहीं',
  'noFriendsBody': 'साथ में ख़र्च बाँटने के लिए दोस्तों को उनके कोड से जोड़ें।',
  'addAFriend': 'दोस्त जोड़ें',
  'sentRequests': 'भेजी गई रिक्वेस्ट',
  'waitingAccept': 'उनके मंज़ूर करने का इंतज़ार',
  'sendRequest': 'रिक्वेस्ट भेजें',
  'profile': 'प्रोफ़ाइल',
  'statGroups': 'ग्रुप',
  'statFriends': 'दोस्त',
  'statThisMonth': 'इस महीने',
  'account': 'खाता',
  'personalInfo': 'निजी जानकारी',
  'personalInfoSub': 'नाम, फ़्रेंड कोड, UPI ID',
  'changePassword': 'पासवर्ड बदलें',
  'privacyPolicy': 'प्राइवेसी पॉलिसी',
  'money': 'पैसा',
  'categoriesBudgets': 'श्रेणियाँ और बजट',
  'receipts': 'रसीदें',
  'monthlyRecap': 'महीने का हिसाब',
  'monthInReview': 'आपका {month}',
  'exportData': 'मेरा डेटा निकालें',
  'appearance': 'दिखावट',
  'theme': 'थीम',
  'themeAuto': 'अपने आप',
  'themeLight': 'हल्की',
  'themeDark': 'गहरी',
  'language': 'भाषा',
  'signOut': 'साइन आउट',
  'signOutQ': 'साइन आउट करें?',
  'signOutBody': 'आपका डेटा आपके खाते में सुरक्षित रहेगा।',
  'deleteAccount': 'खाता मिटाएँ',
  'privacySecurity': 'प्राइवेसी और सुरक्षा',
  'appLock': 'ऐप लॉक',
  'appLockSub': 'SplitMate खोलने के लिए फ़िंगरप्रिंट या फ़ोन का PIN',
  'appLockNoDevice': 'पहले फ़ोन पर स्क्रीन लॉक लगाएँ',
  'appLockOn': 'ऐप लॉक चालू है',
  'appLockOff': 'ऐप लॉक बंद है',
  'crashReports': 'क्रैश रिपोर्ट भेजें',
  'crashReportsSub': 'गड़बड़ियाँ ठीक करने में मदद। कोई नाम, ईमेल या रकम नहीं।',
  'lockedTitle': 'SplitMate लॉक है',
  'lockedBody': 'फ़िंगरप्रिंट या फ़ोन के PIN से खोलें।',
  'unlock': 'खोलें',
  'unlockReason': 'SplitMate खोलें',
  'getStarted': 'शुरू करें',
  'getStartedBody': 'तीन क़दम और आप दोस्तों के साथ बिल बाँटने लगेंगे।',
  'stepGroup': 'ग्रुप बनाएँ',
  'stepGroupSub': 'फ़्लैटमेट, ट्रिप, ऑफ़िस लंच',
  'stepExpense': 'पहला ख़र्च जोड़ें',
  'stepExpenseSub': 'डिनर, कैब, राशन: किसने भरा और किसके लिए',
  'stepInvite': 'दोस्तों को बुलाएँ',
  'stepInviteSub': 'WhatsApp पर लिंक भेजें',
  'allDone': 'सब तैयार है',
  'hideGuide': 'छिपाएँ',
};

const Map<String, String> _hinglish = {
  'navHome': 'Home',
  'navGroups': 'Groups',
  'navFriends': 'Dost',
  'navProfile': 'Profile',
  'ok': 'OK',
  'cancel': 'Cancel',
  'save': 'Save karo',
  'close': 'Band karo',
  'edit': 'Edit',
  'more': 'Aur',
  'search': 'Search',
  'today': 'Aaj',
  'yesterday': 'Kal',
  'pickDate': 'Date chuno',
  'takePhoto': 'Photo lo',
  'chooseGallery': 'Gallery se chuno',
  'noMatches': 'Kuch nahi mila',
  'decline': 'Mana karo',
  'accept': 'Accept karo',
  'join': 'Join karo',
  'youOwe': 'Aapko dena hai',
  'youAreOwed': 'Aapko milna hai',
  'settled': 'Settled',
  'allSettledUp': 'Sab settle ho gaya',
  'youOweAmount': 'Aapko {amount} dena hai',
  'youAreOwedAmount': 'Aapko {amount} milna hai',
  'owedAmount': '{amount} milna hai',
  'youreAllSettled': 'Aapka sab settle hai',
  'addExpense': 'Kharcha jodo',
  'you': 'Aap',
  'youLent': 'aapne diye',
  'youBorrowed': 'aapko dene hain',
  'yourShare': 'aapka hissa',
  'notInvolved': 'shaamil nahi',
  'namePaid': '{name} ne {amount} pay kiye',
  'notifications': 'Notifications',
  'greetLate': 'Late tak jaag rahe ho',
  'greetMorning': 'Good morning',
  'greetAfternoon': 'Namaste',
  'greetEvening': 'Good evening',
  'spentIn': '{month} MEIN KHARCHA',
  'startTracking': 'Apna kharcha track karna shuru karo',
  'startTrackingBody': 'Pehla kharcha jodo. Charts, budget aur trends yahan apne aap dikhenge.',
  'nothingThisPeriod': 'Is time mein koi kharcha nahi',
  'trends': 'Trends',
  'vsLastMonth': 'Pichhle mahine se {pct}',
  'last6Months': 'Pichhle 6 mahine',
  'expenses': 'Kharche',
  'noExpensesYet': 'Abhi koi kharcha nahi',
  'noExpensesToday': 'Aaj koi kharcha nahi',
  'tryAnotherRange': 'Koi aur time chuno ya abhi kharcha jodo.',
  'rangeAllTime': 'All time',
  'rangeWeek': 'Is hafte',
  'rangeMonth': 'Is mahine',
  'rangeCustom': 'Custom',
  'chooseDates': 'Dates chuno',
  'allCategories': 'Sab',
  'manage': 'Manage',
  'budgets': 'Budget',
  'setBudget': 'Monthly budget set karo',
  'setBudgetBody': '80% pe aur budget cross hone pe yaad dilayenge',
  'recapReady': 'Aapka {month} ka recap ready hai',
  'recapBody': 'Dekho paisa kahan gaya',
  'newExpense': 'Naya kharcha',
  'newRecurring': 'Naya repeat kharcha',
  'editExpense': 'Kharcha edit karo',
  'editRecurring': 'Repeat kharcha edit karo',
  'whatFor': 'Kis cheez pe?',
  'addDescription': 'Chhota sa description likho',
  'category': 'Category',
  'autoPicked': 'Auto-picked',
  'newLabel': 'Naya',
  'date': 'Date',
  'startsOn': 'Shuru hoga',
  'repeatExpense': 'Ye kharcha repeat karo',
  'repeatHint': 'Rent, subscriptions, bills…',
  'notes': 'Notes',
  'addNote': 'Note jodo',
  'saveExpense': 'Kharcha save karo',
  'saveChanges': 'Changes save karo',
  'setUpRecurring': 'Repeat set karo',
  'addReceipt': 'Receipt jodo',
  'attachReceipt': 'Receipt lagao',
  'receiptAttached': 'Receipt lag gayi',
  'expenseAdded': 'Kharcha jud gaya',
  'changesSaved': 'Changes save ho gaye',
  'description': 'Description',
  'paidBy': 'Kisne pay kiya',
  'split': 'Split',
  'splitEqual': 'Barabar',
  'splitShares': 'Hisse',
  'splitExact': 'Exact',
  'splitItems': 'Items',
  'scanBill': 'Bill scan karo',
  'otherCurrency': 'Kisi aur currency mein pay kiya?',
  'notesOptional': 'Notes (optional)',
  'groups': 'Groups',
  'joinWithCode': 'Code se join karo',
  'invitations': 'Invitations',
  'noGroupsYet': 'Abhi koi group nahi',
  'noGroupsBody': 'Flat, trip ya office lunch ke liye group banao, ya code se join karo.',
  'createGroup': 'Group banao',
  'yourGroups': 'Aapke groups',
  'newGroup': 'Naya group',
  'noOneOwes': 'Kisi ka kisi pe kuch baaki nahi. Badhiya.',
  'tabExpenses': 'Kharche',
  'tabBalances': 'Hisaab',
  'tabStats': 'Stats',
  'tabMembers': 'Members',
  'activity': 'Activity',
  'shareInvite': 'Invite bhejo',
  'exportPdf': 'PDF banao',
  'recurringExpenses': 'Repeat kharche',
  'tripSummary': 'Trip summary',
  'makeItTrip': 'Ise trip banao',
  'tripSettings': 'Trip dates aur currency',
  'renameGroup': 'Group ka naam badlo',
  'leaveGroup': 'Group chhodo',
  'deleteGroup': 'Group delete karo',
  'searchGroup': 'Is group mein search karo',
  'groupEmptyBody': '"Kharcha jodo" dabao, {group} mein sabko turant dikhega.',
  'overallOwed': 'Total mein aapko milna hai',
  'overallOwe': 'Total mein aapko dena hai',
  'whoOwesWhom': 'Kisko kisko dena hai',
  'fewestPayments': 'Sabse kam payments',
  'simplify': 'Simplify',
  'simplifyHelp': 'Poora group settle karne ke liye sabse kam payments. Ho sakta hai kisi ko aise insaan ko pay karna pade jiske saath seedha kharcha nahi tha.',
  'directHelp': 'Jin kharchon mein aap sach mein saath the, unka seedha hisaab. Inhe settle karne se sabka personal hisaab sahi rehta hai.',
  'allSettledUpParty': 'Sab settle ho gaya',
  'nobodyOwes': 'Is group mein kisi ka kuch baaki nahi.',
  'betweenOthers': 'Doosron ke beech',
  'youOweName': 'Aapko {name} ko dena hai',
  'nameOwesYou': '{name} ko aapko dena hai',
  'nameOwesName': '{a} ko {b} ko dena hai',
  'payViaUpi': 'UPI se pay karo',
  'showMyQr': 'Mera UPI QR dikhao',
  'remind': 'Yaad dilao',
  'record': 'Record karo',
  'received': 'Mil gaya',
  'shareBalances': 'Hisaab share karo',
  'allCaughtUp': 'Sab padh liya',
  'markAllRead': 'Sab read mark karo',
  'clearAll': 'Sab hatao',
  'clearAllQ': 'Saare notifications hatayein?',
  'clearAllBody': 'Ye aapke inbox se hat jayenge.',
  'notifEmptyBody': 'Kharche, payments aur invites yahan dikhenge.',
  'friends': 'Dost',
  'addFriend': 'Dost jodo',
  'yourFriendCode': 'AAPKA FRIEND CODE',
  'friendCode': 'Friend code',
  'settledLower': 'settled',
  'owesYouLower': 'aapko milenge',
  'youOweLower': 'aapko dene hain',
  'shareCodeHint': 'Share karo taaki dost aapko jod sakein',
  'requests': 'Requests',
  'yourFriends': 'Aapke dost',
  'searchFriends': 'Dost search karo',
  'noFriendsYet': 'Abhi koi dost nahi',
  'noFriendsBody': 'Saath mein kharcha baantne ke liye doston ko unke code se jodo.',
  'addAFriend': 'Dost jodo',
  'sentRequests': 'Bheji gayi requests',
  'waitingAccept': 'Unke accept karne ka intezaar',
  'sendRequest': 'Request bhejo',
  'profile': 'Profile',
  'statGroups': 'Groups',
  'statFriends': 'Dost',
  'statThisMonth': 'Is mahine',
  'account': 'Account',
  'personalInfo': 'Personal info',
  'personalInfoSub': 'Naam, friend code, UPI ID',
  'changePassword': 'Password badlo',
  'privacyPolicy': 'Privacy policy',
  'money': 'Paisa',
  'categoriesBudgets': 'Categories aur budget',
  'receipts': 'Receipts',
  'monthlyRecap': 'Monthly recap',
  'monthInReview': 'Aapka {month} ek nazar mein',
  'exportData': 'Mera data export karo',
  'appearance': 'Look',
  'theme': 'Theme',
  'themeAuto': 'Auto',
  'themeLight': 'Light',
  'themeDark': 'Dark',
  'language': 'Bhasha',
  'signOut': 'Sign out',
  'signOutQ': 'Sign out karein?',
  'signOutBody': 'Aapka data aapke account mein safe rahega.',
  'deleteAccount': 'Account delete karo',
  'privacySecurity': 'Privacy aur security',
  'appLock': 'App lock',
  'appLockSub': 'SplitMate kholne ke liye fingerprint ya phone PIN',
  'appLockNoDevice': 'Pehle phone pe screen lock lagao',
  'appLockOn': 'App lock on hai',
  'appLockOff': 'App lock off hai',
  'crashReports': 'Crash reports bhejo',
  'crashReportsSub': 'Bugs theek karne mein madad. Koi naam, email ya amount nahi.',
  'lockedTitle': 'SplitMate lock hai',
  'lockedBody': 'Fingerprint ya phone PIN se kholo.',
  'unlock': 'Unlock karo',
  'unlockReason': 'SplitMate kholo',
  'getStarted': 'Shuru karo',
  'getStartedBody': 'Teen steps aur aap doston ke saath bill baantne lagoge.',
  'stepGroup': 'Group banao',
  'stepGroupSub': 'Flatmates, trip, office lunch',
  'stepExpense': 'Pehla kharcha jodo',
  'stepExpenseSub': 'Dinner, cab, ration: kisne pay kiya aur kiske liye',
  'stepInvite': 'Doston ko bulao',
  'stepInviteSub': 'WhatsApp pe link bhejo',
  'allDone': 'Sab set hai',
  'hideGuide': 'Chhupao',
};
