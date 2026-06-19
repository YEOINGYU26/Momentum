import 'package:flutter/material.dart';

enum LineRole { none, buyTrigger, sellTrigger, alert, stopLoss, takeProfit }

extension LineRoleX on LineRole {
  String get label {
    switch (this) {
      case LineRole.none:        return '추세선';
      case LineRole.buyTrigger:  return '매수선';
      case LineRole.sellTrigger: return '매도선';
      case LineRole.alert:       return '알림선';
      case LineRole.stopLoss:    return '손절선';
      case LineRole.takeProfit:  return '목표가선';
    }
  }

  Color get roleColor {
    switch (this) {
      case LineRole.none:        return Colors.white70;
      case LineRole.buyTrigger:  return const Color(0xFF26A69A);
      case LineRole.sellTrigger: return const Color(0xFFEF5350);
      case LineRole.alert:       return const Color(0xFFFFD700);
      case LineRole.stopLoss:    return const Color(0xFFFF8A65);
      case LineRole.takeProfit:  return const Color(0xFF4FC3F7);
    }
  }

  IconData get icon {
    switch (this) {
      case LineRole.none:        return Icons.timeline;
      case LineRole.buyTrigger:  return Icons.arrow_upward;
      case LineRole.sellTrigger: return Icons.arrow_downward;
      case LineRole.alert:       return Icons.notifications_outlined;
      case LineRole.stopLoss:    return Icons.shield_outlined;
      case LineRole.takeProfit:  return Icons.flag_outlined;
    }
  }
}

class ChartLineInfo {
  final double startPrice;
  final double endPrice;
  final int startTime;
  final int endTime;
  final bool isHorizontal;
  final LineRole role;

  const ChartLineInfo({
    required this.startPrice,
    required this.endPrice,
    required this.startTime,
    required this.endTime,
    this.isHorizontal = false,
    this.role = LineRole.none,
  });

  double priceAt(int unixSec) {
    if (isHorizontal) return startPrice;
    if (endTime == startTime) return startPrice;
    final t = (unixSec - startTime) / (endTime - startTime);
    return startPrice + t * (endPrice - startPrice);
  }

  String get label {
    final roleStr = role != LineRole.none ? '[${role.label}] ' : '';
    if (isHorizontal) return '$roleStr수평선  ${startPrice.toStringAsFixed(0)}원';
    return '$roleStr추세선  ${startPrice.toStringAsFixed(0)} → ${endPrice.toStringAsFixed(0)}원';
  }

  Map<String, dynamic> toJson() => {
    'startPrice': startPrice,
    'endPrice': endPrice,
    'startTime': startTime,
    'endTime': endTime,
    'isHorizontal': isHorizontal,
    'role': role.name,
  };

  factory ChartLineInfo.fromJson(Map<String, dynamic> json) => ChartLineInfo(
    startPrice: (json['startPrice'] as num).toDouble(),
    endPrice: (json['endPrice'] as num).toDouble(),
    startTime: json['startTime'] as int,
    endTime: json['endTime'] as int,
    isHorizontal: json['isHorizontal'] as bool? ?? false,
    role: LineRole.values.firstWhere(
      (r) => r.name == (json['role'] as String? ?? 'none'),
      orElse: () => LineRole.none,
    ),
  );
}
