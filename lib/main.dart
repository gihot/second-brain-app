import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/auth_gate.dart';
import 'providers/auth_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SecondBrainApp());
}

class SecondBrainApp extends StatelessWidget {
  const SecondBrainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthProvider()..init(),
      child: const AuthGate(),
    );
  }
}
