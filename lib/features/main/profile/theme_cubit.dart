import 'package:flutter_bloc/flutter_bloc.dart';

class ThemeCubit extends Cubit<bool> {
  ThemeCubit() : super(false);  // false by default (light mode)

  void toggleTheme() {
    emit(!state);
  }
}
