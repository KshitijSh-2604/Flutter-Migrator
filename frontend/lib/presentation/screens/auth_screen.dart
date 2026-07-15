import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();

  bool _isSignUp = false;
  bool _emailChecked = false;
  String? _foundName;
  bool _isValidatingEmail = false;

  void _resetFlow() {
    setState(() {
      _emailChecked = false;
      _foundName = null;
      _passCtrl.clear();
      _confirmPassCtrl.clear();
      _nameCtrl.clear();
    });
  }

  void _showVerifyDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Verify your email'),
        content: const Text(
            'We have sent a verification link to your email address. Please click the link to activate your account before logging in.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final cs = Theme.of(context).colorScheme;

    return SelectionArea(
      child: Scaffold(
        body: Stack(
          children: [
            // Background
            Container(
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/images/landing_bg.png'),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            Container(color: cs.primary.withOpacity(0.8)),

            Center(
              child: Card(
                elevation: 8,
                margin: const EdgeInsets.all(24),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 400),
                  padding: const EdgeInsets.all(32),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset('assets/images/app_icon.png', height: 60),
                        const Gap(16),
                        Text(
                          'Flutter Migrator',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const Gap(8),
                        Text(
                          _isSignUp ? 'Create your account' : 'Login to continue',
                          style: TextStyle(color: cs.onSurface.withOpacity(0.6)),
                        ),
                        const Gap(32),

                        // --- SIGN UP FLOW ---
                        if (_isSignUp) ...[
                          TextField(
                            controller: _nameCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Full Name',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                          ),
                          const Gap(16),
                          TextField(
                            controller: _emailCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              prefixIcon: Icon(Icons.email_outlined),
                            ),
                          ),
                          const Gap(16),
                          TextField(
                            controller: _passCtrl,
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: 'Password',
                              prefixIcon: Icon(Icons.lock_outline),
                            ),
                          ),
                          const Gap(16),
                          TextField(
                            controller: _confirmPassCtrl,
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: 'Confirm Password',
                              prefixIcon: Icon(Icons.lock_reset),
                            ),
                          ),
                        ]
                        // --- LOGIN FLOW STEP 1: EMAIL ---
                        else if (!_emailChecked) ...[
                          TextField(
                            controller: _emailCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Email Address',
                              prefixIcon: Icon(Icons.email_outlined),
                            ),
                            onSubmitted: (_) => _handleLoginStep1(),
                          ),
                        ]
                        // --- LOGIN FLOW STEP 2: WELCOME + PASSWORD ---
                        else ...[
                          Text(
                            'Welcome back, $_foundName!',
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 16),
                          ),
                          const Gap(16),
                          TextField(
                            controller: _passCtrl,
                            obscureText: true,
                            autofocus: true,
                            decoration: const InputDecoration(
                              labelText: 'Enter your password',
                              prefixIcon: Icon(Icons.lock_outline),
                            ),
                          ),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton(
                              onPressed: () => setState(() => _emailChecked = false),
                              child: const Text('Not you? Change email', style: TextStyle(fontSize: 12)),
                            ),
                          ),
                        ],

                        const Gap(32),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: FilledButton(
                            onPressed: (auth.isLoading || _isValidatingEmail)
                                ? null
                                : (_isSignUp ? _handleSignUp : (_emailChecked ? _handleLoginStep2 : _handleLoginStep1)),
                            child: (auth.isLoading || _isValidatingEmail)
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white))
                                : Text(_isSignUp ? 'Sign Up' : (_emailChecked ? 'Login' : 'Continue')),
                          ),
                        ),
                        const Gap(16),
                        TextButton(
                          onPressed: () {
                            setState(() => _isSignUp = !_isSignUp);
                            _resetFlow();
                          },
                          child: Text(_isSignUp
                              ? 'Already have an account? Login'
                              : 'Need an account? Sign Up'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleLoginStep1() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) return;

    setState(() => _isValidatingEmail = true);
    final name = await context.read<AuthProvider>().checkEmailAndGetName(email);
    setState(() => _isValidatingEmail = false);

    if (name != null) {
      // User found in database!
      setState(() {
        _foundName = name.trim().isEmpty ? "User" : name;
        _emailChecked = true;
      });
    } else {
      // User NOT found in database
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No account found with this email. Please check your spelling or Sign Up.'),
          backgroundColor: Colors.orange,
        ));
      }
    }
  }

  Future<void> _handleLoginStep2() async {
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text.trim();
    if (pass.isEmpty) return;

    final error = await context.read<AuthProvider>().signIn(email, pass);
    if (error != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  Future<void> _handleSignUp() async {
    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text.trim();
    final confirm = _confirmPassCtrl.text.trim();

    if (name.isEmpty || email.isEmpty || pass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all fields')));
      return;
    }

    if (pass != confirm) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Passwords do not match')));
      return;
    }

    final error = await context.read<AuthProvider>().signUp(email, pass, name);
    if (error == null) {
      _showVerifyDialog();
      setState(() => _isSignUp = false);
      _resetFlow();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      }
    }
  }
}
