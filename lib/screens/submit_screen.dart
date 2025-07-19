import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:myapp/services/sync_service.dart'; // Import the SyncService

class SubmitScreen extends StatefulWidget {
  const SubmitScreen({super.key});

  @override
  _SubmitScreenState createState() => _SubmitScreenState();
}

class _SubmitScreenState extends State<SubmitScreen> {
  String? _selectedLocation;

  final List<String> _locations = [
    'Comunidad Kapawi',
    'Comunidad Kasutkao',
    'Comunidad Suwa',
    'Kapawi Ecolodge',
    'Colegio Tuna'
  ];

  final TextEditingController _achuarController = TextEditingController();
  final TextEditingController _spanishController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  bool _isOffline = true;
  List<Map<String, dynamic>> _pendingSubmissions = [];
  late StreamSubscription<List<Map<String, dynamic>>> _pendingSubmissionsSubscription;
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _checkInitialConnectivity();

    _pendingSubmissionsSubscription = SyncService().pendingSubmissionsStream.listen((pending) {
      if (mounted) {
        setState(() {
          _pendingSubmissions = pending;
        });
      }
    });

    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((result) {
      if (mounted) {
        setState(() {
          _isOffline = result.contains(ConnectivityResult.none);
        });
      }
    });

    SyncService().loadPendingSubmissions();
  }

  @override
  void dispose() {
    _pendingSubmissionsSubscription.cancel();
    _connectivitySubscription.cancel();
    _achuarController.dispose();
    _spanishController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _checkInitialConnectivity() async {
    final result = await Connectivity().checkConnectivity();
    if (mounted) {
      setState(() {
        _isOffline = result.contains(ConnectivityResult.none);
      });
    }
  }
  
  void _submit() async {
    if (_achuarController.text.isEmpty || _spanishController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, complete los campos obligatorios')),
      );
      return;
    }

    final deviceId = await SyncService().getDeviceId();
    final submission = {
      'achuar': _achuarController.text,
      'spanish': _spanishController.text,
      'notes': _notesController.text,
      'location': _selectedLocation,
      'deviceId': deviceId,
    };

    final wasSavedLocally = await SyncService().addSubmission(submission);
    
    _clearForm();
    _showConfirmationDialog(isOffline: wasSavedLocally);
  }

  void _clearForm() {
    _achuarController.clear();
    _spanishController.clear();
    _notesController.clear();
    setState(() {
      _selectedLocation = null;
    });
  }

  void _showConfirmationDialog({bool isOffline = false}) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          icon: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: isOffline ? Colors.orange.withOpacity(0.1) : Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(32),
            ),
            child: Icon(
              isOffline ? Icons.cloud_off : Icons.cloud_done,
              color: isOffline ? Colors.orange : Colors.green,
              size: 32,
            ),
          ),
          title: Text(
            isOffline ? 'Guardado localmente' : 'Éxito',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
          content: Text(
            isOffline
                ? 'Tu contribución ha sido guardada y se subirá automáticamente cuando te conectes a internet.'
                : 'Tu contribución ha sido enviada con éxito.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text(
                'Cerrar',
                style: TextStyle(
                  color: isDarkMode ? const Color(0xFF88B0D3) : const Color(0xFF6B5B95),
                  fontWeight: FontWeight.w600,
                ),
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF121212) : const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text(
          'Envío de Frases',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        elevation: 0,
        backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color(0xFF88B0D3),
                                Color(0xFF6B8CAE),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.send,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Contribuye al diccionario',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Ayúdanos a expandir el traductor Achuar-Español',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: _isOffline 
                            ? Colors.orange.withOpacity(0.1) 
                            : Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _isOffline ? Icons.wifi_off : Icons.wifi,
                            color: _isOffline ? Colors.orange : Colors.green,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _isOffline ? 'Modo sin conexión' : 'En línea',
                            style: TextStyle(
                              color: _isOffline ? Colors.orange : Colors.green,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_pendingSubmissions.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        '${_pendingSubmissions.length} ${_pendingSubmissions.length == 1 ? 'contribución pendiente' : 'contribuciones pendientes'}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle('Frase en Achuar', Icons.language),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: _achuarController,
                      hint: 'Ingrese la frase en Achuar',
                      isDarkMode: isDarkMode,
                    ),
                    const SizedBox(height: 24),
                    
                    _buildSectionTitle('Frase en Español', Icons.translate),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: _spanishController,
                      hint: 'Ingrese la traducción en Español',
                      isDarkMode: isDarkMode,
                    ),
                    const SizedBox(height: 24),
                    
                    _buildSectionTitle('Ubicación', Icons.location_on),
                    const SizedBox(height: 8),
                    _buildDropdown(isDarkMode),
                    const SizedBox(height: 24),
                    
                    _buildSectionTitle('Notas adicionales', Icons.note),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: _notesController,
                      hint: 'Agregue cualquier información adicional (opcional)',
                      isDarkMode: isDarkMode,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 32),
                    
                    _buildSubmitButton(isDarkMode),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: const Color(0xFF88B0D3),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required bool isDarkMode,
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        style: TextStyle(
          color: isDarkMode ? Colors.white : Colors.black87,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: isDarkMode ? Colors.grey[600] : Colors.grey[500],
          ),
          filled: true,
          fillColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
          contentPadding: const EdgeInsets.all(16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: isDarkMode ? Colors.grey[800]! : Colors.grey[300]!,
              width: 1,
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
    );
  }

  Widget _buildDropdown(bool isDarkMode) {
    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDarkMode ? Colors.grey[800]! : Colors.grey[300]!,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: ButtonTheme(
          alignedDropdown: true,
          child: DropdownButton<String>(
            isExpanded: true,
            hint: Text(
              'Seleccione una ubicación',
              style: TextStyle(
                color: isDarkMode ? Colors.grey[600] : Colors.grey[500],
              ),
            ),
            value: _selectedLocation,
            icon: Icon(
              Icons.arrow_drop_down,
              color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
            ),
            dropdownColor: isDarkMode ? const Color(0xFF2C2C2C) : Colors.white,
            style: TextStyle(
              color: isDarkMode ? Colors.white : Colors.black87,
              fontSize: 16,
            ),
            items: _locations.map((String location) {
              return DropdownMenuItem<String>(
                value: location,
                child: Text(location),
              );
            }).toList(),
            onChanged: (String? newValue) {
              setState(() {
                _selectedLocation = newValue;
              });
            },
          ),
        ),
      ),
    );
  }

  Widget _buildSubmitButton(bool isDarkMode) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _submit,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF88B0D3),
          foregroundColor: Colors.white,
          elevation: 4,
          shadowColor: const Color(0xFF88B0D3).withOpacity(0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.send, size: 20),
            const SizedBox(width: 8),
            const Text(
              'Enviar contribución',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}