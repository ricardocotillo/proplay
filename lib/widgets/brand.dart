import 'package:material_ui/material_ui.dart';
import 'package:proplay/theme/app_colors.dart';

/// Logo + "ProPlay" wordmark, shared by the landing page and the top bar.
class Brand extends StatelessWidget {
  const Brand({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.titleLarge
        ?.copyWith(fontSize: 24, fontWeight: FontWeight.w800);
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Image.asset(
            'assets/images/landing/logo.webp',
            height: 36,
            semanticLabel: 'Logo de ProPlay',
          ),
        ),
        const SizedBox(width: 10),
        Text.rich(
          TextSpan(
            style: style,
            children: const [
              TextSpan(text: 'Pro'),
              TextSpan(
                text: 'Play',
                style: TextStyle(color: AppColors.selectedText),
              ),
            ],
          ),
        ),
      ],
    );
    if (onTap == null) return row;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: row,
    );
  }
}
