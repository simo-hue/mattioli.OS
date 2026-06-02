import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:evolve_desktop/shared/widgets/desktop_page.dart';
import 'package:evolve_desktop/shared/widgets/evolve_panel.dart';
import 'package:flutter/material.dart';

class AiCoachPage extends StatelessWidget {
  const AiCoachPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DesktopPage(
      title: 'AI Coach',
      subtitle:
          'Ragiona sui pattern con un coach contestuale basato sui dati del percorso.',
      trailing: const StatusPill(
        label: 'Backend richiesto',
        color: EvolveColors.amber,
        icon: Icons.lock_outline_rounded,
      ),
      child: EvolvePanel(
        child: SizedBox(
          height: 420,
          width: double.infinity,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.auto_awesome_outlined,
                    size: 48,
                    color: context.evolveAccent,
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'AI Coach desktop non ancora attivo',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Le risposte simulate sono state rimosse. Il coach verra '
                    'abilitato solo dopo aver collegato un adapter backend '
                    'sicuro, senza inserire segreti API nel client desktop.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
