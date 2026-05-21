import os
import glob
import re

translations = {
    'Impossibile aprire il link.': 'Unable to open the link.',
    'Colore Personalizzato': 'Custom Color',
    'Verifica': 'Verify',
    'Problemi di connessione con il Coach. Riprova più tardi.': 'Connection issues with the Coach. Try again later.',
    'AI Coach': 'AI Coach',
    'Elimina': 'Delete',
    'Password aggiornata con successo!': 'Password updated successfully!',
    "Errore durante l'esportazione: ": 'Error during export: ',
    'Dati resettati con successo!': 'Data reset successfully!',
    'Errore durante il reset: ': 'Error during reset: ',
    'Account eliminato con successo!': 'Account deleted successfully!',
    "Errore durante l'eliminazione: ": 'Error during deletion: ',
    'Ripristina acquisti': 'Restore purchases',
    'Errore durante il salvataggio.': 'Error during saving.',
    'Fatto': 'Done',
    'Inserisci la tua email per reimpostare la password.': 'Enter your email to reset the password.',
    'Tasso di successo': 'Success rate',
    'Tasso di successo per categoria': 'Success rate by category',
    'Attività Trim.': 'Quarterly Activity',
    'Q1 - Q4': 'Q1 - Q4',
    'In Q1-Q4': 'In Q1-Q4',
    'Attività Mensile': 'Monthly Activity',
    'Totale/Completati': 'Total/Completed',
    'Completamenti': 'Completions',
    'Mensili': 'Monthly',
    'Totali: ': 'Total: ',
    'Completati: ': 'Completed: ',
    '🎯 Distribuzione Categorie': '🎯 Category Distribution',
    'Ripartizione degli obiettivi per area di focus': 'Breakdown of goals by focus area',
    '📈 Progressione Annuale': '📈 Annual Progression',
    'Confronto anno per anno del volume di obiettivi e completamenti': 'Year-over-year comparison of goals volume and completions',
    'Attivi: ': 'Active: ',
    'Falliti: ': 'Failed: ',
    '🔮 Distribuzione Tipologie': '🔮 Type Distribution',
    'Ripartizione degli obiettivi per orizzonte temporale': 'Breakdown of goals by time horizon',
    '🎂 Stagionalità': '🎂 Seasonality',
    'Performance Trimestrale aggregata': 'Aggregated Quarterly Performance',
    '📈 Mensile (Storico)': '📈 Monthly (Historical)',
    'Successo medio per mese': 'Average success per month',
    ' successo': ' success',
    '📈 Evoluzione Interessi': '📈 Interest Evolution',
    'Composizione delle aree di focus negli anni': 'Composition of focus areas over the years',
    'Modifica categoria': 'Edit category',
    'Archivia categoria': 'Archive category',
    'Nome categoria...': 'Category name...',
    'Titolo obiettivo...': 'Goal title...',
    'Cambia categoria': 'Change category',
    'Scegli categoria': 'Choose category',
    'Punto di Forza': 'Strength',
    'Mese Migliore': 'Best Month',
    'Nessuno': 'None',
    'Tipologia Efficace': 'Effective Type',
    'Totale Storico': 'Historical Total',
    'dal ': 'since ',
    'Successo Globale': 'Global Success',
    'obiettivi completati': 'completed goals',
    'Anno Migliore': 'Best Year',
    'Anno Più Produttivo': 'Most Productive Year',
    'obiettivi totali': 'total goals',
    '🚀 Velocità di Esecuzione (Cumulativa)': '🚀 Execution Speed (Cumulative)',
    'Confronto tra obiettivi pianificati e completati nel tempo': 'Comparison of planned vs completed goals over time',
    '🎯 Performance Categorie': '🎯 Category Performance',
    'Tutto alla grande!': 'Everything is great!',
    'WORST STREAK': 'WORST STREAK',
    'FREQUENZA': 'FREQUENCY',
    'BEST': 'BEST',
    'WORST': 'WORST',
    'Gap: ': 'Gap: ',
    'MOOD ALTO': 'HIGH MOOD',
    'Coefficiente': 'Coefficient',
    'Co-occorrenza': 'Co-occurrence',
    'Giorni': 'Days',
    'Errore durante la creazione della categoria': 'Error creating category',
    'Errore durante la modifica della categoria': 'Error editing category',
    "Errore durante l'archiviazione della categoria": 'Error archiving category',
    "Errore durante l'aggiornamento": 'Error during update',
    "Errore durante l'aggiornamento dello stato": 'Error updating state',
    "Errore durante il salvataggio dell'umore": 'Error saving mood',
    'Lavoro': 'Work',
    'Salute': 'Health',
    'Finanza': 'Finance',
    'Relazioni': 'Relationships',
    'Formazione': 'Education',
    'Hobby': 'Hobbies',
    'Spirituale': 'Spiritual',
    'Altro': 'Other',
    'Evolve • ': 'Evolve • ',
    'Errore durante il salvataggio': 'Error during saving',
    "Errore durante l'eliminazione": 'Error during deletion'
}

loc_path = 'lib/core/localization.dart'
with open(loc_path, 'r') as f:
    loc_content = f.read()

it_inserts = ""
en_inserts = ""
for k, v in translations.items():
    if f"'{k}':" not in loc_content:
        k_escaped = k.replace("'", "\\'")
        v_escaped = v.replace("'", "\\'")
        it_inserts += f"      '{k_escaped}': '{k_escaped}',\n"
        en_inserts += f"      '{k_escaped}': '{v_escaped}',\n"

loc_content = loc_content.replace("'Errore': 'Errore',", f"'Errore': 'Errore',\n{it_inserts}")
loc_content = loc_content.replace("'Errore': 'Error',", f"'Errore': 'Error',\n{en_inserts}")

with open(loc_path, 'w') as f:
    f.write(loc_content)

print('Updated localization.dart')

def replace_in_file(filepath, translations, is_provider=False):
    with open(filepath, 'r') as f:
        content = f.read()
    
    modified = False
    
    for k in translations.keys():
        k_esc = re.escape(k)
        k_repl = k.replace("'", "\\'")
        
        pattern1 = re.compile(r'Text\(\s*[\'\"]' + k_esc + r'[\'\"]\s*\)')
        if pattern1.search(content):
            content = pattern1.sub(f"Text(context.l10n.translate('{k_repl}'))", content)
            modified = True
            
        pattern2 = re.compile(r'SnackBar\(\s*content:\s*Text\(\s*[\'\"]' + k_esc + r'[\'\"]\s*\)')
        if pattern2.search(content):
            content = pattern2.sub(f"SnackBar(content: Text(context.l10n.translate('{k_repl}'))", content)
            modified = True
            
        pattern3 = re.compile(r'(hintText|labelText|tooltip|label|title|subtitle|text)\s*:\s*[\'\"]' + k_esc + r'[\'\"]')
        if pattern3.search(content):
            if 'models/' not in filepath:
                def rep(m):
                    prefix = m.group(1)
                    return f"{prefix}: context.l10n.translate('{k_repl}')"
                content = pattern3.sub(rep, content)
                modified = True
                
        if is_provider:
            pattern4 = re.compile(r'(title|context|message)\s*:\s*[\'\"]' + k_esc + r'[\'\"]')
            if pattern4.search(content):
                def rep_prov(m):
                    prefix = m.group(1)
                    return f"{prefix}: ref.read(l10nProvider).translate('{k_repl}')"
                content = pattern4.sub(rep_prov, content)
                modified = True
                
    if modified:
        if 'import' in content and 'localization.dart' not in content:
            if is_provider:
                content = content.replace("import 'package:flutter_riverpod/flutter_riverpod.dart';", "import 'package:flutter_riverpod/flutter_riverpod.dart';\nimport '../core/localization.dart';")
            else:
                depth = filepath.count('/') - 1
                prefix = '../' * depth
                import_stmt = f"import '{prefix}core/localization.dart';"
                lines = content.split('\n')
                for i, l in enumerate(lines):
                    if l.startswith('import '):
                        lines.insert(i, import_stmt)
                        break
                content = '\n'.join(lines)
                
        with open(filepath, 'w') as f:
            f.write(content)
        print(f'Modified {filepath}')

ui_files = glob.glob('lib/ui/**/*.dart', recursive=True)
for f in ui_files:
    replace_in_file(f, translations, is_provider=False)

prov_files = glob.glob('lib/providers/**/*.dart', recursive=True)
for f in prov_files:
    replace_in_file(f, translations, is_provider=True)

