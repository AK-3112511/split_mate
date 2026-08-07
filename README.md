# 💳 SplitMate — Smart Expense Tracker & Group Bill Splitting

**SplitMate** is a feature-rich, charcoal-gold dark themed Flutter application designed for seamless personal expense tracking, dynamic data visualization, and group bill splitting with automated debt settlement math.

---

## 📌 Features

### 👤 Personal Expense Tracking & Analytics
- **Net Liquidity Overview**: Live total spend metrics for Today, This Week, This Month, and All Time.
- **Custom Date & Category Filtering**: Filter transactions by custom date ranges and dynamic category tags.
- **Interactive Visualization**: Toggle between **Doughnut Pie Charts** and **Bar Charts** with category breakdowns and exact spend labels.
- **Swipe-to-Delete with UNDO**: Instant swipe removal with a 4-second Snack-bar **UNDO** restoration guard.

### 👥 Group Bill Splitting & Settlement Engine
- **Flexible Bill Splitting**: Split expenses equally, by exact custom amounts, by percentages, or using granular **Itemized** per-item member assignments.
- **Client-Side Settlement Algorithm**: Automated greedy debt minimization math calculating exact minimal transfers needed to settle up group balances.
- **Group Admin & Invite System**: Group creators can assign group admins, invite friends via 6-character connect codes (`appCode`), and manage member permissions.
- **Debt Clearance Logs**: Dedicated debt settlement activity feeds filtering payment clearance events (`settled_up`).

### 🧾 Receipt Photo Attachment & Receipts Vault
- **Receipt Upload**: Attach bill/receipt photos directly from Camera or Gallery for both Personal and Group expenses.
- **Pinch-to-Zoom Viewer**: Interactive popup modal (`InteractiveViewer`) with smooth pan and zoom controls for viewing uploaded bills.
- **Receipts Vault**: Dedicated central gallery aggregating all bill receipts across personal and group ledgers.

### 🔔 Real-Time Notifications & Anti-Spam Control
- **Payment Request Cooldown**: Real-time 24-hour anti-spam guard preventing duplicate payment request spamming (`✓ REQUESTED` button state).
- **Instant Activity Alerts**: Real-time notifications for payment requests, recorded settlements, and new group expense entries.

### 📄 PDF Report Generation & Recurring Engine
- **PDF Export**: Generate clean financial summary reports of group ledgers without double-counting debt settlement transfers.
- **Recurring Expenses**: Automated client-side engine supporting weekly and monthly recurring personal & group expense templates.

---

## 🛠️ Tech Stack

- **Frontend Framework**: [Flutter](https://flutter.dev/) (Dart)
- **State Management**: [Riverpod](https://riverpod.dev/) (`flutter_riverpod`)
- **Backend Services**: [Firebase Authentication](https://firebase.google.com/docs/auth), [Cloud Firestore](https://firebase.google.com/docs/firestore)
- **Data Visualization**: [fl_chart](https://pub.dev/packages/fl_chart)
- **Navigation / Routing**: [GoRouter](https://pub.dev/packages/go_router)
- **Media & Export**: `image_picker`, `pdf`, `path_provider`, `share_plus`
- **Typography & Icons**: Google Fonts (`Lora` & `Inter`), `cupertino_icons`

---

## 📂 Project Structure

```text
lib/
├── core/
│   ├── constants.dart              # Core app constants & styles
│   ├── theme/
│   │   └── app_theme.dart          # Charcoal-Gold theme tokens
│   └── utils/
│       ├── export_helper.dart      # PDF report generator
│       ├── firestore_helper.dart   # Firestore retry helpers
│       ├── recurring_engine.dart   # Recurring templates engine
│       └── settlement_algorithm.dart# Greedy debt minimization math
│
├── features/
│   ├── auth/                       # Auth repositories & screens
│   ├── categories/                 # Category settings & CRUD
│   ├── friends/                    # Friend connect codes & requests
│   ├── groups/                     # Group list, detail, splits, & settlement
│   ├── notifications/              # Real-time notifications & anti-spam guard
│   ├── personal_expenses/          # Personal ledger, charts, & entries
│   └── profile/                    # Personal info, receipts vault, & settings
│
├── shared_widgets/                 # Reusable UI buttons & inputs
├── app.dart                        # Root GoRouter configuration
└── main.dart                       # Firebase initialization & ProviderScope
```

---

## 🧑‍💻 Installation & Setup

Follow these steps to set up and run **SplitMate** locally on your machine:

### Prerequisites
- Install [Flutter SDK](https://docs.flutter.dev/get-started/install) (`>= 3.9.0`)
- Install [Git](https://git-scm.com/)
- Set up an Android Emulator or connect a physical Android device

### Step-by-Step Setup

1. **Clone the Repository**
   ```bash
   git clone https://github.com/<your-username>/split_mate.git
   ```

2. **Navigate to the Project Directory**
   ```bash
   cd split_mate
   ```

3. **Install Dependencies**
   ```bash
   flutter pub get
   ```

4. **Firebase Configuration**
   - Ensure `google-services.json` is placed in `android/app/google-services.json`.

5. **Run the Application**
   ```bash
   flutter run
   ```

---

## 📄 License

This project is licensed under the [MIT License](LICENSE).
