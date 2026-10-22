import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// Hàng chip lọc cuộn ngang, 1 chip được chọn (nền trắng chữ đen).
class ChipBar extends StatelessWidget {
  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final EdgeInsets padding;

  const ChipBar({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: padding,
        itemCount: labels.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final selected = i == selectedIndex;
          return ChoiceChip(
            label: Text(labels[i]),
            selected: selected,
            onSelected: (_) => onSelected(i),
            labelStyle: TextStyle(
              color: selected ? AppColors.chipSelectedFg : AppColors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
            visualDensity: VisualDensity.compact,
          );
        },
      ),
    );
  }
}
