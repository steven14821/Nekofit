// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'NekoFit';

  @override
  String get tagline => 'Tu konbini personal';

  @override
  String get retry => 'Reintentar';

  @override
  String get authGateErrorTitle => 'No pudimos recuperar tu perfil';

  @override
  String get authGateErrorBody => 'Revisa tu conexión e inténtalo de nuevo.';

  @override
  String get navHome => 'Inicio';

  @override
  String get navPantry => 'Despensa';

  @override
  String get navDiary => 'Diario';

  @override
  String get navPet => 'Mascota';

  @override
  String get navProfile => 'Perfil';

  @override
  String get loginWelcome => '¡Hola de nuevo!';

  @override
  String get loginWelcomeSub => 'Tu racha y Mochi te esperan.';

  @override
  String get loginEmailLabel => 'CORREO ELECTRÓNICO';

  @override
  String get loginPasswordLabel => 'CONTRASEÑA';

  @override
  String get loginForgotPassword => '¿Olvidaste tu contraseña?';

  @override
  String get loginSignIn => 'INICIAR SESIÓN';

  @override
  String get loginOrContinueWith => 'O CONTINÚA CON';

  @override
  String get loginContinueGoogle => 'Continuar con Google';

  @override
  String get loginEmailErrorEmpty => 'Por favor ingresa tu correo electrónico';

  @override
  String get loginEmailErrorInvalid => 'Por favor ingresa un correo válido';

  @override
  String get loginPasswordErrorEmpty => 'Por favor ingresa tu contraseña';

  @override
  String get loginNoAccount => '¿No tienes cuenta? ';

  @override
  String get loginRegister => 'Regístrate aquí';

  @override
  String get loginGoogleFailed =>
      'No se pudo iniciar sesión con Google. Revisa tu conexión e inténtalo de nuevo.';

  @override
  String get forgotTitle => 'Recuperar Contraseña';

  @override
  String get forgotBody =>
      'Ingresa tu correo electrónico registrado y te enviaremos un enlace para restablecer tu contraseña.';

  @override
  String get emailLabel => 'Correo electrónico';

  @override
  String get emailEmpty => 'Ingresa tu correo';

  @override
  String get emailInvalid => 'Ingresa un correo válido';

  @override
  String get cancel => 'Cancelar';

  @override
  String get send => 'Enviar';

  @override
  String get resetEmailSent => 'Enlace de recuperación enviado con éxito.';

  @override
  String errorPrefix(String error) {
    return 'Error: $error';
  }

  @override
  String get onboardingSkip => 'OMITIR';

  @override
  String get onboardingTitle => '¿Qué vas a ganar?';

  @override
  String get onboardingSubtitle => '3 cosas que NekoFit hace por ti';

  @override
  String get onboardingSlide1Title => 'Registra tu despensa\nen 10 segundos';

  @override
  String get onboardingSlide1Subtitle =>
      'Escanea o escribe tus productos y NekoFit lleva el inventario por ti. Sabrás qué te falta antes de que se acabe.';

  @override
  String get onboardingSlide2Title =>
      'La IA identifica lo que\ncomes con una foto';

  @override
  String get onboardingSlide2Subtitle =>
      'Saca una foto a tu plato y la IA calcula calorías, proteínas, carbohidratos y grasas al instante. Sin pesadoras ni tablas.';

  @override
  String get onboardingSlide3Title => 'Tu mascota te obliga\na ser constante';

  @override
  String get onboardingSlide3Subtitle =>
      'Cada comida registrada alimenta a tu mascota. Sube de nivel, desbloquea outfits y cuida tu racha: la suya depende de la tuya.';

  @override
  String get start => 'EMPEZAR';

  @override
  String get next => 'SIGUIENTE';

  @override
  String get stepEssential => 'Lo esencial';

  @override
  String get stepPersonalize => 'Personaliza';

  @override
  String get stepExtreme => 'Extremo';

  @override
  String get essentialsTitle => 'Empieza en 30 segundos';

  @override
  String get essentialsBody =>
      'Tu género, edad, altura y peso bastan para calcular tu meta calórica al instante. Lo demás lo afinas después.';

  @override
  String get genderFemale => 'Femenino';

  @override
  String get genderMale => 'Masculino';

  @override
  String get ageField => 'Edad (años)';

  @override
  String get heightField => 'Altura (cm)';

  @override
  String get weightField => 'Peso actual (kg)';

  @override
  String get goalQuestion => '¿Cuál es tu objetivo?';

  @override
  String get customGoalLabel => 'Describe tu objetivo específico';

  @override
  String get customGoalHint =>
      'Ej. Incrementar resistencia para maratón de 10km';

  @override
  String get goalLoseWeight => 'Perder peso';

  @override
  String get goalLoseWeightDesc =>
      'Déficit calórico moderado, priorizando proteína para preservar músculo.';

  @override
  String get goalMaintainWeight => 'Mantener peso';

  @override
  String get goalMaintainWeightDesc =>
      'Equilibrio energético para sostener peso y recomposición corporal.';

  @override
  String get goalGainMuscle => 'Ganar músculo';

  @override
  String get goalGainMuscleDesc =>
      'Superávit controlado + proteína alta para hipertrofia.';

  @override
  String get goalCustom => 'Otro/Personalizado';

  @override
  String get goalCustomDesc =>
      'Si persigues metas atléticas específicas u objetivos clínicos.';

  @override
  String get recommendedDailyCalories => 'Calorías diarias recomendadas';

  @override
  String bmrFormula(String formula) {
    return 'Fórmula BMR: $formula';
  }

  @override
  String get bmrFormulaKatch => 'Katch-McArdle';

  @override
  String get bmrFormulaMifflin => 'Mifflin-St Jeor';

  @override
  String get macroCarbs => 'Carbohidratos';

  @override
  String get macroProteins => 'Proteínas';

  @override
  String get macroFats => 'Grasas';

  @override
  String get personalizeTitle => 'Personaliza tu plan';

  @override
  String get personalizeBody =>
      'Opcional: afina tu cálculo con % de grasa, tu actividad diaria y tu mascota.';

  @override
  String get bodyFatSection => '% de grasa corporal';

  @override
  String get bodyFatSectionHint =>
      'Permite usar la fórmula Katch-McArdle, mucho más precisa que las estándar.';

  @override
  String get lifestyleSection => 'Estilo de vida diario';

  @override
  String get lifestyleSectionHint =>
      '¿Qué haces la mayor parte del día, sin contar el entrenamiento?';

  @override
  String get trainingSection => 'Gasto por entrenamiento';

  @override
  String get trainingSectionHint =>
      'Sumamos kcal fijas según el tipo de actividad y los minutos por semana.';

  @override
  String get petSection => 'Conoce a tu mascota';

  @override
  String get petSectionHint =>
      'Asigna un nombre a tu compañero virtual de nutrición y cocina.';

  @override
  String get methodVisualTitle => 'Método visual';

  @override
  String get methodVisualDesc =>
      'Eliges tu rango con imágenes y descripciones.';

  @override
  String get methodNavyTitle => 'Método US Navy';

  @override
  String get methodNavyDesc =>
      'Cálculo real con cinta métrica (cuello, cintura, cadera).';

  @override
  String get myBodyFatEstimated => 'Tu % de grasa estimado';

  @override
  String get navyHintMale => 'La cintura debe ser mayor que el cuello.';

  @override
  String get navyHintFemale => 'Completa cuello, cintura, cadera y altura.';

  @override
  String get navyCalculated => 'Calculado por fórmula US Navy';

  @override
  String get neckField => 'Cuello (cm)';

  @override
  String get waistField => 'Cintura (cm)';

  @override
  String get hipField => 'Cadera (cm)';

  @override
  String get calculate => 'Calcular';

  @override
  String get lifestyleSedentary => 'Sedentario';

  @override
  String get lifestyleSedentaryDesc =>
      'Paso sentado la mayor parte del dia (estudio, oficina, programacion).';

  @override
  String get lifestyleActive => 'Activo';

  @override
  String get lifestyleActiveDesc =>
      'Trabajo de pie, caminas mucho o te mueves constantemente.';

  @override
  String get trainingActivityLabel => 'Tipo de actividad principal';

  @override
  String get weeklyMinutes => 'Minutos por semana';

  @override
  String minPerWeek(int minutes) {
    return '$minutes min/sem';
  }

  @override
  String minShort(int minutes) {
    return '$minutes min';
  }

  @override
  String get trainingKcalPerDay => 'kcal de entrenamiento / dia';

  @override
  String get chooseYourPet => 'Elige tu mascota';

  @override
  String get petCat => 'Gato';

  @override
  String get petDog1 => 'Perro 1';

  @override
  String get petDog2 => 'Perro 2';

  @override
  String get petNameLabel => 'Nombre de tu mascota';

  @override
  String get petNameHint => 'Ej. Mochi';

  @override
  String get customizeButton => 'Personalizar';

  @override
  String get stepExtremeContinue => 'Continuar';

  @override
  String get stepExtremeSkip => 'Saltar';

  @override
  String get extremeTitle => 'Personalización extrema';

  @override
  String get extremeBody =>
      'Dale a tu plan un plazo, ritmo y contexto reales: por cuántas semanas, si ayunas, y qué alimentos y condiciones respetar. Nuestro gato IA lo usará cada semana.';

  @override
  String get extremeEnableLabel => 'Crear plan con plazo';

  @override
  String get extremeEnableDesc =>
      'Actívalo para generar un plan de 4, 8 o 12 semanas que evoluciona contigo.';

  @override
  String get extremePhaseLabel => 'Fase del plan';

  @override
  String get extremePhaseCut => 'Perder peso';

  @override
  String get extremePhaseMaintain => 'Mantener peso';

  @override
  String get extremePhaseGain => 'Ganar músculo';

  @override
  String get extremePhaseRecomp => 'Recomposición';

  @override
  String get extremeDurationLabel => 'Duración';

  @override
  String get extremeW4 => '4 semanas';

  @override
  String get extremeW8 => '8 semanas';

  @override
  String get extremeW12 => '12 semanas';

  @override
  String get extremeMealsLabel => 'Comidas al día';

  @override
  String get extremeMealsHint =>
      'Afecta solo al plan semanal IA, no a tus macros.';

  @override
  String get extremeMeals3 => '3 comidas';

  @override
  String get extremeMeals4 => '4 comidas';

  @override
  String get extremeMeals5 => '5 comidas';

  @override
  String get extremeIfLabel => 'Ayuno intermitente';

  @override
  String get extremeIfDesc =>
      'La primera comida de la mañana queda fuera del plan.';

  @override
  String get extremeIf16 => '16:8';

  @override
  String get extremeIf18 => '18:6';

  @override
  String get extremeContextLabel => 'Tu contexto (opcional)';

  @override
  String get extremeContextHint =>
      'Este contexto viaja a cada plan semanal IA. Escribe separado por comas.';

  @override
  String get extremeMedicalLabel => 'Condiciones médicas';

  @override
  String get extremeMedicalHint =>
      'P. ej. resistencia a la insulina, hipertensión, hipotiroidismo…';

  @override
  String get extremeDietLabel => 'Preferencias / restricciones';

  @override
  String get extremeDietHint => 'P. ej. vegana, keto, sin gluten, sin lactosa…';

  @override
  String get extremeMustHaveLabel => 'Imprescindibles';

  @override
  String get extremeMustHaveHint =>
      'Alimentos que te encantan y NO quieres soltar (se incluyen casi a diario).';

  @override
  String get extremeAversionsLabel => 'Aversiones';

  @override
  String get extremeAversionsHint =>
      'Alimentos a evitar por completo en el plan.';

  @override
  String get extremeNotice =>
      'Tu fase redefine las calorías: con menos plazo el déficit es más agresivo, con más semanas es más suave. Al vencer el plan, NekoFit te sugerirá la siguiente fase antes de tocarte nada.';

  @override
  String get planExpiredTitle => 'Tu plan terminó';

  @override
  String get planExpiredSubtitle => 'Tu plan nutricional ha llegado a su fin.';

  @override
  String planExpiredBody(int weeks, String phase) {
    return 'Tu plan de $weeks semanas terminó. La siguiente fase sugerida es: $phase. ¿La aplicamos? Recalcularemos tus macros.';
  }

  @override
  String get planApprove => 'Aplicar';

  @override
  String get planSkip => 'Ahora no';

  @override
  String get planTransited =>
      '¡Fase aplicada! Nuevos macros calculados y nuevo plan activo.';

  @override
  String planTransitError(String error) {
    return 'No se pudo aplicar la fase: $error';
  }

  @override
  String get saveAndStart => 'Guardar y empezar';

  @override
  String get savePlanButton => 'Guardar plan';

  @override
  String get deletePlanButton => 'Eliminar plan';

  @override
  String get back => 'Atrás';

  @override
  String get snackEssentials =>
      'Completa edad, altura y peso para calcular tu meta al instante.';

  @override
  String get snackCustomGoal =>
      'Por favor describe tu objetivo fitness personalizado.';

  @override
  String get snackMeasures =>
      'Completa las medidas para calcular tu % de grasa.';

  @override
  String saveProfileError(String error) {
    return 'Error al guardar perfil: $error';
  }

  @override
  String get registerJoinTitle => 'Únete a NekoFit';

  @override
  String get registerJoinSub => 'Crea tu cuenta y abre tu despensa.';

  @override
  String get registerUsernameLabel => 'NOMBRE DE USUARIO';

  @override
  String get registerUsernameHint => 'tu_nombre';

  @override
  String get registerUsernameRequired =>
      'Por favor ingresa un nombre de usuario';

  @override
  String get registerUsernameMin =>
      'El nombre de usuario debe tener al menos 3 caracteres';

  @override
  String get registerEmailHint => 'tú@correo.com';

  @override
  String get registerPasswordHint => 'Mínimo 6 caracteres';

  @override
  String get registerPasswordMin =>
      'La contraseña debe tener al menos 6 caracteres';

  @override
  String get registerCreateAccount => 'CREAR CUENTA';

  @override
  String get registerHaveAccount => '¿Ya tienes cuenta? ';

  @override
  String get registerSignIn => 'Inicia sesión';

  @override
  String homeHello(String name) {
    return 'Hola, $name';
  }

  @override
  String get homeDefaultUser => 'Usuario';

  @override
  String get moodHappy => 'FELIZ';

  @override
  String get moodFull => 'LLENO';

  @override
  String get moodHungry => 'HAMBRE';

  @override
  String get moodOk => 'OK';

  @override
  String get catTipHappy1 =>
      '¡Increíble! Has comido bien hoy. Yo también estoy contento. Casi.';

  @override
  String get catTipHappy2 => 'Mochi aprueba tu dieta. Por una vez.';

  @override
  String get catTipHappy3 => '¿De verdad comiste tan bien? Sospechoso.';

  @override
  String get catTipOk1 =>
      'Todo bien por ahora… pero eso puede cambiar si no registras tu almuerzo.';

  @override
  String get catTipOk2 =>
      'Ni bien ni mal. Mediocre, como tu café de esta mañana.';

  @override
  String get catTipOk3 =>
      'Tengo un ojo en tu despensa. El otro está durmiendo.';

  @override
  String get catTipFull1 =>
      '¿Cuándo fue la última vez que me diste de comer? Pregunto para un amigo.';

  @override
  String get catTipFull2 => 'Registro atrasado. El gato no olvida.';

  @override
  String get catTipFull3 =>
      'Mi panza dice que llevas tiempo sin pasar por el diario.';

  @override
  String get catTipAngry1 => 'HAMBRE. EXTREMA. Registra algo. YA.';

  @override
  String get catTipAngry2 =>
      'Cero comidas registradas hoy. Cero. Nada. Vacío total.';

  @override
  String get catTipAngry3 =>
      '¿Estás comiendo? Porque yo no lo veo. Registra tu comida.';

  @override
  String get dashMacroProtein => 'PROTEÍNA';

  @override
  String get dashMacroCarbs => 'CARBOS';

  @override
  String get dashMacroFats => 'GRASAS';

  @override
  String get homeInPantry => 'En despensa';

  @override
  String get homeDepleted => 'Agotados';

  @override
  String get homeMealsToday => 'Comidas hoy';

  @override
  String get stepsToday => 'Pasos hoy';

  @override
  String get stepsPermissionDenied => 'Permiso de Health Connect denegado.';

  @override
  String get stepsLink => 'Vincular';

  @override
  String get homeQuickAction => 'Acción rápida';

  @override
  String get homeViewAll => 'VER TODO →';

  @override
  String get homeScanMeal => 'Analizar plato';

  @override
  String get homeScanMealHint => 'FOTO → IA';

  @override
  String get homeRestock => 'Reabastecer';

  @override
  String get homeRestockHint => 'DESDE AGOTADOS';

  @override
  String get homeWeeklyProgress => 'Ver progreso semanal';

  @override
  String get homePlanTitle => 'Mi plan nutricional';

  @override
  String get homePlanEmptyTitle => 'Crea tu plan nutricional';

  @override
  String get homePlanEditHint =>
      'Toca para editar tu fase, plazo y comidas. También puedes volver al ritmo clásico.';

  @override
  String get homePlanEmptyHint =>
      'Personalización extrema: fase, duración y hábitos. Afecta tus macros y tu plan semanal.';

  @override
  String planCardProgress(int daysLeft, int totalDays) {
    return '$daysLeft / $totalDays días';
  }

  @override
  String get planCardWeeks => 'semanas';

  @override
  String get planSavedNotice => 'Plan guardado';

  @override
  String ticketNote(String catName) {
    return 'Nota de $catName';
  }

  @override
  String ticketMood(String label) {
    return 'MOOD: $label';
  }

  @override
  String get ticketFed => 'ALIMENTADO';

  @override
  String get ticketFasting => 'EN AYUNAS';

  @override
  String ticketDeducted(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Se descontaron $count ítems de la despensa hoy.',
      one: 'Se descontó 1 ítem de la despensa hoy.',
    );
    return '$_temp0';
  }

  @override
  String get categoryProteins => 'Proteínas';

  @override
  String get categoryCarbs => 'Carbohidratos';

  @override
  String get categoryFats => 'Grasas';

  @override
  String get categoryVegetables => 'Vegetales';

  @override
  String get categoryDairyEggs => 'Lácteos/Huevos';

  @override
  String get pantryCalendarTooltip => 'Plan semanal y lista de compras';

  @override
  String get pantryDailyGoal => 'META DIARIA';

  @override
  String get pantryToday => '¡Hoy!';

  @override
  String get pantryEmptyTitle => 'Tu despensa está vacía';

  @override
  String get pantryEmptyBody =>
      'Escanea tu primer producto y tu despensa cobrará vida.';

  @override
  String get pantryEmptyScan => 'Escanear tu primer producto';

  @override
  String get pantryEmptySearch => 'Buscar alimento';

  @override
  String get pantryInStock => 'EN EXISTENCIA';

  @override
  String get pantryDepleted => 'AGOTADOS';

  @override
  String pantryEmptyCategory(String category) {
    return 'No hay productos en $category';
  }

  @override
  String pantryItemReplenished(String name) {
    return '$name reabastecido';
  }

  @override
  String pantryItemDepleted(String name) {
    return '$name marcado como agotado';
  }

  @override
  String get pantryCatNameTitle => 'Nombra a tu mascota';

  @override
  String get pantryCatNameBody =>
      'Asigna un nombre a tu compañero virtual para personalizar tu experiencia.';

  @override
  String get pantryCatNameLabel => 'Nombre de la mascota';

  @override
  String get pantrySaveName => 'Guardar nombre';

  @override
  String get tourPantry1Title => 'Tu despensa';

  @override
  String get tourPantry1Empty =>
      'Está vacía por ahora. Escanea tu primer producto para llenarla y empezar a controlar tus macros.';

  @override
  String get tourPantry1Full =>
      'Aquí viven tus productos. Toca una pestaña para cambiar de anaquel (categoría).';

  @override
  String get tourPantry2EmptyTitle => 'Buscar sin escanear';

  @override
  String get tourPantry2Empty =>
      'Si ya sabes qué quieres, búscalo por nombre y añádelo a tu despensa sin escanear.';

  @override
  String get tourPantry2FullTitle => 'Reabastecer al toque';

  @override
  String get tourPantry2Full =>
      'En \"Agotados\" basta un toque sobre el sello para reactivar un producto.';

  @override
  String get tourPantry3Title => 'Plan y lista';

  @override
  String get tourPantry3 =>
      'Pulsa el icono del calendario (arriba a la derecha) para ver tu plan semanal y la lista de compras inteligente.';

  @override
  String get petTitle => 'Tu Mascota';

  @override
  String get petWardrobeTooltip => 'Vestidor';

  @override
  String petMoodLabel(String mood) {
    return 'HUMOR · $mood';
  }

  @override
  String get petHunger => 'HAMBRE';

  @override
  String petHungerCritical(String catName) {
    return '$catName está hambriento. Dale de comer pronto.';
  }

  @override
  String get petHungerLow => 'Más bajo es mejor. 0% = satisfecho.';

  @override
  String get petLevel => 'NIVEL';

  @override
  String petLevelValue(int level) {
    return 'Lv $level';
  }

  @override
  String get petStreak => 'RACHA';

  @override
  String petStreakDays(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'días',
      one: 'día',
    );
    return '$_temp0';
  }

  @override
  String get petFeed => 'DAR DE COMER';

  @override
  String get petWardrobe => 'VESTIDOR';

  @override
  String petExpectingFood(String catName) {
    return '$catName esperaba algo de comer…';
  }

  @override
  String petObserving(String catName, num xp) {
    return '$catName te observa · XP total $xp';
  }

  @override
  String get profileTitle => 'Mi Perfil';

  @override
  String get profileSettings => 'Configuración';

  @override
  String get profileAge => 'Edad';

  @override
  String get profileYears => 'años';

  @override
  String get profileWeight => 'Peso';

  @override
  String get profileHeight => 'Altura';

  @override
  String get profileBodyFat => 'Grasa';

  @override
  String get profileDailyMacros => 'MARCOS DIARIOS';

  @override
  String get profileCalories => 'Calorías';

  @override
  String get profileProtein => 'Proteína';

  @override
  String get profileCarbs => 'Carbos';

  @override
  String get profileFats => 'Grasas';

  @override
  String get profileData => 'DATOS';

  @override
  String get profileGender => 'Género';

  @override
  String get profileLifestyle => 'Estilo de vida';

  @override
  String get profileTraining => 'Entrenamiento';

  @override
  String get profileMinutesPerWeek => 'Minutos/semana';

  @override
  String get profileBmrFormula => 'Fórmula BMR';

  @override
  String get profileEdit => 'Editar perfil';

  @override
  String get profileEditDesc => 'Peso, altura, grasa corporal, objetivo';

  @override
  String get profileStats => 'Estadísticas y progreso';

  @override
  String get profileStatsDesc => 'Resumen semanal, calorías y comidas';

  @override
  String get profileRecalc => 'Recalcular macros';

  @override
  String get profileRecalcDesc => 'Volver a calcular según tus datos actuales';

  @override
  String get diaryTitle => 'Tu diario';

  @override
  String get diarySubtitle => 'ALIMENTARIO';

  @override
  String get diaryToday => 'HOY';

  @override
  String get diaryBackToToday => 'VOLVER A HOY';

  @override
  String get diaryDayTotal => 'TOTAL DEL DÍA';

  @override
  String get diarySummary => 'RESUMEN DEL DÍA';

  @override
  String get diaryAdd => 'Añadir';

  @override
  String get diaryAddSnack => 'Comida agregada';

  @override
  String diaryEmptySlot(String catName) {
    return 'Sin registrar. $catName está mirando.';
  }

  @override
  String diaryItemsDeducted(int count) {
    return 'ÍTEMS DESCONTADOS: $count';
  }

  @override
  String get diaryMealTypeLabel => 'TIPO DE COMIDA';

  @override
  String get diaryQuantityLabel => 'CANTIDAD';

  @override
  String get diaryEditMeal => 'Editar comida';

  @override
  String get diaryDeleteMeal => 'Eliminar comida';

  @override
  String get diaryDeleteConfirm => 'Eliminar';

  @override
  String get diaryEditSnackOk => 'Comida actualizada';

  @override
  String get diaryEditSnackPartial =>
      'Comida actualizada, pero no se pudo ajustar la despensa. Revísala.';

  @override
  String get diaryDeleteSnackOk => 'Comida eliminada';

  @override
  String get diaryDeleteSnackPartial =>
      'Comida eliminada, pero no se pudo devolver el producto a la despensa.';

  @override
  String get diarySave => 'Guardar';

  @override
  String get diarySaving => 'Guardando…';

  @override
  String get diaryTour1 => 'Tu diario';

  @override
  String get diaryTour1Msg =>
      'Cambia de día con las flechas. Cada comida queda guardada en la fecha en que la registras.';

  @override
  String get diaryTour2 => 'Resumen del día';

  @override
  String get diaryTour2Msg =>
      'Aquí viven tus kcal y macros acumuladas. La meta se toma de tu perfil.';

  @override
  String get diaryTour3 => 'Registrar comida';

  @override
  String get diaryTour3Msg =>
      'Pulsa \"Añadir\" (o el +) para registrar una comida desde la despensa o con el escáner.';

  @override
  String get diaryFasting => 'EN AYUNAS';

  @override
  String get diaryQuoteNothing => 'Nada registrado hoy. ';

  @override
  String diaryQuoteMeals(int count) {
    return '$count de 4 comidas. ';
  }

  @override
  String diaryQuoteRemainingKcal(num kcal) {
    return 'Te faltan $kcal kcal';
  }

  @override
  String diaryQuoteRemainingPro(num pro) {
    return ' y $pro g de proteína';
  }

  @override
  String get diaryQuoteMet => 'Objetivo cumplido. ';

  @override
  String get diaryQuotePantryEmpty => 'Tu despensa está vacía. ';

  @override
  String diaryQuotePantryNames(String names) {
    return 'Tienes $names en la despensa. ';
  }

  @override
  String get diaryQuoteEnd => 'Lo digo por si acaso.';

  @override
  String get diaryWhatsEaten => '¿Qué comiste?';

  @override
  String diaryDeleteMealConfirm(String foodName) {
    return '¿Eliminar $foodName del diario?';
  }

  @override
  String get nlTitle => 'Foto de la tabla nutricional';

  @override
  String get nlCamera => 'Cámara';

  @override
  String get nlGallery => 'Galería';

  @override
  String get nlDetectedText => 'Texto detectado';

  @override
  String get nlSave => 'Guardar en la despensa';

  @override
  String get nlPhotoHint => 'Toma una foto de la tabla nutricional';

  @override
  String get nlName => 'Nombre del producto';

  @override
  String get nlQuantity => 'Cantidad en la despensa';

  @override
  String get nlTableUnit => 'Unidad tabla';

  @override
  String get nlCalories => 'Calorías';

  @override
  String get nlProteins => 'Proteínas';

  @override
  String get nlCarbs => 'Carbohidratos';

  @override
  String get nlFats => 'Grasas';

  @override
  String nlConfidenceDetected(int percent) {
    return 'Detecté $percent% de los macros. Revisa los valores antes de guardar.';
  }

  @override
  String get nlToastName => 'Dale un nombre al producto';

  @override
  String get nlToastGrams => 'Cantidad en gramos inválida';

  @override
  String get nlToastOneMacro => 'Necesito al menos un macro';

  @override
  String nlToastReadError(String error) {
    return 'No pude leer la foto: $error';
  }

  @override
  String get nlToastUpload => 'No pude subir la foto, pero guardé el producto';

  @override
  String nlToastSaved(String name) {
    return '\"$name\" agregado a tu despensa';
  }

  @override
  String get notifThemeHeader => 'TEMA';

  @override
  String get notifThemeDark => 'Oscuro';

  @override
  String get notifThemeLight => 'Claro';

  @override
  String get settingsLanguageHeader => 'IDIOMA';

  @override
  String get settingsLanguageSystem => 'Sistema';

  @override
  String get settingsLanguageSpanish => 'Español';

  @override
  String get settingsLanguageEnglish => 'English';

  @override
  String get notifMealReminders => 'RECORDATORIOS DE COMIDA';

  @override
  String get notifMealTimeHint => 'Hora para registrar tu comida del día';

  @override
  String get notifBreakfast => 'Desayuno';

  @override
  String get notifLunch => 'Almuerzo';

  @override
  String get notifSnack => 'Merienda';

  @override
  String get notifDinner => 'Cena';

  @override
  String get notifSaving => 'Guardando...';

  @override
  String get notifSaveSchedules => 'Guardar horarios';

  @override
  String get notifErrorUpdateConfig =>
      'No se pudo actualizar la configuración.';

  @override
  String get notifErrorSaveSchedules =>
      'No se pudo guardar los horarios. Intenta de nuevo.';

  @override
  String get notifSavedNotActivated =>
      'Horarios guardados · no se pudieron activar las notificaciones';

  @override
  String get notifSavedActivated =>
      'Horarios guardados · notificaciones activadas';

  @override
  String get notifSmartHeader => 'NOTIFICACIONES INTELIGENTES';

  @override
  String get notifSmartTitle => 'Consejos contextuales del gato';

  @override
  String get notifSmartSubtitle =>
      'El gato te avisa a horas clave: si vas bajo de kcal (18:00), si se rompió la racha (19:00), si un producto lleva días en la despensa (20:00) y tus logros de proteína (21:00).';

  @override
  String get notifTestNotification => 'Probar notificación (Debug)';

  @override
  String get notifTestNotificationDesc =>
      'Dispara una notificación con banner heads-up en 10 segundos';

  @override
  String get notifAbout => 'Acerca de NekoFit';

  @override
  String notifVersion(String version) {
    return 'Versión $version';
  }

  @override
  String get notifResetTours => 'Reiniciar tutoriales';

  @override
  String get notifResetToursDesc =>
      'Vuelve a mostrar los tours del gato (Despensa y Diario)';

  @override
  String get notifClose => 'Cerrar';

  @override
  String get notifAboutTagline => 'NekoFit · tu konbini personal de macros';

  @override
  String get notifLogout => 'Cerrar sesión';

  @override
  String get notifLogoutDesc => 'Vuelve al inicio de sesión';

  @override
  String get notifLogoutConfirmBody =>
      '¿Seguro que quieres salir? Tu despensa y macros se quedan guardados en la nube.';

  @override
  String get notifLogoutConfirm => 'Salir';

  @override
  String get notifTestSnackOk =>
      'Notificación de prueba en 10s. Minimiza la app para ver el banner.';

  @override
  String notifTestSnackError(String error) {
    return 'Error al programar notificación de prueba: $error';
  }

  @override
  String get notifResetToursSnack =>
      'Tutoriales reiniciados: Mochi te volverá a guiar.';

  @override
  String get wardrobeMood => 'HUMOR';

  @override
  String get wardrobeFree => 'Gratis';

  @override
  String get wardrobeLocked => 'BLOQUEADO';

  @override
  String get wardrobeEquipped => 'EQUIPADO';

  @override
  String get wardrobeInUse => 'EN USO';

  @override
  String get wardrobeEquip => 'EQUIPAR';

  @override
  String get wardrobeUnlockFree => 'DESBLOQUEAR GRATIS';

  @override
  String get wardrobeNotYet => 'TODAVÍA NO';

  @override
  String get wardrobeHint =>
      'Toca y mantén para conocer la historia de cada prenda.';

  @override
  String get wardrobeInYourWardrobe => '✔ En tu armario';

  @override
  String get wardrobeUnlockFailed => 'No pude desbloquearlo. Ni idea por qué.';

  @override
  String get wardrobeEquipLocked =>
      'Primero desbloquéalo. No se puede usar lo que no tienes.';

  @override
  String wardrobeUnlockedSnack(String outfitName) {
    return '$outfitName desbloqueado. No la presumas demasiado.';
  }

  @override
  String wardrobeProgressStreak(int current, int value) {
    return 'Racha $current/$value días';
  }

  @override
  String wardrobeProgressLevel(int current, int total) {
    return 'Nivel $current/$total';
  }

  @override
  String get scanTitle => 'ESCANEAR PRODUCTO';

  @override
  String get scanPrompt => 'Apunta al código de barras del producto';

  @override
  String get scanWaiting => 'Esperando código de barras...';

  @override
  String get scanSearching => 'Buscando producto...';

  @override
  String get scanSearchButton => 'Buscar';

  @override
  String get scanSearchByName => 'Buscar por nombre';

  @override
  String get scanSearchProduct => 'Buscar producto';

  @override
  String get scanSearchHint => 'Ej: Quaker Avena Canela';

  @override
  String get scanNoMacrosData => 'Sin datos de macros';

  @override
  String scanNoMacrosBody(String barcode) {
    return 'El código $barcode no tiene datos suficientes. Búscalo por nombre.';
  }

  @override
  String get scanLabelPhoto => 'Foto de tabla';

  @override
  String scanCodeDetected(String barcode) {
    return 'Código: $barcode';
  }

  @override
  String get scanGramsSnack => '¿Cuántos gramos agregas a la despensa?';

  @override
  String get scanProductAdded => 'Producto agregado a la despensa';

  @override
  String get scanPhotoCustom => 'Foto personalizada lista';

  @override
  String get scanPhotoOff => 'Foto de Open Food Facts';

  @override
  String get scanPhotoNone => 'Sin foto disponible';

  @override
  String get scanMacrosPer100ml => 'Macros por cada 100 ml';

  @override
  String get scanGramsHint => 'Ej: 500';

  @override
  String get scanAddToPantry => 'Agregar a Despensa';

  @override
  String get prodEditTitle => 'Editar producto';

  @override
  String get prodUnit => 'Unidad';

  @override
  String get prodCategory => 'Categoría';

  @override
  String get prodPrice => 'Precio (opcional)';

  @override
  String get prodSave => 'Guardar cambios';

  @override
  String get prodCompareSimilar => 'Comparar con similares';

  @override
  String get prodPhotoHint => 'Agregar o cambiar foto del producto';

  @override
  String get prodUpdated => 'Producto actualizado';

  @override
  String get prodDeleteTitle => 'Eliminar producto';

  @override
  String prodDeleteConfirm(String name) {
    return '¿Seguro que quieres sacar a \"$name\" de tu despensa?';
  }

  @override
  String prodPhotoUploadError(String error) {
    return 'No pude subir la foto: $error';
  }

  @override
  String prodMacroField(String label, String unit) {
    return '$label (por 100$unit)';
  }

  @override
  String get peditPetSection => 'MASCOTA VIRTUAL';

  @override
  String get peditGoalSection => 'OBJETIVO FITNESS';

  @override
  String get peditSavedSnack => 'Perfil actualizado';

  @override
  String get peditMacrosTitle => 'Tus macros diarios';

  @override
  String get peditActivityPesasHit => 'Pesas (HIIT / alta intensidad)';

  @override
  String get peditActivityPesasModerado => 'Pesas (ritmo moderado)';

  @override
  String get peditActivityCorrerModerado => 'Correr (ritmo moderado)';

  @override
  String get peditActivityCorrerRapido => 'Correr (ritmo rápido / intervalos)';

  @override
  String get peditActivityCaminar => 'Caminar';

  @override
  String get peditActivityCiclismo => 'Ciclismo';

  @override
  String get statsTitle => 'Estadísticas';

  @override
  String get statsWeek => 'Semana';

  @override
  String get statsMonth => 'Mes';

  @override
  String get statsYear => 'Año';

  @override
  String get statsError => 'No se pudieron cargar tus estadísticas.';

  @override
  String get statsPeriodSummary => 'Resumen del período';

  @override
  String get statsCalPerDay => 'Cal/día';

  @override
  String get statsOnTargetDays => 'Días on-target';

  @override
  String statsOnTargetUnit(int count) {
    return 'de $count';
  }

  @override
  String get statsCurrentStreak => 'Racha actual';

  @override
  String get statsDays => 'días';

  @override
  String get statsNoRecords =>
      'Sin registros en este período — registra una comida para ver tu tendencia';

  @override
  String statsYearSummary(int days, int goal) {
    return '$days días con registros en el año · meta $goal kcal';
  }

  @override
  String statsPeriodSummaryDetail(int logged, int total, int goal) {
    return '$logged de $total días con registros · meta $goal kcal';
  }

  @override
  String get statsCaloriesWeek => 'Calorías esta semana';

  @override
  String get statsCaloriesMonth => 'Calorías este mes';

  @override
  String get statsCaloriesYear => 'Calorías este año';

  @override
  String get statsGoal => 'Meta';

  @override
  String get statsRecentMeals => 'Comidas recientes';

  @override
  String get statsWeekdayMon => 'Lun';

  @override
  String get statsWeekdayTue => 'Mar';

  @override
  String get statsWeekdayWed => 'Mié';

  @override
  String get statsWeekdayThu => 'Jue';

  @override
  String get statsWeekdayFri => 'Vie';

  @override
  String get statsWeekdaySat => 'Sáb';

  @override
  String get statsWeekdaySun => 'Dom';

  @override
  String get statsMonthJan => 'Ene';

  @override
  String get statsMonthFeb => 'Feb';

  @override
  String get statsMonthMar => 'Mar';

  @override
  String get statsMonthApr => 'Abr';

  @override
  String get statsMonthMay => 'May';

  @override
  String get statsMonthJun => 'Jun';

  @override
  String get statsMonthJul => 'Jul';

  @override
  String get statsMonthAug => 'Ago';

  @override
  String get statsMonthSep => 'Sep';

  @override
  String get statsMonthOct => 'Oct';

  @override
  String get statsMonthNov => 'Nov';

  @override
  String get statsMonthDec => 'Dic';

  @override
  String get searchHint => 'Ej: pechuga, arroz, manzana...';

  @override
  String get searchEmptyNoProducts =>
      'No encontré productos en la búsqueda.\n¿Es un alimento fresco?';

  @override
  String get searchAddManually => 'Agregar manualmente';

  @override
  String get searchOrTakeLabelPhoto => 'O tomar foto de la tabla';

  @override
  String get searchFreshSuggestions => 'SUGERENCIAS DE FRESCOS';

  @override
  String get searchSupermarketProducts => 'PRODUCTOS DE SUPERMERCADO';

  @override
  String get searchProduct => 'Producto';

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
    return 'G: ${value}g/100$unit';
  }

  @override
  String searchFreshMacros(
    num calories,
    String proteins,
    String carbs,
    String fats,
  ) {
    return '$calories kcal · P: ${proteins}g · C: ${carbs}g · G: ${fats}g';
  }

  @override
  String get searchPhotoReady => 'Foto lista para guardar.';

  @override
  String get searchPhotoFetchOnSave =>
      'Traeré la foto de Open Food Facts al guardar.';

  @override
  String get searchPhotoNoneAdd =>
      'Sin foto. Toca el recuadro o usa los botones para añadir una.';

  @override
  String get searchAskName => '¿Cómo se llama este alimento?';

  @override
  String searchManualAdded(String name) {
    return '$name agregado a tu despensa';
  }

  @override
  String get searchAddFreshFood => 'Agregar alimento fresco';

  @override
  String get searchFoodName => 'Nombre del alimento';

  @override
  String get searchFoodNameHint => 'Ej: Pechuga de pollo, Banano, Arroz...';

  @override
  String get searchSearchingImage => 'Buscando imagen...';

  @override
  String get searchImageFoundOff => 'Imagen encontrada en Open Food Facts';

  @override
  String get searchUsingImageOff => 'Usando imagen de Open Food Facts.';

  @override
  String get searchCategory => 'CATEGORÍA';

  @override
  String get searchValuesPer100g => 'VALORES POR 100g';

  @override
  String get searchQuantityAdd => 'Cantidad a agregar a la despensa';

  @override
  String get planTitle => 'Plan y despensa';

  @override
  String get planRegenerateTooltip => 'Regenerar plan';

  @override
  String get planTabThisWeek => 'Esta semana';

  @override
  String get planTabToBuy => 'Para comprar';

  @override
  String get planGenerating => 'Generando plan con tu gato…';

  @override
  String get planEmptyTitle => 'Sin plan todavía';

  @override
  String get planEmptyMessage =>
      'Pulsa el botón de refrescar para generar el plan con IA.';

  @override
  String get planWeekTitle => 'Plan de la semana';

  @override
  String planAvgDaily(String avg, String goal) {
    return '$avg kcal/día · meta $goal';
  }

  @override
  String planWeekTotal(int days, String total) {
    return '$days días · $total kcal en total';
  }

  @override
  String get planShoppingLoading => 'Cruzando despensa, plan y predicciones…';

  @override
  String get planListEmptyTitle => 'Lista vacía';

  @override
  String get planListEmptyMessage =>
      'Tu despensa está al día. Vuelve cuando algo se agote o se acerque.';

  @override
  String get planRecalculate => 'Recalcular';

  @override
  String get planSmartList => 'Lista inteligente';

  @override
  String planMealsDone(int done, int total) {
    return '$done / $total hechas';
  }

  @override
  String get planRegenerated => '¡Plan regenerado!';

  @override
  String planGenerateError(String error) {
    return 'No pude generar el plan: $error';
  }

  @override
  String get planMealDone => 'Comida marcada como hecha.';

  @override
  String get planMealUndone => 'Comida desmarcada.';

  @override
  String get planReasonDepleted => 'AGOTADO';

  @override
  String get planReasonCritical => 'CRÍTICO';

  @override
  String get planReasonPlan => 'PLAN';

  @override
  String get planReasonManual => 'MANUAL';

  @override
  String get planDayMon => 'LUN';

  @override
  String get planDayTue => 'MAR';

  @override
  String get planDayWed => 'MIÉ';

  @override
  String get planDayThu => 'JUE';

  @override
  String get planDayFri => 'VIE';

  @override
  String get planDaySat => 'SÁB';

  @override
  String get planDaySun => 'DOM';
}
