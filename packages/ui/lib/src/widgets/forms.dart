import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// The standard input (style §8). Surface-variant fill, 2px accent border on
/// focus, error text below.
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.icon,
    this.obscure = false,
    this.error,
    this.onChanged,
    this.onSubmitted,
    this.keyboardType,
    this.maxLines = 1,
    this.autofocus = false,
    this.accent,
  });

  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final IconData? icon;
  final bool obscure;
  final String? error;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputType? keyboardType;
  final int maxLines;
  final bool autofocus;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final a = accent ?? t.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 6, left: 4),
            child: Text(label!, style: Theme.of(context).textTheme.labelLarge),
          ),
        TextField(
          controller: controller,
          obscureText: obscure,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          keyboardType: keyboardType,
          maxLines: obscure ? 1 : maxLines,
          autofocus: autofocus,
          style: Theme.of(context).textTheme.bodyLarge,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: t.textFaint),
            prefixIcon: icon == null ? null : Icon(icon, color: t.textMuted, size: 20),
            filled: true,
            fillColor: t.surfaceAlt,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: t.radii.inputR,
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: t.radii.inputR,
              borderSide: BorderSide(color: t.border, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: t.radii.inputR,
              borderSide: BorderSide(color: a, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: t.radii.inputR,
              borderSide: BorderSide(color: t.danger, width: 2),
            ),
          ),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(error!, style: TextStyle(color: t.danger, fontSize: 12.5)),
          ),
      ],
    );
  }
}

/// A rounded search field with a leading magnifier.
class SearchField extends StatelessWidget {
  const SearchField({
    super.key,
    this.controller,
    this.hint = 'Search',
    this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
    this.onTap,
    this.readOnly = false,
    this.trailing,
  });

  final TextEditingController? controller;
  final String hint;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;
  final VoidCallback? onTap;
  final bool readOnly;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return TextField(
      controller: controller,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      autofocus: autofocus,
      readOnly: readOnly,
      onTap: onTap,
      style: Theme.of(context).textTheme.bodyMedium,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: t.textFaint),
        prefixIcon: Icon(Icons.search_rounded, color: t.textMuted, size: 20),
        suffixIcon: trailing,
        filled: true,
        fillColor: t.surfaceAlt,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: t.radii.pillR,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: t.radii.pillR,
          borderSide: BorderSide(color: t.border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: t.radii.pillR,
          borderSide: BorderSide(color: t.primary, width: 1.5),
        ),
      ),
    );
  }
}

/// A labelled switch row used in settings.
class AppSwitchTile extends StatelessWidget {
  const AppSwitchTile({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.icon,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: t.radii.cardR,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, color: t.textMuted, size: 20),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleSmall),
                  if (subtitle != null)
                    Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeTrackColor: t.primary,
            ),
          ],
        ),
      ),
    );
  }
}
