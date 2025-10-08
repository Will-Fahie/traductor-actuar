import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:myapp/firebase_options.dart';
import 'dart:math';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:myapp/theme/app_theme.dart';
import 'package:myapp/widgets/app_card.dart';
import 'package:myapp/widgets/app_button.dart';
import 'package:myapp/widgets/info_banner.dart';
import 'package:myapp/services/language_service.dart';
import 'package:myapp/l10n/app_localizations.dart';
import 'package:myapp/widgets/language_toggle.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({Key? key}) : super(key: key);

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  bool _isConnected = true;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _initConnectivity();
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  Future<void> _initConnectivity() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (mounted) {
      setState(() {
        _isConnected = !connectivityResult.contains(ConnectivityResult.none);
      });
    }
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((result) {
      if (mounted) {
        setState(() {
          _isConnected = !result.contains(ConnectivityResult.none);
        });
      }
    });
  }

  Future<void> _showExistingUserDialog(BuildContext context) async {
    final TextEditingController controller = TextEditingController();
    String? errorMessage;
    bool loading = false;
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppTheme.primaryColor.withOpacity(0.8),
                          AppTheme.primaryColor,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.person_outline,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Usuario Existente',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedBuilder(
                    animation: LanguageService(),
                    builder: (context, child) {
                      final l10n = AppLocalizations.of(context);
                      return Text(
                        l10n?.enterUsername ?? 'Ingrese su nombre de usuario',
                        style: TextStyle(
                          fontSize: 14,
                          color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    decoration: InputDecoration(
                      hintText: 'Nombre de usuario',
                      prefixIcon: Icon(
                        Icons.account_circle_outlined,
                        color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: AppTheme.primaryColor,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                  if (errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: Colors.red[400],
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              errorMessage!,
                              style: TextStyle(
                                color: Colors.red[400],
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (loading) ...[
                    const SizedBox(height: 24),
                    Center(
                      child: CircularProgressIndicator(
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ]
                ],
              ),
              actions: [
                TextButton(
                  onPressed: loading ? null : () => Navigator.of(context).pop(),
                  child: AnimatedBuilder(
                    animation: LanguageService(),
                    builder: (context, child) {
                      final l10n = AppLocalizations.of(context);
                      return Text(
                        l10n?.cancel ?? 'Cancelar',
                        style: TextStyle(
                          color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                        ),
                      );
                    },
                  ),
                ),
                ElevatedButton(
                  onPressed: loading
                      ? null
                      : () async {
                          final username = controller.text.trim();
                          if (username.isEmpty) {
                            setState(() {
                              final l10n = AppLocalizations.of(context);
                              errorMessage = l10n?.pleaseEnterUsername ?? 'Por favor, ingrese un nombre de usuario.';
                            });
                            return;
                          }
                          setState(() {
                            loading = true;
                            errorMessage = null;
                          });
                          try {
                            print('Checking username in Firestore: ' + username);
                            final userDoc = await FirebaseFirestore.instance
                                .collection('users')
                                .doc(username)
                                .get();
                            if (userDoc.exists) {
                              final prefs = await SharedPreferences.getInstance();
                              await prefs.setString('username', username);
                              await prefs.setBool('guest_mode', false); // Set guest mode to false for existing users
                              print('Saved username to SharedPreferences (existing): ' + username);
                              Navigator.of(context).pop();
                              Navigator.of(context).pushNamedAndRemoveUntil('/loading', (route) => false);
                            } else {
                              setState(() {
                                errorMessage = 'Nombre de usuario no encontrado. Inténtelo de nuevo.';
                                loading = false;
                              });
                            }
                          } catch (e) {
                            setState(() {
                              errorMessage = 'Error al buscar el usuario. Inténtelo de nuevo.';
                              loading = false;
                            });
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                    ),
                  ),
                  child: AnimatedBuilder(
                    animation: LanguageService(),
                    builder: (context, child) {
                      final l10n = AppLocalizations.of(context);
                      return Text(
                        l10n?.enter ?? 'Entrar',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _loginAsGuest(BuildContext context) async {
    final random = Random();
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    String guestUsername = List.generate(10, (index) => chars[random.nextInt(chars.length)]).join();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('username', guestUsername);
    await prefs.setBool('guest_mode', true); // Set guest mode flag
    Navigator.of(context).pushNamedAndRemoveUntil('/loading', (route) => false);
  }

  Future<void> _showNewUserDialog(BuildContext context) async {
    final TextEditingController controller = TextEditingController();
    String? errorMessage;
    bool loading = false;
    bool infoShown = false;
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            if (!infoShown) {
              Future.delayed(Duration.zero, () {
                setState(() {
                  infoShown = true;
                });
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    title: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: AppTheme.secondaryColor,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Importante',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isDarkMode ? Colors.white : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'El nombre de usuario debe contener solo:',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: isDarkMode ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildRequirement('Letras (mayúsculas o minúsculas)', Icons.check_circle, Colors.green),
                        _buildRequirement('Números', Icons.check_circle, Colors.green),
                        _buildRequirement('Guiones bajos (_)', Icons.check_circle, Colors.green),
                        _buildRequirement('Sin espacios ni caracteres especiales', Icons.cancel, Colors.red),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.secondaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Ejemplos válidos:',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                  color: AppTheme.secondaryColor,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '• aronwalter\n• jake_message\n• WillFahie',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    actions: [
                      ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.secondaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Entendido',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              });
            }
            return AlertDialog(
              backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppTheme.secondaryColor.withOpacity(0.8),
                          AppTheme.secondaryColor,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.person_add_outlined,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Nuevo Usuario',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cree un nombre de usuario único',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    decoration: InputDecoration(
                      hintText: 'Nombre de usuario',
                      prefixIcon: Icon(
                        Icons.account_circle_outlined,
                        color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: AppTheme.secondaryColor,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                  if (errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: Colors.red[400],
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              errorMessage!,
                              style: TextStyle(
                                color: Colors.red[400],
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (loading) ...[
                    const SizedBox(height: 24),
                    Center(
                      child: CircularProgressIndicator(
                        color: AppTheme.secondaryColor,
                      ),
                    ),
                  ]
                ],
              ),
              actions: [
                TextButton(
                  onPressed: loading ? null : () => Navigator.of(context).pop(),
                  child: AnimatedBuilder(
                    animation: LanguageService(),
                    builder: (context, child) {
                      final l10n = AppLocalizations.of(context);
                      return Text(
                        l10n?.cancel ?? 'Cancelar',
                        style: TextStyle(
                          color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                        ),
                      );
                    },
                  ),
                ),
                ElevatedButton(
                  onPressed: loading
                      ? null
                      : () async {
                          final username = controller.text.trim();
                          final valid = RegExp(r'^[A-Za-z0-9_]{1,}$').hasMatch(username);
                          
                          if (username.isEmpty) {
                            setState(() {
                              final l10n = AppLocalizations.of(context);
                              errorMessage = l10n?.pleaseEnterUsername ?? 'Por favor, ingrese un nombre de usuario.';
                            });
                            return;
                          }
                          
                          if (!valid) {
                            setState(() {
                              errorMessage = 'El nombre de usuario solo puede contener letras, números o guiones bajos (_), sin espacios.';
                            });
                            return;
                          }
                          
                          setState(() {
                            loading = true;
                            errorMessage = null;
                          });
                          
                          try {
                            final userDoc = await FirebaseFirestore.instance
                                .collection('users')
                                .doc(username)
                                .get();
                                
                            if (userDoc.exists) {
                              setState(() {
                                errorMessage = 'Este nombre de usuario ya existe. Elija otro.';
                                loading = false;
                              });
                              return;
                            }
                            
                            await FirebaseFirestore.instance
                                .collection('users')
                                .doc(username)
                                .set({'created_at': FieldValue.serverTimestamp()});
                                
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setString('username', username);
                            await prefs.setBool('guest_mode', false); // Set guest mode to false for regular users
                            
                            Navigator.of(context).pop();
                            Navigator.of(context).pushNamedAndRemoveUntil('/loading', (route) => false);
                          } catch (e) {
                            setState(() {
                              errorMessage = 'Error al crear el usuario. Inténtelo de nuevo.';
                              loading = false;
                            });
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.secondaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Crear',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildRequirement(String text, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(fontSize: 14),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: Firebase.apps.isEmpty
          ? Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)
          : Future.value(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        
        final theme = Theme.of(context);
        final isDarkMode = theme.brightness == Brightness.dark;
        
        return Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            automaticallyImplyLeading: false,
            actions: const [
              LanguageToggle(),
              SizedBox(width: 16),
            ],
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.spacingLarge),
                child: Column(
                  children: [
                    const SizedBox(height: AppTheme.spacingXLarge * 2),
                    // App branding
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            theme.colorScheme.primary.withOpacity(0.8),
                            theme.colorScheme.primary,
                          ],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: theme.colorScheme.primary.withOpacity(0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.translate_rounded,
                        color: Colors.white,
                        size: 50,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingLarge),
                    Text(
                      'Traductor Achuar',
                      style: theme.textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingSmall),
                    AnimatedBuilder(
                      animation: LanguageService(),
                      builder: (context, child) {
                        final l10n = AppLocalizations.of(context);
                        return Text(
                          l10n?.welcome ?? 'Bienvenido',
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: theme.textTheme.bodySmall?.color,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: AppTheme.spacingXLarge * 1.5),
                    // Existing user button
                    AnimatedBuilder(
                      animation: LanguageService(),
                      builder: (context, child) {
                        final l10n = AppLocalizations.of(context);
                        return _buildWelcomeButton(
                          onPressed: _isConnected ? () => _showExistingUserDialog(context) : null,
                          icon: Icons.person_outline_rounded,
                          label: l10n?.existingUser ?? 'Usuario existente',
                          subtitle: l10n?.loginWithAccount ?? 'Ingresa con tu cuenta',
                          color: AppTheme.primaryColor,
                          theme: theme,
                          isEnabled: _isConnected,
                        );
                      },
                    ),
                    const SizedBox(height: AppTheme.spacingMedium),
                    // New user button
                    AnimatedBuilder(
                      animation: LanguageService(),
                      builder: (context, child) {
                        final l10n = AppLocalizations.of(context);
                        return _buildWelcomeButton(
                          onPressed: _isConnected ? () => _showNewUserDialog(context) : null,
                          icon: Icons.person_add_outlined,
                          label: l10n?.newUser ?? 'Nuevo usuario',
                          subtitle: l10n?.createAccount ?? 'Crea tu cuenta',
                          color: AppTheme.secondaryColor,
                          theme: theme,
                          isEnabled: _isConnected,
                        );
                      },
                    ),
                    const SizedBox(height: AppTheme.spacingMedium),
                    // Guest button
                    AnimatedBuilder(
                      animation: LanguageService(),
                      builder: (context, child) {
                        final l10n = AppLocalizations.of(context);
                        return _buildWelcomeButton(
                          onPressed: () => _loginAsGuest(context),
                          icon: Icons.account_circle_outlined,
                          label: l10n?.enterAsGuest ?? 'Entrar como invitado',
                          subtitle: l10n?.exploreWithoutAccount ?? 'Explora sin cuenta',
                          color: theme.textTheme.bodySmall?.color ?? Colors.grey,
                          theme: theme,
                          isEnabled: true,
                        );
                      },
                    ),
                    const SizedBox(height: AppTheme.spacingXLarge),
                    if (!_isConnected) ...[
                      AnimatedBuilder(
                        animation: LanguageService(),
                        builder: (context, child) {
                          final l10n = AppLocalizations.of(context);
                          return InfoBanner(
                            title: l10n?.noInternetConnection ?? 'Sin conexión a internet',
                            message: l10n?.noInternetMessage ?? 'Por favor, conéctese a internet para iniciar sesión o crear una cuenta.',
                            type: InfoBannerType.error,
                          );
                        },
                      ),
                      const SizedBox(height: AppTheme.spacingLarge),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildWelcomeButton({
    required VoidCallback? onPressed,
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required ThemeData theme,
    bool isEnabled = true,
  }) {
    return AppCard(
      onTap: isEnabled ? onPressed : null,
      elevation: isEnabled ? AppTheme.elevationLarge : AppTheme.elevationSmall,
      padding: const EdgeInsets.all(AppTheme.spacingMedium),
      child: Opacity(
        opacity: isEnabled ? 1.0 : 0.6,
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    color.withOpacity(0.8),
                    color,
                  ],
                ),
                borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(width: AppTheme.spacingMedium),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppTheme.spacingXSmall),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: theme.textTheme.bodySmall?.color,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}