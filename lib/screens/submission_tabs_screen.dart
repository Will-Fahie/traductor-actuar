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
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.send),
            label: 'Submit',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'Recent',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.pending),
            label: 'Pending',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Theme.of(context).primaryColor,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}
