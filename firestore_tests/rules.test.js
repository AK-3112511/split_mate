// Firestore security rules, tested against the local emulator.
// Run from the repo root:  firebase emulators:exec --only firestore "npm --prefix firestore_tests test"
// Cast: alice (group admin), bob (member), carol (not in the group).

import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, test } from 'node:test';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  addDoc,
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  serverTimestamp,
  setDoc,
  updateDoc,
  writeBatch,
} from 'firebase/firestore';

let env;
const as = (uid) => env.authenticatedContext(uid).firestore();
const alice = () => as('alice');
const bob = () => as('bob');
const carol = () => as('carol');

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-splitmate-rules',
    firestore: { rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8') },
  });
});

after(async () => {
  await env?.cleanup();
});

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'groups/g1'), {
      name: 'Trip',
      members: ['alice', 'bob'],
      admins: ['alice'],
      createdBy: 'alice',
      isDeleted: false,
      inviteCode: 'ABC123',
    });
    await setDoc(doc(db, 'groups/g1/expenses/e1'), { amount: 100, splits: { alice: 50, bob: 50 }, payerUid: 'alice' });
    await setDoc(doc(db, 'groups/g1/expenses/e1/comments/c1'), { authorUid: 'alice', authorName: 'Alice', text: 'includes tip', createdAt: new Date() });
    await setDoc(doc(db, 'groups/g1/activity/a1'), { actorUid: 'alice', type: 'expense_added' });
    await setDoc(doc(db, 'group_codes/ABC123'), { groupId: 'g1' });
    await setDoc(doc(db, 'users/alice'), { name: 'Alice' });
    await setDoc(doc(db, 'users/alice/expenses/x1'), { amount: 40 });
    await setDoc(doc(db, 'users/alice/private/profile'), { email: 'alice@example.com' });
    await setDoc(doc(db, 'app_codes/BOBCOD'), { uid: 'bob' });
    await setDoc(doc(db, 'friends/alice/friendList/carol'), { status: 'pending', sentBy: 'alice' });
    await setDoc(doc(db, 'friends/carol/friendList/alice'), { status: 'pending', sentBy: 'alice' });
    await setDoc(doc(db, 'group_invites/i1'), { groupId: 'g1', recipientUid: 'carol', senderUid: 'alice', status: 'pending' });
    await setDoc(doc(db, 'group_invites/i2'), { groupId: 'g1', recipientUid: 'dave', senderUid: 'alice', status: 'pending' });
    await setDoc(doc(db, 'notifications/n1'), { recipientUid: 'bob', senderUid: 'alice', isRead: false, message: 'Alice added Dinner' });
  });
});

describe('groups', () => {
  test('R1: a non-member cannot read the group, its expenses or its activity', async () => {
    await assertFails(getDoc(doc(carol(), 'groups/g1')));
    await assertFails(getDoc(doc(carol(), 'groups/g1/expenses/e1')));
    await assertFails(getDocs(collection(carol(), 'groups/g1/activity')));
    await assertFails(getDocs(collection(carol(), 'groups/g1/expenses/e1/comments')));
  });

  test('members can read the group', async () => {
    await assertSucceeds(getDoc(doc(bob(), 'groups/g1')));
    await assertSucceeds(getDoc(doc(bob(), 'groups/g1/expenses/e1')));
  });

  test('signed-out users can read nothing', async () => {
    const anon = env.unauthenticatedContext().firestore();
    await assertFails(getDoc(doc(anon, 'groups/g1')));
    await assertFails(getDoc(doc(anon, 'users/alice')));
  });

  test('R2: a non-member cannot add themselves without the join code', async () => {
    await assertFails(updateDoc(doc(carol(), 'groups/g1'), { members: ['alice', 'bob', 'carol'] }));
  });

  test('R3: a non-member joins with the right code, not a wrong one', async () => {
    await assertFails(updateDoc(doc(carol(), 'groups/g1'), { members: ['alice', 'bob', 'carol'], joinCode: 'WRONG1' }));
    await assertSucceeds(updateDoc(doc(carol(), 'groups/g1'), { members: ['alice', 'bob', 'carol'], joinCode: 'ABC123', updatedAt: serverTimestamp() }));
  });

  test('R4: the join code cannot be used to add someone else', async () => {
    await assertFails(updateDoc(doc(carol(), 'groups/g1'), { members: ['alice', 'bob', 'dave'], joinCode: 'ABC123' }));
    await assertFails(updateDoc(doc(carol(), 'groups/g1'), { members: ['alice', 'bob', 'carol'], joinCode: 'ABC123', admins: ['alice', 'carol'] }));
  });

  test('nobody joins a deleted group', async () => {
    await env.withSecurityRulesDisabled((ctx) => updateDoc(doc(ctx.firestore(), 'groups/g1'), { isDeleted: true }));
    await assertFails(updateDoc(doc(carol(), 'groups/g1'), { members: ['alice', 'bob', 'carol'], joinCode: 'ABC123' }));
  });

  test('R5: a non-admin member cannot rename, delete or change admins', async () => {
    await assertFails(updateDoc(doc(bob(), 'groups/g1'), { name: 'Hacked' }));
    await assertFails(updateDoc(doc(bob(), 'groups/g1'), { isDeleted: true }));
    await assertFails(updateDoc(doc(bob(), 'groups/g1'), { admins: ['alice', 'bob'] }));
  });

  test('the admin manages the group but cannot change its creator', async () => {
    await assertSucceeds(updateDoc(doc(alice(), 'groups/g1'), { name: 'Goa 2026' }));
    await assertFails(updateDoc(doc(alice(), 'groups/g1'), { createdBy: 'bob' }));
  });

  test('R6: a member can leave, but cannot remove someone else', async () => {
    await assertFails(updateDoc(doc(bob(), 'groups/g1'), { members: ['bob'] }));
    await assertSucceeds(updateDoc(doc(bob(), 'groups/g1'), { members: ['alice'], updatedAt: serverTimestamp() }));
  });

  test('a member can add guests (people not on SplitMate)', async () => {
    await assertSucceeds(updateDoc(doc(bob(), 'groups/g1'), { guests: [{ id: 'guest_1', name: 'Riya' }] }));
    await assertFails(updateDoc(doc(carol(), 'groups/g1'), { guests: [{ id: 'guest_1', name: 'Riya' }] }));
  });

  test('an invite lets only its recipient in', async () => {
    await assertSucceeds(updateDoc(doc(carol(), 'groups/g1'), { members: ['alice', 'bob', 'carol'], joinInviteId: 'i1', updatedAt: serverTimestamp() }));
  });

  test('someone else\'s invite does not work', async () => {
    await assertFails(updateDoc(doc(carol(), 'groups/g1'), { members: ['alice', 'bob', 'carol'], joinInviteId: 'i2' }));
  });

  test('a new group must start with only its creator', async () => {
    const base = { name: 'New', admins: ['carol'], createdBy: 'carol', isDeleted: false };
    await assertSucceeds(setDoc(doc(carol(), 'groups/g2'), { ...base, members: ['carol'] }));
    await assertFails(setDoc(doc(carol(), 'groups/g3'), { ...base, members: ['carol', 'alice'] }));
    await assertFails(setDoc(doc(carol(), 'groups/g4'), { ...base, members: ['carol'], createdBy: 'alice' }));
  });

  test('R12: groups and expenses are never hard-deleted', async () => {
    await assertFails(deleteDoc(doc(alice(), 'groups/g1')));
    await assertFails(deleteDoc(doc(alice(), 'groups/g1/expenses/e1')));
  });
});

describe('expenses', () => {
  const expense = (amount) => ({ amount, splits: { alice: amount / 2, bob: amount / 2 }, payerUid: 'bob' });

  test('a member can add a normal expense; a non-member cannot', async () => {
    await assertSucceeds(setDoc(doc(bob(), 'groups/g1/expenses/e2'), expense(240)));
    await assertFails(setDoc(doc(carol(), 'groups/g1/expenses/e3'), expense(240)));
  });

  test('R13: zero, negative and absurd amounts are rejected', async () => {
    await assertFails(setDoc(doc(bob(), 'groups/g1/expenses/e2'), expense(0)));
    await assertFails(setDoc(doc(bob(), 'groups/g1/expenses/e2'), expense(-50)));
    await assertFails(setDoc(doc(bob(), 'groups/g1/expenses/e2'), expense(20000000)));
    await assertFails(setDoc(doc(bob(), 'groups/g1/expenses/e2'), { amount: 100, payerUid: 'bob' }));
  });
});

describe('comments', () => {
  const comment = (over = {}) => ({ authorUid: 'bob', authorName: 'Bob', text: 'paid in cash', createdAt: serverTimestamp(), ...over });

  test('a member comments as themselves', async () => {
    await assertSucceeds(addDoc(collection(bob(), 'groups/g1/expenses/e1/comments'), comment()));
  });

  test('no posting as someone else, no empty or overlong text, no extra fields', async () => {
    const path = 'groups/g1/expenses/e1/comments';
    await assertFails(addDoc(collection(bob(), path), comment({ authorUid: 'alice' })));
    await assertFails(addDoc(collection(bob(), path), comment({ text: '' })));
    await assertFails(addDoc(collection(bob(), path), comment({ text: 'x'.repeat(501) })));
    await assertFails(addDoc(collection(bob(), path), comment({ pinned: true })));
    await assertFails(addDoc(collection(bob(), path), comment({ createdAt: new Date(2020, 0, 1) })));
    await assertFails(addDoc(collection(carol(), path), comment({ authorUid: 'carol' })));
  });

  test('only the author deletes a comment, and nobody edits one', async () => {
    await assertFails(deleteDoc(doc(bob(), 'groups/g1/expenses/e1/comments/c1')));
    await assertFails(updateDoc(doc(alice(), 'groups/g1/expenses/e1/comments/c1'), { text: 'changed' }));
    await assertSucceeds(deleteDoc(doc(alice(), 'groups/g1/expenses/e1/comments/c1')));
  });
});

describe('activity', () => {
  test('entries are signed by the writer and cannot be changed', async () => {
    await assertSucceeds(addDoc(collection(bob(), 'groups/g1/activity'), { actorUid: 'bob', type: 'expense_added' }));
    await assertFails(addDoc(collection(bob(), 'groups/g1/activity'), { actorUid: 'alice', type: 'expense_added' }));
    await assertFails(updateDoc(doc(alice(), 'groups/g1/activity/a1'), { type: 'edited' }));
    await assertFails(deleteDoc(doc(alice(), 'groups/g1/activity/a1')));
  });
});

describe('friends', () => {
  test('R7: the sender cannot rewrite or accept their own request', async () => {
    await assertFails(updateDoc(doc(alice(), 'friends/carol/friendList/alice'), { sentBy: 'carol' }));
    await assertFails(updateDoc(doc(alice(), 'friends/carol/friendList/alice'), { status: 'accepted' }));
  });

  test('R8: the recipient accepts (status only)', async () => {
    await assertFails(updateDoc(doc(carol(), 'friends/carol/friendList/alice'), { status: 'accepted', sentBy: 'carol' }));
    await assertSucceeds(updateDoc(doc(carol(), 'friends/carol/friendList/alice'), { status: 'accepted' }));
  });

  test('no forced friendships: a request must come from the writer', async () => {
    await assertFails(setDoc(doc(alice(), 'friends/dave/friendList/alice'), { status: 'accepted', sentBy: 'alice' }));
    await assertFails(setDoc(doc(alice(), 'friends/dave/friendList/alice'), { status: 'pending', sentBy: 'dave' }));
    await assertSucceeds(setDoc(doc(alice(), 'friends/dave/friendList/alice'), { status: 'pending', sentBy: 'alice' }));
  });

  test('nicknames are private to their owner', async () => {
    await assertSucceeds(updateDoc(doc(alice(), 'friends/alice/friendList/carol'), { nickname: 'Caz' }));
    await assertFails(updateDoc(doc(carol(), 'friends/alice/friendList/carol'), { nickname: 'Caz' }));
  });

  test('outsiders cannot see a friendship', async () => {
    await assertFails(getDoc(doc(bob(), 'friends/alice/friendList/carol')));
  });
});

describe('notifications', () => {
  test('R9: only the recipient reads, marks or deletes a notification', async () => {
    await assertFails(getDoc(doc(alice(), 'notifications/n1')));
    await assertFails(updateDoc(doc(alice(), 'notifications/n1'), { isRead: true }));
    await assertFails(deleteDoc(doc(carol(), 'notifications/n1')));
    await assertSucceeds(getDoc(doc(bob(), 'notifications/n1')));
    await assertSucceeds(updateDoc(doc(bob(), 'notifications/n1'), { isRead: true }));
  });

  test('the recipient cannot rewrite the message', async () => {
    await assertFails(updateDoc(doc(bob(), 'notifications/n1'), { message: 'Alice owes you 1 lakh' }));
  });

  test('notifications cannot be sent in someone else\'s name', async () => {
    const n = { recipientUid: 'bob', isRead: false, message: 'hi' };
    await assertSucceeds(addDoc(collection(carol(), 'notifications'), { ...n, senderUid: 'carol' }));
    await assertFails(addDoc(collection(carol(), 'notifications'), { ...n, senderUid: 'alice' }));
    await assertFails(addDoc(collection(carol(), 'notifications'), { ...n, senderUid: 'carol', message: 'x'.repeat(301) }));
  });
});

describe('profiles and friend codes', () => {
  test('R10: email never goes into the public profile', async () => {
    await assertSucceeds(updateDoc(doc(alice(), 'users/alice'), { name: 'Alice K' }));
    await assertFails(updateDoc(doc(alice(), 'users/alice'), { email: 'alice@example.com' }));
    await assertFails(updateDoc(doc(carol(), 'users/alice'), { name: 'Hacked' }));
  });

  test('personal expenses and the private profile are owner-only', async () => {
    await assertSucceeds(getDoc(doc(alice(), 'users/alice/expenses/x1')));
    await assertFails(getDoc(doc(bob(), 'users/alice/expenses/x1')));
    await assertFails(getDoc(doc(bob(), 'users/alice/private/profile')));
    await assertFails(setDoc(doc(bob(), 'users/alice/expenses/x2'), { amount: 1 }));
  });

  test('R11: a friend code owned by someone else cannot be taken', async () => {
    await assertFails(updateDoc(doc(alice(), 'users/alice'), { appCode: 'BOBCOD' }));
    await assertFails(setDoc(doc(alice(), 'app_codes/BOBCOD'), { uid: 'alice' }));
  });

  test('claiming a free code and using it together works', async () => {
    const db = alice();
    const batch = writeBatch(db);
    batch.set(doc(db, 'app_codes/ALICE1'), { uid: 'alice' });
    batch.update(doc(db, 'users/alice'), { appCode: 'ALICE1' });
    await assertSucceeds(batch.commit());
  });

  test('the code registry cannot be listed', async () => {
    await assertFails(getDocs(collection(alice(), 'app_codes')));
    await assertFails(getDocs(collection(alice(), 'group_codes')));
  });
});
