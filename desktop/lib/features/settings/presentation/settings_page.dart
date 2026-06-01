import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:evolve_desktop/shared/widgets/desktop_page.dart';
import 'package:evolve_desktop/shared/widgets/evolve_panel.dart';
import 'package:flutter/material.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _launchAtLogin = false;
  bool _desktopNotifications = true;
  bool _weeklyReport = true;
  bool _reduceAnimations = false;

  @override
  Widget build(BuildContext context) {
    return DesktopPage(
      title: 'Impostazioni',
      subtitle: 'Configura il comportamento dell\'applicazione desktop.',
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: Column(
          children: [
            EvolvePanel(
              child: Column(
                children: [
                  const SectionHeading(
                    title: 'Applicazione desktop',
                    subtitle: 'Preferenze locali per questo computer',
                  ),
                  const SizedBox(height: 12),
                  _SettingSwitch(
                    label: 'Apri Evolve all\'accesso',
                    detail:
                        'Avvia automaticamente l\'app quando accedi al computer.',
                    value: _launchAtLogin,
                    onChanged: (value) =>
                        setState(() => _launchAtLogin = value),
                  ),
                  _SettingSwitch(
                    label: 'Notifiche desktop',
                    detail:
                        'Mostra promemoria e riepiloghi nel centro notifiche.',
                    value: _desktopNotifications,
                    onChanged: (value) =>
                        setState(() => _desktopNotifications = value),
                  ),
                  _SettingSwitch(
                    label: 'Report settimanale',
                    detail:
                        'Prepara ogni domenica una sintesi dei tuoi progressi.',
                    value: _weeklyReport,
                    onChanged: (value) => setState(() => _weeklyReport = value),
                  ),
                  _SettingSwitch(
                    label: 'Riduci animazioni',
                    detail:
                        'Limita le transizioni per una maggiore accessibilita.',
                    value: _reduceAnimations,
                    onChanged: (value) =>
                        setState(() => _reduceAnimations = value),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            const EvolvePanel(
              child: Column(
                children: [
                  SectionHeading(
                    title: 'Account e sincronizzazione',
                    subtitle:
                        'Collegamento cloud da attivare dopo l\'allineamento schema',
                    trailing: StatusPill(
                      label: 'Preview locale',
                      color: EvolveColors.amber,
                      icon: Icons.science_outlined,
                    ),
                  ),
                  SizedBox(height: 18),
                  _AccountRow(label: 'Account', value: 'Non collegato'),
                  _AccountRow(
                    label: 'Piano',
                    value: 'Preview desktop',
                    valueColor: EvolveColors.amber,
                  ),
                  _AccountRow(label: 'Repository dati', value: 'In-memory'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingSwitch extends StatelessWidget {
  const _SettingSwitch({
    required this.label,
    required this.detail,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String detail;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 3),
                Text(detail, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({
    required this.label,
    required this.value,
    this.valueColor = EvolveColors.foreground,
  });

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
