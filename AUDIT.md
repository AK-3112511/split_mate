# SplitMate — Audit Findings (2026-11-15)

Every issue found in the full-code audit. Status: ⬜ open · ✅ fixed · ➖ removed / out of scope · ⏭ deferred · 🚀 fixed in code, needs `firebase deploy`.
Severity: **P0** = wrong money / crash / security · **P1** = broken flow · **P2** = UX / quality.
"Phase" refers to the phases in [PROGRESS.md](PROGRESS.md).

## B — Build health

| ID | Sev | Issue | Where | Phase | Status |
|---|---|---|---|---|---|
| B-01 | P0 | 21 analyzer errors on Flutter 3.50 (stale package config + deprecated `material.dart`) | router.dart, 8 screens | 0 | ✅ |
| B-02 | P2 | 58 warnings/infos: unused imports/vars/casts, `print`, context across async gaps | many | 0 | ✅ |

## G — Groups, splits, settlement, mirrors

| ID | Sev | Issue | Where | Phase | Status |
|---|---|---|---|---|---|
| G-01 | P0 | Editing an expense merges `splits` → removed members keep old shares; sum ≠ amount | group_expenses_repository.dart:261 | 2 | ✅ |
| G-02 | P0 | Edit resets `createdAt` to now, can flip expense into a template, nulls `lastGeneratedDate` (duplicate generation), drops `generatedFromTemplateId`, resets all `settled` flags | add_group_expense_screen.dart:430-446, 350 | 2 | ✅ |
| G-03 | P0 | Editing a group recurring template crashes (`firstWhere` without `orElse` over a template-filtered list) | add_group_expense_screen.dart:596 | 2/5 | ✅ |
| G-04 | P0 | Payer mirror written to the logged-in user, not the payer; real payer never mirrored | add_group_expense_screen.dart:489-506, expense_repository.dart:154 | 2 | ✅ |
| G-05 | P0 | Edit creates debtor mirrors before settlement (`set merge` creates doc); zero-share mirror never removed | add_group_expense_screen.dart:467-480, expense_repository.dart:177 | 2 | ✅ |
| G-06 | P0 | Soft-deleting a group expense leaves personal mirrors (deleteGroupMirrorExpense never called) | group_expenses_repository.dart:281-321 | 2 | ✅ |
| G-07 | P0 | `markSplitsSettled` called with swapped args; marks creditor's entries in every expense; wrong for simplified routes | settlement_screen.dart:630, group_expenses_repository.dart:441-447 | 2 | ✅ |
| G-08 | P0 | Itemized item with no members still counts toward total → payer credited with unowed money | add_group_expense_screen.dart:303, 395, 1770-1783 | 2 | ✅ |
| G-09 | P0 | Custom/percent accept negative numbers; non-positive entries dropped after validation | add_group_expense_screen.dart:94, 323-331, 365-378 | 2 | ✅ |
| G-10 | P1 | Custom & Percent tabs share the same text controllers → stale values, false validation errors | add_group_expense_screen.dart:96-100, 1172, 1207 | 2/5 | ✅ |
| G-11 | P1 | Equal-split remainder given to non-participating payer; edit re-adds payer → silent change | add_group_expense_screen.dart:246, 291-292 | 2 | ✅ |
| G-12 | P1 | Percent reconstruction to 1 dp fails 100% validation on unchanged re-save | add_group_expense_screen.dart:260, 375 | 2 | ✅ |
| G-13 | P1 | Payment detection by `description.contains('settlement')` misclassifies real expenses | group_expense_model.dart:121-125 | 2 | ✅ |
| G-14 | P1 | Amounts < ₹0.01 / >2 decimals accepted | add_group_expense_screen.dart:403-411 | 2 | ✅ |
| G-15 | P0 | Record Payment double-submit possible (no in-flight guard) | settlement_screen.dart:381 | 2/5 | ✅ |
| G-16 | P0 | Record Payment is a non-atomic chain; disposal mid-chain throws `ref` StateError → payment saved, splits not marked | settlement_screen.dart:626-646 | 2 | ✅ |
| G-17 | P1 | Only debtor can settle; creditor can't mark received; removed debtor = unclearable debt | settlement_screen.dart:380-444 | 2/5 | ✅ |
| G-18 | P1 | "Individual balances" use simplified transactions, not pairwise | settlement_screen.dart:189-207, settlement_algorithm.dart:185-213 | 2 | ✅ |
| G-19 | P2 | No partial payments (amount fixed) | settlement_screen.dart:601-621 | 2/5 | ✅ |
| G-20 | P1 | "Ledger entries are permanent" banner false; payment records editable/deletable from activity | settlement_screen.dart:469, group_detail_screen.dart:770-781 | 5 | ✅ |
| G-21 | P1 | Last admin can leave → group with no admin; no demote | groups_repository.dart:313-337 | 2 | ✅ |
| G-22 | P1 | No balance warning on remove/leave/delete; removed members' balances orphaned; deleted group debts vanish | group_detail_screen.dart:436-444, 1340-1442 | 2/5 | ✅ |
| G-23 | P2 | Delete-group dialog says expenses are deleted (only soft flag) | group_detail_screen.dart:1400 | 5 | ✅ |
| G-24 | P1 | "Group deleted" notification sent before the delete | group_detail_screen.dart:1416-1421 | 2 | ✅ |
| G-25 | P1 | Removed member with group open isn't redirected; permission errors | group_detail_screen.dart | 5 | ✅ |
| G-26 | P1 | Deleted groups still processed by recurring engine, mirror scan, join-by-code, accept-invite | recurring_engine.dart:60, group_mirror_service.dart:43, groups_repository.dart:243, 426 | 2 | ✅ |
| G-27 | P1 | Deep link while logged out is lost | router.dart:75-91, app.dart:51 | 1 | ✅ |
| G-28 | P2 | App never generates a deep link in share text | export_helper.dart:446-458 | 2 | ✅ |
| G-29 | P1 | Join screen compares invite code case-sensitively | join_group_screen.dart:70 | 2/5 | ✅ |
| G-30 | P2 | "member_joined" activity logged for existing members | groups_repository.dart:264, 461 | 2 | ✅ |
| G-31 | P2 | Invite codes not unique, not rotatable | groups_repository.dart:132-138, 439 | 2 | ✅ |
| G-32 | P2 | `_backfillInviteCode` races on every stream event | groups_repository.dart:87-89 | 2 | ✅ |
| G-33 | P2 | Stale invites remain after joining/deletion | group_list_screen.dart:724-829 | 2/5 | ✅ |
| G-34 | P0 | Back after join crashes (`go` then `pop` → "nothing to pop") | join_group_screen.dart:41, 266; group_detail_screen.dart:40 | 1 | ✅ |
| G-35 | P2 | Join screen has no AppBar/back | join_group_screen.dart:58 | 5 | ✅ |
| G-36 | P1 | Every notification tap opens Settlement (deleted/removed groups error) | group_list_screen.dart:1104-1117, notifications_list_screen.dart:152 | 2/5 | ✅ |
| G-37 | P1 | Actions after closing sheets/dialogs use dead contexts; snackbars never shown | group_detail_screen.dart:956-1014, add_group_expense_screen.dart:1353 | 5 | ✅ |
| G-38 | P1 | Back during PDF export pops the detail screen | group_detail_screen.dart:1583-1613 | 5 | ✅ |
| G-39 | P2 | Unreachable route `/groups/:id/recurring-expenses` | router.dart:146 | 1 | ✅ |
| G-40 | P0 | Retry after partial failure creates a duplicate expense (new UUID each tap) | add_group_expense_screen.dart:431, 506-518 | 2 | ✅ |
| G-41 | P1 | Save continues after pop → `ref` StateError, setState without mounted | add_group_expense_screen.dart:491-529 | 2/5 | ✅ |
| G-42 | P2 | Missing mounted checks (+CONNECT) | group_detail_screen.dart:409-419 | 5 | ✅ |
| G-43 | P1 | Delete expense / decline invite unhandled errors | group_detail_screen.dart:1011, group_list_screen.dart:811 | 5 | ✅ |
| G-44 | P2 | No re-entrancy guard on Accept invite, Request payment, Connect, Send invite | several | 5 | ✅ |
| G-45 | P1 | `createGroup` not atomic → duplicate groups on retry | groups_repository.dart:171-198 | 2 | ✅ |
| G-46 | P1 | Offline: `await commit()` never returns → endless spinners | all writes | 1 | ✅ |
| G-47 | P0 | Group recurring generation race → duplicate expenses across members | recurring_engine.dart:75-126 | 2 | ✅ |
| G-48 | P1 | Provider errors mapped to `Stream.empty()` → infinite loading | settlement_algorithm.dart:119, 149 etc. | 1/2 | ✅ |
| G-49 | P2 | No `autoDispose`; listeners survive logout | all `.family` providers | 1 | ✅ |
| G-50 | P2 | Whole 2,000-line detail screen rebuilds on any change | group_detail_screen.dart | 5 | ✅ |
| G-51 | P2 | Cooldown stream reads all sent notifications; mirror scan reads everything each launch | notifications_repository.dart:70, group_mirror_service.dart:38 | 2 | ✅ |
| G-52 | P2 | Notification noise: add notifies, edit/delete don't; template creation notifies | add_group_expense_screen.dart:511 | 2 | ✅ |
| G-53 | P2 | Request payment silently overwrites clipboard | settlement_screen.dart:681 | 5 | ✅ |

## P — Personal, auth, categories, recurring, profile

| ID | Sev | Issue | Where | Phase | Status |
|---|---|---|---|---|---|
| P-01 | P0 | Editing a recurring template nulls `lastGeneratedDate` → immediate duplicate | add_expense_screen.dart:174, 184 | 2 | ✅ |
| P-02 | P0 | Recurring engine: non-transactional, one instance/launch, "now" dates, 30-day months, ignores start date | recurring_engine.dart:27-50, 134-144 | 2 | ✅ |
| P-03 | P1 | Category stored by name → rename/delete creates phantom categories; recurring lookup by id never matches | add_expense_screen.dart:161, recurring_expenses_screen.dart:146 | 1/2 | ✅ |
| P-04 | P1 | No way to edit a normal personal expense | expense_list_screen.dart:830 | 5/6 | ✅ |
| P-05 | P1 | Profile photo saved as a local cache path → broken for everyone else | profile_screen.dart:42-47 | 1 | ✅ |
| P-06 | P0 | Initials crash (`RangeError`) on names with double spaces (7 places) | profile_screen.dart:148 etc. | 1 | ✅ |
| P-07 | P1 | Logout leaks previous user's data (no invalidation, no cache clear) | all repositories, profile_screen.dart:364 | 1 | ✅ |
| P-08 | P1 | Offline writes awaited → spinner/undo never resolves | add_expense_screen.dart:178, expense_list_screen.dart:789 | 1 | ✅ |
| P-09 | P1 | Amount accepts NaN/Infinity/1e308; rejects `1,200` and `12,5`; unlimited decimals | add_expense_screen.dart:147-153 | 1 | ✅ |
| P-10 | P1 | Deleted debtor mirrors resurrect on launch; mirrors dated "now" | group_mirror_service.dart:75-98 | 2 | ✅ |
| P-11 | P1 | Verification email sent twice → rate-limited resend | auth_repository.dart:52, verify_email_screen.dart:46 | 2 | ✅ |
| P-12 | P1 | Seeding failures never retried → user without doc/categories/code | auth_repository.dart:45-82 | 2 | ✅ |
| P-13 | P1 | Router refresh only on `authStateChanges` (verification/name changes missed); no splash | router.dart:33, 65 | 1 | ✅ |
| P-14 | P0 | Detail routes outside shell; `pop()` on empty stack throws | router.dart:95-182 | 1 | ✅ |
| P-15 | P1 | Plain `ShellRoute` → tabs rebuilt, filters reset, back exits app | router.dart:183 | 1 | ✅ |
| P-16 | P1 | Launch jobs in `ref.listen` in build, for unverified users, uncaught errors | app.dart:66-76 | 1 | ✅ |
| P-17 | P1 | setState without mounted after awaits in auth screens | login/signup/verify | 5 | ✅ |
| P-18 | P2 | Email regex rejects `+` and long TLDs; password trimmed | login_screen.dart:157, signup_screen.dart:188 | 2 | ✅ |
| P-19 | P1 | "Forgot password" is fake | login_screen.dart:172-181 | 2/5 | ✅ |
| P-20 | P2 | Fake footer links, encryption badge, © 2024 | login_screen.dart:343-470 | 5 | ✅ |
| P-21 | P2 | Raw Firebase error messages shown | everywhere | 1 | ✅ |
| P-22 | P2 | Google sign-in bypasses Terms checkbox; terms not tappable | signup_screen.dart:256-336 | 5 | ✅ |
| P-23 | P1 | Verify screen overflows on small screens | verify_email_screen.dart:185-369 | 5 | ✅ |
| P-24 | P2 | Description not required; category auto-selected in build | add_expense_screen.dart:250, 349 | 5 | ✅ |
| P-25 | P2 | Future dates allowed; backdated entries lose time | add_expense_screen.dart:108-133 | 5 | ✅ |
| P-26 | P1 | Default filter "Today" + reset on tab switch → "no expenses" confusion | expense_list_screen.dart:28 | 1/5 | ✅ |
| P-27 | P2 | Custom range not validated, label omits year, end bound misses ms | expense_list_screen.dart:72-81 | 5 | ✅ |
| P-28 | P1 | Dismissible awaits server before Undo; failure asserts | expense_list_screen.dart:774-829 | 5 | ✅ |
| P-29 | P2 | Nested 330px scroll list; group-name hack via `contains('(')` | expense_list_screen.dart:751, 840 | 5 | ✅ |
| P-30 | P2 | Recurring screen: wrong NEXT RUN, blank Groups tab, no create entry | recurring_expenses_screen.dart | 5 | ✅ |
| P-31 | P1 | Category delete: false "show as Others" text; arrayRemove silent no-op; duplicates allowed; unguarded `int.parse(colorHex)` | category_settings_screen.dart, categories_repository.dart, category_model.dart:54 | 2/5 | ✅ |
| P-32 | P1 | Receipts inline base64 in expense docs → lists download all images; no size guard | add_expense_screen.dart:93, add_group_expense_screen.dart:118 | 1 | ✅ |
| P-33 | P2 | Receipt viewer `base64Decode` uncaught; `dart:io` breaks web; "Rs." | receipt_viewer_dialog.dart | 4/5 | ✅ |
| P-34 | P2 | Receipts vault decodes every build, watches streams in loop, flickers empty | receipts_vault_screen.dart | 5 | ✅ |
| P-35 | P2 | Personal info: fake fallback code `SM8899`, currency setting no-op, stream recreated each build | personal_info_screen.dart | 5 | ✅ |
| P-36 | P2 | No password change / account options | profile | 5 | ✅ |
| P-37 | P2 | Chart overflows (legend, centre label, bar labels), raw tooltips | pie_chart_widget.dart, bar_chart_widget.dart | 5 | ✅ |
| P-38 | P2 | No personal export | export_helper.dart | 6 | ✅ |

## F — Friends & notifications

| ID | Sev | Issue | Where | Phase | Status |
|---|---|---|---|---|---|
| F-01 | P1 | Mutual request dead-end ("already pending") | friends_repository.dart:110-116 | 2 | ✅ |
| F-02 | P1 | Can't cancel sent request; can't unfriend | friends_list_screen.dart:752 | 2/5 | ✅ |
| F-03 | P1 | Accept/decline fire-and-forget; no feedback; double-tap duplicates | friends_list_screen.dart:731, 744 | 5 | ✅ |
| F-04 | P2 | No re-request cooldown after decline | friends_repository.dart:199 | 2 | ⏭ (low value; declined requests can be re-sent, but no notification spam: one request = one notification) |
| F-05 | P1 | `appCode` uniqueness unchecked; look-alike chars; "PENDING" copied as code | auth_repository.dart:90, friends_list_screen.dart:285 | 2 | ✅ |
| F-06 | P2 | Friend count includes pending | profile_screen.dart:144 | 5 | ✅ |
| F-07 | P2 | No badge for incoming friend requests | app.dart:160 | 5 | ✅ |
| F-08 | P2 | Nickname edits: no try/catch, controller leak, inconsistent usage across screens | friends_list_screen.dart:196-260 | 5 | ✅ |
| F-09 | P2 | Notifications: no delete/limit/order; offline taps hang; mark-all >500 fails | notifications_repository.dart | 2 | ✅ |
| F-10 | P2 | Two drifted notification UIs | group_list_screen.dart:970, notifications_list_screen.dart | 5 | ✅ |
| F-11 | P2 | Cooldown trusts client clock; never expires without new snapshot | notifications_repository.dart:36-101 | 2 | ✅ |
| F-12 | P2 | No push notifications (Spark plan) | — | out of scope | ➖ |

## S — Security (firestore.rules)

| ID | Sev | Issue | Phase | Status |
|---|---|---|---|---|
| S-01 | P0 | Any signed-in user can update any group (add self, become admin, rename, delete flag) | 3 | ✅ deployed |
| S-02 | P0 | Forced friendship: rewrite `sentBy` then accept; edit others' nickname | 3 | ✅ deployed |
| S-03 | P0 | Notifications readable/editable/deletable by anyone; spoofable content | 3 | ✅ deployed |
| S-04 | P1 | All user docs (emails) readable by any signed-in user | 3 | ✅ deployed |
| S-05 | P1 | `appCode` hijack (write someone else's code) | 3 | ✅ deployed |
| S-06 | P1 | group_invites readable by all; anyone can invite to any group | 3 | ✅ deployed |
| S-07 | P1 | Group activity writable by non-members | 3 | ✅ deployed |
| S-08 | P2 | Expenses: no field validation | 3 | ✅ deployed |
| S-09 | P2 | iOS has no `CFBundleURLTypes` for `splitmate://` | 1 | ✅ |

## U — UI / design

| ID | Sev | Issue | Phase | Status |
|---|---|---|---|---|
| U-01 | P2 | 83× `BorderRadius.zero`; no radii anywhere | 4/5 | ✅ |
| U-02 | P2 | ~350 monospace styles; 244 ALL-CAPS strings; 311 bold weights | 4/5 | ✅ |
| U-03 | P2 | 48% of text ≤11px (8px in places) | 4/5 | ✅ |
| U-04 | P2 | No shadows/gradients/motion/haptics/skeletons | 4/5 | ✅ |
| U-05 | P2 | 112 hardcoded `Colors.*`; harsh `Colors.red` errors | 4/5 | ✅ |
| U-06 | P2 | ThemeData has no component themes; `bodyMedium` grey by default | 4 | ✅ |
| U-07 | P2 | No shared currency formatter (60× `toStringAsFixed`, "Rs.") | 1 | ✅ |
| U-08 | P2 | Copy-pasted patterns: AppBar, section card ×3, avatar, chips, add-friend dialog ×3, confirm dialogs, sheets | 4 | ✅ |
| U-09 | P2 | App name inconsistent (SplitTrack / SplitMate / split_mate / Split Mate) | 5 | ✅ |
| U-10 | P2 | Jargon copy ("NET LIQUIDITY", "JOURNAL ENTRIES", "Fiscal Systems") | 5 | ✅ |
| U-11 | P2 | Empty states = one grey line, no CTA | 4/5 | ✅ |
| U-12 | P2 | Overflow risks (long names, big amounts) in ~10 rows | 5 | ✅ |
| U-13 | P2 | "You (You)" label; touching cards; double divider; whole-rupee rounding on group cards | 5 | ✅ |
| U-14 | P2 | Group detail AppBar shows "SplitMate" instead of group name; no expense list | 5 | ✅ |

## D — Dead / duplicate code

| ID | Item | Phase | Status |
|---|---|---|---|
| D-01 | `friend_repository.dart`, `group_repository.dart`, `add_friend_screen.dart` (stubs) | 1 | ✅ |
| D-02 | `balance_model.dart`, `primary_button.dart`, `constants.dart` (unused) | 1 | ✅ |
| D-03 | `groupMirrorServiceProvider`, `addGroupMirrorExpenses`, `exportGroupExpensesToPDF` (unused) | 2 | ✅ |
| D-04 | Default categories defined 3×; category resolvers 3× | 1 | ✅ |
| D-05 | Login/Signup duplicated widgets | 5 | ✅ |
| D-06 | `_getActorName` ×3, admin-check block ×4, activity icon mapping ×3 | 2/5 | ✅ |

## E — Found in the two-account device test (2026-11-16)

| ID | Sev | Issue | Where | Status |
|---|---|---|---|---|
| E-01 | P1 | Denied listeners re-subscribe forever: cached snapshot resets the retry counter before the server denial (sign-out, removed member) | core/utils/firestore_helper.dart | ✅ |
| E-02 | P1 | Friend request / friend balance / group invite cards render black and unreadable (translucent tint over the hard shadow) | shared_widgets/motion.dart (`BrutalSurface`) | ✅ |
| E-03 | P2 | UPI intent encodes spaces as `+` → note/payee shown as `SplitMate+·+Trip` in GPay | groups/presentation/widgets/settle_up.dart | ✅ |
| E-04 | P1 | Debtor's mirror missing when the creditor records the payment, until a cold start (scan once per process; skipped on re-login / resume) | core/session/bootstrap.dart, app.dart | ✅ |
| E-05 | P2 | Personal info Save hidden behind the keyboard | profile/presentation/personal_info_screen.dart | ✅ |
| E-06 | P2 | "Pay via UPI" label wraps to two lines | groups/presentation/tabs/balances_tab.dart | ✅ |
| E-07 | P2 | Friend-request notification stays unread after accepting from the Friends tab (same for group invites from Groups, and for a mutual request auto-accept) | friends_screen.dart, group_list_screen.dart, notifications_repository.dart | ✅ |
| E-08 | P2 | Back on Personal info silently discards unsaved edits → now asks "Discard changes?" | profile/presentation/personal_info_screen.dart | ✅ |
| E-09 | P1 | Recurring instances back-filled on template save never mirrored to the payer's ledger until next launch (never if the group is deleted first) | groups/presentation/add_group_expense_screen.dart | ✅ |
| E-10 | P2 | Recap copy: "0% less than September", "1 expenses" | recap/presentation/recap_screen.dart | ✅ |
| E-11 | P2 | Last admin is offered "Leave group", then refused | groups/presentation/group_detail_screen.dart | ✅ |

## Security rules — manual verification matrix

The Firebase emulator needs Java (not installed on this machine), so rules were checked by review against every write path in the code. Before deploying, run these with the emulator or two test accounts (A = member, B = non-member):

| # | Action | Expected |
|---|---|---|
| R1 | B reads `groups/{g}` or its expenses / activity | ❌ denied |
| R2 | B updates `groups/{g}.members` adding self **without** `joinCode` | ❌ denied |
| R3 | B joins with the correct code (`members ∪ [B]`, `joinCode = inviteCode`) | ✅ allowed |
| R4 | B adds **someone else** with the right code | ❌ denied |
| R5 | Non-admin member renames group / sets `isDeleted` / edits `admins` | ❌ denied |
| R6 | Member leaves (removes only self) | ✅ allowed |
| R7 | A sends friend request to B, then edits `sentBy` / `status` on B's edge | ❌ denied |
| R8 | B accepts A's request (status only) | ✅ allowed |
| R9 | A reads / edits / deletes B's notification | ❌ denied |
| R10 | A writes `email` into the public `users/{A}` doc | ❌ denied |
| R11 | A sets `appCode` to a code owned by B in `app_codes` | ❌ denied |
| R12 | Any write that hard-deletes a group or expense | ❌ denied |
| R13 | Group expense with `amount <= 0` | ❌ denied |

> ⚠️ Deploy rules **together with** the v2 APK: v1 clients write `email` to public profiles and rely on open group updates, which v2 rules reject.
