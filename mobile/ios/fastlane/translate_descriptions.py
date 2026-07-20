import os
import sys
import time
from deep_translator import GoogleTranslator

# Mapping from App Store Connect locales to Google Translate locales
localeMap = {
  'ar-SA': 'ar', 'ca': 'ca', 'cs': 'cs', 'da': 'da', 'de-DE': 'de', 'el': 'el', 
  'en-AU': 'en', 'en-CA': 'en', 'en-GB': 'en', 'es-ES': 'es', 'es-MX': 'es', 
  'fi': 'fi', 'fr-CA': 'fr', 'fr-FR': 'fr', 'he': 'iw', 'hi': 'hi', 'hr': 'hr', 
  'hu': 'hu', 'id': 'id', 'it': 'it', 'ja': 'ja', 'ko': 'ko', 'ms': 'ms', 
  'nl-NL': 'nl', 'no': 'no', 'pl': 'pl', 'pt-BR': 'pt', 'pt-PT': 'pt', 'ro': 'ro',
  'ru': 'ru', 'sk': 'sk', 'sv': 'sv', 'th': 'th', 'tr': 'tr', 'uk': 'uk', 
  'vi': 'vi', 'zh-Hans': 'zh-CN', 'zh-Hant': 'zh-TW', 'en-US': 'en'
}

metadata_dir = "/Users/simo/Developer/mattioli.OS/mobile/ios/fastlane/metadata"
source_file = os.path.join(metadata_dir, "en-US", "description.txt")

with open(source_file, "r") as f:
    en_content = f.read()

# We might want to translate in chunks if it's too long, but GoogleTranslator supports up to 5000 chars.
if len(en_content) > 5000:
    print("Content too long for single request. Splitting not implemented here.")
    sys.exit(1)

locales = [d for d in os.listdir(metadata_dir) if os.path.isdir(os.path.join(metadata_dir, d))]

for loc in locales:
    if loc in ('en-US', 'it', 'review_information'):
        continue
        
    target_dir = os.path.join(metadata_dir, loc)
    target_file = os.path.join(target_dir, "description.txt")
    
    target_lang = localeMap.get(loc)
    if not target_lang:
        print(f"Skipping {loc} - no Google Translate mapping.")
        continue
        
    print(f"Translating to {loc} ({target_lang})...")
    
    if target_lang == 'en':
        with open(target_file, "w") as f:
            f.write(en_content)
        continue
        
    try:
        translated_text = GoogleTranslator(source='en', target=target_lang).translate(en_content)
        with open(target_file, "w") as f:
            f.write(translated_text)
        print(f"  - Translated description for {loc}")
        time.sleep(1.5)  # Avoid rate limiting
    except Exception as e:
        print(f"  - Failed {loc}: {str(e)}")
        # Fallback to english
        with open(target_file, "w") as f:
            f.write(en_content)

print("Translation complete!")
