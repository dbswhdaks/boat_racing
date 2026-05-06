import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/iap_constants.dart';
import '../providers/in_app_purchase_provider.dart';

const Color _kBg = Color(0xFF0D1117);
const Color _kCard = Color(0xFF161B22);
const Color _kPrimary = Color(0xFF1565C0);
const Color _kAccent = Color(0xFFFBBF24);
const Color _kBorder = Color(0xFF30363D);

class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({
    super.key,
    this.initialProductId = IapConstants.monthlyProductId,
  });

  final String initialProductId;

  @override
  ConsumerState<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen> {
  late String _selectedProductId;
  String _selectedPaymentMethod = '신용/체크카드';

  @override
  void initState() {
    super.initState();
    _selectedProductId = widget.initialProductId == IapConstants.yearlyProductId
        ? IapConstants.yearlyProductId
        : IapConstants.monthlyProductId;
  }

  Future<void> _openPlayPaymentMethods(BuildContext context) async {
    final uri = Uri.parse('https://play.google.com/store/paymentmethods');
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('결제수단 관리 페이지를 열 수 없습니다.')));
    }
  }

  Future<String?> _showPaymentMethodPicker(BuildContext context) {
    const options = ['신용/체크카드', '휴대폰 결제', '계좌이체'];
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: _kCard,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '결제수단 선택',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              ...options.map(
                (option) => ListTile(
                  title: Text(
                    option,
                    style: const TextStyle(color: Colors.white),
                  ),
                  trailing: option == _selectedPaymentMethod
                      ? const Icon(Icons.check_circle, color: _kAccent)
                      : null,
                  onTap: () => Navigator.of(context).pop(option),
                ),
              ),
              const SizedBox(height: 6),
            ],
          ),
        );
      },
    );
  }

  String _formatPriceSpacing(String raw) {
    return raw.replaceAllMapped(
      RegExp(r'[￦₩]\s*'),
      (match) => '${match.group(0)![0]} ',
    );
  }

  @override
  Widget build(BuildContext context) {
    final iapState = ref.watch(inAppPurchaseProvider);
    final notifier = ref.read(inAppPurchaseProvider.notifier);
    final productMap = {for (final p in iapState.products) p.id: p};
    final isMonthly = _selectedProductId == IapConstants.monthlyProductId;
    final isPending = iapState.isPurchasePending;
    final actionText = isMonthly ? '월간 구독 결제' : '연간 구독 결제';
    final hasSubscription = iapState.purchasedProductIds.any(
      IapConstants.subscriptionProductIds.contains,
    );

    String monthlyText() {
      final monthly = productMap[IapConstants.monthlyProductId];
      if (monthly != null) return '월간 ${_formatPriceSpacing(monthly.price)}';
      return '월간 ￦ 9,900원';
    }

    String yearlyText() {
      final yearly = productMap[IapConstants.yearlyProductId];
      if (yearly != null) {
        return '연간 ${_formatPriceSpacing(yearly.price)} (17% 절약)';
      }
      return '연간 ￦ 99,000원 (17% 절약)';
    }

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kCard,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          '구독 결제',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
          children: [
            _buildHeroCard(),
            const SizedBox(height: 16),
            _buildPaymentMethodsCard(context),
            const SizedBox(height: 16),
            _buildPlanCard(monthlyText(), yearlyText(), isMonthly),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: isPending
                  ? null
                  : () async {
                      if (isMonthly) {
                        final selectedMethod = await _showPaymentMethodPicker(
                          context,
                        );
                        if (selectedMethod == null) return;
                        if (!mounted) return;
                        setState(() => _selectedPaymentMethod = selectedMethod);
                      }

                      final ok = await notifier.startSubscriptionPurchase(
                        preferredProductId: _selectedProductId,
                      );
                      if (!mounted) return;
                      if (!ok && context.mounted) {
                        final latestState = ref.read(inAppPurchaseProvider);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              latestState.errorMessage ?? '결제를 시작하지 못했습니다.',
                            ),
                          ),
                        );
                        return;
                      }

                      if (isMonthly && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              '선택한 결제수단: $_selectedPaymentMethod\n'
                              '실제 결제는 구글플레이에서 진행됩니다.',
                            ),
                          ),
                        );
                      }
                    },
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                backgroundColor: _kPrimary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: _kPrimary.withValues(alpha: 0.4),
                disabledForegroundColor: Colors.white.withValues(alpha: 0.6),
                elevation: 0,
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: isPending
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    )
                  : Text(actionText),
            ),
            const SizedBox(height: 10),
            if (hasSubscription)
              Text(
                '이미 구독이 확인되었습니다. 이전 화면으로 돌아가면 잠금이 해제됩니다.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.greenAccent.shade100,
                ),
              ),
            if (iapState.errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                '오류: ${iapState.errorMessage}',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.red.shade200),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              '현재 선택 결제수단: $_selectedPaymentMethod',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () => notifier.restorePurchases(clearExisting: true),
              icon: const Icon(
                Icons.restore_rounded,
                color: _kAccent,
                size: 18,
              ),
              label: Text(
                '구매 복원',
                style: TextStyle(color: Colors.grey.shade300, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0D47A1), Color(0xFF1565C0), Color(0xFF0097A7)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.workspace_premium_rounded,
                color: _kAccent,
                size: 22,
              ),
              SizedBox(width: 8),
              Text(
                '경정 Plus 프리미엄',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'AI 예측 · 종합 분석 · 베팅 추천을 모두 이용해 보세요.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 13,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const [
              _BenefitChip(icon: Icons.auto_awesome, label: 'AI 추천'),
              _BenefitChip(icon: Icons.insights_outlined, label: '신뢰도 분석'),
              _BenefitChip(icon: Icons.flag_outlined, label: '단·복·쌍승 추천'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodsCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder),
        color: _kCard,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.payments_outlined,
                size: 18,
                color: Color(0xFF64B5F6),
              ),
              SizedBox(width: 8),
              Text(
                '지원 결제수단 (구글플레이)',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _PaymentMethodChip(label: '신용/체크카드'),
              _PaymentMethodChip(label: '휴대폰 결제'),
              _PaymentMethodChip(label: '계좌이체'),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '실제 결제수단 노출은 계정/국가/스토어 설정에 따라 달라질 수 있습니다.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 6),
          TextButton.icon(
            onPressed: () => _openPlayPaymentMethods(context),
            icon: const Icon(
              Icons.open_in_new_rounded,
              size: 14,
              color: _kAccent,
            ),
            label: Text(
              '결제수단 관리',
              style: TextStyle(color: Colors.grey.shade200, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanCard(String monthlyText, String yearlyText, bool isMonthly) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder),
        color: _kCard,
      ),
      child: Column(
        children: [
          _PlanOptionTile(
            selected: isMonthly,
            label: monthlyText,
            onTap: () => setState(
              () => _selectedProductId = IapConstants.monthlyProductId,
            ),
          ),
          const SizedBox(height: 10),
          _PlanOptionTile(
            selected: !isMonthly,
            label: yearlyText,
            onTap: () => setState(
              () => _selectedProductId = IapConstants.yearlyProductId,
            ),
          ),
        ],
      ),
    );
  }
}

class _BenefitChip extends StatelessWidget {
  const _BenefitChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: _kAccent, size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentMethodChip extends StatelessWidget {
  const _PaymentMethodChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _kBorder),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.grey.shade200,
        ),
      ),
    );
  }
}

class _PlanOptionTile extends StatelessWidget {
  const _PlanOptionTile({
    required this.selected,
    required this.label,
    required this.onTap,
  });

  final bool selected;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(13),
          color: selected
              ? _kAccent.withValues(alpha: 0.18)
              : Colors.white.withValues(alpha: 0.02),
          border: Border.all(
            color: selected
                ? _kAccent.withValues(alpha: 0.7)
                : _kBorder,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: selected ? _kAccent : Colors.grey.shade500,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: selected ? _kAccent : Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
