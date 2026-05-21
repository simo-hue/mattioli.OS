import 'package:flutter/widgets.dart';
import 'package:mattioli_os/l10n/generated/app_localizations.dart';

export 'package:mattioli_os/l10n/generated/app_localizations.dart';

extension AppLocalizationsExtension on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

extension AppLocalizationsCompatibility on AppLocalizations {
  String get language => localeName;

  String translate(String key) {
    switch (key) {
      case 'app_title':
        return appTitle;
      case 'Impostazioni App':
        return impostazioniApp;
      case 'ASPETTO & VISUAL':
        return aspettoVisual;
      case 'Modalità Scura':
        return modalitaScura;
      case 'Colore Accento':
        return coloreAccento;
      case 'CALENDARIO & DASHBOARD':
        return calendarioDashboard;
      case 'Vista Predefinita':
        return vistaPredefinita;
      case 'ESPERIENZA UTENTE':
        return esperienzaUtente;
      case 'Feedback Aptico':
        return feedbackAptico;
      case 'UNITÀ E LINGUA':
        return unitaELingua;
      case 'Lingua':
        return lingua;
      case 'Formato 24h':
        return formato24h;
      case 'AI & SISTEMA':
        return aiSistema;
      case 'Suggerimenti AI':
        return suggerimentiAi;
      case 'Analisi intelligente delle abitudini':
        return analisiIntelligenteDelleAbitudini;
      case 'PRO ONLY':
        return proOnly;
      case 'Home':
        return home;
      case 'Statistiche':
        return statistiche;
      case 'Obiettivi':
        return obiettivi;
      case 'Salva':
        return salva;
      case 'Annulla':
        return annulla;
      case 'Conferma':
        return conferma;
      case 'Aggiorna Stato Giornaliero':
        return aggiornaStatoGiornaliero;
      case 'Check-in Giornaliero':
        return checkInGiornaliero;
      case 'Oggi':
        return oggi;
      case 'Abitudini':
        return abitudini;
      case 'Umore':
        return umore;
      case 'Energia':
        return energia;
      case 'AI Chat':
        return aiChat;
      case 'Morning Brief':
        return morningBrief;
      case 'Review Serale':
        return reviewSerale;
      case 'Notifiche':
        return notifiche;
      case 'Privacy e Sicurezza':
        return privacyESicurezza;
      case 'Account':
        return account;
      case 'Piano PRO':
        return pianoPro;
      case 'Informazioni Personali':
        return informazioniPersonali;
      case 'Blocco Biometrico':
        return bloccoBiometrico;
      case 'Analytics Anonimi':
        return analyticsAnonimi;
      case 'Promemoria Abitudini':
        return promemoriaAbitudini;
      case 'Scadenze Obiettivi':
        return scadenzeObiettivi;
      case 'Insight AI':
        return insightAi;
      case 'Resoconti Settimanali':
        return resocontiSettimanali;
      case 'Modalità Focus':
        return modalitaFocus;
      case 'Milestones':
        return milestones;
      case 'Deep Work Insights':
        return deepWorkInsights;
      case 'Gestione Abitudini':
        return gestioneAbitudini;
      case 'Aggiungi Abitudine':
        return aggiungiAbitudine;
      case 'Modifica Abitudine':
        return modificaAbitudine;
      case 'Elimina Abitudine':
        return eliminaAbitudine;
      case 'Nome Abitudine':
        return nomeAbitudine;
      case 'Colore':
        return colore;
      case 'Trascina per riordinare':
        return trascinaPerRiordinare;
      case 'Nessuna abitudine tracciata oggi':
        return nessunaAbitudineTracciataOggi;
      case 'Panoramica Statistiche':
        return panoramicaStatistiche;
      case 'Mese':
        return mese;
      case 'Settimana':
        return settimana;
      case 'Anno':
        return anno;
      case 'Vita':
        return vita;
      case 'Analisi dettagliata delle tue performance.':
        return analisiDettagliataDelleTuePerformance;
      case 'Tutti gli Habits':
        return tuttiGliHabits;
      case 'SELEZIONA HABIT':
        return selezionaHabit;
      case 'Info':
        return info;
      case 'Trend':
        return trend;
      case 'Alert':
        return alert;
      case 'Stats':
        return stats;
      case 'Completamento':
        return completamento;
      case 'Globale':
        return globale;
      case 'Miglior Serie':
        return migliorSerie;
      case 'Giorni':
        return giorni;
      case 'Top Performer':
        return topPerformer;
      case 'Giorno Critico':
        return giornoCritico;
      case 'Focus richiesto':
        return focusRichiesto;
      case 'Abitudini Chiave':
        return abitudiniChiave;
      case 'Abitudini che influenzano positivamente molte altre':
        return abitudiniCheInfluenzanoPositivamenteMolteAltre;
      case 'Alto Impatto':
        return altoImpatto;
      case 'connessioni':
        return connessioni;
      case 'Media Impatto':
        return mediaImpatto;
      case 'Analisi Correlazioni':
        return analisiCorrelazioni;
      case 'Pattern tra le tue abitudini':
        return patternTraLeTueAbitudini;
      case 'Coppie Analizzate':
        return coppieAnalizzate;
      case 'Correlazione Media':
        return correlazioneMedia;
      case 'Positive':
        return positive;
      case 'Negative':
        return negative;
      case 'Abitudini Isolate':
        return abitudiniIsolate;
      case 'Non hanno correlazioni significative.':
        return nonHannoCorrelazioniSignificative;
      case 'Correlazioni Positive':
        return correlazioniPositive;
      case 'Correlazioni Negative':
        return correlazioniNegative;
      case 'Attività Recente':
        return attivitaRecente;
      case 'Suggerimento':
        return suggerimento;
      case 'Le abitudini chiave hanno un effetto "domino".':
        return leAbitudiniChiaveHannoUnEffettoDomino;
      case 'timeframe_week_short':
        return timeframeWeekShort;
      case 'timeframe_month_short':
        return timeframeMonthShort;
      case 'timeframe_year_short':
        return timeframeYearShort;
      case 'timeframe_all':
        return timeframeAll;
      case 'week':
        return week;
      case 'month':
        return month;
      case 'year':
        return year;
      case 'all':
        return all;
      case '7d':
        return label7d;
      case '14d':
        return label14d;
      case '30d':
        return label30d;
      case 'Trend Completamento':
        return trendCompletamento;
      case 'Performance Evolution':
        return performanceEvolution;
      case 'Sett':
        return sett;
      case 'Tutto':
        return tutto;
      case 'Confronto Temporale':
        return confrontoTemporale;
      case 'Analizza come stai andando rispetto al passato.':
        return analizzaComeStaiAndandoRispettoAlPassato;
      case 'vs':
        return vs;
      case 'Aree di Miglioramento':
        return areeDiMiglioramento;
      case 'Abitudini che richiedono più attenzione.':
        return abitudiniCheRichiedonoPiuAttenzione;
      case 'succ.':
        return succ;
      case 'GIORNO NERO':
        return giornoNero;
      case 'Solo il':
        return soloIl;
      case 'di completamento':
        return diCompletamento;
      case 'Analisi Worst Streaks':
        return analisiWorstStreaks;
      case 'Analisi serie negative per identificare pattern.':
        return analisiSerieNegativePerIdentificarePattern;
      case 'Abitudini Critiche':
        return abitudiniCritiche;
      case 'Top 3 Worst Streaks':
        return top3WorstStreaks;
      case 'giorni consecutivi':
        return giorniConsecutivi;
      case 'Analisi Fallimenti':
        return analisiFallimenti;
      case 'Pattern di Recupero':
        return patternDiRecupero;
      case 'Tempo Medio Recupero':
        return tempoMedioRecupero;
      case 'Buono':
        return buono;
      case 'RECUPERATORI VELOCI':
        return recuperatoriVeloci;
      case 'Confronto Performance':
        return confrontoPerformance;
      case 'Attenzione':
        return attenzione;
      case 'Suggerimenti Pratici':
        return suggerimentiPratici;
      case 'Dettagli Abitudini':
        return dettagliAbitudini;
      case 'Ordina per':
        return ordinaPer;
      case 'Rate':
        return rate;
      case 'Peggior Serie':
        return peggiorSerie;
      case 'Serie Attuale':
        return serieAttuale;
      case 'ORDINA PER':
        return ordinaPer2;
      case 'Mood & Energy vs Productivity':
        return moodEnergyVsProductivity;
      case 'Correlazione tra benessere e abitudini':
        return correlazioneTraBenessereEAbitudini;
      case 'time_range_7d':
        return timeRange7d;
      case 'time_range_14d':
        return timeRange14d;
      case 'time_range_30d':
        return timeRange30d;
      case 'Produttività':
        return produttivita;
      case 'Sensibili al Mood':
        return sensibiliAlMood;
      case 'Richiedono un buon mood per essere completate.':
        return richiedonoUnBuonMoodPerEssereCompletate;
      case 'con mood basso':
        return conMoodBasso;
      case 'con mood alto':
        return conMoodAlto;
      case 'Resilienti':
        return resilienti;
      case 'Mantenute anche con mood ed energia bassi.':
        return mantenuteAncheConMoodEdEnergiaBassi;
      case 'Mood':
        return mood;
      case 'Stabile':
        return stabile;
      case 'Suggerimenti':
        return suggerimenti;
      case 'Pianifica le abitudini sensibili al mood quando ti senti meglio.':
        return pianificaLeAbitudiniSensibiliAlMoodQuandoTiSentiMeglio;
      case 'Le abitudini resilienti sono ottime nei giorni difficili.':
        return leAbitudiniResilientiSonoOttimeNeiGiorniDifficili;
      case 'Monitora mood ed energia per insights più accurati.':
        return monitoraMoodEdEnergiaPerInsightsPiuAccurati;
      case 'SERIE ATTUALE':
        return serieAttuale2;
      case 'RECORD':
        return rECORD;
      case 'COMPLETAMENTO':
        return cOMPLETAMENTO;
      case 'MANCATI':
        return mANCATI;
      case 'Trend Ultimi 30 Giorni':
        return trendUltimi30Giorni;
      case 'Completato':
        return completato;
      case 'Non completato':
        return nonCompletato;
      case 'Correlazioni con':
        return correlazioniCon;
      case 'Come questa abitudine si relaziona con le altre':
        return comeQuestaAbitudineSiRelazionaConLeAltre;
      case 'insieme':
        return insieme;
      case 'Info Correlazioni':
        return infoCorrelazioni;
      case 'Calendario Annuale':
        return calendarioAnnuale;
      case 'Mancato':
        return mancato;
      case 'Non tracciato':
        return nonTracciato;
      case 'Performance per Giorno':
        return performancePerGiorno;
      case 'Giorno più forte':
        return giornoPiuForte;
      case 'Giorno più debole':
        return giornoPiuDebole;
      case 'Ben fatto! % di completamento':
        return benFattoDiCompletamento;
      case 'Solo % di completamento':
        return soloDiCompletamento;
      case 'Serie Negativa Peggiore':
        return serieNegativaPeggiore;
      case 'giorni consecutivi mancati':
        return giorniConsecutiviMancati;
      case 'Iniziata il':
        return iniziataIl;
      case 'Streak Interrotti':
        return streakInterrotti;
      case 'Streak di count giorni interrotto':
        return streakDiCountGiorniInterrotto;
      case 'Concentrati sul Dom - è il tuo giorno più debole':
        return concentratiSulDomEIlTuoGiornoPiuDebole;
      case 'Evita pause prolungate - la tua serie negativa più lunga è stata di 12 giorni':
        return evitaPauseProlungateLaTuaSerieNegativaPiuLungaEStataDi12Giorni;
      case 'Obiettivo: raggiungi almeno il 70% di completamento per consolidare l\'abitudine':
        return obiettivoRaggiungiAlmenoIl70DiCompletamentoPerConsolidareLAbitudine;
      case 'Traccia il tuo umore ed energia.':
        return tracciaIlTuoUmoreEdEnergia;
      case 'Scegli un colore':
        return scegliUnColore;
      case 'Es. Bere acqua, Leggere...':
        return esBereAcquaLeggere;
      case 'Correlazione Mood':
        return correlazioneMood;
      case 'Correlazione Energia':
        return correlazioneEnergia;
      case 'Mood Medio (✓)':
        return moodMedio;
      case 'Energia Media (✓)':
        return energiaMedia;
      case 'Nessuna':
        return nessuna;
      case 'su 10':
        return su10;
      case 'Resiliente':
        return resiliente;
      case 'Completato vs Mancato':
        return completatoVsMancato;
      case 'Performance per Livello':
        return performancePerLivello;
      case 'Basso (1-4) • Medio (5-7) • Alto (8-10)':
        return basso14Medio57Alto810;
      case 'Basso':
        return basso;
      case 'Medio':
        return medio;
      case 'Alto':
        return alto;
      case 'Con Mood':
        return conMood;
      case 'Con Energia':
        return conEnergia;
      case 'Analisi basata su count giorni con dati mood/energia (done completati, missed mancati)':
        return analisiBasataSuCountGiorniConDatiMoodEnergiaDoneCompletatiMissedMancati;
      case 'Nome':
        return nome;
      case 'Cognome':
        return cognome;
      case 'Email':
        return email;
      case 'Telefono (Opzionale)':
        return telefonoOpzionale;
      case 'Informazioni salvate con successo':
        return informazioniSalvateConSuccesso;
      case 'Campo obbligatorio':
        return campoObbligatorio;
      case 'Inserisci un\'email valida':
        return inserisciUnEmailValida;
      case 'Giorno':
        return giorno;
      case 'Buongiorno':
        return buongiorno;
      case 'Buon pomeriggio':
        return buonPomeriggio;
      case 'Buonasera':
        return buonasera;
      case 'Bentornato':
        return bentornato;
      case 'Sistema Sincronizzato':
        return sistemaSincronizzato;
      case 'succ':
        return succ2;
      case 'only':
        return only;
      case 'attention':
        return attention;
      case 'monday':
        return monday;
      case 'tuesday':
        return tuesday;
      case 'wednesday':
        return wednesday;
      case 'thursday':
        return thursday;
      case 'friday':
        return friday;
      case 'saturday':
        return saturday;
      case 'sunday':
        return sunday;
      case 'mon':
        return mon;
      case 'tue':
        return tue;
      case 'wed':
        return wed;
      case 'thu':
        return thu;
      case 'fri':
        return fri;
      case 'sat':
        return sat;
      case 'sun':
        return sun;
      case 'january':
        return january;
      case 'february':
        return february;
      case 'march':
        return march;
      case 'april':
        return april;
      case 'may':
        return may;
      case 'june':
        return june;
      case 'july':
        return july;
      case 'august':
        return august;
      case 'september':
        return september;
      case 'october':
        return october;
      case 'november':
        return november;
      case 'december':
        return december;
      case 'rate':
        return rate2;
      case 'best_streak_label':
        return bestStreakLabel;
      case 'worst_streak_label':
        return worstStreakLabel;
      case 'current_streak_label':
        return currentStreakLabel;
      case 'first_name':
        return firstName;
      case 'Crea Abitudine':
        return creaAbitudine;
      case 'Puoi modificare solo oggi e ieri!':
        return puoiModificareSoloOggiEIeri;
      case 'Nessun dato':
        return nessunDato;
      case 'Dati insufficienti (servono almeno 3 categorie)':
        return datiInsufficientiServonoAlmeno3Categorie;
      case 'Distribuzione':
        return distribuzione;
      case 'obiettivi':
        return obiettivi2;
      case 'nascita':
        return nascita;
      case '85 anni':
        return label85Anni;
      case 'Sensibilità':
        return sensibilita;
      case 'Streak Negativa':
        return streakNegativa;
      case 'Coming Soon':
        return comingSoon;
      case 'Errore':
        return errore;
      case 'L\'accesso Pro è stato ripristinato con successo su questo dispositivo. Divertiti!':
        return lAccessoProEStatoRipristinatoConSuccessoSuQuestoDispositivoDivertiti;
      case 'Nessun abbonamento Evolve Pro attivo è stato trovato su questo Apple ID. Assicurati di usare lo stesso Apple ID dell\'acquisto.':
        return nessunAbbonamentoEvolveProAttivoEStatoTrovatoSuQuestoAppleIdAssicuratiDiUsareLoStessoAppleIdDellAcquisto;
      case 'L\'acquisto è registrato, ma l\'abbonamento Pro non risulta ancora attivo. Attendi qualche secondo e usa Ripristina acquisti.':
        return lAcquistoERegistratoMaLAbbonamentoProNonRisultaAncoraAttivoAttendiQualcheSecondoEUsaRipristinaAcquisti;
      case 'Contratto Paid Apps non attivo. L\'Account Holder deve accettare l\'accordo Paid Apps in App Store Connect.':
        return contrattoPaidAppsNonAttivoLAccountHolderDeveAccettareLAccordoPaidAppsInAppStoreConnect;
      case 'Questo abbonamento risulta già acquistato. Usa Ripristina acquisti per riattivare l\'accesso Pro.':
        return questoAbbonamentoRisultaGiaAcquistatoUsaRipristinaAcquistiPerRiattivareLAccessoPro;
      case 'Gli acquisti in-app non sono consentiti su questo dispositivo o account Apple.':
        return gliAcquistiInAppNonSonoConsentitiSuQuestoDispositivoOAccountApple;
      case 'Il piano selezionato non è disponibile per l\'acquisto. Riprova più tardi.':
        return ilPianoSelezionatoNonEDisponibilePerLAcquistoRiprovaPiuTardi;
      case 'Il pagamento è in sospeso. L\'accesso Pro verrà attivato quando Apple confermerà la transazione.':
        return ilPagamentoEInSospesoLAccessoProVerraAttivatoQuandoAppleConfermeraLaTransazione;
      case 'Connessione non disponibile. Controlla la rete e riprova.':
        return connessioneNonDisponibileControllaLaReteERiprova;
      case 'Configurazione acquisti non valida. Verifica App Store Connect e RevenueCat prima di inviare la build.':
        return configurazioneAcquistiNonValidaVerificaAppStoreConnectERevenuecatPrimaDiInviareLaBuild;
      case 'Questo acquisto è già collegato a un altro account Evolve. Accedi con quell\'account o contatta il supporto.':
        return questoAcquistoEGiaCollegatoAUnAltroAccountEvolveAccediConQuellAccountOContattaIlSupporto;
      case 'Un\'operazione di acquisto è già in corso. Attendi qualche secondo.':
        return unOperazioneDiAcquistoEGiaInCorsoAttendiQualcheSecondo;
      case 'Non siamo riusciti a completare l\'acquisto. Riprova tra poco.':
        return nonSiamoRiuscitiACompletareLAcquistoRiprovaTraPoco;
      case 'Ripristino annullato.':
        return ripristinoAnnullato;
      case 'Un ripristino è già in corso. Attendi qualche secondo.':
        return unRipristinoEGiaInCorsoAttendiQualcheSecondo;
      case 'Non siamo riusciti a ripristinare gli acquisti. Riprova tra poco.':
        return nonSiamoRiuscitiARipristinareGliAcquistiRiprovaTraPoco;
      case 'Passa a Evolve Pro':
        return passaAEvolvePro;
      case 'Sblocca tutte le funzionalità e accelera la tua crescita.':
        return sbloccaTutteLeFunzionalitaEAcceleraLaTuaCrescita;
      case 'COSA INCLUDE IL PIANO PRO':
        return cosaIncludeIlPianoPro;
      case 'Suggerimenti intelligenti basati sui tuoi dati.':
        return suggerimentiIntelligentiBasatiSuiTuoiDati;
      case 'Statistiche Avanzate':
        return statisticheAvanzate;
      case 'Grafici profondi e analisi dei trend.':
        return graficiProfondiEAnalisiDeiTrend;
      case 'Crea tutti gli habits che desideri senza limiti.':
        return creaTuttiGliHabitsCheDesideriSenzaLimiti;
      case 'Obiettivi Illimitati':
        return obiettiviIllimitati;
      case 'Crea tutti i tuoi macro obiettivi senza limiti.':
        return creaTuttiITuoiMacroObiettiviSenzaLimiti;
      case 'SCEGLI IL TUO PIANO':
        return scegliIlTuoPiano;
      case 'Mensile':
        return mensile;
      case 'Settimanale':
        return goalTypeWeekly;
      case 'Trimestrale':
        return goalTypeQuarterly;
      case 'Lifetime':
        return goalTypeLifetime;
      case 'Disdici quando vuoi':
        return disdiciQuandoVuoi;
      case 'Annuale':
        return goalTypeAnnual;
      case 'Risparmia oltre il 40%':
        return risparmiaOltreIl40;
      case 'Il servizio acquisti non è raggiungibile. Verifica la tua connessione e riprova.':
        return ilServizioAcquistiNonERaggiungibileVerificaLaTuaConnessioneERiprova;
      case 'Attiva Abbonamento':
        return attivaAbbonamento;
      case 'L\'abbonamento si rinnova automaticamente a meno che l\'autorinnovamento non venga disattivato nelle impostazioni dell\'account Apple almeno 24 ore prima della scadenza.':
        return lAbbonamentoSiRinnovaAutomaticamenteAMenoCheLAutorinnovamentoNonVengaDisattivatoNelleImpostazioniDellAccountAppleAlmeno24OrePrimaDellaScadenza;
      case 'Privacy Policy':
        return privacyPolicy;
      case 'Termini d\'Uso (EULA)':
        return terminiDUsoEula;
      case 'Sei un utente Pro!':
        return seiUnUtentePro;
      case 'Grazie per sostenere lo sviluppo di Evolve.':
        return graziePerSostenereLoSviluppoDiEvolve;
      case 'DETTAGLI ABBONAMENTO':
        return dettagliAbbonamento;
      case 'Piano':
        return piano;
      case 'Evolve Pro Attivo':
        return evolveProAttivo;
      case 'Stato':
        return stato;
      case 'Attivo':
        return attivo;
      case 'Prossimo Rinnovo':
        return prossimoRinnovo;
      case 'Metodo di Pagamento':
        return metodoDiPagamento;
      case 'Apple Pay / App Store':
        return applePayAppStore;
      case 'Gestisci Abbonamento':
        return gestisciAbbonamento;
      case 'Disdici Abbonamento':
        return disdiciAbbonamento;
      case 'Benvenuto in Evolve Pro!':
        return benvenutoInEvolvePro;
      case 'La tua iscrizione è attiva. Ora hai accesso completo ed illimitato all\'AI Coach personalizzato, alle statistiche avanzate dei trend e a tutti gli strumenti di crescita personale di Evolve.':
        return laTuaIscrizioneEAttivaOraHaiAccessoCompletoEdIllimitatoAllAiCoachPersonalizzatoAlleStatisticheAvanzateDeiTrendEATuttiGliStrumentiDiCrescitaPersonaleDiEvolve;
      case 'Inizia il tuo Percorso':
        return iniziaIlTuoPercorso;
      case 'Per modificare, aggiornare o disdire il tuo abbonamento Pro, verrai indirizzato al portale ufficiale di RevenueCat o del tuo Account Apple.':
        return perModificareAggiornareODisdireIlTuoAbbonamentoProVerraiIndirizzatoAlPortaleUfficialeDiRevenuecatODelTuoAccountApple;
      case 'Evolve Pro':
        return evolvePro;
      case 'Termini e Privacy Policy':
        return terminiEPrivacyPolicy;
      case 'Notifiche di Sistema':
        return notificheDiSistema;
      case 'Abitudini giornaliere':
        return abitudiniGiornaliere;
      case 'Stato di completamento di oggi':
        return statoDiCompletamentoDiOggi;
      case 'Macro obiettivi':
        return macroObiettivi;
      case 'Lista degli obiettivi attivi e completati':
        return listaDegliObiettiviAttiviECompletati;
      case 'Nuova chat':
        return nuovaChat;
      case 'Impostazioni contesto':
        return impostazioniContesto;
      case 'Fai una domanda...':
        return faiUnaDomanda;
      case 'Orario Morning Brief':
        return orarioMorningBrief;
      case 'Orario Review Serale':
        return orarioReviewSerale;
      case 'FaceID / TouchID':
        return faceidTouchid;
      case 'Cambia Password':
        return cambiaPassword;
      case 'Invia Segnalazioni Crash':
        return inviaSegnalazioniCrash;
      case 'Aiutaci a migliorare l\'app...':
        return aiutaciAMigliorareLApp;
      case 'Esporta Dati':
        return esportaDati;
      case 'Formato JSON / CSV':
        return formatoJsonCsv;
      case 'Elimina Account & Dati':
        return eliminaAccountDati;
      case 'Gestione Permessi':
        return gestionePermessi;
      case 'Notifiche, Calendario, etc.':
        return notificheCalendarioEtc;
      case 'Password Attuale':
        return passwordAttuale;
      case 'Nuova Password':
        return nuovaPassword;
      case 'Conferma Nuova Password':
        return confermaNuovaPassword;
      case 'Errore durante l\'aggiornamento della password.':
        return erroreDuranteLAggiornamentoDellaPassword;
      case 'Errore durante l\'esportazione dei dati.':
        return erroreDuranteLEsportazioneDeiDati;
      case 'Errore durante l\'eliminazione dell\'account.':
        return erroreDuranteLEliminazioneDellAccount;
      case 'Errore durante l\'eliminazione: \\\$e':
        return erroreDuranteLEliminazioneE;
      case 'Resetta i Dati':
        return resettaIDati;
      case 'Eliminerà abitudini, obiettivi e preferenze, ma manterrà il tuo account attivo.':
        return elimineraAbitudiniObiettiviEPreferenzeMaManterraIlTuoAccountAttivo;
      case 'Conferma Reset Dati':
        return confermaResetDati;
      case 'Elimina l\'account':
        return eliminaLAccount;
      case 'Eliminerà definitivamente il tuo account e tutti i dati associati. Questa azione è irreversibile.':
        return elimineraDefinitivamenteIlTuoAccountETuttiIDatiAssociatiQuestaAzioneEIrreversibile;
      case 'Conferma Eliminazione Account':
        return confermaEliminazioneAccount;
      case 'Acquisti Ripristinati!':
        return acquistiRipristinati;
      case 'Nessun Acquisto Trovato':
        return nessunAcquistoTrovato;
      case 'Ripristino Fallito':
        return ripristinoFallito;
      case 'Abbonamento in Elaborazione':
        return abbonamentoInElaborazione;
      case 'Acquisto Fallito':
        return acquistoFallito;
      case 'Errore Connessione':
        return erroreConnessione;
      case 'DATA DI NASCITA':
        return dataDiNascita;
      case 'Pre-tracking':
        return preTracking;
      case 'Attuale':
        return attuale;
      case 'MESI VISSUTI':
        return mesiVissuti;
      case 'ETÀ ATTUALE':
        return etaAttuale;
      case 'RIMANENTI':
        return rIMANENTI;
      case 'AI Coach Personalizzato':
        return aiCoachPersonalizzato;
      case 'Statistiche Specifiche Per Abitudine':
        return statisticheSpecifichePerAbitudine;
      case 'Metriche Avanzate Obiettivi':
        return metricheAvanzateObiettivi;
      case 'Abitudini Illimitate':
        return abitudiniIllimitate;
      case 'Clicca qui per segnare l\'obiettivo come completato. Cliccandolo di nuovo verrà segnato come fallito.':
        return cliccaQuiPerSegnareLObiettivoComeCompletatoCliccandoloDiNuovoVerraSegnatoComeFallito;
      case 'Usa questo pulsante per assegnare rapidamente una categoria all\'obiettivo.':
        return usaQuestoPulsantePerAssegnareRapidamenteUnaCategoriaAllObiettivo;
      case 'Se non hai fatto in tempo o i piani sono cambiati, puoi spostare questo obiettivo alla settimana / mese o anno successivo ( in base a dove hai inserito l\'obiettivo).':
        return seNonHaiFattoInTempoOIPianiSonoCambiatiPuoiSpostareQuestoObiettivoAllaSettimanaMeseOAnnoSuccessivoInBaseADoveHaiInseritoLObiettivo;
      case 'Se devi semplicemente rinominare l\'obiettivo, usa la matita.':
        return seDeviSemplicementeRinominareLObiettivoUsaLaMatita;
      case 'Infine, questo pulsante elimina definitivamente l\'obiettivo.':
        return infineQuestoPulsanteEliminaDefinitivamenteLObiettivo;
      case 'Passa a questa scheda per visualizzare grafici e performance dettagliate selezionando l\'anno corrente o tutti gli anni.':
        return passaAQuestaSchedaPerVisualizzareGraficiEPerformanceDettagliateSelezionandoLAnnoCorrenteOTuttiGliAnni;
      case 'Da qui puoi selezionare una specifica abitudine per vederne i dettagli, oppure \'Tutti gli Habits\' per una panoramica globale.':
        return daQuiPuoiSelezionareUnaSpecificaAbitudinePerVederneIDettagliOppureTuttiGliHabitsPerUnaPanoramicaGlobale;
      case 'Naviga tra le varie schede per vedere i Trend, gli Alert sulle performance, l\'andamento delle Abitudini e il tuo Mood.':
        return navigaTraLeVarieSchedePerVedereITrendGliAlertSullePerformanceLAndamentoDelleAbitudiniEIlTuoMood;
      case 'Mood & Energia':
        return moodEnergia;
      case 'Analisi del benessere psicofisico.':
        return analisiDelBenesserePsicofisico;
      case 'Non ci sono abbastanza dati per calcolare la sensibilità.':
        return nonCiSonoAbbastanzaDatiPerCalcolareLaSensibilita;
      case 'Non ci sono abbastanza dati per calcolare la resilienza.':
        return nonCiSonoAbbastanzaDatiPerCalcolareLaResilienza;
      case 'Resilienza':
        return resilienza;
      case 'Analisi di Correlazione':
        return analisiDiCorrelazione;
      case 'Non ci sono abbastanza dati per l\'analisi di correlazione.':
        return nonCiSonoAbbastanzaDatiPerLAnalisiDiCorrelazione;
      case 'Trend Globale':
        return trendGlobale;
      case 'COMPLETATI':
        return cOMPLETATI;
      case 'FALLITI':
        return fALLITI;
      case 'di successo':
        return diSuccesso;
      case 'completamento':
        return completamento2;
      case 'dal':
        return dal;
      case 'Totale':
        return totale;
      case 'Successo':
        return successo;
      case 'Crescita':
        return crescita;
      case 'Calo':
        return calo;
      case 'Aggiungi obiettivo lifetime...':
        return aggiungiObiettivoLifetime;
      case 'Aggiungi obiettivo annuale...':
        return aggiungiObiettivoAnnuale;
      case 'Aggiungi obiettivo trimestrale...':
        return aggiungiObiettivoTrimestrale;
      case 'Aggiungi obiettivo mensile...':
        return aggiungiObiettivoMensile;
      case 'Aggiungi obiettivo settimanale...':
        return aggiungiObiettivoSettimanale;
      case 'Limite di 100 obiettivi raggiunto!':
        return limiteDi100ObiettiviRaggiunto;
      case 'Scegli una tonalità premium o creane una tua':
        return scegliUnaTonalitaPremiumOCreaneUnaTua;
      case 'Abbonamento':
        return abbonamento;
      case 'Lingua, Tema, Unità di misura':
        return linguaTemaUnitaDiMisura;
      case 'Promemoria e avvisi di sistema':
        return promemoriaEAvvisiDiSistema;
      case 'Gestione dati e biometrica':
        return gestioneDatiEBiometrica;
      case 'Ripeti Tutorial':
        return ripetiTutorial;
      case 'Visualizza di nuovo la guida iniziale':
        return visualizzaDiNuovoLaGuidaIniziale;
      case 'Stato d\'animo':
        return statoDAnimo;
      case 'Gestione':
        return gestione;
      case 'I tuoi progressi per oggi':
        return iTuoiProgressiPerOggi;
      case 'Nessuna abitudine':
        return nessunaAbitudine;
      case 'Non ci sono abitudini per questo giorno.\nInizia a crearne una!':
        return nonCiSonoAbitudiniPerQuestoGiornoIniziaACrearneUna;
      case 'Trend Settimanale':
        return trendSettimanale;
      case 'Trend Mensile':
        return trendMensile;
      case 'Trend Annuale':
        return trendAnnuale;
      case 'MOOD BASSO':
        return moodBasso;
      case 'Abitudini Sensibili al Mood':
        return abitudiniSensibiliAlMood;
      case 'Abitudini Resilienti':
        return abitudiniResilienti;
      case 'Abitudini che mantieni anche quando il mood è basso.':
        return abitudiniCheMantieniAncheQuandoIlMoodEBasso;
      case 'Analisi Performance':
        return analisiPerformance;
      case ' di completamento':
        return diCompletamento2;
      case ' di successo':
        return diSuccesso2;
      case ' completamento':
        return completamento3;
      case 'Crea nuova categoria':
        return creaNuovaCategoria;
      case 'Completati':
        return completati;
      case 'Falliti':
        return falliti;
      case 'Impossibile aprire il link.':
        return impossibileAprireIlLink;
      case 'Colore Personalizzato':
        return colorePersonalizzato;
      case 'Verifica':
        return verifica;
      case 'Problemi di connessione con il Coach. Riprova più tardi.':
        return problemiDiConnessioneConIlCoachRiprovaPiuTardi;
      case 'AI Coach':
        return aiCoach;
      case 'Password aggiornata con successo!':
        return passwordAggiornataConSuccesso;
      case 'Errore durante l\'esportazione: ':
        return erroreDuranteLEsportazione;
      case 'Dati resettati con successo!':
        return datiResettatiConSuccesso;
      case 'Errore durante il reset: ':
        return erroreDuranteIlReset;
      case 'Account eliminato con successo!':
        return accountEliminatoConSuccesso;
      case 'Errore durante l\'eliminazione: ':
        return erroreDuranteLEliminazione;
      case 'Ripristina acquisti':
        return ripristinaAcquisti;
      case 'Errore durante il salvataggio.':
        return erroreDuranteIlSalvataggio;
      case 'Fatto':
        return fatto;
      case 'Inserisci la tua email per reimpostare la password.':
        return inserisciLaTuaEmailPerReimpostareLaPassword;
      case 'Tasso di successo':
        return tassoDiSuccesso;
      case 'Tasso di successo per categoria':
        return tassoDiSuccessoPerCategoria;
      case 'Attività Trim.':
        return attivitaTrim;
      case 'Q1 - Q4':
        return q1Q4;
      case 'In Q1-Q4':
        return inQ1Q4;
      case 'Attività Mensile':
        return attivitaMensile;
      case 'Totale/Completati':
        return totaleCompletati;
      case 'Completamenti':
        return completamenti;
      case 'Mensili':
        return mensili;
      case 'Totali: ':
        return totali;
      case 'Completati: ':
        return completati2;
      case '🎯 Distribuzione Categorie':
        return distribuzioneCategorie;
      case 'Ripartizione degli obiettivi per area di focus':
        return ripartizioneDegliObiettiviPerAreaDiFocus;
      case '📈 Progressione Annuale':
        return progressioneAnnuale;
      case 'Confronto anno per anno del volume di obiettivi e completamenti':
        return confrontoAnnoPerAnnoDelVolumeDiObiettiviECompletamenti;
      case 'Attivi: ':
        return attivi;
      case 'Falliti: ':
        return falliti2;
      case '🔮 Distribuzione Tipologie':
        return distribuzioneTipologie;
      case 'Ripartizione degli obiettivi per orizzonte temporale':
        return ripartizioneDegliObiettiviPerOrizzonteTemporale;
      case '🎂 Stagionalità':
        return stagionalita;
      case 'Performance Trimestrale aggregata':
        return performanceTrimestraleAggregata;
      case '📈 Mensile (Storico)':
        return mensileStorico;
      case 'Successo medio per mese':
        return successoMedioPerMese;
      case ' successo':
        return successo2;
      case '📈 Evoluzione Interessi':
        return evoluzioneInteressi;
      case 'Composizione delle aree di focus negli anni':
        return composizioneDelleAreeDiFocusNegliAnni;
      case 'Modifica categoria':
        return modificaCategoria;
      case 'Archivia categoria':
        return archiviaCategoria;
      case 'Nome categoria...':
        return nomeCategoria;
      case 'Titolo obiettivo...':
        return titoloObiettivo;
      case 'Cambia categoria':
        return cambiaCategoria;
      case 'Scegli categoria':
        return scegliCategoria;
      case 'Punto di Forza':
        return puntoDiForza;
      case 'Mese Migliore':
        return meseMigliore;
      case 'Nessuno':
        return nessuno;
      case 'Tipologia Efficace':
        return tipologiaEfficace;
      case 'Totale Storico':
        return totaleStorico;
      case 'dal ':
        return dal2;
      case 'Successo Globale':
        return successoGlobale;
      case 'obiettivi completati':
        return obiettiviCompletati;
      case 'Anno Migliore':
        return annoMigliore;
      case 'Anno Più Produttivo':
        return annoPiuProduttivo;
      case 'obiettivi totali':
        return obiettiviTotali;
      case '🚀 Velocità di Esecuzione (Cumulativa)':
        return velocitaDiEsecuzioneCumulativa;
      case 'Confronto tra obiettivi pianificati e completati nel tempo':
        return confrontoTraObiettiviPianificatiECompletatiNelTempo;
      case '🎯 Performance Categorie':
        return performanceCategorie;
      case 'Tutto alla grande!':
        return tuttoAllaGrande;
      case 'WORST STREAK':
        return worstStreak;
      case 'FREQUENZA':
        return fREQUENZA;
      case 'BEST':
        return bEST;
      case 'WORST':
        return wORST;
      case 'Gap: ':
        return gap;
      case 'MOOD ALTO':
        return moodAlto;
      case 'Coefficiente':
        return coefficiente;
      case 'Co-occorrenza':
        return coOccorrenza;
      case 'Errore durante la creazione della categoria':
        return erroreDuranteLaCreazioneDellaCategoria;
      case 'Errore durante la modifica della categoria':
        return erroreDuranteLaModificaDellaCategoria;
      case 'Errore durante l\'archiviazione della categoria':
        return erroreDuranteLArchiviazioneDellaCategoria;
      case 'Errore durante l\'aggiornamento':
        return erroreDuranteLAggiornamento;
      case 'Errore durante l\'aggiornamento dello stato':
        return erroreDuranteLAggiornamentoDelloStato;
      case 'Errore durante il salvataggio dell\'umore':
        return erroreDuranteIlSalvataggioDellUmore;
      case 'Lavoro':
        return lavoro;
      case 'Salute':
        return salute;
      case 'Finanza':
        return finanza;
      case 'Relazioni':
        return relazioni;
      case 'Formazione':
        return formazione;
      case 'Hobby':
        return hobby;
      case 'Spirituale':
        return spirituale;
      case 'Altro':
        return altro;
      case 'Evolve • ':
        return evolve;
      case 'Errore durante il salvataggio':
        return erroreDuranteIlSalvataggio2;
      case 'Errore durante l\'eliminazione':
        return erroreDuranteLEliminazione2;
      case 'App Bloccata':
        return appBloccata;
      case 'Sblocca con i dati biometrici per continuare':
        return sbloccaConIDatiBiometriciPerContinuare;
      case 'Riprova':
        return riprova;
      case 'La tua tela è vuota':
        return laTuaTelaEVuota;
      case 'Crea la tua prima abitudine per iniziare a tracciare i tuoi progressi e costruire la tua routine.':
        return creaLaTuaPrimaAbitudinePerIniziareATracciareITuoiProgressiECostruireLaTuaRoutine;
      case 'Ho capito':
        return hoCapito;
      case 'Dettagli tecnici:':
        return dettagliTecnici;
      case 'Inserisci':
        return inserisci;
      case 'Aggiorna':
        return aggiorna;
      case 'Sblocca Evolve Pro':
        return sbloccaEvolvePro;
      case 'Porta il tuo sistema di abitudini al livello successivo':
        return portaIlTuoSistemaDiAbitudiniAlLivelloSuccessivo;
      case 'Analisi avanzata dei trend e suggerimenti intelligenti generati dall\'AI.':
        return analisiAvanzataDeiTrendESuggerimentiIntelligentiGeneratiDallAi;
      case 'Informazioni chiave per aumentare la tua produttività.':
        return informazioniChiavePerAumentareLaTuaProduttivita;
      case 'Visualizza grafici dettagliati e statistiche di performance profonde per ogni anno.':
        return visualizzaGraficiDettagliatiEStatisticheDiPerformanceProfondePerOgniAnno;
      case 'Crea e traccia tutti gli habits che desideri senza alcun limite.':
        return creaETracciaTuttiGliHabitsCheDesideriSenzaAlcunLimite;
      case 'Ottieni Pro a €4,99 / mese':
        return ottieniProA499Mese;
      case 'Forse più tardi':
        return forsePiuTardi;
      case 'Modifica Obiettivo':
        return modificaObiettivo;
      case 'Eliminare obiettivo?':
        return eliminareObiettivo;
      case 'Questa azione non può essere annullata.':
        return questaAzioneNonPuoEssereAnnullata;
      case 'Scegli colore':
        return scegliColore;
      case 'Crea':
        return crea;
      case 'Archiviare categoria?':
        return archiviareCategoria;
      case 'La categoria "label" non sarà più disponibile per nuovi obiettivi, ma resterà collegata a count obiettivi storici e alle statistiche.':
        return laCategoriaLabelNonSaraPiuDisponibilePerNuoviObiettiviMaResteraCollegataACountObiettiviStoriciEAlleStatistiche;
      case 'La categoria "label" non sarà più disponibile per nuovi obiettivi, ma resterà nello storico.':
        return laCategoriaLabelNonSaraPiuDisponibilePerNuoviObiettiviMaResteraNelloStorico;
      case 'Archivia':
        return archivia;
      case 'Seleziona Orario':
        return selezionaOrario;
      case 'Conferma Uscita':
        return confermaUscita;
      case 'Sei sicuro di voler uscire dal tuo account? Dovrai reinserire le tue credenziali per accedere nuovamente.':
        return seiSicuroDiVolerUscireDalTuoAccountDovraiReinserireLeTueCredenzialiPerAccedereNuovamente;
      case 'Esci':
        return esci;
      case 'Sei sicuro di voler eliminare':
        return seiSicuroDiVolerEliminare;
      case 'Colore troppo scuro per la visibilità in Dark Mode.':
        return coloreTroppoScuroPerLaVisibilitaInDarkMode;
      case 'Verifica Visibilità':
        return verificaVisibilita;
      case 'Riesci a leggere chiaramente questo testo e a vedere il pulsante qui sotto?':
        return riesciALeggereChiaramenteQuestoTestoEAVedereIlPulsanteQuiSotto;
      case 'SI, CONFERMA':
        return siConferma;
      case 'NO, TORNA INDIETRO':
        return noTornaIndietro;
      case 'Inserisci la tua nuova password.':
        return inserisciLaTuaNuovaPassword;
      case 'Inserisci la tua password attuale per continuare.':
        return inserisciLaTuaPasswordAttualePerContinuare;
      case 'Inserisci la password attuale.':
        return inserisciLaPasswordAttuale;
      case 'Utente non trovato.':
        return utenteNonTrovato;
      case 'La password attuale non è corretta.':
        return laPasswordAttualeNonECorretta;
      case 'Tutti i campi sono obbligatori.':
        return tuttiICampiSonoObbligatori;
      case 'La nuova password deve essere di almeno 8 caratteri.':
        return laNuovaPasswordDeveEssereDiAlmeno8Caratteri;
      case 'Le password non coincidono.':
        return lePasswordNonCoincidono;
      case 'Gestione Account e Dati':
        return gestioneAccountEDati;
      case 'Scegli l\'operazione che desideri effettuare. Entrambe le azioni richiedono conferma.':
        return scegliLOperazioneCheDesideriEffettuareEntrambeLeAzioniRichiedonoConferma;
      case 'Sei sicuro di voler eliminare tutti i tuoi dati? Questa azione non può essere annullata.':
        return seiSicuroDiVolerEliminareTuttiITuoiDatiQuestaAzioneNonPuoEssereAnnullata;
      case 'Elimina l\'Account':
        return eliminaLAccount2;
      case 'Sei sicuro di voler eliminare definitivamente il tuo account? Tutti i tuoi dati andranno persi per sempre.':
        return seiSicuroDiVolerEliminareDefinitivamenteIlTuoAccountTuttiITuoiDatiAndrannoPersiPerSempre;
      case 'I miei dati esportati da Growth':
        return iMieiDatiEsportatiDaGrowth;
      case 'Contesto dell\'AI':
        return contestoDellAi;
      case 'Scegli quali informazioni condividere con l\'assistente per personalizzare le risposte.':
        return scegliQualiInformazioniCondividereConLAssistentePerPersonalizzareLeRisposte;
      case 'Online per':
        return onlinePer;
      case 'Elimina chat':
        return eliminaChat;
      case 'Sei sicuro di voler eliminare tutti i messaggi? Questa azione non può essere annullata.':
        return seiSicuroDiVolerEliminareTuttiIMessaggiQuestaAzioneNonPuoEssereAnnullata;
      case 'Coach Virtuale':
        return coachVirtuale;
      case 'Pronto ad aiutarti a mantenere la disciplina.':
        return prontoAdAiutartiAMantenereLaDisciplina;
      case 'Per favore, seleziona almeno un contesto (abitudini o obiettivi) nelle impostazioni per poter parlare con il Coach.':
        return perFavoreSelezionaAlmenoUnContestoAbitudiniOObiettiviNelleImpostazioniPerPoterParlareConIlCoach;
      case 'Ciao! Sono il tuo Coach di Disciplina. Come posso aiutarti oggi?':
        return ciaoSonoIlTuoCoachDiDisciplinaComePossoAiutartiOggi;
      case 'Messaggio copiato':
        return messaggioCopiato;
      case 'Le abitudini chiave have un effetto "domino".':
        return leAbitudiniChiaveHaveUnEffettoDomino;
      case 'Monitora mood ed energia for insights più accurati.':
        return monitoraMoodEdEnergiaForInsightsPiuAccurati;
      case 'Crea il tuo ecosistema personale.':
        return creaIlTuoEcosistemaPersonale;
      case 'Inserisci la tua email.':
        return inserisciLaTuaEmail;
      case 'Email non valida.':
        return emailNonValida;
      case 'Inserisci la password.':
        return inserisciLaPassword;
      case 'Minimo 6 caratteri.':
        return minimo6Caratteri;
      case 'Password dimenticata?':
        return passwordDimenticata;
      case 'OPPURE':
        return oPPURE;
      case 'Continua con Apple':
        return continuaConApple;
      case 'Continua con Google':
        return continuaConGoogle;
      case 'Non hai un account?':
        return nonHaiUnAccount;
      case 'Hai già un account?':
        return haiGiaUnAccount;
      case 'Registrati':
        return registrati;
      case 'Accedi':
        return accedi;
      case 'Crea Account':
        return creaAccount;
      case 'Termini di Servizio':
        return terminiDiServizio;
      case 'Password':
        return password;
      case 'Daily Check-in':
        return dailyCheckIn;
      case 'Qui puoi registrare il tuo stato d\'animo quotidiano per tracciare il tuo benessere nel tempo e soprattutto correlarlo con il completamento dei tuoi obiettivi.':
        return quiPuoiRegistrareIlTuoStatoDAnimoQuotidianoPerTracciareIlTuoBenessereNelTempoESoprattuttoCorrelarloConIlCompletamentoDeiTuoiObiettivi;
      case 'Il tuo assistente personale. Chiedi consigli sulle tue abitudini. Lui è il tuo coach.':
        return ilTuoAssistentePersonaleChiediConsigliSulleTueAbitudiniLuiEIlTuoCoach;
      case 'Aggiungi, modifica o elimina le tue abitudini quotidiane che vuoi rispettare in modo semplice e veloce.':
        return aggiungiModificaOEliminaLeTueAbitudiniQuotidianeCheVuoiRispettareInModoSempliceEVeloce;
      case 'Viste Calendario':
        return visteCalendario;
      case 'Naviga tra le diverse visualizzazioni per vedere i tuoi progressi con varie alternative.':
        return navigaTraLeDiverseVisualizzazioniPerVedereITuoiProgressiConVarieAlternative;
      case 'Calendario':
        return calendario;
      case 'Basta cliccare su un giorno per visualizzare le abitudini giornaliere e spuntarle.':
        return bastaCliccareSuUnGiornoPerVisualizzareLeAbitudiniGiornaliereESpuntarle;
      case 'Passiamo agli Obiettivi':
        return passiamoAgliObiettivi;
      case 'La pagina dove puoi gestire i tuoi obiettivi a lungo termine e relative performance.':
        return laPaginaDovePuoiGestireITuoiObiettiviALungoTermineERelativePerformance;
      case 'Vai agli Obiettivi':
        return vaiAgliObiettivi;
      case 'Inizia il Tour':
        return iniziaIlTour;
      case 'Sei pronto!':
        return seiPronto;
      case 'Il viaggio inizia ora. Dai il massimo!':
        return ilViaggioIniziaOraDaiIlMassimo;
      case 'Inizia':
        return inizia;
      case 'Benvenuto in Evolve!':
        return benvenutoInEvolve;
      case 'Per iniziare, come possiamo chiamarti?':
        return perIniziareComePossiamoChiamarti;
      case 'Il tuo nome':
        return ilTuoNome;
      case 'Inizia ora':
        return iniziaOra;
      case 'Errore durante il salvataggio. Riprova.':
        return erroreDuranteIlSalvataggioRiprova;
      case 'Benvenuto in Evolve':
        return benvenutoInEvolve2;
      case 'Potrebbe essere uno STEP di NON RITORNO... Prima di iniziare però bisogna fare un tour per mostrarti come sfruttare al massimo l\'applicazione.':
        return potrebbeEssereUnoStepDiNonRitornoPrimaDiIniziarePeroBisognaFareUnTourPerMostrartiComeSfruttareAlMassimoLApplicazione;
      case 'Tipo di Pianificazione':
        return tipoDiPianificazione;
      case 'Qui puoi selezionare la visione temporale: Lifetime (per tutta la vita), Annuale, Trimestrale, Mensile o Settimanale.':
        return quiPuoiSelezionareLaVisioneTemporaleLifetimePerTuttaLaVitaAnnualeTrimestraleMensileOSettimanale;
      case 'Nuovo Obiettivo':
        return nuovoObiettivo;
      case 'Da qui puoi inserire un nuovo obiettivo. Potrai anche personalizzare le Categorie a tuo piacimento per organizzare tutto al meglio.':
        return daQuiPuoiInserireUnNuovoObiettivoPotraiAnchePersonalizzareLeCategorieATuoPiacimentoPerOrganizzareTuttoAlMeglio;
      case 'Completare o Fallire':
        return completareOFallire;
      case 'Categoria':
        return categoria;
      case 'Posticipare':
        return posticipare;
      case 'Modifica':
        return modifica;
      case 'Elimina':
        return elimina;
      case 'Analisi e Statistiche':
        return analisiEStatistiche;
      case 'Continua':
        return continua;
      case 'Statistiche Abitudini':
        return statisticheAbitudini;
      case 'Per vedere le statistiche delle tue abitudini giornaliere, puoi spostarti in questa sezione.':
        return perVedereLeStatisticheDelleTueAbitudiniGiornalierePuoiSpostartiInQuestaSezione;
      case 'Passa alle Statistiche':
        return passaAlleStatistiche;
      case 'Indietro':
        return indietro;
      case 'Fine':
        return fine;
      case 'Avanti':
        return avanti;
      case 'Obiettivo Tutorial':
        return obiettivoTutorial;
      case 'I miei obiettivi':
        return iMieiObiettivi;
      case 'Filtra per Abitudine':
        return filtraPerAbitudine;
      case 'Sezioni Statistiche':
        return sezioniStatistiche;
      case 'it':
        return italianLanguage;
      case 'en':
        return englishLanguage;
      case 'system':
        return systemLanguage;
      case 'Accesso non riuscito. Controlla email e password.':
        return authAccessFailed;
      case 'Errore di rete. Riprova.':
        return authNetworkRetry;
      case 'Controlla la tua email per confermare la registrazione.':
        return authConfirmRegistrationEmail;
      case 'Impossibile aggiornare il profilo.':
        return authUpdateProfileFailed;
      case 'Email o password errata.':
        return authInvalidCredentials;
      case 'Controlla la tua email e clicca il link di conferma.':
        return authEmailNotConfirmed;
      case 'Esiste già un account con questa email. Prova ad accedere.':
        return authAccountAlreadyExists;
      case 'La password deve essere di almeno 6 caratteri.':
        return authPasswordMinSix;
      case 'Errore. Riprova.':
        return genericErrorRetry;
    }
    return key;
  }
}
