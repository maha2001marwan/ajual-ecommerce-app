import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../controllers/payment_controller.dart';
import '../../core/animations/motion.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/validators.dart';
import '../../models/payment_card.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/app_header.dart';
import '../../widgets/common/ui.dart';
import 'card_sheet.dart';
import '../../core/utils/navigation.dart';

/// Add New Card (design page 24). Only brand, last 4 digits, holder and
/// expiry are saved; the CVV never leaves the form.
/// Animations: live card preview that flips in 3D to its back while the CVV
/// is focused, brand logo cross-fades as it's detected, pulsing shield,
/// staggered form, shake on invalid input.
class AddCardScreen extends StatefulWidget {
  const AddCardScreen({super.key});

  @override
  State<AddCardScreen> createState() => _AddCardScreenState();
}

class _AddCardScreenState extends State<AddCardScreen>
    with SingleTickerProviderStateMixin {
  final PaymentController payments = Get.find<PaymentController>();
  final _formKey = GlobalKey<FormState>();
  final _number = TextEditingController();
  final _expiry = TextEditingController();
  final _cvv = TextEditingController();
  final _holder = TextEditingController();
  final _address = TextEditingController();
  final _postal = TextEditingController();
  final _cvvFocus = FocusNode();
  late final AnimationController _flip = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );
  int _shake = 0;

  @override
  void initState() {
    super.initState();
    for (final c in [_number, _expiry, _cvv, _holder]) {
      c.addListener(() => setState(() {}));
    }
    _cvvFocus.addListener(() {
      if (_cvvFocus.hasFocus) {
        _flip.forward();
      } else {
        _flip.reverse();
      }
    });
  }

  @override
  void dispose() {
    for (final c in [_number, _expiry, _cvv, _holder, _address, _postal]) {
      c.dispose();
    }
    _cvvFocus.dispose();
    _flip.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      HapticFeedback.heavyImpact();
      setState(() => _shake++);
      return;
    }
    FocusScope.of(context).unfocus();
    final card = await payments.addCard(
      number: _number.text,
      expiry: _expiry.text,
      holder: _holder.text,
      billingAddress: _address.text,
      postalCode: _postal.text,
    );
    if (card != null && mounted) popPage(card);
  }

  @override
  Widget build(BuildContext context) {
    final brand = CardBrand.detect(_number.text);
    return Scaffold(
      backgroundColor: Appcolors.section,
      appBar: const AppHeader(title: 'Add New Card'),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.zero,
          children: staggered([
            Container(
              color: Appcolors.protectedBg,
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _PulsingShield(),
                  SizedBox(width: 8),
                  Text(
                    'Your card details are protected',
                    style: TextStyle(color: Appcolors.success, fontSize: 12.5),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
              child: _CardPreview(
                flip: _flip,
                brand: brand,
                number: _number.text,
                holder: _holder.text,
                expiry: _expiry.text,
                cvv: _cvv.text,
              ),
            ),
            ShakeX(
              trigger: _shake,
              child: SectionCard(
                title: 'Card Details',
                trailing: const Row(
                  children: [
                    CardBrandLogo(brand: CardBrand.visa),
                    SizedBox(width: 6),
                    CardBrandLogo(brand: CardBrand.mastercard),
                    SizedBox(width: 6),
                    CardBrandLogo(brand: CardBrand.jcb),
                  ],
                ),
                child: Column(
                  children: [
                    LabeledField(
                      label: 'Card Number',
                      child: TextFormField(
                        controller: _number,
                        keyboardType: TextInputType.number,
                        autofillHints: const [AutofillHints.creditCardNumber],
                        inputFormatters: [CardNumberInputFormatter()],
                        validator: Validators.cardNumber,
                        decoration: InputDecoration(
                          hintText: '0000 0000 0000 0000',
                          suffixIcon: Padding(
                            padding: const EdgeInsets.all(12),
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 260),
                              transitionBuilder: (child, animation) =>
                                  ScaleTransition(
                                    scale: animation,
                                    child: child,
                                  ),
                              child: brand == CardBrand.unknown
                                  ? const SizedBox(key: ValueKey('none'))
                                  : KeyedSubtree(
                                      key: ValueKey(brand),
                                      child: CardBrandLogo(brand: brand),
                                    ),
                            ),
                          ),
                          suffixIconConstraints: const BoxConstraints(
                            minWidth: 48,
                          ),
                        ),
                      ),
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: LabeledField(
                            label: 'Expiry Date',
                            child: TextFormField(
                              controller: _expiry,
                              keyboardType: TextInputType.number,
                              autofillHints: const [
                                AutofillHints.creditCardExpirationDate,
                              ],
                              inputFormatters: [ExpiryDateInputFormatter()],
                              validator: Validators.expiry,
                              decoration: const InputDecoration(
                                hintText: 'MM/YY',
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: LabeledField(
                            label: 'CVV',
                            child: TextFormField(
                              controller: _cvv,
                              focusNode: _cvvFocus,
                              keyboardType: TextInputType.number,
                              obscureText: true,
                              obscuringCharacter: '*',
                              autofillHints: const [
                                AutofillHints.creditCardSecurityCode,
                              ],
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(4),
                              ],
                              validator: Validators.cvv,
                              decoration: const InputDecoration(
                                hintText: '***',
                                suffixIcon: Tooltip(
                                  message:
                                      '3 or 4 digits on the back of your card. It is never stored.',
                                  child: Icon(
                                    Icons.info_outline_rounded,
                                    size: 18,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    LabeledField(
                      label: 'Name on Card',
                      child: TextFormField(
                        controller: _holder,
                        textCapitalization: TextCapitalization.words,
                        autofillHints: const [AutofillHints.creditCardName],
                        validator: Validators.name,
                        decoration: const InputDecoration(hintText: 'Name'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SectionCard(
              title: 'Billing Address',
              child: Column(
                children: [
                  LabeledField(
                    label: 'Address',
                    child: TextFormField(
                      controller: _address,
                      autofillHints: const [AutofillHints.fullStreetAddress],
                      validator: (v) => Validators.required(v, 'Address'),
                      decoration: const InputDecoration(
                        hintText: 'Street name and number',
                      ),
                    ),
                  ),
                  LabeledField(
                    label: 'Postal Code',
                    child: TextFormField(
                      controller: _postal,
                      autofillHints: const [AutofillHints.postalCode],
                      validator: Validators.postalCode,
                      decoration: const InputDecoration(
                        hintText: 'Postal Code',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              child: Column(
                children: [
                  Obx(
                    () => AppButton(
                      label: 'Submit',
                      loading: payments.isSaving.value,
                      onPressed: _submit,
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Text(
                      'Demo payments: cards are saved for checkout but never charged.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        color: Appcolors.secondaryText,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ], stepMs: 60),
        ),
      ),
    );
  }
}

class _PulsingShield extends StatefulWidget {
  const _PulsingShield();

  @override
  State<_PulsingShield> createState() => _PulsingShieldState();
}

class _PulsingShieldState extends State<_PulsingShield>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween<double>(
        begin: 0.9,
        end: 1.12,
      ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut)),
      child: const Icon(
        Icons.verified_user_outlined,
        color: Appcolors.success,
        size: 18,
      ),
    );
  }
}

/// Front/back card mock-up that turns over in 3D.
class _CardPreview extends StatelessWidget {
  const _CardPreview({
    required this.flip,
    required this.brand,
    required this.number,
    required this.holder,
    required this.expiry,
    required this.cvv,
  });

  final Animation<double> flip;
  final CardBrand brand;
  final String number;
  final String holder;
  final String expiry;
  final String cvv;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.62,
      child: AnimatedBuilder(
        animation: flip,
        builder: (context, _) {
          final angle = Curves.easeInOutCubic.transform(flip.value) * math.pi;
          final showBack = angle > math.pi / 2;
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0012)
              ..rotateY(angle),
            child: showBack
                ? Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()..rotateY(math.pi),
                    child: _back(),
                  )
                : _front(),
          );
        },
      ),
    );
  }

  BoxDecoration get _decoration => BoxDecoration(
    borderRadius: BorderRadius.circular(16),
    gradient: const LinearGradient(
      colors: [Color(0xFF111111), Color(0xFF3A3A3A)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    boxShadow: const [
      BoxShadow(
        color: Color(0x40000000),
        blurRadius: 18,
        offset: Offset(0, 10),
      ),
    ],
  );

  Widget _front() {
    final digits = number.replaceAll(' ', '');
    final padded = digits.padRight(16, '•');
    final groups = [
      for (var i = 0; i < 16; i += 4) padded.substring(i, i + 4),
    ].join('  ');
    return Container(
      decoration: _decoration,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 26,
                decoration: BoxDecoration(
                  color: const Color(0xFFD4AF37),
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              const Spacer(),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                child: KeyedSubtree(
                  key: ValueKey(brand),
                  child: CardBrandLogo(brand: brand, light: true),
                ),
              ),
            ],
          ),
          const Spacer(),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              groups,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 19,
                letterSpacing: 1.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(
                  holder.isEmpty ? 'CARD HOLDER' : holder.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    letterSpacing: 1,
                  ),
                ),
              ),
              Text(
                expiry.isEmpty ? 'MM/YY' : expiry,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _back() {
    return Container(
      decoration: _decoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const SizedBox(height: 22),
          Container(height: 40, color: Colors.black),
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              width: 90,
              height: 34,
              alignment: Alignment.center,
              color: Colors.white,
              child: Text(
                cvv.isEmpty ? 'CVV' : '*' * cvv.length,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
