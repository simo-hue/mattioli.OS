///
/// Generated file. Do not edit.
///
// coverage:ignore-file
// ignore_for_file: type=lint, unused_import
// dart format off

part of 'translations.g.dart';

// Path: <root>
typedef TranslationsEn = Translations; // ignore: unused_element
class Translations with BaseTranslations<AppLocale, Translations> {
	/// Returns the current translations of the given [context].
	///
	/// Usage:
	/// final t = Translations.of(context);
	static Translations of(BuildContext context) => InheritedLocaleData.of<AppLocale, Translations>(context).translations;

	/// You can call this constructor and build your own translation instance of this locale.
	/// Constructing via the enum [AppLocale.build] is preferred.
	Translations({Map<String, Node>? overrides, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver, TranslationMetadata<AppLocale, Translations>? meta})
		: assert(overrides == null, 'Set "translation_overrides: true" in order to enable this feature.'),
		  $meta = meta ?? TranslationMetadata(
		    locale: AppLocale.en,
		    overrides: overrides ?? {},
		    cardinalResolver: cardinalResolver,
		    ordinalResolver: ordinalResolver,
		  ) {
		$meta.setFlatMapFunction(_flatMapFunction);
	}

	/// Metadata for the translations of <en>.
	@override final TranslationMetadata<AppLocale, Translations> $meta;

	/// Access flat map
	dynamic operator[](String key) => $meta.getTranslation(key);

	late final Translations _root = this; // ignore: unused_field

	Translations $copyWith({TranslationMetadata<AppLocale, Translations>? meta}) => Translations(meta: meta ?? this.$meta);

	// Translations
	late final Translations$auth$en auth = Translations$auth$en.internal(_root);
	late final Translations$privateData$en privateData = Translations$privateData$en.internal(_root);
	late final Translations$icloudSync$en icloudSync = Translations$icloudSync$en.internal(_root);
	late final Translations$privateRecovery$en privateRecovery = Translations$privateRecovery$en.internal(_root);
	late final Translations$namePrompt$en namePrompt = Translations$namePrompt$en.internal(_root);
	late final Translations$nav$en nav = Translations$nav$en.internal(_root);
	late final Translations$shell$en shell = Translations$shell$en.internal(_root);
	late final Translations$common$en common = Translations$common$en.internal(_root);
	late final Translations$form$en form = Translations$form$en.internal(_root);
	late final Translations$createGoal$en createGoal = Translations$createGoal$en.internal(_root);
	late final Translations$createHabit$en createHabit = Translations$createHabit$en.internal(_root);
	late final Translations$macroGoals$en macroGoals = Translations$macroGoals$en.internal(_root);
	late final Translations$statistics$en statistics = Translations$statistics$en.internal(_root);
	late final Translations$goalState$en goalState = Translations$goalState$en.internal(_root);
	late final Translations$dueLabel$en dueLabel = Translations$dueLabel$en.internal(_root);
	late final Translations$dashboard$en dashboard = Translations$dashboard$en.internal(_root);
	late final Translations$stats$en stats = Translations$stats$en.internal(_root);
	late final Translations$habitsPage$en habitsPage = Translations$habitsPage$en.internal(_root);

	/// en: 'Work'
	String get lavoro => 'Work';

	/// en: 'Health'
	String get salute => 'Health';

	/// en: 'Finance'
	String get finanza => 'Finance';

	/// en: 'Relationships'
	String get relazioni => 'Relationships';

	/// en: 'Education'
	String get formazione => 'Education';

	/// en: 'Hobbies'
	String get hobby => 'Hobbies';

	/// en: 'Spiritual'
	String get spirituale => 'Spiritual';

	/// en: 'Other'
	String get altro => 'Other';

	late final Translations$goalsPage$en goalsPage = Translations$goalsPage$en.internal(_root);
	late final Translations$goalsStats$en goalsStats = Translations$goalsStats$en.internal(_root);
	late final Translations$ai$en ai = Translations$ai$en.internal(_root);
	late final Translations$aiCoach$en aiCoach = Translations$aiCoach$en.internal(_root);
	late final Translations$settingsPage$en settingsPage = Translations$settingsPage$en.internal(_root);
	late final Translations$consent$en consent = Translations$consent$en.internal(_root);
	late final Translations$notifications$en notifications = Translations$notifications$en.internal(_root);
	late final Translations$privacy$en privacy = Translations$privacy$en.internal(_root);
	late final Translations$consentPage$en consentPage = Translations$consentPage$en.internal(_root);
	late final Translations$notif$en notif = Translations$notif$en.internal(_root);
	late final Translations$biometricGate$en biometricGate = Translations$biometricGate$en.internal(_root);
	late final Translations$sync$en sync = Translations$sync$en.internal(_root);
	late final Translations$subscriptionCtrl$en subscriptionCtrl = Translations$subscriptionCtrl$en.internal(_root);
	late final Translations$authCtrl$en authCtrl = Translations$authCtrl$en.internal(_root);
	late final Translations$proModal$en proModal = Translations$proModal$en.internal(_root);
	late final Translations$appLogs$en appLogs = Translations$appLogs$en.internal(_root);
	late final Translations$coachSettings$en coachSettings = Translations$coachSettings$en.internal(_root);
	late final Translations$tour$en tour = Translations$tour$en.internal(_root);
	late final Translations$palette$en palette = Translations$palette$en.internal(_root);
}

// Path: auth
class Translations$auth$en {
	Translations$auth$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Continue privately on this Mac'
	String get continuePrivately => 'Continue privately on this Mac';

	/// en: 'Log In'
	String get signIn => 'Log In';

	/// en: 'Sign Up'
	String get register => 'Sign Up';

	/// en: 'OR'
	String get or => 'OR';

	/// en: 'Password'
	String get password => 'Password';

	/// en: 'Forgot password?'
	String get forgotPassword => 'Forgot password?';

	/// en: 'Already have an account?'
	String get haveAccount => 'Already have an account?';

	/// en: 'Don't have an account?'
	String get noAccount => 'Don\'t have an account?';

	/// en: 'Continue with Apple'
	String get continueWithApple => 'Continue with Apple';

	/// en: 'Continue with Google'
	String get continueWithGoogle => 'Continue with Google';

	/// en: 'Read Privacy Policy'
	String get readPrivacyPolicy => 'Read Privacy Policy';

	/// en: 'First Name'
	String get nameLabel => 'First Name';

	/// en: 'Enter a valid email'
	String get invalidEmail => 'Enter a valid email';

	/// en: 'Check your email to confirm your registration.'
	String get confirmEmail => 'Check your email to confirm your registration.';

	/// en: 'Email sent. Check your inbox.'
	String get resetSent => 'Email sent. Check your inbox.';

	/// en: 'Sign in to Evolve'
	String get signInTitle => 'Sign in to Evolve';

	/// en: 'Create your account'
	String get signUpTitle => 'Create your account';

	/// en: 'Recover password'
	String get resetTitle => 'Recover password';

	/// en: 'Email'
	String get emailLabel => 'Email';

	/// en: 'Use at least 8 characters.'
	String get passwordMin8 => 'Use at least 8 characters.';

	/// en: 'Send recovery link'
	String get sendResetLink => 'Send recovery link';
}

// Path: privateData
class Translations$privateData$en {
	Translations$privateData$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Delete private data'
	String get deleteTitle => 'Delete private data';

	/// en: 'Are you sure you want to delete the entire encrypted local database? This action is irreversible and the data cannot be recovered.'
	String get deleteMessage => 'Are you sure you want to delete the entire encrypted local database? This action is irreversible and the data cannot be recovered.';

	/// en: 'Private data deleted.'
	String get deleteSuccess => 'Private data deleted.';

	/// en: 'Operation failed.'
	String get deleteFailed => 'Operation failed.';

	/// en: 'Export complete'
	String get exportDoneTitle => 'Export complete';

	/// en: 'The JSON is on the clipboard: Linux does not support file sharing.'
	String get exportDoneClipboard => 'The JSON is on the clipboard: Linux does not support file sharing.';

	/// en: 'The JSON was sent to the share sheet.'
	String get exportDoneShare => 'The JSON was sent to the share sheet.';
}

// Path: icloudSync
class Translations$icloudSync$en {
	Translations$icloudSync$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'iCloud Sync'
	String get title => 'iCloud Sync';

	/// en: 'Enable iCloud Sync'
	String get enableTitle => 'Enable iCloud Sync';

	/// en: 'Sync now'
	String get syncNow => 'Sync now';

	/// en: 'End-to-end encrypted'
	String get disclosureTitle => 'End-to-end encrypted';

	/// en: 'Your private data syncs only through your own iCloud account, end-to-end encrypted — never through our servers. The encryption key lives in your iCloud Keychain; if you turn iCloud Keychain off, synced data can't be recovered.'
	String get disclosureBody => 'Your private data syncs only through your own iCloud account, end-to-end encrypted — never through our servers. The encryption key lives in your iCloud Keychain; if you turn iCloud Keychain off, synced data can\'t be recovered.';

	/// en: 'Enable'
	String get disclosureAccept => 'Enable';

	/// en: 'Up to date'
	String get statusIdle => 'Up to date';

	/// en: 'Not everything has synced'
	String get statusNotSynced => 'Not everything has synced';

	/// en: 'Syncing…'
	String get statusSyncing => 'Syncing…';

	/// en: 'Sync is off'
	String get statusOff => 'Sync is off';

	/// en: 'Sign in to iCloud to sync'
	String get statusNoAccount => 'Sign in to iCloud to sync';

	/// en: 'iCloud is unavailable right now'
	String get statusUnavailable => 'iCloud is unavailable right now';

	/// en: 'Waiting for iCloud Keychain — make sure the app on your iPhone is up to date'
	String get statusWaitingKeychain => 'Waiting for iCloud Keychain — make sure the app on your iPhone is up to date';

	/// en: 'Never synced'
	String get lastSyncedNever => 'Never synced';

	/// en: 'Last synced {time}'
	String lastSyncedAt({required Object time}) => 'Last synced ${time}';

	/// en: 'iCloud Sync is on: this also deletes the synced copy in your iCloud and turns sync off. Other devices keep their local copy — run this on each device to erase everywhere.'
	String get deleteSyncNote => 'iCloud Sync is on: this also deletes the synced copy in your iCloud and turns sync off. Other devices keep their local copy — run this on each device to erase everywhere.';

	/// en: 'iCloud sync is off — your habits live only on this device and are lost if you reset or replace it.'
	String get bannerText => 'iCloud sync is off — your habits live only on this device and are lost if you reset or replace it.';

	/// en: 'Turn on'
	String get bannerAction => 'Turn on';

	/// en: 'Sync details'
	String get detailsTitle => 'Sync details';

	/// en: 'Everything uploaded'
	String get detailsAllSynced => 'Everything uploaded';

	/// en: '{count} items waiting to upload'
	String detailsPending({required Object count}) => '${count} items waiting to upload';

	/// en: '{count} items failed to upload'
	String detailsFailed({required Object count}) => '${count} items failed to upload';

	/// en: 'Copy report'
	String get detailsCopy => 'Copy report';

	/// en: 'Report copied'
	String get detailsCopied => 'Report copied';

	/// en: 'Some iCloud data can't be read'
	String get keySplitTitle => 'Some iCloud data can\'t be read';

	/// en: '{count} records in iCloud were encrypted on another device with a different key, so this device can't read them. Reset sync from whichever device holds the data you want to keep.'
	String keySplitBody({required Object count}) => '${count} records in iCloud were encrypted on another device with a different key, so this device can\'t read them. Reset sync from whichever device holds the data you want to keep.';

	/// en: 'Reset sync from this device'
	String get resetFromDevice => 'Reset sync from this device';

	/// en: 'Replace everything in iCloud with this device's data'
	String get resetFromDeviceDetail => 'Replace everything in iCloud with this device\'s data';

	/// en: 'This erases everything currently stored in iCloud and uploads this device's data in its place. Your other devices will then download this copy. Only do this from the device that holds the data you want to keep. This cannot be undone.'
	String get resetFromDeviceConfirm => 'This erases everything currently stored in iCloud and uploads this device\'s data in its place. Your other devices will then download this copy. Only do this from the device that holds the data you want to keep. This cannot be undone.';

	/// en: 'Sync reset. This device's data is now the copy in iCloud.'
	String get resetFromDeviceDone => 'Sync reset. This device\'s data is now the copy in iCloud.';

	/// en: 'Waiting for the encryption key from your other device'
	String get statusWaitingKey => 'Waiting for the encryption key from your other device';

	/// en: 'Start fresh from this device'
	String get forceEnableTitle => 'Start fresh from this device';

	/// en: 'Another device's data is already in iCloud, but its encryption key hasn't reached this device yet. Waiting is usually enough — it can take a few minutes. Starting fresh erases what is in iCloud and replaces it with this device's data. This cannot be undone.'
	String get forceEnableBody => 'Another device\'s data is already in iCloud, but its encryption key hasn\'t reached this device yet. Waiting is usually enough — it can take a few minutes. Starting fresh erases what is in iCloud and replaces it with this device\'s data. This cannot be undone.';

	/// en: 'Start fresh'
	String get forceEnable => 'Start fresh';
}

// Path: privateRecovery
class Translations$privateRecovery$en {
	Translations$privateRecovery$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Preparing your private space…'
	String get preparing => 'Preparing your private space…';

	/// en: 'Couldn't unlock the local database — restored your data from iCloud.'
	String get restoredFromCloudToast => 'Couldn\'t unlock the local database — restored your data from iCloud.';

	/// en: 'Waiting for iCloud'
	String get waitingTitle => 'Waiting for iCloud';

	/// en: 'Sync is on, but your encryption key hasn't arrived from iCloud Keychain yet. Give it a moment, then retry.'
	String get waitingMessage => 'Sync is on, but your encryption key hasn\'t arrived from iCloud Keychain yet. Give it a moment, then retry.';

	/// en: 'Can't unlock private data'
	String get lockedTitle => 'Can\'t unlock private data';

	/// en: 'This device can't unlock your local private database — its encryption key is missing — and iCloud sync is off, so there's no cloud copy to restore. You can reset and start fresh.'
	String get lockedMessageLocalOnly => 'This device can\'t unlock your local private database — its encryption key is missing — and iCloud sync is off, so there\'s no cloud copy to restore. You can reset and start fresh.';

	/// en: 'This device can't unlock your local private database. iCloud sync is on but the account is unavailable — sign in to iCloud, then retry.'
	String get lockedMessageICloudUnavailable => 'This device can\'t unlock your local private database. iCloud sync is on but the account is unavailable — sign in to iCloud, then retry.';

	/// en: 'Couldn't open private mode'
	String get errorTitle => 'Couldn\'t open private mode';

	/// en: 'Something went wrong opening your private database. Retry, or reset it and start fresh.'
	String get errorMessage => 'Something went wrong opening your private database. Retry, or reset it and start fresh.';

	/// en: 'Have this data on another device? Turn on iCloud sync in Settings after resetting to pull it here.'
	String get enableSyncHint => 'Have this data on another device? Turn on iCloud sync in Settings after resetting to pull it here.';

	/// en: 'Retry'
	String get retry => 'Retry';

	/// en: 'Reset & start fresh'
	String get resetFresh => 'Reset & start fresh';

	/// en: 'Back to sign in'
	String get backToSignIn => 'Back to sign in';
}

// Path: namePrompt
class Translations$namePrompt$en {
	Translations$namePrompt$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'What is your name?'
	String get title => 'What is your name?';

	/// en: 'Enter your name to personalize the dashboard.'
	String get subtitle => 'Enter your name to personalize the dashboard.';

	/// en: 'e.g. Simo'
	String get hint => 'e.g. Simo';

	/// en: 'Save and continue'
	String get save => 'Save and continue';
}

// Path: nav
class Translations$nav$en {
	Translations$nav$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Overview'
	String get overview => 'Overview';

	/// en: 'Habits'
	String get habits => 'Habits';

	/// en: 'Statistics'
	String get insights => 'Statistics';

	/// en: 'Goals'
	String get goals => 'Goals';

	/// en: 'AI Coach'
	String get coach => 'AI Coach';

	/// en: 'Settings'
	String get settings => 'Settings';
}

// Path: shell
class Translations$shell$en {
	Translations$shell$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Sync pending'
	String get syncPending => 'Sync pending';

	/// en: 'Syncing'
	String get syncing => 'Syncing';

	/// en: 'Synced'
	String get synced => 'Synced';

	/// en: 'Sync'
	String get syncTooltip => 'Sync';

	/// en: 'Search or navigate'
	String get searchHint => 'Search or navigate';

	/// en: 'Search a section...'
	String get searchSectionHint => 'Search a section...';
}

// Path: common
class Translations$common$en {
	Translations$common$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	late final Translations$common$actions$en actions = Translations$common$actions$en.internal(_root);
	List<String> get months => [
		'January',
		'February',
		'March',
		'April',
		'May',
		'June',
		'July',
		'August',
		'September',
		'October',
		'November',
		'December',
	];
	List<String> get weekdayInitials => [
		'M',
		'T',
		'W',
		'T',
		'F',
		'S',
		'S',
	];
	late final Translations$common$calendarView$en calendarView = Translations$common$calendarView$en.internal(_root);
	List<String> get weekdaysLong => [
		'Monday',
		'Tuesday',
		'Wednesday',
		'Thursday',
		'Friday',
		'Saturday',
		'Sunday',
	];

	/// en: 'None'
	String get none => 'None';

	/// en: 'Habits'
	String get habits => 'Habits';

	late final Translations$common$status$en status = Translations$common$status$en.internal(_root);

	/// en: 'Total'
	String get total => 'Total';

	/// en: 'Completed'
	String get completed => 'Completed';

	/// en: 'Something went wrong'
	String get unexpectedErrorTitle => 'Something went wrong';

	/// en: 'An unexpected error occurred. Please try again.'
	String get unexpectedErrorMessage => 'An unexpected error occurred. Please try again.';
}

// Path: form
class Translations$form$en {
	Translations$form$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Title'
	String get title => 'Title';

	/// en: 'Category'
	String get category => 'Category';

	/// en: 'Color'
	String get color => 'Color';

	/// en: 'Add'
	String get add => 'Add';
}

// Path: createGoal
class Translations$createGoal$en {
	Translations$createGoal$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'New Goal'
	String get title => 'New Goal';

	/// en: 'Define your next milestone.'
	String get subtitle => 'Define your next milestone.';

	/// en: 'e.g. Launch the new product'
	String get titleHint => 'e.g. Launch the new product';

	/// en: 'e.g. Work'
	String get categoryHint => 'e.g. Work';

	/// en: 'Timeline'
	String get timeline => 'Timeline';

	/// en: 'This Week'
	String get thisWeek => 'This Week';

	/// en: 'This Month'
	String get thisMonth => 'This Month';

	/// en: 'This Quarter'
	String get thisQuarter => 'This Quarter';

	/// en: 'This Year'
	String get thisYear => 'This Year';

	/// en: 'Long-term (Lifetime)'
	String get longTerm => 'Long-term (Lifetime)';

	/// en: 'Whole life'
	String get dueLifetime => 'Whole life';

	/// en: 'By {year}'
	String dueByYear({required Object year}) => 'By ${year}';

	/// en: 'Goal'
	String get defaultCategory => 'Goal';

	/// en: 'When'
	String get periodWhen => 'When';
}

// Path: createHabit
class Translations$createHabit$en {
	Translations$createHabit$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'New Habit'
	String get title => 'New Habit';

	/// en: 'Define your new habit.'
	String get subtitle => 'Define your new habit.';

	/// en: 'e.g. Meditation'
	String get titleHint => 'e.g. Meditation';

	/// en: 'Weekly frequency'
	String get weeklyFrequency => 'Weekly frequency';
}

// Path: macroGoals
class Translations$macroGoals$en {
	Translations$macroGoals$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	late final Translations$macroGoals$types$en types = Translations$macroGoals$types$en.internal(_root);

	/// en: 'Quarter {quarter}'
	String quarterNumber({required Object quarter}) => 'Quarter ${quarter}';

	/// en: 'Add lifetime goal...'
	String get addLifetimeGoal => 'Add lifetime goal...';

	/// en: 'Add annual goal...'
	String get addAnnualGoal => 'Add annual goal...';

	/// en: 'Add quarterly goal...'
	String get addQuarterlyGoal => 'Add quarterly goal...';

	/// en: 'Add monthly goal...'
	String get addMonthlyGoal => 'Add monthly goal...';

	/// en: 'Add weekly goal...'
	String get addWeeklyGoal => 'Add weekly goal...';

	/// en: 'COMPLETED'
	String get completed => 'COMPLETED';

	/// en: 'FAILED'
	String get failed => 'FAILED';

	/// en: 'Create'
	String get create => 'Create';

	/// en: 'Strength'
	String get strength => 'Strength';

	/// en: 'Best Month'
	String get bestMonth => 'Best Month';

	/// en: 'success rate'
	String get successRate2 => 'success rate';

	/// en: 'Effective Type'
	String get effectiveType => 'Effective Type';

	/// en: 'Historical Total'
	String get historicalTotal => 'Historical Total';

	/// en: 'from'
	String get from_ => 'from';

	/// en: 'Global Success'
	String get globalSuccess => 'Global Success';

	/// en: 'completed goals'
	String get completedGoals => 'completed goals';

	/// en: 'Best Year'
	String get bestYear => 'Best Year';

	/// en: 'Most Productive Year'
	String get mostProductiveYear => 'Most Productive Year';

	/// en: 'total goals'
	String get totalGoals => 'total goals';

	/// en: 'All years'
	String get allYears => 'All years';

	/// en: 'SELECT YEAR'
	String get selectYearHeader => 'SELECT YEAR';

	/// en: 'Completions'
	String get completions => 'Completions';

	/// en: 'Success'
	String get success2 => 'Success';

	/// en: 'Archive category?'
	String get archiveCategory2 => 'Archive category?';

	/// en: 'The category "{label}" will no longer be available for new goals, but stays linked to {count} historical goals and your statistics.'
	String categoryUnavailableLinked({required Object label, required Object count}) => 'The category "${label}" will no longer be available for new goals, but stays linked to ${count} historical goals and your statistics.';

	/// en: 'The category "{label}" will no longer be available for new goals, but stays in your history.'
	String categoryUnavailableArchived({required Object label}) => 'The category "${label}" will no longer be available for new goals, but stays in your history.';

	/// en: 'Archive'
	String get archive => 'Archive';

	/// en: 'Create new category'
	String get createNewCategory => 'Create new category';
}

// Path: statistics
class Translations$statistics$en {
	Translations$statistics$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Completed'
	String get completed2 => 'Completed';

	/// en: 'Not completed'
	String get notCompleted => 'Not completed';

	/// en: 'of completion'
	String get ofCompletion => 'of completion';

	/// en: 'Growth'
	String get growth => 'Growth';

	/// en: 'Decline'
	String get decline => 'Decline';

	/// en: 'Strongest day'
	String get strongestDay => 'Strongest day';

	/// en: 'Weakest day'
	String get weakestDay => 'Weakest day';

	/// en: 'Worst Negative Streak'
	String get worstNegativeStreak => 'Worst Negative Streak';

	/// en: 'missed consecutive days'
	String get missedConsecutiveDays => 'missed consecutive days';

	/// en: 'Broken Streaks'
	String get brokenStreaks => 'Broken Streaks';

	/// en: 'No broken streaks recorded'
	String get noBrokenStreaks => 'No broken streaks recorded';

	/// en: 'Started on'
	String get startedOn => 'Started on';

	/// en: 'Mood Correlation'
	String get moodCorrelation => 'Mood Correlation';

	/// en: 'Avg Mood (✓)'
	String get avgMood => 'Avg Mood (✓)';

	/// en: 'Avg Energy (✓)'
	String get avgEnergy => 'Avg Energy (✓)';

	/// en: 'on completed days'
	String get onCompletedDays => 'on completed days';

	/// en: 'Resilient'
	String get resilient => 'Resilient';

	/// en: 'Completed vs Missed'
	String get completedVsMissed => 'Completed vs Missed';

	/// en: 'Mood'
	String get mood2 => 'Mood';

	/// en: 'Energy'
	String get energy => 'Energy';

	/// en: 'Performance per Level'
	String get performancePerLevel => 'Performance per Level';

	/// en: 'With High Mood'
	String get withHighMood => 'With High Mood';

	/// en: 'With Low Mood'
	String get withLowMood => 'With Low Mood';

	/// en: 'The analysis shows how your consistency is influenced by your mood and energy.'
	String get moodEnergyAnalysis => 'The analysis shows how your consistency is influenced by your mood and energy.';

	/// en: 'Missed'
	String get missed2 => 'Missed';

	/// en: 'positive'
	String get positive => 'positive';

	/// en: 'neutral'
	String get neutral => 'neutral';

	/// en: 'high'
	String get high => 'high';

	/// en: 'low'
	String get low => 'low';

	/// en: 'Skipped'
	String get skipped => 'Skipped';

	/// en: 'Critical Habits'
	String get criticalHabits => 'Critical Habits';

	/// en: 'Best Habits'
	String get bestHabitsTitle => 'Best Habits';

	/// en: 'The habits that are getting worse the most.'
	String get worseningHabitsDescription => 'The habits that are getting worse the most.';

	/// en: 'Everything is great!'
	String get everythingIsGreat => 'Everything is great!';

	/// en: 'All your habits are maintaining or improving their trend. Keep going.'
	String get allHabitsStableDescription => 'All your habits are maintaining or improving their trend. Keep going.';

	/// en: 'You completed this habit {rate}% of the time in the selected period.'
	String habitCompletionPeriodDescription({required Object rate}) => 'You completed this habit ${rate}% of the time in the selected period.';

	/// en: 'This habit lost {drop}% consistency in the last week compared with the previous one.'
	String habitLostConsistencyDescription({required Object drop}) => 'This habit lost ${drop}% consistency in the last week compared with the previous one.';

	/// en: 'Negative Streak'
	String get negativeStreak => 'Negative Streak';

	/// en: 'Current Streak'
	String get currentStreak2 => 'Current Streak';

	/// en: 'Improvement Areas'
	String get improvementAreas => 'Improvement Areas';

	/// en: 'Habits requiring more attention.'
	String get habitsRequiringMoreAttention => 'Habits requiring more attention.';

	/// en: 'Failure Analysis'
	String get failureAnalysis => 'Failure Analysis';

	/// en: 'Frequency and patterns of your missed days.'
	String get missedDaysPattern => 'Frequency and patterns of your missed days.';

	/// en: 'Recovery Patterns'
	String get recoveryPatterns => 'Recovery Patterns';

	/// en: 'How quickly you get back on track after a slip.'
	String get recoverySpeed => 'How quickly you get back on track after a slip.';

	/// en: 'Avg Recovery Time'
	String get avgRecoveryTime => 'Avg Recovery Time';

	/// en: 'WORST STREAK'
	String get worstStreak => 'WORST STREAK';

	/// en: 'FREQUENCY'
	String get frequency => 'FREQUENCY';

	/// en: 'd'
	String get daysShortUnit => 'd';

	/// en: 'month'
	String get perMonthUnit => 'month';

	/// en: 'succ.'
	String get succ => 'succ.';

	/// en: 'BLACK DAY'
	String get blackDay => 'BLACK DAY';

	/// en: 'Correlations with'
	String get correlationsWith => 'Correlations with';

	/// en: 'How this habit relates to others'
	String get howThisHabitRelatesToOthers => 'How this habit relates to others';

	/// en: 'Positive Correlations'
	String get positiveCorrelations => 'Positive Correlations';

	/// en: 'Negative Correlations'
	String get negativeCorrelations => 'Negative Correlations';

	/// en: 'No significant positive correlation'
	String get noSignificantPositiveCorrelation => 'No significant positive correlation';

	/// en: 'No significant negative correlation'
	String get noSignificantNegativeCorrelation => 'No significant negative correlation';

	/// en: '{percentage}% together'
	String habitTogetherPercent({required Object percentage}) => '${percentage}% together';

	/// en: 'When you complete "{currentGoal}", you have a {percentage}% chance of also completing "{otherGoal}".'
	String habitPositiveCorrelationDescription({required Object currentGoal, required Object percentage, required Object otherGoal}) => 'When you complete "${currentGoal}", you have a ${percentage}% chance of also completing "${otherGoal}".';

	/// en: 'When you complete "{currentGoal}", you only have a {percentage}% chance of also completing "{otherGoal}".'
	String habitNegativeCorrelationDescription({required Object currentGoal, required Object percentage, required Object otherGoal}) => 'When you complete "${currentGoal}", you only have a ${percentage}% chance of also completing "${otherGoal}".';

	/// en: 'Weekly Trend'
	String get weeklyTrend => 'Weekly Trend';

	/// en: 'Monthly Trend'
	String get monthlyTrend => 'Monthly Trend';

	/// en: 'Yearly Trend'
	String get yearlyTrend => 'Yearly Trend';

	/// en: 'Performance Evolution'
	String get performanceEvolution => 'Performance Evolution';

	/// en: 'Global Trend'
	String get globalTrend => 'Global Trend';

	/// en: 'Total'
	String get total => 'Total';

	/// en: 'All'
	String get all => 'All';

	/// en: 'Not enough data to generate alerts.'
	String get noDataForAlerts => 'Not enough data to generate alerts.';

	/// en: 'Missed'
	String get missed => 'Missed';
}

// Path: goalState
class Translations$goalState$en {
	Translations$goalState$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'In progress'
	String get active => 'In progress';
}

// Path: dueLabel
class Translations$dueLabel$en {
	Translations$dueLabel$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Life goal'
	String get lifetime => 'Life goal';

	/// en: 'Annual goal'
	String get annual => 'Annual goal';

	/// en: 'Quarter'
	String get quarter => 'Quarter';
}

// Path: dashboard
class Translations$dashboard$en {
	Translations$dashboard$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Mood'
	String get mood => 'Mood';

	/// en: 'Energy'
	String get energy => 'Energy';

	/// en: 'Good morning'
	String get goodMorning => 'Good morning';

	/// en: 'Good afternoon'
	String get goodAfternoon => 'Good afternoon';

	/// en: 'Good evening'
	String get goodEvening => 'Good evening';

	/// en: 'Manager'
	String get manager => 'Manager';

	/// en: 'AI Chat'
	String get aiChat => 'AI Chat';

	/// en: 'consecutive days'
	String get consecutiveDays => 'consecutive days';

	/// en: 'Welcome to Evolve'
	String get welcomeTitle => 'Welcome to Evolve';

	/// en: 'Start your personal growth journey.'
	String get welcomeSubtitle => 'Start your personal growth journey.';

	/// en: 'This app helps you build good habits and reach your long-term goals.'
	String get welcomeBody => 'This app helps you build good habits and reach your long-term goals.';

	/// en: 'Start'
	String get welcomeStart => 'Start';

	/// en: 'Keep the pace. Every small action reinforces the person you are becoming.'
	String get subtitle => 'Keep the pace. Every small action reinforces the person you are becoming.';

	/// en: 'Today's completion'
	String get completionToday => 'Today\'s completion';

	/// en: '{done}/{total} habits'
	String habitsCount({required Object done, required Object total}) => '${done}/${total} habits';

	/// en: 'Best streak'
	String get bestStreak => 'Best streak';

	/// en: 'Active goals'
	String get activeGoals => 'Active goals';

	/// en: '{pct}% average progress'
	String avgProgress({required Object pct}) => '${pct}% average progress';

	/// en: 'Momentum'
	String get momentum => 'Momentum';

	/// en: 'vs. last week'
	String get vsLastWeek => 'vs. last week';

	/// en: 'Weekly trend'
	String get weeklyTrend => 'Weekly trend';

	/// en: 'Completion rate of your habits'
	String get weeklyTrendSubtitle => 'Completion rate of your habits';

	/// en: '{value} this week'
	String thisWeekPill({required Object value}) => '${value} this week';

	/// en: 'Today's protocol'
	String get todayProtocol => 'Today\'s protocol';

	/// en: 'Complete the essential actions before adding more'
	String get todayProtocolSubtitle => 'Complete the essential actions before adding more';

	/// en: '{count} actions'
	String actionsCount({required Object count}) => '${count} actions';

	/// en: 'Your canvas is empty. Create your first habit.'
	String get emptyHabits => 'Your canvas is empty. Create your first habit.';

	/// en: '{n} d'
	String streakDaysShort({required Object n}) => '${n} d';

	/// en: 'Check-in recorded'
	String get checkInDone => 'Check-in recorded';

	/// en: 'How do you feel today?'
	String get checkInPrompt => 'How do you feel today?';

	/// en: 'Mood {mood}/10 · Energy {energy}/10'
	String moodEnergyValue({required Object mood, required Object energy}) => 'Mood ${mood}/10 · Energy ${energy}/10';

	/// en: 'Record mood and energy to improve your pattern analysis.'
	String get checkInHint => 'Record mood and energy to improve your pattern analysis.';

	/// en: 'Update check-in'
	String get updateCheckIn => 'Update check-in';

	/// en: 'Do the check-in'
	String get doCheckIn => 'Do the check-in';

	/// en: 'Daily check-in'
	String get dailyCheckIn => 'Daily check-in';

	/// en: 'A quick reading helps Evolve better understand your patterns.'
	String get dailyCheckInSubtitle => 'A quick reading helps Evolve better understand your patterns.';

	/// en: 'Record'
	String get record => 'Record';

	/// en: 'Goals in focus'
	String get focusGoals => 'Goals in focus';

	/// en: 'Current priorities'
	String get currentPriorities => 'Current priorities';

	/// en: '100-goal limit reached. Upgrade to Pro to create more.'
	String get goalLimitReached => '100-goal limit reached. Upgrade to Pro to create more.';

	/// en: 'No goals in focus. Add one.'
	String get emptyFocusGoals => 'No goals in focus. Add one.';

	/// en: 'Week to kick off'
	String get weekToStart => 'Week to kick off';

	/// en: 'Week on the rise'
	String get weekGrowing => 'Week on the rise';

	/// en: 'Week to recover'
	String get weekToRecover => 'Week to recover';

	/// en: '{value} vs. the previous week.'
	String vsPreviousWeek({required Object value}) => '${value} vs. the previous week.';
}

// Path: stats
class Translations$stats$en {
	Translations$stats$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Statistics'
	String get title => 'Statistics';

	/// en: 'Global'
	String get global => 'Global';

	/// en: 'Resilience'
	String get resilience => 'Resilience';

	/// en: 'Habits'
	String get tabHabits => 'Habits';

	/// en: 'Mood'
	String get tabMood => 'Mood';

	/// en: 'Last 30 days'
	String get last30Days => 'Last 30 days';

	/// en: 'Single habit'
	String get singleHabit => 'Single habit';

	/// en: 'No habit'
	String get noHabit => 'No habit';

	/// en: 'Today's completion'
	String get completionToday => 'Today\'s completion';

	/// en: 'Best streak'
	String get bestStreakLabel => 'Best streak';

	/// en: 'Critical day'
	String get criticalDay => 'Critical day';

	/// en: 'Complete priorities first'
	String get completePrioritiesFirst => 'Complete priorities first';

	/// en: 'Recent activity'
	String get recentActivity => 'Recent activity';

	/// en: 'Completion intensity over the last 90 days'
	String get recentActivitySubtitle => 'Completion intensity over the last 90 days';

	/// en: 'Global trend'
	String get trendGlobal => 'Global trend';

	/// en: 'Time comparison of the protocol'
	String get trendGlobalSubtitle => 'Time comparison of the protocol';

	/// en: '{value}% vs previous day'
	String vsPrevDay({required Object value}) => '${value}% vs previous day';

	/// en: 'Best habit'
	String get bestHabit => 'Best habit';

	/// en: 'Critical area'
	String get criticalArea => 'Critical area';

	/// en: 'Streak at risk'
	String get streakAtRisk => 'Streak at risk';

	/// en: '{habit} needs attention in the next check-ins.'
	String streakAtRiskDetail({required Object habit}) => '${habit} needs attention in the next check-ins.';

	/// en: 'Pattern to consolidate'
	String get patternToConsolidate => 'Pattern to consolidate';

	/// en: 'Check low-mood days and keep the essential protocol.'
	String get checkLowMoodDays => 'Check low-mood days and keep the essential protocol.';

	/// en: 'Goal due soon'
	String get goalDue => 'Goal due soon';

	/// en: 'No active goal needs intervention.'
	String get noGoalNeedsIntervention => 'No active goal needs intervention.';

	/// en: 'Performance per habit'
	String get performancePerHabit => 'Performance per habit';

	/// en: 'Ranking computed from synced logs by weekly consistency'
	String get performancePerHabitSubtitle => 'Ranking computed from synced logs by weekly consistency';

	/// en: 'Average mood'
	String get avgMood => 'Average mood';

	/// en: 'Average energy'
	String get avgEnergy => 'Average energy';

	/// en: '{count} check-ins available'
	String checkInsAvailable({required Object count}) => '${count} check-ins available';

	/// en: 'Resilient habit'
	String get resilientHabit => 'Resilient habit';

	/// en: 'Completed even on hard days'
	String get completedEvenHardDays => 'Completed even on hard days';

	/// en: 'Mood and energy'
	String get moodEnergy => 'Mood and energy';

	/// en: 'Average of available check-ins over the last 90 days'
	String get moodEnergySubtitle => 'Average of available check-ins over the last 90 days';

	/// en: 'Completion'
	String get completion => 'Completion';

	/// en: 'Current week'
	String get currentWeek => 'Current week';

	/// en: 'Current streak'
	String get currentStreak => 'Current streak';

	/// en: 'Streak synced from available logs'
	String get currentStreakDetail => 'Streak synced from available logs';

	/// en: '30-day trend'
	String get trend30 => '30-day trend';

	/// en: 'Completion over the last 30 days'
	String get trend30Detail => 'Completion over the last 30 days';

	/// en: 'Yearly calendar'
	String get yearlyCalendar => 'Yearly calendar';

	/// en: 'Distribution of completions for {habit}'
	String yearlyCalendarSubtitle({required Object habit}) => 'Distribution of completions for ${habit}';

	/// en: 'Performance per day'
	String get performancePerDay => 'Performance per day';

	/// en: 'Strong and weak days of the week'
	String get performancePerDaySubtitle => 'Strong and weak days of the week';

	/// en: 'Protect the {days}-day streak'
	String protectStreak({required Object days}) => 'Protect the ${days}-day streak';

	/// en: 'Keep the same time slot to reduce friction on the busiest days.'
	String get keepSameSlot => 'Keep the same time slot to reduce friction on the busiest days.';

	/// en: 'The worst negative streak lasted {days} days.'
	String worstNegativeSeq({required Object days}) => 'The worst negative streak lasted ${days} days.';

	/// en: 'Positive lever detected'
	String get positiveLever => 'Positive lever detected';

	/// en: '{habit} keeps the best recent regularity.'
	String bestHabitRegularity({required Object habit}) => '${habit} keeps the best recent regularity.';

	/// en: 'Mood sensitivity'
	String get moodSensitivity => 'Mood sensitivity';

	/// en: 'Completion with low energy'
	String get lowEnergyCompletion => 'Completion with low energy';

	/// en: 'Mood-output correlation'
	String get moodOutputCorrelation => 'Mood-output correlation';

	/// en: 'Completions available on check-in days'
	String get moodOutputSubtitle => 'Completions available on check-in days';

	/// en: 'Key correlations'
	String get keyCorrelations => 'Key correlations';

	/// en: 'Patterns that most influence the protocol'
	String get keyCorrelationsSubtitle => 'Patterns that most influence the protocol';

	/// en: 'More logs are needed to compute useful correlations.'
	String get moreLogsNeeded => 'More logs are needed to compute useful correlations.';

	/// en: 'Create at least one habit to see the granular analysis.'
	String get createHabitForAnalysis => 'Create at least one habit to see the granular analysis.';

	/// en: 'No data'
	String get noData => 'No data';

	/// en: 'Info'
	String get tabInfo => 'Info';

	/// en: 'Trend'
	String get tabTrend => 'Trend';

	/// en: 'Alerts'
	String get tabAlerts => 'Alerts';

	/// en: 'Overview'
	String get tabOverview => 'Overview';

	/// en: 'Calendar'
	String get tabCalendar => 'Calendar';

	/// en: 'Performance'
	String get tabPerformance => 'Performance';

	/// en: 'Improvement'
	String get tabImprovement => 'Improvement';

	/// en: 'Spot the patterns that drive growth and act on the critical areas.'
	String get pageSubtitle => 'Spot the patterns that drive growth and act on the critical areas.';

	/// en: '{done}/{total} actions'
	String actionsFraction({required Object done, required Object total}) => '${done}/${total} actions';

	/// en: '{habit} is affected by hard days'
	String affectedByHardDays({required Object habit}) => '${habit} is affected by hard days';

	/// en: 'Last 30 Days Trend'
	String get last30DaysTrend => 'Last 30 Days Trend';

	/// en: 'Well done, {pct}% completion ({done}/{total})'
	String strongestDayDetail({required Object pct, required Object done, required Object total}) => 'Well done, ${pct}% completion (${done}/${total})';

	/// en: 'Only {pct}% completion ({done}/{total})'
	String weakestDayDetail({required Object pct, required Object done, required Object total}) => 'Only ${pct}% completion (${done}/${total})';

	/// en: 'Streak of {days} days broken'
	String brokenStreakItem({required Object days}) => 'Streak of ${days} days broken';

	/// en: '{percentage}% together'
	String togetherProbability({required Object percentage}) => '${percentage}% together';

	/// en: 'The habits that are getting worse the most.'
	String get criticalHabitsSubtitle => 'The habits that are getting worse the most.';

	/// en: 'The habits you are most consistent with.'
	String get bestHabitsSubtitle => 'The habits you are most consistent with.';

	/// en: 'Week'
	String get timeframeWeek => 'Week';

	/// en: 'Month'
	String get timeframeMonth => 'Month';

	/// en: 'Year'
	String get timeframeYear => 'Year';

	/// en: 'All'
	String get timeframeAll => 'All';

	/// en: '{days} days without completion'
	String negativeStreakDays({required Object days}) => '${days} days without completion';

	/// en: '-{drop}%'
	String dropPercent({required Object drop}) => '-${drop}%';

	/// en: 'Black day: {day}'
	String blackDayDetail({required Object day}) => 'Black day: ${day}';

	/// en: 'Worst streak: {streak}d · ~{frequency}/month missed'
	String failureDetail({required Object streak, required Object frequency}) => 'Worst streak: ${streak}d · ~${frequency}/month missed';

	/// en: 'Average recovery time: {days} days'
	String recoveryDetail({required Object days}) => 'Average recovery time: ${days} days';

	/// en: '{rate}% success'
	String successRate({required Object rate}) => '${rate}% success';

	/// en: 'Rate'
	String get sortRate => 'Rate';

	/// en: 'Streak'
	String get sortStreak => 'Streak';

	/// en: 'Name'
	String get sortName => 'Name';

	/// en: 'Active'
	String get filterActive => 'Active';

	/// en: 'All'
	String get filterAll => 'All';

	/// en: 'No active habits — switch to All to see ended ones.'
	String get noActiveHabits => 'No active habits — switch to All to see ended ones.';

	/// en: 'Worst'
	String get worstStreakLabel => 'Worst';

	/// en: 'Momentum'
	String get momentumTitle => 'Momentum';

	/// en: 'Your current form'
	String get momentumSubtitle => 'Your current form';

	/// en: 'FORM'
	String get momentumForm => 'FORM';

	/// en: '7-day'
	String get momentumRate => '7-day';

	/// en: 'Streaks'
	String get momentumStreakHealth => 'Streaks';

	/// en: 'Trend'
	String get momentumTrend => 'Trend';

	/// en: 'Improving'
	String get rollingImproving => 'Improving';

	/// en: 'Declining'
	String get rollingDeclining => 'Declining';

	/// en: 'Steady'
	String get rollingSteady => 'Steady';

	/// en: 'Consistency'
	String get lifetimeConsistency => 'Consistency';

	/// en: 'All-time completion'
	String get lifetimeConsistencyDetail => 'All-time completion';

	/// en: 'Total done'
	String get lifetimeTotalDone => 'Total done';

	/// en: 'Habits checked off'
	String get lifetimeTotalDoneDetail => 'Habits checked off';

	/// en: 'Perfect days'
	String get lifetimePerfectDays => 'Perfect days';

	/// en: 'Everything completed'
	String get lifetimePerfectDaysDetail => 'Everything completed';

	/// en: 'Days tracked'
	String get lifetimeDaysTracked => 'Days tracked';

	/// en: 'Since you started'
	String get lifetimeDaysTrackedDetail => 'Since you started';

	/// en: 'KEYSTONE HABIT'
	String get keystoneTitle => 'KEYSTONE HABIT';

	/// en: 'On its days you complete {withPct}% of your other habits, vs {withoutPct}% otherwise.'
	String keystoneImpact({required Object withPct, required Object withoutPct}) => 'On its days you complete ${withPct}% of your other habits, vs ${withoutPct}% otherwise.';

	/// en: '365-day activity'
	String get yearActivity => '365-day activity';

	/// en: 'Every habit, every day'
	String get yearActivitySubtitle => 'Every habit, every day';

	/// en: '{count} active days'
	String activeDaysCount({required Object count}) => '${count} active days';

	/// en: 'Less'
	String get heatmapLess => 'Less';

	/// en: 'More'
	String get heatmapMore => 'More';

	/// en: 'Best habits'
	String get bestHabitsTitle => 'Best habits';

	/// en: 'Needs attention'
	String get criticalHabitsTitle => 'Needs attention';

	/// en: '{days}d idle'
	String criticalStalled({required Object days}) => '${days}d idle';

	/// en: 'Rolling completion'
	String get rollingTitle => 'Rolling completion';

	/// en: '7-day and 30-day rate'
	String get rollingSubtitle => '7-day and 30-day rate';

	/// en: '7-day'
	String get rolling7 => '7-day';

	/// en: '30-day'
	String get rolling30 => '30-day';

	/// en: 'This week vs average'
	String get weekVsAvgTitle => 'This week vs average';

	/// en: 'How this week compares'
	String get weekVsAvgSubtitle => 'How this week compares';

	/// en: 'This week'
	String get thisWeek => 'This week';

	/// en: 'Your average'
	String get yourAverage => 'Your average';

	/// en: 'Weekly rhythm'
	String get weekdayShapeTitle => 'Weekly rhythm';

	/// en: 'Completion by weekday'
	String get weekdayShapeSubtitle => 'Completion by weekday';

	/// en: 'Weekday vs weekend'
	String get weekdayWeekendTitle => 'Weekday vs weekend';

	/// en: 'Where you're strongest'
	String get weekdayWeekendSubtitle => 'Where you\'re strongest';

	/// en: 'Weekdays'
	String get weekdaysLabel => 'Weekdays';

	/// en: 'Weekend'
	String get weekendLabel => 'Weekend';

	/// en: 'Seasonality'
	String get seasonalityTitle => 'Seasonality';

	/// en: 'Completion by month'
	String get seasonalitySubtitle => 'Completion by month';

	/// en: 'Bounce-back rate'
	String get bounceBackTitle => 'Bounce-back rate';

	/// en: 'Recovery after a miss'
	String get bounceBackSubtitle => 'Recovery after a miss';

	/// en: 'Recovered {recoveries} of {opportunities} times'
	String bounceBackDetail({required Object recoveries, required Object opportunities}) => 'Recovered ${recoveries} of ${opportunities} times';

	/// en: 'Danger zone'
	String get dangerZoneTitle => 'Danger zone';

	/// en: 'When streaks break'
	String get dangerZoneSubtitle => 'When streaks break';

	/// en: 'No broken streaks yet'
	String get dangerZoneNone => 'No broken streaks yet';

	/// en: '{breaks} of {total} breaks land here'
	String dangerZoneDetail({required Object breaks, required Object total}) => '${breaks} of ${total} breaks land here';

	/// en: 'Performance comparison'
	String get performanceComparisonTitle => 'Performance comparison';

	/// en: 'Best vs worst streak'
	String get performanceComparisonSubtitle => 'Best vs worst streak';

	/// en: '{pct}% gap'
	String perfCompGap({required Object pct}) => '${pct}% gap';

	/// en: 'Best'
	String get perfCompBest => 'Best';

	/// en: 'Worst'
	String get perfCompWorst => 'Worst';

	/// en: 'Consistency'
	String get consistencyTitle => 'Consistency';

	/// en: 'Most regular habits'
	String get consistencySubtitle => 'Most regular habits';

	/// en: 'Steadiest'
	String get consistencySteadiest => 'Steadiest';

	/// en: 'Most erratic'
	String get consistencyErratic => 'Most erratic';

	/// en: 'Streak leaderboard'
	String get medalsTitle => 'Streak leaderboard';

	/// en: 'Longest current streaks'
	String get medalsSubtitle => 'Longest current streaks';

	/// en: 'Never missed'
	String get neverMissedTitle => 'Never missed';

	/// en: 'No perfect habits yet'
	String get neverMissedEmpty => 'No perfect habits yet';

	/// en: 'Completion spread'
	String get distributionTitle => 'Completion spread';

	/// en: 'Habits by success rate'
	String get distributionSubtitle => 'Habits by success rate';

	/// en: 'Habit synergy'
	String get synergyTitle => 'Habit synergy';

	/// en: 'Which habits move together'
	String get synergySubtitle => 'Which habits move together';

	/// en: 'Mood-sensitive'
	String get moodSensitiveTitle => 'Mood-sensitive';

	/// en: 'Swayed most by your mood'
	String get moodSensitiveSubtitle => 'Swayed most by your mood';

	/// en: 'Resilient habits'
	String get resilientHabitsTitle => 'Resilient habits';

	/// en: 'Done even on low days'
	String get resilientHabitsSubtitle => 'Done even on low days';

	/// en: 'Mood correlation'
	String get correlationAnalysisTitle => 'Mood correlation';

	/// en: 'Low vs high mood completion'
	String get correlationAnalysisSubtitle => 'Low vs high mood completion';

	/// en: 'Mood & energy'
	String get moodEnergyTrendTitle => 'Mood & energy';

	/// en: 'Last {days} days'
	String moodEnergyTrendSubtitle({required Object days}) => 'Last ${days} days';

	/// en: 'All-time record'
	String get allTimeBest => 'All-time record';

	/// en: 'Top performer'
	String get topPerformerLabel => 'Top performer';

	/// en: 'Now'
	String get currentStreakShort => 'Now';

	/// en: 'Record'
	String get recordLabel => 'Record';

	/// en: 'Best streak ever'
	String get recordDetail => 'Best streak ever';

	/// en: 'Schedule adherence'
	String get adherenceTitle => 'Schedule adherence';

	/// en: 'Of the days it was due'
	String get adherenceSubtitle => 'Of the days it was due';

	/// en: '{done} of {scheduled} scheduled days'
	String adherenceDetail({required Object done, required Object scheduled}) => '${done} of ${scheduled} scheduled days';

	/// en: 'At risk'
	String get atRiskTitle => 'At risk';

	/// en: 'Yes'
	String get atRiskYes => 'Yes';

	/// en: 'On track'
	String get atRiskNo => 'On track';

	/// en: '{days} days since last done'
	String atRiskDetail({required Object days}) => '${days} days since last done';

	/// en: 'd'
	String get daysUnit => 'd';

	/// en: 'Timing gaps'
	String get gapTitle => 'Timing gaps';

	/// en: 'Days between completions'
	String get gapSubtitle => 'Days between completions';

	/// en: 'Avg gap'
	String get gapAvg => 'Avg gap';

	/// en: 'Longest'
	String get gapLongest => 'Longest';

	/// en: 'Since last'
	String get gapSince => 'Since last';

	/// en: 'Bounce-back'
	String get habitBounceBackShort => 'Bounce-back';

	/// en: 'Regularity score'
	String get habitConsistencyDetail => 'Regularity score';

	/// en: 'Ahead of {pct}% of your habits'
	String habitPercentile({required Object pct}) => 'Ahead of ${pct}% of your habits';

	/// en: 'This month vs last'
	String get monthVsTitle => 'This month vs last';

	/// en: 'Completion, month over month'
	String get monthVsSubtitle => 'Completion, month over month';

	/// en: 'This month'
	String get thisMonthLabel => 'This month';

	/// en: 'Last month'
	String get lastMonthLabel => 'Last month';

	/// en: 'Next-day mood impact'
	String get nextDayMoodTitle => 'Next-day mood impact';

	/// en: 'Mood & energy the day after'
	String get nextDayMoodSubtitle => 'Mood & energy the day after';

	/// en: 'After doing it'
	String get nextDayAfterDone => 'After doing it';

	/// en: 'After missing it'
	String get nextDayAfterMissed => 'After missing it';

	/// en: '{value} mood lift'
	String nextDayMoodLift({required Object value}) => '${value} mood lift';

	/// en: 'Streak history'
	String get streakHistoryTitle => 'Streak history';

	/// en: 'Every run of consecutive days'
	String get streakHistorySubtitle => 'Every run of consecutive days';

	/// en: '{count} streaks · longest {longest} days'
	String streakHistoryDetail({required Object count, required Object longest}) => '${count} streaks · longest ${longest} days';
}

// Path: habitsPage
class Translations$habitsPage$en {
	Translations$habitsPage$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Today'
	String get today => 'Today';

	/// en: 'Build your daily protocol and watch consistency over time.'
	String get subtitle => 'Build your daily protocol and watch consistency over time.';

	/// en: 'Protocol'
	String get tabProtocol => 'Protocol';

	/// en: 'Calendar'
	String get tabCalendar => 'Calendar';

	/// en: 'Delete habit'
	String get deleteHabitTitle => 'Delete habit';

	/// en: 'Remove "{title}" from the protocol?'
	String deleteHabitConfirm({required Object title}) => 'Remove "${title}" from the protocol?';

	/// en: 'Active protocol'
	String get activeProtocol => 'Active protocol';

	/// en: 'Completed today'
	String get completedToday => 'Completed today';

	/// en: 'Daily protocol'
	String get dailyProtocol => 'Daily protocol';

	/// en: 'Weekly overview, reminders and quick actions'
	String get protocolSubtitle => 'Weekly overview, reminders and quick actions';

	/// en: 'HABIT'
	String get colHabit => 'HABIT';

	/// en: 'STREAK'
	String get colStreak => 'STREAK';

	/// en: 'LAST 7 DAYS'
	String get colLast7Days => 'LAST 7 DAYS';

	/// en: 'REMINDER'
	String get colReminder => 'REMINDER';

	/// en: '{n} days'
	String streakDays({required Object n}) => '${n} days';

	/// en: 'Previous period'
	String get prevPeriod => 'Previous period';

	/// en: 'Next period'
	String get nextPeriod => 'Next period';

	List<String> get weekdayAbbrevUpper => [
		'MON',
		'TUE',
		'WED',
		'THU',
		'FRI',
		'SAT',
		'SUN',
	];

	/// en: 'Life view'
	String get lifeView => 'Life view';

	/// en: 'One cell represents a month of the journey up to age 85.'
	String get lifeViewSubtitle => 'One cell represents a month of the journey up to age 85.';

	/// en: 'Months lived'
	String get monthsLived => 'Months lived';

	/// en: 'Current age'
	String get currentAge => 'Current age';

	/// en: 'Months remaining'
	String get monthsRemaining => 'Months remaining';

	/// en: 'Details {day} {month}'
	String dayDetail({required Object day, required Object month}) => 'Details ${day} ${month}';

	/// en: 'Update the status of habits for this day.'
	String get dayDetailSubtitle => 'Update the status of habits for this day.';

	/// en: 'Edit habit'
	String get editHabit => 'Edit habit';

	/// en: 'New habit'
	String get newHabit => 'New habit';

	/// en: 'Optional reminder'
	String get optionalReminder => 'Optional reminder';

	/// en: 'e.g. 08:30'
	String get reminderHint => 'e.g. 08:30';

	/// en: 'Close'
	String get close => 'Close';

	/// en: 'Completed'
	String get statusDone => 'Completed';

	/// en: 'Skipped'
	String get statusSkipped => 'Skipped';

	/// en: 'Not recorded'
	String get statusUnrecorded => 'Not recorded';

	/// en: 'Week of {day} {month}'
	String weekOf({required Object day, required Object month}) => 'Week of ${day} ${month}';

	/// en: 'Weeks of your journey'
	String get lifeWeeks => 'Weeks of your journey';

	/// en: 'Mindfulness'
	String get catMindfulness => 'Mindfulness';

	/// en: 'Only today and yesterday can be edited.'
	String get editableHint => 'Only today and yesterday can be edited.';
}

// Path: goalsPage
class Translations$goalsPage$en {
	Translations$goalsPage$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Macro Goals'
	String get title => 'Macro Goals';

	/// en: 'Long-term planning.'
	String get subtitle => 'Long-term planning.';

	/// en: 'Sample goal'
	String get sampleGoal => 'Sample goal';

	/// en: 'Life goals'
	String get periodLifetime => 'Life goals';

	/// en: 'Lifetime goals'
	String get subtitleLifetime => 'Lifetime goals';

	/// en: 'Annual goals'
	String get subtitleAnnual => 'Annual goals';

	/// en: 'Quarterly goals'
	String get subtitleQuarterly => 'Quarterly goals';

	/// en: 'Monthly goals'
	String get subtitleMonthly => 'Monthly goals';

	/// en: 'Weekly goals'
	String get subtitleWeekly => 'Weekly goals';

	/// en: 'Stats'
	String get statsTab => 'Stats';

	/// en: 'Full view'
	String get fullView => 'Full view';

	/// en: 'Goal categories'
	String get categoriesTitle => 'Goal categories';

	/// en: 'Default'
	String get defaultPill => 'Default';

	/// en: 'Edit category'
	String get editCategory => 'Edit category';

	/// en: 'Archive category'
	String get archiveCategory => 'Archive category';

	/// en: 'Failed to create category.'
	String get categoryCreateFailed => 'Failed to create category.';

	/// en: 'Failed to archive category.'
	String get categoryArchiveFailed => 'Failed to archive category.';

	/// en: 'Failed to edit category.'
	String get categoryEditFailed => 'Failed to edit category.';

	/// en: 'Add category'
	String get addCategory => 'Add category';

	/// en: 'Back'
	String get back => 'Back';

	/// en: 'Finish'
	String get finish => 'Finish';

	/// en: 'Next'
	String get next => 'Next';

	/// en: 'Categories'
	String get categoriesTooltip => 'Categories';

	/// en: 'Reschedule to next period'
	String get rescheduleTooltip => 'Reschedule to next period';

	/// en: 'Default'
	String get defaultCategory => 'Default';

	/// en: 'No active goal in this period.'
	String get emptyActive => 'No active goal in this period.';

	/// en: 'Add the first goal for this period.'
	String get emptyAdd => 'Add the first goal for this period.';

	/// en: 'New goal'
	String get newGoal => 'New goal';

	/// en: 'Edit goal'
	String get editGoal => 'Edit goal';

	/// en: 'Horizon'
	String get horizonLabel => 'Horizon';

	/// en: 'New category'
	String get newCategory => 'New category';

	/// en: 'Name'
	String get nameLabel => 'Name';

	/// en: 'Week {week}, {month} {year}'
	String weekPeriodLabel({required Object week, required Object month, required Object year}) => 'Week ${week}, ${month} ${year}';

	/// en: 'Current quarter'
	String get currentQuarter => 'Current quarter';

	/// en: 'Current month'
	String get currentMonth => 'Current month';
}

// Path: goalsStats
class Translations$goalsStats$en {
	Translations$goalsStats$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Pro feature required'
	String get proRequired => 'Pro feature required';

	/// en: 'Active'
	String get active => 'Active';

	/// en: 'Failed'
	String get failed => 'Failed';

	/// en: 'Compl.'
	String get complAbbr => 'Compl.';

	/// en: 'Seasonality'
	String get seasonality => 'Seasonality';

	/// en: 'Interest evolution'
	String get interestEvolution => 'Interest evolution';
}

// Path: ai
class Translations$ai$en {
	Translations$ai$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'AI Coach'
	String get coach => 'AI Coach';

	/// en: 'Daily habits'
	String get dailyHabits => 'Daily habits';

	/// en: 'Macro goals'
	String get macroGoals => 'Macro goals';

	late final Translations$ai$openRouter$en openRouter = Translations$ai$openRouter$en.internal(_root);
	late final Translations$ai$apiKey$en apiKey = Translations$ai$apiKey$en.internal(_root);
	late final Translations$ai$suggestions$en suggestions = Translations$ai$suggestions$en.internal(_root);
	late final Translations$ai$local$en local = Translations$ai$local$en.internal(_root);
	late final Translations$ai$standard$en standard = Translations$ai$standard$en.internal(_root);
	late final Translations$ai$consent$en consent = Translations$ai$consent$en.internal(_root);
}

// Path: aiCoach
class Translations$aiCoach$en {
	Translations$aiCoach$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Hi! I'm Evolve AI Coach. I'm here to help you optimize your protocol and reach your goals. How can I help you today?'
	String get greeting => 'Hi! I\'m Evolve AI Coach. I\'m here to help you optimize your protocol and reach your goals. How can I help you today?';

	/// en: 'You are Evolve AI Coach, a virtual assistant for personal discipline.'
	String get systemPersona => 'You are Evolve AI Coach, a virtual assistant for personal discipline.';

	/// en: 'ACTIVE HABITS:'
	String get habitsHeader => 'ACTIVE HABITS:';

	/// en: 'No active habits.'
	String get noActiveHabits => 'No active habits.';

	/// en: '{title} (Completed today: {done}, Streak: {streak})'
	String habitLine({required Object title, required Object done, required Object streak}) => '${title} (Completed today: ${done}, Streak: ${streak})';

	/// en: 'GOALS:'
	String get goalsHeader => 'GOALS:';

	/// en: 'No active long-term goals.'
	String get noActiveGoals => 'No active long-term goals.';

	/// en: '{title} (Due: {due})'
	String goalLine({required Object title, required Object due}) => '${title} (Due: ${due})';

	/// en: 'AI Context'
	String get contextTitle => 'AI Context';

	/// en: 'Choose which data to share with the AI Coach to get personalized advice.'
	String get contextBody => 'Choose which data to share with the AI Coach to get personalized advice.';

	/// en: 'Shares your active habits, streaks and today's completion status.'
	String get shareHabitsDesc => 'Shares your active habits, streaks and today\'s completion status.';

	/// en: 'Shares your active long-term goals.'
	String get shareGoalsDesc => 'Shares your active long-term goals.';

	/// en: 'Save and close'
	String get saveClose => 'Save and close';

	/// en: 'Reason about patterns with a contextual coach based on your journey data.'
	String get subtitle => 'Reason about patterns with a contextual coach based on your journey data.';

	/// en: 'Context'
	String get contextButton => 'Context';

	/// en: 'AI Coach is typing...'
	String get typing => 'AI Coach is typing...';

	/// en: 'Ask your Coach for advice...'
	String get inputHint => 'Ask your Coach for advice...';

	/// en: 'user'
	String get defaultUserName => 'user';

	/// en: '- Name: {userName}'
	String userNameLine({required Object userName}) => '- Name: ${userName}';

	/// en: '- Active goals: {count}'
	String activeGoalsCount({required Object count}) => '- Active goals: ${count}';

	/// en: '- Completed goals: {count}'
	String completedGoalsCount({required Object count}) => '- Completed goals: ${count}';

	/// en: '- Habits today: {completed} completed out of {total} total.'
	String todayCompletion({required Object completed, required Object total}) => '- Habits today: ${completed} completed out of ${total} total.';

	/// en: 'New chat'
	String get newChatTooltip => 'New chat';

	/// en: 'Start a new chat?'
	String get clearConfirmTitle => 'Start a new chat?';

	/// en: 'This clears the current conversation — it isn't saved.'
	String get clearConfirmBody => 'This clears the current conversation — it isn\'t saved.';

	/// en: 'Cancel'
	String get clearConfirmCancel => 'Cancel';

	/// en: 'New chat'
	String get clearConfirmAccept => 'New chat';

	/// en: 'Copy'
	String get copyTooltip => 'Copy';

	/// en: 'Copied to clipboard'
	String get copiedToast => 'Copied to clipboard';

	/// en: 'Couldn't open the link.'
	String get linkOpenFailed => 'Couldn\'t open the link.';
}

// Path: settingsPage
class Translations$settingsPage$en {
	Translations$settingsPage$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Account'
	String get account => 'Account';

	/// en: 'Notifications'
	String get notifications => 'Notifications';

	/// en: 'Language'
	String get language => 'Language';

	/// en: '24h Format'
	String get timeFormat24h => '24h Format';

	/// en: 'Subscription'
	String get subscription => 'Subscription';

	/// en: 'Evolve Pro'
	String get proName => 'Evolve Pro';

	/// en: 'Monthly'
	String get planMonthly => 'Monthly';

	/// en: 'Annual'
	String get planAnnual => 'Annual';

	/// en: 'Restore purchases'
	String get restorePurchases => 'Restore purchases';

	/// en: 'Delete private data'
	String get deletePrivateData => 'Delete private data';

	/// en: 'Importing data...'
	String get importInProgress => 'Importing data...';

	/// en: 'Passwords do not match.'
	String get passwordsDontMatch => 'Passwords do not match.';

	/// en: 'Email'
	String get email => 'Email';

	/// en: 'Cancel'
	String get cancel => 'Cancel';

	/// en: 'Confirm'
	String get confirm => 'Confirm';

	/// en: 'Save'
	String get save => 'Save';

	/// en: 'Settings'
	String get pageTitle => 'Settings';

	/// en: 'Manage your profile, desktop behavior, privacy and Evolve plan.'
	String get pageSubtitle => 'Manage your profile, desktop behavior, privacy and Evolve plan.';

	/// en: 'Profile'
	String get profileLabel => 'Profile';

	/// en: 'Personal information and sync status'
	String get profileSubtitle => 'Personal information and sync status';

	/// en: 'Account and onboarding'
	String get accountAndOnboarding => 'Account and onboarding';

	/// en: 'Private Mode'
	String get privateMode => 'Private Mode';

	/// en: 'Session unavailable'
	String get sessionUnavailable => 'Session unavailable';

	/// en: 'Data repository'
	String get dataRepository => 'Data repository';

	/// en: 'Encrypted local database'
	String get encryptedLocalDatabase => 'Encrypted local database';

	/// en: 'Supabase with encrypted cache'
	String get supabaseWithEncryptedCache => 'Supabase with encrypted cache';

	/// en: 'Personal information'
	String get personalInfo => 'Personal information';

	/// en: 'First name, last name, email and date of birth'
	String get personalInfoDetail => 'First name, last name, email and date of birth';

	/// en: 'Update avatar'
	String get updateAvatar => 'Update avatar';

	/// en: 'Choose a local image for the desktop profile.'
	String get updateAvatarDetail => 'Choose a local image for the desktop profile.';

	/// en: 'Review initial consent'
	String get reviewInitialConsent => 'Review initial consent';

	/// en: 'Terms, privacy, notifications and crash reporting'
	String get reviewInitialConsentDetail => 'Terms, privacy, notifications and crash reporting';

	/// en: 'Sign out of your account'
	String get signOut => 'Sign out of your account';

	/// en: 'Close the session on this device'
	String get signOutDetailActive => 'Close the session on this device';

	/// en: 'Available with an active Supabase session'
	String get availableWithActiveSession => 'Available with an active Supabase session';

	/// en: 'Go to Login'
	String get goToLogin => 'Go to Login';

	/// en: 'Suspend private mode and sign in to Supabase.'
	String get goToLoginDetail => 'Suspend private mode and sign in to Supabase.';

	/// en: 'Appearance and application'
	String get appearanceTitle => 'Appearance and application';

	/// en: 'Local preferences adapted to desktop'
	String get appearanceSubtitle => 'Local preferences adapted to desktop';

	/// en: 'Appearance and visuals'
	String get appearanceAndVisual => 'Appearance and visuals';

	/// en: 'Theme'
	String get themeMode => 'Theme';

	/// en: 'Light'
	String get themeLight => 'Light';

	/// en: 'Dark'
	String get themeDark => 'Dark';

	/// en: 'Follow system'
	String get themeSystem => 'Follow system';

	/// en: 'Calendar, experience and language'
	String get calendarExperienceLanguage => 'Calendar, experience and language';

	/// en: 'Accent color'
	String get accentColor => 'Accent color';

	/// en: 'Extended palette reserved for Evolve Pro.'
	String get accentColorDetail => 'Extended palette reserved for Evolve Pro.';

	/// en: 'Default calendar view'
	String get defaultCalendarView => 'Default calendar view';

	late final Translations$settingsPage$calendarViewOptions$en calendarViewOptions = Translations$settingsPage$calendarViewOptions$en.internal(_root);
	late final Translations$settingsPage$languageOptions$en languageOptions = Translations$settingsPage$languageOptions$en.internal(_root);

	/// en: 'Use times like 20:30 instead of 8:30 PM.'
	String get timeFormat24hDetail => 'Use times like 20:30 instead of 8:30 PM.';

	/// en: 'Haptic feedback'
	String get hapticFeedback => 'Haptic feedback';

	/// en: 'The desktop keeps the preference but does not generate vibrations.'
	String get hapticFeedbackDetail => 'The desktop keeps the preference but does not generate vibrations.';

	/// en: 'AI & SYSTEM'
	String get aiAndSystem => 'AI & SYSTEM';

	/// en: 'AI Suggestions'
	String get aiSuggestions => 'AI Suggestions';

	/// en: 'Intelligent habit analysis'
	String get aiSuggestionsDetail => 'Intelligent habit analysis';

	/// en: 'Focus Mode'
	String get focusMode => 'Focus Mode';

	/// en: 'Pauses all reminders and notifications.'
	String get focusModeDetail => 'Pauses all reminders and notifications.';

	/// en: 'Milestones'
	String get milestones => 'Milestones';

	/// en: 'Celebrations when you reach key milestones.'
	String get milestonesDetail => 'Celebrations when you reach key milestones.';

	/// en: 'Deep Work Insights'
	String get deepWorkInsights => 'Deep Work Insights';

	/// en: 'Advanced analysis of your focus sessions.'
	String get deepWorkInsightsDetail => 'Advanced analysis of your focus sessions.';

	/// en: 'Reset tutorial'
	String get resetTutorial => 'Reset tutorial';

	/// en: 'Reopens the dashboard and goals walkthroughs.'
	String get resetTutorialDetail => 'Reopens the dashboard and goals walkthroughs.';

	/// en: 'Operational reminders from the desktop client'
	String get notificationsSubtitle => 'Operational reminders from the desktop client';

	/// en: 'Operational reminders'
	String get operationalReminders => 'Operational reminders';

	/// en: 'Habit reminders'
	String get habitReminders => 'Habit reminders';

	/// en: 'Sends the daily morning briefing.'
	String get habitRemindersDetail => 'Sends the daily morning briefing.';

	/// en: 'Morning brief time'
	String get morningBriefTime => 'Morning brief time';

	/// en: 'Evening review'
	String get eveningReview => 'Evening review';

	/// en: 'Reminds you to consolidate your day.'
	String get eveningReviewDetail => 'Reminds you to consolidate your day.';

	/// en: 'Evening review time'
	String get eveningReviewTime => 'Evening review time';

	/// en: 'Insights and reports'
	String get insightsAndReports => 'Insights and reports';

	/// en: 'AI Insights'
	String get aiInsights => 'AI Insights';

	/// en: 'Personalized analysis and advice from AI.'
	String get aiInsightsDetail => 'Personalized analysis and advice from AI.';

	/// en: 'Weekly Reports'
	String get weeklyReports => 'Weekly Reports';

	/// en: 'A weekly summary of your progress.'
	String get weeklyReportsDetail => 'A weekly summary of your progress.';

	/// en: 'Request notification permissions'
	String get requestNotificationPermissions => 'Request notification permissions';

	/// en: 'Opens the native prompt on the supported target.'
	String get requestNotificationPermissionsDetail => 'Opens the native prompt on the supported target.';

	/// en: 'Native delivery per operating system'
	String get nativeDeliveryTitle => 'Native delivery per operating system';

	/// en: 'Privacy and security'
	String get privacyTitle => 'Privacy and security';

	/// en: 'Access protection, consents and data management'
	String get privacySubtitle => 'Access protection, consents and data management';

	/// en: 'Access protection'
	String get accessProtection => 'Access protection';

	/// en: 'Biometric lock'
	String get biometricLock => 'Biometric lock';

	/// en: 'Available with the native adapter on macOS and Windows; not supported on Linux.'
	String get biometricLockDetail => 'Available with the native adapter on macOS and Windows; not supported on Linux.';

	/// en: 'Change password'
	String get changePassword => 'Change password';

	/// en: 'Credential update via Supabase Auth.'
	String get changePasswordDetail => 'Credential update via Supabase Auth.';

	/// en: 'Data and consents'
	String get dataAndConsents => 'Data and consents';

	/// en: 'Send crash reports'
	String get sendCrashReports => 'Send crash reports';

	/// en: 'Separate consent for Sentry.'
	String get sendCrashReportsDetail => 'Separate consent for Sentry.';

	/// en: 'Export data'
	String get exportData => 'Export data';

	/// en: 'Shares a complete JSON export of the available data.'
	String get exportDataDetail => 'Shares a complete JSON export of the available data.';

	/// en: 'Import data'
	String get importData => 'Import data';

	/// en: 'Restores a backup (JSON or ZIP) from Evolve.'
	String get importDataDetail => 'Restores a backup (JSON or ZIP) from Evolve.';

	/// en: 'System permissions management'
	String get systemPermissionsManagement => 'System permissions management';

	/// en: 'Notifications, calendar and security.'
	String get systemPermissionsManagementDetail => 'Notifications, calendar and security.';

	/// en: 'Permanently deletes the encrypted local database.'
	String get deletePrivateDataDetail => 'Permanently deletes the encrypted local database.';

	/// en: 'Delete account and data'
	String get deleteAccountAndData => 'Delete account and data';

	/// en: 'Irreversible operation protected by confirmation.'
	String get deleteAccountAndDataDetail => 'Irreversible operation protected by confirmation.';

	/// en: 'My private data exported from Evolve'
	String get exportPrivateShareText => 'My private data exported from Evolve';

	/// en: 'My data exported from Evolve'
	String get exportShareText => 'My data exported from Evolve';

	/// en: 'Export complete'
	String get exportDoneTitle => 'Export complete';

	/// en: 'The JSON is on the clipboard: Linux does not support file sharing.'
	String get exportDoneClipboard => 'The JSON is on the clipboard: Linux does not support file sharing.';

	/// en: 'The JSON was sent to the share selector.'
	String get exportDoneShare => 'The JSON was sent to the share selector.';

	/// en: 'Avatar'
	String get avatarGateTitle => 'Avatar';

	/// en: 'Image selection failed.'
	String get avatarPickFailed => 'Image selection failed.';

	/// en: 'Confirm sign out'
	String get confirmSignOutTitle => 'Confirm sign out';

	/// en: 'Are you sure you want to sign out? You will need to re-enter your credentials to sign in again.'
	String get confirmSignOutMessage => 'Are you sure you want to sign out? You will need to re-enter your credentials to sign in again.';

	/// en: 'Profile'
	String get gateProfile => 'Profile';

	/// en: 'Logout'
	String get gateLogout => 'Logout';

	/// en: 'Change password'
	String get gateChangePassword => 'Change password';

	/// en: 'Requires an active Supabase session.'
	String get gateRequiresActiveSession => 'Requires an active Supabase session.';

	/// en: 'Activation cancelled.'
	String get biometricActivationCancelled => 'Activation cancelled.';

	/// en: 'Notification permissions'
	String get notificationPermissionsTitle => 'Notification permissions';

	/// en: 'Permissions available for this system.'
	String get notificationPermissionsGranted => 'Permissions available for this system.';

	/// en: 'Permission not granted. You can change it from the system settings.'
	String get notificationPermissionsDenied => 'Permission not granted. You can change it from the system settings.';

	/// en: 'System permissions'
	String get systemPermissionsTitle => 'System permissions';

	/// en: 'Unable to open the settings.'
	String get systemPermissionsOpenFailed => 'Unable to open the settings.';

	/// en: 'Tutorials reset'
	String get tutorialResetTitle => 'Tutorials reset';

	/// en: 'The guides will be shown again in the relevant sections.'
	String get tutorialResetMessage => 'The guides will be shown again in the relevant sections.';

	/// en: 'Account and data management'
	String get accountDataManagementTitle => 'Account and data management';

	/// en: 'Choose whether to delete the data while keeping the account active or to permanently delete the account.'
	String get accountDataManagementContent => 'Choose whether to delete the data while keeping the account active or to permanently delete the account.';

	/// en: 'Reset data'
	String get resetDataAction => 'Reset data';

	/// en: 'Delete account'
	String get deleteAccountAction => 'Delete account';

	/// en: 'Confirm data reset'
	String get confirmResetDataTitle => 'Confirm data reset';

	/// en: 'Habits, goals and preferences will be deleted. The account will remain active. This action cannot be undone.'
	String get confirmResetDataMessage => 'Habits, goals and preferences will be deleted. The account will remain active. This action cannot be undone.';

	/// en: 'Confirm account deletion'
	String get confirmDeleteAccountTitle => 'Confirm account deletion';

	/// en: 'The account and all associated data will be permanently deleted. This action is irreversible.'
	String get confirmDeleteAccountMessage => 'The account and all associated data will be permanently deleted. This action is irreversible.';

	/// en: 'Reset data'
	String get resetDataTitle => 'Reset data';

	/// en: 'Data deleted successfully.'
	String get resetDataSuccess => 'Data deleted successfully.';

	/// en: 'Operation failed.'
	String get operationFailed => 'Operation failed.';

	/// en: 'Could not save that setting. It has been restored to its previous value.'
	String get settingSaveFailed => 'Could not save that setting. It has been restored to its previous value.';

	/// en: 'Delete account'
	String get deleteAccountGateTitle => 'Delete account';

	/// en: 'Account deleted.'
	String get accountDeleted => 'Account deleted.';

	/// en: 'Import data'
	String get importDataGateTitle => 'Import data';

	/// en: 'The import feature is currently available only in Private Mode (Local).'
	String get importPrivateOnly => 'The import feature is currently available only in Private Mode (Local).';

	/// en: 'Import summary'
	String get importSummaryTitle => 'Import summary';

	/// en: '{count} Habits'
	String importHabitsCount({required Object count}) => '${count} Habits';

	/// en: '{count} Check-ins (Log)'
	String importLogsCount({required Object count}) => '${count} Check-ins (Log)';

	/// en: '{count} Macro Goals'
	String importMacroGoalsCount({required Object count}) => '${count} Macro Goals';

	/// en: '{count} Categories'
	String importCategoriesCount({required Object count}) => '${count} Categories';

	/// en: '{count} Mood Records'
	String importMoodsCount({required Object count}) => '${count} Mood Records';

	/// en: 'Replace current data'
	String get importReplaceTitle => 'Replace current data';

	/// en: 'Permanently deletes every existing record that isn't in this backup.'
	String get importReplaceSubtitle => 'Permanently deletes every existing record that isn\'t in this backup.';

	/// en: 'Merge with current data'
	String get importMergeTitle => 'Merge with current data';

	/// en: 'Combines with your data, keeping the newest version of each item.'
	String get importMergeSubtitle => 'Combines with your data, keeping the newest version of each item.';

	/// en: 'Replace all data?'
	String get importReplaceConfirmTitle => 'Replace all data?';

	/// en: 'This permanently deletes your current data (about {count} habit logs) and keeps only what's in this backup. This can't be undone.'
	String importReplaceConfirmMessage({required Object count}) => 'This permanently deletes your current data (about ${count} habit logs) and keeps only what\'s in this backup. This can\'t be undone.';

	/// en: 'Delete & Replace'
	String get importReplaceConfirmButton => 'Delete & Replace';

	/// en: 'Confirm import'
	String get importConfirmButton => 'Confirm import';

	/// en: 'Import completed successfully!'
	String get importSuccess => 'Import completed successfully!';

	/// en: 'Error during import: {error}'
	String importError({required Object error}) => 'Error during import: ${error}';

	/// en: 'Reset locked private database?'
	String get importLockedTitle => 'Reset locked private database?';

	/// en: 'This device can't unlock your local private database — its encryption key is missing (this happens after moving to a new Mac or a change to the app's signing). The existing local data can't be recovered, but you can reset it and import this backup onto a fresh, empty database. This can't be undone.'
	String get importLockedMessage => 'This device can\'t unlock your local private database — its encryption key is missing (this happens after moving to a new Mac or a change to the app\'s signing). The existing local data can\'t be recovered, but you can reset it and import this backup onto a fresh, empty database. This can\'t be undone.';

	/// en: 'Reset & import'
	String get importLockedResetButton => 'Reset & import';

	/// en: '⚠ {count} invalid record(s) will be skipped'
	String importPreviewSkipped({required Object count}) => '⚠ ${count} invalid record(s) will be skipped';

	/// en: 'Import Completed'
	String get importCompletedTitle => 'Import Completed';

	/// en: 'Your data was replaced with the backup. Summary:'
	String get importSummaryReplaced => 'Your data was replaced with the backup. Summary:';

	/// en: 'Your data was merged with the backup. Summary:'
	String get importSummaryMerged => 'Your data was merged with the backup. Summary:';

	/// en: 'Awesome!'
	String get importSummaryDone => 'Awesome!';

	/// en: 'Habits'
	String get importEntityHabits => 'Habits';

	/// en: 'Habit Logs'
	String get importEntityLogs => 'Habit Logs';

	/// en: 'Macro Goals'
	String get importEntityMacroGoals => 'Macro Goals';

	/// en: 'Categories'
	String get importEntityCategories => 'Categories';

	/// en: 'Mood Logs'
	String get importEntityMoods => 'Mood Logs';

	/// en: '{count} {label}'
	String importRowReplace({required Object count, required Object label}) => '${count} ${label}';

	/// en: '{label}: {added} added, {updated} updated, {unchanged} unchanged'
	String importRowMerge({required Object label, required Object added, required Object updated, required Object unchanged}) => '${label}: ${added} added, ${updated} updated, ${unchanged} unchanged';

	/// en: ', {count} skipped'
	String importRowSkipped({required Object count}) => ', ${count} skipped';

	/// en: 'The JSON file was saved to the selected location.'
	String get exportDoneSaved => 'The JSON file was saved to the selected location.';

	/// en: 'Evolve Pro'
	String get proTitle => 'Evolve Pro';

	/// en: 'Plan, purchase restore and subscription management'
	String get proSubtitle => 'Plan, purchase restore and subscription management';

	/// en: 'Billed through Apple'
	String get billingAppleTitle => 'Billed through Apple';

	/// en: 'Purchases unavailable'
	String get commercialChannelRequired => 'Purchases unavailable';

	/// en: 'Your subscription is purchased and managed with your Apple account.'
	String get billingAppleDetail => 'Your subscription is purchased and managed with your Apple account.';

	/// en: 'Subscriptions are temporarily unavailable. Please try again later.'
	String get billingUnavailableDetail => 'Subscriptions are temporarily unavailable. Please try again later.';

	/// en: 'In-app purchases aren't available on this platform.'
	String get billingPlatformUnsupported => 'In-app purchases aren\'t available on this platform.';

	/// en: 'Best value'
	String get bestValue => 'Best value';

	/// en: 'Price unavailable'
	String get priceUnavailable => 'Price unavailable';

	/// en: 'The subscription renews automatically unless auto-renew is turned off in Apple account settings at least 24 hours before the end of the period.'
	String get renewalDisclaimer => 'The subscription renews automatically unless auto-renew is turned off in Apple account settings at least 24 hours before the end of the period.';

	/// en: 'Privacy Policy'
	String get privacyPolicy => 'Privacy Policy';

	/// en: 'Terms of Use (EULA)'
	String get termsEula => 'Terms of Use (EULA)';

	/// en: 'Plan management'
	String get planManagement => 'Plan management';

	/// en: 'Activate Evolve Pro'
	String get activateEvolvePro => 'Activate Evolve Pro';

	/// en: 'Evolve Pro entitlement active.'
	String get activateEvolveProActive => 'Evolve Pro entitlement active.';

	/// en: 'Subscribe with your Apple account.'
	String get activateEvolveProStart => 'Subscribe with your Apple account.';

	/// en: 'Restores a subscription you already bought.'
	String get restorePurchasesDetail => 'Restores a subscription you already bought.';

	/// en: 'Manage subscription'
	String get manageSubscription => 'Manage subscription';

	/// en: 'Opens the subscription management of the Apple account.'
	String get manageSubscriptionDetail => 'Opens the subscription management of the Apple account.';

	/// en: 'Not authenticated'
	String get notAuthenticated => 'Not authenticated';

	/// en: 'Verified'
	String get verified => 'Verified';

	/// en: 'Your data is protected and saved only on this device.'
	String get privateModeDataProtected => 'Your data is protected and saved only on this device.';

	/// en: 'Profile'
	String get profileFallback => 'Profile';

	/// en: 'Full name'
	String get fullName => 'Full name';

	/// en: 'Date of birth'
	String get dateOfBirth => 'Date of birth';

	/// en: 'YYYY-MM-DD'
	String get dateOfBirthHint => 'YYYY-MM-DD';

	/// en: 'Current password'
	String get currentPassword => 'Current password';

	/// en: 'New password'
	String get newPassword => 'New password';

	/// en: 'Confirm new password'
	String get confirmNewPassword => 'Confirm new password';

	/// en: 'Update password'
	String get updatePassword => 'Update password';

	/// en: 'Enter your current password.'
	String get enterCurrentPassword => 'Enter your current password.';

	/// en: 'The new password must be at least 8 characters long.'
	String get newPasswordMinLength => 'The new password must be at least 8 characters long.';

	/// en: 'Update failed. Check your current password.'
	String get passwordUpdateFailed => 'Update failed. Check your current password.';

	/// en: 'Application'
	String get sectionApplication => 'Application';

	/// en: 'Privacy'
	String get sectionPrivacy => 'Privacy';

	/// en: 'Custom color'
	String get customColor => 'Custom color';

	/// en: 'Apply'
	String get applyAction => 'Apply';

	/// en: 'Use accent {hex}'
	String useAccent({required Object hex}) => 'Use accent ${hex}';

	/// en: 'Upgrade to Evolve Pro'
	String get proUpsellTitle => 'Upgrade to Evolve Pro';

	/// en: 'Unlock all features and accelerate your growth.'
	String get proUpsellSubtitle => 'Unlock all features and accelerate your growth.';

	/// en: 'Welcome to Evolve Pro!'
	String get proWelcomeTitle => 'Welcome to Evolve Pro!';

	/// en: 'Your subscription is active. The AI Coach is included — no OpenRouter account or API key needed — along with advanced trend statistics and all Evolve's personal growth tools.'
	String get proActiveMessage => 'Your subscription is active. The AI Coach is included — no OpenRouter account or API key needed — along with advanced trend statistics and all Evolve\'s personal growth tools.';

	/// en: 'Start your Journey'
	String get proStartJourney => 'Start your Journey';

	/// en: 'System'
	String get systemSection => 'System';

	/// en: 'App Logs'
	String get appLogsTitle => 'App Logs';

	/// en: 'View diagnostic logs from this session'
	String get appLogsDetail => 'View diagnostic logs from this session';
}

// Path: consent
class Translations$consent$en {
	Translations$consent$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Your Privacy Matters'
	String get onboardingTitle => 'Your Privacy Matters';

	/// en: 'Continue'
	String get continueButton => 'Continue';
}

// Path: notifications
class Translations$notifications$en {
	Translations$notifications$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Done'
	String get actionDone => 'Done';

	/// en: 'Skip'
	String get actionSkip => 'Skip';

	/// en: 'Snooze'
	String get actionSnooze => 'Snooze';

	/// en: 'Morning Brief'
	String get morningBrief => 'Morning Brief';

	/// en: 'Evening Review'
	String get eveningReview => 'Evening Review';

	/// en: 'Time to shape your day. Check your goals.'
	String get morningBriefBody => 'Time to shape your day. Check your goals.';

	/// en: 'How did today go? Track your progress and update the Logbook.'
	String get eveningReviewBody => 'How did today go? Track your progress and update the Logbook.';
}

// Path: privacy
class Translations$privacy$en {
	Translations$privacy$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Authenticate to enable app protection.'
	String get biometricAuthReason => 'Authenticate to enable app protection.';

	/// en: 'Unlock the app to continue.'
	String get biometricUnlockReason => 'Unlock the app to continue.';
}

// Path: consentPage
class Translations$consentPage$en {
	Translations$consentPage$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Before using Evolve Desktop, confirm the terms, privacy policy and the data processing required for syncing.'
	String get subtitle => 'Before using Evolve Desktop, confirm the terms, privacy policy and the data processing required for syncing.';

	/// en: 'I accept the terms and privacy policy'
	String get acceptTerms => 'I accept the terms and privacy policy';

	/// en: 'I confirm I have read the documents and I am at least 14 years old.'
	String get termsSubtitle => 'I confirm I have read the documents and I am at least 14 years old.';

	/// en: 'Crash diagnostics'
	String get crashDiagnostics => 'Crash diagnostics';

	/// en: 'Allow sending anonymized technical reports.'
	String get crashSubtitle => 'Allow sending anonymized technical reports.';

	/// en: 'Open the privacy policy'
	String get openPrivacy => 'Open the privacy policy';

	/// en: 'Terms of Service'
	String get openTerms => 'Terms of Service';

	/// en: 'Enable notifications'
	String get notificationsTitle => 'Enable notifications';

	/// en: 'Get habit reminders and daily briefs.'
	String get notificationsSubtitle => 'Get habit reminders and daily briefs.';

	/// en: 'Enable'
	String get enableNotifications => 'Enable';

	/// en: 'Enabled'
	String get notificationsEnabled => 'Enabled';
}

// Path: notif
class Translations$notif$en {
	Translations$notif$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Daily scheduling active on macOS.'
	String get macScheduling => 'Daily scheduling active on macOS.';

	/// en: 'Linux shows immediate notifications but doesn't support scheduling.'
	String get linuxImmediate => 'Linux shows immediate notifications but doesn\'t support scheduling.';

	/// en: 'Open Evolve'
	String get openEvolve => 'Open Evolve';

	/// en: 'Windows schedules the next occurrence at each launch.'
	String get windowsScheduling => 'Windows schedules the next occurrence at each launch.';

	/// en: 'Review today's habits and choose where to start.'
	String get morningBody => 'Review today\'s habits and choose where to start.';

	/// en: 'It's time to complete your habit.'
	String get habitReminderBody => 'It\'s time to complete your habit.';

	/// en: 'Wrap up the day and update your progress.'
	String get eveningBody => 'Wrap up the day and update your progress.';
}

// Path: biometricGate
class Translations$biometricGate$en {
	Translations$biometricGate$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'App locked'
	String get appLocked => 'App locked';

	/// en: 'Unlock with local authentication to continue.'
	String get unlockPrompt => 'Unlock with local authentication to continue.';

	/// en: 'Verifying...'
	String get verifying => 'Verifying...';

	/// en: 'Unlock'
	String get unlock => 'Unlock';

	/// en: 'Biometric lock is not supported on Linux.'
	String get notSupportedLinux => 'Biometric lock is not supported on Linux.';

	/// en: 'No local authentication method available.'
	String get noLocalAuth => 'No local authentication method available.';

	/// en: 'Authentication failed.'
	String get authFailed => 'Authentication failed.';

	/// en: 'Local authentication unavailable.'
	String get authUnavailable => 'Local authentication unavailable.';
}

// Path: sync
class Translations$sync$en {
	Translations$sync$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Sync failed. Local data kept.'
	String get syncFailed => 'Sync failed. Local data kept.';

	/// en: 'Change saved locally. Sync to be retried.'
	String get editSavedLocally => 'Change saved locally. Sync to be retried.';
}

// Path: subscriptionCtrl
class Translations$subscriptionCtrl$en {
	Translations$subscriptionCtrl$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Purchase complete: syncing entitlement.'
	String get purchaseComplete => 'Purchase complete: syncing entitlement.';

	/// en: 'Purchase not completed.'
	String get purchaseIncomplete => 'Purchase not completed.';

	/// en: 'Unable to open Apple subscription management.'
	String get cantOpenApple => 'Unable to open Apple subscription management.';

	/// en: 'In-app purchases are available in the macOS client.'
	String get macOnly => 'In-app purchases are available in the macOS client.';

	/// en: 'Unable to load RevenueCat offerings.'
	String get loadOffersFailed => 'Unable to load RevenueCat offerings.';

	/// en: 'Evolve Pro activated.'
	String get proActivated => 'Evolve Pro activated.';

	/// en: 'Purchases restored.'
	String get purchasesRestored => 'Purchases restored.';

	/// en: 'No active Pro subscription found.'
	String get noActiveSub => 'No active Pro subscription found.';

	/// en: 'Failed to restore purchases.'
	String get restoreFailed => 'Failed to restore purchases.';

	/// en: 'Configure the desktop client's RevenueCat public key.'
	String get configKey => 'Configure the desktop client\'s RevenueCat public key.';

	/// en: 'Sign in before managing Evolve Pro.'
	String get loginFirst => 'Sign in before managing Evolve Pro.';
}

// Path: authCtrl
class Translations$authCtrl$en {
	Translations$authCtrl$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Apple did not return an identity token.'
	String get appleNoToken => 'Apple did not return an identity token.';

	/// en: 'Apple authentication failed.'
	String get appleAuthFailed => 'Apple authentication failed.';

	/// en: 'Unable to open the system browser.'
	String get cantOpenBrowser => 'Unable to open the system browser.';

	/// en: '{provider} sign-in not completed.'
	String accessNotCompleted({required Object provider}) => '${provider} sign-in not completed.';

	/// en: '{provider} authentication failed.'
	String providerAuthFailed({required Object provider}) => '${provider} authentication failed.';

	/// en: 'Operation failed. Try again shortly.'
	String get operationFailed => 'Operation failed. Try again shortly.';
}

// Path: proModal
class Translations$proModal$en {
	Translations$proModal$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Unlock Evolve Pro'
	String get title => 'Unlock Evolve Pro';

	/// en: 'Take your habit system to the next level'
	String get subtitle => 'Take your habit system to the next level';

	/// en: 'WHAT THE PRO PLAN INCLUDES'
	String get featuresHeader => 'WHAT THE PRO PLAN INCLUDES';

	/// en: 'AI Coach, with no setup'
	String get aiCoachTitle => 'AI Coach, with no setup';

	/// en: 'We run it on our key — no API key to fetch, no second account. Prefer your own OpenRouter account? That's free too.'
	String get aiCoachDesc => 'We run it on our key — no API key to fetch, no second account. Prefer your own OpenRouter account? That\'s free too.';

	/// en: 'Habit-Specific Statistics'
	String get statsTitle => 'Habit-Specific Statistics';

	/// en: 'Key insights to boost your productivity.'
	String get statsDesc => 'Key insights to boost your productivity.';

	/// en: 'Advanced Goal Metrics'
	String get metricsTitle => 'Advanced Goal Metrics';

	/// en: 'View detailed charts and deep performance stats for each year.'
	String get metricsDesc => 'View detailed charts and deep performance stats for each year.';

	/// en: 'Unlimited Habits'
	String get unlimitedTitle => 'Unlimited Habits';

	/// en: 'Create and track all the habits you want without any limits.'
	String get unlimitedDesc => 'Create and track all the habits you want without any limits.';

	/// en: 'Maybe later'
	String get maybeLater => 'Maybe later';

	/// en: 'View Pro plans'
	String get viewPlans => 'View Pro plans';
}

// Path: appLogs
class Translations$appLogs$en {
	Translations$appLogs$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'App Logs'
	String get title => 'App Logs';

	/// en: 'Logs copied to clipboard'
	String get copiedToClipboard => 'Logs copied to clipboard';

	/// en: 'Clear Logs'
	String get clearLogsTitle => 'Clear Logs';

	/// en: 'Are you sure you want to clear all log entries? This action cannot be undone.'
	String get clearLogsConfirm => 'Are you sure you want to clear all log entries? This action cannot be undone.';

	/// en: 'Clear All'
	String get clearLogsAction => 'Clear All';

	/// en: 'Copy All Logs'
	String get copyAll => 'Copy All Logs';

	/// en: 'Search logs...'
	String get searchPlaceholder => 'Search logs...';

	/// en: 'All'
	String get filterAll => 'All';

	/// en: 'Errors'
	String get filterErrors => 'Errors';

	/// en: 'Warnings'
	String get filterWarnings => 'Warnings';

	/// en: 'Info'
	String get filterInfo => 'Info';

	/// en: 'No Logs Yet'
	String get emptyTitle => 'No Logs Yet';

	/// en: 'Logs will appear here as the app runs'
	String get emptySubtitle => 'Logs will appear here as the app runs';

	/// en: 'Tap to view stack trace'
	String get stackTraceAvailable => 'Tap to view stack trace';

	/// en: 'MESSAGE'
	String get detailMessage => 'MESSAGE';

	/// en: 'ERROR'
	String get detailError => 'ERROR';

	/// en: 'Additional context'
	String get detailExtras => 'Additional context';

	/// en: 'STACK TRACE'
	String get detailStackTrace => 'STACK TRACE';

	/// en: 'Share logs file'
	String get shareLogs => 'Share logs file';

	/// en: 'Logs exported'
	String get exportDone => 'Logs exported';
}

// Path: coachSettings
class Translations$coachSettings$en {
	Translations$coachSettings$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'AI Coach engine'
	String get title => 'AI Coach engine';

	/// en: 'Choose where the coach runs. Local models keep every message on this device.'
	String get subtitle => 'Choose where the coach runs. Local models keep every message on this device.';

	/// en: 'Your OpenRouter'
	String get backendCloud => 'Your OpenRouter';

	/// en: 'Local · private'
	String get backendLocal => 'Local · private';

	/// en: 'Connect your own OpenRouter account and pay the provider directly. Free — no subscription needed. The context you share is sent to the provider.'
	String get cloudDesc => 'Connect your own OpenRouter account and pay the provider directly. Free — no subscription needed. The context you share is sent to the provider.';

	/// en: 'Your own model via Ollama, LM Studio or any OpenAI-compatible server. Nothing leaves this device.'
	String get localDesc => 'Your own model via Ollama, LM Studio or any OpenAI-compatible server. Nothing leaves this device.';

	/// en: 'Server'
	String get presetLabel => 'Server';

	/// en: 'Ollama'
	String get presetOllama => 'Ollama';

	/// en: 'LM Studio'
	String get presetLmStudio => 'LM Studio';

	/// en: 'Custom…'
	String get presetCustom => 'Custom…';

	/// en: 'Base URL'
	String get baseUrlLabel => 'Base URL';

	/// en: 'http://localhost:11434/v1'
	String get baseUrlHint => 'http://localhost:11434/v1';

	/// en: 'Model'
	String get modelLabel => 'Model';

	/// en: 'e.g. llama3.1:8b'
	String get modelHint => 'e.g. llama3.1:8b';

	/// en: 'Refresh models'
	String get refreshModels => 'Refresh models';

	/// en: 'Looking for models…'
	String get discovering => 'Looking for models…';

	/// en: 'No models found — type a model id manually below.'
	String get noModelsFound => 'No models found — type a model id manually below.';

	/// en: 'Model id'
	String get manualModelLabel => 'Model id';

	/// en: 'Use this model'
	String get manualModelAdd => 'Use this model';

	/// en: 'Connected'
	String get statusConnected => 'Connected';

	/// en: 'Server offline'
	String get statusOffline => 'Server offline';

	/// en: 'Checking…'
	String get statusChecking => 'Checking…';

	/// en: 'Remote'
	String get remoteBadge => 'Remote';

	/// en: 'This endpoint isn't a local address — messages will leave this device.'
	String get remoteWarning => 'This endpoint isn\'t a local address — messages will leave this device.';

	/// en: 'Advanced'
	String get advanced => 'Advanced';

	/// en: 'System prompt'
	String get systemPromptLabel => 'System prompt';

	/// en: 'Override the coach persona (leave empty for the default)'
	String get systemPromptHint => 'Override the coach persona (leave empty for the default)';

	/// en: 'Reset'
	String get systemPromptReset => 'Reset';

	/// en: 'Temperature'
	String get temperatureLabel => 'Temperature';

	/// en: 'Done'
	String get save => 'Done';

	/// en: 'Local model detected'
	String get detectedTitle => 'Local model detected';

	/// en: 'A local AI server is running on this Mac. Run the coach 100% privately?'
	String get detectedBody => 'A local AI server is running on this Mac. Run the coach 100% privately?';

	/// en: 'Use local'
	String get detectedAction => 'Use local';

	/// en: 'Not now'
	String get detectedDismiss => 'Not now';

	/// en: 'Cloud · {model}'
	String activeCloud({required Object model}) => 'Cloud · ${model}';

	/// en: 'Local · {model}'
	String activeLocal({required Object model}) => 'Local · ${model}';

	/// en: 'Local · pick a model'
	String get activeLocalNoModel => 'Local · pick a model';

	/// en: 'Your OpenRouter'
	String get cloudSection => 'Your OpenRouter';

	/// en: 'Server settings…'
	String get serverSettings => 'Server settings…';

	/// en: 'AI Coach'
	String get settingsSectionLabel => 'AI Coach';

	/// en: 'AI Coach'
	String get settingsTitle => 'AI Coach';

	/// en: 'Pick the engine that powers your coach and point it at a local server for full privacy.'
	String get settingsSubtitle => 'Pick the engine that powers your coach and point it at a local server for full privacy.';

	/// en: 'Active engine'
	String get settingsRowStatus => 'Active engine';

	/// en: 'Engine & local server'
	String get settingsRowConfigure => 'Engine & local server';

	/// en: 'No key yet — this engine won't reply. Connect your OpenRouter account below, switch to Evolve AI, or use a local server.'
	String get cloudKeyMissing => 'No key yet — this engine won\'t reply. Connect your OpenRouter account below, switch to Evolve AI, or use a local server.';

	/// en: 'Lower temperature'
	String get temperatureLower => 'Lower temperature';

	/// en: 'Raise temperature'
	String get temperatureRaise => 'Raise temperature';

	/// en: 'Send'
	String get sendMessage => 'Send';

	/// en: 'Stop'
	String get stopResponse => 'Stop';

	/// en: 'Start Ollama'
	String get startOllama => 'Start Ollama';

	/// en: 'Get Ollama'
	String get getOllama => 'Get Ollama';

	/// en: 'Starting Ollama…'
	String get startingOllama => 'Starting Ollama…';

	/// en: 'Ollama isn't running'
	String get ollamaOfflineTitle => 'Ollama isn\'t running';

	/// en: 'Start your local server to chat privately — no terminal needed.'
	String get ollamaOfflineBody => 'Start your local server to chat privately — no terminal needed.';

	/// en: 'Ollama isn't installed'
	String get ollamaNotInstalledTitle => 'Ollama isn\'t installed';

	/// en: 'Install the free Ollama app, then press Start.'
	String get ollamaNotInstalledBody => 'Install the free Ollama app, then press Start.';

	/// en: 'Taking longer than expected — check the Ollama icon in your menu bar (a first launch may need approval).'
	String get ollamaStartTimeout => 'Taking longer than expected — check the Ollama icon in your menu bar (a first launch may need approval).';

	/// en: 'This can take a few seconds…'
	String get ollamaStartingBody => 'This can take a few seconds…';

	/// en: 'Couldn't start Ollama — try opening it from your Applications folder.'
	String get ollamaStartFailed => 'Couldn\'t start Ollama — try opening it from your Applications folder.';

	/// en: 'Couldn't open the browser — visit ollama.com/download'
	String get ollamaDownloadFailed => 'Couldn\'t open the browser — visit ollama.com/download';

	/// en: 'Evolve AI'
	String get backendStandard => 'Evolve AI';

	/// en: 'Included with Evolve Pro. We run a free Google model (Gemma) for you — no keys, no setup. Your messages go to Google's free tier, which may use them to improve their services.'
	String get standardDesc => 'Included with Evolve Pro. We run a free Google model (Gemma) for you — no keys, no setup. Your messages go to Google\'s free tier, which may use them to improve their services.';

	/// en: 'Evolve AI · {model}'
	String activeStandard({required Object model}) => 'Evolve AI · ${model}';

	/// en: 'Evolve AI'
	String get standardSection => 'Evolve AI';

	/// en: 'Included with Pro'
	String get standardStatusReady => 'Included with Pro';

	/// en: 'Requires Pro'
	String get standardStatusNeedsPro => 'Requires Pro';

	/// en: 'Sign in required'
	String get standardStatusNeedsSignIn => 'Sign in required';

	/// en: 'Unavailable'
	String get standardStatusUnavailable => 'Unavailable';

	/// en: 'Evolve AI is part of Evolve Pro. Subscribe to use it — or connect your own OpenRouter account instead, which is free.'
	String get standardNeedsProNote => 'Evolve AI is part of Evolve Pro. Subscribe to use it — or connect your own OpenRouter account instead, which is free.';

	/// en: 'Sign in to use Evolve AI. Your subscription unlocks it on every device.'
	String get standardNeedsSignInNote => 'Sign in to use Evolve AI. Your subscription unlocks it on every device.';

	/// en: 'Evolve AI isn't available in this build. Connect your own OpenRouter account, or run a local model.'
	String get standardUnavailableNote => 'Evolve AI isn\'t available in this build. Connect your own OpenRouter account, or run a local model.';

	/// en: 'Evolve AI needs an Evolve account, and Private mode doesn't keep one. Connect your own OpenRouter account, or run a local model — both keep working here.'
	String get standardPrivateNote => 'Evolve AI needs an Evolve account, and Private mode doesn\'t keep one. Connect your own OpenRouter account, or run a local model — both keep working here.';
}

// Path: tour
class Translations$tour$en {
	Translations$tour$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Back'
	String get back => 'Back';

	/// en: 'Next'
	String get next => 'Next';

	/// en: 'Continue'
	String get continueLabel => 'Continue';

	/// en: 'Finish'
	String get finish => 'Finish';

	/// en: 'Welcome to Evolve'
	String get welcomeTitle => 'Welcome to Evolve';

	/// en: 'Let's take a quick tour of your workspace — from your daily overview all the way to your AI coach. It only takes a minute.'
	String get welcomeBody => 'Let\'s take a quick tour of your workspace — from your daily overview all the way to your AI coach. It only takes a minute.';

	/// en: 'Start tour'
	String get welcomeStart => 'Start tour';

	/// en: 'Skip tutorial'
	String get welcomeSkip => 'Skip tutorial';

	/// en: 'You're all set'
	String get doneTitle => 'You\'re all set';

	/// en: 'That's the whole app. Jump in anywhere from the sidebar — and you can replay this tour any time from Settings.'
	String get doneBody => 'That\'s the whole app. Jump in anywhere from the sidebar — and you can replay this tour any time from Settings.';

	/// en: 'Get started'
	String get doneButton => 'Get started';

	/// en: 'Your Overview'
	String get overviewOrientationTitle => 'Your Overview';

	/// en: 'This is your daily home base — a snapshot of today the moment you open Evolve.'
	String get overviewOrientationDesc => 'This is your daily home base — a snapshot of today the moment you open Evolve.';

	/// en: 'Daily check-in'
	String get overviewCheckinTitle => 'Daily check-in';

	/// en: 'Log how your day is going. Over time it reveals how your mood tracks with your habits and goals.'
	String get overviewCheckinDesc => 'Log how your day is going. Over time it reveals how your mood tracks with your habits and goals.';

	/// en: 'Today's habits'
	String get overviewHabitsTitle => 'Today\'s habits';

	/// en: 'The habits you've planned for today live here — tick them off as you go.'
	String get overviewHabitsDesc => 'The habits you\'ve planned for today live here — tick them off as you go.';

	/// en: 'Focus goals'
	String get overviewGoalsTitle => 'Focus goals';

	/// en: 'The goals you're focused on surface here so nothing slips.'
	String get overviewGoalsDesc => 'The goals you\'re focused on surface here so nothing slips.';

	/// en: 'The Habits page'
	String get habitsOrientationTitle => 'The Habits page';

	/// en: 'This is where you build your daily protocol and track how consistent you are.'
	String get habitsOrientationDesc => 'This is where you build your daily protocol and track how consistent you are.';

	/// en: 'Add a habit'
	String get habitsAddTitle => 'Add a habit';

	/// en: 'Create a new habit here — give it a name, a category, a colour and an optional reminder.'
	String get habitsAddDesc => 'Create a new habit here — give it a name, a category, a colour and an optional reminder.';

	/// en: 'Mark it done'
	String get habitsCheckoffTitle => 'Mark it done';

	/// en: 'Tick this box to complete a habit for today. That's all it takes to keep a streak alive.'
	String get habitsCheckoffDesc => 'Tick this box to complete a habit for today. That\'s all it takes to keep a streak alive.';

	/// en: 'Streaks & history'
	String get habitsStreakTitle => 'Streaks & history';

	/// en: 'Watch your streak grow, and see your last seven days at a glance.'
	String get habitsStreakDesc => 'Watch your streak grow, and see your last seven days at a glance.';

	/// en: 'Calendar view'
	String get habitsCalendarTitle => 'Calendar view';

	/// en: 'Switch to the Calendar to review your history by week, month, year — or your whole life.'
	String get habitsCalendarDesc => 'Switch to the Calendar to review your history by week, month, year — or your whole life.';

	/// en: 'Your Insights'
	String get insightsOrientationTitle => 'Your Insights';

	/// en: 'See how your habits and goals trend over time, and where you're drifting.'
	String get insightsOrientationDesc => 'See how your habits and goals trend over time, and where you\'re drifting.';

	/// en: 'Filter by habit'
	String get insightsFilterTitle => 'Filter by habit';

	/// en: 'Focus the statistics on a single habit, or keep the global overview.'
	String get insightsFilterDesc => 'Focus the statistics on a single habit, or keep the global overview.';

	/// en: 'Statistics sections'
	String get insightsTabsTitle => 'Statistics sections';

	/// en: 'Switch between the sections for trends, alerts, habit progress and your mood.'
	String get insightsTabsDesc => 'Switch between the sections for trends, alerts, habit progress and your mood.';

	/// en: 'The Goals page'
	String get goalsOrientationTitle => 'The Goals page';

	/// en: 'Set and track your bigger objectives — the things your daily habits build toward.'
	String get goalsOrientationDesc => 'Set and track your bigger objectives — the things your daily habits build toward.';

	/// en: 'Planning type'
	String get goalsPlanTitle => 'Planning type';

	/// en: 'Choose how you plan — daily, weekly or longer — to match how you think about your goals.'
	String get goalsPlanDesc => 'Choose how you plan — daily, weekly or longer — to match how you think about your goals.';

	/// en: 'Add a goal'
	String get goalsAddTitle => 'Add a goal';

	/// en: 'Create a new goal here and give it a target to work toward.'
	String get goalsAddDesc => 'Create a new goal here and give it a target to work toward.';

	/// en: 'Complete or miss'
	String get goalsCheckTitle => 'Complete or miss';

	/// en: 'Mark a goal done or missed. Every outcome feeds your performance over time.'
	String get goalsCheckDesc => 'Mark a goal done or missed. Every outcome feeds your performance over time.';

	/// en: 'Performance'
	String get goalsStatsTitle => 'Performance';

	/// en: 'Toggle performance stats to see how you're doing against your goals.'
	String get goalsStatsDesc => 'Toggle performance stats to see how you\'re doing against your goals.';

	/// en: 'Your AI Coach'
	String get coachOrientationTitle => 'Your AI Coach';

	/// en: 'Personalised guidance grounded in your real habits and goals — right here on your Mac.'
	String get coachOrientationDesc => 'Personalised guidance grounded in your real habits and goals — right here on your Mac.';

	/// en: 'Choose your engine'
	String get coachModelTitle => 'Choose your engine';

	/// en: 'Pick the AI model — our cloud, or a local model running privately on your Mac. Server settings live here too.'
	String get coachModelDesc => 'Pick the AI model — our cloud, or a local model running privately on your Mac. Server settings live here too.';

	/// en: 'What the coach sees'
	String get coachContextTitle => 'What the coach sees';

	/// en: 'Control whether the coach can use your habits and goals to tailor its advice.'
	String get coachContextDesc => 'Control whether the coach can use your habits and goals to tailor its advice.';

	/// en: 'Starter prompts'
	String get coachSuggestionsTitle => 'Starter prompts';

	/// en: 'Not sure where to begin? Tap one of these suggestions to get going.'
	String get coachSuggestionsDesc => 'Not sure where to begin? Tap one of these suggestions to get going.';

	/// en: 'Ask anything'
	String get coachInputTitle => 'Ask anything';

	/// en: 'Type your question here and press send. That's the end of the tour — enjoy Evolve!'
	String get coachInputDesc => 'Type your question here and press send. That\'s the end of the tour — enjoy Evolve!';
}

// Path: palette
class Translations$palette$en {
	Translations$palette$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Search goals, habits, actions…'
	String get searchHint => 'Search goals, habits, actions…';

	/// en: 'Suggested'
	String get groupSuggested => 'Suggested';

	/// en: 'This week'
	String get groupThisWeek => 'This week';

	/// en: 'Goals'
	String get groupGoals => 'Goals';

	/// en: 'Habits'
	String get groupHabits => 'Habits';

	/// en: 'Actions'
	String get groupActions => 'Actions';

	/// en: 'Go to'
	String get groupSections => 'Go to';

	/// en: 'Go to this week'
	String get goToThisWeek => 'Go to this week';

	/// en: 'Create goal'
	String get createGoalBlank => 'Create goal';

	/// en: 'Create goal “{title}”'
	String createGoal({required Object title}) => 'Create goal “${title}”';

	/// en: 'Create habit “{title}”'
	String createHabit({required Object title}) => 'Create habit “${title}”';

	/// en: 'Go to {period}'
	String goToPeriod({required Object period}) => 'Go to ${period}';

	/// en: 'Switch to dark theme'
	String get switchToDark => 'Switch to dark theme';

	/// en: 'Switch to light theme'
	String get switchToLight => 'Switch to light theme';

	/// en: 'Manage goal categories'
	String get manageCategories => 'Manage goal categories';

	/// en: 'Replay guided tour'
	String get replayTour => 'Replay guided tour';

	/// en: 'No results for “{query}”'
	String noResults({required Object query}) => 'No results for “${query}”';

	/// en: 'Open'
	String get rowOpen => 'Open';

	/// en: 'Mark complete'
	String get rowComplete => 'Mark complete';

	/// en: 'Reschedule to next period'
	String get rowReschedule => 'Reschedule to next period';

	/// en: 'Delete goal?'
	String get deleteGoalTitle => 'Delete goal?';

	/// en: '“{title}” will be permanently deleted.'
	String deleteGoalMessage({required Object title}) => '“${title}” will be permanently deleted.';

	/// en: 'Delete habit?'
	String get deleteHabitTitle => 'Delete habit?';

	/// en: '“{title}” will be permanently deleted.'
	String deleteHabitMessage({required Object title}) => '“${title}” will be permanently deleted.';

	/// en: 'navigate'
	String get footerNavigate => 'navigate';

	/// en: 'open'
	String get footerOpen => 'open';

	/// en: 'menu'
	String get footerMenu => 'menu';

	/// en: 'close'
	String get footerClose => 'close';
}

// Path: common.actions
class Translations$common$actions$en {
	Translations$common$actions$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Cancel'
	String get cancel => 'Cancel';

	/// en: 'Save'
	String get save => 'Save';

	/// en: 'Delete'
	String get delete => 'Delete';

	/// en: 'Edit'
	String get edit => 'Edit';

	/// en: 'Pick'
	String get pick => 'Pick';

	/// en: 'Got it'
	String get gotIt => 'Got it';
}

// Path: common.calendarView
class Translations$common$calendarView$en {
	Translations$common$calendarView$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Year'
	String get year => 'Year';

	/// en: 'Month'
	String get month => 'Month';

	/// en: 'Week'
	String get week => 'Week';

	/// en: 'Life'
	String get life => 'Life';
}

// Path: common.status
class Translations$common$status$en {
	Translations$common$status$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Error'
	String get error => 'Error';
}

// Path: macroGoals.types
class Translations$macroGoals$types$en {
	Translations$macroGoals$types$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Annual'
	String get annual => 'Annual';

	/// en: 'Quarterly'
	String get quarterly => 'Quarterly';

	/// en: 'Monthly'
	String get monthly => 'Monthly';

	/// en: 'Weekly'
	String get weekly => 'Weekly';

	/// en: 'Lifetime'
	String get lifetime => 'Lifetime';
}

// Path: ai.openRouter
class Translations$ai$openRouter$en {
	Translations$ai$openRouter$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: '⚠️ The AI Coach needs your own OpenRouter API key. Add one in Settings to start chatting.'
	String get apiKeyMissingShort => '⚠️ The AI Coach needs your own OpenRouter API key. Add one in Settings to start chatting.';

	/// en: '⚠️ OpenRouter rejected this API key. Check it in Settings, or create a new one at openrouter.ai/keys.'
	String get apiKeyInvalid => '⚠️ OpenRouter rejected this API key. Check it in Settings, or create a new one at openrouter.ai/keys.';

	/// en: 'You are the "Discipline Coach", a virtual assistant focused on helping the user stay disciplined, reach goals, and build healthy habits. Be motivating but concrete, direct, and practical. Use a professional but friendly tone.'
	String get defaultSystemPrompt => 'You are the "Discipline Coach", a virtual assistant focused on helping the user stay disciplined, reach goals, and build healthy habits. Be motivating but concrete, direct, and practical. Use a professional but friendly tone.';

	/// en: '❌ Error communicating with the AI. (Code: {code})'
	String communicationError({required Object code}) => '❌ Error communicating with the AI. (Code: ${code})';

	/// en: '❌ Connection error. Make sure you are online and try again.'
	String get connectionError => '❌ Connection error. Make sure you are online and try again.';

	/// en: '❌ Connection error.'
	String get connectionErrorShort => '❌ Connection error.';

	/// en: '❌ Error: Connection check took too long.'
	String get connectionCheckTimeout => '❌ Error: Connection check took too long.';

	/// en: '⚠️ This conversation got too long for the model. Start a new chat (top right) to continue.'
	String get contextTooLong => '⚠️ This conversation got too long for the model. Start a new chat (top right) to continue.';

	/// en: '❌ Error: No internet connection. Check your network.'
	String get noInternet => '❌ Error: No internet connection. Check your network.';

	/// en: '❌ Error: The server is taking too long to respond. Try again.'
	String get serverTimeout => '❌ Error: The server is taking too long to respond. Try again.';

	/// en: '❌ API error: {code} (check Sentry for details)'
	String apiError({required Object code}) => '❌ API error: ${code} (check Sentry for details)';
}

// Path: ai.apiKey
class Translations$ai$apiKey$en {
	Translations$ai$apiKey$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Your OpenRouter account'
	String get rowTitle => 'Your OpenRouter account';

	/// en: 'Prefer to run the coach on your own account? Connect an OpenRouter key and you pay the provider directly — no Evolve subscription needed. Create one at openrouter.ai/keys. It is stored in this device’s keychain and only ever sent to OpenRouter.'
	String get description => 'Prefer to run the coach on your own account? Connect an OpenRouter key and you pay the provider directly — no Evolve subscription needed. Create one at openrouter.ai/keys. It is stored in this device’s keychain and only ever sent to OpenRouter.';

	/// en: 'API key'
	String get fieldLabel => 'API key';

	/// en: 'sk-or-v1-…'
	String get hint => 'sk-or-v1-…';

	/// en: 'Save key'
	String get save => 'Save key';

	/// en: 'API key saved'
	String get saved => 'API key saved';

	/// en: 'Remove key'
	String get remove => 'Remove key';

	/// en: 'API key removed'
	String get removed => 'API key removed';

	/// en: 'Remove API key?'
	String get removeConfirmTitle => 'Remove API key?';

	/// en: 'This engine will stop replying until you connect an account again. Evolve AI and local models are unaffected.'
	String get removeConfirmBody => 'This engine will stop replying until you connect an account again. Evolve AI and local models are unaffected.';

	/// en: 'Saved'
	String get statusSet => 'Saved';

	/// en: 'Not set'
	String get statusMissing => 'Not set';

	/// en: 'Couldn't save the key to the keychain. Try again.'
	String get saveFailed => 'Couldn\'t save the key to the keychain. Try again.';

	/// en: 'Connect your OpenRouter account'
	String get setupTitle => 'Connect your OpenRouter account';

	/// en: 'This engine runs on your own OpenRouter account. Connect it to start chatting — or switch to Evolve AI, included with Pro.'
	String get setupBody => 'This engine runs on your own OpenRouter account. Connect it to start chatting — or switch to Evolve AI, included with Pro.';

	/// en: 'Connect account'
	String get setupAction => 'Connect account';
}

// Path: ai.suggestions
class Translations$ai$suggestions$en {
	Translations$ai$suggestions$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: '🔥 Give me a boost to get started!'
	String get morningBoost => '🔥 Give me a boost to get started!';

	/// en: '🧠 How can I avoid distractions?'
	String get avoidDistractions => '🧠 How can I avoid distractions?';

	/// en: '⚡ My energy is dropping. What should I do?'
	String get lowEnergy => '⚡ My energy is dropping. What should I do?';

	/// en: '💪 Give me one tip to stay focused'
	String get stayFocused => '💪 Give me one tip to stay focused';

	/// en: '🛌 How can I prepare for a productive tomorrow?'
	String get prepareTomorrow => '🛌 How can I prepare for a productive tomorrow?';

	/// en: '📝 Reflect on today’s discipline'
	String get disciplineReflection => '📝 Reflect on today’s discipline';

	/// en: '🎯 Analyze my active goals'
	String get analyzeActiveGoals => '🎯 Analyze my active goals';

	/// en: '🗺️ How should I plan my macro goals?'
	String get planMacroGoals => '🗺️ How should I plan my macro goals?';

	/// en: '🛑 What obstacles are blocking my goals?'
	String get goalObstacles => '🛑 What obstacles are blocking my goals?';

	/// en: '📈 Give me one tip to reach my milestones'
	String get reachMilestones => '📈 Give me one tip to reach my milestones';

	/// en: '📈 How is my consistency going?'
	String get consistencyStatus => '📈 How is my consistency going?';

	/// en: '📊 My weekly stats'
	String get weeklyStats => '📊 My weekly stats';

	/// en: '🌅 Plan my day'
	String get planDay => '🌅 Plan my day';

	/// en: '🚀 How can I raise the bar?'
	String get raiseBar => '🚀 How can I raise the bar?';

	/// en: '🤕 How can I recover after procrastinating?'
	String get recoverProcrastination => '🤕 How can I recover after procrastinating?';

	/// en: '🔗 How can I connect habits to goals?'
	String get connectHabitsGoals => '🔗 How can I connect habits to goals?';

	/// en: '📊 Review my goals and habits'
	String get reviewGoalsHabits => '📊 Review my goals and habits';

	/// en: '🔥 Discipline advice'
	String get disciplineAdvice => '🔥 Discipline advice';

	/// en: '💡 How can I create a new habit?'
	String get createNewHabit => '💡 How can I create a new habit?';
}

// Path: ai.local
class Translations$ai$local$en {
	Translations$ai$local$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: '❌ Local AI server not reachable at {url}. Make sure Ollama or LM Studio is running.'
	String notReachable({required Object url}) => '❌ Local AI server not reachable at ${url}. Make sure Ollama or LM Studio is running.';

	/// en: '⚠️ Choose a local model first — open the model picker at the top.'
	String get modelMissing => '⚠️ Choose a local model first — open the model picker at the top.';

	/// en: '❌ Local model error (code: {code}).'
	String requestFailed({required Object code}) => '❌ Local model error (code: ${code}).';

	/// en: '❌ Connection to the local model failed.'
	String get streamError => '❌ Connection to the local model failed.';

	/// en: '❌ The local model is taking too long — it may still be loading. Try again.'
	String get timeout => '❌ The local model is taking too long — it may still be loading. Try again.';

	/// en: '❌ That model isn't available on the server. Open the model picker to choose or load one.'
	String get modelNotFound => '❌ That model isn\'t available on the server. Open the model picker to choose or load one.';
}

// Path: ai.standard
class Translations$ai$standard$en {
	Translations$ai$standard$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: '⚠️ Your session expired. Sign in again to keep using Evolve AI.'
	String get sessionExpired => '⚠️ Your session expired. Sign in again to keep using Evolve AI.';

	/// en: '⚠️ Evolve AI is part of Evolve Pro. Subscribe in Settings — or switch the engine to your own OpenRouter account, which is free.'
	String get needsPro => '⚠️ Evolve AI is part of Evolve Pro. Subscribe in Settings — or switch the engine to your own OpenRouter account, which is free.';

	/// en: '⚠️ You've reached the Evolve AI fair-use limit for now. Try again later, or switch the engine to your own OpenRouter account.'
	String get rateLimited => '⚠️ You\'ve reached the Evolve AI fair-use limit for now. Try again later, or switch the engine to your own OpenRouter account.';

	/// en: '❌ Evolve AI is unavailable right now. This one's on us — please try again in a moment.'
	String get unavailable => '❌ Evolve AI is unavailable right now. This one\'s on us — please try again in a moment.';
}

// Path: ai.consent
class Translations$ai$consent$en {
	Translations$ai$consent$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Send your messages to the AI?'
	String get standardTitle => 'Send your messages to the AI?';

	/// en: 'To reply, the AI Coach sends your message, your first name and any context you choose to share to OpenRouter, Inc., which routes it to Google LLC (Google AI Studio) to run the model. Because this uses Google's free tier, Google may keep the text for a limited period and use it to improve their services — it is not as private as a paid tier. You can withdraw this any time in Settings, and everything else in Evolve keeps working without it.'
	String get standardBody => 'To reply, the AI Coach sends your message, your first name and any context you choose to share to OpenRouter, Inc., which routes it to Google LLC (Google AI Studio) to run the model. Because this uses Google\'s free tier, Google may keep the text for a limited period and use it to improve their services — it is not as private as a paid tier. You can withdraw this any time in Settings, and everything else in Evolve keeps working without it.';

	/// en: 'Send your messages to OpenRouter?'
	String get byokTitle => 'Send your messages to OpenRouter?';

	/// en: 'To reply, the AI Coach sends your message, your first name and any context you choose to share to OpenRouter, Inc. using your own OpenRouter account. OpenRouter routes it to a model provider according to your account settings. You can withdraw this any time in Settings, and everything else in Evolve keeps working without it.'
	String get byokBody => 'To reply, the AI Coach sends your message, your first name and any context you choose to share to OpenRouter, Inc. using your own OpenRouter account. OpenRouter routes it to a model provider according to your account settings. You can withdraw this any time in Settings, and everything else in Evolve keeps working without it.';

	/// en: 'Your private database stays on this device — only what you send in the chat leaves it.'
	String get privateNote => 'Your private database stays on this device — only what you send in the chat leaves it.';

	/// en: 'Allow'
	String get allow => 'Allow';

	/// en: 'Not now'
	String get decline => 'Not now';

	/// en: 'AI data sharing'
	String get rowTitle => 'AI data sharing';

	/// en: 'Allowed'
	String get statusGranted => 'Allowed';

	/// en: 'Not allowed'
	String get statusNone => 'Not allowed';

	/// en: 'Stop sharing with the AI?'
	String get revokeTitle => 'Stop sharing with the AI?';

	/// en: 'The AI Coach will ask again before it sends anything. Nothing else changes.'
	String get revokeBody => 'The AI Coach will ask again before it sends anything. Nothing else changes.';

	/// en: 'Stop sharing'
	String get revokeAction => 'Stop sharing';
}

// Path: settingsPage.calendarViewOptions
class Translations$settingsPage$calendarViewOptions$en {
	Translations$settingsPage$calendarViewOptions$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Month'
	String get month => 'Month';

	/// en: 'Week'
	String get week => 'Week';

	/// en: 'Year'
	String get year => 'Year';

	/// en: 'Life'
	String get life => 'Life';
}

// Path: settingsPage.languageOptions
class Translations$settingsPage$languageOptions$en {
	Translations$settingsPage$languageOptions$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'System'
	String get system => 'System';

	/// en: 'Italian'
	String get italian => 'Italian';

	/// en: 'English'
	String get english => 'English';

	/// en: 'Spanish'
	String get spanish => 'Spanish';

	/// en: 'German'
	String get german => 'German';

	/// en: 'Arabic'
	String get arabic => 'Arabic';
}

/// The flat map containing all translations for locale <en>.
/// Only for edge cases! For simple maps, use the map function of this library.
///
/// The Dart AOT compiler has issues with very large switch statements,
/// so the map is split into smaller functions (512 entries each).
extension on Translations {
	dynamic _flatMapFunction(String path) {
		return switch (path) {
			'auth.continuePrivately' => 'Continue privately on this Mac',
			'auth.signIn' => 'Log In',
			'auth.register' => 'Sign Up',
			'auth.or' => 'OR',
			'auth.password' => 'Password',
			'auth.forgotPassword' => 'Forgot password?',
			'auth.haveAccount' => 'Already have an account?',
			'auth.noAccount' => 'Don\'t have an account?',
			'auth.continueWithApple' => 'Continue with Apple',
			'auth.continueWithGoogle' => 'Continue with Google',
			'auth.readPrivacyPolicy' => 'Read Privacy Policy',
			'auth.nameLabel' => 'First Name',
			'auth.invalidEmail' => 'Enter a valid email',
			'auth.confirmEmail' => 'Check your email to confirm your registration.',
			'auth.resetSent' => 'Email sent. Check your inbox.',
			'auth.signInTitle' => 'Sign in to Evolve',
			'auth.signUpTitle' => 'Create your account',
			'auth.resetTitle' => 'Recover password',
			'auth.emailLabel' => 'Email',
			'auth.passwordMin8' => 'Use at least 8 characters.',
			'auth.sendResetLink' => 'Send recovery link',
			'privateData.deleteTitle' => 'Delete private data',
			'privateData.deleteMessage' => 'Are you sure you want to delete the entire encrypted local database? This action is irreversible and the data cannot be recovered.',
			'privateData.deleteSuccess' => 'Private data deleted.',
			'privateData.deleteFailed' => 'Operation failed.',
			'privateData.exportDoneTitle' => 'Export complete',
			'privateData.exportDoneClipboard' => 'The JSON is on the clipboard: Linux does not support file sharing.',
			'privateData.exportDoneShare' => 'The JSON was sent to the share sheet.',
			'icloudSync.title' => 'iCloud Sync',
			'icloudSync.enableTitle' => 'Enable iCloud Sync',
			'icloudSync.syncNow' => 'Sync now',
			'icloudSync.disclosureTitle' => 'End-to-end encrypted',
			'icloudSync.disclosureBody' => 'Your private data syncs only through your own iCloud account, end-to-end encrypted — never through our servers. The encryption key lives in your iCloud Keychain; if you turn iCloud Keychain off, synced data can\'t be recovered.',
			'icloudSync.disclosureAccept' => 'Enable',
			'icloudSync.statusIdle' => 'Up to date',
			'icloudSync.statusNotSynced' => 'Not everything has synced',
			'icloudSync.statusSyncing' => 'Syncing…',
			'icloudSync.statusOff' => 'Sync is off',
			'icloudSync.statusNoAccount' => 'Sign in to iCloud to sync',
			'icloudSync.statusUnavailable' => 'iCloud is unavailable right now',
			'icloudSync.statusWaitingKeychain' => 'Waiting for iCloud Keychain — make sure the app on your iPhone is up to date',
			'icloudSync.lastSyncedNever' => 'Never synced',
			'icloudSync.lastSyncedAt' => ({required Object time}) => 'Last synced ${time}',
			'icloudSync.deleteSyncNote' => 'iCloud Sync is on: this also deletes the synced copy in your iCloud and turns sync off. Other devices keep their local copy — run this on each device to erase everywhere.',
			'icloudSync.bannerText' => 'iCloud sync is off — your habits live only on this device and are lost if you reset or replace it.',
			'icloudSync.bannerAction' => 'Turn on',
			'icloudSync.detailsTitle' => 'Sync details',
			'icloudSync.detailsAllSynced' => 'Everything uploaded',
			'icloudSync.detailsPending' => ({required Object count}) => '${count} items waiting to upload',
			'icloudSync.detailsFailed' => ({required Object count}) => '${count} items failed to upload',
			'icloudSync.detailsCopy' => 'Copy report',
			'icloudSync.detailsCopied' => 'Report copied',
			'icloudSync.keySplitTitle' => 'Some iCloud data can\'t be read',
			'icloudSync.keySplitBody' => ({required Object count}) => '${count} records in iCloud were encrypted on another device with a different key, so this device can\'t read them. Reset sync from whichever device holds the data you want to keep.',
			'icloudSync.resetFromDevice' => 'Reset sync from this device',
			'icloudSync.resetFromDeviceDetail' => 'Replace everything in iCloud with this device\'s data',
			'icloudSync.resetFromDeviceConfirm' => 'This erases everything currently stored in iCloud and uploads this device\'s data in its place. Your other devices will then download this copy. Only do this from the device that holds the data you want to keep. This cannot be undone.',
			'icloudSync.resetFromDeviceDone' => 'Sync reset. This device\'s data is now the copy in iCloud.',
			'icloudSync.statusWaitingKey' => 'Waiting for the encryption key from your other device',
			'icloudSync.forceEnableTitle' => 'Start fresh from this device',
			'icloudSync.forceEnableBody' => 'Another device\'s data is already in iCloud, but its encryption key hasn\'t reached this device yet. Waiting is usually enough — it can take a few minutes. Starting fresh erases what is in iCloud and replaces it with this device\'s data. This cannot be undone.',
			'icloudSync.forceEnable' => 'Start fresh',
			'privateRecovery.preparing' => 'Preparing your private space…',
			'privateRecovery.restoredFromCloudToast' => 'Couldn\'t unlock the local database — restored your data from iCloud.',
			'privateRecovery.waitingTitle' => 'Waiting for iCloud',
			'privateRecovery.waitingMessage' => 'Sync is on, but your encryption key hasn\'t arrived from iCloud Keychain yet. Give it a moment, then retry.',
			'privateRecovery.lockedTitle' => 'Can\'t unlock private data',
			'privateRecovery.lockedMessageLocalOnly' => 'This device can\'t unlock your local private database — its encryption key is missing — and iCloud sync is off, so there\'s no cloud copy to restore. You can reset and start fresh.',
			'privateRecovery.lockedMessageICloudUnavailable' => 'This device can\'t unlock your local private database. iCloud sync is on but the account is unavailable — sign in to iCloud, then retry.',
			'privateRecovery.errorTitle' => 'Couldn\'t open private mode',
			'privateRecovery.errorMessage' => 'Something went wrong opening your private database. Retry, or reset it and start fresh.',
			'privateRecovery.enableSyncHint' => 'Have this data on another device? Turn on iCloud sync in Settings after resetting to pull it here.',
			'privateRecovery.retry' => 'Retry',
			'privateRecovery.resetFresh' => 'Reset & start fresh',
			'privateRecovery.backToSignIn' => 'Back to sign in',
			'namePrompt.title' => 'What is your name?',
			'namePrompt.subtitle' => 'Enter your name to personalize the dashboard.',
			'namePrompt.hint' => 'e.g. Simo',
			'namePrompt.save' => 'Save and continue',
			'nav.overview' => 'Overview',
			'nav.habits' => 'Habits',
			'nav.insights' => 'Statistics',
			'nav.goals' => 'Goals',
			'nav.coach' => 'AI Coach',
			'nav.settings' => 'Settings',
			'shell.syncPending' => 'Sync pending',
			'shell.syncing' => 'Syncing',
			'shell.synced' => 'Synced',
			'shell.syncTooltip' => 'Sync',
			'shell.searchHint' => 'Search or navigate',
			'shell.searchSectionHint' => 'Search a section...',
			'common.actions.cancel' => 'Cancel',
			'common.actions.save' => 'Save',
			'common.actions.delete' => 'Delete',
			'common.actions.edit' => 'Edit',
			'common.actions.pick' => 'Pick',
			'common.actions.gotIt' => 'Got it',
			'common.months.0' => 'January',
			'common.months.1' => 'February',
			'common.months.2' => 'March',
			'common.months.3' => 'April',
			'common.months.4' => 'May',
			'common.months.5' => 'June',
			'common.months.6' => 'July',
			'common.months.7' => 'August',
			'common.months.8' => 'September',
			'common.months.9' => 'October',
			'common.months.10' => 'November',
			'common.months.11' => 'December',
			'common.weekdayInitials.0' => 'M',
			'common.weekdayInitials.1' => 'T',
			'common.weekdayInitials.2' => 'W',
			'common.weekdayInitials.3' => 'T',
			'common.weekdayInitials.4' => 'F',
			'common.weekdayInitials.5' => 'S',
			'common.weekdayInitials.6' => 'S',
			'common.calendarView.year' => 'Year',
			'common.calendarView.month' => 'Month',
			'common.calendarView.week' => 'Week',
			'common.calendarView.life' => 'Life',
			'common.weekdaysLong.0' => 'Monday',
			'common.weekdaysLong.1' => 'Tuesday',
			'common.weekdaysLong.2' => 'Wednesday',
			'common.weekdaysLong.3' => 'Thursday',
			'common.weekdaysLong.4' => 'Friday',
			'common.weekdaysLong.5' => 'Saturday',
			'common.weekdaysLong.6' => 'Sunday',
			'common.none' => 'None',
			'common.habits' => 'Habits',
			'common.status.error' => 'Error',
			'common.total' => 'Total',
			'common.completed' => 'Completed',
			'common.unexpectedErrorTitle' => 'Something went wrong',
			'common.unexpectedErrorMessage' => 'An unexpected error occurred. Please try again.',
			'form.title' => 'Title',
			'form.category' => 'Category',
			'form.color' => 'Color',
			'form.add' => 'Add',
			'createGoal.title' => 'New Goal',
			'createGoal.subtitle' => 'Define your next milestone.',
			'createGoal.titleHint' => 'e.g. Launch the new product',
			'createGoal.categoryHint' => 'e.g. Work',
			'createGoal.timeline' => 'Timeline',
			'createGoal.thisWeek' => 'This Week',
			'createGoal.thisMonth' => 'This Month',
			'createGoal.thisQuarter' => 'This Quarter',
			'createGoal.thisYear' => 'This Year',
			'createGoal.longTerm' => 'Long-term (Lifetime)',
			'createGoal.dueLifetime' => 'Whole life',
			'createGoal.dueByYear' => ({required Object year}) => 'By ${year}',
			'createGoal.defaultCategory' => 'Goal',
			'createGoal.periodWhen' => 'When',
			'createHabit.title' => 'New Habit',
			'createHabit.subtitle' => 'Define your new habit.',
			'createHabit.titleHint' => 'e.g. Meditation',
			'createHabit.weeklyFrequency' => 'Weekly frequency',
			'macroGoals.types.annual' => 'Annual',
			'macroGoals.types.quarterly' => 'Quarterly',
			'macroGoals.types.monthly' => 'Monthly',
			'macroGoals.types.weekly' => 'Weekly',
			'macroGoals.types.lifetime' => 'Lifetime',
			'macroGoals.quarterNumber' => ({required Object quarter}) => 'Quarter ${quarter}',
			'macroGoals.addLifetimeGoal' => 'Add lifetime goal...',
			'macroGoals.addAnnualGoal' => 'Add annual goal...',
			'macroGoals.addQuarterlyGoal' => 'Add quarterly goal...',
			'macroGoals.addMonthlyGoal' => 'Add monthly goal...',
			'macroGoals.addWeeklyGoal' => 'Add weekly goal...',
			'macroGoals.completed' => 'COMPLETED',
			'macroGoals.failed' => 'FAILED',
			'macroGoals.create' => 'Create',
			'macroGoals.strength' => 'Strength',
			'macroGoals.bestMonth' => 'Best Month',
			'macroGoals.successRate2' => 'success rate',
			'macroGoals.effectiveType' => 'Effective Type',
			'macroGoals.historicalTotal' => 'Historical Total',
			'macroGoals.from_' => 'from',
			'macroGoals.globalSuccess' => 'Global Success',
			'macroGoals.completedGoals' => 'completed goals',
			'macroGoals.bestYear' => 'Best Year',
			'macroGoals.mostProductiveYear' => 'Most Productive Year',
			'macroGoals.totalGoals' => 'total goals',
			'macroGoals.allYears' => 'All years',
			'macroGoals.selectYearHeader' => 'SELECT YEAR',
			'macroGoals.completions' => 'Completions',
			'macroGoals.success2' => 'Success',
			'macroGoals.archiveCategory2' => 'Archive category?',
			'macroGoals.categoryUnavailableLinked' => ({required Object label, required Object count}) => 'The category "${label}" will no longer be available for new goals, but stays linked to ${count} historical goals and your statistics.',
			'macroGoals.categoryUnavailableArchived' => ({required Object label}) => 'The category "${label}" will no longer be available for new goals, but stays in your history.',
			'macroGoals.archive' => 'Archive',
			'macroGoals.createNewCategory' => 'Create new category',
			'statistics.completed2' => 'Completed',
			'statistics.notCompleted' => 'Not completed',
			'statistics.ofCompletion' => 'of completion',
			'statistics.growth' => 'Growth',
			'statistics.decline' => 'Decline',
			'statistics.strongestDay' => 'Strongest day',
			'statistics.weakestDay' => 'Weakest day',
			'statistics.worstNegativeStreak' => 'Worst Negative Streak',
			'statistics.missedConsecutiveDays' => 'missed consecutive days',
			'statistics.brokenStreaks' => 'Broken Streaks',
			'statistics.noBrokenStreaks' => 'No broken streaks recorded',
			'statistics.startedOn' => 'Started on',
			'statistics.moodCorrelation' => 'Mood Correlation',
			'statistics.avgMood' => 'Avg Mood (✓)',
			'statistics.avgEnergy' => 'Avg Energy (✓)',
			'statistics.onCompletedDays' => 'on completed days',
			'statistics.resilient' => 'Resilient',
			'statistics.completedVsMissed' => 'Completed vs Missed',
			'statistics.mood2' => 'Mood',
			'statistics.energy' => 'Energy',
			'statistics.performancePerLevel' => 'Performance per Level',
			'statistics.withHighMood' => 'With High Mood',
			'statistics.withLowMood' => 'With Low Mood',
			'statistics.moodEnergyAnalysis' => 'The analysis shows how your consistency is influenced by your mood and energy.',
			'statistics.missed2' => 'Missed',
			'statistics.positive' => 'positive',
			'statistics.neutral' => 'neutral',
			'statistics.high' => 'high',
			'statistics.low' => 'low',
			'statistics.skipped' => 'Skipped',
			'statistics.criticalHabits' => 'Critical Habits',
			'statistics.bestHabitsTitle' => 'Best Habits',
			'statistics.worseningHabitsDescription' => 'The habits that are getting worse the most.',
			'statistics.everythingIsGreat' => 'Everything is great!',
			'statistics.allHabitsStableDescription' => 'All your habits are maintaining or improving their trend. Keep going.',
			'statistics.habitCompletionPeriodDescription' => ({required Object rate}) => 'You completed this habit ${rate}% of the time in the selected period.',
			'statistics.habitLostConsistencyDescription' => ({required Object drop}) => 'This habit lost ${drop}% consistency in the last week compared with the previous one.',
			'statistics.negativeStreak' => 'Negative Streak',
			'statistics.currentStreak2' => 'Current Streak',
			'statistics.improvementAreas' => 'Improvement Areas',
			'statistics.habitsRequiringMoreAttention' => 'Habits requiring more attention.',
			'statistics.failureAnalysis' => 'Failure Analysis',
			'statistics.missedDaysPattern' => 'Frequency and patterns of your missed days.',
			'statistics.recoveryPatterns' => 'Recovery Patterns',
			'statistics.recoverySpeed' => 'How quickly you get back on track after a slip.',
			'statistics.avgRecoveryTime' => 'Avg Recovery Time',
			'statistics.worstStreak' => 'WORST STREAK',
			'statistics.frequency' => 'FREQUENCY',
			'statistics.daysShortUnit' => 'd',
			'statistics.perMonthUnit' => 'month',
			'statistics.succ' => 'succ.',
			'statistics.blackDay' => 'BLACK DAY',
			'statistics.correlationsWith' => 'Correlations with',
			'statistics.howThisHabitRelatesToOthers' => 'How this habit relates to others',
			'statistics.positiveCorrelations' => 'Positive Correlations',
			'statistics.negativeCorrelations' => 'Negative Correlations',
			'statistics.noSignificantPositiveCorrelation' => 'No significant positive correlation',
			'statistics.noSignificantNegativeCorrelation' => 'No significant negative correlation',
			'statistics.habitTogetherPercent' => ({required Object percentage}) => '${percentage}% together',
			'statistics.habitPositiveCorrelationDescription' => ({required Object currentGoal, required Object percentage, required Object otherGoal}) => 'When you complete "${currentGoal}", you have a ${percentage}% chance of also completing "${otherGoal}".',
			'statistics.habitNegativeCorrelationDescription' => ({required Object currentGoal, required Object percentage, required Object otherGoal}) => 'When you complete "${currentGoal}", you only have a ${percentage}% chance of also completing "${otherGoal}".',
			'statistics.weeklyTrend' => 'Weekly Trend',
			'statistics.monthlyTrend' => 'Monthly Trend',
			'statistics.yearlyTrend' => 'Yearly Trend',
			'statistics.performanceEvolution' => 'Performance Evolution',
			'statistics.globalTrend' => 'Global Trend',
			'statistics.total' => 'Total',
			'statistics.all' => 'All',
			'statistics.noDataForAlerts' => 'Not enough data to generate alerts.',
			'statistics.missed' => 'Missed',
			'goalState.active' => 'In progress',
			'dueLabel.lifetime' => 'Life goal',
			'dueLabel.annual' => 'Annual goal',
			'dueLabel.quarter' => 'Quarter',
			'dashboard.mood' => 'Mood',
			'dashboard.energy' => 'Energy',
			'dashboard.goodMorning' => 'Good morning',
			'dashboard.goodAfternoon' => 'Good afternoon',
			'dashboard.goodEvening' => 'Good evening',
			'dashboard.manager' => 'Manager',
			'dashboard.aiChat' => 'AI Chat',
			'dashboard.consecutiveDays' => 'consecutive days',
			'dashboard.welcomeTitle' => 'Welcome to Evolve',
			'dashboard.welcomeSubtitle' => 'Start your personal growth journey.',
			'dashboard.welcomeBody' => 'This app helps you build good habits and reach your long-term goals.',
			'dashboard.welcomeStart' => 'Start',
			'dashboard.subtitle' => 'Keep the pace. Every small action reinforces the person you are becoming.',
			'dashboard.completionToday' => 'Today\'s completion',
			'dashboard.habitsCount' => ({required Object done, required Object total}) => '${done}/${total} habits',
			'dashboard.bestStreak' => 'Best streak',
			'dashboard.activeGoals' => 'Active goals',
			'dashboard.avgProgress' => ({required Object pct}) => '${pct}% average progress',
			'dashboard.momentum' => 'Momentum',
			'dashboard.vsLastWeek' => 'vs. last week',
			'dashboard.weeklyTrend' => 'Weekly trend',
			'dashboard.weeklyTrendSubtitle' => 'Completion rate of your habits',
			'dashboard.thisWeekPill' => ({required Object value}) => '${value} this week',
			'dashboard.todayProtocol' => 'Today\'s protocol',
			'dashboard.todayProtocolSubtitle' => 'Complete the essential actions before adding more',
			'dashboard.actionsCount' => ({required Object count}) => '${count} actions',
			'dashboard.emptyHabits' => 'Your canvas is empty. Create your first habit.',
			'dashboard.streakDaysShort' => ({required Object n}) => '${n} d',
			'dashboard.checkInDone' => 'Check-in recorded',
			'dashboard.checkInPrompt' => 'How do you feel today?',
			'dashboard.moodEnergyValue' => ({required Object mood, required Object energy}) => 'Mood ${mood}/10 · Energy ${energy}/10',
			'dashboard.checkInHint' => 'Record mood and energy to improve your pattern analysis.',
			'dashboard.updateCheckIn' => 'Update check-in',
			'dashboard.doCheckIn' => 'Do the check-in',
			'dashboard.dailyCheckIn' => 'Daily check-in',
			'dashboard.dailyCheckInSubtitle' => 'A quick reading helps Evolve better understand your patterns.',
			'dashboard.record' => 'Record',
			'dashboard.focusGoals' => 'Goals in focus',
			'dashboard.currentPriorities' => 'Current priorities',
			'dashboard.goalLimitReached' => '100-goal limit reached. Upgrade to Pro to create more.',
			'dashboard.emptyFocusGoals' => 'No goals in focus. Add one.',
			'dashboard.weekToStart' => 'Week to kick off',
			'dashboard.weekGrowing' => 'Week on the rise',
			'dashboard.weekToRecover' => 'Week to recover',
			'dashboard.vsPreviousWeek' => ({required Object value}) => '${value} vs. the previous week.',
			'stats.title' => 'Statistics',
			'stats.global' => 'Global',
			'stats.resilience' => 'Resilience',
			'stats.tabHabits' => 'Habits',
			'stats.tabMood' => 'Mood',
			'stats.last30Days' => 'Last 30 days',
			'stats.singleHabit' => 'Single habit',
			'stats.noHabit' => 'No habit',
			'stats.completionToday' => 'Today\'s completion',
			'stats.bestStreakLabel' => 'Best streak',
			'stats.criticalDay' => 'Critical day',
			'stats.completePrioritiesFirst' => 'Complete priorities first',
			'stats.recentActivity' => 'Recent activity',
			'stats.recentActivitySubtitle' => 'Completion intensity over the last 90 days',
			'stats.trendGlobal' => 'Global trend',
			'stats.trendGlobalSubtitle' => 'Time comparison of the protocol',
			'stats.vsPrevDay' => ({required Object value}) => '${value}% vs previous day',
			'stats.bestHabit' => 'Best habit',
			'stats.criticalArea' => 'Critical area',
			'stats.streakAtRisk' => 'Streak at risk',
			'stats.streakAtRiskDetail' => ({required Object habit}) => '${habit} needs attention in the next check-ins.',
			'stats.patternToConsolidate' => 'Pattern to consolidate',
			'stats.checkLowMoodDays' => 'Check low-mood days and keep the essential protocol.',
			'stats.goalDue' => 'Goal due soon',
			'stats.noGoalNeedsIntervention' => 'No active goal needs intervention.',
			'stats.performancePerHabit' => 'Performance per habit',
			'stats.performancePerHabitSubtitle' => 'Ranking computed from synced logs by weekly consistency',
			'stats.avgMood' => 'Average mood',
			'stats.avgEnergy' => 'Average energy',
			'stats.checkInsAvailable' => ({required Object count}) => '${count} check-ins available',
			'stats.resilientHabit' => 'Resilient habit',
			'stats.completedEvenHardDays' => 'Completed even on hard days',
			'stats.moodEnergy' => 'Mood and energy',
			'stats.moodEnergySubtitle' => 'Average of available check-ins over the last 90 days',
			'stats.completion' => 'Completion',
			'stats.currentWeek' => 'Current week',
			'stats.currentStreak' => 'Current streak',
			'stats.currentStreakDetail' => 'Streak synced from available logs',
			'stats.trend30' => '30-day trend',
			'stats.trend30Detail' => 'Completion over the last 30 days',
			'stats.yearlyCalendar' => 'Yearly calendar',
			'stats.yearlyCalendarSubtitle' => ({required Object habit}) => 'Distribution of completions for ${habit}',
			'stats.performancePerDay' => 'Performance per day',
			'stats.performancePerDaySubtitle' => 'Strong and weak days of the week',
			'stats.protectStreak' => ({required Object days}) => 'Protect the ${days}-day streak',
			'stats.keepSameSlot' => 'Keep the same time slot to reduce friction on the busiest days.',
			'stats.worstNegativeSeq' => ({required Object days}) => 'The worst negative streak lasted ${days} days.',
			'stats.positiveLever' => 'Positive lever detected',
			'stats.bestHabitRegularity' => ({required Object habit}) => '${habit} keeps the best recent regularity.',
			'stats.moodSensitivity' => 'Mood sensitivity',
			'stats.lowEnergyCompletion' => 'Completion with low energy',
			'stats.moodOutputCorrelation' => 'Mood-output correlation',
			'stats.moodOutputSubtitle' => 'Completions available on check-in days',
			'stats.keyCorrelations' => 'Key correlations',
			'stats.keyCorrelationsSubtitle' => 'Patterns that most influence the protocol',
			'stats.moreLogsNeeded' => 'More logs are needed to compute useful correlations.',
			'stats.createHabitForAnalysis' => 'Create at least one habit to see the granular analysis.',
			'stats.noData' => 'No data',
			'stats.tabInfo' => 'Info',
			'stats.tabTrend' => 'Trend',
			'stats.tabAlerts' => 'Alerts',
			'stats.tabOverview' => 'Overview',
			'stats.tabCalendar' => 'Calendar',
			'stats.tabPerformance' => 'Performance',
			'stats.tabImprovement' => 'Improvement',
			'stats.pageSubtitle' => 'Spot the patterns that drive growth and act on the critical areas.',
			'stats.actionsFraction' => ({required Object done, required Object total}) => '${done}/${total} actions',
			'stats.affectedByHardDays' => ({required Object habit}) => '${habit} is affected by hard days',
			'stats.last30DaysTrend' => 'Last 30 Days Trend',
			'stats.strongestDayDetail' => ({required Object pct, required Object done, required Object total}) => 'Well done, ${pct}% completion (${done}/${total})',
			'stats.weakestDayDetail' => ({required Object pct, required Object done, required Object total}) => 'Only ${pct}% completion (${done}/${total})',
			'stats.brokenStreakItem' => ({required Object days}) => 'Streak of ${days} days broken',
			'stats.togetherProbability' => ({required Object percentage}) => '${percentage}% together',
			'stats.criticalHabitsSubtitle' => 'The habits that are getting worse the most.',
			'stats.bestHabitsSubtitle' => 'The habits you are most consistent with.',
			'stats.timeframeWeek' => 'Week',
			'stats.timeframeMonth' => 'Month',
			'stats.timeframeYear' => 'Year',
			'stats.timeframeAll' => 'All',
			'stats.negativeStreakDays' => ({required Object days}) => '${days} days without completion',
			'stats.dropPercent' => ({required Object drop}) => '-${drop}%',
			'stats.blackDayDetail' => ({required Object day}) => 'Black day: ${day}',
			'stats.failureDetail' => ({required Object streak, required Object frequency}) => 'Worst streak: ${streak}d · ~${frequency}/month missed',
			'stats.recoveryDetail' => ({required Object days}) => 'Average recovery time: ${days} days',
			'stats.successRate' => ({required Object rate}) => '${rate}% success',
			'stats.sortRate' => 'Rate',
			'stats.sortStreak' => 'Streak',
			'stats.sortName' => 'Name',
			'stats.filterActive' => 'Active',
			'stats.filterAll' => 'All',
			'stats.noActiveHabits' => 'No active habits — switch to All to see ended ones.',
			'stats.worstStreakLabel' => 'Worst',
			'stats.momentumTitle' => 'Momentum',
			'stats.momentumSubtitle' => 'Your current form',
			'stats.momentumForm' => 'FORM',
			'stats.momentumRate' => '7-day',
			'stats.momentumStreakHealth' => 'Streaks',
			'stats.momentumTrend' => 'Trend',
			'stats.rollingImproving' => 'Improving',
			'stats.rollingDeclining' => 'Declining',
			'stats.rollingSteady' => 'Steady',
			'stats.lifetimeConsistency' => 'Consistency',
			'stats.lifetimeConsistencyDetail' => 'All-time completion',
			'stats.lifetimeTotalDone' => 'Total done',
			'stats.lifetimeTotalDoneDetail' => 'Habits checked off',
			'stats.lifetimePerfectDays' => 'Perfect days',
			'stats.lifetimePerfectDaysDetail' => 'Everything completed',
			'stats.lifetimeDaysTracked' => 'Days tracked',
			'stats.lifetimeDaysTrackedDetail' => 'Since you started',
			'stats.keystoneTitle' => 'KEYSTONE HABIT',
			'stats.keystoneImpact' => ({required Object withPct, required Object withoutPct}) => 'On its days you complete ${withPct}% of your other habits, vs ${withoutPct}% otherwise.',
			'stats.yearActivity' => '365-day activity',
			'stats.yearActivitySubtitle' => 'Every habit, every day',
			'stats.activeDaysCount' => ({required Object count}) => '${count} active days',
			'stats.heatmapLess' => 'Less',
			'stats.heatmapMore' => 'More',
			'stats.bestHabitsTitle' => 'Best habits',
			'stats.criticalHabitsTitle' => 'Needs attention',
			'stats.criticalStalled' => ({required Object days}) => '${days}d idle',
			'stats.rollingTitle' => 'Rolling completion',
			'stats.rollingSubtitle' => '7-day and 30-day rate',
			'stats.rolling7' => '7-day',
			'stats.rolling30' => '30-day',
			'stats.weekVsAvgTitle' => 'This week vs average',
			'stats.weekVsAvgSubtitle' => 'How this week compares',
			'stats.thisWeek' => 'This week',
			'stats.yourAverage' => 'Your average',
			'stats.weekdayShapeTitle' => 'Weekly rhythm',
			'stats.weekdayShapeSubtitle' => 'Completion by weekday',
			'stats.weekdayWeekendTitle' => 'Weekday vs weekend',
			'stats.weekdayWeekendSubtitle' => 'Where you\'re strongest',
			'stats.weekdaysLabel' => 'Weekdays',
			'stats.weekendLabel' => 'Weekend',
			'stats.seasonalityTitle' => 'Seasonality',
			'stats.seasonalitySubtitle' => 'Completion by month',
			'stats.bounceBackTitle' => 'Bounce-back rate',
			'stats.bounceBackSubtitle' => 'Recovery after a miss',
			'stats.bounceBackDetail' => ({required Object recoveries, required Object opportunities}) => 'Recovered ${recoveries} of ${opportunities} times',
			'stats.dangerZoneTitle' => 'Danger zone',
			'stats.dangerZoneSubtitle' => 'When streaks break',
			'stats.dangerZoneNone' => 'No broken streaks yet',
			'stats.dangerZoneDetail' => ({required Object breaks, required Object total}) => '${breaks} of ${total} breaks land here',
			'stats.performanceComparisonTitle' => 'Performance comparison',
			'stats.performanceComparisonSubtitle' => 'Best vs worst streak',
			'stats.perfCompGap' => ({required Object pct}) => '${pct}% gap',
			'stats.perfCompBest' => 'Best',
			'stats.perfCompWorst' => 'Worst',
			'stats.consistencyTitle' => 'Consistency',
			'stats.consistencySubtitle' => 'Most regular habits',
			'stats.consistencySteadiest' => 'Steadiest',
			'stats.consistencyErratic' => 'Most erratic',
			'stats.medalsTitle' => 'Streak leaderboard',
			'stats.medalsSubtitle' => 'Longest current streaks',
			'stats.neverMissedTitle' => 'Never missed',
			'stats.neverMissedEmpty' => 'No perfect habits yet',
			'stats.distributionTitle' => 'Completion spread',
			'stats.distributionSubtitle' => 'Habits by success rate',
			'stats.synergyTitle' => 'Habit synergy',
			'stats.synergySubtitle' => 'Which habits move together',
			'stats.moodSensitiveTitle' => 'Mood-sensitive',
			'stats.moodSensitiveSubtitle' => 'Swayed most by your mood',
			'stats.resilientHabitsTitle' => 'Resilient habits',
			'stats.resilientHabitsSubtitle' => 'Done even on low days',
			'stats.correlationAnalysisTitle' => 'Mood correlation',
			'stats.correlationAnalysisSubtitle' => 'Low vs high mood completion',
			'stats.moodEnergyTrendTitle' => 'Mood & energy',
			'stats.moodEnergyTrendSubtitle' => ({required Object days}) => 'Last ${days} days',
			'stats.allTimeBest' => 'All-time record',
			'stats.topPerformerLabel' => 'Top performer',
			'stats.currentStreakShort' => 'Now',
			'stats.recordLabel' => 'Record',
			'stats.recordDetail' => 'Best streak ever',
			'stats.adherenceTitle' => 'Schedule adherence',
			'stats.adherenceSubtitle' => 'Of the days it was due',
			'stats.adherenceDetail' => ({required Object done, required Object scheduled}) => '${done} of ${scheduled} scheduled days',
			'stats.atRiskTitle' => 'At risk',
			'stats.atRiskYes' => 'Yes',
			'stats.atRiskNo' => 'On track',
			'stats.atRiskDetail' => ({required Object days}) => '${days} days since last done',
			'stats.daysUnit' => 'd',
			'stats.gapTitle' => 'Timing gaps',
			'stats.gapSubtitle' => 'Days between completions',
			'stats.gapAvg' => 'Avg gap',
			'stats.gapLongest' => 'Longest',
			'stats.gapSince' => 'Since last',
			'stats.habitBounceBackShort' => 'Bounce-back',
			'stats.habitConsistencyDetail' => 'Regularity score',
			'stats.habitPercentile' => ({required Object pct}) => 'Ahead of ${pct}% of your habits',
			'stats.monthVsTitle' => 'This month vs last',
			'stats.monthVsSubtitle' => 'Completion, month over month',
			'stats.thisMonthLabel' => 'This month',
			'stats.lastMonthLabel' => 'Last month',
			'stats.nextDayMoodTitle' => 'Next-day mood impact',
			'stats.nextDayMoodSubtitle' => 'Mood & energy the day after',
			'stats.nextDayAfterDone' => 'After doing it',
			'stats.nextDayAfterMissed' => 'After missing it',
			'stats.nextDayMoodLift' => ({required Object value}) => '${value} mood lift',
			'stats.streakHistoryTitle' => 'Streak history',
			'stats.streakHistorySubtitle' => 'Every run of consecutive days',
			'stats.streakHistoryDetail' => ({required Object count, required Object longest}) => '${count} streaks · longest ${longest} days',
			'habitsPage.today' => 'Today',
			'habitsPage.subtitle' => 'Build your daily protocol and watch consistency over time.',
			'habitsPage.tabProtocol' => 'Protocol',
			_ => null,
		} ?? switch (path) {
			'habitsPage.tabCalendar' => 'Calendar',
			'habitsPage.deleteHabitTitle' => 'Delete habit',
			'habitsPage.deleteHabitConfirm' => ({required Object title}) => 'Remove "${title}" from the protocol?',
			'habitsPage.activeProtocol' => 'Active protocol',
			'habitsPage.completedToday' => 'Completed today',
			'habitsPage.dailyProtocol' => 'Daily protocol',
			'habitsPage.protocolSubtitle' => 'Weekly overview, reminders and quick actions',
			'habitsPage.colHabit' => 'HABIT',
			'habitsPage.colStreak' => 'STREAK',
			'habitsPage.colLast7Days' => 'LAST 7 DAYS',
			'habitsPage.colReminder' => 'REMINDER',
			'habitsPage.streakDays' => ({required Object n}) => '${n} days',
			'habitsPage.prevPeriod' => 'Previous period',
			'habitsPage.nextPeriod' => 'Next period',
			'habitsPage.weekdayAbbrevUpper.0' => 'MON',
			'habitsPage.weekdayAbbrevUpper.1' => 'TUE',
			'habitsPage.weekdayAbbrevUpper.2' => 'WED',
			'habitsPage.weekdayAbbrevUpper.3' => 'THU',
			'habitsPage.weekdayAbbrevUpper.4' => 'FRI',
			'habitsPage.weekdayAbbrevUpper.5' => 'SAT',
			'habitsPage.weekdayAbbrevUpper.6' => 'SUN',
			'habitsPage.lifeView' => 'Life view',
			'habitsPage.lifeViewSubtitle' => 'One cell represents a month of the journey up to age 85.',
			'habitsPage.monthsLived' => 'Months lived',
			'habitsPage.currentAge' => 'Current age',
			'habitsPage.monthsRemaining' => 'Months remaining',
			'habitsPage.dayDetail' => ({required Object day, required Object month}) => 'Details ${day} ${month}',
			'habitsPage.dayDetailSubtitle' => 'Update the status of habits for this day.',
			'habitsPage.editHabit' => 'Edit habit',
			'habitsPage.newHabit' => 'New habit',
			'habitsPage.optionalReminder' => 'Optional reminder',
			'habitsPage.reminderHint' => 'e.g. 08:30',
			'habitsPage.close' => 'Close',
			'habitsPage.statusDone' => 'Completed',
			'habitsPage.statusSkipped' => 'Skipped',
			'habitsPage.statusUnrecorded' => 'Not recorded',
			'habitsPage.weekOf' => ({required Object day, required Object month}) => 'Week of ${day} ${month}',
			'habitsPage.lifeWeeks' => 'Weeks of your journey',
			'habitsPage.catMindfulness' => 'Mindfulness',
			'habitsPage.editableHint' => 'Only today and yesterday can be edited.',
			'lavoro' => 'Work',
			'salute' => 'Health',
			'finanza' => 'Finance',
			'relazioni' => 'Relationships',
			'formazione' => 'Education',
			'hobby' => 'Hobbies',
			'spirituale' => 'Spiritual',
			'altro' => 'Other',
			'goalsPage.title' => 'Macro Goals',
			'goalsPage.subtitle' => 'Long-term planning.',
			'goalsPage.sampleGoal' => 'Sample goal',
			'goalsPage.periodLifetime' => 'Life goals',
			'goalsPage.subtitleLifetime' => 'Lifetime goals',
			'goalsPage.subtitleAnnual' => 'Annual goals',
			'goalsPage.subtitleQuarterly' => 'Quarterly goals',
			'goalsPage.subtitleMonthly' => 'Monthly goals',
			'goalsPage.subtitleWeekly' => 'Weekly goals',
			'goalsPage.statsTab' => 'Stats',
			'goalsPage.fullView' => 'Full view',
			'goalsPage.categoriesTitle' => 'Goal categories',
			'goalsPage.defaultPill' => 'Default',
			'goalsPage.editCategory' => 'Edit category',
			'goalsPage.archiveCategory' => 'Archive category',
			'goalsPage.categoryCreateFailed' => 'Failed to create category.',
			'goalsPage.categoryArchiveFailed' => 'Failed to archive category.',
			'goalsPage.categoryEditFailed' => 'Failed to edit category.',
			'goalsPage.addCategory' => 'Add category',
			'goalsPage.back' => 'Back',
			'goalsPage.finish' => 'Finish',
			'goalsPage.next' => 'Next',
			'goalsPage.categoriesTooltip' => 'Categories',
			'goalsPage.rescheduleTooltip' => 'Reschedule to next period',
			'goalsPage.defaultCategory' => 'Default',
			'goalsPage.emptyActive' => 'No active goal in this period.',
			'goalsPage.emptyAdd' => 'Add the first goal for this period.',
			'goalsPage.newGoal' => 'New goal',
			'goalsPage.editGoal' => 'Edit goal',
			'goalsPage.horizonLabel' => 'Horizon',
			'goalsPage.newCategory' => 'New category',
			'goalsPage.nameLabel' => 'Name',
			'goalsPage.weekPeriodLabel' => ({required Object week, required Object month, required Object year}) => 'Week ${week}, ${month} ${year}',
			'goalsPage.currentQuarter' => 'Current quarter',
			'goalsPage.currentMonth' => 'Current month',
			'goalsStats.proRequired' => 'Pro feature required',
			'goalsStats.active' => 'Active',
			'goalsStats.failed' => 'Failed',
			'goalsStats.complAbbr' => 'Compl.',
			'goalsStats.seasonality' => 'Seasonality',
			'goalsStats.interestEvolution' => 'Interest evolution',
			'ai.coach' => 'AI Coach',
			'ai.dailyHabits' => 'Daily habits',
			'ai.macroGoals' => 'Macro goals',
			'ai.openRouter.apiKeyMissingShort' => '⚠️ The AI Coach needs your own OpenRouter API key. Add one in Settings to start chatting.',
			'ai.openRouter.apiKeyInvalid' => '⚠️ OpenRouter rejected this API key. Check it in Settings, or create a new one at openrouter.ai/keys.',
			'ai.openRouter.defaultSystemPrompt' => 'You are the "Discipline Coach", a virtual assistant focused on helping the user stay disciplined, reach goals, and build healthy habits. Be motivating but concrete, direct, and practical. Use a professional but friendly tone.',
			'ai.openRouter.communicationError' => ({required Object code}) => '❌ Error communicating with the AI. (Code: ${code})',
			'ai.openRouter.connectionError' => '❌ Connection error. Make sure you are online and try again.',
			'ai.openRouter.connectionErrorShort' => '❌ Connection error.',
			'ai.openRouter.connectionCheckTimeout' => '❌ Error: Connection check took too long.',
			'ai.openRouter.contextTooLong' => '⚠️ This conversation got too long for the model. Start a new chat (top right) to continue.',
			'ai.openRouter.noInternet' => '❌ Error: No internet connection. Check your network.',
			'ai.openRouter.serverTimeout' => '❌ Error: The server is taking too long to respond. Try again.',
			'ai.openRouter.apiError' => ({required Object code}) => '❌ API error: ${code} (check Sentry for details)',
			'ai.apiKey.rowTitle' => 'Your OpenRouter account',
			'ai.apiKey.description' => 'Prefer to run the coach on your own account? Connect an OpenRouter key and you pay the provider directly — no Evolve subscription needed. Create one at openrouter.ai/keys. It is stored in this device’s keychain and only ever sent to OpenRouter.',
			'ai.apiKey.fieldLabel' => 'API key',
			'ai.apiKey.hint' => 'sk-or-v1-…',
			'ai.apiKey.save' => 'Save key',
			'ai.apiKey.saved' => 'API key saved',
			'ai.apiKey.remove' => 'Remove key',
			'ai.apiKey.removed' => 'API key removed',
			'ai.apiKey.removeConfirmTitle' => 'Remove API key?',
			'ai.apiKey.removeConfirmBody' => 'This engine will stop replying until you connect an account again. Evolve AI and local models are unaffected.',
			'ai.apiKey.statusSet' => 'Saved',
			'ai.apiKey.statusMissing' => 'Not set',
			'ai.apiKey.saveFailed' => 'Couldn\'t save the key to the keychain. Try again.',
			'ai.apiKey.setupTitle' => 'Connect your OpenRouter account',
			'ai.apiKey.setupBody' => 'This engine runs on your own OpenRouter account. Connect it to start chatting — or switch to Evolve AI, included with Pro.',
			'ai.apiKey.setupAction' => 'Connect account',
			'ai.suggestions.morningBoost' => '🔥 Give me a boost to get started!',
			'ai.suggestions.avoidDistractions' => '🧠 How can I avoid distractions?',
			'ai.suggestions.lowEnergy' => '⚡ My energy is dropping. What should I do?',
			'ai.suggestions.stayFocused' => '💪 Give me one tip to stay focused',
			'ai.suggestions.prepareTomorrow' => '🛌 How can I prepare for a productive tomorrow?',
			'ai.suggestions.disciplineReflection' => '📝 Reflect on today’s discipline',
			'ai.suggestions.analyzeActiveGoals' => '🎯 Analyze my active goals',
			'ai.suggestions.planMacroGoals' => '🗺️ How should I plan my macro goals?',
			'ai.suggestions.goalObstacles' => '🛑 What obstacles are blocking my goals?',
			'ai.suggestions.reachMilestones' => '📈 Give me one tip to reach my milestones',
			'ai.suggestions.consistencyStatus' => '📈 How is my consistency going?',
			'ai.suggestions.weeklyStats' => '📊 My weekly stats',
			'ai.suggestions.planDay' => '🌅 Plan my day',
			'ai.suggestions.raiseBar' => '🚀 How can I raise the bar?',
			'ai.suggestions.recoverProcrastination' => '🤕 How can I recover after procrastinating?',
			'ai.suggestions.connectHabitsGoals' => '🔗 How can I connect habits to goals?',
			'ai.suggestions.reviewGoalsHabits' => '📊 Review my goals and habits',
			'ai.suggestions.disciplineAdvice' => '🔥 Discipline advice',
			'ai.suggestions.createNewHabit' => '💡 How can I create a new habit?',
			'ai.local.notReachable' => ({required Object url}) => '❌ Local AI server not reachable at ${url}. Make sure Ollama or LM Studio is running.',
			'ai.local.modelMissing' => '⚠️ Choose a local model first — open the model picker at the top.',
			'ai.local.requestFailed' => ({required Object code}) => '❌ Local model error (code: ${code}).',
			'ai.local.streamError' => '❌ Connection to the local model failed.',
			'ai.local.timeout' => '❌ The local model is taking too long — it may still be loading. Try again.',
			'ai.local.modelNotFound' => '❌ That model isn\'t available on the server. Open the model picker to choose or load one.',
			'ai.standard.sessionExpired' => '⚠️ Your session expired. Sign in again to keep using Evolve AI.',
			'ai.standard.needsPro' => '⚠️ Evolve AI is part of Evolve Pro. Subscribe in Settings — or switch the engine to your own OpenRouter account, which is free.',
			'ai.standard.rateLimited' => '⚠️ You\'ve reached the Evolve AI fair-use limit for now. Try again later, or switch the engine to your own OpenRouter account.',
			'ai.standard.unavailable' => '❌ Evolve AI is unavailable right now. This one\'s on us — please try again in a moment.',
			'ai.consent.standardTitle' => 'Send your messages to the AI?',
			'ai.consent.standardBody' => 'To reply, the AI Coach sends your message, your first name and any context you choose to share to OpenRouter, Inc., which routes it to Google LLC (Google AI Studio) to run the model. Because this uses Google\'s free tier, Google may keep the text for a limited period and use it to improve their services — it is not as private as a paid tier. You can withdraw this any time in Settings, and everything else in Evolve keeps working without it.',
			'ai.consent.byokTitle' => 'Send your messages to OpenRouter?',
			'ai.consent.byokBody' => 'To reply, the AI Coach sends your message, your first name and any context you choose to share to OpenRouter, Inc. using your own OpenRouter account. OpenRouter routes it to a model provider according to your account settings. You can withdraw this any time in Settings, and everything else in Evolve keeps working without it.',
			'ai.consent.privateNote' => 'Your private database stays on this device — only what you send in the chat leaves it.',
			'ai.consent.allow' => 'Allow',
			'ai.consent.decline' => 'Not now',
			'ai.consent.rowTitle' => 'AI data sharing',
			'ai.consent.statusGranted' => 'Allowed',
			'ai.consent.statusNone' => 'Not allowed',
			'ai.consent.revokeTitle' => 'Stop sharing with the AI?',
			'ai.consent.revokeBody' => 'The AI Coach will ask again before it sends anything. Nothing else changes.',
			'ai.consent.revokeAction' => 'Stop sharing',
			'aiCoach.greeting' => 'Hi! I\'m Evolve AI Coach. I\'m here to help you optimize your protocol and reach your goals. How can I help you today?',
			'aiCoach.systemPersona' => 'You are Evolve AI Coach, a virtual assistant for personal discipline.',
			'aiCoach.habitsHeader' => 'ACTIVE HABITS:',
			'aiCoach.noActiveHabits' => 'No active habits.',
			'aiCoach.habitLine' => ({required Object title, required Object done, required Object streak}) => '${title} (Completed today: ${done}, Streak: ${streak})',
			'aiCoach.goalsHeader' => 'GOALS:',
			'aiCoach.noActiveGoals' => 'No active long-term goals.',
			'aiCoach.goalLine' => ({required Object title, required Object due}) => '${title} (Due: ${due})',
			'aiCoach.contextTitle' => 'AI Context',
			'aiCoach.contextBody' => 'Choose which data to share with the AI Coach to get personalized advice.',
			'aiCoach.shareHabitsDesc' => 'Shares your active habits, streaks and today\'s completion status.',
			'aiCoach.shareGoalsDesc' => 'Shares your active long-term goals.',
			'aiCoach.saveClose' => 'Save and close',
			'aiCoach.subtitle' => 'Reason about patterns with a contextual coach based on your journey data.',
			'aiCoach.contextButton' => 'Context',
			'aiCoach.typing' => 'AI Coach is typing...',
			'aiCoach.inputHint' => 'Ask your Coach for advice...',
			'aiCoach.defaultUserName' => 'user',
			'aiCoach.userNameLine' => ({required Object userName}) => '- Name: ${userName}',
			'aiCoach.activeGoalsCount' => ({required Object count}) => '- Active goals: ${count}',
			'aiCoach.completedGoalsCount' => ({required Object count}) => '- Completed goals: ${count}',
			'aiCoach.todayCompletion' => ({required Object completed, required Object total}) => '- Habits today: ${completed} completed out of ${total} total.',
			'aiCoach.newChatTooltip' => 'New chat',
			'aiCoach.clearConfirmTitle' => 'Start a new chat?',
			'aiCoach.clearConfirmBody' => 'This clears the current conversation — it isn\'t saved.',
			'aiCoach.clearConfirmCancel' => 'Cancel',
			'aiCoach.clearConfirmAccept' => 'New chat',
			'aiCoach.copyTooltip' => 'Copy',
			'aiCoach.copiedToast' => 'Copied to clipboard',
			'aiCoach.linkOpenFailed' => 'Couldn\'t open the link.',
			'settingsPage.account' => 'Account',
			'settingsPage.notifications' => 'Notifications',
			'settingsPage.language' => 'Language',
			'settingsPage.timeFormat24h' => '24h Format',
			'settingsPage.subscription' => 'Subscription',
			'settingsPage.proName' => 'Evolve Pro',
			'settingsPage.planMonthly' => 'Monthly',
			'settingsPage.planAnnual' => 'Annual',
			'settingsPage.restorePurchases' => 'Restore purchases',
			'settingsPage.deletePrivateData' => 'Delete private data',
			'settingsPage.importInProgress' => 'Importing data...',
			'settingsPage.passwordsDontMatch' => 'Passwords do not match.',
			'settingsPage.email' => 'Email',
			'settingsPage.cancel' => 'Cancel',
			'settingsPage.confirm' => 'Confirm',
			'settingsPage.save' => 'Save',
			'settingsPage.pageTitle' => 'Settings',
			'settingsPage.pageSubtitle' => 'Manage your profile, desktop behavior, privacy and Evolve plan.',
			'settingsPage.profileLabel' => 'Profile',
			'settingsPage.profileSubtitle' => 'Personal information and sync status',
			'settingsPage.accountAndOnboarding' => 'Account and onboarding',
			'settingsPage.privateMode' => 'Private Mode',
			'settingsPage.sessionUnavailable' => 'Session unavailable',
			'settingsPage.dataRepository' => 'Data repository',
			'settingsPage.encryptedLocalDatabase' => 'Encrypted local database',
			'settingsPage.supabaseWithEncryptedCache' => 'Supabase with encrypted cache',
			'settingsPage.personalInfo' => 'Personal information',
			'settingsPage.personalInfoDetail' => 'First name, last name, email and date of birth',
			'settingsPage.updateAvatar' => 'Update avatar',
			'settingsPage.updateAvatarDetail' => 'Choose a local image for the desktop profile.',
			'settingsPage.reviewInitialConsent' => 'Review initial consent',
			'settingsPage.reviewInitialConsentDetail' => 'Terms, privacy, notifications and crash reporting',
			'settingsPage.signOut' => 'Sign out of your account',
			'settingsPage.signOutDetailActive' => 'Close the session on this device',
			'settingsPage.availableWithActiveSession' => 'Available with an active Supabase session',
			'settingsPage.goToLogin' => 'Go to Login',
			'settingsPage.goToLoginDetail' => 'Suspend private mode and sign in to Supabase.',
			'settingsPage.appearanceTitle' => 'Appearance and application',
			'settingsPage.appearanceSubtitle' => 'Local preferences adapted to desktop',
			'settingsPage.appearanceAndVisual' => 'Appearance and visuals',
			'settingsPage.themeMode' => 'Theme',
			'settingsPage.themeLight' => 'Light',
			'settingsPage.themeDark' => 'Dark',
			'settingsPage.themeSystem' => 'Follow system',
			'settingsPage.calendarExperienceLanguage' => 'Calendar, experience and language',
			'settingsPage.accentColor' => 'Accent color',
			'settingsPage.accentColorDetail' => 'Extended palette reserved for Evolve Pro.',
			'settingsPage.defaultCalendarView' => 'Default calendar view',
			'settingsPage.calendarViewOptions.month' => 'Month',
			'settingsPage.calendarViewOptions.week' => 'Week',
			'settingsPage.calendarViewOptions.year' => 'Year',
			'settingsPage.calendarViewOptions.life' => 'Life',
			'settingsPage.languageOptions.system' => 'System',
			'settingsPage.languageOptions.italian' => 'Italian',
			'settingsPage.languageOptions.english' => 'English',
			'settingsPage.languageOptions.spanish' => 'Spanish',
			'settingsPage.languageOptions.german' => 'German',
			'settingsPage.languageOptions.arabic' => 'Arabic',
			'settingsPage.timeFormat24hDetail' => 'Use times like 20:30 instead of 8:30 PM.',
			'settingsPage.hapticFeedback' => 'Haptic feedback',
			'settingsPage.hapticFeedbackDetail' => 'The desktop keeps the preference but does not generate vibrations.',
			'settingsPage.aiAndSystem' => 'AI & SYSTEM',
			'settingsPage.aiSuggestions' => 'AI Suggestions',
			'settingsPage.aiSuggestionsDetail' => 'Intelligent habit analysis',
			'settingsPage.focusMode' => 'Focus Mode',
			'settingsPage.focusModeDetail' => 'Pauses all reminders and notifications.',
			'settingsPage.milestones' => 'Milestones',
			'settingsPage.milestonesDetail' => 'Celebrations when you reach key milestones.',
			'settingsPage.deepWorkInsights' => 'Deep Work Insights',
			'settingsPage.deepWorkInsightsDetail' => 'Advanced analysis of your focus sessions.',
			'settingsPage.resetTutorial' => 'Reset tutorial',
			'settingsPage.resetTutorialDetail' => 'Reopens the dashboard and goals walkthroughs.',
			'settingsPage.notificationsSubtitle' => 'Operational reminders from the desktop client',
			'settingsPage.operationalReminders' => 'Operational reminders',
			'settingsPage.habitReminders' => 'Habit reminders',
			'settingsPage.habitRemindersDetail' => 'Sends the daily morning briefing.',
			'settingsPage.morningBriefTime' => 'Morning brief time',
			'settingsPage.eveningReview' => 'Evening review',
			'settingsPage.eveningReviewDetail' => 'Reminds you to consolidate your day.',
			'settingsPage.eveningReviewTime' => 'Evening review time',
			'settingsPage.insightsAndReports' => 'Insights and reports',
			'settingsPage.aiInsights' => 'AI Insights',
			'settingsPage.aiInsightsDetail' => 'Personalized analysis and advice from AI.',
			'settingsPage.weeklyReports' => 'Weekly Reports',
			'settingsPage.weeklyReportsDetail' => 'A weekly summary of your progress.',
			'settingsPage.requestNotificationPermissions' => 'Request notification permissions',
			'settingsPage.requestNotificationPermissionsDetail' => 'Opens the native prompt on the supported target.',
			'settingsPage.nativeDeliveryTitle' => 'Native delivery per operating system',
			'settingsPage.privacyTitle' => 'Privacy and security',
			'settingsPage.privacySubtitle' => 'Access protection, consents and data management',
			'settingsPage.accessProtection' => 'Access protection',
			'settingsPage.biometricLock' => 'Biometric lock',
			'settingsPage.biometricLockDetail' => 'Available with the native adapter on macOS and Windows; not supported on Linux.',
			'settingsPage.changePassword' => 'Change password',
			'settingsPage.changePasswordDetail' => 'Credential update via Supabase Auth.',
			'settingsPage.dataAndConsents' => 'Data and consents',
			'settingsPage.sendCrashReports' => 'Send crash reports',
			'settingsPage.sendCrashReportsDetail' => 'Separate consent for Sentry.',
			'settingsPage.exportData' => 'Export data',
			'settingsPage.exportDataDetail' => 'Shares a complete JSON export of the available data.',
			'settingsPage.importData' => 'Import data',
			'settingsPage.importDataDetail' => 'Restores a backup (JSON or ZIP) from Evolve.',
			'settingsPage.systemPermissionsManagement' => 'System permissions management',
			'settingsPage.systemPermissionsManagementDetail' => 'Notifications, calendar and security.',
			'settingsPage.deletePrivateDataDetail' => 'Permanently deletes the encrypted local database.',
			'settingsPage.deleteAccountAndData' => 'Delete account and data',
			'settingsPage.deleteAccountAndDataDetail' => 'Irreversible operation protected by confirmation.',
			'settingsPage.exportPrivateShareText' => 'My private data exported from Evolve',
			'settingsPage.exportShareText' => 'My data exported from Evolve',
			'settingsPage.exportDoneTitle' => 'Export complete',
			'settingsPage.exportDoneClipboard' => 'The JSON is on the clipboard: Linux does not support file sharing.',
			'settingsPage.exportDoneShare' => 'The JSON was sent to the share selector.',
			'settingsPage.avatarGateTitle' => 'Avatar',
			'settingsPage.avatarPickFailed' => 'Image selection failed.',
			'settingsPage.confirmSignOutTitle' => 'Confirm sign out',
			'settingsPage.confirmSignOutMessage' => 'Are you sure you want to sign out? You will need to re-enter your credentials to sign in again.',
			'settingsPage.gateProfile' => 'Profile',
			'settingsPage.gateLogout' => 'Logout',
			'settingsPage.gateChangePassword' => 'Change password',
			'settingsPage.gateRequiresActiveSession' => 'Requires an active Supabase session.',
			'settingsPage.biometricActivationCancelled' => 'Activation cancelled.',
			'settingsPage.notificationPermissionsTitle' => 'Notification permissions',
			'settingsPage.notificationPermissionsGranted' => 'Permissions available for this system.',
			'settingsPage.notificationPermissionsDenied' => 'Permission not granted. You can change it from the system settings.',
			'settingsPage.systemPermissionsTitle' => 'System permissions',
			'settingsPage.systemPermissionsOpenFailed' => 'Unable to open the settings.',
			'settingsPage.tutorialResetTitle' => 'Tutorials reset',
			'settingsPage.tutorialResetMessage' => 'The guides will be shown again in the relevant sections.',
			'settingsPage.accountDataManagementTitle' => 'Account and data management',
			'settingsPage.accountDataManagementContent' => 'Choose whether to delete the data while keeping the account active or to permanently delete the account.',
			'settingsPage.resetDataAction' => 'Reset data',
			'settingsPage.deleteAccountAction' => 'Delete account',
			'settingsPage.confirmResetDataTitle' => 'Confirm data reset',
			'settingsPage.confirmResetDataMessage' => 'Habits, goals and preferences will be deleted. The account will remain active. This action cannot be undone.',
			'settingsPage.confirmDeleteAccountTitle' => 'Confirm account deletion',
			'settingsPage.confirmDeleteAccountMessage' => 'The account and all associated data will be permanently deleted. This action is irreversible.',
			'settingsPage.resetDataTitle' => 'Reset data',
			'settingsPage.resetDataSuccess' => 'Data deleted successfully.',
			'settingsPage.operationFailed' => 'Operation failed.',
			'settingsPage.settingSaveFailed' => 'Could not save that setting. It has been restored to its previous value.',
			'settingsPage.deleteAccountGateTitle' => 'Delete account',
			'settingsPage.accountDeleted' => 'Account deleted.',
			'settingsPage.importDataGateTitle' => 'Import data',
			'settingsPage.importPrivateOnly' => 'The import feature is currently available only in Private Mode (Local).',
			'settingsPage.importSummaryTitle' => 'Import summary',
			'settingsPage.importHabitsCount' => ({required Object count}) => '${count} Habits',
			'settingsPage.importLogsCount' => ({required Object count}) => '${count} Check-ins (Log)',
			'settingsPage.importMacroGoalsCount' => ({required Object count}) => '${count} Macro Goals',
			'settingsPage.importCategoriesCount' => ({required Object count}) => '${count} Categories',
			'settingsPage.importMoodsCount' => ({required Object count}) => '${count} Mood Records',
			'settingsPage.importReplaceTitle' => 'Replace current data',
			'settingsPage.importReplaceSubtitle' => 'Permanently deletes every existing record that isn\'t in this backup.',
			'settingsPage.importMergeTitle' => 'Merge with current data',
			'settingsPage.importMergeSubtitle' => 'Combines with your data, keeping the newest version of each item.',
			'settingsPage.importReplaceConfirmTitle' => 'Replace all data?',
			'settingsPage.importReplaceConfirmMessage' => ({required Object count}) => 'This permanently deletes your current data (about ${count} habit logs) and keeps only what\'s in this backup. This can\'t be undone.',
			'settingsPage.importReplaceConfirmButton' => 'Delete & Replace',
			'settingsPage.importConfirmButton' => 'Confirm import',
			'settingsPage.importSuccess' => 'Import completed successfully!',
			'settingsPage.importError' => ({required Object error}) => 'Error during import: ${error}',
			'settingsPage.importLockedTitle' => 'Reset locked private database?',
			'settingsPage.importLockedMessage' => 'This device can\'t unlock your local private database — its encryption key is missing (this happens after moving to a new Mac or a change to the app\'s signing). The existing local data can\'t be recovered, but you can reset it and import this backup onto a fresh, empty database. This can\'t be undone.',
			'settingsPage.importLockedResetButton' => 'Reset & import',
			'settingsPage.importPreviewSkipped' => ({required Object count}) => '⚠ ${count} invalid record(s) will be skipped',
			'settingsPage.importCompletedTitle' => 'Import Completed',
			'settingsPage.importSummaryReplaced' => 'Your data was replaced with the backup. Summary:',
			'settingsPage.importSummaryMerged' => 'Your data was merged with the backup. Summary:',
			'settingsPage.importSummaryDone' => 'Awesome!',
			'settingsPage.importEntityHabits' => 'Habits',
			'settingsPage.importEntityLogs' => 'Habit Logs',
			'settingsPage.importEntityMacroGoals' => 'Macro Goals',
			'settingsPage.importEntityCategories' => 'Categories',
			'settingsPage.importEntityMoods' => 'Mood Logs',
			'settingsPage.importRowReplace' => ({required Object count, required Object label}) => '${count} ${label}',
			'settingsPage.importRowMerge' => ({required Object label, required Object added, required Object updated, required Object unchanged}) => '${label}: ${added} added, ${updated} updated, ${unchanged} unchanged',
			'settingsPage.importRowSkipped' => ({required Object count}) => ', ${count} skipped',
			'settingsPage.exportDoneSaved' => 'The JSON file was saved to the selected location.',
			'settingsPage.proTitle' => 'Evolve Pro',
			'settingsPage.proSubtitle' => 'Plan, purchase restore and subscription management',
			'settingsPage.billingAppleTitle' => 'Billed through Apple',
			'settingsPage.commercialChannelRequired' => 'Purchases unavailable',
			'settingsPage.billingAppleDetail' => 'Your subscription is purchased and managed with your Apple account.',
			'settingsPage.billingUnavailableDetail' => 'Subscriptions are temporarily unavailable. Please try again later.',
			'settingsPage.billingPlatformUnsupported' => 'In-app purchases aren\'t available on this platform.',
			'settingsPage.bestValue' => 'Best value',
			'settingsPage.priceUnavailable' => 'Price unavailable',
			'settingsPage.renewalDisclaimer' => 'The subscription renews automatically unless auto-renew is turned off in Apple account settings at least 24 hours before the end of the period.',
			'settingsPage.privacyPolicy' => 'Privacy Policy',
			'settingsPage.termsEula' => 'Terms of Use (EULA)',
			'settingsPage.planManagement' => 'Plan management',
			'settingsPage.activateEvolvePro' => 'Activate Evolve Pro',
			'settingsPage.activateEvolveProActive' => 'Evolve Pro entitlement active.',
			'settingsPage.activateEvolveProStart' => 'Subscribe with your Apple account.',
			'settingsPage.restorePurchasesDetail' => 'Restores a subscription you already bought.',
			'settingsPage.manageSubscription' => 'Manage subscription',
			'settingsPage.manageSubscriptionDetail' => 'Opens the subscription management of the Apple account.',
			'settingsPage.notAuthenticated' => 'Not authenticated',
			'settingsPage.verified' => 'Verified',
			'settingsPage.privateModeDataProtected' => 'Your data is protected and saved only on this device.',
			'settingsPage.profileFallback' => 'Profile',
			'settingsPage.fullName' => 'Full name',
			'settingsPage.dateOfBirth' => 'Date of birth',
			'settingsPage.dateOfBirthHint' => 'YYYY-MM-DD',
			'settingsPage.currentPassword' => 'Current password',
			'settingsPage.newPassword' => 'New password',
			'settingsPage.confirmNewPassword' => 'Confirm new password',
			'settingsPage.updatePassword' => 'Update password',
			'settingsPage.enterCurrentPassword' => 'Enter your current password.',
			'settingsPage.newPasswordMinLength' => 'The new password must be at least 8 characters long.',
			'settingsPage.passwordUpdateFailed' => 'Update failed. Check your current password.',
			'settingsPage.sectionApplication' => 'Application',
			'settingsPage.sectionPrivacy' => 'Privacy',
			'settingsPage.customColor' => 'Custom color',
			'settingsPage.applyAction' => 'Apply',
			'settingsPage.useAccent' => ({required Object hex}) => 'Use accent ${hex}',
			'settingsPage.proUpsellTitle' => 'Upgrade to Evolve Pro',
			'settingsPage.proUpsellSubtitle' => 'Unlock all features and accelerate your growth.',
			'settingsPage.proWelcomeTitle' => 'Welcome to Evolve Pro!',
			'settingsPage.proActiveMessage' => 'Your subscription is active. The AI Coach is included — no OpenRouter account or API key needed — along with advanced trend statistics and all Evolve\'s personal growth tools.',
			'settingsPage.proStartJourney' => 'Start your Journey',
			'settingsPage.systemSection' => 'System',
			'settingsPage.appLogsTitle' => 'App Logs',
			'settingsPage.appLogsDetail' => 'View diagnostic logs from this session',
			'consent.onboardingTitle' => 'Your Privacy Matters',
			'consent.continueButton' => 'Continue',
			'notifications.actionDone' => 'Done',
			'notifications.actionSkip' => 'Skip',
			'notifications.actionSnooze' => 'Snooze',
			'notifications.morningBrief' => 'Morning Brief',
			'notifications.eveningReview' => 'Evening Review',
			'notifications.morningBriefBody' => 'Time to shape your day. Check your goals.',
			'notifications.eveningReviewBody' => 'How did today go? Track your progress and update the Logbook.',
			'privacy.biometricAuthReason' => 'Authenticate to enable app protection.',
			'privacy.biometricUnlockReason' => 'Unlock the app to continue.',
			'consentPage.subtitle' => 'Before using Evolve Desktop, confirm the terms, privacy policy and the data processing required for syncing.',
			'consentPage.acceptTerms' => 'I accept the terms and privacy policy',
			'consentPage.termsSubtitle' => 'I confirm I have read the documents and I am at least 14 years old.',
			'consentPage.crashDiagnostics' => 'Crash diagnostics',
			'consentPage.crashSubtitle' => 'Allow sending anonymized technical reports.',
			'consentPage.openPrivacy' => 'Open the privacy policy',
			'consentPage.openTerms' => 'Terms of Service',
			'consentPage.notificationsTitle' => 'Enable notifications',
			'consentPage.notificationsSubtitle' => 'Get habit reminders and daily briefs.',
			'consentPage.enableNotifications' => 'Enable',
			'consentPage.notificationsEnabled' => 'Enabled',
			'notif.macScheduling' => 'Daily scheduling active on macOS.',
			'notif.linuxImmediate' => 'Linux shows immediate notifications but doesn\'t support scheduling.',
			'notif.openEvolve' => 'Open Evolve',
			'notif.windowsScheduling' => 'Windows schedules the next occurrence at each launch.',
			'notif.morningBody' => 'Review today\'s habits and choose where to start.',
			'notif.habitReminderBody' => 'It\'s time to complete your habit.',
			'notif.eveningBody' => 'Wrap up the day and update your progress.',
			'biometricGate.appLocked' => 'App locked',
			'biometricGate.unlockPrompt' => 'Unlock with local authentication to continue.',
			'biometricGate.verifying' => 'Verifying...',
			'biometricGate.unlock' => 'Unlock',
			'biometricGate.notSupportedLinux' => 'Biometric lock is not supported on Linux.',
			'biometricGate.noLocalAuth' => 'No local authentication method available.',
			'biometricGate.authFailed' => 'Authentication failed.',
			'biometricGate.authUnavailable' => 'Local authentication unavailable.',
			'sync.syncFailed' => 'Sync failed. Local data kept.',
			'sync.editSavedLocally' => 'Change saved locally. Sync to be retried.',
			'subscriptionCtrl.purchaseComplete' => 'Purchase complete: syncing entitlement.',
			'subscriptionCtrl.purchaseIncomplete' => 'Purchase not completed.',
			'subscriptionCtrl.cantOpenApple' => 'Unable to open Apple subscription management.',
			'subscriptionCtrl.macOnly' => 'In-app purchases are available in the macOS client.',
			'subscriptionCtrl.loadOffersFailed' => 'Unable to load RevenueCat offerings.',
			'subscriptionCtrl.proActivated' => 'Evolve Pro activated.',
			'subscriptionCtrl.purchasesRestored' => 'Purchases restored.',
			'subscriptionCtrl.noActiveSub' => 'No active Pro subscription found.',
			'subscriptionCtrl.restoreFailed' => 'Failed to restore purchases.',
			'subscriptionCtrl.configKey' => 'Configure the desktop client\'s RevenueCat public key.',
			'subscriptionCtrl.loginFirst' => 'Sign in before managing Evolve Pro.',
			'authCtrl.appleNoToken' => 'Apple did not return an identity token.',
			'authCtrl.appleAuthFailed' => 'Apple authentication failed.',
			'authCtrl.cantOpenBrowser' => 'Unable to open the system browser.',
			'authCtrl.accessNotCompleted' => ({required Object provider}) => '${provider} sign-in not completed.',
			'authCtrl.providerAuthFailed' => ({required Object provider}) => '${provider} authentication failed.',
			'authCtrl.operationFailed' => 'Operation failed. Try again shortly.',
			'proModal.title' => 'Unlock Evolve Pro',
			'proModal.subtitle' => 'Take your habit system to the next level',
			'proModal.featuresHeader' => 'WHAT THE PRO PLAN INCLUDES',
			'proModal.aiCoachTitle' => 'AI Coach, with no setup',
			'proModal.aiCoachDesc' => 'We run it on our key — no API key to fetch, no second account. Prefer your own OpenRouter account? That\'s free too.',
			'proModal.statsTitle' => 'Habit-Specific Statistics',
			'proModal.statsDesc' => 'Key insights to boost your productivity.',
			'proModal.metricsTitle' => 'Advanced Goal Metrics',
			'proModal.metricsDesc' => 'View detailed charts and deep performance stats for each year.',
			'proModal.unlimitedTitle' => 'Unlimited Habits',
			'proModal.unlimitedDesc' => 'Create and track all the habits you want without any limits.',
			'proModal.maybeLater' => 'Maybe later',
			'proModal.viewPlans' => 'View Pro plans',
			'appLogs.title' => 'App Logs',
			'appLogs.copiedToClipboard' => 'Logs copied to clipboard',
			'appLogs.clearLogsTitle' => 'Clear Logs',
			'appLogs.clearLogsConfirm' => 'Are you sure you want to clear all log entries? This action cannot be undone.',
			'appLogs.clearLogsAction' => 'Clear All',
			'appLogs.copyAll' => 'Copy All Logs',
			'appLogs.searchPlaceholder' => 'Search logs...',
			'appLogs.filterAll' => 'All',
			'appLogs.filterErrors' => 'Errors',
			'appLogs.filterWarnings' => 'Warnings',
			'appLogs.filterInfo' => 'Info',
			'appLogs.emptyTitle' => 'No Logs Yet',
			'appLogs.emptySubtitle' => 'Logs will appear here as the app runs',
			'appLogs.stackTraceAvailable' => 'Tap to view stack trace',
			'appLogs.detailMessage' => 'MESSAGE',
			'appLogs.detailError' => 'ERROR',
			'appLogs.detailExtras' => 'Additional context',
			'appLogs.detailStackTrace' => 'STACK TRACE',
			'appLogs.shareLogs' => 'Share logs file',
			'appLogs.exportDone' => 'Logs exported',
			'coachSettings.title' => 'AI Coach engine',
			'coachSettings.subtitle' => 'Choose where the coach runs. Local models keep every message on this device.',
			'coachSettings.backendCloud' => 'Your OpenRouter',
			'coachSettings.backendLocal' => 'Local · private',
			'coachSettings.cloudDesc' => 'Connect your own OpenRouter account and pay the provider directly. Free — no subscription needed. The context you share is sent to the provider.',
			'coachSettings.localDesc' => 'Your own model via Ollama, LM Studio or any OpenAI-compatible server. Nothing leaves this device.',
			'coachSettings.presetLabel' => 'Server',
			'coachSettings.presetOllama' => 'Ollama',
			'coachSettings.presetLmStudio' => 'LM Studio',
			_ => null,
		} ?? switch (path) {
			'coachSettings.presetCustom' => 'Custom…',
			'coachSettings.baseUrlLabel' => 'Base URL',
			'coachSettings.baseUrlHint' => 'http://localhost:11434/v1',
			'coachSettings.modelLabel' => 'Model',
			'coachSettings.modelHint' => 'e.g. llama3.1:8b',
			'coachSettings.refreshModels' => 'Refresh models',
			'coachSettings.discovering' => 'Looking for models…',
			'coachSettings.noModelsFound' => 'No models found — type a model id manually below.',
			'coachSettings.manualModelLabel' => 'Model id',
			'coachSettings.manualModelAdd' => 'Use this model',
			'coachSettings.statusConnected' => 'Connected',
			'coachSettings.statusOffline' => 'Server offline',
			'coachSettings.statusChecking' => 'Checking…',
			'coachSettings.remoteBadge' => 'Remote',
			'coachSettings.remoteWarning' => 'This endpoint isn\'t a local address — messages will leave this device.',
			'coachSettings.advanced' => 'Advanced',
			'coachSettings.systemPromptLabel' => 'System prompt',
			'coachSettings.systemPromptHint' => 'Override the coach persona (leave empty for the default)',
			'coachSettings.systemPromptReset' => 'Reset',
			'coachSettings.temperatureLabel' => 'Temperature',
			'coachSettings.save' => 'Done',
			'coachSettings.detectedTitle' => 'Local model detected',
			'coachSettings.detectedBody' => 'A local AI server is running on this Mac. Run the coach 100% privately?',
			'coachSettings.detectedAction' => 'Use local',
			'coachSettings.detectedDismiss' => 'Not now',
			'coachSettings.activeCloud' => ({required Object model}) => 'Cloud · ${model}',
			'coachSettings.activeLocal' => ({required Object model}) => 'Local · ${model}',
			'coachSettings.activeLocalNoModel' => 'Local · pick a model',
			'coachSettings.cloudSection' => 'Your OpenRouter',
			'coachSettings.serverSettings' => 'Server settings…',
			'coachSettings.settingsSectionLabel' => 'AI Coach',
			'coachSettings.settingsTitle' => 'AI Coach',
			'coachSettings.settingsSubtitle' => 'Pick the engine that powers your coach and point it at a local server for full privacy.',
			'coachSettings.settingsRowStatus' => 'Active engine',
			'coachSettings.settingsRowConfigure' => 'Engine & local server',
			'coachSettings.cloudKeyMissing' => 'No key yet — this engine won\'t reply. Connect your OpenRouter account below, switch to Evolve AI, or use a local server.',
			'coachSettings.temperatureLower' => 'Lower temperature',
			'coachSettings.temperatureRaise' => 'Raise temperature',
			'coachSettings.sendMessage' => 'Send',
			'coachSettings.stopResponse' => 'Stop',
			'coachSettings.startOllama' => 'Start Ollama',
			'coachSettings.getOllama' => 'Get Ollama',
			'coachSettings.startingOllama' => 'Starting Ollama…',
			'coachSettings.ollamaOfflineTitle' => 'Ollama isn\'t running',
			'coachSettings.ollamaOfflineBody' => 'Start your local server to chat privately — no terminal needed.',
			'coachSettings.ollamaNotInstalledTitle' => 'Ollama isn\'t installed',
			'coachSettings.ollamaNotInstalledBody' => 'Install the free Ollama app, then press Start.',
			'coachSettings.ollamaStartTimeout' => 'Taking longer than expected — check the Ollama icon in your menu bar (a first launch may need approval).',
			'coachSettings.ollamaStartingBody' => 'This can take a few seconds…',
			'coachSettings.ollamaStartFailed' => 'Couldn\'t start Ollama — try opening it from your Applications folder.',
			'coachSettings.ollamaDownloadFailed' => 'Couldn\'t open the browser — visit ollama.com/download',
			'coachSettings.backendStandard' => 'Evolve AI',
			'coachSettings.standardDesc' => 'Included with Evolve Pro. We run a free Google model (Gemma) for you — no keys, no setup. Your messages go to Google\'s free tier, which may use them to improve their services.',
			'coachSettings.activeStandard' => ({required Object model}) => 'Evolve AI · ${model}',
			'coachSettings.standardSection' => 'Evolve AI',
			'coachSettings.standardStatusReady' => 'Included with Pro',
			'coachSettings.standardStatusNeedsPro' => 'Requires Pro',
			'coachSettings.standardStatusNeedsSignIn' => 'Sign in required',
			'coachSettings.standardStatusUnavailable' => 'Unavailable',
			'coachSettings.standardNeedsProNote' => 'Evolve AI is part of Evolve Pro. Subscribe to use it — or connect your own OpenRouter account instead, which is free.',
			'coachSettings.standardNeedsSignInNote' => 'Sign in to use Evolve AI. Your subscription unlocks it on every device.',
			'coachSettings.standardUnavailableNote' => 'Evolve AI isn\'t available in this build. Connect your own OpenRouter account, or run a local model.',
			'coachSettings.standardPrivateNote' => 'Evolve AI needs an Evolve account, and Private mode doesn\'t keep one. Connect your own OpenRouter account, or run a local model — both keep working here.',
			'tour.back' => 'Back',
			'tour.next' => 'Next',
			'tour.continueLabel' => 'Continue',
			'tour.finish' => 'Finish',
			'tour.welcomeTitle' => 'Welcome to Evolve',
			'tour.welcomeBody' => 'Let\'s take a quick tour of your workspace — from your daily overview all the way to your AI coach. It only takes a minute.',
			'tour.welcomeStart' => 'Start tour',
			'tour.welcomeSkip' => 'Skip tutorial',
			'tour.doneTitle' => 'You\'re all set',
			'tour.doneBody' => 'That\'s the whole app. Jump in anywhere from the sidebar — and you can replay this tour any time from Settings.',
			'tour.doneButton' => 'Get started',
			'tour.overviewOrientationTitle' => 'Your Overview',
			'tour.overviewOrientationDesc' => 'This is your daily home base — a snapshot of today the moment you open Evolve.',
			'tour.overviewCheckinTitle' => 'Daily check-in',
			'tour.overviewCheckinDesc' => 'Log how your day is going. Over time it reveals how your mood tracks with your habits and goals.',
			'tour.overviewHabitsTitle' => 'Today\'s habits',
			'tour.overviewHabitsDesc' => 'The habits you\'ve planned for today live here — tick them off as you go.',
			'tour.overviewGoalsTitle' => 'Focus goals',
			'tour.overviewGoalsDesc' => 'The goals you\'re focused on surface here so nothing slips.',
			'tour.habitsOrientationTitle' => 'The Habits page',
			'tour.habitsOrientationDesc' => 'This is where you build your daily protocol and track how consistent you are.',
			'tour.habitsAddTitle' => 'Add a habit',
			'tour.habitsAddDesc' => 'Create a new habit here — give it a name, a category, a colour and an optional reminder.',
			'tour.habitsCheckoffTitle' => 'Mark it done',
			'tour.habitsCheckoffDesc' => 'Tick this box to complete a habit for today. That\'s all it takes to keep a streak alive.',
			'tour.habitsStreakTitle' => 'Streaks & history',
			'tour.habitsStreakDesc' => 'Watch your streak grow, and see your last seven days at a glance.',
			'tour.habitsCalendarTitle' => 'Calendar view',
			'tour.habitsCalendarDesc' => 'Switch to the Calendar to review your history by week, month, year — or your whole life.',
			'tour.insightsOrientationTitle' => 'Your Insights',
			'tour.insightsOrientationDesc' => 'See how your habits and goals trend over time, and where you\'re drifting.',
			'tour.insightsFilterTitle' => 'Filter by habit',
			'tour.insightsFilterDesc' => 'Focus the statistics on a single habit, or keep the global overview.',
			'tour.insightsTabsTitle' => 'Statistics sections',
			'tour.insightsTabsDesc' => 'Switch between the sections for trends, alerts, habit progress and your mood.',
			'tour.goalsOrientationTitle' => 'The Goals page',
			'tour.goalsOrientationDesc' => 'Set and track your bigger objectives — the things your daily habits build toward.',
			'tour.goalsPlanTitle' => 'Planning type',
			'tour.goalsPlanDesc' => 'Choose how you plan — daily, weekly or longer — to match how you think about your goals.',
			'tour.goalsAddTitle' => 'Add a goal',
			'tour.goalsAddDesc' => 'Create a new goal here and give it a target to work toward.',
			'tour.goalsCheckTitle' => 'Complete or miss',
			'tour.goalsCheckDesc' => 'Mark a goal done or missed. Every outcome feeds your performance over time.',
			'tour.goalsStatsTitle' => 'Performance',
			'tour.goalsStatsDesc' => 'Toggle performance stats to see how you\'re doing against your goals.',
			'tour.coachOrientationTitle' => 'Your AI Coach',
			'tour.coachOrientationDesc' => 'Personalised guidance grounded in your real habits and goals — right here on your Mac.',
			'tour.coachModelTitle' => 'Choose your engine',
			'tour.coachModelDesc' => 'Pick the AI model — our cloud, or a local model running privately on your Mac. Server settings live here too.',
			'tour.coachContextTitle' => 'What the coach sees',
			'tour.coachContextDesc' => 'Control whether the coach can use your habits and goals to tailor its advice.',
			'tour.coachSuggestionsTitle' => 'Starter prompts',
			'tour.coachSuggestionsDesc' => 'Not sure where to begin? Tap one of these suggestions to get going.',
			'tour.coachInputTitle' => 'Ask anything',
			'tour.coachInputDesc' => 'Type your question here and press send. That\'s the end of the tour — enjoy Evolve!',
			'palette.searchHint' => 'Search goals, habits, actions…',
			'palette.groupSuggested' => 'Suggested',
			'palette.groupThisWeek' => 'This week',
			'palette.groupGoals' => 'Goals',
			'palette.groupHabits' => 'Habits',
			'palette.groupActions' => 'Actions',
			'palette.groupSections' => 'Go to',
			'palette.goToThisWeek' => 'Go to this week',
			'palette.createGoalBlank' => 'Create goal',
			'palette.createGoal' => ({required Object title}) => 'Create goal “${title}”',
			'palette.createHabit' => ({required Object title}) => 'Create habit “${title}”',
			'palette.goToPeriod' => ({required Object period}) => 'Go to ${period}',
			'palette.switchToDark' => 'Switch to dark theme',
			'palette.switchToLight' => 'Switch to light theme',
			'palette.manageCategories' => 'Manage goal categories',
			'palette.replayTour' => 'Replay guided tour',
			'palette.noResults' => ({required Object query}) => 'No results for “${query}”',
			'palette.rowOpen' => 'Open',
			'palette.rowComplete' => 'Mark complete',
			'palette.rowReschedule' => 'Reschedule to next period',
			'palette.deleteGoalTitle' => 'Delete goal?',
			'palette.deleteGoalMessage' => ({required Object title}) => '“${title}” will be permanently deleted.',
			'palette.deleteHabitTitle' => 'Delete habit?',
			'palette.deleteHabitMessage' => ({required Object title}) => '“${title}” will be permanently deleted.',
			'palette.footerNavigate' => 'navigate',
			'palette.footerOpen' => 'open',
			'palette.footerMenu' => 'menu',
			'palette.footerClose' => 'close',
			_ => null,
		};
	}
}
