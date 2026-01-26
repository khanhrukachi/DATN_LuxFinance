import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:personal_financial_management/controls/spending_firebase.dart';
import 'package:personal_financial_management/models/ml_service.dart';
import 'package:personal_financial_management/models/spending.dart';
import 'package:personal_financial_management/setting/localization/app_localizations.dart';

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

  bool _isDarkMode = false;
  bool _isLoading = true;
  String? _errorMessage;

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

  Future<void> _loadAllData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      _transactions = await SpendingFirebase.getAllSpendingForAI();

      if (_transactions.length < 10) {
        throw Exception(
            'Cần ít nhất 10 giao dịch để phân tích AI (${_transactions.length})');
      }

      final userId = FirebaseAuth.instance.currentUser!.uid;

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

  @override
  Widget build(BuildContext context) {
    final bgColor = _isDarkMode ? const Color(0xFF121212) : Colors.white;
    final tabTrackColor = _isDarkMode ? Colors.grey[800] : Colors.grey[100];
    final indicatorColor = _isDarkMode ? Colors.grey[700] : Colors.white;
    final selectedLabelColor = _isDarkMode ? Colors.white : Colors.black87;
    final unselectedLabelColor = _isDarkMode ? Colors.white54 : Colors.grey[500];

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title:  Text(
            AppLocalizations.of(context).translate('ai_insights'),
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: bgColor,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Container(
            height: 45,
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: tabTrackColor,
              borderRadius: BorderRadius.circular(25),
            ),
            child: TabBar(
              controller: _tabController,
              overlayColor: MaterialStateProperty.all(Colors.transparent),
              labelColor: selectedLabelColor,
              unselectedLabelColor: unselectedLabelColor,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),

              indicatorSize: TabBarIndicatorSize.tab,
              indicator: BoxDecoration(
                color: indicatorColor,
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              dividerColor: Colors.transparent,
              padding: const EdgeInsets.all(4),

              tabs: [
                _buildCompactTab(Icons.trending_up_rounded, 'Xu hướng'),
                _buildCompactTab(Icons.bubble_chart_rounded, 'Phân cụm'),
                _buildCompactTab(Icons.warning_amber_rounded, 'Bất thường'),
              ],
            ),
          ),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildCompactTab(IconData icon, String label) {
    return Tab(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16),
            const SizedBox(width: 4),
            Text(label),
          ],
        ),
      ),
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
        TrendTab(
          result: _trendResult!,
          isDarkMode: _isDarkMode,
        ),

        ClusterTab(
          result: _clusterResult!,
          isDarkMode: _isDarkMode,
        ),

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
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline_rounded, size: 48, color: Colors.red),
            ),
            const SizedBox(height: 16),
            Text(
              "Đã xảy ra lỗi",
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _isDarkMode ? Colors.white : Colors.black87
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 14,
                  color: _isDarkMode ? Colors.white70 : Colors.black54
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadAllData,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Thử lại'),
            )
          ],
        ),
      ),
    );
  }
}