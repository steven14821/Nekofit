import 'package:cloud_firestore/cloud_firestore.dart';

class UserContext {
  final String uid;
  final String username;
  final String gender; // 'Masculino' | 'Femenino'
  final int age;
  final double weight; // en kg
  final double height; // en cm
  final String activityLevel; // mantenido por compatibilidad (legacy string)
  final String? customActivityDescription;
  final String fitnessGoal;
  final String? customGoalDescription;
  final Map<String, double> macroGoals; // carbs, protein, fat (en gramos)

  // --- Campos nuevos (Katch-McArdle + split de actividad) ---
  final double? bodyFatPercent; // % grasa corporal
  final String?
      bodyFatMethod; // 'visual' | 'us_navy' (cómo se obtuvo el % grasa)
  final double? neckCircumference; // cm
  final double? waistCircumference; // cm
  final double? hipCircumference; // cm (usado solo en mujeres, US Navy)
  final String
      dailyLifestyle; // 'sedentario' | 'activo' (qué hace el usuario la mayor parte del día)
  final String
      trainingActivity; // clave en ActivityMetFactors.byKey (pesas_hit, correr, etc.)
  final int weeklyTrainingMinutes; // minutos de entrenamiento a la semana
  final String bmrFormula; // 'katch' | 'mifflin' (cuál se usó en el cálculo)

  // --- Campos de Mascota y Racha (Streak) ---
  final String? catName;
  final String catStyle;

  /// Qué mascota se eligió: 'gato' | 'perro1' | 'perro2'.
  final String petType;
  final int currentStreak;
  final int longestStreak;
  final DateTime? lastLoggedDate;

  UserContext({
    required this.uid,
    required this.username,
    this.gender = 'Femenino',
    required this.age,
    required this.weight,
    required this.height,
    required this.activityLevel,
    this.customActivityDescription,
    required this.fitnessGoal,
    this.customGoalDescription,
    required this.macroGoals,
    this.bodyFatPercent,
    this.bodyFatMethod,
    this.neckCircumference,
    this.waistCircumference,
    this.hipCircumference,
    this.dailyLifestyle = 'sedentario',
    this.trainingActivity = 'pesas_hit',
    this.weeklyTrainingMinutes = 0,
    this.bmrFormula = 'mifflin',
    this.catName,
    this.catStyle = 'default',
    this.petType = 'gato',
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.lastLoggedDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'username': username,
      'gender': gender,
      'age': age,
      'weight': weight,
      'height': height,
      'activityLevel': activityLevel,
      'customActivityDescription': customActivityDescription,
      'fitnessGoal': fitnessGoal,
      'customGoalDescription': customGoalDescription,
      'macroGoals': macroGoals,
      'bodyFatPercent': bodyFatPercent,
      'bodyFatMethod': bodyFatMethod,
      'neckCircumference': neckCircumference,
      'waistCircumference': waistCircumference,
      'hipCircumference': hipCircumference,
      'dailyLifestyle': dailyLifestyle,
      'trainingActivity': trainingActivity,
      'weeklyTrainingMinutes': weeklyTrainingMinutes,
      'bmrFormula': bmrFormula,
      'catName': catName,
      'catStyle': catStyle,
      'petType': petType,
      'currentStreak': currentStreak,
      'longestStreak': longestStreak,
      'lastLoggedDate': lastLoggedDate?.toIso8601String(),
    };
  }

  factory UserContext.fromMap(Map<String, dynamic> map) {
    return UserContext(
      uid: map['uid'] ?? '',
      username: map['username'] ?? '',
      gender: map['gender'] ?? 'Femenino',
      age: map['age'] ?? 0,
      weight: (map['weight'] ?? 0.0).toDouble(),
      height: (map['height'] ?? 0.0).toDouble(),
      activityLevel: map['activityLevel'] ?? '',
      customActivityDescription: map['customActivityDescription'],
      fitnessGoal: map['fitnessGoal'] ?? '',
      customGoalDescription: map['customGoalDescription'],
      macroGoals: Map<String, double>.from(map['macroGoals'] ?? {}),
      bodyFatPercent: (map['bodyFatPercent'] as num?)?.toDouble(),
      bodyFatMethod: map['bodyFatMethod'] as String?,
      neckCircumference: (map['neckCircumference'] as num?)?.toDouble(),
      waistCircumference: (map['waistCircumference'] as num?)?.toDouble(),
      hipCircumference: (map['hipCircumference'] as num?)?.toDouble(),
      dailyLifestyle: map['dailyLifestyle'] ?? 'sedentario',
      trainingActivity: map['trainingActivity'] ?? 'pesas_hit',
      weeklyTrainingMinutes: (map['weeklyTrainingMinutes'] as num?)?.toInt() ?? 0,
      bmrFormula: map['bmrFormula'] ?? 'mifflin',
      catName: map['catName'] as String?,
      catStyle: map['catStyle'] ?? 'default',
      petType: map['petType'] ?? 'gato',
      currentStreak: (map['currentStreak'] as num?)?.toInt() ?? 0,
      longestStreak: (map['longestStreak'] as num?)?.toInt() ?? 0,
      lastLoggedDate: map['lastLoggedDate'] != null
          ? (map['lastLoggedDate'] is Timestamp
              ? (map['lastLoggedDate'] as Timestamp).toDate()
              : DateTime.tryParse(map['lastLoggedDate'].toString()))
          : null,
    );
  }
}
