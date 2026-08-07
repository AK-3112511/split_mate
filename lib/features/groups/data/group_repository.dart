import '../domain/group_model.dart';
import '../domain/group_expense_model.dart';

class GroupRepository {
  Future<void> createGroup(GroupModel group) async {
    // TODO: Implement Firestore write for group
  }

  Future<void> addExpense(String groupId, GroupExpenseModel expense) async {
    // TODO: Implement Firestore write for expense
  }

  Stream<List<GroupExpenseModel>> streamExpenses(String groupId) {
    // TODO: Implement Firestore stream reader
    return const Stream.empty();
  }
}
