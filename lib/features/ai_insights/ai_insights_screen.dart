import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:personal_financial_management/controls/spending_firebase.dart';
import 'package:personal_financial_management/models/ml_service.dart';
import 'package:personal_financial_management/models/spending.dart';

import 'tabs/trend_tab.dart';
import 'tabs/cluster_tab.dart';
import 'tabs/anomaly_tab.dart';

class AiInsightsScreen extends StatefulWidget {
  const AiInsightsScreen({super.key});

  @override
  State<AiInsightsScreen> createState() => _AiInsightsScreenState();
}

class _AiInsightsScreenState extends State<AiInsightsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // ===== UI STATE =====
  bool _isDarkMode = false;
  bool _isLoading = true;
  String? _errorMessage;

  // ===== DATA =====
  List<Spending> _transactions = [];

  TrendPredictionResult? _trendResult;
  ClusteringResult? _clusterResult;
  AnomalyResult? _anomalyResult;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAllData();
  }

  // ======================
  // LOAD ALL AI DATA
  // ======================
  Future<void> _loadAllData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 1. Load transactions
      _transactions = await SpendingFirebase.getAllSpendingForAI();

      if (_transactions.length < 10) {
        throw Exception(
            'Cần ít nhất 10 giao dịch để phân tích AI (${_transactions.length})');
      }

      final userId = FirebaseAuth.instance.currentUser!.uid;

      // 2. Run all ML in parallel
      final results = await Future.wait([
        MLService.predictTrend(
          userId: userId,
          transactions: _transactions,
          predictionDays: 7,
        ),
        MLService.clusterBehavior(
          userId: userId,
          transactions: _transactions,
        ),
        MLService.detectAnomaly(
          userId: userId,
          transactions: _transactions,
        ),
      ]);

      _trendResult = results[0] as TrendPredictionResult;
      _clusterResult = results[1] as ClusteringResult;
      _anomalyResult = results[2] as AnomalyResult;
    } catch (e) {
      _errorMessage = e.toString();
    }

    setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ======================
  // UI
  // ======================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Insights'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.trending_up), text: 'Xu hướng'),
            Tab(icon: Icon(Icons.scatter_plot), text: 'Phân cụm'),
            Tab(icon: Icon(Icons.warning_amber), text: 'Bất thường'),
          ],
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return _buildErrorView();
    }

    return TabBarView(
      controller: _tabController,
      children: [
        // ===== TREND =====
        TrendTab(
          result: _trendResult!,
          isDarkMode: _isDarkMode,
        ),

        // ===== CLUSTER =====
        ClusterTab(
          result: _clusterResult!,
          isDarkMode: _isDarkMode,
        ),

        // ===== ANOMALY =====
        AnomalyTab(
          result: _anomalyResult!,
          isDarkMode: _isDarkMode,
          numberFormat: NumberFormat.currency(
            locale: 'vi_VN',
            symbol: '₫',
          ),
        ),
      ],
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _loadAllData,
              icon: const Icon(Icons.refresh),
              label: const Text('Thử lại'),
            )
          ],
        ),
      ),
    );
  }
}
