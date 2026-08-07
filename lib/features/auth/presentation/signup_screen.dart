import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../data/auth_repository.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _agreedToTerms = false;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignUp() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (!_agreedToTerms) {
      setState(() {
        _errorMessage = 'You must acknowledge the terms to create an account';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await ref.read(authRepositoryProvider).signUpWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        fullName: _nameController.text.trim(),
      );
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '').split(']').last.trim();
        _isLoading = false;
      });
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = await ref.read(authRepositoryProvider).signInWithGoogle();
      if (user == null) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '').split(']').last.trim();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    // Logo Box
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppTheme.textSecondary.withValues(alpha: 0.2)),
                        color: AppTheme.surfaceCard,
                      ),
                      child: Image.asset(
                        'assets/logo.png',
                        height: 48,
                        width: 48,
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Large Wordmark
                    Text(
                      'SplitMate',
                      style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                            color: AppTheme.accent,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                    ),
                    const SizedBox(height: 32),

                    // Error Message
                    if (_errorMessage != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppTheme.semanticNegative.withValues(alpha: 0.1),
                          border: Border.all(color: AppTheme.semanticNegative),
                        ),
                        child: Text(
                          _errorMessage!,
                          style: AppTheme.monoStyle.copyWith(
                            color: AppTheme.semanticNegative,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Input Form Card
                    Container(
                      padding: const EdgeInsets.all(24.0),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppTheme.textSecondary.withValues(alpha: 0.3)),
                        color: Colors.transparent,
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Join the ledger',
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Establish your fiscal footprint today.',
                              style: AppTheme.monoSecondary.copyWith(fontSize: 12),
                            ),
                            const SizedBox(height: 28),

                            // Full Name Field
                            _buildTextField(
                              label: 'FULL NAME',
                              controller: _nameController,
                              hintText: 'J. MORGAN',
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return 'Full name is required';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 24),

                            // Email Address Field
                            _buildTextField(
                              label: 'EMAIL ADDRESS',
                              controller: _emailController,
                              hintText: 'ledger@splitmate.com',
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return 'Email is required';
                                }
                                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(val.trim())) {
                                  return 'Enter a valid email address';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 24),

                            // Master Password Field
                            _buildTextField(
                              label: 'MASTER PASSWORD',
                              controller: _passwordController,
                              hintText: '•••••••••••••',
                              obscureText: _obscurePassword,
                              suffix: InkWell(
                                onTap: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                                child: Icon(
                                  _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                  color: AppTheme.textSecondary,
                                  size: 18,
                                ),
                              ),
                              validator: (val) {
                                if (val == null || val.isEmpty) {
                                  return 'Password is required';
                                }
                                if (val.length < 6) {
                                  return 'Password must be at least 6 characters';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 20),

                            // Acknowledge Checkbox
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: Checkbox(
                                    value: _agreedToTerms,
                                    activeColor: AppTheme.accent,
                                    checkColor: Colors.black,
                                    side: BorderSide(
                                      color: AppTheme.textSecondary.withValues(alpha: 0.5),
                                    ),
                                    onChanged: (val) {
                                      setState(() {
                                        _agreedToTerms = val ?? false;
                                      });
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: RichText(
                                    text: TextSpan(
                                      style: TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontSize: 12,
                                        height: 1.4,
                                      ),
                                      children: const [
                                        TextSpan(text: 'I acknowledge the '),
                                        TextSpan(
                                          text: 'Terms of Service',
                                          style: TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold),
                                        ),
                                        TextSpan(text: ' and consent to the '),
                                        TextSpan(
                                          text: 'Privacy Policy',
                                          style: TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold),
                                        ),
                                        TextSpan(text: '.'),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 32),

                            // Create Account Button
                            InkWell(
                              onTap: _isLoading ? null : _handleSignUp,
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                decoration: const BoxDecoration(
                                  color: AppTheme.accent,
                                ),
                                child: _isLoading
                                    ? const Center(
                                        child: SizedBox(
                                          height: 18,
                                          width: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                                          ),
                                        ),
                                      )
                                    : Center(
                                        child: Text(
                                          'CREATE ACCOUNT',
                                          style: AppTheme.monoStyle.copyWith(
                                            color: Colors.black,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            letterSpacing: 1.5,
                                          ),
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Divider
                            Row(
                              children: [
                                Expanded(
                                  child: Divider(color: AppTheme.textSecondary.withValues(alpha: 0.2)),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  child: Text(
                                    'OR CONTINUE WITH',
                                    style: AppTheme.monoSecondary.copyWith(
                                      fontSize: 10,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Divider(color: AppTheme.textSecondary.withValues(alpha: 0.2)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),

                            // Google Button
                            InkWell(
                              onTap: _isLoading ? null : _handleGoogleSignIn,
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                decoration: BoxDecoration(
                                  border: Border.all(color: AppTheme.textSecondary.withValues(alpha: 0.4)),
                                  color: AppTheme.surfaceCard,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    _buildGoogleLogo(),
                                    const SizedBox(width: 12),
                                    Text(
                                      'GOOGLE',
                                      style: AppTheme.monoStyle.copyWith(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Sign in navigation
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Already have an account? ',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                        ),
                        InkWell(
                          onTap: () => context.go('/login'),
                          child: const Text(
                            'Sign in',
                            style: TextStyle(
                              color: AppTheme.accent,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 48),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildGoogleLogo() {
    return Container(
      width: 18,
      height: 18,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: const Text(
        'G',
        style: TextStyle(
          color: Colors.black,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          fontFamily: 'sans-serif',
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required String hintText,
    bool obscureText = false,
    Widget? suffix,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: AppTheme.monoSecondary.copyWith(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            if (suffix != null) suffix,
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          validator: validator,
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15),
          cursorColor: AppTheme.accent,
          decoration: InputDecoration(
            filled: true,
            fillColor: AppTheme.surfaceCard,
            hintText: hintText,
            hintStyle: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.4)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: OutlineInputBorder(
              borderSide: BorderSide(color: AppTheme.textSecondary.withValues(alpha: 0.3)),
              borderRadius: BorderRadius.zero,
            ),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: AppTheme.textSecondary.withValues(alpha: 0.3)),
              borderRadius: BorderRadius.zero,
            ),
            focusedBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: AppTheme.accent, width: 1.5),
              borderRadius: BorderRadius.zero,
            ),
            errorBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: AppTheme.semanticNegative),
              borderRadius: BorderRadius.zero,
            ),
            focusedErrorBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: AppTheme.semanticNegative, width: 1.5),
              borderRadius: BorderRadius.zero,
            ),
          ),
        ),
      ],
    );
  }
}
