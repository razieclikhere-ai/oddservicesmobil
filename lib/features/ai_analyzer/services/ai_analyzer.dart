import 'package:flutter/material.dart';

enum HealthStatus { normal, warning, critical }

enum ComponentType { engine, battery, brakes, tires, coolant, oil, transmission }

class ComponentStatus {
  final ComponentType type;
  final HealthStatus status;
  final String label;
  final String value;
  final String recommendation;

  ComponentStatus({
    required this.type,
    required this.status,
    required this.label,
    required this.value,
    required this.recommendation,
  });

  Color get statusColor {
    switch (status) {
      case HealthStatus.normal:
        return Colors.green;
      case HealthStatus.warning:
        return Colors.orange;
      case HealthStatus.critical:
        return Colors.red;
    }
  }

  IconData get statusIcon {
    switch (status) {
      case HealthStatus.normal:
        return Icons.check_circle;
      case HealthStatus.warning:
        return Icons.warning;
      case HealthStatus.critical:
        return Icons.error;
    }
  }
}

class AnalysisResult {
  final double healthScore;
  final HealthStatus overallStatus;
  final String summary;
  final List<ComponentStatus> components;
  final List<String> recommendations;
  final List<String> activeDtcs;

  AnalysisResult({
    required this.healthScore,
    required this.overallStatus,
    required this.summary,
    required this.components,
    required this.recommendations,
    required this.activeDtcs,
  });
}

class LiveDataReading {
  final String pid;
  final String name;
  final double value;
  final String unit;

  LiveDataReading({
    required this.pid,
    required this.name,
    required this.value,
    required this.unit,
  });
}

class AIAnalyzer {
  static const double _coolantWarningThreshold = 100.0;
  static const double _coolantCriticalThreshold = 105.0;
  static const double _batteryWarningThreshold = 12.4;
  static const double _batteryCriticalThreshold = 12.0;
  static const double _fuelTrimWarningThreshold = 10.0;
  static const double _fuelTrimCriticalThreshold = 20.0;

  static AnalysisResult analyze({
    required List<LiveDataReading> liveData,
    required List<String> activeDtcs,
    required int currentMileage,
    required int lastServiceMileage,
  }) {
    final Map<String, LiveDataReading> dataMap = {
      for (var reading in liveData) reading.pid: reading
    };

    double coolantTemp = dataMap['0105']?.value ?? 90.0;
    double batteryVoltage = dataMap['0142']?.value ?? 12.6;
    double shortTermFuelTrim = dataMap['0106']?.value ?? 0.0;
    double longTermFuelTrim = dataMap['0107']?.value ?? 0.0;
    double fuelTrim = shortTermFuelTrim + longTermFuelTrim;
    bool isMisfire = activeDtcs.any((dtc) => dtc.startsWith('P030'));

    final List<ComponentStatus> components = [];
    final List<String> recommendations = [];
    double score = 100.0;

    // Engine Coolant Analysis
    HealthStatus coolantStatus = HealthStatus.normal;
    String coolantRec = 'Normal operating temperature';
    if (coolantTemp > _coolantCriticalThreshold) {
      coolantStatus = HealthStatus.critical;
      coolantRec = '⚠️ OVERHEATING! Stop immediately. Check coolant level, radiator, thermostat.';
      score -= 30;
    } else if (coolantTemp > _coolantWarningThreshold) {
      coolantStatus = HealthStatus.warning;
      coolantRec = '⚠️ High coolant temperature. Monitor closely. Check cooling system.';
      score -= 15;
    }
    components.add(ComponentStatus(
      type: ComponentType.coolant,
      status: coolantStatus,
      label: 'Coolant Temp',
      value: '${coolantTemp.toStringAsFixed(1)}°C',
      recommendation: coolantRec,
    ));

    // Battery Analysis
    HealthStatus batteryStatus = HealthStatus.normal;
    String batteryRec = 'Battery voltage normal';
    if (batteryVoltage < _batteryCriticalThreshold) {
      batteryStatus = HealthStatus.critical;
      batteryRec = '🔋 CRITICAL: Battery failing. Replace immediately.';
      score -= 25;
    } else if (batteryVoltage < _batteryWarningThreshold) {
      batteryStatus = HealthStatus.warning;
      batteryRec = '🔋 Battery weakening. Test charging system and battery health.';
      score -= 10;
    }
    components.add(ComponentStatus(
      type: ComponentType.battery,
      status: batteryStatus,
      label: 'Battery',
      value: '${batteryVoltage.toStringAsFixed(1)}V',
      recommendation: batteryRec,
    ));

    // Fuel Trim Analysis
    HealthStatus fuelStatus = HealthStatus.normal;
    String fuelRec = 'Fuel system operating normally';
    if (fuelTrim.abs() > _fuelTrimCriticalThreshold) {
      fuelStatus = HealthStatus.critical;
      fuelRec = '⛽ Severe fuel trim deviation. Clean injectors, check MAF, vacuum leaks.';
      score -= 20;
    } else if (fuelTrim.abs() > _fuelTrimWarningThreshold) {
      fuelStatus = HealthStatus.warning;
      fuelRec = '⛽ Fuel trim high. Consider injector cleaning or MAF sensor check.';
      score -= 10;
    }
    components.add(ComponentStatus(
      type: ComponentType.engine,
      status: fuelStatus,
      label: 'Fuel Trim',
      value: '${fuelTrim.toStringAsFixed(1)}%',
      recommendation: fuelRec,
    ));

    // Misfire Detection
    HealthStatus misfireStatus = isMisfire ? HealthStatus.critical : HealthStatus.normal;
    String misfireRec = isMisfire 
        ? '🔥 MISFIRE DETECTED! Check spark plugs, ignition coils, compression.'
        : 'No misfires detected';
    if (isMisfire) score -= 25;
    components.add(ComponentStatus(
      type: ComponentType.engine,
      status: misfireStatus,
      label: 'Misfire',
      value: isMisfire ? 'DETECTED' : 'None',
      recommendation: misfireRec,
    ));

    // Service Interval Check
    int mileageSinceService = currentMileage - lastServiceMileage;
    HealthStatus serviceStatus = HealthStatus.normal;
    String serviceRec = 'Service up to date';
    if (mileageSinceService > 10000) {
      serviceStatus = HealthStatus.warning;
      serviceRec = '🔧 Service due soon (${mileageSinceService}km since last service)';
      score -= 10;
    } else if (mileageSinceService > 15000) {
      serviceStatus = HealthStatus.critical;
      serviceRec = '🔧 SERVICE OVERDUE! (${mileageSinceService}km since last service)';
      score -= 20;
    }
    components.add(ComponentStatus(
      type: ComponentType.oil,
      status: serviceStatus,
      label: 'Oil Service',
      value: '$mileageSinceService km',
      recommendation: serviceRec,
    ));

    // DTC Analysis
    if (activeDtcs.isNotEmpty) {
      recommendations.add('🛠 ${activeDtcs.length} active DTC(s): ${activeDtcs.join(", ")}. Use Technician Mode for Freeze Frame analysis.');
      score -= (activeDtcs.length * 5).clamp(0, 30);
    }

    // Add component recommendations to global list
    for (var comp in components) {
      if (comp.status != HealthStatus.normal) {
        recommendations.add(comp.recommendation);
      }
    }

    HealthStatus overallStatus = HealthStatus.normal;
    if (components.any((c) => c.status == HealthStatus.critical)) {
      overallStatus = HealthStatus.critical;
    } else if (components.any((c) => c.status == HealthStatus.warning)) {
      overallStatus = HealthStatus.warning;
    }

    return AnalysisResult(
      healthScore: score.clamp(0, 100),
      overallStatus: overallStatus,
      summary: _generateSummary(overallStatus, activeDtcs.length, components),
      components: components,
      recommendations: recommendations,
      activeDtcs: activeDtcs,
    );
  }

  static String _generateSummary(HealthStatus status, int dtcCount, List<ComponentStatus> components) {
    switch (status) {
      case HealthStatus.critical:
        return '⚠️ CRITICAL: Immediate attention required. ${components.where((c) => c.status == HealthStatus.critical).length} critical issue(s), $dtcCount DTC(s).';
      case HealthStatus.warning:
        return '⚠️ WARNING: ${components.where((c) => c.status == HealthStatus.warning).length} component(s) need attention. $dtcCount DTC(s).';
      case HealthStatus.normal:
        return '✅ Vehicle operating normally. No critical issues detected.';
    }
  }

  static String getDtcDescription(String code) {
    if (code.startsWith('P030')) return 'Cylinder Misfire Detected';
    if (code == 'P0420') return 'Catalyst System Efficiency Below Threshold (Bank 1)';
    if (code == 'P0171') return 'System Too Lean (Bank 1)';
    if (code == 'P0172') return 'System Too Rich (Bank 1)';
    if (code == 'P0101') return 'Mass Air Flow Circuit Range/Performance';
    if (code == 'P0102') return 'Mass Air Flow Circuit Low Input';
    if (code == 'P0113') return 'Intake Air Temperature Sensor Circuit High';
    return 'Unknown DTC: $code';
  }

  static String estimateRepairCost(String code) {
    if (code.startsWith('P030')) return 'Est: $50-$300 (Spark plugs/Coils)';
    if (code == 'P0420') return 'Est: $200-$1000 (Catalytic Converter/O2 Sensor)';
    if (code == 'P0171' || code == 'P0172') return 'Est: $100-$500 (Vacuum leak/Injectors/MAF)';
    return 'Est: Variable - Requires diagnosis';
  }
}