import 'package:flutter/material.dart';
import 'package:achuar_ingis/theme/app_theme.dart';

class AppTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String? hintText;
  final String? labelText;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final int maxLines;
  final bool readOnly;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final String? errorText;
  final TextInputType? keyboardType;
  final bool autofocus;

  const AppTextField({
    super.key,
    this.controller,
    this.hintText,
    this.labelText,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.maxLines = 1,
    this.readOnly = false,
    this.onChanged,
    this.onTap,
    this.errorText,
    this.keyboardType,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return TextField(
      controller: controller,
      obscureText: obscureText,
      maxLines: obscureText ? 1 : maxLines,
      readOnly: readOnly,
      onChanged: onChanged,
      onTap: onTap,
      keyboardType: keyboardType,
      autofocus: autofocus,
      style: theme.textTheme.bodyLarge,
      decoration: InputDecoration(
        hintText: hintText,
        labelText: labelText,
        errorText: errorText,
        prefixIcon: prefixIcon != null 
            ? Icon(prefixIcon, size: 20) 
            : null,
        suffixIcon: suffixIcon,
      ),
    );
  }
}
