import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const NaqadiApp());
}

// ==========================================
// THÈME & STYLES (الهوية البصرية)
// ==========================================
class AppTheme {
  static const Color background = Color(0xFF091E17);
  static const Color surface = Color(0xFF102A21);
  static const Color surfaceAlt = Color(0xFF183B2F);
  static const Color border = Color(0xFF235242);
  
  static const Color primary = Color(0xFF00694A);
  static const Color primaryLight = Color(0xFF059669);
  static const Color accentGold = Color(0xFFC59B4E);
  
  static const Color success = Color(0xFF10B981);
  static const Color danger = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  
  static const Color textPrimary = Color(0xFFECFDF5);
  static const Color textMuted = Color(0xFF6EE7B7);

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: background,
        colorScheme: const ColorScheme.dark(
          primary: primary,
          secondary: accentGold,
          surface: surface,
          error: danger,
          onPrimary: Colors.white,
          onSurface: textPrimary,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: background,
          elevation: 0,
          centerTitle: true,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: surface,
          selectedItemColor: accentGold,
          unselectedItemColor: Colors.white38,
          type: BottomNavigationBarType.fixed,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: surfaceAlt,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: accentGold, width: 1.5),
          ),
        ),
      );
}

// ==========================================
// MODELS
// ==========================================
enum TransactionType { income, expense }

class TransactionItem {
  final String id;
  final String title;
  final double amount;
  final TransactionType type;
  final String category;
  final DateTime date;

  TransactionItem({
    required this.id,
    required this.title,
    required this.amount,
    required this.type,
    required this.category,
    required this.date,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'amount': amount,
        'type': type.index,
        'category': category,
        'date': date.toIso8601String(),
      };

  factory TransactionItem.fromJson(Map<String, dynamic> json) => TransactionItem(
        id: json['id'] as String,
        title: json['title'] as String,
        amount: (json['amount'] as num).toDouble(),
        type: TransactionType.values[json['type'] as int],
        category: json['category'] as String,
        date: DateTime.parse(json['date'] as String),
      );
}

// ==========================================
// MAIN APP ENTRY
// ==========================================
class NaqadiApp extends StatelessWidget {
  const NaqadiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'نقدي Naqadi',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const MainNavigationScreen(),
    );
  }
}

// ==========================================
// NAVIGATION SCREEN
// ==========================================
class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  
  double _initialBalance = 0.0;
  final List<TransactionItem> _transactions = [];
  final Map<String, double> _categoryBudgets = {
    'مشتريات': 0.0,
    'أكل ومطاعم': 0.0,
    'مواصلات': 0.0,
    'فواتير': 0.0,
    'ترفيه': 0.0,
    'أخرى': 0.0,
  };

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _initialBalance = prefs.getDouble('naqadi_initial_balance') ?? 0.0;

      final txData = prefs.getString('naqadi_transactions');
      if (txData != null) {
        final List list = jsonDecode(txData);
        _transactions.clear();
        _transactions.addAll(list.map((e) => TransactionItem.fromJson(e)));
      }

      final budgetData = prefs.getString('naqadi_budgets');
      if (budgetData != null) {
        final Map<String, dynamic> map = jsonDecode(budgetData);
        map.forEach((key, value) {
          _categoryBudgets[key] = (value as num).toDouble();
        });
      }
    } catch (_) {}
    
    setState(() => _loading = false);
  }

  Future<void> _saveData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('naqadi_initial_balance', _initialBalance);
      await prefs.setString(
          'naqadi_transactions', jsonEncode(_transactions.map((e) => e.toJson()).toList()));
      await prefs.setString('naqadi_budgets', jsonEncode(_categoryBudgets));
    } catch (_) {}
  }

  double get totalIncome =>
      _initialBalance +
      _transactions
          .where((t) => t.type == TransactionType.income)
          .fold(0.0, (sum, t) => sum + t.amount);

  double get totalExpenses => _transactions
      .where((t) => t.type == TransactionType.expense)
      .fold(0.0, (sum, t) => sum + t.amount);

  double get remainingBalance => totalIncome - totalExpenses;

  void _addTransaction(TransactionItem item) {
    setState(() {
      _transactions.insert(0, item);
    });
    _saveData();
    _checkBudgetAlert(item);
  }

  void _deleteTransaction(String id) {
    setState(() {
      _transactions.removeWhere((t) => t.id == id);
    });
    _saveData();
  }

  void _setInitialBalance(double amount) {
    setState(() {
      _initialBalance = amount;
    });
    _saveData();
  }

  void _setCategoryBudget(String category, double limit) {
    setState(() {
      _categoryBudgets[category] = limit;
    });
    _saveData();
  }

  void _checkBudgetAlert(TransactionItem item) {
    if (item.type == TransactionType.expense) {
      final cat = item.category;
      final limit = _categoryBudgets[cat] ?? 0.0;
      if (limit > 0) {
        final spentInCat = _transactions
            .where((t) => t.type == TransactionType.expense && t.category == cat)
            .fold(0.0, (sum, t) => sum + t.amount);

        if (spentInCat >= limit) {
          _showSnackBar('تنبيه: تجاوزت الميزانية المحددة لـ "$cat"!', isWarning: true);
        } else if (spentInCat >= limit * 0.8) {
          _showSnackBar('تنبيه: اقتربت من 80% من ميزانية "$cat"', isWarning: true);
        }
      }
    }
  }

  void _showSnackBar(String msg, {bool isWarning = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isWarning ? AppTheme.warning : AppTheme.primaryLight,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppTheme.accentGold)),
      );
    }

    final pages = [
      IncomeBalanceScreen(
        initialBalance: _initialBalance,
        totalIncome: totalIncome,
        remainingBalance: remainingBalance,
        onSetInitialBalance: _setInitialBalance,
        onAddIncome: _addTransaction,
      ),
      ExpenseScreen(
        categories: _categoryBudgets.keys.toList(),
        onAddExpense: _addTransaction,
      ),
      BudgetScreen(
        categoryBudgets: _categoryBudgets,
        transactions: _transactions,
        onUpdateBudget: _setCategoryBudget,
      ),
      ReportsScreen(
        totalIncome: totalIncome,
        totalExpenses: totalExpenses,
        remainingBalance: remainingBalance,
        transactions: _transactions,
        categories: _categoryBudgets.keys.toList(),
      ),
      HistoryScreen(
        transactions: _transactions,
        onDelete: _deleteTransaction,
      ),
    ];

    return Scaffold(
      body: SafeArea(child: pages[_currentIndex]),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet_rounded), label: 'الدخل'),
          BottomNavigationBarItem(icon: Icon(Icons.add_shopping_cart_rounded), label: 'المصاريف'),
          BottomNavigationBarItem(icon: Icon(Icons.pie_chart_rounded), label: 'الميزانية'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart_rounded), label: 'التقارير'),
          BottomNavigationBarItem(icon: Icon(Icons.history_rounded), label: 'السجل'),
        ],
      ),
    );
  }
}

// ==========================================
// 1. قسم الرصيد والدخل
// ==========================================
class IncomeBalanceScreen extends StatelessWidget {
  final double initialBalance;
  final double totalIncome;
  final double remainingBalance;
  final Function(double) onSetInitialBalance;
  final Function(TransactionItem) onAddIncome;

  const IncomeBalanceScreen({
    super.key,
    required this.initialBalance,
    required this.totalIncome,
    required this.remainingBalance,
    required this.onSetInitialBalance,
    required this.onAddIncome,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const HeaderTitle(title: 'الرصيد والدخل'),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF00694A), Color(0xFF055E40)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.accentGold.withOpacity(0.5)),
            ),
            child: Column(
              children: [
                const Text('المتبقي حالياً', style: TextStyle(color: Colors.white70, fontSize: 14)),
                const SizedBox(height: 8),
                Text(
                  '${remainingBalance.toStringAsFixed(2)} \$',
                  style: const TextStyle(
                      color: AppTheme.accentGold, fontSize: 32, fontWeight: FontWeight.bold),
                ),
                const Divider(color: Colors.white24, height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('إجمالي الدخل + الرصيد: \$${totalIncome.toStringAsFixed(2)}',
                        style: const TextStyle(color: Colors.white, fontSize: 13)),
                    IconButton(
                      icon: const Icon(Icons.edit_rounded, color: AppTheme.accentGold, size: 20),
                      onPressed: () => _showInitialBalanceDialog(context),
                    ),
                  ],
                )
              ],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryLight,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () => _showAddIncomeDialog(context),
            icon: const Icon(Icons.add_rounded, color: Colors.white),
            label: const Text('إضافة دخل جديد', style: TextStyle(color: Colors.white, fontSize: 16)),
          ),
        ],
      ),
    );
  }

  void _showInitialBalanceDialog(BuildContext context) {
    final controller = TextEditingController(text: initialBalance.toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('المبلغ الأولي / الرصيد'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: 'أدخل الرصيد المتاح'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () {
              onSetInitialBalance(double.tryParse(controller.text) ?? 0.0);
              Navigator.pop(ctx);
            },
            child: const Text('حفظ'),
          )
        ],
      ),
    );
  }

  void _showAddIncomeDialog(BuildContext context) {
    final titleController = TextEditingController();
    final amountController = TextEditingController();
    String selectedCat = 'راتب';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: AppTheme.surface,
          title: const Text('إضافة دخل جديد'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(hintText: 'مصدر الدخل (راتب، هدية...)'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(hintText: 'المبلغ'),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: selectedCat,
                items: ['راتب', 'مصروف', 'هدايا', 'أخرى']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (val) => setState(() => selectedCat = val!),
              )
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            FilledButton(
              onPressed: () {
                final amount = double.tryParse(amountController.text) ?? 0.0;
                if (amount > 0 && titleController.text.isNotEmpty) {
                  onAddIncome(TransactionItem(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    title: titleController.text,
                    amount: amount,
                    type: TransactionType.income,
                    category: selectedCat,
                    date: DateTime.now(),
                  ));
                  Navigator.pop(ctx);
                }
              },
              child: const Text('إضافة'),
            )
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 2. قسم المصاريف
// ==========================================
class ExpenseScreen extends StatefulWidget {
  final List<String> categories;
  final Function(TransactionItem) onAddExpense;

  const ExpenseScreen({super.key, required this.categories, required this.onAddExpense});

  @override
  State<ExpenseScreen> createState() => _ExpenseScreenState();
}

class _ExpenseScreenState extends State<ExpenseScreen> {
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  late String _selectedCategory;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.categories.first;
  }

  void _submit() {
    final title = _titleController.text.trim();
    final amount = double.tryParse(_amountController.text) ?? 0.0;

    if (title.isNotEmpty && amount > 0) {
      widget.onAddExpense(TransactionItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: title,
        amount: amount,
        type: TransactionType.expense,
        category: _selectedCategory,
        date: DateTime.now(),
      ));

      _titleController.clear();
      _amountController.clear();
      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تسجيل المصروف بنجاح'), backgroundColor: AppTheme.success),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const HeaderTitle(title: 'تسجيل مصروف'),
          const SizedBox(height: 20),
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'عنوان المصروف',
              prefixIcon: Icon(Icons.edit_note_rounded, color: AppTheme.accentGold),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'المبلغ المصروف',
              prefixIcon: Icon(Icons.attach_money_rounded, color: AppTheme.accentGold),
            ),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            value: _selectedCategory,
            decoration: const InputDecoration(
              labelText: 'الفئة',
              prefixIcon: Icon(Icons.category_rounded, color: AppTheme.accentGold),
            ),
            items: widget.categories
                .map((cat) => DropdownMenuItem(value: cat, child: Text(cat)))
                .toList(),
            onChanged: (val) => setState(() => _selectedCategory = val!),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.danger,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: _submit,
            icon: const Icon(Icons.remove_circle_outline_rounded, color: Colors.white),
            label: const Text('تسجيل المصروف', style: TextStyle(color: Colors.white, fontSize: 16)),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 3. قسم الميزانية والتقسيم
// ==========================================
class BudgetScreen extends StatelessWidget {
  final Map<String, double> categoryBudgets;
  final List<TransactionItem> transactions;
  final Function(String, double) onUpdateBudget;

  const BudgetScreen({
    super.key,
    required this.categoryBudgets,
    required this.transactions,
    required this.onUpdateBudget,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const HeaderTitle(title: 'الميزانية والتقسيم'),
        const SizedBox(height: 8),
        const Text('تخصيص ميزانية لكل فئة مع التنبيه التلقائي',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
        const SizedBox(height: 16),
        ...categoryBudgets.entries.map((entry) {
          final cat = entry.key;
          final limit = entry.value;

          final spent = transactions
              .where((t) => t.type == TransactionType.expense && t.category == cat)
              .fold(0.0, (sum, t) => sum + t.amount);

          final progress = limit == 0 ? 0.0 : (spent / limit).clamp(0.0, 1.0);
          final isExceeded = limit > 0 && spent >= limit;

          return Card(
            color: AppTheme.surface,
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: isExceeded ? AppTheme.danger : AppTheme.border),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(cat, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      IconButton(
                        icon: const Icon(Icons.edit, size: 18, color: AppTheme.accentGold),
                        onPressed: () => _editBudgetDialog(context, cat, limit),
                      )
                    ],
                  ),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    value: progress,
                    backgroundColor: AppTheme.surfaceAlt,
                    color: isExceeded
                        ? AppTheme.danger
                        : (progress > 0.8 ? AppTheme.warning : AppTheme.primaryLight),
                    minHeight: 8,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('صرفت: \$${spent.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                      Text('الميزانية: \$${limit.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 12, color: Colors.white70)),
                    ],
                  )
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  void _editBudgetDialog(BuildContext context, String category, double currentLimit) {
    final controller = TextEditingController(text: currentLimit.toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text('ميزانية فئة: $category'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: 'المبلغ المحدد'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () {
              onUpdateBudget(category, double.tryParse(controller.text) ?? 0.0);
              Navigator.pop(ctx);
            },
            child: const Text('حفظ'),
          )
        ],
      ),
    );
  }
}

// ==========================================
// 4. قسم التقارير والملخص
// ==========================================
class ReportsScreen extends StatelessWidget {
  final double totalIncome;
  final double totalExpenses;
  final double remainingBalance;
  final List<TransactionItem> transactions;
  final List<String> categories;

  const ReportsScreen({
    super.key,
    required this.totalIncome,
    required this.totalExpenses,
    required this.remainingBalance,
    required this.transactions,
    required this.categories,
  });

  @override
  Widget build(BuildContext context) {
    final Map<String, double> catExpenses = {};
    for (var cat in categories) {
      catExpenses[cat] = transactions
          .where((t) => t.type == TransactionType.expense && t.category == cat)
          .fold(0.0, (sum, t) => sum + t.amount);
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const HeaderTitle(title: 'التقارير والملخص'),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(
            children: [
              _reportRow('إجمالي الدخل', totalIncome, AppTheme.success),
              const Divider(color: AppTheme.border),
              _reportRow('إجمالي المصاريف', totalExpenses, AppTheme.danger),
              const Divider(color: AppTheme.border),
              _reportRow('الرصيد المتبقي', remainingBalance, AppTheme.accentGold),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Text('نسبة توزيع المصاريف لكل قسم',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 12),
        ...catExpenses.entries.map((entry) {
          final percentage = totalExpenses == 0 ? 0.0 : (entry.value / totalExpenses);
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(entry.key, style: const TextStyle(fontSize: 14)),
                    Text('\$${entry.value.toStringAsFixed(2)} (${(percentage * 100).toStringAsFixed(1)}%)',
                        style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                  ],
                ),
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: percentage,
                  minHeight: 10,
                  backgroundColor: AppTheme.surfaceAlt,
                  color: AppTheme.accentGold,
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _reportRow(String title, double value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary)),
          Text('\$${value.toStringAsFixed(2)}',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}

// ==========================================
// 5. قسم السجل (التاريخ والتعديل/الحذف)
// ==========================================
class HistoryScreen extends StatefulWidget {
  final List<TransactionItem> transactions;
  final Function(String) onDelete;

  const HistoryScreen({super.key, required this.transactions, required this.onDelete});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.transactions.where((t) {
      return t.title.contains(_search) || t.category.contains(_search);
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const HeaderTitle(title: 'سجل العمليات'),
          const SizedBox(height: 12),
          TextField(
            onChanged: (val) => setState(() => _search = val),
            decoration: const InputDecoration(
              hintText: 'بحث في السجل (بالاسم أو الفئة)...',
              prefixIcon: Icon(Icons.search_rounded, color: AppTheme.textMuted),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: filtered.isEmpty
                ? const Center(child: Text('لا توجد عمليات مسجلة', style: TextStyle(color: AppTheme.textMuted)))
                : ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (ctx, idx) {
                      final item = filtered[idx];
                      final isIncome = item.type == TransactionType.income;
                      return Card(
                        color: AppTheme.surface,
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isIncome ? AppTheme.success.withOpacity(0.2) : AppTheme.danger.withOpacity(0.2),
                            child: Icon(
                              isIncome ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                              color: isIncome ? AppTheme.success : AppTheme.danger,
                            ),
                          ),
                          title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('${item.category} • ${_formatDate(item.date)}',
                              style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${isIncome ? "+" : "-"}\$${item.amount.toStringAsFixed(2)}',
                                style: TextStyle(
                                  color: isIncome ? AppTheme.success : AppTheme.danger,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 20, color: AppTheme.textMuted),
                                onPressed: () => widget.onDelete(item.id),
                              )
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          )
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}/${dt.month}/${dt.day}';
  }
}

// ==========================================
// HEADER WITH SIGNATURE
// ==========================================
class HeaderTitle extends StatelessWidget {
  final String title;

  const HeaderTitle({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
            const Text(
              'Eng - Abdulrahman Taher Yusuf',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.accentGold),
            ),
          ],
        ),
        const Divider(color: AppTheme.border, thickness: 1),
      ],
    );
  }
}