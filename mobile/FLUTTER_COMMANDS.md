# 🚀 Comandi Flutter per Evolve

Tutti i comandi Flutter devono essere lanciati dalla cartella `mobile/`. Se ti trovi nella root del progetto, entra prima nella cartella: `cd mobile`.

## 🛠️ Gestione Simulatore
| Azione | Comando | Note |
| :--- | :--- | :--- |
| **Aprire Simulatore iOS** | `open -a Simulator` | Avvia l'app Simulator di macOS |
| **Vedere Dispositivi Connessi** | `flutter devices` | Verifica se il simulatore è riconosciuto |
| **Vedere Emulatori Disponibili** | `flutter emulators` | Elenca gli emulatori configurati |

## 🏃 Avvio e Debug
| Azione | Comando | Note |
| :--- | :--- | :--- |
| **Avviare l'App** | `flutter run` | Compila e lancia l'app sul dispositivo/simulatore attivo |
| **Hot Reload** | Premere `r` nel terminale | Aggiorna le modifiche al codice quasi istantaneamente (mantenendo lo stato) |
| **Hot Restart** | Premere `R` nel terminale | Riavvia l'app da zero (più lento di hot reload, azzera lo stato) |
| **Interrompere l'App** | Premere `q` nel terminale | Chiude l'applicazione e termina il processo di debug |

## 📦 Gestione Dipendenze e Build
| Azione | Comando | Note |
| :--- | :--- | :--- |
| **Installare Dipendenze** | `flutter pub get` | Da lanciare se aggiungi nuovi pacchetti nel `pubspec.yaml` |
| **Pulire la Build** | `flutter clean` | Risolve spesso errori strani di compilazione svuotando la cache |
| **Build iOS (Release)** | `flutter build ios` | Crea la versione pronta per il test su TestFlight o App Store |

## ⚠️ Consigli Utili
- **Errore `MissingPluginException`**: Se aggiungi un pacchetto che usa codice nativo (es. `shared_preferences`), il semplice "Hot Reload" non basta. Devi fermare l'app (`q`) e rilanciarla (`flutter run`).
- **Analisi Codice**: Usa `flutter analyze` per trovare errori di sintassi o suggerimenti di stile prima di fare il commit.
