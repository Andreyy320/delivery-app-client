import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserStorage {
  static final _auth = FirebaseAuth.instance;
  static final _firestore = FirebaseFirestore.instance;

  static String _authEmailFromPhone(String phone) {
    return 'user_${phone.replaceAll('+', '')}@auth.local';
  }

  /// РЕГИСТРАЦИЯ
  static Future<void> register({
    required String name,
    required String phone,
    required String email, // РЕАЛЬНАЯ почта
    required String password,
  }) async {
    final authEmail = _authEmailFromPhone(phone);

    UserCredential cred =
    await _auth.createUserWithEmailAndPassword(
      email: authEmail,
      password: password,
    );

    await _firestore.collection('users').doc(cred.user!.uid).set({
      'name': name,
      'phone': phone,
      'email': email, // сохраняем настоящую почту
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// ВХОД (телефон + пароль)
  static Future<void> login({
    required String phone,
    required String password,
  }) async {
    final authEmail = _authEmailFromPhone(phone);

    await _auth.signInWithEmailAndPassword(
      email: authEmail,
      password: password,
    );
  }

  static String? get uid => _auth.currentUser?.uid;

  static Future<void> logout() async {
    await _auth.signOut();
  }

  static Future<Map<String, dynamic>?> getCurrentUser() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;

    final doc = await _firestore.collection('users').doc(uid).get();
    if (!doc.exists) return null;

    final data = doc.data()!;
    data['uid'] = uid; // добавляем поле uid
    return data;
  }

}
