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
        const _AbitudiniChiaveSection(),
        const SizedBox(height: 16),
        const _AnalisiCorrelazioniSection(),
        const SizedBox(height: 16),
        const _CorrelazioniPositiveSection(),
        const SizedBox(height: 16),
        const _CorrelazioniNegativeSection(),
        const SizedBox(height: 16),
        const _AttivitaRecenteSection(),
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


class _AbitudiniChiaveSection extends StatelessWidget {
  const _AbitudiniChiaveSection();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAB308).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(LucideIcons.crown, size: 18, color: Color(0xFFEAB308)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.l10n.translate('Abitudini Chiave'),
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.foreground,
                        ),
                      ),
                      Text(
                        context.l10n.translate('Abitudini che influenzano positivamente molte altre'),
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          color: AppColors.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: const [
                _AbitudineChiaveCard(
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
                SizedBox(height: 12),
                _AbitudineChiaveCard(
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
                SizedBox(height: 12),
                _AbitudineChiaveCard(
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
              ],
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.muted,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(LucideIcons.lightbulb, size: 14, color: AppColors.mutedForeground),
                  const SizedBox(width: 8),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: const TextStyle(fontFamily: 'Inter', fontSize: 10, color: AppColors.mutedForeground, height: 1.4),
                        children: [
                          TextSpan(text: '${context.l10n.translate('Suggerimento')}: ', style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.foreground)),
                          TextSpan(text: context.l10n.translate('Le abitudini chiave hanno un effetto "domino".')),
                        ],
                      ),
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

class _AbitudineChiaveCard extends StatefulWidget {
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
  State<_AbitudineChiaveCard> createState() => _AbitudineChiaveCardState();
}

class _AbitudineChiaveCardState extends State<_AbitudineChiaveCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _isExpanded = !_isExpanded),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _isExpanded ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.3) : AppColors.border,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
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
                    color: widget.dotColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: widget.dotColor.withValues(alpha: 0.4), blurRadius: 4, spreadRadius: 1),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.title,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.foreground,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
                AnimatedRotation(
                  turns: _isExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 300),
                  child: const Icon(LucideIcons.chevronDown, size: 18, color: AppColors.mutedForeground),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
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
                      '${widget.correlations.length + widget.extraConnections} ${context.l10n.translate('connessioni')}',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppColors.mutedForeground,
                      ),
                    ),
                  ],
                ),
                Text(
                  widget.media,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: widget.media.startsWith('+') ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                  ),
                ),
              ],
            ),
            
            ClipRect(
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                alignment: Alignment.topCenter,
                heightFactor: _isExpanded ? 1.0 : 0.0,
                child: Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Divider(color: AppColors.border, height: 1),
                      const SizedBox(height: 16),
                      ...widget.correlations.map((c) {
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
                          '+${widget.extraConnections} altre connessioni',
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 10,
                            color: AppColors.mutedForeground,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
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

class _CorrelazioniPositiveSection extends StatelessWidget {
  const _CorrelazioniPositiveSection();

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
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
        const SizedBox(height: 12),
        _CorrelazioneDetailCard(
          tag: 'Correlazione Positiva - Forte',
          tagColor: const Color(0xFF10B981),
          habit1: '20 Flessioni 1',
          habit1Color: Color(0xFFEF4444),
          habit2: '20 Flessioni 2',
          habit2Color: Color(0xFFEF4444),
          coef: '+0.92',
          cooccorrenza: '94%',
          giorni: '102',
          desc: 'Quando completi "20 Flessioni 1", hai una probabilità del 94% di completare anche "20 Flessioni 2". Considera di farle insieme come routine consolidata.',
        ),
        SizedBox(height: 8),
        _CorrelazioneDetailCard(
          tag: 'Correlazione Positiva - Forte',
          tagColor: const Color(0xFF10B981),
          habit1: '20 Flessioni 2',
          habit1Color: Color(0xFFEF4444),
          habit2: '20 Flessioni 3',
          habit2Color: Color(0xFFEF4444),
          coef: '+0.84',
          cooccorrenza: '87%',
          giorni: '99',
          desc: 'Quando completi "20 Flessioni 2", hai una probabilità del 87% di completare anche "20 Flessioni 3". Considera di farle insieme come routine consolidata.',
        ),
        SizedBox(height: 8),
        _CorrelazioneDetailCard(
          tag: 'Correlazione Positiva - Forte',
          tagColor: const Color(0xFF10B981),
          habit1: '20 Flessioni 3',
          habit1Color: Color(0xFFEF4444),
          habit2: '20 Flessioni 4',
          habit2Color: Color(0xFFEF4444),
          coef: '+0.79',
          cooccorrenza: '71%',
          giorni: '71',
          desc: 'Quando completi "20 Flessioni 3", hai una probabilità del 71% di completare anche "20 Flessioni 4". Considera di farle insieme come routine consolidata.',
        ),
        SizedBox(height: 8),
        _CorrelazioneDetailCard(
          tag: 'Correlazione Positiva - Forte',
          tagColor: const Color(0xFF10B981),
          habit1: '20 Flessioni 1',
          habit1Color: Color(0xFFEF4444),
          habit2: '20 Flessioni 3',
          habit2Color: Color(0xFFEF4444),
          coef: '+0.77',
          cooccorrenza: '81%',
          giorni: '99',
          desc: 'Quando completi "20 Flessioni 1", hai una probabilità del 81% di completare anche "20 Flessioni 3". Considera di farle insieme come routine consolidata.',
        ),
        SizedBox(height: 8),
        _CorrelazioneDetailCard(
          tag: 'Correlazione Positiva - Forte',
          tagColor: const Color(0xFF10B981),
          habit1: '20 Flessioni 2',
          habit1Color: Color(0xFFEF4444),
          habit2: '20 Flessioni 4',
          habit2Color: Color(0xFFEF4444),
          coef: '+0.70',
          cooccorrenza: '61%',
          giorni: '71',
          desc: 'Quando completi "20 Flessioni 2", hai una probabilità del 61% di completare anche "20 Flessioni 4". Considera di farle insieme come routine consolidata.',
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

class _CorrelazioniNegativeSection extends StatelessWidget {
  const _CorrelazioniNegativeSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Row(
          children: [
            const Icon(LucideIcons.triangleAlert, size: 16, color: Color(0xFFEAB308)),
            const SizedBox(width: 8),
            const Text('Correlazioni Negative', style: TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.foreground)),
          ],
        ),
        SizedBox(height: 4),
        Text('Queste abitudini tendono a non essere completate insieme.', style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: AppColors.mutedForeground)),
        SizedBox(height: 12),
        _CorrelazioneDetailCard(
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
      ],
    );
  }
}

class _AttivitaRecenteSection extends StatelessWidget {
  const _AttivitaRecenteSection();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: AppColors.mutedForeground,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Attività Recente',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.foreground,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border, width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Costanza',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.foreground,
                  ),
                ),
                const SizedBox(height: 24),
                _buildActivityGrid(),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    const Text('Meno', style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppColors.mutedForeground)),
                    const SizedBox(width: 8),
                    _buildDot(0),
                    const SizedBox(width: 4),
                    _buildDot(1),
                    const SizedBox(width: 4),
                    _buildDot(2),
                    const SizedBox(width: 4),
                    _buildDot(3),
                    const SizedBox(width: 4),
                    _buildDot(4),
                    const SizedBox(width: 8),
                    const Text('Più', style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppColors.mutedForeground)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDot(int intensity) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: _getColor(intensity),
        shape: BoxShape.circle,
      ),
    );
  }

  Color _getColor(int intensity) {
    switch (intensity) {
      case 0: return const Color(0xFF18181B);
      case 1: return const Color(0xFF3F3F46);
      case 2: return const Color(0xFF71717A);
      case 3: return const Color(0xFFA1A1AA);
      case 4: return const Color(0xFFFFFFFF);
      default: return const Color(0xFF18181B);
    }
  }

  Widget _buildActivityGrid() {
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
                      color: _getColor(intensity),
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
