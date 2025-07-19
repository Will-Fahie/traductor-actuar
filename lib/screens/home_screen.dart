import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // Set the system UI overlay style
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent, // Make the status bar transparent
      statusBarIconBrightness: isDarkMode ? Brightness.light : Brightness.dark,
    ));
    
    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF121212) : const Color(0xFFF5F5F5),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(top: 40), // Increased top padding
          children: [
            // Welcome message
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Winiajai!',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Explora las herramientas de traducción y recursos educativos.',
                    style: TextStyle(
                      fontSize: 16,
                      color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
            
            // Menu items
            _buildMenuItem(
              context,
              title: 'Diccionario',
              subtitle: 'Busca palabras y sus significados',
              icon: Icons.book,
              routeName: '/dictionary',
              color: const Color(0xFF6B5B95),
            ),
            _buildMenuItem(
              context,
              title: 'Envío de Frases',
              subtitle: 'Comparte nuevas frases para traducir',
              icon: Icons.send,
              routeName: '/submit',
              color: const Color(0xFF88B0D3),
            ),
            _buildMenuItem(
              context,
              title: 'Traductor',
              subtitle: 'Traduce texto instantáneamente',
              icon: Icons.translate,
              routeName: '/translator',
              color: const Color(0xFF82B366),
            ),
            _buildMenuItem(
              context,
              title: 'Recursos de Enseñanza',
              subtitle: 'Material educativo y lecciones',
              icon: Icons.school,
              routeName: '/teaching_resources',
              color: const Color(0xFFFA6900),
            ),
            _buildMenuItem(
              context,
              title: 'Recursos de Guía',
              subtitle: 'Guías y documentación útil',
              icon: Icons.map,
              routeName: '/guide_resources',
              color: const Color(0xFFF38630),
            ),
            _buildMenuItem(
              context,
              title: 'Recursos de Ecolodge',
              subtitle: 'Información sobre ecoturismo',
              icon: Icons.eco,
              routeName: '/ecolodge_resources',
              color: const Color(0xFF69D2E7),
            ),
            const SizedBox(height: 20), // Bottom padding
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required String routeName,
    required Color color,
  }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Material(
        elevation: isDarkMode ? 2 : 4,
        shadowColor: Colors.black.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        child: InkWell(
          onTap: () => Navigator.pushNamed(context, routeName),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                // Icon container with gradient background
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        color.withOpacity(0.8),
                        color,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    icon,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 20),
                // Title and subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
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
                // Arrow icon
                Icon(
                  Icons.arrow_forward_ios,
                  color: isDarkMode ? Colors.grey[600] : Colors.grey[400],
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}