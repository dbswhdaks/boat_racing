import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/api_constants.dart';
import '../../race/providers/race_providers.dart';

const Color _kPrimary = Color(0xFF1565C0);
const Color _kAccent = Color(0xFFFBBF24);

/// 공공데이터 API 키 설정 (경정)
class ApiSettingsScreen extends ConsumerStatefulWidget {
  const ApiSettingsScreen({super.key});

  @override
  ConsumerState<ApiSettingsScreen> createState() => _ApiSettingsScreenState();
}

class _ApiSettingsScreenState extends ConsumerState<ApiSettingsScreen> {
  final _controller = TextEditingController();
  bool _obscure = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadKey();
  }

  Future<void> _loadKey() async {
    await ApiConstants.loadServiceKey();
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _controller.text = prefs.getString('boat_racing_service_key') ?? '';
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    setState(() => _busy = true);
    try {
      await ApiConstants.saveServiceKey(_controller.text.trim());
      final api = ref.read(boatRacingApiProvider);
      final result = await api.testConnection();
      if (!mounted) return;
      final msg = result.isSuccess ? (result.data ?? '연결 성공') : (result.errorMessage ?? '실패');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      await ApiConstants.saveServiceKey(_controller.text.trim());
      ref.invalidate(raceListProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('API 키가 저장되었습니다. 경주 목록을 새로 불러옵니다.')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reset() async {
    setState(() => _busy = true);
    try {
      await ApiConstants.saveServiceKey('');
      _controller.clear();
      ref.invalidate(raceListProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('사용자 API 키를 초기화했습니다. 기본 키가 적용됩니다.')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '경정 API 설정',
          style: GoogleFonts.notoSansKr(fontWeight: FontWeight.w700),
        ),
        backgroundColor: _kPrimary,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '공공데이터포털(data.go.kr)에서 발급받은 인증키를 입력하세요. '
            '경정(보트레이싱) 경주·출주·배당 등 Open API 호출에 사용됩니다.',
            style: GoogleFonts.notoSansKr(
              height: 1.45,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            obscureText: _obscure,
            maxLines: 1,
            decoration: InputDecoration(
              labelText: '서비스 키 (인증키)',
              labelStyle: GoogleFonts.notoSansKr(color: _kPrimary),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _kPrimary),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _kAccent, width: 2),
              ),
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _busy ? null : _testConnection,
                  style: FilledButton.styleFrom(
                    backgroundColor: _kPrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.wifi_tethering),
                  label: Text(
                    '연결 테스트',
                    style: GoogleFonts.notoSansKr(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _save,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _kPrimary,
                    side: const BorderSide(color: _kPrimary),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: const Icon(Icons.save_outlined),
                  label: Text(
                    '저장',
                    style: GoogleFonts.notoSansKr(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _reset,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                    side: BorderSide(color: theme.colorScheme.error.withValues(alpha: 0.6)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: const Icon(Icons.restart_alt),
                  label: Text(
                    '초기화',
                    style: GoogleFonts.notoSansKr(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _kPrimary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _kAccent.withValues(alpha: 0.35)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.help_outline, color: _kAccent, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      'API 키 발급 안내 (경정)',
                      style: GoogleFonts.notoSansKr(
                        fontWeight: FontWeight.w800,
                        color: _kPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  '1. 공공데이터포털(https://www.data.go.kr)에 회원가입 후 로그인합니다.\n'
                  '2. 상단 검색에서 「경정」 또는 「보트레이싱」 관련 Open API를 검색합니다.\n'
                  '3. 활용신청 후 발급되는 일반 인증키(Encoding)를 복사해 위 입력란에 붙여넣습니다.\n'
                  '4. 「연결 테스트」로 응답을 확인한 뒤 「저장」을 눌러 주세요.',
                  style: GoogleFonts.notoSansKr(
                    fontSize: 13,
                    height: 1.5,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.88),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
