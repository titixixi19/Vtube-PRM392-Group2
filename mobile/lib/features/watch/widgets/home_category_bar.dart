import 'package:flutter/material.dart';

import '../../../app/theme.dart';

/// Đại diện cho 1 chip danh mục trên Trang chủ.
class CategoryChipItem {
  final String label;
  final String? slug;
  final IconData? icon;

  const CategoryChipItem({
    required this.label,
    this.slug,
    this.icon,
  });
}

/// Thanh chip danh mục nằm ngang ghim dưới AppBar Trang chủ.
class HomeCategoryBar extends StatelessWidget implements PreferredSizeWidget {
  final List<CategoryChipItem> categories;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const HomeCategoryBar({
    super.key,
    required this.categories,
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Size get preferredSize => const Size.fromHeight(48.0);

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) return const SizedBox(height: 48);

    return Container(
      height: 48,
      color: AppColors.surface,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final item = categories[index];
          final selected = index == selectedIndex;

          return ChoiceChip(
            avatar: item.icon != null
                ? Icon(
                    item.icon,
                    size: 18,
                    color: selected ? AppColors.chipSelectedFg : AppColors.textPrimary,
                  )
                : null,
            label: Text(item.label),
            selected: selected,
            onSelected: (_) => onSelected(index),
            labelStyle: TextStyle(
              color: selected ? AppColors.chipSelectedFg : AppColors.textPrimary,
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
            visualDensity: VisualDensity.compact,
          );
        },
      ),
    );
  }
}
