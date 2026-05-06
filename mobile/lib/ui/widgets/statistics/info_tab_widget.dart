import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/theme.dart';
import '../../../core/localization.dart';

class InfoTabWidget extends StatelessWidget {
  const InfoTabWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _TopStatsGrid(),
        const SizedBox(height: 16),
        const _AttivitaRecenteSection(),
        const SizedBox(height: 16),
        const _AbitudiniChiaveSection(),
        const SizedBox(height: 16),
        const _AnalisiCorrelazioniSection(),
        const SizedBox(height: 16),
        const _CorrelazioniPositiveSection(),
        const SizedBox(height: 16),
        const _CorrelazioniNegativeSection(),
        const SizedBox(height: 32),
      ],

    );
  }
}

class _TopStatsGrid extends StatelessWidget {
  const _TopStatsGrid();

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.6, // Adjusted for better text fit
      children: [
        _StatCard(
          icon: LucideIcons.target,
          title: context.l10n.translate('Completamento'),
          value: '44%',
           subtitle: context.l10n.translate('Globale'),
          accentColor: Theme.of(context).colorScheme.primary,
        ),
        _StatCard(
          icon: LucideIcons.flame,
          title: context.l10n.translate('Miglior Serie'),
          value: '48',
          subtitle: context.l10n.translate('Giorni'),
          accentColor: Theme.of(context).colorScheme.primary,
        ),
        _StatCard(
          icon: LucideIcons.trophy,
          title: context.l10n.translate('Top Performer'),
          value: 'Caviglie',
          subtitle: '86% Rate',
          accentColor: Theme.of(context).colorScheme.primary,
        ),
        _StatCard(
          icon: LucideIcons.triangleAlert,
          title: context.l10n.translate('Giorno Critico'),
          value: context.l10n.translate('sat'),
          subtitle: context.l10n.translate('Focus richiesto'),
          accentColor: const Color(0xFFEF4444),
        ),
      ],

    );
  }
}


class _StatCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final String subtitle;
  final Color accentColor;

  const _StatCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20), // More rounded
        border: Border.all(color: AppColors.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.hardEdge,
      child: Stack(
        children: [
          // Background Glow
          Positioned(
            right: -15,
            top: -15,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 14, color: accentColor),
                    const SizedBox(width: 8),
                    Text(
                      title,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.mutedForeground,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: AppColors.foreground,
                        letterSpacing: -1,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: AppColors.mutedForeground,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


class _AbitudiniChiaveSection extends StatefulWidget {
  const _AbitudiniChiaveSection();

  @override
  State<_AbitudiniChiaveSection> createState() => _AbitudiniChiaveSectionState();
}

class _AbitudiniChiaveSectionState extends State<_AbitudiniChiaveSection> {
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.9);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> cards = [
      const _AbitudineChiaveCard(
        title: '1 YT-Video',
        dotColor: Color(0xFFEF4444),
        correlations: [
          MapEntry('Caviglia', '-0.43'),
          MapEntry('20 Flessioni 4', '-0.42'),
          MapEntry('20 Flessioni 3', '-0.38'),
          MapEntry('20 Flessioni 2', '-0.35'),
        ],
        extraConnections: 2,
        media: '-0.13',
      ),
      const _AbitudineChiaveCard(
        title: '20 Flessioni 1',
        dotColor: Color(0xFFEF4444),
        correlations: [
          MapEntry('20 Flessioni 2', '+0.92'),
          MapEntry('20 Flessioni 3', '+0.77'),
          MapEntry('20 Flessioni 4', '+0.62'),
          MapEntry('Journaling', '+0.55'),
        ],
        extraConnections: 1,
        media: '+0.47',
      ),
      const _AbitudineChiaveCard(
        title: '20 Flessioni 2',
        dotColor: Color(0xFFEF4444),
        correlations: [
          MapEntry('20 Flessioni 1', '+0.92'),
          MapEntry('20 Flessioni 3', '+0.84'),
          MapEntry('20 Flessioni 4', '+0.70'),
          MapEntry('1 YT-Video', '-0.35'),
        ],
        extraConnections: 1,
        media: '+0.48',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(LucideIcons.crown, size: 16, color: Color(0xFFEAB308)),
            const SizedBox(width: 8),
            Text(context.l10n.translate('Abitudini Chiave'), style: const TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.foreground)),
          ],
        ),
        const SizedBox(height: 4),
        Text(context.l10n.translate('Abitudini che influenzano positivamente molte altre'), style: const TextStyle(fontFamily: 'Inter', fontSize: 11, color: AppColors.mutedForeground)),
        const SizedBox(height: 16),
        
        // Carousel
        SizedBox(
          height: 280, // Height for habit cards
          child: PageView.builder(
            controller: _pageController,
            itemCount: cards.length,
            onPageChanged: (index) => setState(() => _currentPage = index),
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: cards[index],
              );
            },
          ),
        ),
        
        const SizedBox(height: 12),
        
        // Pagination Dots
        Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(cards.length, (index) {
              final isActive = _currentPage == index;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: isActive ? 16 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: isActive 
                      ? const Color(0xFFEAB308)
                      : AppColors.mutedForeground.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}

class _AbitudineChiaveCard extends StatelessWidget {
  final String title;
  final Color dotColor;
  final List<MapEntry<String, String>> correlations;
  final int extraConnections;
  final String media;

  const _AbitudineChiaveCard({
    required this.title,
    required this.dotColor,
    required this.correlations,
    required this.extraConnections,
    required this.media,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      // width: 280, // Removed fixed width for PageView compatibility
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: dotColor.withValues(alpha: 0.4), blurRadius: 4, spreadRadius: 1),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.foreground,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              Icon(LucideIcons.crown, size: 18, color: Theme.of(context).colorScheme.primary),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  context.l10n.translate('Alto Impatto'),
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${correlations.length + extraConnections} ${context.l10n.translate('connessioni')}',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppColors.mutedForeground,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...correlations.map((c) {
            final isPositive = c.value.startsWith('+');
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    c.key,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: AppColors.mutedForeground,
                    ),
                  ),
                  Text(
                    c.value,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isPositive ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 8),
          Center(
            child: Text(
              '+$extraConnections altre connessioni',
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 10,
                color: AppColors.mutedForeground,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(LucideIcons.chartSpline, size: 14, color: AppColors.mutedForeground),
                  const SizedBox(width: 6),
                  Text(
                    context.l10n.translate('Media Impatto'),
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.mutedForeground,
                    ),
                  ),
                ],
              ),
              Text(
                media,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.foreground,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}


class _AnalisiCorrelazioniSection extends StatelessWidget {
  const _AnalisiCorrelazioniSection();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(LucideIcons.gitCommitVertical, size: 18, color: Color(0xFF3B82F6)),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.l10n.translate('Analisi Correlazioni'), style: const TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.foreground)),
                  Text(context.l10n.translate('Pattern tra le tue abitudini'), style: const TextStyle(fontFamily: 'Inter', fontSize: 11, color: AppColors.mutedForeground)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _CorrelazioneStatBox(title: context.l10n.translate('Coppie Analizzate'), value: '16')),
              const SizedBox(width: 8),
              Expanded(child: _CorrelazioneStatBox(title: context.l10n.translate('Correlazione Media'), value: '+0.52')),
              const SizedBox(width: 8),
              Expanded(child: _CorrelazioneStatBox(title: context.l10n.translate('Positive'), value: '5', valueColor: Theme.of(context).colorScheme.primary)),
              const SizedBox(width: 8),
              Expanded(child: _CorrelazioneStatBox(title: context.l10n.translate('Negative'), value: '3', valueColor: const Color(0xFFEF4444))),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFEAB308).withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFEAB308).withValues(alpha: 0.3), width: 1),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(LucideIcons.triangleAlert, size: 14, color: Color(0xFFEAB308)),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(context.l10n.translate('Abitudini Isolate'), style: const TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFEAB308))),
                      const SizedBox(height: 2),
                      Text(context.l10n.translate('Non hanno correlazioni significative.'), style: const TextStyle(fontFamily: 'Inter', fontSize: 10, color: AppColors.mutedForeground, height: 1.4)),
                    ],
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

class _CorrelazioneStatBox extends StatelessWidget {
  final String title;
  final String value;
  final Color? valueColor;

  const _CorrelazioneStatBox({required this.title, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(title, style: const TextStyle(fontFamily: 'Inter', fontSize: 9, color: AppColors.mutedForeground), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.w700, color: valueColor ?? AppColors.foreground)),
        ],
      ),
    );
  }
}

class _CorrelazioniPositiveSection extends StatefulWidget {
  const _CorrelazioniPositiveSection();

  @override
  State<_CorrelazioniPositiveSection> createState() => _CorrelazioniPositiveSectionState();
}

class _CorrelazioniPositiveSectionState extends State<_CorrelazioniPositiveSection> {
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.9);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> cards = [
      _CorrelazioneDetailCard(
        tag: 'Correlazione Positiva - Forte',
        tagColor: const Color(0xFF10B981),
        habit1: '20 Flessioni 1',
        habit1Color: const Color(0xFFEF4444),
        habit2: '20 Flessioni 2',
        habit2Color: const Color(0xFFEF4444),
        coef: '+0.92',
        cooccorrenza: '94%',
        giorni: '102',
        desc: 'Quando completi "20 Flessioni 1", hai una probabilità del 94% di completare anche "20 Flessioni 2". Considera di farle insieme come routine consolidata.',
      ),
      _CorrelazioneDetailCard(
        tag: 'Correlazione Positiva - Forte',
        tagColor: const Color(0xFF10B981),
        habit1: '20 Flessioni 2',
        habit1Color: const Color(0xFFEF4444),
        habit2: '20 Flessioni 3',
        habit2Color: const Color(0xFFEF4444),
        coef: '+0.84',
        cooccorrenza: '87%',
        giorni: '99',
        desc: 'Quando completi "20 Flessioni 2", hai una probabilità del 87% di completare anche "20 Flessioni 3". Considera di farle insieme come routine consolidata.',
      ),
      _CorrelazioneDetailCard(
        tag: 'Correlazione Positiva - Forte',
        tagColor: const Color(0xFF10B981),
        habit1: '20 Flessioni 3',
        habit1Color: const Color(0xFFEF4444),
        habit2: '20 Flessioni 4',
        habit2Color: const Color(0xFFEF4444),
        coef: '+0.79',
        cooccorrenza: '71%',
        giorni: '71',
        desc: 'Quando completi "20 Flessioni 3", hai una probabilità del 71% di completare anche "20 Flessioni 4". Considera di farle insieme come routine consolidata.',
      ),
      _CorrelazioneDetailCard(
        tag: 'Correlazione Positiva - Forte',
        tagColor: const Color(0xFF10B981),
        habit1: '20 Flessioni 1',
        habit1Color: const Color(0xFFEF4444),
        habit2: '20 Flessioni 3',
        habit2Color: const Color(0xFFEF4444),
        coef: '+0.77',
        cooccorrenza: '81%',
        giorni: '99',
        desc: 'Quando completi "20 Flessioni 1", hai una probabilità del 81% di completare anche "20 Flessioni 3". Considera di farle insieme come routine consolidata.',
      ),
      _CorrelazioneDetailCard(
        tag: 'Correlazione Positiva - Forte',
        tagColor: const Color(0xFF10B981),
        habit1: '20 Flessioni 2',
        habit1Color: const Color(0xFFEF4444),
        habit2: '20 Flessioni 4',
        habit2Color: const Color(0xFFEF4444),
        coef: '+0.70',
        cooccorrenza: '61%',
        giorni: '71',
        desc: 'Quando completi "20 Flessioni 2", hai una probabilità del 61% di completare anche "20 Flessioni 4". Considera di farle insieme come routine consolidata.',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(LucideIcons.heart, size: 16, color: Color(0xFF10B981)),
            const SizedBox(width: 8),
            Text(context.l10n.translate('Correlazioni Positive'), style: const TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.foreground)),
          ],
        ),
        const SizedBox(height: 16),
        
        // Carousel
        SizedBox(
          height: 190, // Adjusted for correlation cards
          child: PageView.builder(
            controller: _pageController,
            itemCount: cards.length,
            onPageChanged: (index) => setState(() => _currentPage = index),
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: cards[index],
              );
            },
          ),
        ),
        
        const SizedBox(height: 12),
        
        // Pagination Dots
        Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(cards.length, (index) {
              final isActive = _currentPage == index;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: isActive ? 16 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: isActive 
                      ? const Color(0xFF10B981)
                      : AppColors.mutedForeground.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}

class _CorrelazioneDetailCard extends StatelessWidget {
  final String tag;
  final Color tagColor;
  final String habit1;
  final Color habit1Color;
  final String habit2;
  final Color habit2Color;
  final String coef;
  final String cooccorrenza;
  final String giorni;
  final String desc;

  const _CorrelazioneDetailCard({
    required this.tag,
    required this.tagColor,
    required this.habit1,
    required this.habit1Color,
    required this.habit2,
    required this.habit2Color,
    required this.coef,
    required this.cooccorrenza,
    required this.giorni,
    required this.desc,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderHover, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: tagColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: tagColor.withValues(alpha: 0.3), width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.trendingUp, size: 10, color: tagColor),
                const SizedBox(width: 4),
                Text(tag, style: TextStyle(fontFamily: 'Inter', fontSize: 9, fontWeight: FontWeight.w600, color: tagColor)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(width: 8, height: 8, decoration: BoxDecoration(color: habit1Color, shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(habit1, style: const TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.foreground), overflow: TextOverflow.ellipsis)),
                  ],
                ),
              ),
              Icon(LucideIcons.link, size: 14, color: tagColor),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(width: 8, height: 8, decoration: BoxDecoration(color: habit2Color, shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(habit2, style: const TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.foreground), overflow: TextOverflow.ellipsis)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _DetailBox(title: 'Coefficiente', value: coef, valueColor: tagColor)),
              const SizedBox(width: 8),
              Expanded(child: _DetailBox(title: 'Co-occorrenza', value: cooccorrenza)),
              const SizedBox(width: 8),
              Expanded(child: _DetailBox(title: 'Giorni', value: giorni)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(LucideIcons.chevronRight, size: 14, color: AppColors.mutedForeground),
              const SizedBox(width: 6),
              Expanded(child: Text(desc, style: const TextStyle(fontFamily: 'Inter', fontSize: 10, color: AppColors.mutedForeground, height: 1.4))),
            ],
          ),
        ],
      ),
    );
  }
}

class _DetailBox extends StatelessWidget {
  final String title;
  final String value;
  final Color? valueColor;

  const _DetailBox({required this.title, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(title, style: const TextStyle(fontFamily: 'Inter', fontSize: 9, color: AppColors.mutedForeground)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w700, color: valueColor ?? AppColors.foreground)),
        ],
      ),
    );
  }
}

class _CorrelazioniNegativeSection extends StatefulWidget {
  const _CorrelazioniNegativeSection();

  @override
  State<_CorrelazioniNegativeSection> createState() => _CorrelazioniNegativeSectionState();
}

class _CorrelazioniNegativeSectionState extends State<_CorrelazioniNegativeSection> {
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.9);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> cards = [
      const _CorrelazioneDetailCard(
        tag: 'Correlazione Negativa - Moderata',
        tagColor: Color(0xFFEF4444),
        habit1: '1 YT-Video',
        habit1Color: Color(0xFFEF4444),
        habit2: 'Caviglia',
        habit2Color: Color(0xFFF59E0B),
        coef: '-0.43',
        cooccorrenza: '15%',
        giorni: '80',
        desc: 'Quando completi "1 YT-Video", è raro che completi anche "Caviglia".',
      ),
      // Adding a dummy card for demonstration if there's only one, 
      // but normally it would be a dynamic list.
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(LucideIcons.triangleAlert, size: 16, color: Color(0xFFEAB308)),
            const SizedBox(width: 8),
            Text(context.l10n.translate('Correlazioni Negative'), style: const TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.foreground)),
          ],
        ),
        const SizedBox(height: 4),
        Text(context.l10n.translate('Queste abitudini tendono a non essere completate insieme.'), style: const TextStyle(fontFamily: 'Inter', fontSize: 11, color: AppColors.mutedForeground)),
        const SizedBox(height: 16),
        
        // Carousel
        SizedBox(
          height: 190,
          child: PageView.builder(
            controller: _pageController,
            itemCount: cards.length,
            onPageChanged: (index) => setState(() => _currentPage = index),
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: cards[index],
              );
            },
          ),
        ),
        
        const SizedBox(height: 12),
        
        // Pagination Dots (only show if more than 1 card)
        if (cards.length > 1)
          Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(cards.length, (index) {
                final isActive = _currentPage == index;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: isActive ? 16 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: isActive 
                        ? const Color(0xFFEF4444)
                        : AppColors.mutedForeground.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
            ),
          ),
      ],
    );
  }
}

class _AttivitaRecenteSection extends StatelessWidget {
  const _AttivitaRecenteSection();

  @override
  Widget build(BuildContext context) {
    final accentColor = Theme.of(context).colorScheme.primary;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(LucideIcons.calendarRange, size: 18, color: accentColor),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.l10n.translate('Attività Recente'),
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.foreground,
                          letterSpacing: -0.5,
                        ),
                      ),
                      Text(
                        context.l10n.translate('La tua costanza negli ultimi mesi'),
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          color: AppColors.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Activity Grid
          Center(
            child: _buildActivityGrid(accentColor),
          ),
          
          const SizedBox(height: 20),
          
          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                context.l10n.translate('Meno'),
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: AppColors.mutedForeground,
                ),
              ),
              const SizedBox(width: 8),
              _buildDot(0, accentColor),
              const SizedBox(width: 4),
              _buildDot(1, accentColor),
              const SizedBox(width: 4),
              _buildDot(2, accentColor),
              const SizedBox(width: 4),
              _buildDot(3, accentColor),
              const SizedBox(width: 4),
              _buildDot(4, accentColor),
              const SizedBox(width: 8),
              Text(
                context.l10n.translate('Più'),
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: AppColors.mutedForeground,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDot(int intensity, Color accentColor) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: _getColor(intensity, accentColor),
        shape: BoxShape.circle,
      ),
    );
  }

  Color _getColor(int intensity, Color accentColor) {
    switch (intensity) {
      case 0: return AppColors.border.withValues(alpha: 0.3);
      case 1: return accentColor.withValues(alpha: 0.2);
      case 2: return accentColor.withValues(alpha: 0.4);
      case 3: return accentColor.withValues(alpha: 0.7);
      case 4: return accentColor;
      default: return AppColors.border.withValues(alpha: 0.3);
    }
  }

  Widget _buildActivityGrid(Color accentColor) {
    final pattern = [
      [2,3,4,4,3,3,3,4,4,4,3,3,3,4,3,3,3,4],
      [3,3,3,3,2,3,3,3,2,3,2,3,3,2,3,2,4,4],
      [2,2,2,3,3,3,2,3,3,3,3,2,4,4,4,3,3,3],
      [2,1,2,3,3,1,1,2,3,1,0,3,2,3,3,2,2,2],
      [3,3,2,0,2,3,3,2,3,2,1,1,2,2,2,2,2,2],
      [-1,-1,-1,3,3,3,3,2,3,2,3,3,3,-1,-1,-1,-1,-1],
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(pattern[0].length, (colIndex) {
          return Padding(
            padding: EdgeInsets.only(right: colIndex == pattern[0].length - 1 ? 0 : 6.0),
            child: Column(
              children: List.generate(pattern.length, (rowIndex) {
                final intensity = pattern[rowIndex][colIndex];
                if (intensity == -1) {
                  return const SizedBox(width: 14, height: 20); 
                }
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6.0),
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: _getColor(intensity, accentColor),
                      shape: BoxShape.circle,
                    ),
                  ),
                );
              }),
            ),
          );
        }),
      ),
    );
  }
}
