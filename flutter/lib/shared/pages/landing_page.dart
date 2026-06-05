import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/routing/routes.dart';
import 'package:learnova/core/theme/app_theme.dart';

/// Public landing page for unauthenticated (guest) visitors.
///
/// Sections (matching the design):
///   1. Navigation bar
///   2. Hero — headline + mockup
///   3. "Tailored for the Academic Ecosystem" — 3 audience cards
///   4. "Everything needed for modern assessment" — feature grid
///   5. "Seamless Workflow Integration" — 5-step flow
///   6. "Comprehensive Portals for Every Role" — portals + mockup
///   7. Stat bar — 4 benefit chips
///   8. CTA banner — "Transform Learning with AI"
///   9. Footer
class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Scaffold(
      backgroundColor: AppColors.cardBg,
      body: ListView.builder(
        // Lazily build landing sections to avoid heavy first-frame work on web.
        itemCount: 9,
        itemBuilder: (context, index) {
          switch (index) {
            case 0:
              return _NavBar(
                onLogin: () => context.go(Routes.login),
                onSignUp: () => context.go(Routes.signup),
              );
            case 1:
              return _HeroSection(
                onGetStarted: () => context.go(Routes.signup),
                onLogin: () => context.go(Routes.login),
              );
            case 2:
              return _AudienceSection();
            case 3:
              return _FeaturesSection(onExplore: () => context.go(Routes.signup));
            case 4:
              return  _WorkflowSection();
            case 5:
              return  _PortalsSection();
            case 6:
              return  _StatsBar();
            case 7:
              return _CtaBanner(
                onSignUp: () => context.go(Routes.signup),
                onLogin: () => context.go(Routes.login),
              );
            case 8:
            default:
              return _Footer(
                onLogin: () => context.go(Routes.login),
                onSignUp: () => context.go(Routes.signup),
              );
          }
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 1. Nav bar
// ─────────────────────────────────────────────────────────────────────────────

class _NavBar extends StatelessWidget {
  final VoidCallback onLogin;
  final VoidCallback onSignUp;
  const _NavBar({required this.onLogin, required this.onSignUp});

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Container(
      height: 56,
      color: AppColors.cardBg,
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Row(
        children: [
          // Logo
          Image.asset('assets/logo.webp', height: 28, cacheWidth: (28 * MediaQuery.of(context).devicePixelRatio).round()),
          const SizedBox(width: 8),
          Text(
            'Learnova',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textTitle,
              letterSpacing: -0.3,
            ),
          ),

          const SizedBox(width: 40),

          // Nav links (hide on small screens)
          if (MediaQuery.sizeOf(context).width > 700) ...[
            const _NavLink('Features'),
            const SizedBox(width: 28),
            const _NavLink('How It Works'),
            const SizedBox(width: 28),
            const _NavLink('Benefits'),
          ],

          const Spacer(),

          // Auth buttons
          TextButton(
            onPressed: onLogin,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textGray,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            child: const Text('Login',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: onSignUp,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),),
            ),
            child: const Text('Sign Up',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),),
          ),
        ],
      ),
    );
  }
}

class _NavLink extends StatelessWidget {
  final String label;
  const _NavLink(this.label);

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Text(
      label,
      style: TextStyle(
        fontSize: 14,
        color: AppColors.textGray,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 2. Hero
// ─────────────────────────────────────────────────────────────────────────────

class _HeroSection extends StatelessWidget {
  final VoidCallback onGetStarted;
  final VoidCallback onLogin;
  const _HeroSection({required this.onGetStarted, required this.onLogin});

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    final w = MediaQuery.sizeOf(context).width;
    final isMobile = w < 700;

    return Container(
      color: AppColors.cardBg,
      padding: EdgeInsets.fromLTRB(isMobile ? 24 : 80, 60, isMobile ? 24 : 80, 80),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _HeroText(onGetStarted: onGetStarted, onLogin: onLogin),
                const SizedBox(height: 40),
                _HeroMockup(),
              ],
            )
          : Row(
              children: [
                Expanded(
                  child: _HeroText(onGetStarted: onGetStarted, onLogin: onLogin),
                ),
                const SizedBox(width: 60),
                Expanded(child: _HeroMockup()),
              ],
            ),
    );
  }
}

class _HeroText extends StatelessWidget {
  final VoidCallback onGetStarted;
  final VoidCallback onLogin;
  const _HeroText({required this.onGetStarted, required this.onLogin});

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Headline with blue highlight
        RichText(
          text: TextSpan(
            style: TextStyle(
              fontSize: 42,
              fontWeight: FontWeight.w900,
              color: AppColors.textTitle,
              height: 1.15,
              letterSpacing: -1.0,
            ),
            children: [
              const TextSpan(text: 'Smart Study\nCompanion: '),
              const TextSpan(
                text: 'AI-\nPowered',
                style: TextStyle(color: AppColors.primary),
              ),
              const TextSpan(text: ' Learning &\nAssessment'),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Subtitle
        Text(
          'Automatically extract topics, generate questions, assess\n'
          'students, and personalize learning using advanced AI. Trusted\n'
          'by leading academic institutions.',
          style: TextStyle(
            fontSize: 14.5,
            color: AppColors.textGray,
            height: 1.65,
          ),
        ),
        const SizedBox(height: 32),

        // Buttons
        Row(
          children: [
            ElevatedButton(
              onPressed: onGetStarted,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),),
              ),
              child: const Text('Get Started',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),),
            ),
            const SizedBox(width: 16),
            TextButton(
              onPressed: onLogin,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textGray,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              child: const Text('Login',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),),
            ),
          ],
        ),
      ],
    );
  }
}

class _HeroMockup extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Container(
      height: 320,
      decoration: BoxDecoration(
        color: const Color(0xFF0E7490),
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Decorative circles
          Positioned(
            top: -40,
            right: -40,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: -30,
            left: -30,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                shape: BoxShape.circle,
              ),
            ),
          ),

          // Mock UI card
          Center(
            child: Container(
              margin: const EdgeInsets.all(28),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2),),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Traffic lights
                  Row(
                    children: [
                      _dot(AppColors.errorDot),
                      const SizedBox(width: 6),
                      _dot(AppColors.warningText),
                      const SizedBox(width: 6),
                      _dot(AppColors.successDot),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // Mock bar chart rows
                  for (final pct in [0.7, 0.45, 0.85, 0.55])
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Container(
                            width: 50,
                            height: 8,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: pct,
                                minHeight: 8,
                                backgroundColor: AppColors.cardBg.withValues(alpha: 0.2),
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                    AppColors.primary,),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 10),
                  // Completed badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6,),
                    decoration: BoxDecoration(
                      color: AppColors.successDot,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle,
                            size: 14, color: Colors.white,),
                        SizedBox(width: 6),
                        Text(
                          'Completed in 1.2x',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
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
        ],
      ),
    );
  }

  Widget _dot(Color c) => Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: c, shape: BoxShape.circle),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// 3. Audience cards
// ─────────────────────────────────────────────────────────────────────────────

class _AudienceSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    Theme.of(context);

    return Container(
      color: AppColors.surfaceBg,
      padding: const EdgeInsets.symmetric(vertical: 72, horizontal: 40),
      child: Column(
        children: [
          Text(
            'Tailored for the Academic Ecosystem',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: AppColors.textTitle,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Designed to serve every stakeholder in the educational process with specialized tools.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.primary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 48),
          LayoutBuilder(builder: (_, constraints) {
            if (constraints.maxWidth > 800) {
              return const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _AudienceCard(
                    icon: Icons.school_outlined,
                    title: 'Instructors',
                    subtitle: 'Empower your teaching with AI tools that remove the heavy lifting of assessment creation.',
                    bullets: [
                      'Upload materials & auto-generate questions',
                      'Track student performance analytics',
                      'Reduce grading time by 80%',
                    ],
                  ),),
                  SizedBox(width: 20),
                  Expanded(child: _AudienceCard(
                    icon: Icons.person_outline_rounded,
                    title: 'Students',
                    subtitle: 'Enhance your study routine with personalised feedback and an AI tutor assistant 24/7.',
                    bullets: [
                      'Personalized learning paths',
                      'Instant feedback on quizzes',
                      'AI-powered study assistant',
                    ],
                  ),),
                  SizedBox(width: 20),
                  Expanded(child: _AudienceCard(
                    icon: Icons.business_outlined,
                    title: 'Institutions',
                    subtitle: 'Scale assessment quality across departments with centralized management and insights.',
                    bullets: [
                      'Centralized question banks',
                      'Deep analytics & global insights',
                      'Scalable & secure assessment',
                    ],
                  ),),
                ],
              );
            }
            return const Column(
              children: [
                _AudienceCard(
                  icon: Icons.school_outlined,
                  title: 'Instructors',
                  subtitle: 'Empower your teaching with AI tools.',
                  bullets: [
                    'Upload materials & auto-generate questions',
                    'Track student performance analytics',
                    'Reduce grading time by 80%',
                  ],
                ),
                SizedBox(height: 16),
                _AudienceCard(
                  icon: Icons.person_outline_rounded,
                  title: 'Students',
                  subtitle: 'Enhance your study routine with AI assistance.',
                  bullets: [
                    'Personalized learning paths',
                    'Instant feedback on quizzes',
                    'AI-powered study assistant',
                  ],
                ),
                SizedBox(height: 16),
                _AudienceCard(
                  icon: Icons.business_outlined,
                  title: 'Institutions',
                  subtitle: 'Scale assessment quality across departments.',
                  bullets: [
                    'Centralized question banks',
                    'Deep analytics & global insights',
                    'Scalable & secure assessment',
                  ],
                ),
              ],
            );
          },),
        ],
      ),
    );
  }
}

class _AudienceCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<String> bullets;

  const _AudienceCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.bullets,
  });

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 22, color: AppColors.primary),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppColors.textTitle,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textGray,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          ...bullets.map((b) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.check, size: 14, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        b,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textGray,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 4. Features grid
// ─────────────────────────────────────────────────────────────────────────────

class _FeaturesSection extends StatelessWidget {
  final VoidCallback onExplore;
  const _FeaturesSection({required this.onExplore});

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Container(
      color: AppColors.cardBg,
      padding: const EdgeInsets.symmetric(vertical: 72, horizontal: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'KEY FEATURES',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Everything needed for modern assessment',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: AppColors.textTitle,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 40),
          LayoutBuilder(builder: (_, constraints) {
            final cols = constraints.maxWidth > 900 ? 3 : (constraints.maxWidth > 600 ? 2 : 1);
            return _FeatureGrid(columns: cols, onExplore: onExplore);
          },),
        ],
      ),
    );
  }
}

class _FeatureGrid extends StatelessWidget {
  final int columns;
  final VoidCallback onExplore;
  const _FeatureGrid({required this.columns, required this.onExplore});

  static List<_FeatureItem> get _features => [
    const _FeatureItem(
      icon: Icons.description_outlined,
      color: AppColors.primary,
      title: 'AI Material Processing',
      desc: 'Upload textbooks, PDFs, or lecture notes. Our AI automatically parses and structures the content into learning modules.',
    ),
    _FeatureItem(
      icon: Icons.quiz_outlined,
      color: AppColors.purpleText,
      title: 'AI Question Generation',
      desc: 'Automatically generate multiple-choice, short-answer, and essay questions with various difficulty levels.',
    ),
    _FeatureItem(
      icon: Icons.analytics_outlined,
      color: AppColors.warningText,
      title: 'Auto-Grading & Analytics',
      desc: 'Instant grading for objective questions and AI-assisted grading for subjective answers with detailed rubrics.',
    ),
    const _FeatureItem(
      icon: Icons.recommend_outlined,
      color: AppColors.successDot,
      title: 'Personalized Recommendations',
      desc: 'The system identifies knowledge gaps and recommends specific study materials to each student.',
    ),
    const _FeatureItem(
      icon: Icons.support_agent_outlined,
      color: Color(0xFF06B6D4),
      title: 'AI Chatbot Assistant',
      desc: 'A dedicated AI tutor that answers student queries 24/7 based strictly on the uploaded course materials.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    final rows = <Widget>[];
    for (var i = 0; i < _features.length; i += columns) {
      final rowItems = _features.sublist(
          i, i + columns > _features.length ? _features.length : i + columns,);
      rows.add(Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var j = 0; j < rowItems.length; j++) ...[
            if (j > 0) const SizedBox(width: 20),
            Expanded(child: _FeatureCard(item: rowItems[j])),
          ],
          // Fill remaining slots if last row is partial
          for (var k = rowItems.length; k < columns; k++) ...[
            const SizedBox(width: 20),
            if (k == columns - 1)
              Expanded(child: _ExploreCta(onTap: onExplore))
            else
              const Expanded(child: SizedBox()),
          ],
        ],
      ),);
      rows.add(const SizedBox(height: 20));
    }
    // If features filled all cells evenly, add CTA as its own row
    if (_features.length % columns == 0) {
      rows.add(Row(
        children: [
          Expanded(child: _ExploreCta(onTap: onExplore)),
          for (var i = 1; i < columns; i++) ...[
            const SizedBox(width: 20),
            const Expanded(child: SizedBox()),
          ],
        ],
      ),);
    }
    return Column(children: rows);
  }
}

class _FeatureItem {
  final IconData icon;
  final Color color;
  final String title;
  final String desc;
  const _FeatureItem({required this.icon, required this.color, required this.title, required this.desc});
}

class _FeatureCard extends StatelessWidget {
  final _FeatureItem item;
  const _FeatureCard({required this.item});

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: item.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(item.icon, size: 20, color: item.color),
          ),
          const SizedBox(height: 12),
          Text(
            item.title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textTitle,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            item.desc,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textGray,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExploreCta extends StatelessWidget {
  final VoidCallback onTap;
  const _ExploreCta({required this.onTap});

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.infoBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.infoBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: onTap,
            child: const Text(
              'Explore the Platform',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
                decoration: TextDecoration.underline,
                decorationColor: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Discover all features by signing up for a demo.',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textGray,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: onTap,
            child: const Text(
              'View Full Feature List',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
                decoration: TextDecoration.underline,
                decorationColor: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 5. Workflow steps
// ─────────────────────────────────────────────────────────────────────────────

class _WorkflowSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    const steps = [
      _Step(n: 1, label: 'Upload',     desc: 'Add course materials, PDFs, slides & lecture notes'),
      _Step(n: 2, label: 'Processing', desc: 'AI analyzes and structures your content automatically'),
      _Step(n: 3, label: 'Review',     desc: 'Instructor reviews AI-suggested questions'),
      _Step(n: 4, label: 'Assess',     desc: 'Students take their personalized assessments'),
      _Step(n: 5, label: 'Analyze',    desc: 'System generates detailed analytics reports'),
    ];

    return Container(
      color: AppColors.surfaceBg,
      padding: const EdgeInsets.symmetric(vertical: 72, horizontal: 40),
      child: Column(
        children: [
          Text(
            'Seamless Workflow Integration',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: AppColors.textTitle,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'From raw material to graded assessment, in five simple steps.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: AppColors.textGray),
          ),
          const SizedBox(height: 56),
          LayoutBuilder(builder: (_, c) {
            if (c.maxWidth > 700) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: steps.expand((s) sync* {
                  if (s.n > 1) {
                    yield Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 22),
                        child: Container(
                          height: 2,
                          color: AppColors.borderSoft,
                        ),
                      ),
                    );
                  }
                  yield _StepCard(step: s);
                }).toList(),
              );
            }
            return Column(
              children: steps
                  .map((s) => Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: _StepCard(step: s),
                      ),)
                  .toList(),
            );
          },),
        ],
      ),
    );
  }
}

class _Step {
  final int n;
  final String label;
  final String desc;
  const _Step({required this.n, required this.label, required this.desc});
}

class _StepCard extends StatelessWidget {
  final _Step step;
  const _StepCard({required this.step});

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return SizedBox(
      width: 100,
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              '${step.n}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            step.label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textTitle,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            step.desc,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11.5,
              color: AppColors.textMuted,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 6. Portals section
// ─────────────────────────────────────────────────────────────────────────────

class _PortalsSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    final w = MediaQuery.sizeOf(context).width;
    final isMobile = w < 800;

    return Container(
      color: AppColors.cardBg,
      padding: EdgeInsets.symmetric(
          vertical: 72, horizontal: isMobile ? 24 : 80,),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [_PortalsText(), const SizedBox(height: 32), _PortalsMockup()],
            )
          : Row(
              children: [
                Expanded(child: _PortalsText()),
                const SizedBox(width: 60),
                Expanded(child: _PortalsMockup()),
              ],
            ),
    );
  }
}

class _PortalsText extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Comprehensive Portals for Every Role',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: AppColors.textTitle,
            height: 1.25,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Each user type gets a dedicated interface optimized for their specific tasks and responsibilities.',
          style: TextStyle(fontSize: 14, color: AppColors.textGray, height: 1.6),
        ),
        const SizedBox(height: 28),
        const _PortalRow(
          icon: Icons.menu_book_outlined,
          title: 'Instructor Portal',
          desc: 'The command center for course management. Upload content, review AI suggestions, release assignments, and view class-wide analytics.',
        ),
        const SizedBox(height: 16),
        const _PortalRow(
          icon: Icons.person_outline_rounded,
          title: 'Student Portal',
          desc: 'A clean, distraction-free environment for taking assessments, reviewing past performance, and accessing AI study aids.',
        ),
        const SizedBox(height: 16),
        const _PortalRow(
          icon: Icons.admin_panel_settings_outlined,
          title: 'Admin Portal',
          desc: 'Organization-level controls for managing users, departments, billing, and system-wide configurations.',
        ),
      ],
    );
  }
}

class _PortalRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String desc;
  const _PortalRow({required this.icon, required this.title, required this.desc});

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.primarySoft,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: AppColors.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textTitle,),),
              const SizedBox(height: 3),
              Text(desc,
                  style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textGray,
                      height: 1.5,),),
            ],
          ),
        ),
      ],
    );
  }
}

class _PortalsMockup extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Container(
      height: 300,
      decoration: BoxDecoration(
        color: AppColors.textTitle,
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Teal wave at bottom
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 80,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x000F172A), Color(0xFF0E7490)],
                ),
              ),
            ),
          ),
          // Center card
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.cardBg.withValues(alpha: 0.15)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.hub_outlined,
                      size: 36, color: Colors.white.withValues(alpha: 0.8),),
                  const SizedBox(height: 10),
                  const Text(
                    'Unified Learning Ecosystem',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 7. Stat bar
// ─────────────────────────────────────────────────────────────────────────────

class _StatsBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    const stats = [
      _Stat('Saves Time',
          'Instructors save hours weekly on grading and question creation.',),
      _Stat('Better Outcomes',
          'Instant feedback loops help students learn from mistakes faster.',),
      _Stat('Fair Assessment',
          'Standardized, objective grading eliminates unconscious bias.',),
      _Stat('Scalable',
          'Effortlessly manage classes of 15 or 10,000 students.',),
    ];

    return Container(
      color: AppColors.surfaceBg,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 40),
      child: LayoutBuilder(builder: (_, c) {
        if (c.maxWidth > 700) {
          return Row(
            children: stats.expand((s) sync* {
              if (s != stats.first) {
                yield Container(
                    width: 1, height: 48, color: AppColors.border,
                    margin: const EdgeInsets.symmetric(horizontal: 20),);
              }
              yield Expanded(child: _StatChip(stat: s));
            }).toList(),
          );
        }
        return Column(
          children: stats.map((s) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _StatChip(stat: s),
          ),).toList(),
        );
      },),
    );
  }
}

class _Stat {
  final String title;
  final String desc;
  const _Stat(this.title, this.desc);
}

class _StatChip extends StatelessWidget {
  final _Stat stat;
  const _StatChip({required this.stat});

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(stat.title,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.textTitle,),),
        const SizedBox(height: 4),
        Text(stat.desc,
            style: TextStyle(
                fontSize: 12, color: AppColors.textMuted, height: 1.4,),),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 8. CTA banner
// ─────────────────────────────────────────────────────────────────────────────

class _CtaBanner extends StatelessWidget {
  final VoidCallback onSignUp;
  final VoidCallback onLogin;
  const _CtaBanner({required this.onSignUp, required this.onLogin});

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Container(
      color: AppColors.primary,
      padding: const EdgeInsets.symmetric(vertical: 72, horizontal: 40),
      child: Column(
        children: [
          const Text(
            'Transform Learning with AI',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Join the institutions that are already modernising their educational\ninfrastructure with Smart Study Companion.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.white70,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 36),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              ElevatedButton(
                onPressed: onSignUp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.cardBg,
                  foregroundColor: AppColors.primary,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 28, vertical: 14,),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),),
                ),
                child: const Text('Sign Up',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),),
              ),
              OutlinedButton(
                onPressed: onLogin,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white60, width: 1.5),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 28, vertical: 14,),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),),
                ),
                child: const Text('Login',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 9. Footer
// ─────────────────────────────────────────────────────────────────────────────

class _Footer extends StatelessWidget {
  final VoidCallback onLogin;
  final VoidCallback onSignUp;
  const _Footer({required this.onLogin, required this.onSignUp});

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Container(
      color: AppColors.cardBg,
      padding: const EdgeInsets.fromLTRB(40, 52, 40, 28),
      child: Column(
        children: [
          LayoutBuilder(builder: (_, c) {
            if (c.maxWidth > 700) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Brand col
                  SizedBox(
                    width: 200,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Image.asset('assets/logo.webp', height: 22, cacheWidth: (22 * MediaQuery.of(context).devicePixelRatio).round()),
                          const SizedBox(width: 6),
                          Text('Learnova',
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textTitle,),),
                        ],),
                        const SizedBox(height: 10),
                        Text(
                          'Empowering education through fast, intelligent, flexible, scalable, and secure tools.',
                          style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                              height: 1.5,),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 40),
                  Expanded(child: _FooterLinks()),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Image.asset('assets/logo.webp', height: 22, cacheWidth: (22 * MediaQuery.of(context).devicePixelRatio).round()),
                  const SizedBox(width: 6),
                  Text('Learnova',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textTitle,),),
                ],),
                const SizedBox(height: 24),
                _FooterLinks(),
              ],
            );
          },),
          const SizedBox(height: 36),
          Divider(color: AppColors.border),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                '© 2025 Learnova. All rights reserved.',
                style: TextStyle(fontSize: 12, color: AppColors.textHint),
              ),
              const Spacer(),
              // Social icons
              Icon(Icons.language, size: 18, color: AppColors.textHint),
              const SizedBox(width: 12),
              Icon(Icons.send, size: 18, color: AppColors.textHint),
            ],
          ),
        ],
      ),
    );
  }
}

class _FooterLinks extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return LayoutBuilder(builder: (_, c) {
      if (c.maxWidth > 500) {
        return const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _FooterCol(title: 'Platform', links: ['Features', 'Pricing', 'For Institutions'])),
            Expanded(child: _FooterCol(title: 'Company', links: ['About Us', 'Contacts', 'Blog'])),
            Expanded(child: _FooterCol(title: 'Legal', links: ['Privacy Policy', 'Terms of Service', 'Security'])),
          ],
        );
      }
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FooterCol(title: 'Platform', links: ['Features', 'Pricing', 'For Institutions']),
          SizedBox(height: 20),
          _FooterCol(title: 'Company', links: ['About Us', 'Contacts', 'Blog']),
          SizedBox(height: 20),
          _FooterCol(title: 'Legal', links: ['Privacy Policy', 'Terms of Service', 'Security']),
        ],
      );
    },);
  }
}

class _FooterCol extends StatelessWidget {
  final String title;
  final List<String> links;
  const _FooterCol({required this.title, required this.links});

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textTitle,),),
        const SizedBox(height: 12),
        ...links.map((l) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(l,
                  style: TextStyle(
                      fontSize: 13, color: AppColors.textMuted,),),
            ),),
      ],
    );
  }
}
