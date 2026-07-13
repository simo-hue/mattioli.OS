import json
import os

langs = {
    'en': {
        'best': 'BEST',
        'avg': 'AVG',
        'worst': 'WORST',
        'privacyMode': 'Privacy Mode',
        'noData': 'No data for this week yet'
    },
    'it': {
        'best': 'MIGLIORE',
        'avg': 'MEDIA',
        'worst': 'PEGGIORE',
        'privacyMode': 'Modalità Privacy',
        'noData': 'Nessun dato per questa settimana'
    },
    'es': {
        'best': 'MEJOR',
        'avg': 'PROM',
        'worst': 'PEOR',
        'privacyMode': 'Modo de Privacidad',
        'noData': 'Aún no hay datos para esta semana'
    },
    'de': {
        'best': 'BESTE',
        'avg': 'DURCH',
        'worst': 'SCHLECHTESTE',
        'privacyMode': 'Datenschutzmodus',
        'noData': 'Noch keine Daten für diese Woche'
    },
    'ar': {
        'best': 'الأفضل',
        'avg': 'المتوسط',
        'worst': 'الأسوأ',
        'privacyMode': 'وضع الخصوصية',
        'noData': 'لا توجد بيانات لهذا الأسبوع بعد'
    }
}

dir_path = '/Users/simo/Developer/mattioli.OS/mobile/lib/i18n'

for lang, trans in langs.items():
    file_path = os.path.join(dir_path, f'{lang}.i18n.json')
    if os.path.exists(file_path):
        with open(file_path, 'r', encoding='utf-8') as f:
            data = json.load(f)
        
        data['weeklyView'] = trans
        
        with open(file_path, 'w', encoding='utf-8') as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
            f.write('\n')
