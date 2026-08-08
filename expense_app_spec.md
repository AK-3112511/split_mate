# SplitTrack — Master Build Spec (Flutter + Firebase)

> This is the source-of-truth spec. Feed it to Antigravity in the sequenced prompts at the bottom — not as one giant request. Each prompt references sections of this doc so the agent has consistent context every time.

---

## 1. App Overview

A Flutter expense-tracking app with two modes:
1. **Personal mode** — existing feature: log expenses into custom categories, view pie/bar charts, filter by date range.
2. **Group mode (new)** — create groups with friends, log shared expenses with flexible splits, and get an auto-computed minimum-transaction settlement ("who pays whom, how much") with zero manual math.

Target: Phase 1 MVP, real usage by an actual friend group, portfolio-quality code.

---

## 2. Tech Stack

| Layer | Choice | Why |
|---|---|---|
| Frontend | Flutter (Dart) | existing app is already Flutter |
| State management | Riverpod | testable, scales better than setState/Provider for multi-screen sync state |
| Backend | Firebase (Spark/free plan) | managed auth + real-time sync, no server to run, no billing account required |
| Auth | Firebase Auth (Email/Password + Google Sign-In) | fastest path to real login |
| Database | Cloud Firestore | real-time listeners, offline cache built in |
| Server logic | None — client-side Dart only | balance/settlement calculation runs on-device, derived live from Firestore real-time listeners; deliberately avoids Cloud Functions to stay on the free Spark plan (see Section 6) |
| Charts | `fl_chart` | already likely in use; supports pie + bar |

---

## 3. Core Packages (pubspec.yaml)

```yaml
dependencies:
  flutter:
    sdk: flutter
  firebase_core: ^3.x
  firebase_auth: ^5.x
  cloud_firestore: ^5.x
  google_sign_in: ^6.x
  flutter_riverpod: ^2.x
  fl_chart: ^0.x        # charts (already used, keep version consistent)
  intl: ^0.19.x          # date formatting
  uuid: ^4.x              # local id generation before Firestore write
  go_router: ^14.x        # navigation, needed once auth-gated routes exist
  cached_network_image: ^3.x  # for friend profile photos (Phase 2, scaffold now)
```

---

## 4. Folder Structure

```
lib/
  main.dart
  app.dart                     # MaterialApp + router setup
  core/
    theme/
    utils/
      settlement_algorithm.dart   # primary implementation — recomputeBalances + settleUp run here, client-side, no server mirror
    constants.dart
  features/
    auth/
      data/
      domain/
      presentation/
        login_screen.dart
        signup_screen.dart
    categories/
      domain/category_model.dart
      presentation/category_settings_screen.dart
    personal_expenses/
      domain/expense_model.dart
      presentation/
        expense_list_screen.dart
        add_expense_screen.dart
        charts/
          pie_chart_widget.dart
          bar_chart_widget.dart
    groups/
      domain/
        group_model.dart
        group_expense_model.dart
        balance_model.dart
      data/
        group_repository.dart
      presentation/
        group_list_screen.dart
        group_detail_screen.dart
        add_group_expense_screen.dart
        settlement_screen.dart
    friends/
      domain/friend_model.dart
      data/friend_repository.dart
      presentation/
        friends_list_screen.dart
        add_friend_screen.dart
  shared_widgets/
```

---

## 5. Firestore Data Model

```
users/{uid}
  displayName: string
  email: string
  photoUrl: string?
  categories: [ { id, name, iconCode, colorHex } ]   # user-customizable, default 5 seeded on signup

friends/{uid}/friendList/{friendUid}
  status: "pending" | "accepted"
  addedAt: timestamp

groups/{groupId}
  name: string
  createdBy: uid
  members: [uid]
  createdAt: timestamp

groups/{groupId}/expenses/{expenseId}
  payerUid: string
  amount: number
  category: string
  description: string
  splitType: "equal" | "custom" | "percentage"
  splits: { uid: amountOwed }     # always resolved to absolute amounts, even if entered as %
  createdAt: timestamp
  isDeleted: boolean               # soft delete — never hard-delete financial records

groups/{groupId}/activity/{activityId}
  type: "expense_added" | "expense_edited" | "expense_deleted" | "settled_up"
  actorUid: string
  message: string
  createdAt: timestamp
```

**Architecture rule (revised for Spark/free plan):** there is no `balances` collection anywhere in Firestore. Net balances and the settle-up payoff list are computed entirely client-side, in Dart, derived live from a real-time listener on `groups/{groupId}/expenses`. Every device independently recomputes the same result from the same shared expense data — since expense data is already visible to every group member, deriving balances from it client-side introduces no new trust or tampering risk beyond what the expenses collection itself already carries. This trades a small amount of redundant on-device computation (acceptable at small-group scale) for staying entirely on the free Spark plan with no Cloud Functions and no billing account. Revisit this decision only if the app scales to a point where redundant client-side computation becomes a real performance concern — not before.

---

## 6. Settlement Algorithm (client-side Dart, no Cloud Function)

```
function recomputeBalances(groupId):
  expenses = all non-deleted expenses in group
  netBalance = { uid: 0 for uid in group.members }

  for expense in expenses:
    netBalance[expense.payerUid] += expense.amount
    for uid, owed in expense.splits:
      netBalance[uid] -= owed

  return netBalance   # kept in memory, never written back to Firestore

function settleUp(netBalance):
  creditors = sorted people with balance > 0, descending
  debtors   = sorted people with balance < 0, ascending (most negative first)

  transactions = []
  while creditors and debtors not empty:
    creditor = creditors[0]; debtor = debtors[0]
    amount = min(creditor.balance, -debtor.balance)
    transactions.append({ from: debtor.uid, to: creditor.uid, amount })
    creditor.balance -= amount
    debtor.balance += amount
    if creditor.balance == 0: pop creditors
    if debtor.balance == 0: pop debtors

  return transactions   # minimum number of payments to zero out the group
```

Both functions live in `lib/core/utils/settlement_algorithm.dart` as pure Dart. They're driven by a Riverpod `StreamProvider` wrapping a `snapshots()` listener on `groups/{groupId}/expenses`: every time any member adds, edits, or soft-deletes an expense, Firestore pushes the updated expense list to every connected client in real time, and each client re-runs `recomputeBalances` + `settleUp` locally on that fresh data. No Cloud Function, no persisted balance document — the "instant update for every member" behavior comes from Firestore's own real-time sync, not from server-side recomputation.

Rounding rule: when splitting equally and the division isn't exact, the remainder (in smallest currency unit) is added to the **payer's** share, not distributed randomly. Document this behavior in-app so it's not mistaken for a bug.

---

## 7. Firestore Security Rules (must-have, not optional)

```
match /groups/{groupId} {
  allow read, write: if request.auth.uid in resource.data.members;

  match /expenses/{expenseId} {
    allow read: if request.auth.uid in get(/databases/$(database)/documents/groups/$(groupId)).data.members;
    allow create, update: if request.auth.uid in get(/databases/$(database)/documents/groups/$(groupId)).data.members;
    allow delete: if false; // enforce soft-delete only
  }
}
```

No rule is needed for a `balances` collection — it doesn't exist. Since balances are derived client-side from expense data that every group member can already read, the entire protection surface is the `expenses` subcollection above: membership-gated reads/writes, and no hard deletes.

---

## 8. Phase 1 Feature Checklist

- [ ] Firebase Auth (email/password + Google Sign-In)
- [ ] Custom categories (name, icon, color) — CRUD, seeded defaults on signup
- [ ] Personal expense tracking (existing feature, ported to Firestore instead of local storage)
- [ ] Add friend (by unique app code, not WhatsApp yet)
- [ ] Create group, add friends to group
- [ ] Add group expense with split type: equal / custom / percentage
- [ ] Edit / soft-delete an expense, with balance recompute
- [ ] Client-side balance calculation, live via Firestore real-time listener (no Cloud Functions, no Blaze plan)
- [ ] Settlement screen: minimum-transaction payoff list
- [ ] Group activity log (chronological feed)
- [ ] Firestore security rules enforced and tested

---

## 9. Recommended Prompt Sequence for Antigravity

Deliver these **one at a time**, in order, each referencing this spec doc:

1. **"Set up Firebase project scaffolding"** — Firebase Auth + Firestore init, folder structure from Section 4, pubspec from Section 3.
2. **"Build auth flow"** — login/signup screens, Riverpod auth state, route guarding via go_router.
3. **"Build personal expense tracking on Firestore"** — port existing local pie/bar chart feature to the `users/{uid}` + expenses model, custom categories CRUD.
4. **"Build friends + groups"** — friend add/accept flow, group creation, member management.
5. **"Build group expense entry + splits"** — the three split types, writing to `groups/{groupId}/expenses`.
6. **"Implement client-side balance recompute + settlement"** — Section 6 pseudocode, as pure Dart in `settlement_algorithm.dart`, driven by a Riverpod StreamProvider on the expenses listener. No Cloud Functions, no Blaze plan.
7. **"Build settlement screen + activity log UI"** — final Phase 1 screen, consuming the client-side StreamProvider output from step 6.
8. **"Write and deploy Firestore security rules"** — Section 7, plus a test pass confirming non-members can't read/write.

Do not combine steps 5 and 6 into one prompt — the split-entry UI and the settlement math are the two places bugs are most likely, and reviewing them separately is the only way you'll actually catch a wrong balance before your friends do.

---

## 10. Phase 2 Data Model Additions

These extend the Phase 1 model above. All remain Spark-plan compatible — no Cloud Storage, no Cloud Functions.

**Group invite links** — no new collection. Add one field to the existing `groups/{groupId}` document:
```
groups/{groupId}
  ...(existing fields)
  inviteCode: string   # random 6-character code, generated at group creation
```
Share sheet builds a link such as `splitmate://join?groupId={groupId}&code={inviteCode}` (custom URL scheme; Android App Links optional refinement later). On tap, if the app is installed, it opens directly to a "Join group" confirmation screen that verifies `inviteCode` matches before adding the user to `members`. If not installed, falls back to manual entry of the group's existing app-join-code flow — no separate mechanism needed, this reuses Phase 1's friend-code pattern at the group level.

**Recurring expenses** — no new collection. Add fields to the existing `expenses` document shape (both `users/{uid}/expenses` for personal and `groups/{groupId}/expenses` for group):
```
  isRecurringTemplate: boolean       # true only for the template itself, false for generated instances
  recurrenceInterval: "weekly" | "monthly" | null
  lastGeneratedDate: timestamp | null
  generatedFromTemplateId: string | null   # set on instances created from a template
  isCancelled: boolean               # true once the user cancels a recurring template; launch-time check must skip cancelled templates, but never delete their already-generated instances
```
On app launch, check all documents where `isRecurringTemplate == true`; if `lastGeneratedDate` is more than one interval in the past, create a new real expense instance (copying amount/category/split, setting `generatedFromTemplateId`) and update `lastGeneratedDate` on the template. Purely client-side, triggered on launch — no scheduled server job.

**Itemized bill splitting** — extends `splitType` with a new value and a new field on group expenses only:
```
groups/{groupId}/expenses/{expenseId}
  splitType: "equal" | "custom" | "percentage" | "itemized"   # new value added
  items: [ { id, name, amount, assignedTo: [uid] } ]           # only present when splitType == "itemized"
```
When `splitType == "itemized"`, `splits` (the existing per-member absolute-amount map) is still the source of truth for balance calculation — it's computed by summing, for each member, every item where their uid appears in `assignedTo`, divided evenly among however many people are assigned to that specific item. `items` is stored alongside for display/editing purposes, but `recomputeBalances` only ever reads `splits`, unchanged from Phase 1 — this means the settlement algorithm needs zero modification for this feature.

**Global settle-up dashboard (Option A — per-group, not cross-group netting)** — no schema changes at all. Reuses the existing per-group `groupSettlementProvider` from Phase 1, called once per group the user belongs to, displayed as a list.

---

## 11. Phase 3 Data Model Additions

Receipts and push notifications remain deliberately deferred — both require the Blaze plan, decided against again this phase. Everything below is Spark-compatible.

**Monthly spending insights/trends** — no schema changes. Purely computed client-side from existing `expenses` documents (personal and group), grouped by month and category using the `createdAt` field already present.

**Group spending breakdown** — no schema changes. Computed client-side from existing group `expenses`, aggregated by category and by `payerUid`, to show category totals and "who paid the most" for a given group.

**Budget limits with alerts** — one new field on the existing category structure:
```
users/{uid}
  categories: [ { id, name, iconCode, colorHex, monthlyBudget: number | null } ]   # monthlyBudget added, null means no limit set
```
Computed client-side: sum the current month's personal expenses per category, compare against `monthlyBudget`, show a warning state when a chosen threshold (e.g. 80%) is crossed.

**Multi-currency support** — this is the one feature this phase that touches shared-expense math, so the isolation rule is critical: **currency conversion happens entirely at expense-entry time, client-side. The existing `splits` field is always stored already-converted into the group's base currency. `recomputeBalances` and the settlement algorithm in `settlement_algorithm.dart` must not be modified at all** — same invariant established for itemized splitting in Phase 2.

Schema additions:
```
groups/{groupId}
  baseCurrency: string   # e.g. "INR", set at group creation, defaults to INR

groups/{groupId}/expenses/{expenseId}
  currency: string          # the currency the expense was actually entered in, e.g. "EUR"
  exchangeRate: number      # rate used to convert to the group's baseCurrency at entry time, stored for transparency
  # 'amount' remains the original entered amount in 'currency'
  # 'splits' remains the existing absolute-amount map, but always expressed in baseCurrency — computed as amount * exchangeRate, then split

users/{uid}
  homeCurrency: string   # user's personal default currency, for their own personal expenses, e.g. "INR"

users/{uid}/expenses/{expenseId}
  currency: string   # defaults to the user's homeCurrency; personal expenses don't need conversion since there's no shared balance to protect
```
When an expense is entered in a currency different from the group's `baseCurrency`, fetch the current exchange rate client-side (e.g. via a free no-key API such as open.er-api.com), display the converted amount to the user for confirmation before saving, then store both the original `amount`/`currency` (for display/reference) and the converted `splits` (for balance calculation, in baseCurrency). If the exchange rate fetch fails (no network), block saving with a clear message rather than guessing a rate or defaulting to a 1:1 conversion — a wrong silent conversion is worse than a blocked save.

---

## 12. Personal Expense Mirroring from Group Expenses

**Goal:** a group expense's per-member share should also appear in that member's personal expense tracker, categorized correctly — but timed differently depending on whether the person paid or owes.

**Scoping decision (important):** this mirrors off the **pairwise Individual Balances** between two specific people who actually share expenses, never off the optimized "Suggested Settlements" minimal-transaction list. The optimizer can route payments between people who never directly shared an expense (e.g., in a 3+ person group, "C pays B" purely to minimize transaction count) — mirroring against that would make category attribution meaningless. Pairwise balances are always real, direct, and traceable back to actual shared expenses.

**Schema addition** — the existing `splits` map on `groups/{groupId}/expenses/{expenseId}` gains a settlement flag per member:
```
groups/{groupId}/expenses/{expenseId}
  splits: { uid: { amountOwed: number, settled: boolean } }   # was previously { uid: amountOwed }; now each entry also tracks settlement
```
The payer's own entry in `splits` is set `settled: true` immediately at creation (they already paid with their own money). Every other member's entry starts `settled: false`.

**No changes to `recomputeBalances` or `settleUp`** — both continue reading only the `amountOwed` value from each split entry, completely unaware the `settled` field exists. This is the same isolation principle used for itemized splitting and multi-currency.

**Mirroring mechanism — entirely client-side, no new Firestore rules needed:**

1. **Payer side (immediate):** the moment a user adds a group expense as payer, their own client writes a personal expense entry into their own `users/{uid}/expenses` — amount = their own `amountOwed` share, same category as the group expense — tagged `isFromGroup: true, sourceGroupId, sourceExpenseId`. This is a self-write, already permitted by existing rules.

2. **Debtor side (deferred):** when two people settle their pairwise Individual Balance (via the existing Record Payment confirm/dispute flow), the app finds every still-`settled: false` split entry between exactly those two people, in both directions, across all their shared group expenses — and marks all of them `settled: true` together in one batch, since the confirmed payment amount is by construction the exact net of all of them. This flag update is a normal group-expense-subcollection write, already permitted for any group member under existing rules — no rule change needed.

3. Each user's own client (on next launch, or live if the app is open) scans for split entries where they are the debtor, marked `settled: true`, and not yet mirrored — then writes the corresponding personal expense entry into their own `users/{uid}/expenses`, one entry per underlying original category (never one lump sum), tagged the same way as step 1. This reuses the same "check on launch" pattern already established for recurring expenses in Section 10.

**Worked example, confirming the mechanism:** A pays ₹1000 Food (split equally, ₹500 each) and ₹500 Entertainment (split equally, ₹250 each) in a 2-person group with B. A's client immediately mirrors ₹500/Food + ₹250/Entertainment into A's own personal list (A already spent that money). B currently owes A ₹750 net. Before settling, B pays ₹200 for Auto (split equally, ₹100 each) — B's client immediately mirrors ₹100/Travel into B's own personal list. The pairwise net between A and B is now ₹750 − ₹100 = ₹650 (A owes B ₹100, B owes A ₹750). When B pays A the net ₹650 and A confirms it, all three underlying split entries (B's Food ₹500, B's Entertainment ₹250, A's Auto ₹100) get marked settled together. B's client then mirrors ₹500/Food + ₹250/Entertainment into B's own personal list (two separate entries, not one ₹750 lump). A's client mirrors ₹100/Travel into A's own personal list. Every category stays intact on both sides.

---

## 13. Connection Model Refinement (Friends + Groups)

Two distinct join paths now exist, and they behave differently on purpose:

- **Code-based group join:** direct, no approval — possessing the code is itself the invitation. Group codes must be displayed prominently in the app, the same way a user's own friend code is already displayed — not just embedded silently inside a share link.
- **Friend-selected group invite:** a targeted invite to a specific person, requiring accept/decline — same pattern already used for friend requests, replacing the current direct-add-to-members behavior.

**New collection:**
```
users/{uid}/groupInvites/{inviteId}
  groupId: string
  groupName: string
  invitedBy: uid
  invitedByName: string
  status: "pending" | "accepted" | "declined"
  createdAt: timestamp
```
Selecting an existing friend to add to a group creates a document here, in the invited user's own subcollection, instead of directly appending to `groups/{groupId}.members`. Accepting runs a transaction: add the accepting user's own uid to `members`, set `status: "accepted"`, log a `"member_joined"` activity entry. Declining only updates `status: "declined"` — no membership change.

**Hardened groups security rule** — closes a real gap where any existing member can currently rewrite the entire `members` array arbitrarily. An update may only ever add or remove the caller's own uid, never anyone else's:
```
match /groups/{groupId} {
  allow create: if request.auth != null &&
    request.auth.uid in request.resource.data.members;

  allow read: if request.auth != null &&
    request.auth.uid in resource.data.members;

  allow update: if request.auth != null &&
    request.auth.uid in resource.data.members &&
    request.resource.data.members.toSet().difference(resource.data.members.toSet()).hasOnly([request.auth.uid]) &&
    resource.data.members.toSet().difference(request.resource.data.members.toSet()).hasOnly([request.auth.uid]);

  allow delete: if false;
}
```
(Antigravity should verify exact Firestore rules-language syntax for set difference on arrays — the intent is: the only permitted change to `members` on any single update is adding or removing the caller's own uid, nothing else.)

**WhatsApp share message redesign** — replace the current clickable-link message (not reliably clickable via a custom URL scheme in WhatsApp) with two distinct code-focused templates, no link included:
- Friend-code share: a short message naming the sender, their code, and instructions to open the app, go to Friends → Add Friend, and enter the code.
- Group-code share: a short message naming the group, the code, and instructions to open the app, go to Groups → Join with Code, and enter the code.

**UI requirements:**
- Both the user's own friend code and any group's code must be displayed as a prominent, bordered, tabular-mono, tap-to-copy component — not plain inline text — consistent with the Ledger design system's gold-accent highlight treatment.
- Any text field where a user manually types in a code must use the design system's muted/secondary text color for its placeholder, not full-contrast primary text.
- When viewing a group member who joined via code and is not yet an accepted friend, show a small "Add as friend" action next to their name.
