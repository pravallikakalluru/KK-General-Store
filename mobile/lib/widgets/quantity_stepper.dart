import 'package:flutter/material.dart';

import '../config/theme.dart';

/// Reusable +/- quantity stepper used in the cart and product detail screen.
class QuantityStepper extends StatelessWidget {
  const QuantityStepper({
    super.key,
    required this.quantity,
    required this.onIncrement,
    required this.onDecrement,
    this.minQuantity = 1,
    this.compact = false,
  });

  final int quantity;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final int minQuantity;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 28.0 : 34.0;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.divider),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepButton(
            icon: Icons.remove,
            size: size,
            onTap: quantity > minQuantity ? onDecrement : null,
          ),
          SizedBox(
            width: compact ? 28 : 36,
            child: Text(
              '$quantity',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: compact ? 13 : 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          _StepButton(icon: Icons.add, size: size, onTap: onIncrement),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.size, required this.onTap});

  final IconData icon;
  final double size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isEnabled = onTap != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        height: size,
        width: size,
        child: Icon(
          icon,
          size: size * 0.5,
          color: isEnabled ? AppColors.primary : AppColors.textSecondary.withOpacity(0.4),
        ),
      ),
    );
  }
}
