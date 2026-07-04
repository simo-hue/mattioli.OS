import re

with open('desktop/lib/features/settings/presentation/settings_page.dart', 'r') as f:
    content = f.read()

# 1. Add imports if missing
if "import 'package:file_picker/file_picker.dart';" not in content:
    content = "import 'package:file_picker/file_picker.dart';\n" + content

if "import 'package:evolve_desktop/core/desktop_backup_import_service.dart';" not in content:
    content = "import 'package:evolve_desktop/core/desktop_backup_import_service.dart';\n" + content

# 2. Add the UI button
old_export_row = """            _ActionRow(
              icon: Icons.download_outlined,
              title: 'Esporta dati',
              detail: 'Condivide un export JSON completo dei dati disponibili.',
              onTap: _exportData,
            ),"""

new_export_row = """            _ActionRow(
              icon: Icons.download_outlined,
              title: 'Esporta dati',
              detail: 'Condivide un export JSON completo dei dati disponibili.',
              onTap: _exportData,
            ),
            _ActionRow(
              icon: Icons.upload_outlined,
              title: 'Importa dati',
              detail: 'Ripristina un backup (formato .zip) di Evolve.',
              onTap: _importData,
            ),"""

if "Importa dati" not in content:
    content = content.replace(old_export_row, new_export_row)

# 3. Add the _importData method right after _exportData
import_logic = """
  Future<void> _importData() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip'],
      );

      if (result == null || result.files.isEmpty) return;
      final path = result.files.single.path;
      if (path == null) return;

      final isPrivateMode = ref.read(activeDataModeProvider) == AppDataMode.private;
      if (!isPrivateMode) {
        _showGate('Importa dati', 'La funzione di importazione è attualmente disponibile solo in Modalità Privata (Locale).');
        return;
      }

      final privateStore = ref.read(privateDatabaseProvider);
      final importService = DesktopBackupImportService(privateStore, null);

      // 1. Preview
      final preview = await importService.parseZipPreview(path);

      if (!mounted) return;

      // 2. Ask for Replace/Merge
      bool replaceExisting = true;
      final confirm = await showEvolveDialog<bool>(
        context: context,
        builder: (ctx) {
          return StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                backgroundColor: context.evolveColors.surface,
                title: Text(
                  'Riepilogo Importazione',
                  style: TextStyle(
                    color: context.evolveColors.foreground,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('• ${preview.habitsCount} Abitudini', style: TextStyle(color: context.evolveColors.foreground)),
                      Text('• ${preview.logsCount} Check-in (Log)', style: TextStyle(color: context.evolveColors.foreground)),
                      Text('• ${preview.macroGoalsCount} Obiettivi Macro', style: TextStyle(color: context.evolveColors.foreground)),
                      Text('• ${preview.categoriesCount} Categorie', style: TextStyle(color: context.evolveColors.foreground)),
                      Text('• ${preview.moodsCount} Registrazioni Umore', style: TextStyle(color: context.evolveColors.foreground)),
                      const SizedBox(height: 24),
                      RadioListTile<bool>(
                        title: Text('Sostituisci i dati attuali', style: TextStyle(color: context.evolveColors.foreground)),
                        subtitle: Text('Elimina tutti i dati locali esistenti prima di importare. (Consigliato)', style: TextStyle(color: context.evolveColors.foreground.withValues(alpha: 0.5), fontSize: 12)),
                        value: true,
                        groupValue: replaceExisting,
                        activeColor: context.evolveColors.primary,
                        onChanged: (val) => setState(() => replaceExisting = val!),
                      ),
                      RadioListTile<bool>(
                        title: Text('Unisci ai dati attuali', style: TextStyle(color: context.evolveColors.foreground)),
                        subtitle: Text('Aggiunge i dati importati senza eliminare nulla. Potrebbe causare duplicati.', style: TextStyle(color: context.evolveColors.foreground.withValues(alpha: 0.5), fontSize: 12)),
                        value: false,
                        groupValue: replaceExisting,
                        activeColor: context.evolveColors.primary,
                        onChanged: (val) => setState(() => replaceExisting = val!),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: Text(
                      'Annulla',
                      style: TextStyle(color: context.evolveColors.foreground.withValues(alpha: 0.5)),
                    ),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Conferma Importazione'),
                  ),
                ],
              );
            },
          );
        },
      );

      if (confirm != true) return;
      if (!mounted) return;

      // 3. Execute
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: context.evolveColors.surface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Importazione in corso...'),
                ],
              ),
            ),
          ),
        ),
      );

      final resultImport = await importService.executeImport(
        rawData: preview.rawData,
        replaceExisting: replaceExisting,
        isPrivateMode: true,
      );

      if (!mounted) return;
      Navigator.pop(context); // close loading

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Importazione completata con successo!'),
          backgroundColor: Colors.green,
        ),
      );
      
      // Refresh dashboard
      ref.invalidate(dashboardControllerProvider);

    } catch (e, st) {
      AppLogger.error('Errore durante importData', e, st);
      if (!mounted) return;
      // Close loading if still open
      if (Navigator.canPop(context)) Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Errore durante importazione: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
"""

if "_importData() async {" not in content:
    # insert before _deletePrivateData
    content = content.replace("  Future<void> _deletePrivateData() async {", import_logic + "\n  Future<void> _deletePrivateData() async {")

with open('desktop/lib/features/settings/presentation/settings_page.dart', 'w') as f:
    f.write(content)
