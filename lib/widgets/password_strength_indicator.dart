import 'package:flutter/material.dart';

class PasswordStrengthIndicator extends StatelessWidget {
  final String password;
  
  const PasswordStrengthIndicator({
    super.key,
    required this.password,
  });

  int _calculateStrength(String password) {
    int score = 0;
    
    // Length bonus
    if (password.length >= 8) score += 1;
    if (password.length >= 12) score += 1;
    if (password.length >= 16) score += 1;
    
    // Character variety
    if (password.contains(RegExp(r'[A-Z]'))) score += 1; // Uppercase
    if (password.contains(RegExp(r'[a-z]'))) score += 1; // Lowercase
    if (password.contains(RegExp(r'[0-9]'))) score += 1; // Numbers
    if (password.contains(RegExp(r'[!@#$%^&*()_+\-=\[\]{}|;:,.<>?]'))) score += 1; // Symbols
    
    // Penalty for common patterns
    if (password.toLowerCase().contains('password')) score -= 2;
    if (password.contains('123')) score -= 1;
    if (password.contains('abc')) score -= 1;
    
    return score.clamp(0, 7);
  }

  Color _getStrengthColor(int strength) {
    if (strength < 2) return Colors.red;
    if (strength < 4) return Colors.orange;
    if (strength < 6) return Colors.yellow;
    return Colors.green;
  }

  String _getStrengthText(int strength) {
    if (strength < 2) return 'Weak';
    if (strength < 4) return 'Fair';
    if (strength < 6) return 'Good';
    return 'Strong';
  }

  @override
  Widget build(BuildContext context) {
    if (password.isEmpty) {
      return const SizedBox.shrink();
    }

    final strength = _calculateStrength(password);
    final color = _getStrengthColor(strength);
    final text = _getStrengthText(strength);
    final progress = strength / 7.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Password Strength: ',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: progress,
          backgroundColor: Colors.grey[300],
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
      ],
    );
  }
} 