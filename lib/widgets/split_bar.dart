import 'package:expenses_tracker/models/shared_tracker.dart';
import 'package:flutter/material.dart' hide Split;

/// A horizontal bar that visualises how a shared expense is split among members.
///
/// Each member's portion is rendered as a coloured segment proportional to
/// their [Split.amount] relative to [totalAmount].
class SplitBar extends StatelessWidget {
  final double totalAmount;
  final List<Split> splits;
  final List<TrackerMember> members;
  final double height;
  final BorderRadius? borderRadius;

  const SplitBar({
    super.key,
    required this.totalAmount,
    required this.splits,
    required this.members,
    this.height = 8,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    if (totalAmount <= 0 || splits.isEmpty) {
      return const SizedBox.shrink();
    }

    // If split amounts exceed the total, scale everything down to fit the bar.
    final splitSum = splits.fold<double>(0, (s, e) => s + e.amount);
    final denominator = splitSum > totalAmount ? splitSum : totalAmount;

    return LayoutBuilder(
      builder: (context, constraints) {
        final total = constraints.maxWidth;
        final radius = borderRadius ?? BorderRadius.circular(height / 2);

        return ClipRRect(
          borderRadius: radius,
          child: Row(
            children: splits.map((split) {
              final frac = (split.amount / denominator).clamp(0.0, 1.0);
              final member = members.firstWhere(
                (m) => m.uid == split.uid,
                orElse: () => TrackerMember(
                  uid: split.uid,
                  displayName: split.displayName,
                  colorValue: const Color(0xFF88ACA2).toARGB32(),
                ),
              );
              return SizedBox(
                width: total * frac,
                height: height,
                child: ColoredBox(color: member.color),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}

/// A legend row showing each member's colour dot, name, amount and percentage.
class SplitLegend extends StatelessWidget {
  final double totalAmount;
  final List<Split> splits;
  final List<TrackerMember> members;
  final String Function(double) formatAmount;

  const SplitLegend({
    super.key,
    required this.totalAmount,
    required this.splits,
    required this.members,
    required this.formatAmount,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: splits.map((split) {
        final member = members.firstWhere(
          (m) => m.uid == split.uid,
          orElse: () => TrackerMember(
            uid: split.uid,
            displayName: split.displayName,
            colorValue: const Color(0xFF88ACA2).toARGB32(),
          ),
        );
        final pct = totalAmount > 0
            ? (split.amount / totalAmount * 100).toStringAsFixed(1)
            : '0.0';

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: member.color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  member.displayName,
                  style: const TextStyle(fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                formatAmount(split.amount),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 6),
              SizedBox(
                width: 48,
                child: Text(
                  '$pct%',
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    fontSize: 12,
                    color: member.color,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
