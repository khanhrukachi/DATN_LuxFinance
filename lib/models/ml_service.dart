import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:personal_financial_management/models/spending.dart';

class MLService {
  // Đổi IP này thành IP máy chạy backend
  // - Emulator Android: http://10.0.2.2:8000/api/v1
  // - Thiết bị thật cùng mạng: http://YOUR_PC_IP:8000/api/v1
  // - Web/Desktop: http://localhost:8000/api/v1
  static const String _baseUrl = "http://192.168.1.202:8000/api/v1";

  // URL for health check (without /api/v1)
  static const String _healthUrl = "http://192.168.1.202:8000";

  /// Convert Spending to API format
  static Map<String, dynamic> _spendingToJson(Spending s) {
    return {
      "id": s.id ?? "",
      "money": s.money,
      "type": s.type,
      "typeName": s.typeName ?? "Khác",
      "dateTime": s.dateTime.toIso8601String(),
      "note": s.note,
      "image": s.image,
      "location": s.location,
    };
  }

  /// =====================
  /// LSTM - Dự báo xu hướng
  /// =====================
  static Future<TrendPredictionResult> predictTrend({
    required String userId,
    required List<Spending> transactions,
    int predictionDays = 7,
  }) async {
    try {
      final response = await http.post(
        Uri.parse("$_baseUrl/predict/trend"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "userId": userId,
          "transactions": transactions.map(_spendingToJson).toList(),
          "predictionDays": predictionDays,
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return TrendPredictionResult.fromJson(data);
      } else {
        debugPrint("Predict trend error: ${response.body}");
        return TrendPredictionResult.error("Lỗi server: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("Predict trend exception: $e");
      return TrendPredictionResult.error("Không thể kết nối server: $e");
    }
  }

  /// =====================
  /// K-Means - Phân cụm hành vi
  /// =====================
  static Future<ClusteringResult> clusterBehavior({
    required String userId,
    required List<Spending> transactions,
    int? nClusters,
  }) async {
    try {
      final body = {
        "userId": userId,
        "transactions": transactions.map(_spendingToJson).toList(),
      };
      if (nClusters != null) {
        body["nClusters"] = nClusters;
      }

      final response = await http.post(
        Uri.parse("$_baseUrl/cluster/behavior"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return ClusteringResult.fromJson(data);
      } else {
        debugPrint("Cluster behavior error: ${response.body}");
        return ClusteringResult.error("Lỗi server: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("Cluster behavior exception: $e");
      return ClusteringResult.error("Không thể kết nối server: $e");
    }
  }

  /// =====================
  /// Isolation Forest - Phát hiện bất thường
  /// =====================
  static Future<AnomalyResult> detectAnomaly({
    required String userId,
    required List<Spending> transactions,
    double sensitivity = 0.1,
  }) async {
    try {
      final response = await http.post(
        Uri.parse("$_baseUrl/detect/anomaly"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "userId": userId,
          "transactions": transactions.map(_spendingToJson).toList(),
          "sensitivity": sensitivity,
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return AnomalyResult.fromJson(data);
      } else {
        debugPrint("Detect anomaly error: ${response.body}");
        return AnomalyResult.error("Lỗi server: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("Detect anomaly exception: $e");
      return AnomalyResult.error("Không thể kết nối server: $e");
    }
  }

  /// Health check
  static Future<bool> healthCheck() async {
    try {
      final response = await http.get(
        Uri.parse("$_healthUrl/health"),
      ).timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}

/// =====================
/// RESULT MODELS
/// =====================

class TrendPredictionResult {
  final bool success;
  final String? errorMessage;
  final List<PredictedValue> predictions;
  final Map<String, dynamic> summary;

  TrendPredictionResult({
    required this.success,
    this.errorMessage,
    this.predictions = const [],
    this.summary = const {},
  });

  factory TrendPredictionResult.fromJson(Map<String, dynamic> json) {
    return TrendPredictionResult(
      success: json['success'] ?? false,
      predictions: (json['predictions'] as List<dynamic>?)
              ?.map((e) => PredictedValue.fromJson(e))
              .toList() ??
          [],
      summary: json['summary'] ?? {},
    );
  }

  factory TrendPredictionResult.error(String message) {
    return TrendPredictionResult(
      success: false,
      errorMessage: message,
    );
  }
}

class PredictedValue {
  final String date;
  final double predictedIncome;
  final double predictedExpense;
  final double confidence;

  PredictedValue({
    required this.date,
    required this.predictedIncome,
    required this.predictedExpense,
    required this.confidence,
  });

  factory PredictedValue.fromJson(Map<String, dynamic> json) {
    return PredictedValue(
      date: json['date'] ?? '',
      predictedIncome: (json['predictedIncome'] ?? 0).toDouble(),
      predictedExpense: (json['predictedExpense'] ?? 0).toDouble(),
      confidence: (json['confidence'] ?? 0).toDouble(),
    );
  }
}

class ClusteringResult {
  final bool success;
  final String? errorMessage;
  final List<SpendingCluster> clusters;
  final Map<String, dynamic> userProfile;
  final List<String> recommendations;

  ClusteringResult({
    required this.success,
    this.errorMessage,
    this.clusters = const [],
    this.userProfile = const {},
    this.recommendations = const [],
  });

  factory ClusteringResult.fromJson(Map<String, dynamic> json) {
    return ClusteringResult(
      success: json['success'] ?? false,
      clusters: (json['clusters'] as List<dynamic>?)
              ?.map((e) => SpendingCluster.fromJson(e))
              .toList() ??
          [],
      userProfile: json['userProfile'] ?? {},
      recommendations: (json['recommendations'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }

  factory ClusteringResult.error(String message) {
    return ClusteringResult(
      success: false,
      errorMessage: message,
    );
  }
}

class SpendingCluster {
  final int clusterId;
  final String clusterName;
  final String description;
  final Map<String, dynamic> characteristics;
  final double percentage;

  SpendingCluster({
    required this.clusterId,
    required this.clusterName,
    required this.description,
    required this.characteristics,
    required this.percentage,
  });

  factory SpendingCluster.fromJson(Map<String, dynamic> json) {
    return SpendingCluster(
      clusterId: json['clusterId'] ?? 0,
      clusterName: json['clusterName'] ?? '',
      description: json['description'] ?? '',
      characteristics: json['characteristics'] ?? {},
      percentage: (json['percentage'] ?? 0).toDouble(),
    );
  }
}

class AnomalyResult {
  final bool success;
  final String? errorMessage;
  final int totalTransactions;
  final int anomaliesDetected;
  final List<AnomalyTransaction> anomalies;
  final Map<String, dynamic> statistics;
  final List<String> alerts;

  AnomalyResult({
    required this.success,
    this.errorMessage,
    this.totalTransactions = 0,
    this.anomaliesDetected = 0,
    this.anomalies = const [],
    this.statistics = const {},
    this.alerts = const [],
  });

  factory AnomalyResult.fromJson(Map<String, dynamic> json) {
    return AnomalyResult(
      success: json['success'] ?? false,
      totalTransactions: json['totalTransactions'] ?? 0,
      anomaliesDetected: json['anomaliesDetected'] ?? 0,
      anomalies: (json['anomalies'] as List<dynamic>?)
              ?.map((e) => AnomalyTransaction.fromJson(e))
              .toList() ??
          [],
      statistics: json['statistics'] ?? {},
      alerts: (json['alerts'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }

  factory AnomalyResult.error(String message) {
    return AnomalyResult(
      success: false,
      errorMessage: message,
    );
  }
}

class AnomalyTransaction {
  final String transactionId;
  final int money;
  final String typeName;
  final String dateTime;
  final double anomalyScore;
  final String anomalyReason;
  final String severity;

  AnomalyTransaction({
    required this.transactionId,
    required this.money,
    required this.typeName,
    required this.dateTime,
    required this.anomalyScore,
    required this.anomalyReason,
    required this.severity,
  });

  factory AnomalyTransaction.fromJson(Map<String, dynamic> json) {
    return AnomalyTransaction(
      transactionId: json['transactionId'] ?? '',
      money: json['money'] ?? 0,
      typeName: json['typeName'] ?? '',
      dateTime: json['dateTime'] ?? '',
      anomalyScore: (json['anomalyScore'] ?? 0).toDouble(),
      anomalyReason: json['anomalyReason'] ?? '',
      severity: json['severity'] ?? 'low',
    );
  }

}
