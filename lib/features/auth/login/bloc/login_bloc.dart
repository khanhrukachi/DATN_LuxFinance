import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'login_event.dart';
import 'login_state.dart';
import 'package:personal_financial_management/models/user.dart' as myuser;

class LoginBloc extends Bloc<LoginEvent, LoginState> {
  String _status = "";

  LoginBloc() : super(InitState()) {
    on<LoginWithEmailPasswordEvent>(_loginWithEmail);
    on<LoginWithGoogleEvent>(_loginWithGoogle);
  }

  /* ================= EMAIL LOGIN ================= */

  Future<void> _loginWithEmail(
      LoginWithEmailPasswordEvent event, Emitter<LoginState> emit) async {
    bool check = await signInWithEmailAndPassword(
      emailAddress: event.email,
      password: event.password,
    );

    if (check) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool("login", true);
      emit(LoginSuccessState(social: Social.email));
    } else {
      emit(LoginErrorState(status: _status));
    }
  }

  /* ================= GOOGLE LOGIN ================= */

  Future<void> _loginWithGoogle(
      LoginWithGoogleEvent event, Emitter<LoginState> emit) async {
    try {
      final UserCredential? credential = await signInWithGoogle();
      final User? user = credential?.user;

      if (user == null) {
        emit(LoginErrorState(status: "google_login_failed"));
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool("login", false);

      final bool existed = await initInfoUser(user);

      emit(LoginSuccessState(
          social: existed ? Social.google : Social.newUser));
    } catch (e) {
      emit(LoginErrorState(status: e.toString()));
    }
  }

  /* ================= AUTH METHODS ================= */

  Future<UserCredential?> signInWithGoogle() async {
    final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) return null;

    final googleAuth = await googleUser.authentication;

    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    return FirebaseAuth.instance.signInWithCredential(credential);
  }

  Future<bool> signInWithEmailAndPassword({
    required String emailAddress,
    required String password,
  }) async {
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailAddress,
        password: password,
      );
      return true;
    } on FirebaseAuthException catch (e) {
      _status = e.code;
      return false;
    }
  }

  /* ================= FIRESTORE SYNC ================= */

  Future<bool> initInfoUser(User user) async {
    final docRef =
    FirebaseFirestore.instance.collection("info").doc(user.uid);

    final docSnap = await docRef.get();

    final avatarUrl = user.photoURL ?? "";

    if (!docSnap.exists) {
      await docRef.set(
        myuser.User(
          name: user.displayName ?? "User",
          birthday: DateFormat("dd/MM/yyyy").format(DateTime.now()),
          money: 0,
          avatar: avatarUrl,
        ).toMap(),
      );
      return false;
    } else {
      await docRef.update({
        'avatar': avatarUrl,
        'name': user.displayName ?? '',
      });
      return true;
    }
  }
}
