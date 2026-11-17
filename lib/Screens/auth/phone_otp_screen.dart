import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/auth_controller.dart';

class PhoneOtpScreen extends StatefulWidget {
  const PhoneOtpScreen({super.key, required this.phoneNumber});

  final String phoneNumber;

  @override
  State<PhoneOtpScreen> createState() => _PhoneOtpScreenState();
}

class _PhoneOtpScreenState extends State<PhoneOtpScreen> {
  final AuthController auth = Get.find<AuthController>();
  final _codeController = TextEditingController();

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_codeController.text.trim().length < 6) {
      Get.snackbar('Invalid code', 'Enter the 6-digit code from the SMS.');
      return;
    }
    final ok = await auth.confirmPhoneCode(_codeController.text.trim());
    if (ok && mounted) {
      Get.until((route) => route.isFirst);
    }
  }

  Future<void> _resend() async {
    final started = await auth.startPhoneVerification(widget.phoneNumber);
    if (started) {
      Get.snackbar('Code sent', 'A new verification code was sent.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verify phone')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.sms_outlined, size: 56),
              const SizedBox(height: 16),
              Text(
                'Enter the code sent to\n${widget.phoneNumber}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _codeController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 6,
                style: const TextStyle(fontSize: 24, letterSpacing: 8),
                decoration: const InputDecoration(
                  counterText: '',
                  border: OutlineInputBorder(),
                  hintText: '------',
                ),
                onSubmitted: (_) => _verify(),
              ),
              const SizedBox(height: 24),
              Obx(
                () => ElevatedButton(
                  onPressed: auth.isBusy.value ? null : _verify,
                  child: auth.isBusy.value
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Verify'),
                ),
              ),
              TextButton(
                onPressed: auth.isBusy.value ? null : _resend,
                child: const Text('Resend code'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
