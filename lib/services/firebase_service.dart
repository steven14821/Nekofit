import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Puerto mínimo que el auth-gate necesita de la capa de Firebase.
///
/// Dividir la ruta de acceso a datos de su implementación permite que el
/// [AuthGateController] se pruebe sin conectar a Firebase: basta con
/// sobrescribir `authRepositoryProvider` con un fake que devuelva los
/// documentos que el test necesite (incluso errores o perfiles incompletos).
///
/// Expone el [uid] (String) en vez del objeto `User` de FirebaseAuth para
/// que los fakes no tengan que construir clases del SDK.
abstract interface class AuthRepository {
  /// Stream reactivo de autenticación (nunca debe recrearse por rebuild).
  /// Emite el uid del usuario autenticado, o `null` si no hay sesión.
  Stream<String?> get authState;

  /// Uid del usuario actualmente autenticado, o `null`.
  String? get currentUid;

  /// Devuelve el documento `users/{uid}` como mapa, o `null` si no existe.
  Future<Map<String, dynamic>?> fetchUserDoc(String uid);

  /// Cierra la sesión (autenticación + Google).
  Future<void> logout();
}

class FirebaseService implements AuthRepository {
  FirebaseService._internal();

  /// Singleton: una sola instancia viva durante toda la app.
  /// Crítico para que el `authState` stream no se recree en cada rebuild
  /// del AuthWrapper (eso era lo que dejaba la app pegada en Login
  /// después de autenticar).
  static final FirebaseService instance = FirebaseService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  @override
  Stream<String?> get authState =>
      _auth.authStateChanges().map((user) => user?.uid);

  /// Uid del usuario autenticado (interfaz [AuthRepository]).
  @override
  String? get currentUid => _auth.currentUser?.uid;

  /// Usuario autenticado — API legacy de la implementación concreta, la
  /// usan las pantallas que todavía no migran al contenedor DI.
  User? get currentUser => _auth.currentUser;

  @override
  Future<Map<String, dynamic>?> fetchUserDoc(String uid) async {
    final snap = await _db.collection('users').doc(uid).get();
    return snap.exists ? snap.data() : null;
  }

  FirebaseAuth get auth => _auth;
  FirebaseFirestore get db => _db;

  Future<UserCredential> login(String email, String password) {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  /// Inicia sesión con Google (cuenta Gmail).
  ///
  /// Devuelve null si el usuario canceló el flujo. Si el usuario no tiene un
  /// perfil en Firestore, el AuthWrapper lo manda al profile setup wizard.
  Future<User?> signInWithGoogle() async {
    final googleSignIn = GoogleSignIn.instance;
    await _ensureGoogleInitialized();

    final GoogleSignInAccount account;
    try {
      account = await googleSignIn.authenticate();
    } on GoogleSignInException catch (e) {
      // Cancelado / interrumpido / UI no disponible → el usuario no eligió cuenta.
      if (e.code == GoogleSignInExceptionCode.canceled ||
          e.code == GoogleSignInExceptionCode.interrupted ||
          e.code == GoogleSignInExceptionCode.uiUnavailable) {
        return null;
      }
      rethrow;
    }

    final credential = GoogleAuthProvider.credential(
      idToken: account.authentication.idToken,
    );
    final creds = await _auth.signInWithCredential(credential);
    return creds.user;
  }

  bool _googleInitialized = false;

  Future<void> _ensureGoogleInitialized() async {
    if (_googleInitialized) return;
    await GoogleSignIn.instance.initialize();
    _googleInitialized = true;
  }

  /// Cierra la sesión de Google también (evita que el selector de cuenta
  /// salte automáticamente en el siguiente inicio).
  @override
  Future<void> logout() async {
    await _auth.signOut();
    await GoogleSignIn.instance.signOut();
  }

  Future<UserCredential> registerWithProfile({
    required String email,
    required String password,
    required String username,
  }) async {
    final creds = await _auth.createUserWithEmailAndPassword(email: email, password: password);
    if (creds.user != null) {
      await _db.collection('users').doc(creds.user!.uid).set({
        'uid': creds.user!.uid,
        'username': username,
        'email': email,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    return creds;
  }

  Future<void> sendPasswordReset(String email) {
    return _auth.sendPasswordResetEmail(email: email);
  }

  Future<bool> verifyUsernameMatches(String uid, String username) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (doc.exists) {
      final storedUsername = doc.data()?['username'] as String?;
      return storedUsername?.trim().toLowerCase() == username.trim().toLowerCase();
    }
    return false;
  }
}
