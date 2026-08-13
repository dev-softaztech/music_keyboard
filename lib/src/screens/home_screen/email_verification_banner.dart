import 'package:flutter/material.dart';

/// Banner shown at the top of [HomeScreen] prompting an unverified user to
/// verify their email address.
class EmailVerificationBanner extends StatelessWidget {
  const EmailVerificationBanner({super.key, required this.onResend});

  final VoidCallback onResend;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 58, 16, 8),
      decoration: BoxDecoration(
        color: Colors.orange[100],
        border: Border(
          bottom: BorderSide(color: Colors.orange[300]!, width: 1),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded,
                color: Colors.orange[900], size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Please verify your email',
                style: TextStyle(
                  color: Colors.orange[900],
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            TextButton(
              onPressed: onResend,
              style: TextButton.styleFrom(
                foregroundColor: Colors.orange[900],
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'Resend',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
