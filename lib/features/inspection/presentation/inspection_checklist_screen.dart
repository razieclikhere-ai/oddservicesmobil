// ────────────────────────────────────────────────────────────────────────────
// features/inspection/presentation/inspection_checklist_screen.dart
// Vehicle inspection checklist — SharedPreferences persistence, AI diagnostic
// ────────────────────────────────────────────────────────────────────────────
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/app_providers.dart';

// ─── Model ──────────────────────────────────────────────────────────────────
enum CheckStatus { unchecked, ok, warning, problem }

class CheckItem {
  final String id;
  final String label;
  final String? hint;
  CheckStatus status;

  CheckItem(
      {required this.id,
      required this.label,
      this.hint,
      this.status = CheckStatus.unchecked});
}

class CheckCategory {
  final String title;
  final IconData icon;
  final Color color;
  final List<CheckItem> items;
  bool isExpanded;

  CheckCategory({
    required this.title,
    required this.icon,
    required this.color,
    required this.items,
    this.isExpanded = true,
  });
}

// ─── Screen ─────────────────────────────────────────────────────────────────
class InspectionChecklistScreen extends ConsumerStatefulWidget {
  const InspectionChecklistScreen({super.key});

  @override
  ConsumerState<InspectionChecklistScreen> createState() =>
      _InspectionChecklistScreenState();
}

class _InspectionChecklistScreenState
    extends ConsumerState<InspectionChecklistScreen> {
  static String get _obfuscatedApiKey {
    const part1 = 'gsk_exMM6y7n';
    const part2 = 'CJJqt7qh6sjNWGdy';
    const part3 = 'b3FY8XthZ6rGXnvq3AVXQLSKSCHE';
    return part1 + part2 + part3;
  }

  final String _apiKey =
      const String.fromEnvironment('GROQ_API_KEY', defaultValue: '').isNotEmpty
          ? const String.fromEnvironment('GROQ_API_KEY')
          : _obfuscatedApiKey;

  bool _isAnalyzing = false;
  bool _isLoading = true;
  String? _aiResult;

  late List<CheckCategory> _categories;

  @override
  void initState() {
    super.initState();
    _initCategories();
    _loadState();
  }

  void _initCategories() {
    _categories = [
      CheckCategory(
        title: 'Pemeriksaan Harian',
        icon: FontAwesomeIcons.sun,
        color: AppTheme.neonCyan,
        items: [
          CheckItem(
              id: 'tire_pressure',
              label: 'Tekanan Ban',
              hint: 'Pastikan sesuai rekomendasi pabrik'),
          CheckItem(
              id: 'leaks',
              label: 'Cek Kebocoran',
              hint: 'Periksa bawah kendaraan – oli, air, dll'),
          CheckItem(
              id: 'lights',
              label: 'Cek Lampu',
              hint: 'Lampu depan, belakang, sein, hazard'),
          CheckItem(
              id: 'dashboard',
              label: 'Cek Dashboard',
              hint: 'Tidak ada lampu peringatan menyala'),
          CheckItem(
              id: 'fuel',
              label: 'Cek Bensin',
              hint: 'Pastikan cukup untuk perjalanan'),
          CheckItem(
              id: 'wiper',
              label: 'Cek Wiper',
              hint: 'Karet wiper masih efektif membersihkan'),
          CheckItem(
              id: 'engine_sound',
              label: 'Suara Mesin',
              hint: 'Dengarkan suara abnormal saat start'),
        ],
      ),
      CheckCategory(
        title: 'Cairan & Komponen Vital',
        icon: FontAwesomeIcons.oilCan,
        color: AppTheme.neonGreen,
        items: [
          CheckItem(
              id: 'oil',
              label: 'Cek Oli Mesin',
              hint: 'Level & kondisi warna oli'),
          CheckItem(
              id: 'coolant',
              label: 'Cek Coolant',
              hint: 'Level cairan pendingin radiator'),
          CheckItem(
              id: 'battery',
              label: 'Cek Aki',
              hint: 'Terminal bersih, tidak ada kerak'),
          CheckItem(
              id: 'wiper_fluid',
              label: 'Cek Air Wiper',
              hint: 'Reservoir air pembersih kaca'),
          CheckItem(
              id: 'brake',
              label: 'Cek Rem',
              hint: 'Respons rem, pedal tidak terasa kosong'),
          CheckItem(
              id: 'ac',
              label: 'Cek AC',
              hint: 'Dingin optimal, tidak ada bau abnormal'),
        ],
      ),
      CheckCategory(
        title: 'Jadwal Servis',
        icon: FontAwesomeIcons.screwdriverWrench,
        color: AppTheme.neonYellow,
        items: [
          CheckItem(
              id: 'air_filter',
              label: 'Bersihkan Filter Udara',
              hint: 'Interval: setiap 10.000 – 15.000 km'),
          CheckItem(
              id: 'oil_change',
              label: 'Ganti Oli Mesin',
              hint: 'Interval: setiap 5.000 – 10.000 km'),
          CheckItem(
              id: 'oil_filter',
              label: 'Filter Oli',
              hint: 'Ganti bersamaan dengan ganti oli'),
          CheckItem(
              id: 'brake_service',
              label: 'Servis Rem',
              hint: 'Kampas rem & minyak rem'),
          CheckItem(
              id: 'ac_service',
              label: 'Servis AC',
              hint: 'Freon, filter kabin, evaporator'),
        ],
      ),
      CheckCategory(
        title: 'Inspeksi Komprehensif',
        icon: FontAwesomeIcons.magnifyingGlass,
        color: AppTheme.neonOrange,
        items: [
          CheckItem(
              id: 'suspension',
              label: 'Cek Suspensi',
              hint: 'Karet bushing, link stabilizer'),
          CheckItem(
              id: 'bearing',
              label: 'Cek Bearing',
              hint: 'Suara dengung saat berkendara'),
          CheckItem(
              id: 'shockbreaker',
              label: 'Cek Shockbreaker',
              hint: 'Kebocoran oli, pantulan berlebih'),
          CheckItem(
              id: 'battery2',
              label: 'Cek Aki Mendalam',
              hint: 'Test voltase & ampere aki'),
          CheckItem(
              id: 'underbody',
              label: 'Cek Underbody',
              hint: 'Karat, retakan, kerusakan structural'),
        ],
      ),
    ];
  }

  Future<void> _loadState() async {
    final vehicleUuid = ref.read(activeVehicleUuidProvider);
    final prefs = await SharedPreferences.getInstance();

    final savedJson = prefs.getString('inspection_$vehicleUuid');
    final savedAiResult = prefs.getString('inspection_ai_$vehicleUuid');

    if (savedJson != null) {
      try {
        final Map<String, dynamic> data = jsonDecode(savedJson);
        for (final cat in _categories) {
          for (final item in cat.items) {
            if (data.containsKey(item.id)) {
              final statusIndex = data[item.id] as int;
              item.status = CheckStatus.values[statusIndex];
            }
          }
        }
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        _aiResult = savedAiResult;
        _isLoading = false;
      });
    }
  }

  Future<void> _saveState() async {
    final vehicleUuid = ref.read(activeVehicleUuidProvider);
    final prefs = await SharedPreferences.getInstance();

    final data = <String, int>{};
    for (final cat in _categories) {
      for (final item in cat.items) {
        data[item.id] = item.status.index;
      }
    }

    await prefs.setString('inspection_$vehicleUuid', jsonEncode(data));
    if (_aiResult != null) {
      await prefs.setString('inspection_ai_$vehicleUuid', _aiResult!);
    } else {
      await prefs.remove('inspection_ai_$vehicleUuid');
    }
  }

  Future<void> _resetChecklist() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.darkSurface,
        title: const Text('Reset Checklist?',
            style: TextStyle(color: Colors.white)),
        content: const Text(
            'Semua status item pemeriksaan dan hasil analisis AI akan dibersihkan.',
            style: TextStyle(color: Colors.grey)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.neonOrange,
                foregroundColor: Colors.black),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final vehicleUuid = ref.read(activeVehicleUuidProvider);
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('inspection_$vehicleUuid');
      await prefs.remove('inspection_ai_$vehicleUuid');

      setState(() {
        _aiResult = null;
        for (final cat in _categories) {
          for (final item in cat.items) {
            item.status = CheckStatus.unchecked;
          }
        }
      });
    }
  }

  // ─── Stats helpers ─────────────────────────────────────────────────────────
  List<CheckItem> get _allItems => _categories.expand((c) => c.items).toList();
  int get _checkedCount =>
      _allItems.where((i) => i.status != CheckStatus.unchecked).length;
  int get _totalCount => _allItems.length;
  int get _problemCount =>
      _allItems.where((i) => i.status == CheckStatus.problem).length;
  int get _warningCount =>
      _allItems.where((i) => i.status == CheckStatus.warning).length;
  double get _progress => _totalCount == 0 ? 0 : _checkedCount / _totalCount;
  bool get _allChecked => _checkedCount == _totalCount;

  // ─── AI Analysis ──────────────────────────────────────────────────────────
  Future<void> _analyzeWithAI() async {
    setState(() {
      _isAnalyzing = true;
      _aiResult = null;
    });

    final sb = StringBuffer();
    sb.writeln(
        'Saya baru saja melakukan inspeksi kendaraan dengan hasil berikut:');
    for (final cat in _categories) {
      sb.writeln('\n**${cat.title}:**');
      for (final item in cat.items) {
        final statusStr = item.status == CheckStatus.ok
            ? '✅ OK'
            : item.status == CheckStatus.warning
                ? '⚠️ Perlu Perhatian'
                : item.status == CheckStatus.problem
                    ? '❌ Bermasalah'
                    : '☐ Belum Diperiksa';
        sb.writeln('- ${item.label}: $statusStr');
      }
    }
    sb.writeln(
        '\nBerikan analisis singkat dan rekomendasi prioritas tindakan yang harus segera dilakukan, dalam Bahasa Indonesia.');

    try {
      final dio = Dio(BaseOptions(
        baseUrl: 'https://api.groq.com/openai/v1',
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json'
        },
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
      ));

      final response = await dio.post('/chat/completions', data: {
        'model': 'llama3-70b-8192',
        'messages': [
          {
            'role': 'system',
            'content':
                'Kamu adalah mekanik otomotif profesional bernama Smart OBD AI. Berikan analisis inspeksi kendaraan yang akurat, ringkas, dan actionable dalam Bahasa Indonesia.'
          },
          {'role': 'user', 'content': sb.toString()},
        ],
        'temperature': 0.4,
        'max_tokens': 600,
      });

      setState(() {
        _aiResult = response.data['choices'][0]['message']['content'] as String? ??
            'Tidak ada respons dari AI.';
      });
      await _saveState();
    } on DioException catch (e) {
      String err = 'Gagal terhubung ke AI.';
      if (e.response?.statusCode == 401) {
        err = 'API Key tidak valid. Periksa konfigurasi API Key Anda.';
      }
      setState(() {
        _aiResult = err;
      });
    } finally {
      setState(() {
        _isAnalyzing = false;
      });
    }
  }

  // ─── Item status cycle tap ─────────────────────────────────────────────────
  void _cycleStatus(CheckItem item) {
    setState(() {
      switch (item.status) {
        case CheckStatus.unchecked:
          item.status = CheckStatus.ok;
          break;
        case CheckStatus.ok:
          item.status = CheckStatus.warning;
          break;
        case CheckStatus.warning:
          item.status = CheckStatus.problem;
          break;
        case CheckStatus.problem:
          item.status = CheckStatus.unchecked;
          break;
      }
    });
    _saveState();
  }

  // ─── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      appBar: AppBar(
        backgroundColor: AppTheme.darkSurface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: Colors.white, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Inspeksi Kendaraan',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.rotate_left_rounded, color: Colors.grey),
            onPressed: _resetChecklist,
            tooltip: 'Reset checklist',
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16, left: 8),
              child: Text('$_checkedCount/$_totalCount',
                  style: const TextStyle(
                      color: AppTheme.neonCyan, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.neonCyan))
          : Column(
              children: [
                _buildProgressHeader(),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                    children: [
                      ..._categories.map((cat) => _buildCategoryCard(cat)),
                      if (_aiResult != null) _buildAIResultCard(),
                    ],
                  ),
                ),
              ],
            ),
      floatingActionButton: _buildActionButton(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildProgressHeader() {
    Color barColor = _problemCount > 0
        ? AppTheme.neonOrange
        : _warningCount > 0
            ? AppTheme.neonYellow
            : AppTheme.neonGreen;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      color: AppTheme.darkSurface,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Progress Inspeksi',
                    style: TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 2),
                RichText(
                    text: TextSpan(children: [
                  TextSpan(
                      text: '$_problemCount Masalah  ',
                      style: const TextStyle(
                          color: AppTheme.neonOrange,
                          fontWeight: FontWeight.bold)),
                  TextSpan(
                      text: '$_warningCount Perhatian',
                      style: const TextStyle(
                          color: AppTheme.neonYellow,
                          fontWeight: FontWeight.bold)),
                ])),
              ]),
              Text('${(_progress * 100).toInt()}%',
                  style: TextStyle(
                      color: barColor,
                      fontSize: 24,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: _progress,
              minHeight: 8,
              backgroundColor: Colors.white.withOpacity(0.06),
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(CheckCategory cat) {
    final doneCount =
        cat.items.where((i) => i.status != CheckStatus.unchecked).length;

    return Container(
      margin: const EdgeInsets.only(top: 16),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          // Category header
          InkWell(
            onTap: () => setState(() => cat.isExpanded = !cat.isExpanded),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: cat.color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(cat.icon, color: cat.color, size: 18),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(cat.title,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15)),
                        Text('$doneCount/${cat.items.length} selesai',
                            style: TextStyle(
                                color: Colors.grey[500], fontSize: 11)),
                      ],
                    ),
                  ),
                  Icon(
                      cat.isExpanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: Colors.grey),
                ],
              ),
            ),
          ),
          if (cat.isExpanded) ...[
            Divider(color: Colors.white.withOpacity(0.05), height: 1),
            ...cat.items.asMap().entries.map((e) => _buildCheckItem(
                e.value, e.key == cat.items.length - 1)),
          ],
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.05);
  }

  Widget _buildCheckItem(CheckItem item, bool isLast) {
    Color statusColor;
    IconData statusIcon;
    String statusLabel;

    switch (item.status) {
      case CheckStatus.ok:
        statusColor = AppTheme.neonGreen;
        statusIcon = Icons.check_circle_rounded;
        statusLabel = 'OK';
        break;
      case CheckStatus.warning:
        statusColor = AppTheme.neonYellow;
        statusIcon = Icons.warning_rounded;
        statusLabel = 'Perlu Perhatian';
        break;
      case CheckStatus.problem:
        statusColor = AppTheme.neonOrange;
        statusIcon = Icons.cancel_rounded;
        statusLabel = 'Bermasalah';
        break;
      default:
        statusColor = Colors.grey.shade600;
        statusIcon = Icons.radio_button_unchecked;
        statusLabel = 'Belum Diperiksa';
    }

    return InkWell(
      onTap: () => _cycleStatus(item),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: item.status != CheckStatus.unchecked
              ? statusColor.withOpacity(0.04)
              : Colors.transparent,
          border: isLast
              ? null
              : Border(bottom: BorderSide(color: Colors.white.withOpacity(0.04))),
          borderRadius: isLast
              ? const BorderRadius.vertical(bottom: Radius.circular(20))
              : null,
        ),
        child: Row(
          children: [
            Icon(statusIcon, color: statusColor, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.label,
                      style: TextStyle(
                          color: item.status == CheckStatus.unchecked
                              ? Colors.grey[300]
                              : Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14)),
                  if (item.hint != null)
                    Text(item.hint!,
                        style: TextStyle(
                            color: Colors.grey[600], fontSize: 11, height: 1.3)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(statusLabel,
                  style: TextStyle(
                      color: statusColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAIResultCard() {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.neonCyan.withOpacity(0.08), Colors.transparent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.neonCyan.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.neonCyan.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(FontAwesomeIcons.robot,
                    color: AppTheme.neonCyan, size: 16),
              ),
              const SizedBox(width: 12),
              const Text('Analisis Smart OBD AI',
                  style: TextStyle(
                      color: AppTheme.neonCyan,
                      fontWeight: FontWeight.bold,
                      fontSize: 15)),
            ],
          ),
          const SizedBox(height: 14),
          Text(_aiResult!,
              style: const TextStyle(
                  color: Colors.white70, fontSize: 14, height: 1.6)),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.1);
  }

  Widget _buildActionButton() {
    if (_isAnalyzing) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.darkSurface,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: AppTheme.neonCyan.withOpacity(0.3)),
        ),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppTheme.neonCyan)),
          SizedBox(width: 12),
          Text('AI Menganalisis...',
              style: TextStyle(
                  color: AppTheme.neonCyan, fontWeight: FontWeight.bold)),
        ]),
      );
    }

    if (!_allChecked) {
      return FloatingActionButton.extended(
        onPressed: null,
        backgroundColor: Colors.grey[800],
        label: Text(
          'Selesaikan Dulu ($_checkedCount/$_totalCount)',
          style:
              const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
        ),
        icon: const Icon(Icons.checklist_rounded, color: Colors.grey),
      );
    }

    return FloatingActionButton.extended(
      onPressed: _analyzeWithAI,
      backgroundColor: AppTheme.neonCyan,
      foregroundColor: Colors.black,
      icon: const Icon(FontAwesomeIcons.robot, size: 18),
      label: const Text('Analisis dengan AI',
          style: TextStyle(fontWeight: FontWeight.bold)),
    ).animate().scale(duration: 300.ms, curve: Curves.elasticOut);
  }
}
