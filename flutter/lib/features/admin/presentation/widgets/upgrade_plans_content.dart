import 'package:flutter/material.dart';
import 'package:learnova/core/ui/toast.dart';


import '../../../../shared/widgets/app_ui_components.dart';

class UpgradePlansContent extends StatefulWidget {
  const UpgradePlansContent({super.key});

  @override
  State<UpgradePlansContent> createState() => _UpgradePlansContentState();
}

class _UpgradePlansContentState extends State<UpgradePlansContent> {
  bool isYearly = false;

  void _comingSoon(String action) {
    AppToast.info(
      context,
      title: 'Coming soon',
      message: '$action is coming soon.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final isNarrow = c.maxWidth < 1100;

        
        const proMonthly = 99;
        const proYearlyMonthlyEquivalent = 79; // "save" when billed yearly
        const monthsInYear = 12;
        const proYearlyBilled = proYearlyMonthlyEquivalent * monthsInYear;

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Column(
                children: [
                  const Text(
                    'Ready to scale your institution?',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Choose a plan that fits your needs. Get savings with a yearly subscription.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14.5,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 22),

                  
                  UpgradePeriodToggle(
                    isYearly: isYearly,
                    onToggle: () => setState(() => isYearly = !isYearly),
                  ),

                  const SizedBox(height: 28),

                  if (isNarrow) ...[
                    const UpgradePlanCard(
                      title: 'Starter',
                      price: 'Free',
                      period: '',
                      description:
                          'Essential features for small teams and test projects.',
                      features: [
                        'Up to 50 Users',
                        'Basic Analytics',
                        'Community Support',
                        '1GB Storage',
                      ],
                      buttonText: 'Current Plan',
                      isPopular: false,
                      isCurrent: true,
                      tone: UpgradeTone.neutral,
                      onPressed: null,
                    ),
                    const SizedBox(height: 16),
                    UpgradePlanCard(
                      title: 'Professional',
                      price: isYearly
                          ? proYearlyMonthlyEquivalent.toString()
                          : proMonthly.toString(),
                      period: isYearly ? '/mo (billed yearly)' : '/month',
                      subPriceText:
                          isYearly ? '\$$proYearlyBilled billed yearly' : null,
                      description:
                          'Advanced features for growing schools and institutes.',
                      features: const [
                        'Unlimited Users',
                        'Advanced Analytics',
                        'Priority Email Support',
                        '100GB Storage',
                        'Custom Domain',
                        'API Access',
                      ],
                      buttonText: 'Upgrade Now',
                      isPopular: true,
                      isCurrent: false,
                      tone: UpgradeTone.primary,
                      onPressed: () => _comingSoon('Upgrade'),
                    ),
                    const SizedBox(height: 16),
                    UpgradePlanCard(
                      title: 'Enterprise',
                      price: 'Custom',
                      period: '',
                      description:
                          'Full-scale solution for large universities and enterprises.',
                      features: const [
                        'On-premise Hosting',
                        'Custom Integrations',
                        'Dedicated Manager',
                        'SLA Support',
                        'Unlimited Storage',
                        'White-labeling',
                      ],
                      buttonText: 'Contact Sales',
                      isPopular: false,
                      isCurrent: false,
                      tone: UpgradeTone.neutral,
                      onPressed: () => _comingSoon('Contact Sales'),
                    ),
                  ] else ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Expanded(
                          child: UpgradePlanCard(
                            title: 'Starter',
                            price: 'Free',
                            period: '',
                            description:
                                'Essential features for small teams and test projects.',
                            features: [
                              'Up to 50 Users',
                              'Basic Analytics',
                              'Community Support',
                              '1GB Storage',
                            ],
                            buttonText: 'Current Plan',
                            isPopular: false,
                            isCurrent: true,
                            tone: UpgradeTone.neutral,
                            onPressed: null,
                          ),
                        ),
                        const SizedBox(width: 18),
                        Expanded(
                          child: UpgradePlanCard(
                            title: 'Professional',
                            price: isYearly
                                ? proYearlyMonthlyEquivalent.toString()
                                : proMonthly.toString(),
                            period: isYearly ? '/mo (billed yearly)' : '/month',
                            subPriceText: isYearly
                                ? '\$$proYearlyBilled billed yearly'
                                : null,
                            description:
                                'Advanced features for growing schools and institutes.',
                            features: const [
                              'Unlimited Users',
                              'Advanced Analytics',
                              'Priority Email Support',
                              '100GB Storage',
                              'Custom Domain',
                              'API Access',
                            ],
                            buttonText: 'Upgrade Now',
                            isPopular: true,
                            isCurrent: false,
                            tone: UpgradeTone.primary,
                            onPressed: () => _comingSoon('Upgrade'),
                          ),
                        ),
                        const SizedBox(width: 18),
                        Expanded(
                          child: UpgradePlanCard(
                            title: 'Enterprise',
                            price: 'Custom',
                            period: '',
                            description:
                                'Full-scale solution for large universities and enterprises.',
                            features: const [
                              'On-premise Hosting',
                              'Custom Integrations',
                              'Dedicated Manager',
                              'SLA Support',
                              'Unlimited Storage',
                              'White-labeling',
                            ],
                            buttonText: 'Contact Sales',
                            isPopular: false,
                            isCurrent: false,
                            tone: UpgradeTone.neutral,
                            onPressed: () => _comingSoon('Contact Sales'),
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 18),

                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.lock_outline,
                            size: 18, color: Color(0xFF64748B),),
                        SizedBox(width: 10),
                        Text(
                          'Secure payments · Cancel anytime · Invoice available',
                          style: TextStyle(
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
