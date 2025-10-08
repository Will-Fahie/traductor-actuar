import 'package:flutter/material.dart';
import 'package:achuar_ingis/screens/submit_screen.dart';
import 'package:achuar_ingis/screens/recent_screen.dart';
import 'package:achuar_ingis/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SubmissionTabsScreen extends StatefulWidget {
  const SubmissionTabsScreen({super.key});

  @override
  _SubmissionTabsScreenState createState() => _SubmissionTabsScreenState();
}

class _SubmissionTabsScreenState extends State<SubmissionTabsScreen> {
  int _selectedIndex = 0;
  int _recentScreenRebuildKey = 0;

  List<Widget> get _screens => <Widget>[
    const SubmitScreen(),
    RecentScreen(key: ValueKey('recent_$_recentScreenRebuildKey')),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
      
      // Force rebuild when switching to recent tab to reload fresh data
      if (index == 1) {
        _recentScreenRebuildKey++;
      }
    });
  }

  Future<bool> _onWillPop() async {
    // Clear edit mode when going back to home screen
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isEditMode', false);
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) {
          await _onWillPop();
        }
      },
      child: Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          items: <BottomNavigationBarItem>[
            BottomNavigationBarItem(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _selectedIndex == 0
                      ? const Color(0xFF88B0D3).withOpacity(0.15)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.send_rounded),
              ),
              label: AppLocalizations.of(context)?.submit ?? 'Enviar',
            ),
            BottomNavigationBarItem(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _selectedIndex == 1
                      ? const Color(0xFF82B366).withOpacity(0.15)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.history_rounded),
              ),
              label: AppLocalizations.of(context)?.recentSubmissions ?? 'Recientes',
            ),
          ],
          currentIndex: _selectedIndex,
          selectedItemColor: _selectedIndex == 0 
              ? const Color(0xFF88B0D3)
              : const Color(0xFF82B366),
          unselectedItemColor: isDarkMode ? Colors.grey[600] : Colors.grey[600],
          backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
          onTap: _onItemTapped,
          type: BottomNavigationBarType.fixed,
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 12,
          ),
          iconSize: 24,
        ),
      ),
      ),
    );
  }
}