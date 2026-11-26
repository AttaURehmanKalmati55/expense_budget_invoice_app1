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

enum TransactionType { expense, regularExpense }

class LedgerEntry {
  final String id;
  final String title;
  final String category;
  final double amount;
  final DateTime date;
  final TransactionType type;
  final String? frequency;

  LedgerEntry({
    required this.id,
    required this.title,
    required this.category,
    required this.amount,
    required this.date,
    required this.type,
    this.frequency,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'category': category,
        'amount': amount,
        'date': date.toIso8601String(),
        'type': type.name,
        'frequency': frequency,
      };

  factory LedgerEntry.fromJson(Map<String, dynamic> json) => LedgerEntry(
        id: json['id']?.toString() ?? '',
        title: json['title']?.toString() ?? '',
        category: json['category']?.toString() ?? 'General',
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
  final double amount;
  final bool isPaid;

  InvoiceItem({
    required this.id,
    required this.clientName,
    required this.description,
    required this.amount,
    this.isPaid = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'clientName': clientName,
        'description': description,
        'amount': amount,
        'isPaid': isPaid,
      };

  factory InvoiceItem.fromJson(Map<String, dynamic> json) => InvoiceItem(
        id: json['id']?.toString() ?? '',
        clientName: json['clientName']?.toString() ?? '',
        description: json['description']?.toString() ?? '',
        amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
        isPaid: json['isPaid'] == true,
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
  static const String _catBudgetsKey = 'smartledger_category_budgets';
  static const String _entriesKey = 'smartledger_entries';
  static const String _invoicesKey = 'smartledger_invoices';

  int _selectedIndex = 0;
  bool _isLoading = true;

  double _monthlyBudget = 0.0;
  final Map<String, double> _categoryBudgets = {
    'Food': 0.0,
    'Travel': 0.0,
    'Bills': 0.0,
    'Shopping': 0.0,
    'Other': 0.0,
  };

  final List<LedgerEntry> _entries = [];
  final List<InvoiceItem> _invoices = [];

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

    final catJsonString = prefs.getString(_catBudgetsKey);
    if (catJsonString != null && catJsonString.isNotEmpty) {
      final decoded = jsonDecode(catJsonString) as Map<String, dynamic>;
      for (final key in _categoryBudgets.keys) {
        if (decoded.containsKey(key)) {
          _categoryBudgets[key] = (decoded[key] as num?)?.toDouble() ?? 0.0;
        }
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

    if (!mounted) return;
    setState(() {
      _monthlyBudget = savedBudget;
      _isLoading = false;
    });
  }

  Future<void> _saveDataToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_budgetKey, _monthlyBudget);
    await prefs.setString(_catBudgetsKey, jsonEncode(_categoryBudgets));
    await prefs.setString(
      _entriesKey,
      jsonEncode(_entries.map((e) => e.toJson()).toList()),
    );
    await prefs.setString(
      _invoicesKey,
      jsonEncode(_invoices.map((i) => i.toJson()).toList()),
    );
  }

  double get _totalSpent =>
      _entries.fold(0.0, (sum, item) => sum + item.amount);

  double get _regularExpensesTotal => _entries
      .where((e) => e.type == TransactionType.regularExpense)
      .fold(0.0, (sum, item) => sum + item.amount);

  double get _remainingBudget => _monthlyBudget - _totalSpent;

  void _setMonthlyBudgetDialog() {
    final controller = TextEditingController(
      text: _monthlyBudget > 0 ? _monthlyBudget.toStringAsFixed(0) : '',
    );

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Apna Monthly Budget Likhein'),
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
                setState(() => _monthlyBudget = value);
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

  void _addEntryDialog({required bool isRegular}) {
    final titleController = TextEditingController();
    final amountController = TextEditingController();
    String selectedCategory = _categoryBudgets.keys.first;
    String selectedFrequency = 'Monthly';

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: Text(
            isRegular
                ? 'Naya Regular Expense Add Karein'
                : 'Naya Expense Add Karein',
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: InputDecoration(
                    labelText: isRegular ? 'Regular Expense Title' : 'Expense Title',
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
                  setState(() {
                    _entries.insert(
                      0,
                      LedgerEntry(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        title: title,
                        category: selectedCategory,
                        amount: amount,
                        date: DateTime.now(),
                        type: isRegular
                            ? TransactionType.regularExpense
                            : TransactionType.expense,
                        frequency: isRegular ? selectedFrequency : null,
                      ),
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
        title: Text('$category Budget Set Karein'),
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
                setState(() => _categoryBudgets[category] = value);
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

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Naya Invoice Banayein'),
        content: Column(
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
                setState(() {
                  _invoices.insert(
                    0,
                    InvoiceItem(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      clientName: client,
                      description: desc.isEmpty ? 'Invoice Item' : desc,
                      amount: amount,
                    ),
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
                    const Text(
                      'Apna Monthly Budget',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    TextButton.icon(
                      onPressed: _setMonthlyBudgetDialog,
                      icon: const Icon(Icons.edit, size: 18),
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
                const SizedBox(height: 10),
                LinearProgressIndicator(value: progress),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Total Kharcha: ${_totalSpent.toStringAsFixed(0)}'),
                    Text(
                      'Baqi: ${_remainingBudget.toStringAsFixed(0)}',
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
        Row(
          children: [
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Regular Expenses'),
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
                      const Text('Total Entries'),
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
          'Recent Entries',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (_entries.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'Abhi koi entry nahi hai. Neeche + button se apna expense ya regular expense add karein.',
              ),
            ),
          )
        else
          ..._entries.take(5).map(
                (entry) => Card(
                  child: ListTile(
                    title: Text(entry.title),
                    subtitle: Text(
                      entry.type == TransactionType.regularExpense
                          ? '${entry.category} • Regular (${entry.frequency})'
                          : '${entry.category} • Expense',
                    ),
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
              child: Text(
                'Koi expense add nahi hua. Naya expense add karne ke liye + dabayein.',
              ),
            ),
          )
        else
          ..._entries.map(
            (entry) => Card(
              child: ListTile(
                title: Text(entry.title),
                subtitle: Text(
                  entry.type == TransactionType.regularExpense
                      ? '${entry.category} • Regular (${entry.frequency})'
                      : '${entry.category} • One-time Expense',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      entry.amount.toStringAsFixed(0),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () async {
                        setState(
                          () => _entries.removeWhere((e) => e.id == entry.id),
                        );
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

  Widget _buildBudgetAndRegularTab() {
    final regularList = _entries
        .where((e) => e.type == TransactionType.regularExpense)
        .toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: ListTile(
            title: const Text('Overall Monthly Budget'),
            subtitle: Text('Current: ${_monthlyBudget.toStringAsFixed(0)}'),
            trailing: FilledButton(
              onPressed: _setMonthlyBudgetDialog,
              child: const Text('Set'),
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Category Budgets (Khud Set Karein)',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        ..._categoryBudgets.entries.map(
          (item) => Card(
            child: ListTile(
              title: Text(item.key),
              subtitle: Text('Limit: ${item.value.toStringAsFixed(0)}'),
              trailing: IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () => _editCategoryBudgetDialog(item.key),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Regular Expenses',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            TextButton.icon(
              onPressed: () => _addEntryDialog(isRegular: true),
              icon: const Icon(Icons.add),
              label: const Text('Add Regular'),
            ),
          ],
        ),
        if (regularList.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('Koi regular expense add nahi hua.'),
            ),
          )
        else
          ...regularList.map(
            (reg) => Card(
              child: ListTile(
                title: Text(reg.title),
                subtitle: Text('${reg.category} • ${reg.frequency}'),
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

  Widget _buildInvoicesTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_invoices.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'Koi invoice nahi bana. Naya invoice banane ke liye neeche + dabayein.',
              ),
            ),
          )
        else
          ..._invoices.map(
            (inv) => Card(
              child: CheckboxListTile(
                value: inv.isPaid,
                title: Text(
                  '${inv.clientName} — ${inv.amount.toStringAsFixed(0)}',
                ),
                subtitle: Text(inv.description),
                onChanged: (val) async {
                  setState(() {
                    final idx = _invoices.indexWhere((i) => i.id == inv.id);
                    if (idx != -1) {
                      _invoices[idx] = InvoiceItem(
                        id: inv.id,
                        clientName: inv.clientName,
                        description: inv.description,
                        amount: inv.amount,
                        isPaid: val ?? false,
                      );
                    }
                  });
                  await _saveDataToPrefs();
                },
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
      _buildBudgetAndRegularTab(),
      _buildInvoicesTab(),
    ];

    final titles = [
      'SmartLedger • Dashboard',
      'Expenses Menu',
      'Budget & Regular Menu',
      'Invoices Menu',
    ];

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
                  Text('Apna Budget & Expenses Khud Manage Karein'),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.dashboard),
              title: const Text('Dashboard'),
              selected: _selectedIndex == 0,
              onTap: () {
                setState(() => _selectedIndex = 0);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.receipt_long),
              title: const Text('Expenses'),
              selected: _selectedIndex == 1,
              onTap: () {
                setState(() => _selectedIndex = 1);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.account_balance_wallet),
              title: const Text('Budget & Regular Expenses'),
              selected: _selectedIndex == 2,
              onTap: () {
                setState(() => _selectedIndex = 2);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.description),
              title: const Text('Invoices'),
              selected: _selectedIndex == 3,
              onTap: () {
                setState(() => _selectedIndex = 3);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
      body: pages[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) => setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.receipt_long), label: 'Expenses'),
          NavigationDestination(icon: Icon(Icons.savings), label: 'Budget'),
          NavigationDestination(icon: Icon(Icons.description), label: 'Invoices'),
        ],
      ),
      floatingActionButton: _selectedIndex == 3
          ? FloatingActionButton.extended(
              onPressed: _addInvoiceDialog,
              icon: const Icon(Icons.add),
              label: const Text('New Invoice'),
            )
          : FloatingActionButton.extended(
              onPressed: () => _addEntryDialog(isRegular: _selectedIndex == 2),
              icon: const Icon(Icons.add),
              label: Text(_selectedIndex == 2 ? 'Add Regular' : 'Add Expense'),
            ),
    );
  }
        }
                      
                  
