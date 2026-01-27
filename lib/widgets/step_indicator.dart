import 'package:flutter/material.dart';

class StepIndicator extends StatelessWidget {
  final int currentStep;
  final int totalSteps;
  final List<String>? stepLabels;

  const StepIndicator({
    super.key,
    required this.currentStep,
    required this.totalSteps,
    this.stepLabels,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: List.generate(totalSteps * 2 - 1, (index) {
          if (index.isOdd) {
            // Connector line
            final stepIndex = index ~/ 2;
            final isCompleted = stepIndex < currentStep;
            return Expanded(
              child: Container(
                height: 2,
                color: isCompleted
                    ? colorScheme.primary
                    : colorScheme.outlineVariant,
              ),
            );
          } else {
            // Step circle
            final stepIndex = index ~/ 2;
            final isActive = stepIndex == currentStep;
            final isCompleted = stepIndex < currentStep;

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isActive || isCompleted
                        ? colorScheme.primary
                        : colorScheme.surfaceContainerHighest,
                    border: Border.all(
                      color: isActive || isCompleted
                          ? colorScheme.primary
                          : colorScheme.outlineVariant,
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: isCompleted
                        ? Icon(
                            Icons.check,
                            size: 18,
                            color: colorScheme.onPrimary,
                          )
                        : Text(
                            '${stepIndex + 1}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isActive
                                  ? colorScheme.onPrimary
                                  : colorScheme.onSurfaceVariant,
                            ),
                          ),
                  ),
                ),
                if (stepLabels != null && stepIndex < stepLabels!.length) ...[
                  const SizedBox(height: 4),
                  Text(
                    stepLabels![stepIndex],
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: isActive || isCompleted
                              ? colorScheme.primary
                              : colorScheme.onSurfaceVariant,
                          fontWeight:
                              isActive ? FontWeight.bold : FontWeight.normal,
                        ),
                  ),
                ],
              ],
            );
          }
        }),
      ),
    );
  }
}
