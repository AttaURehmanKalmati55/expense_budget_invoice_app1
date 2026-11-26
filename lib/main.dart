import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SmartLedgerApp());
}

class SmartLedgerApp extends StatelessWidget {
  const SmartLedgerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SmartLedger Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0F766E)),
        useMaterial3: true,
      ),
      home: const SmartLedgerHome(),
    );
  }
}

String _formatDateTime(DateTime dt) {
  final day = dt.day.toString().padLeft(2, '0');
  final month = dt.month.toString().padLeft(2, '0');
  final year = dt.year.toString();
  final hour12 = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
  final hourStr = hour12.toString().padLeft(2, '0');
  final minStr = dt.minute.toString().padLeft(2, '0');
  final period = dt.hour >= 12 ? 'PM' : 'AM';
  return '$day/$month/$year • $hourStr:$minStr $period';
}

enum TransactionType { expense, regularExpense }

class AccountSource {
  final String id;
  final String name;
  final double balance;
  final DateTime updatedAt;

  AccountSource({
    required this.id,
    required this.name,
    required this.balance,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'balance': balance,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory AccountSource.fromJson(Map<String, dynamic> json) => AccountSource(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? 'Account',
        balance: (json['balance'] as num?)?.toDouble() ?? 0.0,
        updatedAt:
            DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
                DateTime.now(),
      );
}

class LedgerEntry {
  final String id;
  final String title;
  final String category;
  final String sourceAccount;
  final double amount;
  final DateTime date;
  final TransactionType type;
  final String? frequency;

  LedgerEntry({
    required this.id,
    required this.title,
    required this.category,
    required this.sourceAccount,
    required this.amount,
    required this.date,
    required this.type,
    this.frequency,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'category': category,
        'sourceAccount': sourceAccount,
        'amount': amount,
        'date': date.toIso8601String(),
        'type': type.name,
        'frequency': frequency,
      };

  factory LedgerEntry.fromJson(Map<String, dynamic> json) => LedgerEntry(
        id: json['id']?.toString() ?? '',
        title: json['title']?.toString() ?? '',
        category: json['category']?.toString() ?? 'General',
        sourceAccount: json['sourceAccount']?.toString() ?? 'Easypaisa Account',
        amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
        date: DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime.now(),
        type: json['type'] == 'regularExpense'
            ? TransactionType.regularExpense
            : TransactionType.expense,
        frequency: json['frequency']?.toString(),
      );
}

class InvoiceItem {
  final String id;
  final String clientName;
  final String description;
  final String targetAccount;
  final double amount;
  final bool isPaid;
  final DateTime updatedAt;

  InvoiceItem({
    required this.id,
    required this.clientName,
    required this.description,
    required this.targetAccount,
    required this.amount,
    this.isPaid = false,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'clientName': clientName,
        'description': description,
        'targetAccount': targetAccount,
        'amount': amount,
        'isPaid': isPaid,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory InvoiceItem.fromJson(Map<String, dynamic> json) => InvoiceItem(
        id: json['id']?.toString() ?? '',
        clientName: json['clientName']?.toString() ?? '',
        description: json['description']?.toString() ?? '',
        targetAccount: json['targetAccount']?.toString() ?? 'Bank Account',
        amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
        isPaid: json['isPaid'] == true,
        updatedAt:
            DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
                DateTime.now(),
      );
}

class ActivityLogItem {
  final String id;
  final String summary;
  final String tag;
  final DateTime timestamp;

  ActivityLogItem({
    required this.id,
    required this.summary,
    required this.tag,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'summary': summary,
        'tag': tag,
        'timestamp': timestamp.toIso8601String(),
      };

  factory ActivityLogItem.fromJson(Map<String, dynamic> json) =>
      ActivityLogItem(
        id: json['id']?.toString() ?? '',
        summary: json['summary']?.toString() ?? '',
        tag: json['tag']?.toString() ?? 'Update',
        timestamp:
            DateTime.tryParse(json['timestamp']?.toString() ?? '') ??
                DateTime.now(),
      );
}

class SmartLedgerHome extends StatefulWidget {
  const SmartLedgerHome({super.key});

  @override
  State<SmartLedgerHome> createState() => _SmartLedgerHomeState();
}

class _SmartLedgerHomeState extends State<SmartLedgerHome>
    with WidgetsBindingObserver {
  static const String _budgetKey = 'smartledger_monthly_budget';
  static const String _budgetUpdatedKey = 'smartledger_budget_updated_at';
  static const String _catBudgetsKey = 'smartledger_category_budgets';
  static const String _accountsKey = 'smartledger_accounts';
  static const String _entriesKey = 'smartledger_entries';
  static const String _invoicesKey = 'smartledger_invoices';
  static const String _logsKey = 'smartledger_activity_logs';

  // 0: Dashboard, 1: Expenses, 2: Regular Expenses, 3: Accounts, 4: Budget, 5: Invoices, 6: Activity Log
  int _selectedIndex = 0;
  bool _isLoading = true;

  double _monthlyBudget = 0.0;
  DateTime? _budgetUpdatedAt;

  final Map<String, double> _categoryBudgets = {
    'Food': 0.0,
    'Travel': 0.0,
    'Bills': 0.0,
    'Shopping': 0.0,
    'Other': 0.0,
  };

  final List<AccountSource> _accounts = [
    AccountSource(
      id: 'acc_easypaisa',
      name: 'Easypaisa Account',
      balance: 0.0,
      updatedAt: DateTime.now(),
    ),
    AccountSource(
      id: 'acc_jazzcash',
      name: 'JazzCash Account',
      balance: 0.0,
      updatedAt: DateTime.now(),
    ),
    AccountSource(
      id: 'acc_bank',
      name: 'Bank Account',
      balance: 0.0,
      updatedAt: DateTime.now(),
    ),
  ];

  final List<LedgerEntry> _entries = [];
  final List<InvoiceItem> _invoices = [];
  final List<ActivityLogItem> _logs = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadDataFromPrefs();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _saveDataToPrefs();
    }
  }

  Future<void> _loadDataFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final savedBudget = prefs.getDouble(_budgetKey) ?? 0.0;
    final budgetTimeStr = prefs.getString(_budgetUpdatedKey);
    final parsedBudgetTime =
        budgetTimeStr != null ? DateTime.tryParse(budgetTimeStr) : null;

    final catJsonString = prefs.getString(_catBudgetsKey);
    if (catJsonString != null && catJsonString.isNotEmpty) {
      final decoded = jsonDecode(catJsonString) as Map<String, dynamic>;
      for (final key in _categoryBudgets.keys) {
        if (decoded.containsKey(key)) {
          _categoryBudgets[key] = (decoded[key] as num?)?.toDouble() ?? 0.0;
        }
      }
    }

    final accountsString = prefs.getString(_accountsKey);
    if (accountsString != null && accountsString.isNotEmpty) {
      final decodedAccounts = jsonDecode(accountsString) as List<dynamic>;
      if (decodedAccounts.isNotEmpty) {
        _accounts
          ..clear()
          ..addAll(
            decodedAccounts.map(
              (item) => AccountSource.fromJson(item as Map<String, dynamic>),
            ),
          );
      }
    }

    final entriesString = prefs.getString(_entriesKey);
    if (entriesString != null && entriesString.isNotEmpty) {
      final decodedList = jsonDecode(entriesString) as List<dynamic>;
      _entries
        ..clear()
        ..addAll(
          decodedList.map(
            (item) => LedgerEntry.fromJson(item as Map<String, dynamic>),
          ),
        );
    }

    final invoicesString = prefs.getString(_invoicesKey);
    if (invoicesString != null && invoicesString.isNotEmpty) {
      final decodedInv = jsonDecode(invoicesString) as List<dynamic>;
      _invoices
        ..clear()
        ..addAll(
          decodedInv.map(
            (item) => InvoiceItem.fromJson(item as Map<String, dynamic>),
          ),
        );
    }

    final logsString = prefs.getString(_logsKey);
    if (logsString != null && logsString.isNotEmpty) {
      final decodedLogs = jsonDecode(logsString) as List<dynamic>;
      _logs
        ..clear()
        ..addAll(
          decodedLogs.map(
            (item) => ActivityLogItem.fromJson(item as Map<String, dynamic>),
          ),
        );
    }

    if (!mounted) return;
    setState(() {
      _monthlyBudget = savedBudget;
      _budgetUpdatedAt = parsedBudgetTime;
      _isLoading = false;
    });
  }

  Future<void> _saveDataToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_budgetKey, _monthlyBudget);
    if (_budgetUpdatedAt != null) {
      await prefs.setString(
        _budgetUpdatedKey,
        _budgetUpdatedAt!.toIso8601String(),
      );
    }
    await prefs.setString(_catBudgetsKey, jsonEncode(_categoryBudgets));
    await prefs.setString(
      _accountsKey,
      jsonEncode(_accounts.map((a) => a.toJson()).toList()),
    );
    await prefs.setString(
      _entriesKey,
      jsonEncode(_entries.map((e) => e.toJson()).toList()),
    );
    await prefs.setString(
      _invoicesKey,
      jsonEncode(_invoices.map((i) => i.toJson()).toList()),
    );
    await prefs.setString(
      _logsKey,
      jsonEncode(_logs.map((l) => l.toJson()).toList()),
    );
  }

  void _recordActivity(String tag, String summary) {
    _logs.insert(
      0,
      ActivityLogItem(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        tag: tag,
        summary: summary,
        timestamp: DateTime.now(),
      ),
    );
  }

  double get _totalAccountsBalance =>
      _accounts.fold(0.0, (sum, acc) => sum + acc.balance);

  double get _totalSpent =>
      _entries.fold(0.0, (sum, item) => sum + item.amount);

  double get _regularExpensesTotal => _entries
      .where((e) => e.type == TransactionType.regularExpense)
      .fold(0.0, (sum, item) => sum + item.amount);

  double get _remainingBudget => _monthlyBudget - _totalSpent;

  Color _accountIconColor(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('easypaisa')) return Colors.green;
    if (lower.contains('jazzcash')) return Colors.redAccent;
    if (lower.contains('bank')) return Colors.indigo;
    return Colors.teal;
  }

  IconData _accountIcon(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('easypaisa')) return Icons.phone_android;
    if (lower.contains('jazzcash')) return Icons.account_balance_wallet;
    if (lower.contains('bank')) return Icons.account_balance;
    return Icons.wallet;
  }

  void _setMonthlyBudgetDialog() {
    final controller = TextEditingController(
      text: _monthlyBudget > 0 ? _monthlyBudget.toStringAsFixed(0) : '',
    );

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Set Monthly Budget'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Total Budget',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final value = double.tryParse(controller.text.trim());
              if (value != null && value >= 0) {
                final now = DateTime.now();
                setState(() {
                  _monthlyBudget = value;
                  _budgetUpdatedAt = now;
                  _recordActivity(
                    'Budget',
                    'Monthly budget set to ${value.toStringAsFixed(0)}',
                  );
                });
                await _saveDataToPrefs();
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              }
            },
            child: const Text('Save Budget'),
          ),
        ],
      ),
    );
  }

  void _editAccountBalanceDialog(AccountSource account) {
    final controller = TextEditingController(
      text: account.balance > 0 ? account.balance.toStringAsFixed(0) : '',
    );

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Update ${account.name}'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Available Balance',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final value = double.tryParse(controller.text.trim());
              if (value != null && value >= 0) {
                final now = DateTime.now();
                setState(() {
                  final idx = _accounts.indexWhere((a) => a.id == account.id);
                  if (idx != -1) {
                    _accounts[idx] = AccountSource(
                      id: account.id,
                      name: account.name,
                      balance: value,
                      updatedAt: now,
                    );
                  }
                  _recordActivity(
                    'Account',
                    '${account.name} balance set to ${value.toStringAsFixed(0)}',
                  );
                });
                await _saveDataToPrefs();
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _addCustomAccountDialog() {
    final nameController = TextEditingController();
    final balanceController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add Funding Account'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Account Name (e.g. Easypaisa, JazzCash, Bank)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: balanceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Initial Balance',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final name = nameController.text.trim();
              final bal = double.tryParse(balanceController.text.trim()) ?? 0.0;
              if (name.isNotEmpty && bal >= 0) {
                final now = DateTime.now();
                setState(() {
                  _accounts.add(
                    AccountSource(
                      id: now.microsecondsSinceEpoch.toString(),
                      name: name,
                      balance: bal,
                      updatedAt: now,
                    ),
                  );
                  _recordActivity(
                    'Account',
                    '$name added with balance ${bal.toStringAsFixed(0)}',
                  );
                });
                await _saveDataToPrefs();
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _addEntryDialog({required bool isRegular}) {
    final titleController = TextEditingController();
    final amountController = TextEditingController();
    String selectedCategory = _categoryBudgets.keys.first;
    String selectedFrequency = 'Monthly';
    String selectedAccount =
        _accounts.isNotEmpty ? _accounts.first.name : 'Easypaisa Account';

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: Text(
            isRegular ? 'Add Regular Expense' : 'Add Expense',
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: InputDecoration(
                    labelText:
                        isRegular ? 'Regular Expense Title' : 'Expense Title',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Amount',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedAccount,
                  decoration: const InputDecoration(
                    labelText: 'Budget Source Account',
                    border: OutlineInputBorder(),
                  ),
                  items: _accounts
                      .map(
                        (acc) => DropdownMenuItem(
                          value: acc.name,
                          child: Text(acc.name),
                        ),
                      )
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setModalState(() => selectedAccount = val);
                    }
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedCategory,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(),
                  ),
                  items: _categoryBudgets.keys
               .map((cat) => DropdownMenuItem(value: cat, child: Text(cat)))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setModalState(() => selectedCategory = val);
                    }
                  },
                ),
                if (isRegular) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedFrequency,
                    decoration: const InputDecoration(
                      labelText: 'Repeat Frequency',
                      border: OutlineInputBorder(),
                    ),
                    items: const ['Daily', 'Weekly', 'Monthly']
                        .map(
                          (freq) =>
                              DropdownMenuItem(value: freq, child: Text(freq)),
                        )
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setModalState(() => selectedFrequency = val);
                      }
                    },
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final title = titleController.text.trim();
                final amount = double.tryParse(amountController.text.trim());
                if (title.isNotEmpty && amount != null && amount > 0) {
                  final now = DateTime.now();
                  setState(() {
                    _entries.insert(
                      0,
                      LedgerEntry(
                        id: now.microsecondsSinceEpoch.toString(),
                        title: title,
                        category: selectedCategory,
                        sourceAccount: selectedAccount,
                        amount: amount,
                        date: now,
                        type: isRegular
                            ? TransactionType.regularExpense
                            : TransactionType.expense,
                        frequency: isRegular ? selectedFrequency : null,
                      ),
                    );
                    final accIdx =
                        _accounts.indexWhere((a) => a.name == selectedAccount);
                    if (accIdx != -1) {
                      final currentAcc = _accounts[accIdx];
                      final nextBal = (currentAcc.balance - amount)
                          .clamp(0.0, double.infinity);
                      _accounts[accIdx] = AccountSource(
                        id: currentAcc.id,
                        name: currentAcc.name,
                        balance: nextBal,
                        updatedAt: now,
                      );
                    }
                    _recordActivity(
                      isRegular ? 'Regular' : 'Expense',
                      '$title (${amount.toStringAsFixed(0)}) via $selectedAccount',
                    );
                  });
                  await _saveDataToPrefs();
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _editCategoryBudgetDialog(String category) {
    final controller = TextEditingController(
      text: (_categoryBudgets[category] ?? 0).toStringAsFixed(0),
    );
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('$category Budget Limit'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Category Limit',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final value = double.tryParse(controller.text.trim());
              if (value != null && value >= 0) {
                setState(() {
                  _categoryBudgets[category] = value;
                  _recordActivity(
                    'Budget',
                    '$category limit updated to ${value.toStringAsFixed(0)}',
                  );
                });
                await _saveDataToPrefs();
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _addInvoiceDialog() {
    final clientController = TextEditingController();
    final descController = TextEditingController();
    final amountController = TextEditingController();
    String selectedAccount =
        _accounts.isNotEmpty ? _accounts.first.name : 'Bank Account';

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: const Text('Create Invoice'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: clientController,
                  decoration: const InputDecoration(
                    labelText: 'Client / Customer Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(
                    labelText: 'Work / Item Description',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: selectedAccount,
                  decoration: const InputDecoration(
                    labelText: 'Receiving Account',
                    border: OutlineInputBorder(),
                  ),
                  items: _accounts
                      .map(
                        (acc) => DropdownMenuItem(
                          value: acc.name,
                          child: Text(acc.name),
                        ),
                      )
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setModalState(() => selectedAccount = val);
                    }
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Amount',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final client = clientController.text.trim();
                final desc = descController.text.trim();
                final amount = double.tryParse(amountController.text.trim());
                if (client.isNotEmpty && amount != null && amount > 0) {
                  final now = DateTime.now();
                  setState(() {
                    _invoices.insert(
                      0,
                      InvoiceItem(
                        id: now.microsecondsSinceEpoch.toString(),
                        clientName: client,
                        description: desc.isEmpty ? 'Invoice Item' : desc,
                        targetAccount: selectedAccount,
                        amount: amount,
                        updatedAt: now,
                      ),
                    );
                    _recordActivity(
                      'Invoice',
                      'Invoice for $client (${amount.toStringAsFixed(0)}) created',
                    );
                  });
                  await _saveDataToPrefs();
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardTab() {
    final progress = _monthlyBudget > 0
        ? (_totalSpent / _monthlyBudget).clamp(0.0, 1.0)
        : 0.0;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.account_balance_wallet,
                            color: Colors.teal, size: 22),
                        SizedBox(width: 8),
                        Text(
                          'Monthly Budget',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    TextButton.icon(
                      onPressed: _setMonthlyBudgetDialog,
                      icon: const Icon(Icons.edit,
                          size: 18, color: Colors.deepPurple),
                      label: Text(_monthlyBudget > 0 ? 'Change' : 'Set Budget'),
                    ),
                  ],
                ),
                Text(
                  _monthlyBudget.toStringAsFixed(0),
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_budgetUpdatedAt != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Last Updated: ${_formatDateTime(_budgetUpdatedAt!)}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
                const SizedBox(height: 10),
                LinearProgressIndicator(value: progress),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Total Spent: ${_totalSpent.toStringAsFixed(0)}'),
                    Text(
                      'Remaining: ${_remainingBudget.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _remainingBudget < 0 ? Colors.red : Colors.teal,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: const Icon(Icons.account_balance, color: Colors.indigo),
            title: const Text('Total Accounts Balance'),
            subtitle: const Text('Easypaisa, JazzCash & Bank Accounts'),
            trailing: Text(
              _totalAccountsBalance.toStringAsFixed(0),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            onTap: () => setState(() => _selectedIndex = 3),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.repeat, color: Colors.deepOrange, size: 18),
                          SizedBox(width: 6),
                          Text('Regular'),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _regularExpensesTotal.toStringAsFixed(0),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.receipt_long, color: Colors.blue, size: 18),
                          SizedBox(width: 6),
                          Text('Entries'),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${_entries.length}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Text(
          'Recent Entries (Date & Time)',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (_entries.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'No entries yet. Tap + to add your expense or regular expense.',
              ),
            ),
          )
        else
          ..._entries.take(5).map(
                (entry) => Card(
                  child: ListTile(
                    leading: Icon(
                      entry.type == TransactionType.regularExpense
                          ? Icons.repeat
                          : Icons.payments,
                      color: entry.type == TransactionType.regularExpense
                          ? Colors.deepOrange
                          : Colors.blue,
                    ),
                    title: Text(entry.title),
                    subtitle: Text(
                      '${entry.category} • ${entry.sourceAccount}\n${_formatDateTime(entry.date)}',
                    ),
                    isThreeLine: true,
                    trailing: Text(
                      '-${entry.amount.toStringAsFixed(0)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
      ],
    );
  }

  Widget _buildExpensesTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_entries.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text('No expenses added yet. Tap + to add an expense.'),
            ),
          )
        else
          ..._entries.map(
            (entry) => Card(
              child: ListTile(
                leading: const Icon(Icons.payments, color: Colors.blue),
                title: Text(entry.title),
                subtitle: Text(
                  entry.type == TransactionType.regularExpense
                      ? '${entry.category} • Regular (${entry.frequency}) • ${entry.sourceAccount}\n${_formatDateTime(entry.date)}'
                      : '${entry.category} • One-time • ${entry.sourceAccount}\n${_formatDateTime(entry.date)}',
                ),
                isThreeLine: true,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      entry.amount.toStringAsFixed(0),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () async {
                        setState(() {
                          _entries.removeWhere((e) => e.id == entry.id);
                          _recordActivity(
                            'Deleted',
                            '${entry.title} (${entry.amount.toStringAsFixed(0)}) removed',
                          );
                        });
                        await _saveDataToPrefs();
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildRegularExpensesTab() {
    final regularList = _entries
        .where((e) => e.type == TransactionType.regularExpense)
        .toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Regular Expenses',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            TextButton.icon(
              onPressed: () => _addEntryDialog(isRegular: true),
              icon: const Icon(Icons.add_circle, color: Colors.deepOrange),
              label: const Text('Add Regular'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (regularList.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('No regular expenses added yet.'),
            ),
          )
        else
          ...regularList.map(
            (reg) => Card(
              child: ListTile(
                leading: const Icon(Icons.repeat, color: Colors.deepOrange),
                title: Text(reg.title),
                subtitle: Text(
                  '${reg.category} • ${reg.frequency} • ${reg.sourceAccount}\n${_formatDateTime(reg.date)}',
                ),
                isThreeLine: true,
                trailing: Text(
                  reg.amount.toStringAsFixed(0),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildAccountsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.savings, color: Colors.teal),
            title: const Text('Combined Funding Balance'),
            subtitle: const Text('Total across all budget accounts'),
            trailing: Text(
              _totalAccountsBalance.toStringAsFixed(0),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Budget Sources (Accounts)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            TextButton.icon(
              onPressed: _addCustomAccountDialog,
              icon: const Icon(Icons.add_circle, color: Colors.indigo),
              label: const Text('Add Account'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ..._accounts.map(
          (acc) => Card(
            child: ListTile(
              leading: Icon(
                _accountIcon(acc.name),
                color: _accountIconColor(acc.name),
              ),
              title: Text(acc.name),
              subtitle: Text(
                'Balance: ${acc.balance.toStringAsFixed(0)}\nUpdated: ${_formatDateTime(acc.updatedAt)}',
              ),
              isThreeLine: true,
              trailing: IconButton(
                icon: const Icon(Icons.edit, color: Colors.deepPurple),
                onPressed: () => _editAccountBalanceDialog(acc),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBudgetTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: ListTile(
            leading:
                const Icon(Icons.account_balance_wallet, color: Colors.teal),
            title: const Text('Overall Monthly Budget'),
            subtitle: Text(
              'Current: ${_monthlyBudget.toStringAsFixed(0)}${_budgetUpdatedAt != null ? '\nUpdated: ${_formatDateTime(_budgetUpdatedAt!)}' : ''}',
            ),
            isThreeLine: _budgetUpdatedAt != null,
            trailing: FilledButton(
              onPressed: _setMonthlyBudgetDialog,
              child: const Text('Set'),
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Category Budgets',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        ..._categoryBudgets.entries.map(
          (item) => Card(
            child: ListTile(
              leading: const Icon(Icons.pie_chart, color: Colors.purple),
              title: Text(item.key),
              subtitle: Text('Limit: ${item.value.toStringAsFixed(0)}'),
              trailing: IconButton(
                icon: const Icon(Icons.edit, color: Colors.deepPurple),
                onPressed: () => _editCategoryBudgetDialog(item.key),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInvoicesTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_invoices.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text('No invoices yet. Tap + to create an invoice.'),
            ),
          )
        else
          ..._invoices.map(
            (inv) => Card(
              child: CheckboxListTile(
                secondary: const Icon(Icons.description, color: Colors.green),
                value: inv.isPaid,
                title: Text(
                  '${inv.clientName} — ${inv.amount.toStringAsFixed(0)}',
                ),
                subtitle: Text(
                  '${inv.description} • ${inv.targetAccount}\n${_formatDateTime(inv.updatedAt)}',
                ),
                isThreeLine: true,
                onChanged: (val) async {
                  final now = DateTime.now();
                  final nextPaid = val ?? false;
                  setState(() {
                    final idx = _invoices.indexWhere((i) => i.id == inv.id);
                    if (idx != -1) {
                      _invoices[idx] = InvoiceItem(
                        id: inv.id,
                        clientName: inv.clientName,
                        description: inv.description,
                        targetAccount: inv.targetAccount,
                        amount: inv.amount,
                        isPaid: nextPaid,
                        updatedAt: now,
                      );
                    }
                    if (nextPaid && !inv.isPaid) {
                      final accIdx = _accounts
                          .indexWhere((a) => a.name == inv.targetAccount);
                      if (accIdx != -1) {
                        final acc = _accounts[accIdx];
                        _accounts[accIdx] = AccountSource(
                          id: acc.id,
                          name: acc.name,
                          balance: acc.balance + inv.amount,
                          updatedAt: now,
                        );
                      }
                    }
                    _recordActivity(
                      'Invoice',
                      '${inv.clientName} marked ${nextPaid ? 'Paid' : 'Unpaid'}',
                    );
                  });
                  await _saveDataToPrefs();
                },
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildActivityLogTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_logs.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'No activity logs yet. Every update to accounts, budget, expenses, or invoices will record its date and time here.',
              ),
            ),
          )
        else
          ..._logs.map(
            (log) => Card(
              child: ListTile(
                leading: const Icon(Icons.schedule, color: Colors.amber),
                title: Text('${log.tag}: ${log.summary}'),
                subtitle: Text(_formatDateTime(log.timestamp)),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final pages = [
      _buildDashboardTab(),
      _buildExpensesTab(),
      _buildRegularExpensesTab(),
      _buildAccountsTab(),
      _buildBudgetTab(),
      _buildInvoicesTab(),
      _buildActivityLogTab(),
    ];

    final titles = [
      'SmartLedger • Dashboard',
      'Expenses',
      'Regular Expenses',
      'Accounts (Easypaisa, JazzCash & Bank)',
      'Budget & Categories',
      'Invoices',
      'Date & Time Activity Log',
    ];

    final drawerItems = [
      ('Dashboard', Icons.dashboard, Colors.teal),
      ('Expenses', Icons.receipt_long, Colors.blue),
      ('Regular Expenses', Icons.repeat, Colors.deepOrange),
      ('Accounts', Icons.account_balance, Colors.indigo),
      ('Budget & Categories', Icons.account_balance_wallet, Colors.purple),
      ('Invoices', Icons.description, Colors.green),
      ('Activity Log (Time)', Icons.schedule, Colors.amber),
    ];

    final bottomNavIndex = switch (_selectedIndex) {
      1 => 1,
      2 => 2,
      3 => 3,
      _ => 0,
    };

    return Scaffold(
      appBar: AppBar(title: Text(titles[_selectedIndex])),
      drawer: Drawer(
        child: ListView(
          children: [
            const DrawerHeader(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'SmartLedger Tracker',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 4),
                  Text('Manage Accounts, Budget & Expenses'),
                ],
              ),
            ),
            for (int i = 0; i < drawerItems.length; i++)
              ListTile(
                leading: Icon(
                  drawerItems[i].$2,
                  color: drawerItems[i].$3,
                ),
                title: Text(drawerItems[i].$1),
                selected: _selectedIndex == i,
                onTap: () {
                  setState(() => _selectedIndex = i);
                  Navigator.pop(context);
                },
              ),
          ],
        ),
      ),
      body: pages[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: bottomNavIndex,
        onDestinationSelected: (index) {
          final targetTab = switch (index) {
            1 => 1,
            2 => 2,
            3 => 3,
            _ => 0,
          };
          setState(() => _selectedIndex = targetTab);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard, color: Colors.teal),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long, color: Colors.blue),
            label: 'Expenses',
          ),
          NavigationDestination(
            icon: Icon(Icons.repeat, color: Colors.deepOrange),
            label: 'Regular',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance, color: Colors.indigo),
            label: 'Accounts',
          ),
        ],
      ),
      floatingActionButton: _selectedIndex == 5
          ? FloatingActionButton.extended(
              onPressed: _addInvoiceDialog,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('New Invoice'),
            )
          : _selectedIndex == 3
              ? FloatingActionButton.extended(
                  onPressed: _addCustomAccountDialog,
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: const Text('Add Account'),
                )
              : FloatingActionButton.extended(
                  onPressed: () =>
                      _addEntryDialog(isRegular: _selectedIndex == 2),
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: Text(
                    _selectedIndex == 2 ? 'Add Regular' : 'Add Expense',
                  ),
                ),
    );
  }
}
