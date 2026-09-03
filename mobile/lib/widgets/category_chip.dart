import 'package:flutter/material.dart';

import '../config/theme.dart';

/// Reusable selectable chip for category filtering (customer home screen).
class CategoryChip extends StatelessWidget {
  const CategoryChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Container(
        // A soft shadow under every chip (a stronger, colored one when
        // selected) lifts the filter row off the page the same way the
        // product cards below it are lifted - small but part of reading
        // the whole screen as layered/elevated rather than flat.
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: selected
                  ? AppColors.primary.withOpacity(0.28)
                  : Colors.black.withOpacity(0.05),
              blurRadius: selected ? 10 : 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ChoiceChip(
          label: Text(label),
          selected: selected,
          onSelected: (_) => onTap(),
          selectedColor: AppColors.primary,
          labelStyle: TextStyle(
            color: selected ? Colors.white : AppColors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: selected ? AppColors.primary : AppColors.divider,
            ),
          ),
          showCheckmark: false,
        ),
      ),
    );
  }
}
