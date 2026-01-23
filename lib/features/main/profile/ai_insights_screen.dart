import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:personal_financial_management/controls/spending_firebase.dart';
import 'package:personal_financial_management/models/ml_service.dart';
import 'package:personal_financial_management/models/spending.dart';
import 'package:personal_financial_management/setting/localization/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';

class AIInsightsScreen extends StatefulWidget {
  const AIInsightsScreen({Key? key}) : super(key: key);

  @override
  State<AIInsightsScreen> createState() => _AIInsightsScreenState();
}

class _AIInsightsScreenState extends State<AIInsightsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isDarkMode = false;
  bool _isLoading = true;
  bool _isServerOnline = false;
  String? _errorMessage;

  List<Spending> _transactions = [];
  TrendPredictionResult? _trendResult;
  ClusteringResult? _clusterResult;
  AnomalyResult? _anomalyResult;

  final numberFormat = NumberFormat.currency(locale: "vi_VI", symbol: "₫");

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadPreferences();
    _checkServerAndLoadData();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = prefs.getBool("isDark") ?? false;
    });
  }

  Future<void> _checkServerAndLoadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // Check server
    _isServerOnline = await MLService.healthCheck();

    if (!_isServerOnline) {
      setState(() {
        _isLoading = false;
        _errorMessage = "Không thể kết nối đến server ML. Vui lòng kiểm tra backend.";
      });
      return;
    }

    // Load transactions
    try {
      _transactions = await SpendingFirebase.getAllSpendingForAI();

      if (_transactions.length < 10) {
        setState(() {
          _isLoading = false;
          _errorMessage = "Cần ít nhất 10 giao dịch để phân tích. Hiện có ${_transactions.length} giao dịch.";
        });
        return;
      }

      // Call all ML services
      await _runAllAnalysis();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = "Lỗi tải dữ liệu: $e";
      });
    }
  }

  Future<void> _runAllAnalysis() async {
    final userId = FirebaseAuth.instance.currentUser!.uid;

    // Run all analysis in parallel
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

    setState(() {
      _trendResult = results[0] as TrendPredictionResult;
      _clusterResult = results[1] as ClusteringResult;
      _anomalyResult = results[2] as AnomalyResult;
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _isDarkMode ? Colors.black : Colors.grey[100],
      appBar: AppBar(
        title: Text(
          AppLocalizations.of(context).translate('ai_insights'),
          style: TextStyle(
            color: _isDarkMode ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: _isDarkMode ? Colors.grey[900] : Colors.white,
        iconTheme: IconThemeData(
          color: _isDarkMode ? Colors.white : Colors.black,
        ),
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: _isDarkMode
                  ? const Color(0xFF1E1E1E)
                  : const Color(0xFFF2F4F7),
              borderRadius: BorderRadius.circular(30),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                color: _isDarkMode ? Colors.amber : Colors.blue,
                boxShadow: [
                  BoxShadow(
                    color: (_isDarkMode ? Colors.amber : Colors.blue)
                        .withOpacity(0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              labelColor: Colors.white,
              unselectedLabelColor:
              _isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
              labelStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              tabs: [
                _buildTab(
                  icon: Icons.trending_up,
                  text: AppLocalizations.of(context).translate('prediction'),
                ),
                _buildTab(
                  icon: Icons.pie_chart_rounded,
                  text: AppLocalizations.of(context).translate('behavior'),
                ),
                _buildTab(
                  icon: Icons.warning_amber_rounded,
                  text: AppLocalizations.of(context).translate('anomaly'),
                ),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? _buildLoadingView()
          : _errorMessage != null
              ? _buildErrorView()
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildTrendTab(),
                    _buildClusterTab(),
                    _buildAnomalyTab(),
                  ],
                ),
    );
  }

  Widget _buildTab({
    required IconData icon,
    required String text,
  }) {
    return Tab(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 6),
          Text(text),
        ],
      ),
    );
  }


  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 20),
          Text(
            "Đang phân tích dữ liệu...",
            style: TextStyle(
              color: _isDarkMode ? Colors.white : Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 80,
              color: _isDarkMode ? Colors.amber : Colors.red,
            ),
            const SizedBox(height: 20),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: _isDarkMode ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _checkServerAndLoadData,
              icon: const Icon(Icons.refresh),
              label: const Text("Thử lại"),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isDarkMode ? Colors.amber : Colors.blue,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =====================
  // TREND TAB (LSTM)
  // =====================
  Widget _buildTrendTab() {
    if (_trendResult == null || !_trendResult!.success) {
      return _buildTabError(_trendResult?.errorMessage ?? "Không có dữ liệu dự báo");
    }

    final predictions = _trendResult!.predictions;
    final summary = _trendResult!.summary;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary Cards
          _buildSummaryCard(
            title: "Dự báo ${summary['predictionPeriod'] ?? '7 ngày'}",
            children: [
              _buildSummaryRow(
                "Tổng thu nhập dự kiến",
                numberFormat.format(summary['totalPredictedIncome'] ?? 0),
                Colors.green,
              ),
              _buildSummaryRow(
                "Tổng chi tiêu dự kiến",
                numberFormat.format(summary['totalPredictedExpense'] ?? 0),
                Colors.red,
              ),
              _buildSummaryRow(
                "Cân đối dự kiến",
                numberFormat.format(summary['predictedBalance'] ?? 0),
                (summary['predictedBalance'] ?? 0) >= 0 ? Colors.green : Colors.red,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Prediction Chart
          _buildChartCard(
            title: "Biểu đồ dự báo",
            child: SizedBox(
              height: 200,
              child: _buildPredictionChart(predictions),
            ),
          ),
          const SizedBox(height: 16),

          // Trend Analysis
          if (summary['trend'] != null)
            _buildTrendAnalysisCard(summary['trend']),

          const SizedBox(height: 16),

          // Daily Predictions
          _buildSummaryCard(
            title: "Chi tiết theo ngày",
            children: predictions.map((p) => _buildPredictionRow(p)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildPredictionChart(List<PredictedValue> predictions) {
    if (predictions.isEmpty) return const SizedBox();

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: predictions.map((p) =>
          p.predictedExpense > p.predictedIncome ? p.predictedExpense : p.predictedIncome
        ).reduce((a, b) => a > b ? a : b) * 1.2,
        barGroups: predictions.asMap().entries.map((entry) {
          final i = entry.key;
          final p = entry.value;
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: p.predictedIncome,
                color: Colors.green,
                width: 12,
              ),
              BarChartRodData(
                toY: p.predictedExpense,
                color: Colors.red,
                width: 12,
              ),
            ],
          );
        }).toList(),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value.toInt() < predictions.length) {
                  final date = predictions[value.toInt()].date;
                  return Text(
                    date.substring(5),
                    style: TextStyle(
                      fontSize: 10,
                      color: _isDarkMode ? Colors.white70 : Colors.black54,
                    ),
                  );
                }
                return const Text('');
              },
            ),
          ),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(show: false),
      ),
    );
  }

  Widget _buildTrendAnalysisCard(Map<String, dynamic> trend) {
    return _buildSummaryCard(
      title: "Phân tích xu hướng",
      children: [
        _buildTrendRow("Thu nhập", trend['incomeTrend'] ?? "N/A"),
        _buildTrendRow("Chi tiêu", trend['expenseTrend'] ?? "N/A"),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _isDarkMode ? Colors.blue.withOpacity(0.2) : Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(Icons.lightbulb, color: Colors.amber, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  trend['recommendation'] ?? "",
                  style: TextStyle(
                    color: _isDarkMode ? Colors.white : Colors.black87,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTrendRow(String label, String value) {
    IconData icon;
    Color color;
    if (value.contains("tăng")) {
      icon = Icons.trending_up;
      color = label == "Thu nhập" ? Colors.green : Colors.red;
    } else if (value.contains("giảm")) {
      icon = Icons.trending_down;
      color = label == "Thu nhập" ? Colors.red : Colors.green;
    } else {
      icon = Icons.trending_flat;
      color = Colors.grey;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(
            "$label: ",
            style: TextStyle(color: _isDarkMode ? Colors.white70 : Colors.black54),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPredictionRow(PredictedValue p) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _isDarkMode ? Colors.grey[700] : Colors.grey[200],
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              p.date,
              style: TextStyle(
                fontSize: 12,
                color: _isDarkMode ? Colors.white : Colors.black,
              ),
            ),
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                "+${numberFormat.format(p.predictedIncome)}",
                style: const TextStyle(color: Colors.green, fontSize: 12),
              ),
              Text(
                "-${numberFormat.format(p.predictedExpense)}",
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // =====================
  // CLUSTER TAB (K-Means)
  // =====================
  Widget _buildClusterTab() {
    if (_clusterResult == null || !_clusterResult!.success) {
      return _buildTabError(_clusterResult?.errorMessage ?? "Không có dữ liệu phân cụm");
    }

    final clusters = _clusterResult!.clusters;
    final profile = _clusterResult!.userProfile;
    final recommendations = _clusterResult!.recommendations;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User Profile Summary
          _buildSummaryCard(
            title: "Hồ sơ chi tiêu",
            children: [
              _buildSummaryRow(
                "Tổng chi tiêu",
                numberFormat.format(profile['totalSpent'] ?? 0),
                Colors.red,
              ),
              _buildSummaryRow(
                "Giao dịch trung bình",
                numberFormat.format(profile['averageTransaction'] ?? 0),
                Colors.blue,
              ),
              _buildSummaryRow(
                "Số giao dịch",
                "${profile['transactionCount'] ?? 0}",
                Colors.purple,
              ),
              if (profile['spendingStyle'] != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.person, color: Colors.amber),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            profile['spendingStyle'],
                            style: TextStyle(
                              color: _isDarkMode ? Colors.white : Colors.black,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Cluster Pie Chart
          _buildChartCard(
            title: "Phân bổ hành vi chi tiêu",
            child: SizedBox(
              height: 200,
              child: _buildClusterPieChart(clusters),
            ),
          ),
          const SizedBox(height: 16),

          // Clusters Detail
          _buildSectionTitle("Các nhóm hành vi"),
          ...clusters.map((c) => _buildClusterCard(c)),

          const SizedBox(height: 16),

          // Recommendations
          if (recommendations.isNotEmpty)
            _buildSummaryCard(
              title: "Khuyến nghị",
              children: recommendations
                  .map((r) => _buildRecommendationItem(r))
                  .toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildClusterPieChart(List<SpendingCluster> clusters) {
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.pink,
    ];

    return PieChart(
      PieChartData(
        sections: clusters.asMap().entries.map((entry) {
          final i = entry.key;
          final c = entry.value;
          return PieChartSectionData(
            value: c.percentage,
            title: "${c.percentage.toStringAsFixed(1)}%",
            color: colors[i % colors.length],
            radius: 60,
            titleStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          );
        }).toList(),
        centerSpaceRadius: 40,
      ),
    );
  }

  Widget _buildClusterCard(SpendingCluster cluster) {
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
    ];
    final color = colors[cluster.clusterId % colors.length];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _isDarkMode ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: color, width: 4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  "${cluster.percentage.toStringAsFixed(1)}%",
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  cluster.clusterName,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            cluster.description,
            style: TextStyle(
              color: _isDarkMode ? Colors.white70 : Colors.black54,
            ),
          ),
          if (cluster.characteristics['averageAmount'] != null) ...[
            const SizedBox(height: 8),
            Text(
              "TB: ${numberFormat.format(cluster.characteristics['averageAmount'])}",
              style: TextStyle(
                fontSize: 12,
                color: _isDarkMode ? Colors.white60 : Colors.black45,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRecommendationItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.tips_and_updates, color: Colors.amber, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: _isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =====================
  // ANOMALY TAB (Isolation Forest)
  // =====================
  Widget _buildAnomalyTab() {
    if (_anomalyResult == null || !_anomalyResult!.success) {
      return _buildTabError(_anomalyResult?.errorMessage ?? "Không có dữ liệu");
    }

    final anomalies = _anomalyResult!.anomalies;
    final stats = _anomalyResult!.statistics;
    final alerts = _anomalyResult!.alerts;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stats Summary
          _buildSummaryCard(
            title: "Tổng quan phát hiện",
            children: [
              _buildSummaryRow(
                "Tổng giao dịch",
                "${_anomalyResult!.totalTransactions}",
                Colors.blue,
              ),
              _buildSummaryRow(
                "Giao dịch bất thường",
                "${_anomalyResult!.anomaliesDetected}",
                Colors.red,
              ),
              _buildSummaryRow(
                "Tỷ lệ bất thường",
                "${stats['anomalyRate'] ?? 0}%",
                Colors.orange,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Alerts
          if (alerts.isNotEmpty)
            _buildAlertsCard(alerts),
          const SizedBox(height: 16),

          // Anomaly List
          if (anomalies.isNotEmpty) ...[
            _buildSectionTitle("Giao dịch bất thường (${anomalies.length})"),
            ...anomalies.map((a) => _buildAnomalyCard(a)),
          ] else
            _buildNoAnomalyCard(),
        ],
      ),
    );
  }

  Widget _buildAlertsCard(List<String> alerts) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _isDarkMode ? Colors.orange.withOpacity(0.2) : Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.notifications_active, color: Colors.orange),
              const SizedBox(width: 8),
              Text(
                "Cảnh báo",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _isDarkMode ? Colors.white : Colors.black,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...alerts.map((a) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  a,
                  style: TextStyle(
                    color: _isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildAnomalyCard(AnomalyTransaction anomaly) {
    Color severityColor;
    String severityText;
    switch (anomaly.severity) {
      case 'high':
        severityColor = Colors.red;
        severityText = "Cao";
        break;
      case 'medium':
        severityColor = Colors.orange;
        severityText = "TB";
        break;
      default:
        severityColor = Colors.green;
        severityText = "Thấp";
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _isDarkMode ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: severityColor, width: 4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: severityColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  severityText,
                  style: TextStyle(
                    color: severityColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  anomaly.typeName,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
              ),
              Text(
                numberFormat.format(anomaly.money),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: anomaly.money < 0 ? Colors.red : Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            anomaly.dateTime,
            style: TextStyle(
              fontSize: 12,
              color: _isDarkMode ? Colors.white60 : Colors.black45,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _isDarkMode ? Colors.grey[800] : Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 16,
                  color: _isDarkMode ? Colors.white60 : Colors.black45,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    anomaly.anomalyReason,
                    style: TextStyle(
                      fontSize: 12,
                      color: _isDarkMode ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoAnomalyCard() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withOpacity(0.5)),
      ),
      child: Column(
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 60),
          const SizedBox(height: 16),
          Text(
            "Không phát hiện giao dịch bất thường!",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: _isDarkMode ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Hành vi chi tiêu của bạn ổn định và bình thường.",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _isDarkMode ? Colors.white70 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  // =====================
  // COMMON WIDGETS
  // =====================
  Widget _buildSummaryCard({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _isDarkMode ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: _isDarkMode ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildChartCard({
    required String title,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _isDarkMode ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: _isDarkMode ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: _isDarkMode ? Colors.white70 : Colors.black54,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: _isDarkMode ? Colors.white : Colors.black,
        ),
      ),
    );
  }

  Widget _buildTabError(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.info_outline,
              size: 60,
              color: _isDarkMode ? Colors.amber : Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _isDarkMode ? Colors.white : Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
