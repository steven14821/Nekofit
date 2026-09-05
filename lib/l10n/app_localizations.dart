import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In es, this message translates to:
  /// **'NekoFit'**
  String get appTitle;

  /// No description provided for @tagline.
  ///
  /// In es, this message translates to:
  /// **'Tu konbini personal'**
  String get tagline;

  /// No description provided for @retry.
  ///
  /// In es, this message translates to:
  /// **'Reintentar'**
  String get retry;

  /// No description provided for @authGateErrorTitle.
  ///
  /// In es, this message translates to:
  /// **'No pudimos recuperar tu perfil'**
  String get authGateErrorTitle;

  /// No description provided for @authGateErrorBody.
  ///
  /// In es, this message translates to:
  /// **'Revisa tu conexión e inténtalo de nuevo.'**
  String get authGateErrorBody;

  /// No description provided for @navHome.
  ///
  /// In es, this message translates to:
  /// **'Inicio'**
  String get navHome;

  /// No description provided for @navPantry.
  ///
  /// In es, this message translates to:
  /// **'Despensa'**
  String get navPantry;

  /// No description provided for @navDiary.
  ///
  /// In es, this message translates to:
  /// **'Diario'**
  String get navDiary;

  /// No description provided for @navPet.
  ///
  /// In es, this message translates to:
  /// **'Mascota'**
  String get navPet;

  /// No description provided for @navProfile.
  ///
  /// In es, this message translates to:
  /// **'Perfil'**
  String get navProfile;

  /// No description provided for @loginWelcome.
  ///
  /// In es, this message translates to:
  /// **'¡Hola de nuevo!'**
  String get loginWelcome;

  /// No description provided for @loginWelcomeSub.
  ///
  /// In es, this message translates to:
  /// **'Tu racha y Mochi te esperan.'**
  String get loginWelcomeSub;

  /// No description provided for @loginEmailLabel.
  ///
  /// In es, this message translates to:
  /// **'CORREO ELECTRÓNICO'**
  String get loginEmailLabel;

  /// No description provided for @loginPasswordLabel.
  ///
  /// In es, this message translates to:
  /// **'CONTRASEÑA'**
  String get loginPasswordLabel;

  /// No description provided for @loginForgotPassword.
  ///
  /// In es, this message translates to:
  /// **'¿Olvidaste tu contraseña?'**
  String get loginForgotPassword;

  /// No description provided for @loginSignIn.
  ///
  /// In es, this message translates to:
  /// **'INICIAR SESIÓN'**
  String get loginSignIn;

  /// No description provided for @loginOrContinueWith.
  ///
  /// In es, this message translates to:
  /// **'O CONTINÚA CON'**
  String get loginOrContinueWith;

  /// No description provided for @loginContinueGoogle.
  ///
  /// In es, this message translates to:
  /// **'Continuar con Google'**
  String get loginContinueGoogle;

  /// No description provided for @loginEmailErrorEmpty.
  ///
  /// In es, this message translates to:
  /// **'Por favor ingresa tu correo electrónico'**
  String get loginEmailErrorEmpty;

  /// No description provided for @loginEmailErrorInvalid.
  ///
  /// In es, this message translates to:
  /// **'Por favor ingresa un correo válido'**
  String get loginEmailErrorInvalid;

  /// No description provided for @loginPasswordErrorEmpty.
  ///
  /// In es, this message translates to:
  /// **'Por favor ingresa tu contraseña'**
  String get loginPasswordErrorEmpty;

  /// No description provided for @loginNoAccount.
  ///
  /// In es, this message translates to:
  /// **'¿No tienes cuenta? '**
  String get loginNoAccount;

  /// No description provided for @loginRegister.
  ///
  /// In es, this message translates to:
  /// **'Regístrate aquí'**
  String get loginRegister;

  /// No description provided for @loginGoogleFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo iniciar sesión con Google. Revisa tu conexión e inténtalo de nuevo.'**
  String get loginGoogleFailed;

  /// No description provided for @forgotTitle.
  ///
  /// In es, this message translates to:
  /// **'Recuperar Contraseña'**
  String get forgotTitle;

  /// No description provided for @forgotBody.
  ///
  /// In es, this message translates to:
  /// **'Ingresa tu correo electrónico registrado y te enviaremos un enlace para restablecer tu contraseña.'**
  String get forgotBody;

  /// No description provided for @emailLabel.
  ///
  /// In es, this message translates to:
  /// **'Correo electrónico'**
  String get emailLabel;

  /// No description provided for @emailEmpty.
  ///
  /// In es, this message translates to:
  /// **'Ingresa tu correo'**
  String get emailEmpty;

  /// No description provided for @emailInvalid.
  ///
  /// In es, this message translates to:
  /// **'Ingresa un correo válido'**
  String get emailInvalid;

  /// No description provided for @cancel.
  ///
  /// In es, this message translates to:
  /// **'Cancelar'**
  String get cancel;

  /// No description provided for @send.
  ///
  /// In es, this message translates to:
  /// **'Enviar'**
  String get send;

  /// No description provided for @resetEmailSent.
  ///
  /// In es, this message translates to:
  /// **'Enlace de recuperación enviado con éxito.'**
  String get resetEmailSent;

  /// Prefijo de errores; {error} es el mensaje del backend.
  ///
  /// In es, this message translates to:
  /// **'Error: {error}'**
  String errorPrefix(String error);

  /// No description provided for @onboardingSkip.
  ///
  /// In es, this message translates to:
  /// **'OMITIR'**
  String get onboardingSkip;

  /// No description provided for @onboardingTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Qué vas a ganar?'**
  String get onboardingTitle;

  /// No description provided for @onboardingSubtitle.
  ///
  /// In es, this message translates to:
  /// **'3 cosas que NekoFit hace por ti'**
  String get onboardingSubtitle;

  /// No description provided for @onboardingSlide1Title.
  ///
  /// In es, this message translates to:
  /// **'Registra tu despensa\nen 10 segundos'**
  String get onboardingSlide1Title;

  /// No description provided for @onboardingSlide1Subtitle.
  ///
  /// In es, this message translates to:
  /// **'Escanea o escribe tus productos y NekoFit lleva el inventario por ti. Sabrás qué te falta antes de que se acabe.'**
  String get onboardingSlide1Subtitle;

  /// No description provided for @onboardingSlide2Title.
  ///
  /// In es, this message translates to:
  /// **'La IA identifica lo que\ncomes con una foto'**
  String get onboardingSlide2Title;

  /// No description provided for @onboardingSlide2Subtitle.
  ///
  /// In es, this message translates to:
  /// **'Saca una foto a tu plato y la IA calcula calorías, proteínas, carbohidratos y grasas al instante. Sin pesadoras ni tablas.'**
  String get onboardingSlide2Subtitle;

  /// No description provided for @onboardingSlide3Title.
  ///
  /// In es, this message translates to:
  /// **'Tu mascota te obliga\na ser constante'**
  String get onboardingSlide3Title;

  /// No description provided for @onboardingSlide3Subtitle.
  ///
  /// In es, this message translates to:
  /// **'Cada comida registrada alimenta a tu mascota. Sube de nivel, desbloquea outfits y cuida tu racha: la suya depende de la tuya.'**
  String get onboardingSlide3Subtitle;

  /// No description provided for @start.
  ///
  /// In es, this message translates to:
  /// **'EMPEZAR'**
  String get start;

  /// No description provided for @next.
  ///
  /// In es, this message translates to:
  /// **'SIGUIENTE'**
  String get next;

  /// No description provided for @stepEssential.
  ///
  /// In es, this message translates to:
  /// **'Lo esencial'**
  String get stepEssential;

  /// No description provided for @stepPersonalize.
  ///
  /// In es, this message translates to:
  /// **'Personaliza'**
  String get stepPersonalize;

  /// No description provided for @stepExtreme.
  ///
  /// In es, this message translates to:
  /// **'Extremo'**
  String get stepExtreme;

  /// No description provided for @essentialsTitle.
  ///
  /// In es, this message translates to:
  /// **'Empieza en 30 segundos'**
  String get essentialsTitle;

  /// No description provided for @essentialsBody.
  ///
  /// In es, this message translates to:
  /// **'Tu género, edad, altura y peso bastan para calcular tu meta calórica al instante. Lo demás lo afinas después.'**
  String get essentialsBody;

  /// No description provided for @genderFemale.
  ///
  /// In es, this message translates to:
  /// **'Femenino'**
  String get genderFemale;

  /// No description provided for @genderMale.
  ///
  /// In es, this message translates to:
  /// **'Masculino'**
  String get genderMale;

  /// No description provided for @ageField.
  ///
  /// In es, this message translates to:
  /// **'Edad (años)'**
  String get ageField;

  /// No description provided for @heightField.
  ///
  /// In es, this message translates to:
  /// **'Altura (cm)'**
  String get heightField;

  /// No description provided for @weightField.
  ///
  /// In es, this message translates to:
  /// **'Peso actual (kg)'**
  String get weightField;

  /// No description provided for @goalQuestion.
  ///
  /// In es, this message translates to:
  /// **'¿Cuál es tu objetivo?'**
  String get goalQuestion;

  /// No description provided for @customGoalLabel.
  ///
  /// In es, this message translates to:
  /// **'Describe tu objetivo específico'**
  String get customGoalLabel;

  /// No description provided for @customGoalHint.
  ///
  /// In es, this message translates to:
  /// **'Ej. Incrementar resistencia para maratón de 10km'**
  String get customGoalHint;

  /// No description provided for @goalLoseWeight.
  ///
  /// In es, this message translates to:
  /// **'Perder peso'**
  String get goalLoseWeight;

  /// No description provided for @goalLoseWeightDesc.
  ///
  /// In es, this message translates to:
  /// **'Déficit calórico moderado, priorizando proteína para preservar músculo.'**
  String get goalLoseWeightDesc;

  /// No description provided for @goalMaintainWeight.
  ///
  /// In es, this message translates to:
  /// **'Mantener peso'**
  String get goalMaintainWeight;

  /// No description provided for @goalMaintainWeightDesc.
  ///
  /// In es, this message translates to:
  /// **'Equilibrio energético para sostener peso y recomposición corporal.'**
  String get goalMaintainWeightDesc;

  /// No description provided for @goalGainMuscle.
  ///
  /// In es, this message translates to:
  /// **'Ganar músculo'**
  String get goalGainMuscle;

  /// No description provided for @goalGainMuscleDesc.
  ///
  /// In es, this message translates to:
  /// **'Superávit controlado + proteína alta para hipertrofia.'**
  String get goalGainMuscleDesc;

  /// No description provided for @goalCustom.
  ///
  /// In es, this message translates to:
  /// **'Otro/Personalizado'**
  String get goalCustom;

  /// No description provided for @goalCustomDesc.
  ///
  /// In es, this message translates to:
  /// **'Si persigues metas atléticas específicas u objetivos clínicos.'**
  String get goalCustomDesc;

  /// No description provided for @recommendedDailyCalories.
  ///
  /// In es, this message translates to:
  /// **'Calorías diarias recomendadas'**
  String get recommendedDailyCalories;

  /// Muestra la fórmula BMR usada; {formula} es katch o mifflin.
  ///
  /// In es, this message translates to:
  /// **'Fórmula BMR: {formula}'**
  String bmrFormula(String formula);

  /// No description provided for @bmrFormulaKatch.
  ///
  /// In es, this message translates to:
  /// **'Katch-McArdle'**
  String get bmrFormulaKatch;

  /// No description provided for @bmrFormulaMifflin.
  ///
  /// In es, this message translates to:
  /// **'Mifflin-St Jeor'**
  String get bmrFormulaMifflin;

  /// No description provided for @macroCarbs.
  ///
  /// In es, this message translates to:
  /// **'Carbohidratos'**
  String get macroCarbs;

  /// No description provided for @macroProteins.
  ///
  /// In es, this message translates to:
  /// **'Proteínas'**
  String get macroProteins;

  /// No description provided for @macroFats.
  ///
  /// In es, this message translates to:
  /// **'Grasas'**
  String get macroFats;

  /// No description provided for @personalizeTitle.
  ///
  /// In es, this message translates to:
  /// **'Personaliza tu plan'**
  String get personalizeTitle;

  /// No description provided for @personalizeBody.
  ///
  /// In es, this message translates to:
  /// **'Opcional: afina tu cálculo con % de grasa, tu actividad diaria y tu mascota.'**
  String get personalizeBody;

  /// No description provided for @bodyFatSection.
  ///
  /// In es, this message translates to:
  /// **'% de grasa corporal'**
  String get bodyFatSection;

  /// No description provided for @bodyFatSectionHint.
  ///
  /// In es, this message translates to:
  /// **'Permite usar la fórmula Katch-McArdle, mucho más precisa que las estándar.'**
  String get bodyFatSectionHint;

  /// No description provided for @lifestyleSection.
  ///
  /// In es, this message translates to:
  /// **'Estilo de vida diario'**
  String get lifestyleSection;

  /// No description provided for @lifestyleSectionHint.
  ///
  /// In es, this message translates to:
  /// **'¿Qué haces la mayor parte del día, sin contar el entrenamiento?'**
  String get lifestyleSectionHint;

  /// No description provided for @trainingSection.
  ///
  /// In es, this message translates to:
  /// **'Gasto por entrenamiento'**
  String get trainingSection;

  /// No description provided for @trainingSectionHint.
  ///
  /// In es, this message translates to:
  /// **'Sumamos kcal fijas según el tipo de actividad y los minutos por semana.'**
  String get trainingSectionHint;

  /// No description provided for @petSection.
  ///
  /// In es, this message translates to:
  /// **'Conoce a tu mascota'**
  String get petSection;

  /// No description provided for @petSectionHint.
  ///
  /// In es, this message translates to:
  /// **'Asigna un nombre a tu compañero virtual de nutrición y cocina.'**
  String get petSectionHint;

  /// No description provided for @methodVisualTitle.
  ///
  /// In es, this message translates to:
  /// **'Método visual'**
  String get methodVisualTitle;

  /// No description provided for @methodVisualDesc.
  ///
  /// In es, this message translates to:
  /// **'Eliges tu rango con imágenes y descripciones.'**
  String get methodVisualDesc;

  /// No description provided for @methodNavyTitle.
  ///
  /// In es, this message translates to:
  /// **'Método US Navy'**
  String get methodNavyTitle;

  /// No description provided for @methodNavyDesc.
  ///
  /// In es, this message translates to:
  /// **'Cálculo real con cinta métrica (cuello, cintura, cadera).'**
  String get methodNavyDesc;

  /// No description provided for @myBodyFatEstimated.
  ///
  /// In es, this message translates to:
  /// **'Tu % de grasa estimado'**
  String get myBodyFatEstimated;

  /// No description provided for @navyHintMale.
  ///
  /// In es, this message translates to:
  /// **'La cintura debe ser mayor que el cuello.'**
  String get navyHintMale;

  /// No description provided for @navyHintFemale.
  ///
  /// In es, this message translates to:
  /// **'Completa cuello, cintura, cadera y altura.'**
  String get navyHintFemale;

  /// No description provided for @navyCalculated.
  ///
  /// In es, this message translates to:
  /// **'Calculado por fórmula US Navy'**
  String get navyCalculated;

  /// No description provided for @neckField.
  ///
  /// In es, this message translates to:
  /// **'Cuello (cm)'**
  String get neckField;

  /// No description provided for @waistField.
  ///
  /// In es, this message translates to:
  /// **'Cintura (cm)'**
  String get waistField;

  /// No description provided for @hipField.
  ///
  /// In es, this message translates to:
  /// **'Cadera (cm)'**
  String get hipField;

  /// No description provided for @calculate.
  ///
  /// In es, this message translates to:
  /// **'Calcular'**
  String get calculate;

  /// No description provided for @lifestyleSedentary.
  ///
  /// In es, this message translates to:
  /// **'Sedentario'**
  String get lifestyleSedentary;

  /// No description provided for @lifestyleSedentaryDesc.
  ///
  /// In es, this message translates to:
  /// **'Paso sentado la mayor parte del dia (estudio, oficina, programacion).'**
  String get lifestyleSedentaryDesc;

  /// No description provided for @lifestyleActive.
  ///
  /// In es, this message translates to:
  /// **'Activo'**
  String get lifestyleActive;

  /// No description provided for @lifestyleActiveDesc.
  ///
  /// In es, this message translates to:
  /// **'Trabajo de pie, caminas mucho o te mueves constantemente.'**
  String get lifestyleActiveDesc;

  /// No description provided for @trainingActivityLabel.
  ///
  /// In es, this message translates to:
  /// **'Tipo de actividad principal'**
  String get trainingActivityLabel;

  /// No description provided for @weeklyMinutes.
  ///
  /// In es, this message translates to:
  /// **'Minutos por semana'**
  String get weeklyMinutes;

  /// Minutos por semana mostrados como cantidad.
  ///
  /// In es, this message translates to:
  /// **'{minutes} min/sem'**
  String minPerWeek(int minutes);

  /// No description provided for @minShort.
  ///
  /// In es, this message translates to:
  /// **'{minutes} min'**
  String minShort(int minutes);

  /// No description provided for @trainingKcalPerDay.
  ///
  /// In es, this message translates to:
  /// **'kcal de entrenamiento / dia'**
  String get trainingKcalPerDay;

  /// No description provided for @chooseYourPet.
  ///
  /// In es, this message translates to:
  /// **'Elige tu mascota'**
  String get chooseYourPet;

  /// No description provided for @petCat.
  ///
  /// In es, this message translates to:
  /// **'Gato'**
  String get petCat;

  /// No description provided for @petDog1.
  ///
  /// In es, this message translates to:
  /// **'Perro 1'**
  String get petDog1;

  /// No description provided for @petDog2.
  ///
  /// In es, this message translates to:
  /// **'Perro 2'**
  String get petDog2;

  /// No description provided for @petNameLabel.
  ///
  /// In es, this message translates to:
  /// **'Nombre de tu mascota'**
  String get petNameLabel;

  /// No description provided for @petNameHint.
  ///
  /// In es, this message translates to:
  /// **'Ej. Mochi'**
  String get petNameHint;

  /// No description provided for @customizeButton.
  ///
  /// In es, this message translates to:
  /// **'Personalizar'**
  String get customizeButton;

  /// No description provided for @stepExtremeContinue.
  ///
  /// In es, this message translates to:
  /// **'Continuar'**
  String get stepExtremeContinue;

  /// No description provided for @stepExtremeSkip.
  ///
  /// In es, this message translates to:
  /// **'Saltar'**
  String get stepExtremeSkip;

  /// No description provided for @extremeTitle.
  ///
  /// In es, this message translates to:
  /// **'Personalización extrema'**
  String get extremeTitle;

  /// No description provided for @extremeBody.
  ///
  /// In es, this message translates to:
  /// **'Define el plazo, el ritmo de comidas y las condiciones de tu plan. Nuestro gato IA lo usará cada semana para armar tus menús.'**
  String get extremeBody;

  /// No description provided for @extremeEnableLabel.
  ///
  /// In es, this message translates to:
  /// **'Crear plan personalizado'**
  String get extremeEnableLabel;

  /// No description provided for @extremeEnableDesc.
  ///
  /// In es, this message translates to:
  /// **'Actívalo para generar un plan de 4, 8 o 12 semanas con tus preferencias y condiciones.'**
  String get extremeEnableDesc;

  /// No description provided for @extremePhaseLabel.
  ///
  /// In es, this message translates to:
  /// **'Fase del plan'**
  String get extremePhaseLabel;

  /// No description provided for @extremePhaseCut.
  ///
  /// In es, this message translates to:
  /// **'Perder peso'**
  String get extremePhaseCut;

  /// No description provided for @extremePhaseMaintain.
  ///
  /// In es, this message translates to:
  /// **'Mantener peso'**
  String get extremePhaseMaintain;

  /// No description provided for @extremePhaseGain.
  ///
  /// In es, this message translates to:
  /// **'Ganar músculo'**
  String get extremePhaseGain;

  /// No description provided for @extremePhaseRecomp.
  ///
  /// In es, this message translates to:
  /// **'Recomposición'**
  String get extremePhaseRecomp;

  /// No description provided for @extremeDurationLabel.
  ///
  /// In es, this message translates to:
  /// **'Duración'**
  String get extremeDurationLabel;

  /// No description provided for @extremeW4.
  ///
  /// In es, this message translates to:
  /// **'4 semanas'**
  String get extremeW4;

  /// No description provided for @extremeW8.
  ///
  /// In es, this message translates to:
  /// **'8 semanas'**
  String get extremeW8;

  /// No description provided for @extremeW12.
  ///
  /// In es, this message translates to:
  /// **'12 semanas'**
  String get extremeW12;

  /// No description provided for @extremeMealsLabel.
  ///
  /// In es, this message translates to:
  /// **'Comidas al día'**
  String get extremeMealsLabel;

  /// No description provided for @extremeMealsHint.
  ///
  /// In es, this message translates to:
  /// **'Afecta solo al plan semanal IA, no a tus macros.'**
  String get extremeMealsHint;

  /// No description provided for @extremeMeals3.
  ///
  /// In es, this message translates to:
  /// **'3 comidas'**
  String get extremeMeals3;

  /// No description provided for @extremeMeals4.
  ///
  /// In es, this message translates to:
  /// **'4 comidas'**
  String get extremeMeals4;

  /// No description provided for @extremeMeals5.
  ///
  /// In es, this message translates to:
  /// **'5 comidas'**
  String get extremeMeals5;

  /// No description provided for @extremeIfLabel.
  ///
  /// In es, this message translates to:
  /// **'Ayuno intermitente'**
  String get extremeIfLabel;

  /// No description provided for @extremeIfDesc.
  ///
  /// In es, this message translates to:
  /// **'La primera comida de la mañana queda fuera del plan.'**
  String get extremeIfDesc;

  /// No description provided for @extremeIf16.
  ///
  /// In es, this message translates to:
  /// **'16:8'**
  String get extremeIf16;

  /// No description provided for @extremeIf18.
  ///
  /// In es, this message translates to:
  /// **'18:6'**
  String get extremeIf18;

  /// No description provided for @extremeContextLabel.
  ///
  /// In es, this message translates to:
  /// **'Tu contexto, opcional'**
  String get extremeContextLabel;

  /// No description provided for @extremeContextHint.
  ///
  /// In es, this message translates to:
  /// **'Este contexto se aplica a cada plan semanal. Separa los elementos con comas.'**
  String get extremeContextHint;

  /// No description provided for @extremeMedicalLabel.
  ///
  /// In es, this message translates to:
  /// **'Condiciones médicas'**
  String get extremeMedicalLabel;

  /// No description provided for @extremeMedicalHint.
  ///
  /// In es, this message translates to:
  /// **'Ejemplos: resistencia a la insulina, hipertensión, hipotiroidismo'**
  String get extremeMedicalHint;

  /// No description provided for @extremeDietLabel.
  ///
  /// In es, this message translates to:
  /// **'Preferencias y restricciones'**
  String get extremeDietLabel;

  /// No description provided for @extremeDietHint.
  ///
  /// In es, this message translates to:
  /// **'Ejemplos: vegana, keto, sin gluten, sin lactosa'**
  String get extremeDietHint;

  /// No description provided for @extremeMustHaveLabel.
  ///
  /// In es, this message translates to:
  /// **'Imprescindibles'**
  String get extremeMustHaveLabel;

  /// No description provided for @extremeMustHaveHint.
  ///
  /// In es, this message translates to:
  /// **'Alimentos que te encantan y no quieres soltar. Se incluyen casi a diario.'**
  String get extremeMustHaveHint;

  /// No description provided for @extremeAversionsLabel.
  ///
  /// In es, this message translates to:
  /// **'Aversiones'**
  String get extremeAversionsLabel;

  /// No description provided for @extremeAversionsHint.
  ///
  /// In es, this message translates to:
  /// **'Alimentos a evitar por completo en el plan.'**
  String get extremeAversionsHint;

  /// No description provided for @extremeNotice.
  ///
  /// In es, this message translates to:
  /// **'El plan es un apoyo opcional que organiza tus comidas sobre las calorías de tu objetivo sin cambiarlas. Al vencer, NekoFit te sugerirá la siguiente fase.'**
  String get extremeNotice;

  /// No description provided for @planExpiredTitle.
  ///
  /// In es, this message translates to:
  /// **'Tu plan terminó'**
  String get planExpiredTitle;

  /// No description provided for @planExpiredSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Tu plan nutricional ha llegado a su fin.'**
  String get planExpiredSubtitle;

  /// No description provided for @planExpiredBody.
  ///
  /// In es, this message translates to:
  /// **'Tu plan de {weeks} semanas ha terminado. La siguiente fase sugerida es {phase}. ¿La aplicamos? Se mantendrán las calorías de tu objetivo.'**
  String planExpiredBody(int weeks, String phase);

  /// No description provided for @planApprove.
  ///
  /// In es, this message translates to:
  /// **'Aplicar'**
  String get planApprove;

  /// No description provided for @planSkip.
  ///
  /// In es, this message translates to:
  /// **'No por ahora'**
  String get planSkip;

  /// No description provided for @planTransited.
  ///
  /// In es, this message translates to:
  /// **'Fase aplicada. Tu nuevo plan ya está activo y mantiene las calorías de tu objetivo.'**
  String get planTransited;

  /// No description provided for @planTransitError.
  ///
  /// In es, this message translates to:
  /// **'No se pudo aplicar la fase: {error}'**
  String planTransitError(String error);

  /// No description provided for @saveAndStart.
  ///
  /// In es, this message translates to:
  /// **'Guardar y empezar'**
  String get saveAndStart;

  /// No description provided for @savePlanButton.
  ///
  /// In es, this message translates to:
  /// **'Guardar plan'**
  String get savePlanButton;

  /// No description provided for @deletePlanButton.
  ///
  /// In es, this message translates to:
  /// **'Eliminar plan'**
  String get deletePlanButton;

  /// No description provided for @back.
  ///
  /// In es, this message translates to:
  /// **'Atrás'**
  String get back;

  /// No description provided for @snackEssentials.
  ///
  /// In es, this message translates to:
  /// **'Completa edad, altura y peso para calcular tu meta al instante.'**
  String get snackEssentials;

  /// No description provided for @snackCustomGoal.
  ///
  /// In es, this message translates to:
  /// **'Por favor describe tu objetivo fitness personalizado.'**
  String get snackCustomGoal;

  /// No description provided for @snackMeasures.
  ///
  /// In es, this message translates to:
  /// **'Completa las medidas para calcular tu % de grasa.'**
  String get snackMeasures;

  /// No description provided for @saveProfileError.
  ///
  /// In es, this message translates to:
  /// **'Error al guardar perfil: {error}'**
  String saveProfileError(String error);

  /// No description provided for @registerJoinTitle.
  ///
  /// In es, this message translates to:
  /// **'Únete a NekoFit'**
  String get registerJoinTitle;

  /// No description provided for @registerJoinSub.
  ///
  /// In es, this message translates to:
  /// **'Crea tu cuenta y abre tu despensa.'**
  String get registerJoinSub;

  /// No description provided for @registerUsernameLabel.
  ///
  /// In es, this message translates to:
  /// **'NOMBRE DE USUARIO'**
  String get registerUsernameLabel;

  /// No description provided for @registerUsernameHint.
  ///
  /// In es, this message translates to:
  /// **'tu_nombre'**
  String get registerUsernameHint;

  /// No description provided for @registerUsernameRequired.
  ///
  /// In es, this message translates to:
  /// **'Por favor ingresa un nombre de usuario'**
  String get registerUsernameRequired;

  /// No description provided for @registerUsernameMin.
  ///
  /// In es, this message translates to:
  /// **'El nombre de usuario debe tener al menos 3 caracteres'**
  String get registerUsernameMin;

  /// No description provided for @registerEmailHint.
  ///
  /// In es, this message translates to:
  /// **'tú@correo.com'**
  String get registerEmailHint;

  /// No description provided for @registerPasswordHint.
  ///
  /// In es, this message translates to:
  /// **'Mínimo 6 caracteres'**
  String get registerPasswordHint;

  /// No description provided for @registerPasswordMin.
  ///
  /// In es, this message translates to:
  /// **'La contraseña debe tener al menos 6 caracteres'**
  String get registerPasswordMin;

  /// No description provided for @registerCreateAccount.
  ///
  /// In es, this message translates to:
  /// **'CREAR CUENTA'**
  String get registerCreateAccount;

  /// No description provided for @registerHaveAccount.
  ///
  /// In es, this message translates to:
  /// **'¿Ya tienes cuenta? '**
  String get registerHaveAccount;

  /// No description provided for @registerSignIn.
  ///
  /// In es, this message translates to:
  /// **'Inicia sesión'**
  String get registerSignIn;

  /// No description provided for @homeHello.
  ///
  /// In es, this message translates to:
  /// **'Hola, {name}'**
  String homeHello(String name);

  /// No description provided for @homeDefaultUser.
  ///
  /// In es, this message translates to:
  /// **'Usuario'**
  String get homeDefaultUser;

  /// No description provided for @moodHappy.
  ///
  /// In es, this message translates to:
  /// **'FELIZ'**
  String get moodHappy;

  /// No description provided for @moodFull.
  ///
  /// In es, this message translates to:
  /// **'LLENO'**
  String get moodFull;

  /// No description provided for @moodHungry.
  ///
  /// In es, this message translates to:
  /// **'HAMBRE'**
  String get moodHungry;

  /// No description provided for @moodOk.
  ///
  /// In es, this message translates to:
  /// **'OK'**
  String get moodOk;

  /// No description provided for @catTipHappy1.
  ///
  /// In es, this message translates to:
  /// **'¡Increíble! Has comido bien hoy. Yo también estoy contento. Casi.'**
  String get catTipHappy1;

  /// No description provided for @catTipHappy2.
  ///
  /// In es, this message translates to:
  /// **'Mochi aprueba tu dieta. Por una vez.'**
  String get catTipHappy2;

  /// No description provided for @catTipHappy3.
  ///
  /// In es, this message translates to:
  /// **'¿De verdad comiste tan bien? Sospechoso.'**
  String get catTipHappy3;

  /// No description provided for @catTipOk1.
  ///
  /// In es, this message translates to:
  /// **'Todo bien por ahora… pero eso puede cambiar si no registras tu almuerzo.'**
  String get catTipOk1;

  /// No description provided for @catTipOk2.
  ///
  /// In es, this message translates to:
  /// **'Ni bien ni mal. Mediocre, como tu café de esta mañana.'**
  String get catTipOk2;

  /// No description provided for @catTipOk3.
  ///
  /// In es, this message translates to:
  /// **'Tengo un ojo en tu despensa. El otro está durmiendo.'**
  String get catTipOk3;

  /// No description provided for @catTipFull1.
  ///
  /// In es, this message translates to:
  /// **'¿Cuándo fue la última vez que me diste de comer? Pregunto para un amigo.'**
  String get catTipFull1;

  /// No description provided for @catTipFull2.
  ///
  /// In es, this message translates to:
  /// **'Registro atrasado. El gato no olvida.'**
  String get catTipFull2;

  /// No description provided for @catTipFull3.
  ///
  /// In es, this message translates to:
  /// **'Mi panza dice que llevas tiempo sin pasar por el diario.'**
  String get catTipFull3;

  /// No description provided for @catTipAngry1.
  ///
  /// In es, this message translates to:
  /// **'HAMBRE. EXTREMA. Registra algo. YA.'**
  String get catTipAngry1;

  /// No description provided for @catTipAngry2.
  ///
  /// In es, this message translates to:
  /// **'Cero comidas registradas hoy. Cero. Nada. Vacío total.'**
  String get catTipAngry2;

  /// No description provided for @catTipAngry3.
  ///
  /// In es, this message translates to:
  /// **'¿Estás comiendo? Porque yo no lo veo. Registra tu comida.'**
  String get catTipAngry3;

  /// No description provided for @dashMacroProtein.
  ///
  /// In es, this message translates to:
  /// **'PROTEÍNA'**
  String get dashMacroProtein;

  /// No description provided for @dashMacroCarbs.
  ///
  /// In es, this message translates to:
  /// **'CARBOS'**
  String get dashMacroCarbs;

  /// No description provided for @dashMacroFats.
  ///
  /// In es, this message translates to:
  /// **'GRASAS'**
  String get dashMacroFats;

  /// No description provided for @homeInPantry.
  ///
  /// In es, this message translates to:
  /// **'En despensa'**
  String get homeInPantry;

  /// No description provided for @homeDepleted.
  ///
  /// In es, this message translates to:
  /// **'Agotados'**
  String get homeDepleted;

  /// No description provided for @homeMealsToday.
  ///
  /// In es, this message translates to:
  /// **'Comidas hoy'**
  String get homeMealsToday;

  /// No description provided for @stepsToday.
  ///
  /// In es, this message translates to:
  /// **'Pasos hoy'**
  String get stepsToday;

  /// No description provided for @stepsPermissionDenied.
  ///
  /// In es, this message translates to:
  /// **'Permiso de Health Connect denegado.'**
  String get stepsPermissionDenied;

  /// No description provided for @stepsLink.
  ///
  /// In es, this message translates to:
  /// **'Vincular'**
  String get stepsLink;

  /// No description provided for @homeQuickAction.
  ///
  /// In es, this message translates to:
  /// **'Acción rápida'**
  String get homeQuickAction;

  /// No description provided for @homeViewAll.
  ///
  /// In es, this message translates to:
  /// **'VER TODO →'**
  String get homeViewAll;

  /// No description provided for @homeScanMeal.
  ///
  /// In es, this message translates to:
  /// **'Analizar plato'**
  String get homeScanMeal;

  /// No description provided for @homeScanMealHint.
  ///
  /// In es, this message translates to:
  /// **'FOTO → IA'**
  String get homeScanMealHint;

  /// No description provided for @homeRestock.
  ///
  /// In es, this message translates to:
  /// **'Reabastecer'**
  String get homeRestock;

  /// No description provided for @homeRestockHint.
  ///
  /// In es, this message translates to:
  /// **'DESDE AGOTADOS'**
  String get homeRestockHint;

  /// No description provided for @homeWeeklyProgress.
  ///
  /// In es, this message translates to:
  /// **'Ver progreso semanal'**
  String get homeWeeklyProgress;

  /// No description provided for @homePlanTitle.
  ///
  /// In es, this message translates to:
  /// **'Mi plan nutricional'**
  String get homePlanTitle;

  /// No description provided for @homePlanEmptyTitle.
  ///
  /// In es, this message translates to:
  /// **'Crea tu plan nutricional'**
  String get homePlanEmptyTitle;

  /// No description provided for @homePlanEditHint.
  ///
  /// In es, this message translates to:
  /// **'Toca para ajustar tu fase, duración y comidas. También puedes volver al ritmo clásico sin plan.'**
  String get homePlanEditHint;

  /// No description provided for @homePlanEmptyHint.
  ///
  /// In es, this message translates to:
  /// **'Crea un plan opcional que organiza tus comidas sobre las calorías de tu objetivo sin cambiarlas.'**
  String get homePlanEmptyHint;

  /// No description provided for @planCardProgress.
  ///
  /// In es, this message translates to:
  /// **'{daysLeft} / {totalDays} días'**
  String planCardProgress(int daysLeft, int totalDays);

  /// No description provided for @planCardWeeks.
  ///
  /// In es, this message translates to:
  /// **'semanas'**
  String get planCardWeeks;

  /// No description provided for @planSavedNotice.
  ///
  /// In es, this message translates to:
  /// **'Plan guardado'**
  String get planSavedNotice;

  /// No description provided for @ticketNote.
  ///
  /// In es, this message translates to:
  /// **'Nota de {catName}'**
  String ticketNote(String catName);

  /// No description provided for @ticketMood.
  ///
  /// In es, this message translates to:
  /// **'MOOD: {label}'**
  String ticketMood(String label);

  /// No description provided for @ticketFed.
  ///
  /// In es, this message translates to:
  /// **'ALIMENTADO'**
  String get ticketFed;

  /// No description provided for @ticketFasting.
  ///
  /// In es, this message translates to:
  /// **'EN AYUNAS'**
  String get ticketFasting;

  /// No description provided for @ticketDeducted.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, one{Se descontó 1 ítem de la despensa hoy.} other{Se descontaron {count} ítems de la despensa hoy.}}'**
  String ticketDeducted(num count);

  /// No description provided for @categoryProteins.
  ///
  /// In es, this message translates to:
  /// **'Proteínas'**
  String get categoryProteins;

  /// No description provided for @categoryCarbs.
  ///
  /// In es, this message translates to:
  /// **'Carbohidratos'**
  String get categoryCarbs;

  /// No description provided for @categoryFats.
  ///
  /// In es, this message translates to:
  /// **'Grasas'**
  String get categoryFats;

  /// No description provided for @categoryVegetables.
  ///
  /// In es, this message translates to:
  /// **'Vegetales'**
  String get categoryVegetables;

  /// No description provided for @categoryDairyEggs.
  ///
  /// In es, this message translates to:
  /// **'Lácteos/Huevos'**
  String get categoryDairyEggs;

  /// No description provided for @pantryCalendarTooltip.
  ///
  /// In es, this message translates to:
  /// **'Plan semanal y lista de compras'**
  String get pantryCalendarTooltip;

  /// No description provided for @pantryDailyGoal.
  ///
  /// In es, this message translates to:
  /// **'META DIARIA'**
  String get pantryDailyGoal;

  /// No description provided for @pantryToday.
  ///
  /// In es, this message translates to:
  /// **'¡Hoy!'**
  String get pantryToday;

  /// No description provided for @pantryEmptyTitle.
  ///
  /// In es, this message translates to:
  /// **'Tu despensa está vacía'**
  String get pantryEmptyTitle;

  /// No description provided for @pantryEmptyBody.
  ///
  /// In es, this message translates to:
  /// **'Escanea tu primer producto y tu despensa cobrará vida.'**
  String get pantryEmptyBody;

  /// No description provided for @pantryEmptyScan.
  ///
  /// In es, this message translates to:
  /// **'Escanear tu primer producto'**
  String get pantryEmptyScan;

  /// No description provided for @pantryEmptySearch.
  ///
  /// In es, this message translates to:
  /// **'Buscar alimento'**
  String get pantryEmptySearch;

  /// No description provided for @pantryInStock.
  ///
  /// In es, this message translates to:
  /// **'EN EXISTENCIA'**
  String get pantryInStock;

  /// No description provided for @pantryDepleted.
  ///
  /// In es, this message translates to:
  /// **'AGOTADOS'**
  String get pantryDepleted;

  /// No description provided for @pantryEmptyCategory.
  ///
  /// In es, this message translates to:
  /// **'No hay productos en {category}'**
  String pantryEmptyCategory(String category);

  /// No description provided for @pantryItemReplenished.
  ///
  /// In es, this message translates to:
  /// **'{name} reabastecido'**
  String pantryItemReplenished(String name);

  /// No description provided for @pantryItemDepleted.
  ///
  /// In es, this message translates to:
  /// **'{name} marcado como agotado'**
  String pantryItemDepleted(String name);

  /// No description provided for @pantryCatNameTitle.
  ///
  /// In es, this message translates to:
  /// **'Nombra a tu mascota'**
  String get pantryCatNameTitle;

  /// No description provided for @pantryCatNameBody.
  ///
  /// In es, this message translates to:
  /// **'Asigna un nombre a tu compañero virtual para personalizar tu experiencia.'**
  String get pantryCatNameBody;

  /// No description provided for @pantryCatNameLabel.
  ///
  /// In es, this message translates to:
  /// **'Nombre de la mascota'**
  String get pantryCatNameLabel;

  /// No description provided for @pantrySaveName.
  ///
  /// In es, this message translates to:
  /// **'Guardar nombre'**
  String get pantrySaveName;

  /// No description provided for @tourPantry1Title.
  ///
  /// In es, this message translates to:
  /// **'Tu despensa'**
  String get tourPantry1Title;

  /// No description provided for @tourPantry1Empty.
  ///
  /// In es, this message translates to:
  /// **'Está vacía por ahora. Escanea tu primer producto para llenarla y empezar a controlar tus macros.'**
  String get tourPantry1Empty;

  /// No description provided for @tourPantry1Full.
  ///
  /// In es, this message translates to:
  /// **'Aquí viven tus productos. Toca una pestaña para cambiar de anaquel (categoría).'**
  String get tourPantry1Full;

  /// No description provided for @tourPantry2EmptyTitle.
  ///
  /// In es, this message translates to:
  /// **'Buscar sin escanear'**
  String get tourPantry2EmptyTitle;

  /// No description provided for @tourPantry2Empty.
  ///
  /// In es, this message translates to:
  /// **'Si ya sabes qué quieres, búscalo por nombre y añádelo a tu despensa sin escanear.'**
  String get tourPantry2Empty;

  /// No description provided for @tourPantry2FullTitle.
  ///
  /// In es, this message translates to:
  /// **'Reabastecer al toque'**
  String get tourPantry2FullTitle;

  /// No description provided for @tourPantry2Full.
  ///
  /// In es, this message translates to:
  /// **'En \"Agotados\" basta un toque sobre el sello para reactivar un producto.'**
  String get tourPantry2Full;

  /// No description provided for @tourPantry3Title.
  ///
  /// In es, this message translates to:
  /// **'Plan y lista'**
  String get tourPantry3Title;

  /// No description provided for @tourPantry3.
  ///
  /// In es, this message translates to:
  /// **'Pulsa el icono del calendario (arriba a la derecha) para ver tu plan semanal y la lista de compras inteligente.'**
  String get tourPantry3;

  /// No description provided for @petTitle.
  ///
  /// In es, this message translates to:
  /// **'Tu Mascota'**
  String get petTitle;

  /// No description provided for @petWardrobeTooltip.
  ///
  /// In es, this message translates to:
  /// **'Vestidor'**
  String get petWardrobeTooltip;

  /// No description provided for @petMoodLabel.
  ///
  /// In es, this message translates to:
  /// **'HUMOR · {mood}'**
  String petMoodLabel(String mood);

  /// No description provided for @petHunger.
  ///
  /// In es, this message translates to:
  /// **'HAMBRE'**
  String get petHunger;

  /// No description provided for @petHungerCritical.
  ///
  /// In es, this message translates to:
  /// **'{catName} está hambriento. Dale de comer pronto.'**
  String petHungerCritical(String catName);

  /// No description provided for @petHungerLow.
  ///
  /// In es, this message translates to:
  /// **'Más bajo es mejor. 0% = satisfecho.'**
  String get petHungerLow;

  /// No description provided for @petLevel.
  ///
  /// In es, this message translates to:
  /// **'NIVEL'**
  String get petLevel;

  /// No description provided for @petLevelValue.
  ///
  /// In es, this message translates to:
  /// **'Lv {level}'**
  String petLevelValue(int level);

  /// No description provided for @petStreak.
  ///
  /// In es, this message translates to:
  /// **'RACHA'**
  String get petStreak;

  /// No description provided for @petStreakDays.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, one{día} other{días}}'**
  String petStreakDays(num count);

  /// No description provided for @petFeed.
  ///
  /// In es, this message translates to:
  /// **'DAR DE COMER'**
  String get petFeed;

  /// No description provided for @petWardrobe.
  ///
  /// In es, this message translates to:
  /// **'VESTIDOR'**
  String get petWardrobe;

  /// No description provided for @petExpectingFood.
  ///
  /// In es, this message translates to:
  /// **'{catName} esperaba algo de comer…'**
  String petExpectingFood(String catName);

  /// No description provided for @petObserving.
  ///
  /// In es, this message translates to:
  /// **'{catName} te observa · XP total {xp}'**
  String petObserving(String catName, num xp);

  /// No description provided for @profileTitle.
  ///
  /// In es, this message translates to:
  /// **'Mi Perfil'**
  String get profileTitle;

  /// No description provided for @profileSettings.
  ///
  /// In es, this message translates to:
  /// **'Configuración'**
  String get profileSettings;

  /// No description provided for @profileAge.
  ///
  /// In es, this message translates to:
  /// **'Edad'**
  String get profileAge;

  /// No description provided for @profileYears.
  ///
  /// In es, this message translates to:
  /// **'años'**
  String get profileYears;

  /// No description provided for @profileWeight.
  ///
  /// In es, this message translates to:
  /// **'Peso'**
  String get profileWeight;

  /// No description provided for @profileHeight.
  ///
  /// In es, this message translates to:
  /// **'Altura'**
  String get profileHeight;

  /// No description provided for @profileBodyFat.
  ///
  /// In es, this message translates to:
  /// **'Grasa'**
  String get profileBodyFat;

  /// No description provided for @profileDailyMacros.
  ///
  /// In es, this message translates to:
  /// **'MARCOS DIARIOS'**
  String get profileDailyMacros;

  /// No description provided for @profileCalories.
  ///
  /// In es, this message translates to:
  /// **'Calorías'**
  String get profileCalories;

  /// No description provided for @profileProtein.
  ///
  /// In es, this message translates to:
  /// **'Proteína'**
  String get profileProtein;

  /// No description provided for @profileCarbs.
  ///
  /// In es, this message translates to:
  /// **'Carbos'**
  String get profileCarbs;

  /// No description provided for @profileFats.
  ///
  /// In es, this message translates to:
  /// **'Grasas'**
  String get profileFats;

  /// No description provided for @profileData.
  ///
  /// In es, this message translates to:
  /// **'DATOS'**
  String get profileData;

  /// No description provided for @profileGender.
  ///
  /// In es, this message translates to:
  /// **'Género'**
  String get profileGender;

  /// No description provided for @profileLifestyle.
  ///
  /// In es, this message translates to:
  /// **'Estilo de vida'**
  String get profileLifestyle;

  /// No description provided for @profileTraining.
  ///
  /// In es, this message translates to:
  /// **'Entrenamiento'**
  String get profileTraining;

  /// No description provided for @profileMinutesPerWeek.
  ///
  /// In es, this message translates to:
  /// **'Minutos/semana'**
  String get profileMinutesPerWeek;

  /// No description provided for @profileBmrFormula.
  ///
  /// In es, this message translates to:
  /// **'Fórmula BMR'**
  String get profileBmrFormula;

  /// No description provided for @profileEdit.
  ///
  /// In es, this message translates to:
  /// **'Editar perfil'**
  String get profileEdit;

  /// No description provided for @profileEditDesc.
  ///
  /// In es, this message translates to:
  /// **'Peso, altura, grasa corporal, objetivo'**
  String get profileEditDesc;

  /// No description provided for @profileStats.
  ///
  /// In es, this message translates to:
  /// **'Estadísticas y progreso'**
  String get profileStats;

  /// No description provided for @profileStatsDesc.
  ///
  /// In es, this message translates to:
  /// **'Resumen semanal, calorías y comidas'**
  String get profileStatsDesc;

  /// No description provided for @profileRecalc.
  ///
  /// In es, this message translates to:
  /// **'Recalcular macros'**
  String get profileRecalc;

  /// No description provided for @profileRecalcDesc.
  ///
  /// In es, this message translates to:
  /// **'Volver a calcular según tus datos actuales'**
  String get profileRecalcDesc;

  /// No description provided for @diaryTitle.
  ///
  /// In es, this message translates to:
  /// **'Tu diario'**
  String get diaryTitle;

  /// No description provided for @diarySubtitle.
  ///
  /// In es, this message translates to:
  /// **'ALIMENTARIO'**
  String get diarySubtitle;

  /// No description provided for @diaryToday.
  ///
  /// In es, this message translates to:
  /// **'HOY'**
  String get diaryToday;

  /// No description provided for @diaryBackToToday.
  ///
  /// In es, this message translates to:
  /// **'VOLVER A HOY'**
  String get diaryBackToToday;

  /// No description provided for @diaryDayTotal.
  ///
  /// In es, this message translates to:
  /// **'TOTAL DEL DÍA'**
  String get diaryDayTotal;

  /// No description provided for @diarySummary.
  ///
  /// In es, this message translates to:
  /// **'RESUMEN DEL DÍA'**
  String get diarySummary;

  /// No description provided for @diaryAdd.
  ///
  /// In es, this message translates to:
  /// **'Añadir'**
  String get diaryAdd;

  /// No description provided for @diaryAddSnack.
  ///
  /// In es, this message translates to:
  /// **'Comida agregada'**
  String get diaryAddSnack;

  /// No description provided for @diaryEmptySlot.
  ///
  /// In es, this message translates to:
  /// **'Sin registrar. {catName} está mirando.'**
  String diaryEmptySlot(String catName);

  /// No description provided for @diaryItemsDeducted.
  ///
  /// In es, this message translates to:
  /// **'ÍTEMS DESCONTADOS: {count}'**
  String diaryItemsDeducted(int count);

  /// No description provided for @diaryMealTypeLabel.
  ///
  /// In es, this message translates to:
  /// **'TIPO DE COMIDA'**
  String get diaryMealTypeLabel;

  /// No description provided for @diaryQuantityLabel.
  ///
  /// In es, this message translates to:
  /// **'CANTIDAD'**
  String get diaryQuantityLabel;

  /// No description provided for @diaryEditMeal.
  ///
  /// In es, this message translates to:
  /// **'Editar comida'**
  String get diaryEditMeal;

  /// No description provided for @diaryDeleteMeal.
  ///
  /// In es, this message translates to:
  /// **'Eliminar comida'**
  String get diaryDeleteMeal;

  /// No description provided for @diaryDeleteConfirm.
  ///
  /// In es, this message translates to:
  /// **'Eliminar'**
  String get diaryDeleteConfirm;

  /// No description provided for @diaryEditSnackOk.
  ///
  /// In es, this message translates to:
  /// **'Comida actualizada'**
  String get diaryEditSnackOk;

  /// No description provided for @diaryEditSnackPartial.
  ///
  /// In es, this message translates to:
  /// **'Comida actualizada, pero no se pudo ajustar la despensa. Revísala.'**
  String get diaryEditSnackPartial;

  /// No description provided for @diaryDeleteSnackOk.
  ///
  /// In es, this message translates to:
  /// **'Comida eliminada'**
  String get diaryDeleteSnackOk;

  /// No description provided for @diaryDeleteSnackPartial.
  ///
  /// In es, this message translates to:
  /// **'Comida eliminada, pero no se pudo devolver el producto a la despensa.'**
  String get diaryDeleteSnackPartial;

  /// No description provided for @diarySave.
  ///
  /// In es, this message translates to:
  /// **'Guardar'**
  String get diarySave;

  /// No description provided for @diarySaving.
  ///
  /// In es, this message translates to:
  /// **'Guardando…'**
  String get diarySaving;

  /// No description provided for @diaryTour1.
  ///
  /// In es, this message translates to:
  /// **'Tu diario'**
  String get diaryTour1;

  /// No description provided for @diaryTour1Msg.
  ///
  /// In es, this message translates to:
  /// **'Cambia de día con las flechas. Cada comida queda guardada en la fecha en que la registras.'**
  String get diaryTour1Msg;

  /// No description provided for @diaryTour2.
  ///
  /// In es, this message translates to:
  /// **'Resumen del día'**
  String get diaryTour2;

  /// No description provided for @diaryTour2Msg.
  ///
  /// In es, this message translates to:
  /// **'Aquí viven tus kcal y macros acumuladas. La meta se toma de tu perfil.'**
  String get diaryTour2Msg;

  /// No description provided for @diaryTour3.
  ///
  /// In es, this message translates to:
  /// **'Registrar comida'**
  String get diaryTour3;

  /// No description provided for @diaryTour3Msg.
  ///
  /// In es, this message translates to:
  /// **'Pulsa \"Añadir\" (o el +) para registrar una comida desde la despensa o con el escáner.'**
  String get diaryTour3Msg;

  /// No description provided for @diaryFasting.
  ///
  /// In es, this message translates to:
  /// **'EN AYUNAS'**
  String get diaryFasting;

  /// No description provided for @diaryQuoteNothing.
  ///
  /// In es, this message translates to:
  /// **'Nada registrado hoy. '**
  String get diaryQuoteNothing;

  /// No description provided for @diaryQuoteMeals.
  ///
  /// In es, this message translates to:
  /// **'{count} de 4 comidas. '**
  String diaryQuoteMeals(int count);

  /// No description provided for @diaryQuoteRemainingKcal.
  ///
  /// In es, this message translates to:
  /// **'Te faltan {kcal} kcal'**
  String diaryQuoteRemainingKcal(num kcal);

  /// No description provided for @diaryQuoteRemainingPro.
  ///
  /// In es, this message translates to:
  /// **' y {pro} g de proteína'**
  String diaryQuoteRemainingPro(num pro);

  /// No description provided for @diaryQuoteMet.
  ///
  /// In es, this message translates to:
  /// **'Objetivo cumplido. '**
  String get diaryQuoteMet;

  /// No description provided for @diaryQuotePantryEmpty.
  ///
  /// In es, this message translates to:
  /// **'Tu despensa está vacía. '**
  String get diaryQuotePantryEmpty;

  /// No description provided for @diaryQuotePantryNames.
  ///
  /// In es, this message translates to:
  /// **'Tienes {names} en la despensa. '**
  String diaryQuotePantryNames(String names);

  /// No description provided for @diaryQuoteEnd.
  ///
  /// In es, this message translates to:
  /// **'Lo digo por si acaso.'**
  String get diaryQuoteEnd;

  /// No description provided for @diaryWhatsEaten.
  ///
  /// In es, this message translates to:
  /// **'¿Qué comiste?'**
  String get diaryWhatsEaten;

  /// No description provided for @diaryDeleteMealConfirm.
  ///
  /// In es, this message translates to:
  /// **'¿Eliminar {foodName} del diario?'**
  String diaryDeleteMealConfirm(String foodName);

  /// No description provided for @nlTitle.
  ///
  /// In es, this message translates to:
  /// **'Foto de la tabla nutricional'**
  String get nlTitle;

  /// No description provided for @nlCamera.
  ///
  /// In es, this message translates to:
  /// **'Cámara'**
  String get nlCamera;

  /// No description provided for @nlGallery.
  ///
  /// In es, this message translates to:
  /// **'Galería'**
  String get nlGallery;

  /// No description provided for @nlDetectedText.
  ///
  /// In es, this message translates to:
  /// **'Texto detectado'**
  String get nlDetectedText;

  /// No description provided for @nlSave.
  ///
  /// In es, this message translates to:
  /// **'Guardar en la despensa'**
  String get nlSave;

  /// No description provided for @nlPhotoHint.
  ///
  /// In es, this message translates to:
  /// **'Toma una foto de la tabla nutricional'**
  String get nlPhotoHint;

  /// No description provided for @nlName.
  ///
  /// In es, this message translates to:
  /// **'Nombre del producto'**
  String get nlName;

  /// No description provided for @nlQuantity.
  ///
  /// In es, this message translates to:
  /// **'Cantidad en la despensa'**
  String get nlQuantity;

  /// No description provided for @nlTableUnit.
  ///
  /// In es, this message translates to:
  /// **'Unidad tabla'**
  String get nlTableUnit;

  /// No description provided for @nlCalories.
  ///
  /// In es, this message translates to:
  /// **'Calorías'**
  String get nlCalories;

  /// No description provided for @nlProteins.
  ///
  /// In es, this message translates to:
  /// **'Proteínas'**
  String get nlProteins;

  /// No description provided for @nlCarbs.
  ///
  /// In es, this message translates to:
  /// **'Carbohidratos'**
  String get nlCarbs;

  /// No description provided for @nlFats.
  ///
  /// In es, this message translates to:
  /// **'Grasas'**
  String get nlFats;

  /// No description provided for @nlConfidenceDetected.
  ///
  /// In es, this message translates to:
  /// **'Detecté {percent}% de los macros. Revisa los valores antes de guardar.'**
  String nlConfidenceDetected(int percent);

  /// No description provided for @nlToastName.
  ///
  /// In es, this message translates to:
  /// **'Dale un nombre al producto'**
  String get nlToastName;

  /// No description provided for @nlToastGrams.
  ///
  /// In es, this message translates to:
  /// **'Cantidad en gramos inválida'**
  String get nlToastGrams;

  /// No description provided for @nlToastOneMacro.
  ///
  /// In es, this message translates to:
  /// **'Necesito al menos un macro'**
  String get nlToastOneMacro;

  /// No description provided for @nlToastReadError.
  ///
  /// In es, this message translates to:
  /// **'No pude leer la foto: {error}'**
  String nlToastReadError(String error);

  /// No description provided for @nlToastUpload.
  ///
  /// In es, this message translates to:
  /// **'No pude subir la foto, pero guardé el producto'**
  String get nlToastUpload;

  /// No description provided for @nlToastSaved.
  ///
  /// In es, this message translates to:
  /// **'\"{name}\" agregado a tu despensa'**
  String nlToastSaved(String name);

  /// No description provided for @notifThemeHeader.
  ///
  /// In es, this message translates to:
  /// **'TEMA'**
  String get notifThemeHeader;

  /// No description provided for @notifThemeDark.
  ///
  /// In es, this message translates to:
  /// **'Oscuro'**
  String get notifThemeDark;

  /// No description provided for @notifThemeLight.
  ///
  /// In es, this message translates to:
  /// **'Claro'**
  String get notifThemeLight;

  /// No description provided for @settingsLanguageHeader.
  ///
  /// In es, this message translates to:
  /// **'IDIOMA'**
  String get settingsLanguageHeader;

  /// No description provided for @settingsLanguageSystem.
  ///
  /// In es, this message translates to:
  /// **'Sistema'**
  String get settingsLanguageSystem;

  /// No description provided for @settingsLanguageSpanish.
  ///
  /// In es, this message translates to:
  /// **'Español'**
  String get settingsLanguageSpanish;

  /// No description provided for @settingsLanguageEnglish.
  ///
  /// In es, this message translates to:
  /// **'English'**
  String get settingsLanguageEnglish;

  /// No description provided for @notifMealReminders.
  ///
  /// In es, this message translates to:
  /// **'RECORDATORIOS DE COMIDA'**
  String get notifMealReminders;

  /// No description provided for @notifMealTimeHint.
  ///
  /// In es, this message translates to:
  /// **'Hora para registrar tu comida del día'**
  String get notifMealTimeHint;

  /// No description provided for @notifBreakfast.
  ///
  /// In es, this message translates to:
  /// **'Desayuno'**
  String get notifBreakfast;

  /// No description provided for @notifLunch.
  ///
  /// In es, this message translates to:
  /// **'Almuerzo'**
  String get notifLunch;

  /// No description provided for @notifSnack.
  ///
  /// In es, this message translates to:
  /// **'Merienda'**
  String get notifSnack;

  /// No description provided for @notifDinner.
  ///
  /// In es, this message translates to:
  /// **'Cena'**
  String get notifDinner;

  /// No description provided for @notifSaving.
  ///
  /// In es, this message translates to:
  /// **'Guardando...'**
  String get notifSaving;

  /// No description provided for @notifSaveSchedules.
  ///
  /// In es, this message translates to:
  /// **'Guardar horarios'**
  String get notifSaveSchedules;

  /// No description provided for @notifErrorUpdateConfig.
  ///
  /// In es, this message translates to:
  /// **'No se pudo actualizar la configuración.'**
  String get notifErrorUpdateConfig;

  /// No description provided for @notifErrorSaveSchedules.
  ///
  /// In es, this message translates to:
  /// **'No se pudo guardar los horarios. Intenta de nuevo.'**
  String get notifErrorSaveSchedules;

  /// No description provided for @notifSavedNotActivated.
  ///
  /// In es, this message translates to:
  /// **'Horarios guardados · no se pudieron activar las notificaciones'**
  String get notifSavedNotActivated;

  /// No description provided for @notifSavedActivated.
  ///
  /// In es, this message translates to:
  /// **'Horarios guardados · notificaciones activadas'**
  String get notifSavedActivated;

  /// No description provided for @notifSmartHeader.
  ///
  /// In es, this message translates to:
  /// **'NOTIFICACIONES INTELIGENTES'**
  String get notifSmartHeader;

  /// No description provided for @notifSmartTitle.
  ///
  /// In es, this message translates to:
  /// **'Consejos contextuales del gato'**
  String get notifSmartTitle;

  /// No description provided for @notifSmartSubtitle.
  ///
  /// In es, this message translates to:
  /// **'El gato te avisa a horas clave: si vas bajo de kcal (18:00), si se rompió la racha (19:00), si un producto lleva días en la despensa (20:00) y tus logros de proteína (21:00).'**
  String get notifSmartSubtitle;

  /// No description provided for @notifTestNotification.
  ///
  /// In es, this message translates to:
  /// **'Probar notificación (Debug)'**
  String get notifTestNotification;

  /// No description provided for @notifTestNotificationDesc.
  ///
  /// In es, this message translates to:
  /// **'Dispara una notificación con banner heads-up en 10 segundos'**
  String get notifTestNotificationDesc;

  /// No description provided for @notifAbout.
  ///
  /// In es, this message translates to:
  /// **'Acerca de NekoFit'**
  String get notifAbout;

  /// No description provided for @notifVersion.
  ///
  /// In es, this message translates to:
  /// **'Versión {version}'**
  String notifVersion(String version);

  /// No description provided for @notifResetTours.
  ///
  /// In es, this message translates to:
  /// **'Reiniciar tutoriales'**
  String get notifResetTours;

  /// No description provided for @notifResetToursDesc.
  ///
  /// In es, this message translates to:
  /// **'Vuelve a mostrar los tours del gato (Despensa y Diario)'**
  String get notifResetToursDesc;

  /// No description provided for @notifClose.
  ///
  /// In es, this message translates to:
  /// **'Cerrar'**
  String get notifClose;

  /// No description provided for @notifAboutTagline.
  ///
  /// In es, this message translates to:
  /// **'NekoFit · tu konbini personal de macros'**
  String get notifAboutTagline;

  /// No description provided for @notifLogout.
  ///
  /// In es, this message translates to:
  /// **'Cerrar sesión'**
  String get notifLogout;

  /// No description provided for @notifLogoutDesc.
  ///
  /// In es, this message translates to:
  /// **'Vuelve al inicio de sesión'**
  String get notifLogoutDesc;

  /// No description provided for @notifLogoutConfirmBody.
  ///
  /// In es, this message translates to:
  /// **'¿Seguro que quieres salir? Tu despensa y macros se quedan guardados en la nube.'**
  String get notifLogoutConfirmBody;

  /// No description provided for @notifLogoutConfirm.
  ///
  /// In es, this message translates to:
  /// **'Salir'**
  String get notifLogoutConfirm;

  /// No description provided for @notifTestSnackOk.
  ///
  /// In es, this message translates to:
  /// **'Notificación de prueba en 10s. Minimiza la app para ver el banner.'**
  String get notifTestSnackOk;

  /// No description provided for @notifTestSnackError.
  ///
  /// In es, this message translates to:
  /// **'Error al programar notificación de prueba: {error}'**
  String notifTestSnackError(String error);

  /// No description provided for @notifResetToursSnack.
  ///
  /// In es, this message translates to:
  /// **'Tutoriales reiniciados: Mochi te volverá a guiar.'**
  String get notifResetToursSnack;

  /// No description provided for @wardrobeMood.
  ///
  /// In es, this message translates to:
  /// **'HUMOR'**
  String get wardrobeMood;

  /// No description provided for @wardrobeFree.
  ///
  /// In es, this message translates to:
  /// **'Gratis'**
  String get wardrobeFree;

  /// No description provided for @wardrobeLocked.
  ///
  /// In es, this message translates to:
  /// **'BLOQUEADO'**
  String get wardrobeLocked;

  /// No description provided for @wardrobeEquipped.
  ///
  /// In es, this message translates to:
  /// **'EQUIPADO'**
  String get wardrobeEquipped;

  /// No description provided for @wardrobeInUse.
  ///
  /// In es, this message translates to:
  /// **'EN USO'**
  String get wardrobeInUse;

  /// No description provided for @wardrobeEquip.
  ///
  /// In es, this message translates to:
  /// **'EQUIPAR'**
  String get wardrobeEquip;

  /// No description provided for @wardrobeUnlockFree.
  ///
  /// In es, this message translates to:
  /// **'DESBLOQUEAR GRATIS'**
  String get wardrobeUnlockFree;

  /// No description provided for @wardrobeNotYet.
  ///
  /// In es, this message translates to:
  /// **'TODAVÍA NO'**
  String get wardrobeNotYet;

  /// No description provided for @wardrobeHint.
  ///
  /// In es, this message translates to:
  /// **'Toca y mantén para conocer la historia de cada prenda.'**
  String get wardrobeHint;

  /// No description provided for @wardrobeInYourWardrobe.
  ///
  /// In es, this message translates to:
  /// **'✔ En tu armario'**
  String get wardrobeInYourWardrobe;

  /// No description provided for @wardrobeUnlockFailed.
  ///
  /// In es, this message translates to:
  /// **'No pude desbloquearlo. Ni idea por qué.'**
  String get wardrobeUnlockFailed;

  /// No description provided for @wardrobeEquipLocked.
  ///
  /// In es, this message translates to:
  /// **'Primero desbloquéalo. No se puede usar lo que no tienes.'**
  String get wardrobeEquipLocked;

  /// No description provided for @wardrobeUnlockedSnack.
  ///
  /// In es, this message translates to:
  /// **'{outfitName} desbloqueado. No la presumas demasiado.'**
  String wardrobeUnlockedSnack(String outfitName);

  /// No description provided for @wardrobeProgressStreak.
  ///
  /// In es, this message translates to:
  /// **'Racha {current}/{value} días'**
  String wardrobeProgressStreak(int current, int value);

  /// No description provided for @wardrobeProgressLevel.
  ///
  /// In es, this message translates to:
  /// **'Nivel {current}/{total}'**
  String wardrobeProgressLevel(int current, int total);

  /// No description provided for @scanTitle.
  ///
  /// In es, this message translates to:
  /// **'ESCANEAR PRODUCTO'**
  String get scanTitle;

  /// No description provided for @scanPrompt.
  ///
  /// In es, this message translates to:
  /// **'Apunta al código de barras del producto'**
  String get scanPrompt;

  /// No description provided for @scanWaiting.
  ///
  /// In es, this message translates to:
  /// **'Esperando código de barras...'**
  String get scanWaiting;

  /// No description provided for @scanSearching.
  ///
  /// In es, this message translates to:
  /// **'Buscando producto...'**
  String get scanSearching;

  /// No description provided for @scanSearchButton.
  ///
  /// In es, this message translates to:
  /// **'Buscar'**
  String get scanSearchButton;

  /// No description provided for @scanSearchByName.
  ///
  /// In es, this message translates to:
  /// **'Buscar por nombre'**
  String get scanSearchByName;

  /// No description provided for @scanSearchProduct.
  ///
  /// In es, this message translates to:
  /// **'Buscar producto'**
  String get scanSearchProduct;

  /// No description provided for @scanSearchHint.
  ///
  /// In es, this message translates to:
  /// **'Ej: Quaker Avena Canela'**
  String get scanSearchHint;

  /// No description provided for @scanNoMacrosData.
  ///
  /// In es, this message translates to:
  /// **'Sin datos de macros'**
  String get scanNoMacrosData;

  /// No description provided for @scanNoMacrosBody.
  ///
  /// In es, this message translates to:
  /// **'El código {barcode} no tiene datos suficientes. Búscalo por nombre.'**
  String scanNoMacrosBody(String barcode);

  /// No description provided for @scanLabelPhoto.
  ///
  /// In es, this message translates to:
  /// **'Foto de tabla'**
  String get scanLabelPhoto;

  /// No description provided for @scanCodeDetected.
  ///
  /// In es, this message translates to:
  /// **'Código: {barcode}'**
  String scanCodeDetected(String barcode);

  /// No description provided for @scanGramsSnack.
  ///
  /// In es, this message translates to:
  /// **'¿Cuántos gramos agregas a la despensa?'**
  String get scanGramsSnack;

  /// No description provided for @scanProductAdded.
  ///
  /// In es, this message translates to:
  /// **'Producto agregado a la despensa'**
  String get scanProductAdded;

  /// No description provided for @scanPhotoCustom.
  ///
  /// In es, this message translates to:
  /// **'Foto personalizada lista'**
  String get scanPhotoCustom;

  /// No description provided for @scanPhotoOff.
  ///
  /// In es, this message translates to:
  /// **'Foto de Open Food Facts'**
  String get scanPhotoOff;

  /// No description provided for @scanPhotoNone.
  ///
  /// In es, this message translates to:
  /// **'Sin foto disponible'**
  String get scanPhotoNone;

  /// No description provided for @scanMacrosPer100ml.
  ///
  /// In es, this message translates to:
  /// **'Macros por cada 100 ml'**
  String get scanMacrosPer100ml;

  /// No description provided for @scanGramsHint.
  ///
  /// In es, this message translates to:
  /// **'Ej: 500'**
  String get scanGramsHint;

  /// No description provided for @scanAddToPantry.
  ///
  /// In es, this message translates to:
  /// **'Agregar a Despensa'**
  String get scanAddToPantry;

  /// No description provided for @prodEditTitle.
  ///
  /// In es, this message translates to:
  /// **'Editar producto'**
  String get prodEditTitle;

  /// No description provided for @prodUnit.
  ///
  /// In es, this message translates to:
  /// **'Unidad'**
  String get prodUnit;

  /// No description provided for @prodCategory.
  ///
  /// In es, this message translates to:
  /// **'Categoría'**
  String get prodCategory;

  /// No description provided for @prodPrice.
  ///
  /// In es, this message translates to:
  /// **'Precio (opcional)'**
  String get prodPrice;

  /// No description provided for @prodSave.
  ///
  /// In es, this message translates to:
  /// **'Guardar cambios'**
  String get prodSave;

  /// No description provided for @prodCompareSimilar.
  ///
  /// In es, this message translates to:
  /// **'Comparar con similares'**
  String get prodCompareSimilar;

  /// No description provided for @prodPhotoHint.
  ///
  /// In es, this message translates to:
  /// **'Agregar o cambiar foto del producto'**
  String get prodPhotoHint;

  /// No description provided for @prodUpdated.
  ///
  /// In es, this message translates to:
  /// **'Producto actualizado'**
  String get prodUpdated;

  /// No description provided for @prodDeleteTitle.
  ///
  /// In es, this message translates to:
  /// **'Eliminar producto'**
  String get prodDeleteTitle;

  /// No description provided for @prodDeleteConfirm.
  ///
  /// In es, this message translates to:
  /// **'¿Seguro que quieres sacar a \"{name}\" de tu despensa?'**
  String prodDeleteConfirm(String name);

  /// No description provided for @prodPhotoUploadError.
  ///
  /// In es, this message translates to:
  /// **'No pude subir la foto: {error}'**
  String prodPhotoUploadError(String error);

  /// No description provided for @prodMacroField.
  ///
  /// In es, this message translates to:
  /// **'{label} (por 100{unit})'**
  String prodMacroField(String label, String unit);

  /// No description provided for @peditPetSection.
  ///
  /// In es, this message translates to:
  /// **'MASCOTA VIRTUAL'**
  String get peditPetSection;

  /// No description provided for @peditGoalSection.
  ///
  /// In es, this message translates to:
  /// **'OBJETIVO FITNESS'**
  String get peditGoalSection;

  /// No description provided for @peditSavedSnack.
  ///
  /// In es, this message translates to:
  /// **'Perfil actualizado'**
  String get peditSavedSnack;

  /// No description provided for @peditMacrosTitle.
  ///
  /// In es, this message translates to:
  /// **'Tus macros diarios'**
  String get peditMacrosTitle;

  /// No description provided for @peditActivityPesasHit.
  ///
  /// In es, this message translates to:
  /// **'Pesas (HIIT / alta intensidad)'**
  String get peditActivityPesasHit;

  /// No description provided for @peditActivityPesasModerado.
  ///
  /// In es, this message translates to:
  /// **'Pesas (ritmo moderado)'**
  String get peditActivityPesasModerado;

  /// No description provided for @peditActivityCorrerModerado.
  ///
  /// In es, this message translates to:
  /// **'Correr (ritmo moderado)'**
  String get peditActivityCorrerModerado;

  /// No description provided for @peditActivityCorrerRapido.
  ///
  /// In es, this message translates to:
  /// **'Correr (ritmo rápido / intervalos)'**
  String get peditActivityCorrerRapido;

  /// No description provided for @peditActivityCaminar.
  ///
  /// In es, this message translates to:
  /// **'Caminar'**
  String get peditActivityCaminar;

  /// No description provided for @peditActivityCiclismo.
  ///
  /// In es, this message translates to:
  /// **'Ciclismo'**
  String get peditActivityCiclismo;

  /// No description provided for @statsTitle.
  ///
  /// In es, this message translates to:
  /// **'Estadísticas'**
  String get statsTitle;

  /// No description provided for @statsWeek.
  ///
  /// In es, this message translates to:
  /// **'Semana'**
  String get statsWeek;

  /// No description provided for @statsMonth.
  ///
  /// In es, this message translates to:
  /// **'Mes'**
  String get statsMonth;

  /// No description provided for @statsYear.
  ///
  /// In es, this message translates to:
  /// **'Año'**
  String get statsYear;

  /// No description provided for @statsError.
  ///
  /// In es, this message translates to:
  /// **'No se pudieron cargar tus estadísticas.'**
  String get statsError;

  /// No description provided for @statsPeriodSummary.
  ///
  /// In es, this message translates to:
  /// **'Resumen del período'**
  String get statsPeriodSummary;

  /// No description provided for @statsCalPerDay.
  ///
  /// In es, this message translates to:
  /// **'Cal/día'**
  String get statsCalPerDay;

  /// No description provided for @statsOnTargetDays.
  ///
  /// In es, this message translates to:
  /// **'Días on-target'**
  String get statsOnTargetDays;

  /// No description provided for @statsOnTargetUnit.
  ///
  /// In es, this message translates to:
  /// **'de {count}'**
  String statsOnTargetUnit(int count);

  /// No description provided for @statsCurrentStreak.
  ///
  /// In es, this message translates to:
  /// **'Racha actual'**
  String get statsCurrentStreak;

  /// No description provided for @statsDays.
  ///
  /// In es, this message translates to:
  /// **'días'**
  String get statsDays;

  /// No description provided for @statsNoRecords.
  ///
  /// In es, this message translates to:
  /// **'Sin registros en este período — registra una comida para ver tu tendencia'**
  String get statsNoRecords;

  /// No description provided for @statsYearSummary.
  ///
  /// In es, this message translates to:
  /// **'{days} días con registros en el año · meta {goal} kcal'**
  String statsYearSummary(int days, int goal);

  /// No description provided for @statsPeriodSummaryDetail.
  ///
  /// In es, this message translates to:
  /// **'{logged} de {total} días con registros · meta {goal} kcal'**
  String statsPeriodSummaryDetail(int logged, int total, int goal);

  /// No description provided for @statsCaloriesWeek.
  ///
  /// In es, this message translates to:
  /// **'Calorías esta semana'**
  String get statsCaloriesWeek;

  /// No description provided for @statsCaloriesMonth.
  ///
  /// In es, this message translates to:
  /// **'Calorías este mes'**
  String get statsCaloriesMonth;

  /// No description provided for @statsCaloriesYear.
  ///
  /// In es, this message translates to:
  /// **'Calorías este año'**
  String get statsCaloriesYear;

  /// No description provided for @statsGoal.
  ///
  /// In es, this message translates to:
  /// **'Meta'**
  String get statsGoal;

  /// No description provided for @statsRecentMeals.
  ///
  /// In es, this message translates to:
  /// **'Comidas recientes'**
  String get statsRecentMeals;

  /// No description provided for @statsWeekdayMon.
  ///
  /// In es, this message translates to:
  /// **'Lun'**
  String get statsWeekdayMon;

  /// No description provided for @statsWeekdayTue.
  ///
  /// In es, this message translates to:
  /// **'Mar'**
  String get statsWeekdayTue;

  /// No description provided for @statsWeekdayWed.
  ///
  /// In es, this message translates to:
  /// **'Mié'**
  String get statsWeekdayWed;

  /// No description provided for @statsWeekdayThu.
  ///
  /// In es, this message translates to:
  /// **'Jue'**
  String get statsWeekdayThu;

  /// No description provided for @statsWeekdayFri.
  ///
  /// In es, this message translates to:
  /// **'Vie'**
  String get statsWeekdayFri;

  /// No description provided for @statsWeekdaySat.
  ///
  /// In es, this message translates to:
  /// **'Sáb'**
  String get statsWeekdaySat;

  /// No description provided for @statsWeekdaySun.
  ///
  /// In es, this message translates to:
  /// **'Dom'**
  String get statsWeekdaySun;

  /// No description provided for @statsMonthJan.
  ///
  /// In es, this message translates to:
  /// **'Ene'**
  String get statsMonthJan;

  /// No description provided for @statsMonthFeb.
  ///
  /// In es, this message translates to:
  /// **'Feb'**
  String get statsMonthFeb;

  /// No description provided for @statsMonthMar.
  ///
  /// In es, this message translates to:
  /// **'Mar'**
  String get statsMonthMar;

  /// No description provided for @statsMonthApr.
  ///
  /// In es, this message translates to:
  /// **'Abr'**
  String get statsMonthApr;

  /// No description provided for @statsMonthMay.
  ///
  /// In es, this message translates to:
  /// **'May'**
  String get statsMonthMay;

  /// No description provided for @statsMonthJun.
  ///
  /// In es, this message translates to:
  /// **'Jun'**
  String get statsMonthJun;

  /// No description provided for @statsMonthJul.
  ///
  /// In es, this message translates to:
  /// **'Jul'**
  String get statsMonthJul;

  /// No description provided for @statsMonthAug.
  ///
  /// In es, this message translates to:
  /// **'Ago'**
  String get statsMonthAug;

  /// No description provided for @statsMonthSep.
  ///
  /// In es, this message translates to:
  /// **'Sep'**
  String get statsMonthSep;

  /// No description provided for @statsMonthOct.
  ///
  /// In es, this message translates to:
  /// **'Oct'**
  String get statsMonthOct;

  /// No description provided for @statsMonthNov.
  ///
  /// In es, this message translates to:
  /// **'Nov'**
  String get statsMonthNov;

  /// No description provided for @statsMonthDec.
  ///
  /// In es, this message translates to:
  /// **'Dic'**
  String get statsMonthDec;

  /// No description provided for @searchHint.
  ///
  /// In es, this message translates to:
  /// **'Ej: pechuga, arroz, manzana...'**
  String get searchHint;

  /// No description provided for @searchEmptyNoProducts.
  ///
  /// In es, this message translates to:
  /// **'No encontré productos en la búsqueda.\n¿Es un alimento fresco?'**
  String get searchEmptyNoProducts;

  /// No description provided for @searchAddManually.
  ///
  /// In es, this message translates to:
  /// **'Agregar manualmente'**
  String get searchAddManually;

  /// No description provided for @searchOrTakeLabelPhoto.
  ///
  /// In es, this message translates to:
  /// **'O tomar foto de la tabla'**
  String get searchOrTakeLabelPhoto;

  /// No description provided for @searchFreshSuggestions.
  ///
  /// In es, this message translates to:
  /// **'SUGERENCIAS DE FRESCOS'**
  String get searchFreshSuggestions;

  /// No description provided for @searchSupermarketProducts.
  ///
  /// In es, this message translates to:
  /// **'PRODUCTOS DE SUPERMERCADO'**
  String get searchSupermarketProducts;

  /// No description provided for @searchProduct.
  ///
  /// In es, this message translates to:
  /// **'Producto'**
  String get searchProduct;

  /// No description provided for @searchMacroKcal.
  ///
  /// In es, this message translates to:
  /// **'{kcal} kcal/100{unit}'**
  String searchMacroKcal(num kcal, String unit);

  /// No description provided for @searchMacroProtein.
  ///
  /// In es, this message translates to:
  /// **'P: {value}g/100{unit}'**
  String searchMacroProtein(String value, String unit);

  /// No description provided for @searchMacroCarbs.
  ///
  /// In es, this message translates to:
  /// **'C: {value}g/100{unit}'**
  String searchMacroCarbs(String value, String unit);

  /// No description provided for @searchMacroFats.
  ///
  /// In es, this message translates to:
  /// **'G: {value}g/100{unit}'**
  String searchMacroFats(String value, String unit);

  /// No description provided for @searchFreshMacros.
  ///
  /// In es, this message translates to:
  /// **'{calories} kcal · P: {proteins}g · C: {carbs}g · G: {fats}g'**
  String searchFreshMacros(
    num calories,
    String proteins,
    String carbs,
    String fats,
  );

  /// No description provided for @searchPhotoReady.
  ///
  /// In es, this message translates to:
  /// **'Foto lista para guardar.'**
  String get searchPhotoReady;

  /// No description provided for @searchPhotoFetchOnSave.
  ///
  /// In es, this message translates to:
  /// **'Traeré la foto de Open Food Facts al guardar.'**
  String get searchPhotoFetchOnSave;

  /// No description provided for @searchPhotoNoneAdd.
  ///
  /// In es, this message translates to:
  /// **'Sin foto. Toca el recuadro o usa los botones para añadir una.'**
  String get searchPhotoNoneAdd;

  /// No description provided for @searchAskName.
  ///
  /// In es, this message translates to:
  /// **'¿Cómo se llama este alimento?'**
  String get searchAskName;

  /// No description provided for @searchManualAdded.
  ///
  /// In es, this message translates to:
  /// **'{name} agregado a tu despensa'**
  String searchManualAdded(String name);

  /// No description provided for @searchAddFreshFood.
  ///
  /// In es, this message translates to:
  /// **'Agregar alimento fresco'**
  String get searchAddFreshFood;

  /// No description provided for @searchFoodName.
  ///
  /// In es, this message translates to:
  /// **'Nombre del alimento'**
  String get searchFoodName;

  /// No description provided for @searchFoodNameHint.
  ///
  /// In es, this message translates to:
  /// **'Ej: Pechuga de pollo, Banano, Arroz...'**
  String get searchFoodNameHint;

  /// No description provided for @searchSearchingImage.
  ///
  /// In es, this message translates to:
  /// **'Buscando imagen...'**
  String get searchSearchingImage;

  /// No description provided for @searchImageFoundOff.
  ///
  /// In es, this message translates to:
  /// **'Imagen encontrada en Open Food Facts'**
  String get searchImageFoundOff;

  /// No description provided for @searchUsingImageOff.
  ///
  /// In es, this message translates to:
  /// **'Usando imagen de Open Food Facts.'**
  String get searchUsingImageOff;

  /// No description provided for @searchCategory.
  ///
  /// In es, this message translates to:
  /// **'CATEGORÍA'**
  String get searchCategory;

  /// No description provided for @searchValuesPer100g.
  ///
  /// In es, this message translates to:
  /// **'VALORES POR 100g'**
  String get searchValuesPer100g;

  /// No description provided for @searchQuantityAdd.
  ///
  /// In es, this message translates to:
  /// **'Cantidad a agregar a la despensa'**
  String get searchQuantityAdd;

  /// No description provided for @planTitle.
  ///
  /// In es, this message translates to:
  /// **'Plan y despensa'**
  String get planTitle;

  /// No description provided for @planRegenerateTooltip.
  ///
  /// In es, this message translates to:
  /// **'Regenerar plan'**
  String get planRegenerateTooltip;

  /// No description provided for @planTabThisWeek.
  ///
  /// In es, this message translates to:
  /// **'Esta semana'**
  String get planTabThisWeek;

  /// No description provided for @planTabToBuy.
  ///
  /// In es, this message translates to:
  /// **'Para comprar'**
  String get planTabToBuy;

  /// No description provided for @planGenerating.
  ///
  /// In es, this message translates to:
  /// **'Generando plan con tu gato…'**
  String get planGenerating;

  /// No description provided for @planEmptyTitle.
  ///
  /// In es, this message translates to:
  /// **'Sin plan todavía'**
  String get planEmptyTitle;

  /// No description provided for @planEmptyMessage.
  ///
  /// In es, this message translates to:
  /// **'Pulsa el botón de refrescar para generar el plan con IA.'**
  String get planEmptyMessage;

  /// No description provided for @planWeekTitle.
  ///
  /// In es, this message translates to:
  /// **'Plan de la semana'**
  String get planWeekTitle;

  /// No description provided for @planAvgDaily.
  ///
  /// In es, this message translates to:
  /// **'{avg} kcal/día · meta {goal}'**
  String planAvgDaily(String avg, String goal);

  /// No description provided for @planWeekTotal.
  ///
  /// In es, this message translates to:
  /// **'{days} días · {total} kcal en total'**
  String planWeekTotal(int days, String total);

  /// No description provided for @planShoppingLoading.
  ///
  /// In es, this message translates to:
  /// **'Cruzando despensa, plan y predicciones…'**
  String get planShoppingLoading;

  /// No description provided for @planListEmptyTitle.
  ///
  /// In es, this message translates to:
  /// **'Lista vacía'**
  String get planListEmptyTitle;

  /// No description provided for @planListEmptyMessage.
  ///
  /// In es, this message translates to:
  /// **'Tu despensa está al día. Vuelve cuando algo se agote o se acerque.'**
  String get planListEmptyMessage;

  /// No description provided for @planRecalculate.
  ///
  /// In es, this message translates to:
  /// **'Recalcular'**
  String get planRecalculate;

  /// No description provided for @planSmartList.
  ///
  /// In es, this message translates to:
  /// **'Lista inteligente'**
  String get planSmartList;

  /// No description provided for @planMealsDone.
  ///
  /// In es, this message translates to:
  /// **'{done} / {total} hechas'**
  String planMealsDone(int done, int total);

  /// No description provided for @planRegenerated.
  ///
  /// In es, this message translates to:
  /// **'¡Plan regenerado!'**
  String get planRegenerated;

  /// No description provided for @planGenerateError.
  ///
  /// In es, this message translates to:
  /// **'No pude generar el plan: {error}'**
  String planGenerateError(String error);

  /// No description provided for @planMealDone.
  ///
  /// In es, this message translates to:
  /// **'Comida marcada como hecha.'**
  String get planMealDone;

  /// No description provided for @planMealUndone.
  ///
  /// In es, this message translates to:
  /// **'Comida desmarcada.'**
  String get planMealUndone;

  /// No description provided for @planReasonDepleted.
  ///
  /// In es, this message translates to:
  /// **'AGOTADO'**
  String get planReasonDepleted;

  /// No description provided for @planReasonCritical.
  ///
  /// In es, this message translates to:
  /// **'CRÍTICO'**
  String get planReasonCritical;

  /// No description provided for @planReasonPlan.
  ///
  /// In es, this message translates to:
  /// **'PLAN'**
  String get planReasonPlan;

  /// No description provided for @planReasonManual.
  ///
  /// In es, this message translates to:
  /// **'MANUAL'**
  String get planReasonManual;

  /// No description provided for @planDayMon.
  ///
  /// In es, this message translates to:
  /// **'LUN'**
  String get planDayMon;

  /// No description provided for @planDayTue.
  ///
  /// In es, this message translates to:
  /// **'MAR'**
  String get planDayTue;

  /// No description provided for @planDayWed.
  ///
  /// In es, this message translates to:
  /// **'MIÉ'**
  String get planDayWed;

  /// No description provided for @planDayThu.
  ///
  /// In es, this message translates to:
  /// **'JUE'**
  String get planDayThu;

  /// No description provided for @planDayFri.
  ///
  /// In es, this message translates to:
  /// **'VIE'**
  String get planDayFri;

  /// No description provided for @planDaySat.
  ///
  /// In es, this message translates to:
  /// **'SÁB'**
  String get planDaySat;

  /// No description provided for @planDaySun.
  ///
  /// In es, this message translates to:
  /// **'DOM'**
  String get planDaySun;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
