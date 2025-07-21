import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:myapp/firebase_options.dart';
import 'dart:math';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({Key? key}) : super(key: key);

  Future<void> _showExistingUserDialog(BuildContext context) async {
    final TextEditingController controller = TextEditingController();
    String? errorMessage;
    bool loading = false;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

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
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF6B5B95),
                          Color(0xFF5A4A83),
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
                  Text(
                    'Ingrese su nombre de usuario',
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
                        borderSide: const BorderSide(
                          color: Color(0xFF6B5B95),
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
                        color: const Color(0xFF6B5B95),
                      ),
                    ),
                  ]
                ],
              ),
              actions: [
                TextButton(
                  onPressed: loading ? null : () => Navigator.of(context).pop(),
                  child: Text(
                    'Cancelar',
                    style: TextStyle(
                      color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: loading
                      ? null
                      : () async {
                          final username = controller.text.trim();
                          if (username.isEmpty) {
                            setState(() {
                              errorMessage = 'Por favor, ingrese un nombre de usuario.';
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
                    backgroundColor: const Color(0xFF6B5B95),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Entrar'),
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
    Navigator.of(context).pushNamedAndRemoveUntil('/loading', (route) => false);
  }

  Future<void> _showNewUserDialog(BuildContext context) async {
    final TextEditingController controller = TextEditingController();
    String? errorMessage;
    bool loading = false;
    bool infoShown = false;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

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
                          color: const Color(0xFF88B0D3),
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
                            color: const Color(0xFF88B0D3).withOpacity(0.1),
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
                                  color: const Color(0xFF88B0D3),
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
                          backgroundColor: const Color(0xFF88B0D3),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Entendido'),
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
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF88B0D3),
                          Color(0xFF6B8CAE),
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
                        borderSide: const BorderSide(
                          color: Color(0xFF88B0D3),
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
                        color: const Color(0xFF88B0D3),
                      ),
                    ),
                  ]
                ],
              ),
              actions: [
                TextButton(
                  onPressed: loading ? null : () => Navigator.of(context).pop(),
                  child: Text(
                    'Cancelar',
                    style: TextStyle(
                      color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                    ),
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
                              errorMessage = 'Por favor, ingrese un nombre de usuario.';
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
                    backgroundColor: const Color(0xFF88B0D3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Crear'),
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
        
        final isDarkMode = Theme.of(context).brightness == Brightness.dark;
        
        return Scaffold(
          backgroundColor: isDarkMode ? const Color(0xFF121212) : const Color(0xFFF5F5F5),
          body: SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    const SizedBox(height: 60),
                    // Removed logo container here
                    const SizedBox(height: 40),
                    Text(
                      'Traductor Achuar',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 60),
                    // Existing user button
                    _buildWelcomeButton(
                      onPressed: () => _showExistingUserDialog(context),
                      icon: Icons.person_outline,
                      label: 'Usuario existente',
                      subtitle: 'Ingresa con tu cuenta',
                      gradient: const [
                        Color(0xFF6B5B95),
                        Color(0xFF5A4A83),
                      ],
                      isDarkMode: isDarkMode,
                    ),
                    const SizedBox(height: 16),
                    // New user button
                    _buildWelcomeButton(
                      onPressed: () => _showNewUserDialog(context),
                      icon: Icons.person_add_outlined,
                      label: 'Nuevo usuario',
                      subtitle: 'Crea tu cuenta',
                      gradient: const [
                        Color(0xFF88B0D3),
                        Color(0xFF6B8CAE),
                      ],
                      isDarkMode: isDarkMode,
                    ),
                    const SizedBox(height: 16),
                    // Guest button
                    _buildWelcomeButton(
                      onPressed: () => _loginAsGuest(context),
                      icon: Icons.account_circle_outlined,
                      label: 'Entrar como invitado',
                      subtitle: 'Explora sin cuenta',
                      gradient: [
                        Colors.grey[600]!,
                        Colors.grey[700]!,
                      ],
                      isDarkMode: isDarkMode,
                    ),
                    const SizedBox(height: 40),
                    Text(
                      'Selecciona cómo deseas continuar',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDarkMode ? Colors.grey[500] : Colors.grey[600],
                      ),
                    ),
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
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
    required String subtitle,
    required List<Color> gradient,
    required bool isDarkMode,
  }) {
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(16),
      shadowColor: gradient[0].withOpacity(0.3),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: gradient,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: isDarkMode ? Colors.grey[600] : Colors.grey[400],
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}