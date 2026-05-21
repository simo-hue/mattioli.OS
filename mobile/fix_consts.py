import re

files_to_fix = [
    'lib/ui/screens/ai_chat_screen.dart',
    'lib/ui/screens/app_settings_screen.dart',
    'lib/ui/screens/auth_screen.dart',
    'lib/ui/screens/consent_screen.dart',
    'lib/ui/screens/personal_info_screen.dart',
    'lib/ui/screens/privacy_settings_screen.dart',
    'lib/ui/screens/subscription_screen.dart',
    'lib/ui/widgets/statistics/global_alerts_tab_widget.dart',
    'lib/ui/widgets/statistics/global_trend_tab_widget.dart',
]

for filepath in files_to_fix:
    with open(filepath, 'r') as f:
        content = f.read()
    
    # We remove "const " if the line or the expression contains "context.l10n.translate"
    # Actually, a regex that removes "const " when followed by spaces and a widget that contains context.l10n.translate
    # Simpler: find all lines with 'const ' and 'context.l10n.translate', and replace 'const ' with ''
    
    lines = content.split('\n')
    for i, line in enumerate(lines):
        if 'const ' in line and 'context.l10n.translate' in line:
            lines[i] = line.replace('const ', '')
            
    with open(filepath, 'w') as f:
        f.write('\n'.join(lines))
    print(f'Fixed {filepath}')

