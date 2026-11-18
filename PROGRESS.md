# SplitMate v2 "Aurora" — Progress Log

> Branch: `redesign/aurora` · Plan: see [PRD.md](PRD.md) · Findings: [AUDIT.md](AUDIT.md) · Design: [DESIGN_SYSTEM.md](DESIGN_SYSTEM.md)
> Legend: ⬜ not started · 🟡 in progress · ✅ done · ⏸ blocked

## Summary

| Phase | Scope | Status |
|---|---|---|
| Docs | PRD, PROGRESS, AUDIT, DESIGN_SYSTEM | ✅ 2026-11-15 |
| 0 | Build health — 0 analyzer issues, tests green | ✅ 2026-11-15 |
| 1 | Foundations — routing, session state, utilities, data model | ✅ 2026-11-15 |
| 2 | Correctness — splits, settlement, mirrors, recurring, membership, friends, notifications, auth | ✅ 2026-11-15 |
| 3 | Firestore security rules | ✅ deployed 2026-11-16 |
| 4 | Design system — tokens, light/dark theme, components, motion | ✅ 2026-11-15 |
| 5 | Screen redesign + approved removals | ✅ 2026-11-15 |
| 6 | New features — budgets, UPI, search & details, recap & export | ✅ 2026-11-15 |
| 7 | Verification — analyze, tests, rules, manual E2E, release build | ✅ full manual E2E checklist done on device 2026-11-16 (rules matrix R1–R13 only partly exercised; emulator needs Java) |

## Phase log

### Docs — ✅ 2026-11-15
- Created `PRD.md`, `AUDIT.md` (≈150 findings with IDs), `DESIGN_SYSTEM.md`, `PROGRESS.md`.

### Phase 0 — Build health — ✅ 2026-11-15
- [x] `flutter pub get` — the 21 "errors" were a stale `.dart_tool/package_config.json` from an older SDK; resolved on refresh (B-01)
- [x] Migrated `package:flutter/material.dart` (deprecated in Flutter 3.47+) → `package:material_ui/material_ui.dart` via the official `dart fix --code=migrate_design_widgets` (31 files). Added `material_ui: ^1.11.0`, bumped `intl` to `^0.20.2` (required by material_ui).
- [x] Added `MaterialUiCompatibilityBridge` in `MaterialApp.router.builder` so go_router / fl_chart (still on legacy material) get our theme. Temporary — remove when those packages migrate.
- [x] `google_fonts` `*TextTheme` helpers return legacy `TextTheme` → switched to `textTheme.apply(fontFamily: …)`. **Rule:** use `GoogleFonts.x(textStyle: …)`/`fontFamily`, never `GoogleFonts.xTextTheme()`.
- [x] Fixed all warnings/infos (unused imports/vars/casts, `print`→`debugPrint`, context across async gaps) (B-02)
- [x] `flutter analyze` → **No issues found**; `flutter test` → **39/39 passed**

### Phase 1 — Foundations — ✅ 2026-11-15
**Architecture (new files)**
- `lib/core/router/app_router.dart` — `StatefulShellRoute.indexedStack` (Home / Groups / Friends / Profile keep state), `/splash` while auth restores, `?from=` preserved through login & verify (deep links survive), `context.popOrGo()`; group expense form nested under `/groups/:id` on the root navigator. Old `core/utils/router.dart` deleted.
- `lib/app_shell.dart` — M3 `NavigationBar` with blur, badges for group invites & friend requests.
- `lib/core/session/bootstrap.dart` — once per verified uid: `ensureProfile` → recurring engine → mirror scan → notification cleanup; each step isolated with try/catch.
- `lib/app.dart` / `main.dart` — light + dark theme, persisted theme mode (shared_preferences), global `rootMessengerKey` for toasts, deep link `splitmate://join?code=…` → `/join`.
- Providers watch `currentUidProvider` (from `userChanges()`), families are `autoDispose` → no stale data after logout/account switch.
- **Decision:** not calling `clearPersistence()` on logout — it requires terminating Firestore (fragile in FlutterFire) and every query is uid-scoped + protected by rules, so cached docs can't leak across accounts.

**Utilities** — `money.dart` (paise maths, en_IN format, compact ₹1.2L, strict `parse`), `initials.dart`, `friendly_error.dart` + `AppException`, `dates.dart`, `haptics.dart`, `write_helper.dart` (`commitWithTimeout` → "will sync" instead of hanging), `image_codec.dart` (compressed base64 + size guard).

**Data model (backward compatible)** — personal expenses: `categoryId`, `date`, `notes`, `receiptId`, `hidden` tombstone; group expenses: `type: payment`, category snapshot (icon/colour), `date`, `updatedAt`; receipts in `users/{uid}/receipts` & `groups/{gid}/receipts`; avatars as small `photoData`; email moved to `users/{uid}/private/profile`; unique-code registries `app_codes/{code}` and `group_codes/{code}`.

### Phase 2 — Correctness — ✅ 2026-11-15
- `core/domain/split_calculator.dart` — paise-exact equal / exact / percent / itemized; rejects negatives & unassigned items; percent round-trips (G-08..G-12, G-14).
- `core/domain/settlement.dart` — net balances, simplify, **pairwise** balances (G-18).
- `core/domain/recurrence.dart` + `core/utils/recurring_engine.dart` — month-end clamping, catch-up (≤12), due-date dating, deterministic ids + transactions, legacy guard (P-01, P-02, G-47).
- `groups/data/group_expenses_repository.dart` — edits replace the doc (G-01/G-02), atomic `recordPayment` that settles only that pair when it reaches zero (G-07, G-15, G-16), delete/edit notifications (G-52).
- `groups/data/group_mirror_service.dart` — pure `decideMirror` (own share only, dated by expense, tombstones, removes v1 wrong-user mirrors) + incremental scan (G-04..G-06, P-10).
- `groups/data/groups_repository.dart` — create in one batch (G-45), join via `group_codes` (case-insensitive, G-29/G-31), last-admin guard + demote (G-21), notify after delete (G-24), rotate code, close stale invites (G-33).
- `friends/data/friends_repository.dart` — mutual auto-accept, cancel/unfriend, nicknames (F-01..F-03).
- `notifications/data/notifications_repository.dart` — generic `send`, chunked mark-all/clear, cleanup, private reminder cooldown (F-09, F-11).
- `auth/data/auth_repository.dart` — single verification email, real reset, code registry, email privacy, change password, UPI ID (P-11, P-12, P-19, F-05, S-04/S-05 data side).
- Tests: `test/core/*` — 49 passing (money, split calculator, settlement/pairwise, recurrence, mirror decisions).

### Phase 4 — Design system — ✅ 2026-11-15
- `core/theme/tokens.dart`, `aurora_colors.dart` (ThemeExtension, `context.aurora`), `app_theme.dart` (light+dark, all component themes, Plus Jakarta Sans, tabular figures, shared-axis transitions), `theme_mode_provider.dart`.
- `shared_widgets/`: `motion.dart` (entrance stagger, Pressable), `cards.dart` (AppCard, GradientCard, AuroraBackground), `amount_text.dart`, `avatars.dart` (PersonAvatar, UserAvatar, AvatarStack), `buttons.dart`, `bits.dart` (Pill, CategoryBubble, IconBadge, SectionHeader, SoftProgressBar), `states.dart` (Empty/Error/Skeleton), `feedback.dart` (Toast, sheets, confirmAction), `code_chip.dart`, `progress_ring.dart`, `celebrate.dart` (confetti), `inputs.dart`, `receipt_viewer.dart`.
- `features/export/export_service.dart` replaces `export_helper.dart` (group PDF + personal CSV/PDF).

### Phase 3 — Security rules — 🚀
- `firestore.rules` rewritten: members-only groups; join only by adding yourself with the current code or a pending invite; admin-only fields; leave = remove only yourself; friendships can only be accepted by the recipient (status-only change); nickname edits only on your own edge; notifications private to the recipient; public profile can't hold email; friend codes must be owned in `app_codes`; expense shape validation; no hard deletes.
- Not deployed (needs your go-ahead). Emulator not runnable here (no Java) → manual matrix in `AUDIT.md`.
- ⚠️ Deploy together with the v2 APK — v1 clients will be rejected by the new rules.

### Phase 5 — Screens — ✅ 2026-11-15
- [x] Auth: splash, login (real forgot-password), signup (terms enforced for Google too), verify (scrollable, single email, resend cooldown)
- [x] Home (`features/home`): greeting header + search + bell, gradient hero (month spend, trend, owed/owe), recap card, budget rings, range & category chips, donut/list toggle, 6-month trends (tap a bar), day-grouped list with swipe-to-delete + Undo, detail sheet
- [x] Add/edit personal expense: big amount, category grid + inline "New", Today/Yesterday/date, receipt, notes, recurring
- [x] Groups list: overview, invitations (accept/decline), group cards with avatars + balance pill, create & join sheets
- [x] Group detail: collapsing gradient header, tabs **Expenses · Balances · Stats · Members**, activity timeline sheet, PDF export, rename / leave / delete with balance warnings
- [x] Add/edit group expense: paid-by avatars, Equal / Exact / % / Items with live meter, receipt, notes, recurring
- [x] Join (deep link) screen with preview
- [x] Friends: code hero, requests, friends with pairwise balances, sent requests (cancel), friend sheet (shared groups, nickname, remove)
- [x] Notifications (single inbox): typed icons, routing per type, swipe delete, mark all / clear
- [x] Profile: avatar upload (visible to friends), stats, settings, theme picker, change password, sign-out confirm; Personal info with UPI ID
- [x] Categories & budgets, Recurring (personal + group, next date, pause/resume), Receipts vault (lazy thumbnails, search)
- **Removed:** Personal Insights, Group Insights, Settlement screen, Groups notification sheet, payer ranking, "Receipt Total", fake login bits, currency setting, stub/dead files.

### Phase 6 — New features — ✅ 2026-11-15
- [x] **Budgets + smart home** — `monthlyBudget` per category, rings + 80%/100% alerts on save, owed/owe + trend on Home
- [x] **UPI settle-up** — UPI ID on profile; "Pay via UPI" opens the UPI app (`upi://pay…`), then "Did it go through?" → record (Android `<queries>` + iOS `LSApplicationQueriesSchemes`)
- [x] **Search + expense details** — global search (scope + time filters); personal & group detail sheets with split, settled ticks, receipt, notes, history
- [x] **Monthly recap + export** — story-style recap, shareable PNG; CSV & PDF personal export; confetti when a debt hits ₹0

### Phase 7 — Verification — 🟡
- [x] `flutter analyze` → **No issues found**
- [x] `flutter test` → **72 passed** (money, split calculator, settlement & pairwise, recurrence, mirror decisions, home/recap stats, model back-compat, CSV, widget tests for login + themes)
- [x] Android build config upgraded for Flutter 3.50 (Gradle 9.5.0, AGP 9.3.1, Kotlin 2.4.20, Java 17) — v1 config no longer built on this SDK
- [x] `flutter build apk --debug` ✅ and `--release` ✅ (`build/app/outputs/flutter-apk/app-release.apk`, 63.7 MB). Added `kotlin.incremental=false` (Windows cross-drive Kotlin cache bug).
- [x] Manual E2E checklist on a device (below) — all items done on the USB phone
- [x] Deployed `firestore.rules` to `splitmate-6b600` — compiled and released successfully (added `firestore` target to `firebase.json` + `.firebaserc`)

### v2.1 — "Pop Brutal" redesign (UI/UX Pro Max) — ✅ 2026-11-16
- Ran the UI/UX Pro Max design-system search for a Gen-Z fintech / bill-splitting app; you picked **Pop Brutal** (neubrutalism) from 3 options.
- New tokens: cream paper with ink outlines, hard offset shadows, pop palette, Space Grotesk (`tokens.dart`, `aurora_colors.dart`, `app_theme.dart`).
- New core primitive `BrutalSurface` (press-in interaction); every card, button, chip, pill, avatar, chart, sheet, nav bar and tab bar restyled.
- Screens updated: home hero and owed/owe tiles, groups overview and group tiles, group header (stable pop colour per group), friends code card, profile, join, recap (icon stickers instead of emoji), brand mark.
- Money-app guardrails: no decoration on amounts, colour always paired with words, confirmations not tilted (see `DESIGN_SYSTEM.md`).
- Checks: `theme_contrast_test.dart` (WCAG AA both themes), visual renders in `docs/design/`, analyze clean, 79 tests pass.

### On-device end-to-end test — ✅ 2026-11-16 (OPPO CPH2467, Android 15, your real account)
Driven via adb with screenshots; every test entry was labelled `TEST`, kept in a solo test group (no friend was notified), and deleted afterwards. Theme and budgets restored.

**Verified working:** session restore; home dashboard (totals, trend, owed/owe = ₹2,325.38 matches group balances); recurring weekly instances dated on their due Fridays; add / edit / swipe-delete + Undo; detail sheet; search (personal + group); personal mirror of group shares (dated by expense, split exactly ÷3); create group → auto-open; itemized split + validation; group activity log; group expense delete removes the personal mirror (₹440 → ₹190); delete group; Balances tab pairwise maths; Stats; Members + code; Friends with balances & photos; Notifications routing (old group → info sheet, marks read, badge 3 → 2); budgets (95% amber, 105% red + alert toast); light/dark/auto theme persisted across restart; Receipts vault (legacy receipts load); Monthly recap; Recurring "next on" date; Firestore rules accepted every write (no permission errors).

**Bugs found on the phone and fixed (all re-verified on device):**
1. Floating "Add expense / New group" buttons hidden behind the nav bar
2. Bottom sheets rendered under the nav bar
3. Home hero card not full width
4. Greeting truncated
5. Group name truncated by the balance pill
6. White header icons + status bar on light group colours
7. "Mark received" wrapping → "Received"
8. **Recurring screen crash** (`TabAlignment.start` on a non-scrollable TabBar)
9. ₹ symbol detached from the amount
10. Category picker tiles in the old style (+ 1.8px overflow after restyle)
11. Split-mode buttons breaking words ("Equ/al")
12. "not involved" shown for your own share → "your share"
13. Duplicate "Add expense" on empty groups
14. Delete/leave group didn't return to the list
15. Info message showed a pointless Cancel button
16. Budget alert used an info icon → amber warning
17. "Theme" label wrapping
18. Ink ripples hidden inside cards (debug assertion)
19. Material FABs without the Pop Brutal shadow → shared `PopFab`
20. Tight spacing between category cards

**Not tested on device (would need a second account or real money):** ~~recording/receiving a real payment, Pay via UPI hand-off, friend request accept between two accounts, join-by-code from another account~~ (done below), offline mode, sign-up / email verification / Google sign-in.

### Two-account on-device test — ✅ 2026-11-16 (same phone, A = your account, B = new test account "qwer")
Accounts switched on the phone (you signed in each time). Test data lived in two throwaway groups, **TEST Pay** and **TEST Link**; afterwards both groups, A's two mirrored entries, A's test notifications and the A↔B friendship were removed, so A is back to how it was (Home: spent ₹150, owed ₹100, owe ₹0). B keeps the test UPI ID `splitmate.qa.test@upi`.

**Verified working:** join by deep link while logged out (link survives sign-in, lands on the invite screen); join by code typed in lowercase; back after joining; friend request by code → badge → accept on the other account; unfriend (open-balance warning); mutual request auto-accepts (lowercase code); group expense equal and % split (live "left to assign" meter); notifications across accounts (expense added, friend request/accepted, paid you, reminder, marked received) and routing to the group; pairwise balances on Balances tab and Friends; Pay via UPI → Android chooser (GPay / Amazon Pay / INDIE) → payee, amount and note reach GPay → "Did it go through?" → record; partial payment (₹50 of ₹150) then the rest → confetti + "All square"; creditor "Received" flow; Remind + "Reminded" cooldown; mirrors in both ledgers with group tag and category (debtor mirror after settlement); delete group; no stale A data after switching to B. No payment was made: GPay stayed locked and has no bank account.

**Bugs found and fixed (re-verified on device):**
1. **Denied listeners retried forever** (`retryOnPermissionDenied`): Firestore replays the cached snapshot before the server's denial, which reset the retry counter → ~2.4 re-listens/sec per stream after sign-out (3,316 denied listens in one session) and an endless loop for a removed member. Budget now refills only after 10 s of healthy subscription; verified: 4 attempts then stop.
2. **Friend request card unreadable (black)**: translucent card tints let the Pop Brutal hard shadow show through. `BrutalSurface` now blends tints onto the opaque surface; fixes the request card, the friend sheet balance card and the group invitation card.
3. **UPI note showed `SplitMate+·+TEST+Pay`** in GPay: `Uri.queryParameters` encodes spaces as `+`. Link is now built with `%20` (payee names with spaces were affected too).
4. **Settlement by the other person never reached your ledger until a cold start**: the mirror scan ran once per user per app process, so signing out/in or coming back to the app skipped it. Bootstrap now re-runs after sign-out → sign-in, and an incremental scan runs when the app returns to the foreground (max once a minute). Cold-start path verified on device; the resume and re-login paths are covered by code review only.
5. Personal info **Save button hidden behind the keyboard** → lifted above it.
6. "Pay via UPI" label wrapped onto two lines → kept on one line.

Checks: analyze clean, **85 tests pass** (new: `test/core/firestore_helper_test.dart`, `test/core/upi_uri_test.dart`).

**Follow-up fixes (same day):** handling a friend request (accept, decline, or mutual auto-accept) or a group invite now marks its notification read (E-07, unit-tested; not yet seen across two accounts on the device). Back on Personal info with unsaved edits asks "Discard changes?" (E-08, verified on device: system Back, app-bar back, Cancel, Discard, no prompt when unchanged). 87 tests pass.

### New logo + animated splash — ✅ 2026-11-16
- **Logo:** a coin split into two halves (mint = owed to you, coral = you owe) on brand yellow, with ink outlines and hard shadows. Drawn in code (`shared_widgets/logo_mark.dart`, animatable `split` value) and as PNGs (`assets/icon/icon.png`, adaptive foreground `icon_fg.png`, `assets/logo.png`) by `flutter_launcher_icons`. Preview: `docs/design/logo.png`.
- **Splash** (`features/auth/presentation/splash_screen.dart`), about 1.9s: the tile drops in with an elastic bounce, the coin splits apart (with a haptic) while an ink ring ripples out, the "SplitMate" letters bounce up one by one, and the "Split bills. Stay friends." sticker fades in. The router waits for `splashDoneProvider`, so the animation always finishes; deep links are kept in `?from=`. Under reduce-motion it's skipped.
- Native Android launch background and Android 12+ splash colour changed to brand yellow (`values/colors.xml`), so there's no flash before the animation.
- Verified on device (release APK); analyze clean, 79 tests pass.
- **Splash v2 (about 5.4s, on request):** the two coin halves fly in spinning from opposite corners, click into one coin (haptic, bump, double shockwave, pop-colour sparks), flip like a coin toss, land in the logo tile, re-split into the logo, then the wordmark letters bounce in and the tagline sticker pops. (The bottom progress bar was removed later on request.) A doubled-coin glitch during the tile hand-off was spotted on the phone and fixed. Installed and verified on device.

### Two-account round 2 — ✅ 2026-11-16 (same phone, A = your account, B = "qwer")
Test group **TEST R2** (created by B, A invited) plus a solo **TEST Solo** for a fix check; all test groups, A's mirrored entries, A's test notifications and the A↔B friendship were removed afterwards (A: spent ₹150, owed ₹100, owe ₹0, 2 friends; a search for "TEST" finds nothing).

**Verified working:** group invite → Invitations card → Join opens the group; accepting a friend request / invite marks its notification read (E-07 now seen on device); Exact split with live meter; creditor "Received" then edit → settled mark and date kept, history entry added; edit removes a member → that member shows "—", group settles to 0; delete expense → payer's mirror gone, involved members notified (uninvolved members correctly aren't); monthly recurring from 31 Aug → 31 Aug / 30 Sep / 31 Oct, no duplicates after the second member's sign-in ran the engine; debtor's mirrors appear on their original dates after settling; non-admins get no remove option; admin removing a member with a balance gets the ₹ warning; last admin can't leave; notification routing (edited expense → group, deleted group → "nothing to open"); mark all read clears the badge; clear all → "You're all caught up"; recap share sheet; CSV and PDF export (`SplitMate_All_time.csv/.pdf`); airplane mode → "Expense added — will sync when you're online", total updates at once, no write errors after reconnecting (the server copy itself can't be inspected from the app).

**Bugs found and fixed:**
1. **Recurring instances missing from the payer's ledger** until the next app launch (and never if the group was deleted first): the engine run after saving a template wrote instances but no mirrors. The incremental mirror scan now runs right after it. Verified on device: 3 back-filled shares appear immediately.
2. Recap said **"0% less than September"** and **"1 expenses"** → "Same as September", "1 expense" (also on the share card). Verified on device.
3. Last admin tapping Leave saw a "Leave group" button that then failed → now says "Make someone else an admin first" up front.

**Note:** an extra tap during the recap test opened Google Lens with B's recap image from the share sheet (B's test data only; nothing was sent to any person).

### Auth flows — ✅ 2026-11-16 (you drove sign-up, inbox and Google; I watched screen + logs)
**Verified working:** sign-up refuses without Terms; one verification email; after verifying, the app continues into the app; forgot-password email arrives; Google sign-in works with the debug-key SHA-1 registered in Firebase (`6B:73:1A…`).

**Bugs found and fixed:**
1. **Google sign-in on the login screen skipped the Terms** for a first-time user (the earlier fix only covered the sign-up screen). A brand-new Google user now gets a "New to SplitMate?" terms sheet; "Not now" deletes the just-created auth user before anything is written. The session bootstrap now waits until sign-up/Google seeding finishes, so it can't create a profile for an account that's being undone (also removes a race with sign-in's own profile seeding). Verified on device: Not now → stays on login, no account; I agree → account with friend code, Home.
2. **After sign-out, the next sign-in (even another account) reopened the previous account's screen** (`/login?from=…` kept the sign-out location, e.g. someone else's group). Only invite links (`/join?code=…`) are kept now. Verified on device: sign out from Profile → sign in → Home. Unit test `test/core/invite_link_test.dart`.

### UI tweaks — ✅ 2026-11-16 (on request)
- Splash: removed the moving progress bar at the bottom; the rest of the animation is unchanged.
- Profile: removed the "SplitMate 2.0 · Made with 💜" footer.
- Home: new **All time** range chip in front of Today / This week / This month / Custom (labelled "All time" so it isn't confused with the category row's "All"). Empty state reads "No expenses yet". Verified on device.

### Release signing + app ID — ✅ 2026-11-17
- Release builds are now signed with a real release key instead of the debug key. Gradle reads it from `android/key.properties` (git-ignored); the keystore lives outside the repo. Without that file a release build still works but is debug-signed and prints a warning.
- App ID changed from the placeholder `com.example.split_mate` (rejected by the Play Store) to **`com.ak3112511.splitmate`**, registered as a new Android app in Firebase (`…:android:fefd1dd54d86a324dcaeca`); `google-services.json` and `firebase_options.dart` updated. The Kotlin namespace is unchanged.
- Release and debug SHA-1 / SHA-256 fingerprints added to the new Firebase app. Release SHA-1 `54:2E:4C:A7:FB:DB:16:59:A4:F6:97:3B:9F:30:66:63:BA:AA:36:40`.
- Version 2.0.1+4. Verified on device: installs as the new app, Google and email sign-in work, and a later build installs as an update.
- Existing installs (old ID + debug key) can't update to this; users install the new app and uninstall the old one. Accounts and data are unaffected.
- If the app goes to the Play Store with Play App Signing, add Play's app-signing SHA-1 to Firebase as well.

### Account deletion + privacy policy — ✅ 2026-11-17
- **Delete account** (Profile → Delete account, under Sign out): explains what's deleted and what stays; **blocked while you owe anyone** (lists who and how much, with "Go to groups"); warns if others owe you; confirms with the way you signed in (password or Google, with a switch when an account has both).
- Deletion (all on the device, no Cloud Functions): leaves every group (hands admin to another member first if needed; a solo group is soft-deleted), removes friendships both ways, declines received invites, deletes sent invites and own notifications, deletes personal expenses / receipts / reminders / private profile, frees the friend code, deletes the profile, then the sign-in. Shared group records stay; the person shows as **"Deleted user"**.
- Rules: the owner may now delete their own `users/{uid}` profile (deployed).
- **Privacy policy** at https://splitmate-6b600.web.app/privacy, deletion info at https://splitmate-6b600.web.app/delete-account, small home page at https://splitmate-6b600.web.app (Firebase Hosting, `hosting/`). Contact: splitmate.support123@gmail.com. Linked from Profile, the delete screen and both Terms sheets.
- Verified on device: an account owing ₹20 is blocked ("Settle up first"); test account qwer deleted (Google confirmation), and signing in with its Google account again is treated as a brand-new user. Policy link opens in the browser.
- Found during testing: an email account later used with Google sign-in has both methods; the screen first insisted on the password → now uses the current sign-in method and offers the other.

### Tappable invite links — ✅ 2026-11-17
- Group invites are now shared as `https://splitmate-6b600.web.app/join?code=XXXXXX` (WhatsApp makes these tappable; `splitmate://` links weren't). The old `splitmate://join` links still work.
- Android App Link: `autoVerify` intent filter for `/join` on `splitmate-6b600.web.app`, verified by `hosting/.well-known/assetlinks.json` (release key SHA-256 only). Firebase Hosting now publishes dot-folders (ignore list no longer hides `.well-known`).
- Without the app (or in a browser), `/join` shows the code with Copy, **Open in SplitMate** (Android intent link, falls back to the download page) and **Download SplitMate**, plus manual steps.
- Verified: Google's Digital Asset Links API reads the statement; `pm get-app-links` → `verified`; an https invite opens the app directly (no browser, no chooser), survives sign-in and lands on the invite screen; the web page's button opens the app; a real invite sent in WhatsApp was tappable and opened SplitMate.
- Needs v2.0.3 installed to open links directly; older versions get the web page, whose button still opens the app. If the app later uses Play App Signing, add Play's SHA-256 to `assetlinks.json`.
- Version 2.0.3+6.

### Friends without the app (guest members) — ✅ 2026-11-17
- Any member can add someone who isn't on SplitMate yet ("Add someone without the app" in Members, or the **Add** bubble in Add expense). Guests take part in every split mode, balances, stats and the PDF; you can record cash payments with them. No UPI button, reminders or notifications for guests.
- Taking over a spot: **"Send Rahul their link"** shares an invite made for that guest (`/join?code=…&guest=…`); opening it joins the group and asks **"Are you Rahul?"** with the guest's balance. As a fallback, whoever added the guest (or an admin) can use **"They already joined…"** to move the guest to a member. Either way every expense, payment, item split and recurring template moves to the real account (shares are merged if that person already had one), the guest is removed, the activity log and the group are told, and the new owner's personal ledger updates.
- Data: `guests` map on the group doc (`guest_…` ids); rules allow members to change only that field (deployed). Guest ids never get group access and are skipped for notifications.
- Verified on device: guest added, ₹300 split with them, ₹50 cash received; claim link opened while signed out survived sign-in and "Are you Rahul?" moved everything (claimant owed ₹100, payment and share now theirs, activity "took over Rahul's spot", group notified); second guest linked by hand to an existing member and their shares merged (₹30 + ₹30 → ₹60). Test group, ledger entries and notifications cleaned up.
- Version 2.1.0+7.

### WhatsApp sharing — ✅ 2026-11-17
- **Share balances** (share icon next to "Who owes whom"): preview card with group name, date, total spent and who owes whom (real names, not "You"), shared as an image with a one-line caption and the group's invite link.
- **Remind on WhatsApp:** "Remind" on a debt owed to you now offers *In SplitMate* (notification, once a day) or *On WhatsApp*; guests get a WhatsApp button directly. The message is one line: amount and group, a tappable pay link when you have a UPI ID, and the claim link for guests. Falls back to the share sheet without WhatsApp; suggests adding a UPI ID when missing.
- **Pay page** https://splitmate-6b600.web.app/pay (hosting/pay.html): validates the UPI ID and amount, shows "Pay ₹X to Name" with the UPI ID and a button that opens the UPI app (WhatsApp doesn't make `upi://` links tappable). Not an App Link, so it always opens in the browser.
- Verified on device (nothing sent or paid): preview card and share sheet with image + caption; WhatsApp opened on "Send to…" with the message; pay page rendered and its button opened Android's UPI app chooser. Test group and ledger entry cleaned up.
- Version 2.2.0+8.

### Faster adding: shortcuts, widget, category guess, bill scan — ✅ 2026-11-18
- **Long-press shortcuts** on the app icon: *Add an expense* and *Scan a bill*. Android launches static shortcuts with CLEAR_TASK, which would restart a running app and replay the intro, so they go through a tiny invisible `QuickLaunchActivity` (own task affinity) that forwards `splitmate://add` / `splitmate://scan` to MainActivity.
- **Home-screen widget** (4×1, resizable): yellow *Add expense* button and a mint scan button, Pop Brutal outlines and shadows (`QuickAddWidget.kt`, `res/layout/widget_quick_add.xml`, preview image for launchers that ignore `previewLayout`).
- Quick-launch links skip the intro animation and open on top of whatever was open (Close goes back there); the amount keyboard is re-requested once the window has focus (Android ignores autofocus while the app is still coming to the front).
- **Category guessing** (`categories/domain/category_guesser.dart`): your own history first (same description → same category; a word used twice for one category carries over), then a category's name in the text, then a list of common Indian merchants and words (Uber/Ola/Rapido → Travel, Swiggy/Zomato → Food, Blinkit/Zepto → Groceries, Netflix → Entertainment…), with phrases first ("Uber Eats" → Food). Works with renamed defaults. Shown as an *Auto-picked* pill; tapping a category stops guessing. On both add screens.
- **Quick picks**: your frequent recent personal expenses as one-tap chips (fills the amount too when it has always been the same). Amount → Next → description → Done saves.
- **Bill scan** (ML Kit text recognition, on the phone, Latin script): photo or gallery → items, quantities (×4), tax/service charge, discount, round-off and the printed total → Items split with everyone ticked; tap people off items. The photo is kept as the receipt and the shop name fills the description. A card says whether the items add up to the bill's total.
  - Parser (`bill_scan/domain/bill_parser.dart`) regroups OCR lines into printed rows after undoing the photo's tilt, matches bill labels as whole words ("Vegetable" isn't a table number), ignores GST summaries after the grand total, fixes OCR look-alikes in prices (240.0e, 1OO.OO), and never drops an item with an unreadable price: qty × rate or the subtotal fills it, otherwise it's left blank to type in.
  - Itemized splits gained **Tax & charges** and **Discount** (`itemsExtra` on the expense, kept on recurring copies), shared in proportion to what each person had. Shown in the expense details.
- Release builds: R8 keep rules for ML Kit (`android/app/proguard-rules.pro`; without them the first scan crashed inside ML Kit). The release APK is now built for ARM phones only (`--target-platform android-arm,android-arm64`): 71.4 MB instead of 92.9 MB with the x86_64 slice.
- Tests: 128 pass (new: category guesser, bill parser incl. real ML Kit output from the phone, proportional tax/discount). Analyze clean.
- **Verified on device** (OPPO CPH2467, release APK): both shortcuts cold and warm (form in ~1.1 s, no intro, Close returns to the previous tab); widget added from the picker, both buttons; "TEST Uber" → Travel auto-picked and saved with Done; group picker for scan; a tilted photo of a GST bill read fully (5 items, ₹128 tax, matches ₹1,408), who-had-what shares ₹781 / ₹627 as calculated by hand, tax line in details, edit reopens with the tax. Test group, expense, guest, widget and photo removed afterwards.
- Found and fixed on the phone: ML Kit crash under R8; "240.0e" dropping an item; on a cold start from a shortcut the form picked a built-in category id before your profile loaded (would have saved as "Other"); keyboard not opening from a shortcut; widget label cut off at 3 cells.
- Not verified: a real paper bill photographed with the camera (only a rendered bill photo from the gallery), the resized 4-cell widget label on the home screen, iOS (no shortcuts/widget there).
- Version 2.3.0+9.

### Shares, trips, currencies, comments, UPI QR — ✅ 2026-11-18
- **Split by shares** (new *Shares* mode): − / + per person (a couple = 2, 0 leaves someone out) and optional **adjustments** ("+₹50 for the one who ate more"): adjustments come off the top, the rest is split by shares, leftover paise to the payer. Stored as `shareWeights` / `adjustments`; the details show "2 shares · +₹50".
- **Multiple currencies**: "Paid in another currency?" under the amount → 26 currencies (USD, EUR, GBP, AED, THB, SGD, MYR, IDR, VND, LKR, NPR…). Today's rate from ExchangeRate-API's free open endpoint (only the currency code is sent; attribution shown), cached on the phone for offline use, always editable. Expenses are **saved in rupees** (amount, splits, items, adjustments), so balances, settling, personal ledgers, the PDF and older app versions keep working; what was typed is kept in `fx` (currency, rate, amounts) for display and editing. Every split mode and the bill scan work in the chosen currency.
- **Trip mode**: "It's a trip" when creating a group, or *Make it a trip* in the menu (admins): dates and a trip currency (new expenses start in it). The header shows "17–20 Nov 2026 · Day 2 of 4"; a trip card above the expenses opens the **Trip summary**: total, per day, per person, biggest expense, busiest day, top categories, currencies used, who consumed / paid what, shareable as an image, and **Settle everything** (fewest payments, each with QR / remind / record).
- **Comments on an expense**: thread in the expense details (long-press your own to delete), count on the expense row, in-app notification to everyone in the expense. Stored in `groups/{g}/expenses/{e}/comments`; new rules (deployed): members read and add their own (≤500 chars, server time), only the author deletes. Expense rows keep a `commentCount`.
- **UPI QR**: "Show my UPI QR" on any debt owed to you (amount filled in, then "They paid · record it") and in Personal info (no amount). Dark on white even in dark mode. Without a UPI ID it explains and links to Personal info.
- Layout fixes found on the phone: five split modes in one row (labels shrink instead of clipping), wider adjustment fields, trip stats spacing, debt-card buttons with the QR button (text-only WhatsApp/Remind, "Received" no longer cut).
- Tests: 146 pass (new: shares + adjustments, rupee conversion that adds up exactly, foreign expense round trip and older documents, trip days / summary / date ranges, QR sheet). Analyze clean.
- **Verified on device** (release build): trip group created with dates and THB, "Day 2 of 4" header and trip card; expense opened in baht with a live rate (1 THB = ₹2.7643), ฿1,000 by shares 2:1 with +฿100 → ฿600 / ฿400, saved as ₹2,764.30 with ₹1,105.72 owed; details show "฿1,000 at ₹2.7643 per THB" and the shares; edit reopened everything in baht; trip summary numbers and settle-everything card; "add your UPI ID first" path. Test group, guest and expense removed afterwards.
- **Comments verified on device** after the rules deploy (solo test group): "Includes tip" added and shown, the sheet stays above the keyboard, the row shows a comment count of 1, long-press → delete works, no permission errors. Test group removed.
- **Not verified**: the QR code on screen (your account has no UPI ID; covered by a widget test); sharing the trip summary image.
- Version 2.4.0+10.

## Manual end-to-end checklist (Phase 7)

Two test accounts (A, B) on an Android emulator.

- [x] Signup → verification email (once) → verify → home
- [x] Forgot password email arrives
- [x] Login with Google (terms respected)
- [x] A adds B by code → B accepts → both see each other; mutual request auto-accepts
- [x] A creates group with B invited → B accepts → A opens group
- [x] Join by code (lowercase works) and by deep link while logged out
- [x] Add expense: Equal / Exact / Percent / Itemized; live "left to assign" meter
- [x] Edit expense (remove a member) → balances sum to 0; date & settled flags kept
- [x] Delete expense → mirrors hidden; members notified
- [x] Balances tab pairwise; Pay via UPI opens UPI app → Record payment → confetti
- [x] Mirrors appear in both personal ledgers with original dates & categories
- [x] Recurring monthly template on 31st → instances clamp to month end; no duplicates across A & B
- [x] Budget 80% / 100% alerts
- [x] Search finds personal + group expenses; detail sheet edit/delete
- [x] Monthly recap shares as image; CSV + PDF export open
- [x] Theme: System / Light / Dark persists across restart
- [x] Airplane mode: add expense → "Saved — will sync" → syncs later
- [x] Logout A → login B: no stale A data anywhere
- [x] Notifications: each type routes correctly; mark all read; clear
- [x] Remove member with balance → warning; last admin cannot leave
