# SplitMate — Product Requirements Document (v2.0 "Aurora")

> Status: **In development** · Branch: `redesign/aurora` · Owner: Arham · Last updated: 2026-11-15
> Companion docs: [PROGRESS.md](PROGRESS.md) · [AUDIT.md](AUDIT.md) · [DESIGN_SYSTEM.md](DESIGN_SYSTEM.md)

---

## 1. Vision

SplitMate is a personal expense tracker plus a group bill splitter in one app. Version 2 has three aims:

- Make every flow **correct**: no wrong balances, no broken navigation, no data leaks.
- Make the app **delightful**, so it feels alive, friendly and modern instead of a strict "ledger terminal".
- Add a few high-value features that people use every week.

**Design north star:** "Money, minus the stress." Use soft gradients and friendly language, give instant feedback, celebrate when debts clear, and make the important numbers obvious at a glance.

## 2. Target users

| Persona | Need |
|---|---|
| **Hostel / flatmates** (primary) | Split rent, groceries and outings. Know who owes whom. Settle quickly over UPI. |
| **Trip groups** | Add many expenses fast, use itemized bills, and settle once at the end. |
| **Solo tracker** | Log daily spend, stay within category budgets, and see monthly trends. |

## 3. Platform & constraints

- Flutter (Android first, iOS supported), Riverpod, GoRouter, Firebase Auth and Cloud Firestore.
- **Firebase Spark (free) plan only.** There are no Cloud Functions, Firebase Storage or push messaging. All business logic runs on the client. Receipts and avatars are stored as compressed base64 in **separate** Firestore docs.
- Currency is INR (₹) with en_IN grouping.
- Must stay backward compatible with existing Firestore data. Readers accept the old shapes: numeric splits, category names and inline receipts.

## 4. Information architecture

```
Bottom navigation (StatefulShellRoute — tab state preserved)
├── Home        personal dashboard, trends, budgets, expense list
├── Groups      overview, invites, group cards → Group detail (tabs)
├── Friends     my code, requests, friends with balances
└── Profile     settings, theme, categories, recurring, receipts, export

Global: Search · Notifications · Add expense (root-level full-screen forms)
```

### Group detail tabs
**Expenses** · **Balances** (settle up) · **Stats** · **Members**

## 5. Feature specification

### 5.1 Authentication
- Email/password signup with a verification email, sent **once**. Users can also sign in with Google; this requires accepting the Terms.
- **Forgot password** sends a real reset email.
- A splash screen shows while the session restores. Deep links (group invites) survive the login and verify steps through `?from=`.
- Errors are shown in friendly language (for example "Wrong password, try again"), never as raw Firebase strings.
- **Acceptance:** an invite link opened while logged out lands on the Join screen after login.

### 5.2 Personal expenses
- Add or edit an expense with: amount (validated, max 2 decimals), description (required), category, date (no future dates; quick picks Today and Yesterday), notes, optional receipt and optional recurrence.
- Tapping an expense opens the **Expense detail sheet**, which offers Edit and Delete.
- Swipe to delete is optimistic, with **Undo**.
- **Home** shows:
  - A gradient hero card: spent this month, the trend against last month, and "You're owed / You owe" across all groups.
  - Budget rings.
  - Range chips: Today, Week, Month or Custom.
  - Category chips.
  - A distribution chart (bar or donut).
  - A trends section (last 6 months).
  - A day-grouped list.
- **Acceptance:** totals match the list. Changing tabs keeps the selected filters. Offline adds appear instantly and sync later.

### 5.3 Categories & budgets *(new: budgets)*
- Create, edit and delete categories with a name, icon, colour and an optional **monthly budget**.
- Duplicate names are blocked. Deleting a category moves its expenses to "Other".
- Budget rings on Home: amber at ≥80% and coral at ≥100%. A toast appears when a save crosses a threshold.
- **Acceptance:** renaming a category updates every expense that uses it, because expenses reference the category id.

### 5.4 Recurring expenses
- Weekly or monthly templates, for personal and group expenses.
- Instances are generated on launch:
  - one per missed period, up to 12;
  - each dated on its due date;
  - month-end safe (Jan 31 → Feb 28);
  - deduplicated across devices and members with deterministic ids.
- Templates can be paused, resumed and edited. Editing never creates a duplicate.

### 5.5 Friends
- Every user has a unique 6-character code (no look-alike characters). Codes can be copied and shared.
- Add a friend by code. If both people have already sent each other a request, it is accepted automatically.
- Accept or decline incoming requests. Cancel outgoing requests. Unfriend.
- Nicknames, shown everywhere in the app.
- Each friend card shows the **pairwise** net balance across shared groups.

### 5.6 Groups
- Create a group: name plus friends to invite. Invites are written in one batch, and the app opens the new group afterwards.
- Join by code (case-insensitive) or by deep link `splitmate://join?groupId=…&code=…`.
- Admins can rename the group, rotate the invite code, promote or demote members, remove members and delete the group.
- The last admin cannot leave without promoting someone else.
- When a member is removed, leaves, or the group is deleted while balances are outstanding, a warning shows the amount.

### 5.7 Group expenses & splits
- Split modes: **Equal**, **Exact amounts**, **Percent** and **Itemized**.
- A live "₹X left to assign" meter. Negative values are rejected, and every itemized item must be assigned to someone.
- In an equal split, any rounding remainder goes to the payer if the payer participates; otherwise it goes to the first participant.
- An edit **replaces** the splits entirely; old splits are never merged in. The edit keeps the date, the recurrence and the settled flags of shares that didn't change.
- Edits and deletes notify group members and are recorded in the activity log with a readable diff.

### 5.8 Settle up *(redesigned + new UPI)*
- The **Balances** tab shows real pairwise balances. "Simplify debts" is an optional suggestion view.
- **Record payment:**
  - The amount is editable, so partial payments work.
  - The write is one atomic batch: the payment doc, the split flags for **only that pair**, and an activity entry.
  - Double taps are guarded.
- The creditor can **Mark as received**.
- **Pay via UPI** *(new)*: if the creditor has saved a UPI ID, the app opens the user's UPI app (GPay, PhonePe or Paytm) with the amount and note prefilled. When the user returns, the app asks "Did it go through?" and offers to record the payment. The app never moves money itself.
- **Remind**: sends an in-app nudge, at most once every 24 hours per pair.
- **Confetti** plays when a balance reaches ₹0.

### 5.9 Personal mirroring of group shares
- Your own share of a group expense appears in your personal ledger:
  - **immediately** if you paid it;
  - **after settlement** if you owed it.
- Mirrors carry the original expense date and category.
- Deleting the group expense hides the mirrors. A mirror you deleted yourself is never brought back.

### 5.10 Search & expense details *(new)*
- Global search across personal and group expenses: text, category, group, amount and date range.
- The **Expense detail sheet** shows payer, split per member (with settled ticks), receipt, notes and the activity history for that expense. Edit and Delete appear only to people allowed to use them.

### 5.11 Notifications (single UI)
- A bell with an unread badge on Home and a single Notifications screen.
- Each notification type opens the right place: expense → detail, payment → Balances, friend request → Friends. Notifications about a group you were removed from, or a group that was deleted, show an info sheet.
- Notifications can be marked read, marked all read, deleted or cleared. The list keeps the latest 100.

### 5.12 Monthly recap & export *(new)*
- A **"Your November"** animated recap with:
  - the month's total and the change from last month;
  - top category;
  - biggest expense;
  - busiest day;
  - no-spend-day streak.
- The recap can be shared as an image.
- Personal **CSV and PDF export** for any date range. The existing group PDF export is kept.

### 5.13 Profile & settings
- Avatar: a compressed photo, visible to friends.
- Name, email, friend code, **UPI ID**.
- Theme: System, Light or Dark.
- Shortcuts to Categories & Budgets, Recurring, Receipts vault, Export, Notifications, and Change/Reset password.
- Logout asks for confirmation, then clears cached data.

## 6. Flows removed or merged (approved)

| Removed / merged | Replaced by |
|---|---|
| Personal Insights screen | Trends section on Home |
| Group Insights screen + Spending Breakdown card + payer ranking | Group **Stats** tab |
| Settlement screen + "Debts to settle" card | Group **Balances** tab |
| Groups-tab notification bottom sheet | Single Notifications screen |
| 2,000-line single-scroll group screen | 4 tabs |
| "Primary currency" setting (did nothing) | Removed |
| Fake login badge, footer links, copyright | Removed |
| "Receipt Total" duplicate, fake pull-to-refresh | Removed |
| Stub files: `friend_repository.dart`, `group_repository.dart`, `add_friend_screen.dart`, `balance_model.dart`, `primary_button.dart`, `constants.dart` | Deleted |
| 3 copies of the "add friend by code" dialog | One `AddFriendByCodeSheet` |

## 7. Non-functional requirements

- **Correctness:**
  - Balances in every group always sum to 0 (±₹0.01).
  - All split and settlement math has unit tests.
- **Security:** Firestore rules are hardened.
  - Only members can read or write a group.
  - Only admins can change admin-only fields.
  - Users can only add themselves to a group, and only with the invite code.
  - Notifications are visible only to their recipient.
  - Friendship cannot be forced.
- **Offline:** writes never leave a spinner hanging. After 3 seconds the UI says "Saved — will sync".
- **Performance:**
  - Lists don't download receipt images.
  - Providers auto-dispose.
  - The mirror scan is incremental.
- **Accessibility:**
  - Minimum font size 12, and text scales with the system setting.
  - Tap targets are at least 44px.
  - Contrast meets WCAG AA in both themes.
  - Animations respect the system "reduce motion" setting.
- **Quality gates:** `flutter analyze` reports 0 issues, `flutter test` passes, and the release APK builds.

## 8. Out of scope (future)

- Push notifications: these need Cloud Functions or the Blaze plan.
- Multi-currency conversion (spec §11).
- Real payment confirmation from the UPI app; the user confirms manually.
- A web build.
