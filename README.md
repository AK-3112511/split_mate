# 💳 SplitMate — Smart Expense Tracker & Group Bill Splitting

**SplitMate** is a feature-rich, charcoal-gold dark themed Flutter application designed for seamless personal expense tracking, dynamic data visualization, and group bill splitting with automated debt settlement math.

---

## 📲 Download APK
👉 [**Download the latest APK here**](https://github.com/AK-3112511/split_mate/releases/download/v1.0.0/app-release.apk)

---

## 📌 Major Features

### 👥 1. Group Bill Splitting & Multi-Mode Splits
- **4 Split Modes**: Split expenses **Equally**, by **Exact Custom Amounts**, by **Percentages**, or using granular **Itemized** per-item member assignments.
- **Smart Remainder Distribution**: Exact cent-rounding logic automatically assigns remaining division cents to the payer.
- **Client-Side Greedy Settlement Algorithm**: Client-side minimal-transaction math calculating exact minimal transfers needed to balance group accounts ("who pays whom").
- **Pairwise Settlement & Batch Clearing**: Settle up direct individual balances between any two members, automatically marking all underlying split entries as `settled: true`.

---

### 🔄 2. Personal Ledger Synchronization & Deferred Mirroring
- **Payer & Debtor Personal Sync**: Group expenses automatically reflect in the personal expense tracker without double counting.
  - **Payer-side**: Immediate personal expense creation upon bill entry.
  - **Debtor-side**: Deferred personal expense creation (`mirror_{expenseId}`) upon settlement clearance.
- **Live Edit Mirror Sync**: Editing a group expense (amount, description, or category) instantly updates the corresponding personal ledger entry for both payer and settled debtors.

---

### 💬 3. Rich Group Activity Feed & Audit Diffs
- **Granular Change Auditing**: Real-time group activity feed detailing exact modifications made to expenses (e.g. `Arham updated "Pizza": amount ₹400.00 → ₹500.00, renamed "Momos" → "Pizza"`).
- **Member Spend Breakdown**: Displays total effective share consumed and total amount paid for every individual group member.
- **Settlement & Clearance Feeds**: Filters payment clearance events (`settled_up`) and deleted expense entries.

---

### 🤝 4. Friends System & Custom Nicknames
- **6-Character Connect Codes**: Connect with friends using unique 6-character `appCode` identifiers with single-tap clipboard copy and native system share integration.
- **Custom Nicknames**: Assign personalized nicknames to friends that resolve app-wide across member lists, split selection, and settlement screens.

---

### 👑 5. Group Admins, Invites & Real-time Notifications
- **Admin Authority & Management**: Group creators and admins can promote members to Admin, remove members, or delete groups.
- **Real-Time Group Alerts**: Automatic notifications sent to all members when a group is edited, deleted, or when members join or are removed.
- **Anti-Spam Payment Cooldown**: 24-hour rate limiting guard on payment clearance requests with `✓ REQUESTED` button state locking.

---

### 👤 6. Personal Expense Analytics & Custom Categories
- **Flexible Date Filtering**: View spending metrics for Today (Daily Fresh Reset), This Month, All Time, or Custom Date Ranges.
- **Interactive Charts**: Toggle between **Doughnut Pie Charts** and **Bar Charts** with category breakdowns and spend percentages.
- **Custom Categories**: Create, edit, and manage custom user categories with smart icon guessing.
- **Swipe-to-Delete with UNDO**: Instant swipe removal with a 4-second Snack-bar **UNDO** restoration guard.

---

### 🧾 7. Receipt Vault & PDF Export
- **Receipt Photo Attachment**: Attach bill images directly from Camera or Gallery for personal and group expenses.
- **Pinch-to-Zoom Viewer**: Interactive modal (`InteractiveViewer`) with smooth pan and zoom controls for inspecting receipts.
- **Receipts Vault**: Centralized receipt gallery aggregating all uploaded bills across personal and group ledgers.
- **PDF Report Generator**: Export clean, un-duplicated financial summary reports of group ledgers.

---

## 🛠️ Tech Stack

- **Frontend Framework**: [Flutter](https://flutter.dev/) (Dart)
- **State Management**: [Riverpod](https://riverpod.dev/) (`flutter_riverpod`)
- **Backend & Database**: [Firebase Authentication](https://firebase.google.com/docs/auth), [Cloud Firestore](https://firebase.google.com/docs/firestore)
- **Data Visualization**: [fl_chart](https://pub.dev/packages/fl_chart)
- **Navigation / Routing**: [GoRouter](https://pub.dev/packages/go_router)
- **Media & Sharing**: `image_picker`, `pdf`, `path_provider`, `share_plus`
- **Typography & Icons**: Google Fonts (`Lora` & `Inter`), `cupertino_icons`

---

## 📂 Project Structure

```text
lib/
├── core/
│   ├── theme/
│   │   └── app_theme.dart          # Charcoal-Gold theme system
│   └── utils/
│       ├── category_helper.dart    # Smart category resolver
│       ├── export_helper.dart      # PDF generator & native sharing
│       ├── firestore_helper.dart   # Firestore retry logic
│       ├── recurring_engine.dart   # Recurring expense engine
│       └── settlement_algorithm.dart# Greedy debt minimization math
│
├── features/
│   ├── auth/                       # Authentication & login repository
│   ├── categories/                 # Category management & CRUD
│   ├── friends/                    # Friend codes, nicknames, & invites
│   ├── groups/                     # Groups, splits, settlements, & mirror service
│   ├── notifications/              # Real-time notifications & anti-spam guard
│   ├── personal_expenses/          # Personal ledger, charts, & analytics
│   └── profile/                    # Profile settings & receipts vault
│
├── shared_widgets/                 # Reusable buttons, inputs, & receipt viewer
├── app.dart                        # GoRouter configuration & mirror scan trigger
└── main.dart                       # Firebase initialization
```

---

## 🧑‍💻 Installation & Setup

1. **Clone the Repository**
   ```bash
   git clone https://github.com/AK-3112511/split_mate.git
   cd split_mate
   ```

2. **Install Dependencies**
   ```bash
   flutter pub get
   ```

3. **Firebase Configuration**
   - Ensure `google-services.json` is placed in `android/app/google-services.json`.

4. **Run the Application**
   ```bash
   flutter run
   ```

---

## 📄 License

This project is licensed under the [MIT License](LICENSE).
