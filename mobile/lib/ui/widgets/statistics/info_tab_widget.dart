import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/theme.dart';

class InfoTabWidget extends StatelessWidget {
  const InfoTabWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        _TopStatsGrid(),
        SizedBox(height: 16),
        _AbitudiniChiaveSection(),
        SizedBox(height: 16),
        _AnalisiCorrelazioniSection(),
        SizedBox(height: 16),
        _CorrelazioniPositiveSection(),
        SizedBox(height: 16),
        _CorrelazioniNegativeSection(),
        SizedBox(height: 32),
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
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.8,
      children: const [
        _StatCard(
          icon: LucideIcons.target,
          title: 'Completamento',
          value: '44%',
          subtitle: 'globale',
        ),
        _StatCard(
          icon: LucideIcons.flame,
          title: 'Miglior Serie',
          value: '48',
          subtitle: 'giorni',
          iconColor: Color(0xFFF97316),
        ),
        _StatCard(
          icon: LucideIcons.trophy,
          title: 'Top Performer',
          value: 'Caviglie',
          subtitle: '86% completamento',
          iconColor: Color(0xFFEAB308),
        ),
        _StatCard(
          icon: LucideIcons.triangleAlert,
          title: 'Giorno Peggiore',
          value: 'sabato',
          subtitle: 'Focus richiesto',
          iconColor: Color(0xFFEAB308),
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
  final Color? iconColor;

  const _StatCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.subtitle,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      clipBehavior: Clip.hardEdge,
      child: Stack(
        children: [
          Positioned(
            right: -10,
            bottom: -10,
            child: Icon(
              icon,
              size: 70,
              color: (iconColor ?? AppColors.mutedForeground).withValues(alpha: 0.08),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 14, color: AppColors.mutedForeground),
                    const SizedBox(width: 6),
                    Text(
                      title,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.mutedForeground,
                      ),
                    ),
                  ],
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      value,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.foreground,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        subtitle,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 10,
                          color: AppColors.mutedForeground,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
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
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Abitudini Chiave',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.foreground,
                        ),
                      ),
                      Text(
                        'Abitudini che influenzano positivamente molte altre',
                        style: TextStyle(
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
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
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
                SizedBox(width: 12),
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
                SizedBox(width: 12),
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
                      text: const TextSpan(
                        style: TextStyle(fontFamily: 'Inter', fontSize: 10, color: AppColors.mutedForeground, height: 1.4),
                        children: [
                          TextSpan(text: 'Suggerimento: ', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.foreground)),
                          TextSpan(text: 'Le abitudini chiave hanno un effetto "domino" su altre. Concentrati a mantenerle costanti per migliorare l\'intero sistema delle tue abitudini.'),
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
      width: 260,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderHover, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title, style: const TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.foreground)),
              ),
              const Icon(LucideIcons.crown, size: 16, color: Color(0xFF10B981)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: const Color(0xFF10B981).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
                child: const Text('Alto Impatto', style: TextStyle(fontFamily: 'Inter', fontSize: 9, fontWeight: FontWeight.w600, color: Color(0xFF10B981))),
              ),
              const SizedBox(width: 8),
              Text('${correlations.length + extraConnections} connessioni', style: const TextStyle(fontFamily: 'Inter', fontSize: 10, color: AppColors.mutedForeground)),
            ],
          ),
          const SizedBox(height: 12),
          ...correlations.map((c) {
            final isPositive = c.value.startsWith('+');
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(c.key, style: const TextStyle(fontFamily: 'Inter', fontSize: 11, color: AppColors.mutedForeground)),
                  Text(c.value, style: TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.w600, color: isPositive ? const Color(0xFF10B981) : AppColors.mutedForeground)),
                ],
              ),
            );
          }),
          const SizedBox(height: 4),
          Center(child: Text('+$extraConnections altre connessioni', style: const TextStyle(fontFamily: 'Inter', fontSize: 9, color: AppColors.mutedForeground))),
          const SizedBox(height: 12),
          Container(height: 1, color: AppColors.border),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  Icon(LucideIcons.trendingUp, size: 12, color: AppColors.mutedForeground),
                  SizedBox(width: 4),
                  Text('Media', style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: AppColors.mutedForeground)),
                ],
              ),
              Text(media, style: const TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.foreground)),
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
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Analisi Correlazioni', style: TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.foreground)),
                  Text('Pattern tra le tue abitudini', style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: AppColors.mutedForeground)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: const [
              Expanded(child: _CorrelazioneStatBox(title: 'Coppie Analizzate', value: '16')),
              SizedBox(width: 8),
              Expanded(child: _CorrelazioneStatBox(title: 'Correlazione Media', value: '+0.52')),
              SizedBox(width: 8),
              Expanded(child: _CorrelazioneStatBox(title: 'Positive', value: '5', valueColor: Color(0xFF10B981))),
              SizedBox(width: 8),
              Expanded(child: _CorrelazioneStatBox(title: 'Negative', value: '3', valueColor: Color(0xFFEF4444))),
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
                    children: const [
                      Text('Abitudini Isolate', style: TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFEAB308))),
                      SizedBox(height: 2),
                      Text('5 abitudini non hanno correlazioni significative con le altre. Potrebbero essere indipendenti o necessitare di più dati.', style: TextStyle(fontFamily: 'Inter', fontSize: 10, color: AppColors.mutedForeground, height: 1.4)),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Row(
          children: [
            Icon(LucideIcons.heart, size: 16, color: Color(0xFF10B981)),
            SizedBox(width: 8),
            Text('Correlazioni Positive', style: TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.foreground)),
          ],
        ),
        SizedBox(height: 12),
        _CorrelazioneDetailCard(
          tag: 'Correlazione Positiva - Forte',
          tagColor: Color(0xFF10B981),
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
          tagColor: Color(0xFF10B981),
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
          tagColor: Color(0xFF10B981),
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
          tagColor: Color(0xFF10B981),
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
          tagColor: Color(0xFF10B981),
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
            Icon(LucideIcons.triangleAlert, size: 16, color: Color(0xFFEAB308)),
            SizedBox(width: 8),
            Text('Correlazioni Negative', style: TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.foreground)),
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
