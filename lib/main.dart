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

enum EntryType { expense, regular }

class EntryItem {
  final String id;
  final String title;
  final String category;
  final double amount;
  final EntryType type;
  final String frequency;

  EntryItem({
    required this.id,
    required this.title,
    required this.category,
    required this.amount,
    required this.type,
    required this.frequency,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'category': category,
        'amount': amount,
        'type': type.name,
        'frequency': frequency,
      };

  factory EntryItem.fromMap(Map<String, dynamic> map) => EntryItem(
        id: map['id'] ?? '',
        title: map['title'] ?? '',
        category: map['category'] ?? 'General',
        amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
        type: map['type'] == 'regular' ? EntryType.regular : EntryType.expense,
        frequency: map['frequency'] ?? 'One-time',
      );
}

class InvoiceRecord {
  final String id;
  final String customer;
  final String note;
  final double amount;
  final bool paid;

  InvoiceRecord({
    required this.id,
    required this.customer,
    required this.note,
    required this.amount,
    required this.paid,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'customer': customer,
        'note': note,
        'amount': amount,
        'paid': paid,
      };

  factory InvoiceRecord.fromMap(Map<String, dynamic> map) => InvoiceRecord(
        id: map['id'] ?? '',
        customer: map['customer'] ?? '',
        note: map['note'] ?? '',
        amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
        paid: map['paid'] ?? false,
      );
}

class SmartLedgerHome extends StatefulWidget {
  const SmartLedgerHome({super.key});

  @override
  State<SmartLedgerHome> createState() => _SmartLedgerHomeState();
}

class _SmartLedgerHomeState extends State<SmartLedgerHome> {
  int _tabIndex = 0;
  bool _loading = true;

  double _budget = 0.0;
  final List<EntryItem> _entries = [];
  final List<InvoiceRecord> _invoices = [];

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final savedBudget = prefs.getDouble('sl_budget') ?? 0.0;

    final entriesRaw = prefs.getString('sl_entries');
    if (entriesRaw != null) {
      final list = jsonDecode(entriesRaw) as List<dynamic>;
      _entries
        ..clear()
        ..addAll(list.map((e) => EntryItem.fromMap(e as Map<String, dynamic>)));
    }

    final invoicesRaw = prefs.getString('sl_invoices');
    if (invoicesRaw != null) {
      final list = jsonDecode(invoicesRaw) as List<dynamic>;
      _invoices
        ..clear()
        ..addAll(
          list.map((e) => InvoiceRecord.fromMap(e as Map<String, dynamic>)),
        );
    }

    if (!mounted) return;
    setState(() {
      _budget = savedBudget;
      _loading = false;
    });
  }

  Future<void> _saveAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('sl_budget', _budget);
    await prefs.setString(
      'sl_entries',
      jsonEncode(_entries.map((e) => e.toMap()).toList()),
    );
    await prefs.setString(
      'sl_invoices',
      jsonEncode(_invoices.map((e) => e.toMap()).toList()),
    );
  }

  double get _spent => _entries.fold(0.0, (sum, e) => sum + e.amount);

  double get _regularTotal => _entries
      .where((e) => e.type == EntryType.regular)
      .fold(0.0, (sum, e) => sum + e.amount);

  void _openBudgetDialog() {
    final ctrl = TextEditingController(
      text: _budget > 0 ? _budget.toStringAsFixed(0) : '',
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Apna Budget Likhein'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Budget Amount',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final val = double.tryParse(ctrl.text.trim());
              if (val != null && val >= 0) {
                setState(() => _budget = val);
                await _saveAll();
                if (ctx.mounted) Navigator.pop(ctx);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _openEntryDialog({EntryItem? existing, bool forceRegular = false}) {
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final amountCtrl = TextEditingController(
      text: existing != null ? existing.amount.toStringAsFixed(0) : '',
    );
    final catCtrl = TextEditingController(text: existing?.category ?? 'General');
    EntryType type = existing?.type ??
        (forceRegular ? EntryType.regular : EntryType.expense);
    String freq = existing?.frequency ?? (forceRegular ? 'Monthly' : 'One-time');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(existing == null ? 'Entry Add Karein' : 'Entry Edit Karein'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Amount',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: catCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<EntryType>(
                  value: type,
                  decoration: const InputDecoration(
                    labelText: 'Type',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: EntryType.expense,
                      child: Text('Expense'),
                    ),
                    DropdownMenuItem(
                      value: EntryType.regular,
                      child: Text('Regular Expense'),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      setLocal(() {
                        type = v;
                        if (v == EntryType.regular && freq == 'One-time') {
                          freq = 'Monthly';
                        }
                      });
                    }
                  },
                ),
                if (type == EntryType.regular) ...[
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: freq == 'One-time' ? 'Monthly' : freq,
                    decoration: const InputDecoration(
                      labelText: 'Frequency',
                      border: OutlineInputBorder(),
                    ),
                    items: const ['Daily', 'Weekly', 'Monthly']
                        .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setLocal(() => freq = v);
                    },
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final title = titleCtrl.text.trim();
                final amt = double.tryParse(amountCtrl.text.trim());
                final cat =
                    catCtrl.text.trim().isEmpty ? 'General' : catCtrl.text.trim();
                if (title.isNotEmpty && amt != null && amt > 0) {
                  setState(() {
                    final item = EntryItem(
                      id: existing?.id ??
                          DateTime.now().millisecondsSinceEpoch.toString(),
                      title: title,
                      category: cat,
                      amount: amt,
                      type: type,
                      frequency: type == EntryType.regular ? freq : 'One-time',
                    );
                    if (existing == null) {
                      _entries.insert(0, item);
                    } else {
                      final i = _entries.indexWhere((e) => e.id == existing.id);
                      if (i != -1) _entries[i] = item;
                    }
                  });
                  await _saveAll();
                  if (ctx.mounted) Navigator.pop(ctx);
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _openInvoiceDialog() {
    final custCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    final amtCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Naya Invoice'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: custCtrl,
              decoration: const InputDecoration(
                labelText: 'Customer Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: noteCtrl,
              decoration: const InputDecoration(
                labelText: 'Details',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: amtCtrl,
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
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final cust = custCtrl.text.trim();
              final amt = double.tryParse(amtCtrl.text.trim());
              if (cust.isNotEmpty && amt != null && amt > 0) {
                setState(() {
                  _invoices.insert(
                    0,
                    InvoiceRecord(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      customer: cust,
                      note: noteCtrl.text.trim(),
                      amount: amt,
                      paid: false,
                    ),
                  );
                });
                await _saveAll();
                if (ctx.mounted) Navigator.pop(ctx);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Widget _dashboardView() {
    final rem = _budget - _spent;
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
                      'Monthly Budget',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    TextButton(
                      onPressed: _openBudgetDialog,
                      child: const Text('Set / Edit'),
                    ),
                  ],
                ),
                Text(
                  _budget.toStringAsFixed(0),
                  style: const TextStyle(
                      fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text('Total Spent: ${_spent.toStringAsFixed(0)}'),
                Text('Regular Total: ${_regularTotal.toStringAsFixed(0)}'),
                Text(
                  'Remaining: ${rem.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: rem < 0 ? Colors.red : Colors.teal,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (_entries.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('Abhi koi entry nahi hai. + se apna expense add karein.'),
            ),
          )
        else
          ..._entries.take(5).map(
                (e) => Card(
                  child: ListTile(
                    title: Text(e.title),
                    subtitle: Text('${e.category} • ${e.frequency}'),
                    trailing: Text(e.amount.toStringAsFixed(0)),
                  ),
                ),
              ),
      ],
    );
  }

  Widget _entriesView({required bool onlyRegular}) {
    final list = onlyRegular
        ? _entries.where((e) => e.type == EntryType.regular).toList()
        : _entries;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (list.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                onlyRegular
                    ? 'Koi regular expense nahi hai.'
                    : 'Koi expense nahi hai.',
              ),
            ),
          )
        else
          ...list.map(
            (e) => Card(
              child: ListTile(
                title: Text(e.title),
                subtitle: Text('${e.category} • ${e.frequency}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(e.amount.toStringAsFixed(0)),
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _openEntryDialog(existing: e),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () async {
                        setState(
                            () => _entries.removeWhere((x) => x.id == e.id));
                        await _saveAll();
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

  Widget _invoicesView() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_invoices.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('Koi invoice nahi hai.'),
            ),
          )
        else
          ..._invoices.map(
            (inv) => Card(
              child: CheckboxListTile(
                value: inv.paid,
                title: Text('${inv.customer} — ${inv.amount.toStringAsFixed(0)}'),
                subtitle: Text(inv.note.isEmpty ? 'Invoice' : inv.note),
                onChanged: (v) async {
                  setState(() {
                    final i = _invoices.indexWhere((x) => x.id == inv.id);
                    if (i != -1) {
                      _invoices[i] = InvoiceRecord(
                        id: inv.id,
                        customer: inv.customer,
                        note: inv.note,
                        amount: inv.amount,
                        paid: v ?? false,
                      );
                    }
                  });
                  await _saveAll();
                },
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final views = [
      _dashboardView(),
      _entriesView(onlyRegular: false),
      _entriesView(onlyRegular: true),
      _invoicesView(),
    ];

    final menuTitles = [
      'Dashboard',
      'Expenses',
      'Regular Expenses',
      'Invoices',
    ];

    return Scaffold(
      appBar: AppBar(title: Text('SmartLedger • ${menuTitles[_tabIndex]}')),
      drawer: Drawer(
        child: ListView(
          children: [
            const DrawerHeader(
              child: Text(
                'SmartLedger Menu',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            for (int i = 0; i < menuTitles.length; i++)
              ListTile(
                title: Text(menuTitles[i]),
                selected: _tabIndex == i,
                onTap: () {
                  setState(() => _tabIndex = i);
                  Navigator.pop(context);
                },
              ),
            ListTile(
              title: const Text('Set Budget'),
              onTap: () {
                Navigator.pop(context);
                _openBudgetDialog();
              },
            ),
          ],
        ),
      ),
      body: views[_tabIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (i) => setState(() => _tabIndex = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: 'Dashboard'),
          NavigationDestination(icon: Icon(Icons.list), label: 'Expenses'),
          NavigationDestination(icon: Icon(Icons.repeat), label: 'Regular'),
          NavigationDestination(icon: Icon(Icons.receipt), label: 'Invoices'),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (_tabIndex == 3) {
            _openInvoiceDialog();
          } else {
            _openEntryDialog(forceRegular: _tabIndex == 2);
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
