import 'package:flutter/material.dart';

class ProfileCompletionIndicator extends StatelessWidget {
  final double completionPercentage;
  final bool showPercentage;
  final double size;
  final double strokeWidth;
  final Color progressColor;
  final Color backgroundColor;
  final TextStyle? percentageStyle;

  const ProfileCompletionIndicator({
    Key? key,
    required this.completionPercentage,
    this.showPercentage = true,
    this.size = 60,
    this.strokeWidth = 4,
    this.progressColor = const Color(0xFF35C2C1),
    this.backgroundColor = Colors.grey,
    this.percentageStyle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: size,
          width: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: completionPercentage / 100,
                strokeWidth: strokeWidth,
                backgroundColor: backgroundColor.withOpacity(0.2),
                valueColor: AlwaysStoppedAnimation<Color>(progressColor),
              ),
              if (showPercentage)
                Text(
                  '${completionPercentage.toInt()}%',
                  style: percentageStyle ?? const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
} 