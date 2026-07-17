import { startOfMonth, startOfWeek, differenceInWeeks, getDay } from 'date-fns';

/**
 * Calcola la settimana logica/intuitiva del mese.
 * 
 * La logica è progettata per essere user-friendly:
 * - La "Settimana 1" include tutti i giorni dalla domenica (o primo giorno del mese)
 *   fino alla fine della prima settimana lavorativa completa.
 * - Se il mese inizia di domenica, quella domenica + i giorni lun-sab successivi
 *   formano la "Settimana 1".
 * 
 * Esempio Febbraio 2026:
 * - 1 Feb (Dom) → Settimana 1
 * - 2 Feb (Lun) → Settimana 1 (stesso blocco logico)
 * - 8 Feb (Dom) → Settimana 1
 * - 9 Feb (Lun) → Settimana 2
 * 
 * @param date - La data da analizzare
 * @returns Il numero della settimana (1-based)
 */
export function getLogicalWeekOfMonth(date: Date): number {
    const monthStart = startOfMonth(date);
    const dayOfMonthStart = getDay(monthStart); // 0 = Sunday, 1 = Monday, ...

    // Calcola il primo lunedì del mese o il lunedì successivo al primo giorno
    const firstMondayOfMonth = startOfWeek(monthStart, { weekStartsOn: 1 });

    // Se firstMondayOfMonth è prima dell'inizio del mese, il primo lunedì "nel mese"
    // è 7 giorni dopo
    const isMondayInCurrentMonth = firstMondayOfMonth.getMonth() === monthStart.getMonth();
    const effectiveFirstMonday = isMondayInCurrentMonth
        ? firstMondayOfMonth
        : new Date(firstMondayOfMonth.getTime() + 7 * 24 * 60 * 60 * 1000);

    // Caso speciale: la data è PRIMA del primo lunedì del mese
    // Questi giorni (es. 1 Feb domenica) appartengono alla Settimana 1
    if (date < effectiveFirstMonday) {
        return 1;
    }

    // Calcola il lunedì della settimana corrente della data
    const dateWeekStart = startOfWeek(date, { weekStartsOn: 1 });

    // Conta quante settimane complete dalla prima settimana con lunedì nel mese
    const weeksDiff = differenceInWeeks(dateWeekStart, effectiveFirstMonday);

    // Calcoliamo i giorni "orfani" all'inizio del mese prima del primo vero lunedì
    const daysBeforeFirstMonday = Math.round((effectiveFirstMonday.getTime() - monthStart.getTime()) / (1000 * 60 * 60 * 24));

    // Di base, il primo venero lunedì segna l'inizio della Settimana 1
    let baseWeek = 1;

    // Tuttavia, se ci sono giorni prima del primo lunedì...
    if (daysBeforeFirstMonday > 1) {
        // Se i giorni sono > 1 (il mese inizia di sab, ven, gio, mer, mar)
        // Allora questi giorni costituiscono da soli la "Settimana 1"
        // di conseguenza, il primo lunedì segna l'inizio della "Settimana 2".
        baseWeek = 2;
    } 
    // Se daysBeforeFirstMonday == 1 (inizia di domenica), come da specifica, 
    // la domenica viene accorpata alla prima settimana intera successiva.
    // Quindi baseWeek rimane 1.

    return weeksDiff + baseWeek;
}

/**
 * Calcola il numero totale di settimane logiche in un mese.
 * 
 * @param date - Una data nel mese da analizzare (tipicamente il primo del mese)
 * @returns Il numero totale di settimane nel mese
 */
export function getLogicalWeeksInMonth(date: Date): number {
    // Prendi l'ultimo giorno del mese
    const endOfMonthDate = new Date(date.getFullYear(), date.getMonth() + 1, 0);
    // La settimana dell'ultimo giorno ci dice quante settimane ha il mese
    return getLogicalWeekOfMonth(endOfMonthDate);
}
