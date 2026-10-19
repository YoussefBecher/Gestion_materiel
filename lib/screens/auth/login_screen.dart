import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../utils/auth_validators.dart';

/// Écran de connexion de l'application BIAT Gestion Matériel.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordFocusNode = FocusNode();

  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
    } on FirebaseAuthException catch (e) {
      setState(() => _errorMessage = messageErreurConnexion(e.code));
    } catch (_) {
      setState(() => _errorMessage = 'Une erreur inattendue est survenue.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue.shade50,
      // LayoutBuilder + ConstrainedBox(minHeight) : la vraie façon de centrer
      // verticalement un formulaire dans un SingleChildScrollView. Un simple
      // "Center" autour d'un SingleChildScrollView ne fonctionne PAS en
      // Flutter (piège classique) — il faut forcer une hauteur minimale.
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight - 48, // -48 = padding haut+bas
              ),
              child: Center(
                child: Form(
                  key: _formKey,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Semantics(
                        label: 'Logo BIAT',
                        image: true,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blue.shade100,
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Image.asset('assets/logo_biat.png',
                              height: 80, fit: BoxFit.contain),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text('Gestion Matériel',
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                      const Text('Banque — Espace Administration',
                          style: TextStyle(fontSize: 13, color: Colors.grey)),
                      const SizedBox(height: 32),

                      TextFormField(
                        controller: _emailController,
                        enabled: !_isLoading,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.email],
                        validator: validerEmail,
                        onFieldSubmitted: (_) => _passwordFocusNode.requestFocus(),
                        decoration: const InputDecoration(
                          labelText: 'Adresse e-mail',
                          prefixIcon: Icon(Icons.email_outlined),
                          border: OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _passwordController,
                        focusNode: _passwordFocusNode,
                        enabled: !_isLoading,
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.password],
                        validator: validerMotDePasse,
                        onFieldSubmitted: (_) => _login(),
                        decoration: InputDecoration(
                          labelText: 'Mot de passe',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: Semantics(
                            label: _obscurePassword
                                ? 'Afficher le mot de passe'
                                : 'Masquer le mot de passe',
                            button: true,
                            child: IconButton(
                              icon: Icon(_obscurePassword
                                  ? Icons.visibility_off
                                  : Icons.visibility),
                              onPressed: () => setState(
                                      () => _obscurePassword = !_obscurePassword),
                            ),
                          ),
                          border: const OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                      ),

                      if (_errorMessage != null) ...[
                        const SizedBox(height: 12),
                        Semantics(
                          liveRegion: true,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline,
                                    color: Colors.red, size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: const TextStyle(color: Colors.red, fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: Semantics(
                          label: 'Se connecter',
                          button: true,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _login,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF003087),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )
                                : const Text('Se connecter',
                                style: TextStyle(color: Colors.white, fontSize: 16)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}