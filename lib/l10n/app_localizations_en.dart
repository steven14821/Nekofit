// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'NekoFit';

  @override
  String get tagline => 'Your personal konbini';

  @override
  String get retry => 'Retry';

  @override
  String get authGateErrorTitle => 'We couldn\'t load your profile';

  @override
  String get authGateErrorBody => 'Check your connection and try again.';

  @override
  String get navHome => 'Home';

  @override
  String get navPantry => 'Pantry';

  @override
  String get navDiary => 'Diary';

  @override
  String get navPet => 'Pet';

  @override
  String get navProfile => 'Profile';

  @override
  String get loginWelcome => 'Welcome back!';

  @override
  String get loginWelcomeSub => 'Your streak and Mochi are waiting.';

  @override
  String get loginEmailLabel => 'EMAIL';

  @override
  String get loginPasswordLabel => 'PASSWORD';

  @override
  String get loginForgotPassword => 'Forgot your password?';

  @override
  String get loginSignIn => 'SIGN IN';

  @override
  String get loginOrContinueWith => 'OR CONTINUE WITH';

  @override
  String get loginContinueGoogle => 'Continue with Google';

  @override
  String get loginEmailErrorEmpty => 'Please enter your email';

  @override
  String get loginEmailErrorInvalid => 'Please enter a valid email';

  @override
  String get loginPasswordErrorEmpty => 'Please enter your password';

  @override
  String get loginNoAccount => 'Don\'t have an account? ';

  @override
  String get loginRegister => 'Sign up here';

  @override
  String get loginGoogleFailed =>
      'Couldn\'t sign in with Google. Check your connection and try again.';

  @override
  String get forgotTitle => 'Recover Password';

  @override
  String get forgotBody =>
      'Enter your registered email and we\'ll send you a link to reset your password.';

  @override
  String get emailLabel => 'Email';

  @override
  String get emailEmpty => 'Enter your email';

  @override
  String get emailInvalid => 'Enter a valid email';

  @override
  String get cancel => 'Cancel';

  @override
  String get send => 'Send';

  @override
  String get resetEmailSent => 'Recovery link sent successfully.';

  @override
  String errorPrefix(String error) {
    return 'Error: $error';
  }

  @override
  String get onboardingSkip => 'SKIP';

  @override
  String get onboardingTitle => 'What will you gain?';

  @override
  String get onboardingSubtitle => '3 things NekoFit does for you';

  @override
  String get onboardingSlide1Title => 'Log your pantry\nin 10 seconds';

  @override
  String get onboardingSlide1Subtitle =>
      'Scan or write in your products and NekoFit tracks the inventory for you. You\'ll know what\'s running low before it runs out.';

  @override
  String get onboardingSlide2Title =>
      'AI identifies what\nyou eat from a photo';

  @override
  String get onboardingSlide2Subtitle =>
      'Snap a picture of your plate and AI calculates calories, protein, carbs and fat instantly. No scales or tables needed.';

  @override
  String get onboardingSlide3Title => 'Your pet keeps\nyou consistent';

  @override
  String get onboardingSlide3Subtitle =>
      'Every logged meal feeds your pet. Level up, unlock outfits and keep your streak: theirs depends on yours.';

  @override
  String get start => 'START';

  @override
  String get next => 'NEXT';

  @override
  String get stepEssential => 'Essentials';

  @override
  String get stepPersonalize => 'Customize';

  @override
  String get stepExtreme => 'Extreme';

  @override
  String get essentialsTitle => 'Start in 30 seconds';

  @override
  String get essentialsBody =>
      'Your gender, age, height and weight are enough to estimate your calorie goal instantly. You can fine-tune the rest later.';

  @override
  String get genderFemale => 'Female';

  @override
  String get genderMale => 'Male';

  @override
  String get ageField => 'Age (years)';

  @override
  String get heightField => 'Height (cm)';

  @override
  String get weightField => 'Current weight (kg)';

  @override
  String get goalQuestion => 'What\'s your goal?';

  @override
  String get customGoalLabel => 'Describe your specific goal';

  @override
  String get customGoalHint => 'e.g. Build endurance for a 10km marathon';

  @override
  String get goalLoseWeight => 'Lose weight';

  @override
  String get goalLoseWeightDesc =>
      'Moderate calorie deficit, prioritizing protein to preserve muscle.';

  @override
  String get goalMaintainWeight => 'Maintain weight';

  @override
  String get goalMaintainWeightDesc =>
      'Energy balance to sustain weight and body recomposition.';

  @override
  String get goalGainMuscle => 'Gain muscle';

  @override
  String get goalGainMuscleDesc =>
      'Controlled surplus + high protein for hypertrophy.';

  @override
  String get goalCustom => 'Other/Custom';

  @override
  String get goalCustomDesc =>
      'If you\'re chasing specific athletic or clinical goals.';

  @override
  String get recommendedDailyCalories => 'Recommended daily calories';

  @override
  String bmrFormula(String formula) {
    return 'BMR formula: $formula';
  }

  @override
  String get bmrFormulaKatch => 'Katch-McArdle';

  @override
  String get bmrFormulaMifflin => 'Mifflin-St Jeor';

  @override
  String get macroCarbs => 'Carbs';

  @override
  String get macroProteins => 'Protein';

  @override
  String get macroFats => 'Fats';

  @override
  String get personalizeTitle => 'Customize your plan';

  @override
  String get personalizeBody =>
      'Optional: refine your estimate with body fat, daily activity and your pet.';

  @override
  String get bodyFatSection => 'Body fat %';

  @override
  String get bodyFatSectionHint =>
      'Enables the Katch-McArdle formula, much more accurate than standard ones.';

  @override
  String get lifestyleSection => 'Daily lifestyle';

  @override
  String get lifestyleSectionHint =>
      'What do you do most of the day, not counting training?';

  @override
  String get trainingSection => 'Training burn';

  @override
  String get trainingSectionHint =>
      'We add fixed kcal based on activity type and minutes per week.';

  @override
  String get petSection => 'Meet your pet';

  @override
  String get petSectionHint =>
      'Give a name to your virtual nutrition and cooking buddy.';

  @override
  String get methodVisualTitle => 'Visual method';

  @override
  String get methodVisualDesc =>
      'Pick your range using pictures and descriptions.';

  @override
  String get methodNavyTitle => 'US Navy method';

  @override
  String get methodNavyDesc =>
      'Real calculation with measuring tape (neck, waist, hips).';

  @override
  String get myBodyFatEstimated => 'Your estimated body fat';

  @override
  String get navyHintMale => 'Your waist must be bigger than your neck.';

  @override
  String get navyHintFemale => 'Complete neck, waist, hips and height.';

  @override
  String get navyCalculated => 'Calculated with the US Navy formula';

  @override
  String get neckField => 'Neck (cm)';

  @override
  String get waistField => 'Waist (cm)';

  @override
  String get hipField => 'Hips (cm)';

  @override
  String get calculate => 'Calculate';

  @override
  String get lifestyleSedentary => 'Sedentary';

  @override
  String get lifestyleSedentaryDesc =>
      'Sitting most of the day (study, office, programming).';

  @override
  String get lifestyleActive => 'Active';

  @override
  String get lifestyleActiveDesc =>
      'Standing work, walk a lot or move constantly.';

  @override
  String get trainingActivityLabel => 'Main activity type';

  @override
  String get weeklyMinutes => 'Minutes per week';

  @override
  String minPerWeek(int minutes) {
    return '$minutes min/wk';
  }

  @override
  String minShort(int minutes) {
    return '$minutes min';
  }

  @override
  String get trainingKcalPerDay => 'training kcal / day';

  @override
  String get chooseYourPet => 'Choose your pet';

  @override
  String get petCat => 'Cat';

  @override
  String get petDog1 => 'Dog 1';

  @override
  String get petDog2 => 'Dog 2';

  @override
  String get petNameLabel => 'Your pet\'s name';

  @override
  String get petNameHint => 'e.g. Mochi';

  @override
  String get customizeButton => 'Customize';

  @override
  String get stepExtremeContinue => 'Continue';

  @override
  String get stepExtremeSkip => 'Skip';

  @override
  String get extremeTitle => 'Extreme personalization';

  @override
  String get extremeBody =>
      'Give your plan a real timeline, pace and context: for how many weeks, whether you fast, and which foods and conditions to respect. Our AI cat uses it every week.';

  @override
  String get extremeEnableLabel => 'Create a timed plan';

  @override
  String get extremeEnableDesc =>
      'Turn it on to generate a 4, 8 or 12-week plan that evolves with you.';

  @override
  String get extremePhaseLabel => 'Plan phase';

  @override
  String get extremePhaseCut => 'Lose weight';

  @override
  String get extremePhaseMaintain => 'Maintain weight';

  @override
  String get extremePhaseGain => 'Gain muscle';

  @override
  String get extremePhaseRecomp => 'Recomposition';

  @override
  String get extremeDurationLabel => 'Duration';

  @override
  String get extremeW4 => '4 weeks';

  @override
  String get extremeW8 => '8 weeks';

  @override
  String get extremeW12 => '12 weeks';

  @override
  String get extremeMealsLabel => 'Meals per day';

  @override
  String get extremeMealsHint =>
      'Only shapes the weekly AI plan, not your macros.';

  @override
  String get extremeMeals3 => '3 meals';

  @override
  String get extremeMeals4 => '4 meals';

  @override
  String get extremeMeals5 => '5 meals';

  @override
  String get extremeIfLabel => 'Intermittent fasting';

  @override
  String get extremeIfDesc =>
      'The first meal of the day stays out of the plan.';

  @override
  String get extremeIf16 => '16:8';

  @override
  String get extremeIf18 => '18:6';

  @override
  String get extremeContextLabel => 'Your context (optional)';

  @override
  String get extremeContextHint =>
      'This context goes into every weekly AI plan. Write items separated by commas.';

  @override
  String get extremeMedicalLabel => 'Medical conditions';

  @override
  String get extremeMedicalHint =>
      'E.g. insulin resistance, hypertension, hypothyroidism…';

  @override
  String get extremeDietLabel => 'Preferences / restrictions';

  @override
  String get extremeDietHint => 'E.g. vegan, keto, gluten-free, lactose-free…';

  @override
  String get extremeMustHaveLabel => 'Must haves';

  @override
  String get extremeMustHaveHint =>
      'Foods you love and don\'t want to drop (included almost daily).';

  @override
  String get extremeAversionsLabel => 'Aversions';

  @override
  String get extremeAversionsHint => 'Foods to avoid completely in the plan.';

  @override
  String get extremeNotice =>
      'Your phase resets calories: shorter plans use a more aggressive deficit, longer ones are gentler. When the plan ends, NekoFit suggests the next phase before touching anything.';

  @override
  String get planExpiredTitle => 'Your plan ended';

  @override
  String get planExpiredSubtitle => 'Your nutrition plan has come to an end.';

  @override
  String planExpiredBody(int weeks, String phase) {
    return 'Your $weeks-week plan has ended. The suggested next phase is: $phase. Shall we apply it? We\'ll recalculate your macros.';
  }

  @override
  String get planApprove => 'Apply';

  @override
  String get planSkip => 'Not now';

  @override
  String get planTransited =>
      'Phase applied! New macros calculated and a new plan is active.';

  @override
  String planTransitError(String error) {
    return 'Could not apply the phase: $error';
  }

  @override
  String get saveAndStart => 'Save and start';

  @override
  String get back => 'Back';

  @override
  String get snackEssentials =>
      'Complete age, height and weight to estimate your goal instantly.';

  @override
  String get snackCustomGoal => 'Please describe your custom fitness goal.';

  @override
  String get snackMeasures =>
      'Complete the measurements to estimate your body fat %.';

  @override
  String saveProfileError(String error) {
    return 'Couldn\'t save profile: $error';
  }

  @override
  String get registerJoinTitle => 'Join NekoFit';

  @override
  String get registerJoinSub => 'Create your account and open your pantry.';

  @override
  String get registerUsernameLabel => 'USERNAME';

  @override
  String get registerUsernameHint => 'your_name';

  @override
  String get registerUsernameRequired => 'Please enter a username';

  @override
  String get registerUsernameMin => 'Username must be at least 3 characters';

  @override
  String get registerEmailHint => 'you@email.com';

  @override
  String get registerPasswordHint => 'At least 6 characters';

  @override
  String get registerPasswordMin => 'Password must be at least 6 characters';

  @override
  String get registerCreateAccount => 'CREATE ACCOUNT';

  @override
  String get registerHaveAccount => 'Already have an account? ';

  @override
  String get registerSignIn => 'Sign in';

  @override
  String homeHello(String name) {
    return 'Hi, $name';
  }

  @override
  String get homeDefaultUser => 'User';

  @override
  String get moodHappy => 'HAPPY';

  @override
  String get moodFull => 'FULL';

  @override
  String get moodHungry => 'HUNGRY';

  @override
  String get moodOk => 'OK';

  @override
  String get catTipHappy1 =>
      'Amazing! You ate well today. I\'m happy too. Almost.';

  @override
  String get catTipHappy2 => 'Mochi approves of your diet. For once.';

  @override
  String get catTipHappy3 => 'Did you really eat that well? Suspicious.';

  @override
  String get catTipOk1 =>
      'All good for now… but that can change if you don\'t log your lunch.';

  @override
  String get catTipOk2 =>
      'Neither good nor bad. Mediocre, like your coffee this morning.';

  @override
  String get catTipOk3 =>
      'I have one eye on your pantry. The other is sleeping.';

  @override
  String get catTipFull1 =>
      'When was the last time you fed me? Asking for a friend.';

  @override
  String get catTipFull2 => 'Overdue logging. The cat doesn\'t forget.';

  @override
  String get catTipFull3 =>
      'My belly says it\'s been a while since you logged a meal.';

  @override
  String get catTipAngry1 => 'HUNGER. EXTREME. Log something. NOW.';

  @override
  String get catTipAngry2 =>
      'Zero meals logged today. Zero. Nothing. Absolute void.';

  @override
  String get catTipAngry3 =>
      'Are you eating? Because I can\'t see it. Log your food.';

  @override
  String get dashMacroProtein => 'PROTEIN';

  @override
  String get dashMacroCarbs => 'CARBS';

  @override
  String get dashMacroFats => 'FATS';

  @override
  String get homeInPantry => 'In pantry';

  @override
  String get homeDepleted => 'Depleted';

  @override
  String get homeMealsToday => 'Meals today';

  @override
  String get stepsToday => 'Steps today';

  @override
  String get stepsPermissionDenied => 'Health Connect permission denied.';

  @override
  String get stepsLink => 'Link';

  @override
  String get homeQuickAction => 'Quick action';

  @override
  String get homeViewAll => 'VIEW ALL →';

  @override
  String get homeScanMeal => 'Scan meal';

  @override
  String get homeScanMealHint => 'PHOTO → AI';

  @override
  String get homeRestock => 'Restock';

  @override
  String get homeRestockHint => 'FROM DEPLETED';

  @override
  String get homeWeeklyProgress => 'View weekly progress';

  @override
  String ticketNote(String catName) {
    return '$catName\'s note';
  }

  @override
  String ticketMood(String label) {
    return 'MOOD: $label';
  }

  @override
  String get ticketFed => 'FED';

  @override
  String get ticketFasting => 'FASTING';

  @override
  String ticketDeducted(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pantry items were deducted today.',
      one: '1 pantry item was deducted today.',
    );
    return '$_temp0';
  }

  @override
  String get categoryProteins => 'Proteins';

  @override
  String get categoryCarbs => 'Carbs';

  @override
  String get categoryFats => 'Fats';

  @override
  String get categoryVegetables => 'Vegetables';

  @override
  String get categoryDairyEggs => 'Dairy/Eggs';

  @override
  String get pantryCalendarTooltip => 'Weekly plan and shopping list';

  @override
  String get pantryDailyGoal => 'DAILY GOAL';

  @override
  String get pantryToday => 'Today!';

  @override
  String get pantryEmptyTitle => 'Your pantry is empty';

  @override
  String get pantryEmptyBody =>
      'Scan your first product and your pantry will come to life.';

  @override
  String get pantryEmptyScan => 'Scan your first product';

  @override
  String get pantryEmptySearch => 'Search food';

  @override
  String get pantryInStock => 'IN STOCK';

  @override
  String get pantryDepleted => 'DEPLETED';

  @override
  String pantryEmptyCategory(String category) {
    return 'No products in $category';
  }

  @override
  String pantryItemReplenished(String name) {
    return '$name restocked';
  }

  @override
  String pantryItemDepleted(String name) {
    return '$name marked as depleted';
  }

  @override
  String get pantryCatNameTitle => 'Name your pet';

  @override
  String get pantryCatNameBody =>
      'Give your virtual companion a name to personalize your experience.';

  @override
  String get pantryCatNameLabel => 'Pet name';

  @override
  String get pantrySaveName => 'Save name';

  @override
  String get tourPantry1Title => 'Your pantry';

  @override
  String get tourPantry1Empty =>
      'It\'s empty for now. Scan your first product to fill it up and start tracking your macros.';

  @override
  String get tourPantry1Full =>
      'Your products live here. Tap a tab to switch shelves (categories).';

  @override
  String get tourPantry2EmptyTitle => 'Search without scanning';

  @override
  String get tourPantry2Empty =>
      'If you already know what you want, search by name and add it to your pantry without scanning.';

  @override
  String get tourPantry2FullTitle => 'Restock on tap';

  @override
  String get tourPantry2Full =>
      'In \"Depleted\", one tap on the stamp reactivates a product.';

  @override
  String get tourPantry3Title => 'Plan and list';

  @override
  String get tourPantry3 =>
      'Tap the calendar icon (top right) to see your weekly plan and smart shopping list.';

  @override
  String get petTitle => 'Your Pet';

  @override
  String get petWardrobeTooltip => 'Wardrobe';

  @override
  String petMoodLabel(String mood) {
    return 'MOOD · $mood';
  }

  @override
  String get petHunger => 'HUNGER';

  @override
  String petHungerCritical(String catName) {
    return '$catName is hungry. Feed it soon.';
  }

  @override
  String get petHungerLow => 'Lower is better. 0% = satisfied.';

  @override
  String get petLevel => 'LEVEL';

  @override
  String petLevelValue(int level) {
    return 'Lv $level';
  }

  @override
  String get petStreak => 'STREAK';

  @override
  String petStreakDays(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'days',
      one: 'day',
    );
    return '$_temp0';
  }

  @override
  String get petFeed => 'FEED';

  @override
  String get petWardrobe => 'WARDROBE';

  @override
  String petExpectingFood(String catName) {
    return '$catName was expecting something to eat…';
  }

  @override
  String petObserving(String catName, num xp) {
    return '$catName is watching you · $xp total XP';
  }

  @override
  String get profileTitle => 'My Profile';

  @override
  String get profileSettings => 'Settings';

  @override
  String get profileAge => 'Age';

  @override
  String get profileYears => 'years';

  @override
  String get profileWeight => 'Weight';

  @override
  String get profileHeight => 'Height';

  @override
  String get profileBodyFat => 'Body fat';

  @override
  String get profileDailyMacros => 'DAILY MACROS';

  @override
  String get profileCalories => 'Calories';

  @override
  String get profileProtein => 'Protein';

  @override
  String get profileCarbs => 'Carbs';

  @override
  String get profileFats => 'Fats';

  @override
  String get profileData => 'DATA';

  @override
  String get profileGender => 'Gender';

  @override
  String get profileLifestyle => 'Lifestyle';

  @override
  String get profileTraining => 'Training';

  @override
  String get profileMinutesPerWeek => 'Minutes/week';

  @override
  String get profileBmrFormula => 'BMR formula';

  @override
  String get profileEdit => 'Edit profile';

  @override
  String get profileEditDesc => 'Weight, height, body fat, goal';

  @override
  String get profileStats => 'Stats and progress';

  @override
  String get profileStatsDesc => 'Weekly summary, calories and meals';

  @override
  String get profileRecalc => 'Recalculate macros';

  @override
  String get profileRecalcDesc => 'Recalculate based on your current data';

  @override
  String get diaryTitle => 'Your diary';

  @override
  String get diarySubtitle => 'FOOD LOG';

  @override
  String get diaryToday => 'TODAY';

  @override
  String get diaryBackToToday => 'BACK TO TODAY';

  @override
  String get diaryDayTotal => 'DAY TOTAL';

  @override
  String get diarySummary => 'DAY SUMMARY';

  @override
  String get diaryAdd => 'Add';

  @override
  String get diaryAddSnack => 'Meal added';

  @override
  String diaryEmptySlot(String catName) {
    return 'Not logged yet. $catName is watching.';
  }

  @override
  String diaryItemsDeducted(int count) {
    return 'ITEMS DEDUCTED: $count';
  }

  @override
  String get diaryMealTypeLabel => 'MEAL TYPE';

  @override
  String get diaryQuantityLabel => 'AMOUNT';

  @override
  String get diaryEditMeal => 'Edit meal';

  @override
  String get diaryDeleteMeal => 'Delete meal';

  @override
  String get diaryDeleteConfirm => 'Delete';

  @override
  String get diaryEditSnackOk => 'Meal updated';

  @override
  String get diaryEditSnackPartial =>
      'Meal updated, but the pantry couldn\'t be adjusted. Check it.';

  @override
  String get diaryDeleteSnackOk => 'Meal deleted';

  @override
  String get diaryDeleteSnackPartial =>
      'Meal deleted, but the product couldn\'t be returned to the pantry.';

  @override
  String get diarySave => 'Save';

  @override
  String get diarySaving => 'Saving…';

  @override
  String get diaryTour1 => 'Your diary';

  @override
  String get diaryTour1Msg =>
      'Switch days with the arrows. Each meal is saved on the date you log it.';

  @override
  String get diaryTour2 => 'Day summary';

  @override
  String get diaryTour2Msg =>
      'Your accumulated kcal and macros live here. The goal comes from your profile.';

  @override
  String get diaryTour3 => 'Log a meal';

  @override
  String get diaryTour3Msg =>
      'Tap \"Add\" (or the +) to log a meal from the pantry or the scanner.';

  @override
  String get diaryFasting => 'FASTING';

  @override
  String get diaryQuoteNothing => 'Nothing logged today. ';

  @override
  String diaryQuoteMeals(int count) {
    return '$count of 4 meals. ';
  }

  @override
  String diaryQuoteRemainingKcal(num kcal) {
    return '$kcal kcal remaining';
  }

  @override
  String diaryQuoteRemainingPro(num pro) {
    return ' and $pro g of protein';
  }

  @override
  String get diaryQuoteMet => 'Goal met. ';

  @override
  String get diaryQuotePantryEmpty => 'Your pantry is empty. ';

  @override
  String diaryQuotePantryNames(String names) {
    return 'You have $names in the pantry. ';
  }

  @override
  String get diaryQuoteEnd => 'Just in case.';

  @override
  String get diaryWhatsEaten => 'What did you eat?';

  @override
  String diaryDeleteMealConfirm(String foodName) {
    return 'Remove $foodName from the log?';
  }

  @override
  String get nlTitle => 'Photo of the nutrition label';

  @override
  String get nlCamera => 'Camera';

  @override
  String get nlGallery => 'Gallery';

  @override
  String get nlDetectedText => 'Detected text';

  @override
  String get nlSave => 'Save to pantry';

  @override
  String get nlPhotoHint => 'Take a photo of the nutrition label';

  @override
  String get nlName => 'Product name';

  @override
  String get nlQuantity => 'Amount in the pantry';

  @override
  String get nlTableUnit => 'Table unit';

  @override
  String get nlCalories => 'Calories';

  @override
  String get nlProteins => 'Protein';

  @override
  String get nlCarbs => 'Carbs';

  @override
  String get nlFats => 'Fat';

  @override
  String nlConfidenceDetected(int percent) {
    return 'Detected $percent% of the macros. Review the values before saving.';
  }

  @override
  String get nlToastName => 'Give the product a name';

  @override
  String get nlToastGrams => 'Invalid amount in grams';

  @override
  String get nlToastOneMacro => 'I need at least one macro';

  @override
  String nlToastReadError(String error) {
    return 'Couldn\'t read the photo: $error';
  }

  @override
  String get nlToastUpload =>
      'Couldn\'t upload the photo, but I saved the product';

  @override
  String nlToastSaved(String name) {
    return '\"$name\" added to your pantry';
  }

  @override
  String get notifThemeHeader => 'THEME';

  @override
  String get notifThemeDark => 'Dark';

  @override
  String get notifThemeLight => 'Light';

  @override
  String get settingsLanguageHeader => 'LANGUAGE';

  @override
  String get settingsLanguageSystem => 'System';

  @override
  String get settingsLanguageSpanish => 'Español';

  @override
  String get settingsLanguageEnglish => 'English';

  @override
  String get notifMealReminders => 'MEAL REMINDERS';

  @override
  String get notifMealTimeHint => 'Time to log your meal of the day';

  @override
  String get notifBreakfast => 'Breakfast';

  @override
  String get notifLunch => 'Lunch';

  @override
  String get notifSnack => 'Snack';

  @override
  String get notifDinner => 'Dinner';

  @override
  String get notifSaving => 'Saving...';

  @override
  String get notifSaveSchedules => 'Save schedules';

  @override
  String get notifErrorUpdateConfig => 'Couldn\'t update the settings.';

  @override
  String get notifErrorSaveSchedules =>
      'Couldn\'t save the schedules. Try again.';

  @override
  String get notifSavedNotActivated =>
      'Schedules saved · couldn\'t activate the notifications';

  @override
  String get notifSavedActivated => 'Schedules saved · notifications activated';

  @override
  String get notifSmartHeader => 'SMART NOTIFICATIONS';

  @override
  String get notifSmartTitle => 'Contextual tips from the cat';

  @override
  String get notifSmartSubtitle =>
      'The cat lets you know at key times: if you\'re low on kcal (18:00), if you broke your streak (19:00), if a product has been in the pantry for days (20:00) and your protein milestones (21:00).';

  @override
  String get notifTestNotification => 'Test notification (Debug)';

  @override
  String get notifTestNotificationDesc =>
      'Fires a heads-up banner notification in 10 seconds';

  @override
  String get notifAbout => 'About NekoFit';

  @override
  String notifVersion(String version) {
    return 'Version $version';
  }

  @override
  String get notifResetTours => 'Reset tutorials';

  @override
  String get notifResetToursDesc =>
      'Show the cat tours again (Pantry and Diary)';

  @override
  String get notifClose => 'Close';

  @override
  String get notifAboutTagline => 'NekoFit · your personal konbini for macros';

  @override
  String get notifLogout => 'Log out';

  @override
  String get notifLogoutDesc => 'Back to sign in';

  @override
  String get notifLogoutConfirmBody =>
      'Are you sure you want to leave? Your pantry and macros stay saved in the cloud.';

  @override
  String get notifLogoutConfirm => 'Leave';

  @override
  String get notifTestSnackOk =>
      'Test notification in 10s. Minimize the app to see the banner.';

  @override
  String notifTestSnackError(String error) {
    return 'Error scheduling the test notification: $error';
  }

  @override
  String get notifResetToursSnack =>
      'Tutorials reset: Mochi will guide you again.';

  @override
  String get wardrobeMood => 'MOOD';

  @override
  String get wardrobeFree => 'Free';

  @override
  String get wardrobeLocked => 'LOCKED';

  @override
  String get wardrobeEquipped => 'EQUIPPED';

  @override
  String get wardrobeInUse => 'IN USE';

  @override
  String get wardrobeEquip => 'EQUIP';

  @override
  String get wardrobeUnlockFree => 'UNLOCK FREE';

  @override
  String get wardrobeNotYet => 'NOT YET';

  @override
  String get wardrobeHint =>
      'Tap and hold to discover the story behind each outfit.';

  @override
  String get wardrobeInYourWardrobe => '✔ In your wardrobe';

  @override
  String get wardrobeUnlockFailed => 'I couldn\'t unlock it. No idea why.';

  @override
  String get wardrobeEquipLocked =>
      'Unlock it first. You can\'t use what you don\'t own.';

  @override
  String wardrobeUnlockedSnack(String outfitName) {
    return '$outfitName unlocked. Don\'t show it off too much.';
  }

  @override
  String wardrobeProgressStreak(int current, int value) {
    return 'Streak $current/$value days';
  }

  @override
  String wardrobeProgressLevel(int current, int total) {
    return 'Level $current/$total';
  }

  @override
  String get scanTitle => 'SCAN PRODUCT';

  @override
  String get scanPrompt => 'Point at the product\'s barcode';

  @override
  String get scanWaiting => 'Waiting for a barcode...';

  @override
  String get scanSearching => 'Searching for product...';

  @override
  String get scanSearchButton => 'Search';

  @override
  String get scanSearchByName => 'Search by name';

  @override
  String get scanSearchProduct => 'Search product';

  @override
  String get scanSearchHint => 'e.g. Quaker Cinnamon Oatmeal';

  @override
  String get scanNoMacrosData => 'No macros data';

  @override
  String scanNoMacrosBody(String barcode) {
    return 'Barcode $barcode doesn\'t have enough data. Search for it by name.';
  }

  @override
  String get scanLabelPhoto => 'Photo of the table';

  @override
  String scanCodeDetected(String barcode) {
    return 'Code: $barcode';
  }

  @override
  String get scanGramsSnack => 'How many grams are you adding to the pantry?';

  @override
  String get scanProductAdded => 'Product added to the pantry';

  @override
  String get scanPhotoCustom => 'Custom photo ready';

  @override
  String get scanPhotoOff => 'Open Food Facts photo';

  @override
  String get scanPhotoNone => 'No photo available';

  @override
  String get scanMacrosPer100ml => 'Macros per 100 ml';

  @override
  String get scanGramsHint => 'e.g. 500';

  @override
  String get scanAddToPantry => 'Add to Pantry';

  @override
  String get prodEditTitle => 'Edit product';

  @override
  String get prodUnit => 'Unit';

  @override
  String get prodCategory => 'Category';

  @override
  String get prodPrice => 'Price (optional)';

  @override
  String get prodSave => 'Save changes';

  @override
  String get prodCompareSimilar => 'Compare with similar';

  @override
  String get prodPhotoHint => 'Add or change the product photo';

  @override
  String get prodUpdated => 'Product updated';

  @override
  String get prodDeleteTitle => 'Delete product';

  @override
  String prodDeleteConfirm(String name) {
    return 'Are you sure you want to remove \"$name\" from your pantry?';
  }

  @override
  String prodPhotoUploadError(String error) {
    return 'I couldn\'t upload the photo: $error';
  }

  @override
  String prodMacroField(String label, String unit) {
    return '$label (per 100$unit)';
  }

  @override
  String get peditPetSection => 'VIRTUAL PET';

  @override
  String get peditGoalSection => 'FITNESS GOAL';

  @override
  String get peditSavedSnack => 'Profile updated';

  @override
  String get peditMacrosTitle => 'Your daily macros';

  @override
  String get peditActivityPesasHit => 'Weights (HIIT / high intensity)';

  @override
  String get peditActivityPesasModerado => 'Weights (moderate pace)';

  @override
  String get peditActivityCorrerModerado => 'Running (moderate pace)';

  @override
  String get peditActivityCorrerRapido => 'Running (fast pace / intervals)';

  @override
  String get peditActivityCaminar => 'Walking';

  @override
  String get peditActivityCiclismo => 'Cycling';

  @override
  String get statsTitle => 'Statistics';

  @override
  String get statsWeek => 'Week';

  @override
  String get statsMonth => 'Month';

  @override
  String get statsYear => 'Year';

  @override
  String get statsError => 'We couldn\'t load your statistics.';

  @override
  String get statsPeriodSummary => 'Period summary';

  @override
  String get statsCalPerDay => 'Cal/day';

  @override
  String get statsOnTargetDays => 'On-target days';

  @override
  String statsOnTargetUnit(int count) {
    return 'of $count';
  }

  @override
  String get statsCurrentStreak => 'Current streak';

  @override
  String get statsDays => 'days';

  @override
  String get statsNoRecords =>
      'No records in this period — log a meal to see your trend';

  @override
  String statsYearSummary(int days, int goal) {
    return '$days days with records this year · goal $goal kcal';
  }

  @override
  String statsPeriodSummaryDetail(int logged, int total, int goal) {
    return '$logged of $total days with records · goal $goal kcal';
  }

  @override
  String get statsCaloriesWeek => 'Calories this week';

  @override
  String get statsCaloriesMonth => 'Calories this month';

  @override
  String get statsCaloriesYear => 'Calories this year';

  @override
  String get statsGoal => 'Goal';

  @override
  String get statsRecentMeals => 'Recent meals';

  @override
  String get statsWeekdayMon => 'Mon';

  @override
  String get statsWeekdayTue => 'Tue';

  @override
  String get statsWeekdayWed => 'Wed';

  @override
  String get statsWeekdayThu => 'Thu';

  @override
  String get statsWeekdayFri => 'Fri';

  @override
  String get statsWeekdaySat => 'Sat';

  @override
  String get statsWeekdaySun => 'Sun';

  @override
  String get statsMonthJan => 'Jan';

  @override
  String get statsMonthFeb => 'Feb';

  @override
  String get statsMonthMar => 'Mar';

  @override
  String get statsMonthApr => 'Apr';

  @override
  String get statsMonthMay => 'May';

  @override
  String get statsMonthJun => 'Jun';

  @override
  String get statsMonthJul => 'Jul';

  @override
  String get statsMonthAug => 'Aug';

  @override
  String get statsMonthSep => 'Sep';

  @override
  String get statsMonthOct => 'Oct';

  @override
  String get statsMonthNov => 'Nov';

  @override
  String get statsMonthDec => 'Dec';

  @override
  String get searchHint => 'e.g. chicken breast, rice, apple...';

  @override
  String get searchEmptyNoProducts =>
      'I couldn\'t find products in the search.\nIs it a fresh food?';

  @override
  String get searchAddManually => 'Add manually';

  @override
  String get searchOrTakeLabelPhoto => 'Or take a photo of the label';

  @override
  String get searchFreshSuggestions => 'FRESH SUGGESTIONS';

  @override
  String get searchSupermarketProducts => 'SUPERMARKET PRODUCTS';

  @override
  String get searchProduct => 'Product';

  @override
  String searchMacroKcal(num kcal, String unit) {
    return '$kcal kcal/100$unit';
  }

  @override
  String searchMacroProtein(String value, String unit) {
    return 'P: ${value}g/100$unit';
  }

  @override
  String searchMacroCarbs(String value, String unit) {
    return 'C: ${value}g/100$unit';
  }

  @override
  String searchMacroFats(String value, String unit) {
    return 'F: ${value}g/100$unit';
  }

  @override
  String searchFreshMacros(
    num calories,
    String proteins,
    String carbs,
    String fats,
  ) {
    return '$calories kcal · P: ${proteins}g · C: ${carbs}g · F: ${fats}g';
  }

  @override
  String get searchPhotoReady => 'Photo ready to save.';

  @override
  String get searchPhotoFetchOnSave =>
      'I\'ll fetch the photo from Open Food Facts when saving.';

  @override
  String get searchPhotoNoneAdd =>
      'No photo. Tap the box or use the buttons to add one.';

  @override
  String get searchAskName => 'What is this food called?';

  @override
  String searchManualAdded(String name) {
    return '$name added to your pantry';
  }

  @override
  String get searchAddFreshFood => 'Add fresh food';

  @override
  String get searchFoodName => 'Food name';

  @override
  String get searchFoodNameHint => 'e.g. Chicken breast, Banana, Rice...';

  @override
  String get searchSearchingImage => 'Searching for image...';

  @override
  String get searchImageFoundOff => 'Image found on Open Food Facts';

  @override
  String get searchUsingImageOff => 'Using image from Open Food Facts.';

  @override
  String get searchCategory => 'CATEGORY';

  @override
  String get searchValuesPer100g => 'VALUES PER 100g';

  @override
  String get searchQuantityAdd => 'Amount to add to the pantry';

  @override
  String get planTitle => 'Plan & pantry';

  @override
  String get planRegenerateTooltip => 'Regenerate plan';

  @override
  String get planTabThisWeek => 'This week';

  @override
  String get planTabToBuy => 'To buy';

  @override
  String get planGenerating => 'Generating a plan with your cat…';

  @override
  String get planEmptyTitle => 'No plan yet';

  @override
  String get planEmptyMessage =>
      'Tap the refresh button to generate the plan with AI.';

  @override
  String get planWeekTitle => 'This week\'s plan';

  @override
  String planAvgDaily(String avg, String goal) {
    return '$avg kcal/day · goal $goal';
  }

  @override
  String planWeekTotal(int days, String total) {
    return '$days days · $total kcal in total';
  }

  @override
  String get planShoppingLoading =>
      'Cross-checking pantry, plan and predictions…';

  @override
  String get planListEmptyTitle => 'Empty list';

  @override
  String get planListEmptyMessage =>
      'Your pantry is up to date. Come back when something runs out or gets close.';

  @override
  String get planRecalculate => 'Recalculate';

  @override
  String get planSmartList => 'Smart list';

  @override
  String planMealsDone(int done, int total) {
    return '$done / $total done';
  }

  @override
  String get planRegenerated => 'Plan regenerated!';

  @override
  String planGenerateError(String error) {
    return 'I couldn\'t generate the plan: $error';
  }

  @override
  String get planMealDone => 'Meal marked as done.';

  @override
  String get planMealUndone => 'Meal marked as not done.';

  @override
  String get planReasonDepleted => 'OUT';

  @override
  String get planReasonCritical => 'CRITICAL';

  @override
  String get planReasonPlan => 'PLAN';

  @override
  String get planReasonManual => 'MANUAL';

  @override
  String get planDayMon => 'MON';

  @override
  String get planDayTue => 'TUE';

  @override
  String get planDayWed => 'WED';

  @override
  String get planDayThu => 'THU';

  @override
  String get planDayFri => 'FRI';

  @override
  String get planDaySat => 'SAT';

  @override
  String get planDaySun => 'SUN';
}
