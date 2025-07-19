import 'package:flutter/material.dart';
import 'package:myapp/screens/submit_screen.dart';
import 'package:myapp/screens/recent_screen.dart';
import 'package:myapp/screens/pending_screen.dart';

class SubmissionTabsScreen extends StatefulWidget {
  const SubmissionTabsScreen({super.key});

  @override
  _SubmissionTabsScreenState createState() => _SubmissionTabsScreenState();
}

class _SubmissionTabsScreenState extends State<SubmissionTabsScreen> {
  int _selectedIndex = 0;
  
  static const List<Widget> _screens = <Widget>[
    SubmitScreen(),
    RecentScreen(),
    PendingScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
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
              label: 'Enviar',
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
              label: 'Recientes',
            ),
            BottomNavigationBarItem(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _selectedIndex == 2
                      ? const Color(0xFFFA6900).withOpacity(0.15)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.pending_actions_rounded),
              ),
              label: 'Pendientes',
            ),
          ],
          currentIndex: _selectedIndex,
          selectedItemColor: _selectedIndex == 0 
              ? const Color(0xFF88B0D3)
              : _selectedIndex == 1 
                  ? const Color(0xFF82B366)
                  : const Color(0xFFFA6900),
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
    );
  }
}