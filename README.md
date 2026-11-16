# 💸 SplitMate — track spending, split bills, stay friends

SplitMate is a Flutter + Firebase app that combines a **personal expense tracker** with **group bill splitting**. It shows who owes whom, lets people settle up over UPI, and copies each person's share of group expenses into their personal ledger.

**v2 "Aurora"** is a full rebuild:
- Fixes roughly 150 audited issues, including several that produced wrong balances.
- Hardens the security rules.
- Adds a new animated light and dark design, plus budgets, UPI settle-up, search and monthly recaps.

> 📄 Docs: [PRD](PRD.md) · [Progress log](PROGRESS.md) · [Audit findings](AUDIT.md) · [Design system](DESIGN_SYSTEM.md)

---

## ✨ Features

### Personal
- **Home dashboard:** a gradient hero card (this month's spend, trend vs last month, what you're owed and what you owe), budget rings, a category donut, 6-month trends and a day-grouped expense list.
- **Expenses:** add, edit and delete, with Undo. Each expense can have a category, a back-dated date (never in the future), notes, a receipt photo, and weekly or monthly repeats.
- **Categories and budgets:** custom icons and colours, a monthly budget per category, and alerts at 80% and 100%.
- **Search** across personal and group expenses, plus a detail sheet for every expense.
- **Monthly recap:** a story-style summary of your month that you can share as an image.
- **Export:** CSV and PDF for any date range.

### Groups
- Create a group and invite friends, or join with a 6-character code or an invite link (`splitmate://join?code=…`).
- **Four split modes:** Equal, Exact, Percent and Itemized. A live "₹X left to assign" meter shows what's still unassigned, and all maths is done in exact paise.
- **Balances tab:** shows direct who-owes-whom balances, with an optional "Simplify debts" view.
- **Settle up:**
  - Partial payments.
  - "Pay via UPI", which opens GPay, PhonePe or Paytm with the amount filled in.
  - Mark as received.
  - Reminders, limited to one per day.
  - Confetti when a debt reaches ₹0 🎉
- **Stats tab:** categories, trends, and what each member paid vs. their share.
- **Members tab:** roles (promote or demote), remove a member, generate a new invite code, and add members as friends.
- **Activity timeline** with a readable record of each edit; members are notified of edits and deletes.
- **PDF report** for the whole group.

### Friends and notifications
- Friend codes with no look-alike characters, so they're easy to read out. A mutual request is accepted automatically. You can cancel a sent request, unfriend someone, and set nicknames that only you see.
- Each friend shows your direct balance with them across all shared groups.
- One notifications inbox, where each notification opens the right screen.

### Design
- **Midnight Aurora:** violet-to-cyan gradients, glass navigation bar, rounded cards and the Plus Jakarta Sans font. Light and dark themes, with the choice saved.
- Staggered entrance animations, numbers that count up, shimmer loading placeholders, haptic feedback and confetti.
- Respects the system "reduce motion" setting.

---

## 🛠 Tech stack

| Area | Packages |
|---|---|
| UI | Flutter 3.50 · `material_ui` · `cupertino_ui` · `google_fonts` · `flutter_animate` · `animations` · `shimmer` · `confetti` · `fl_chart` |
| State & navigation | `flutter_riverpod` · `go_router` (with `StatefulShellRoute`) |
| Backend | Firebase Auth (email and Google) · Cloud Firestore, on the free Spark plan (no Cloud Functions or Storage) |
| Other | `app_links` (deep links) · `url_launcher` (UPI) · `share_plus` · `pdf` · `image_picker` · `shared_preferences` |

All business logic runs on the device:
- `lib/core/domain/` contains pure, unit-tested code: the split calculator, settlement and pairwise balances, and recurrence rules.
- Repositories in `lib/features/*/data/` are the only code that talks to Firestore.

```text
lib/
├── core/        domain maths · router · session bootstrap · theme · utilities
├── features/    auth · home · personal_expenses · categories · groups · friends
│                notifications · profile · recurring_expenses · receipts · search · recap · export
├── shared_widgets/   cards · buttons · inputs · avatars · states · toasts · charts bits
├── app.dart / app_shell.dart / main.dart
```

---

## 🚀 Setup

1. Install dependencies.

   ```bash
   flutter pub get
   ```

2. Add your `android/app/google-services.json` (FlutterFire).

3. Deploy the security rules. No composite indexes are needed.

   ```bash
   firebase deploy --only firestore:rules
   ```

   > Deploy the rules together with the v2 app. Older v1 builds are rejected by the hardened rules.

4. Run the app.

   ```bash
   flutter run
   ```

5. Run the analyzer and tests.

   ```bash
   flutter analyze
   ```

   ```bash
   flutter test
   ```

---

## 📄 License

MIT
