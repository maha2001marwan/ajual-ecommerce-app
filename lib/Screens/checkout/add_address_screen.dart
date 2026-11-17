import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../controllers/address_controller.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/checkout_controller.dart';
import '../../core/animations/motion.dart';
import '../../core/utils/validators.dart';
import '../../models/address.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/app_header.dart';
import '../../widgets/common/ui.dart';
import '../../core/utils/navigation.dart';

/// Add / edit delivery address (design page 22).
/// Animations: staggered sections, dependent State/City dropdowns cross-fade
/// when the country changes, default checkbox, shake on invalid fields,
/// save button morph.
class AddAddressScreen extends StatefulWidget {
  const AddAddressScreen({super.key, this.initial});

  final Address? initial;

  @override
  State<AddAddressScreen> createState() => _AddAddressScreenState();
}

class _AddAddressScreenState extends State<AddAddressScreen> {
  final AddressController addresses = Get.find<AddressController>();
  final _formKey = GlobalKey<FormState>();
  late final _first = TextEditingController(text: widget.initial?.firstName);
  late final _last = TextEditingController(text: widget.initial?.lastName);
  late final _company = TextEditingController(text: widget.initial?.company);
  late final _phone = TextEditingController(text: widget.initial?.phone);
  late final _line1 = TextEditingController(text: widget.initial?.line1);
  late final _line2 = TextEditingController(text: widget.initial?.line2);
  late final _postal = TextEditingController(text: widget.initial?.postalCode);
  late String _country = widget.initial?.country ?? 'Palestine (PS)';
  late String? _state = widget.initial?.state;
  late String? _city = widget.initial?.city;
  late bool _isDefault =
      widget.initial?.isDefault ?? addresses.addresses.isEmpty;
  int _shake = 0;

  bool get _editing => widget.initial != null;

  @override
  void initState() {
    super.initState();
    if (widget.initial == null) {
      final profile = Get.find<AuthController>().userProfile;
      _first.text = profile?.firstName ?? '';
      _last.text = profile?.lastName ?? '';
      _phone.text = profile?.phoneNumber ?? '';
    }
    if (!Regions.countries.contains(_country)) {
      _country = Regions.countries.first;
    }
  }

  @override
  void dispose() {
    for (final c in [
      _first,
      _last,
      _company,
      _phone,
      _line1,
      _line2,
      _postal,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      HapticFeedback.heavyImpact();
      setState(() => _shake++);
      return;
    }
    FocusScope.of(context).unfocus();
    final address = Address(
      id: widget.initial?.id ?? '',
      country: _country,
      firstName: _first.text.trim(),
      lastName: _last.text.trim(),
      company: _company.text.trim(),
      phoneCode: Regions.phoneCodes[_country] ?? '',
      phone: _phone.text.trim(),
      line1: _line1.text.trim(),
      line2: _line2.text.trim(),
      state: _state ?? '',
      city: _city ?? '',
      postalCode: _postal.text.trim(),
      isDefault: _isDefault,
    );
    final id = await addresses.save(address);
    if (id == null) return;
    if (Get.isRegistered<CheckoutController>()) {
      Get.find<CheckoutController>().addressId.value = id;
    }
    if (mounted) popPage();
  }

  Future<void> _delete() async {
    final initial = widget.initial;
    if (initial == null) return;
    await addresses.delete(initial);
    if (mounted) popPage();
  }

  @override
  Widget build(BuildContext context) {
    final states = Regions.statesOf(_country);
    final cities = _state == null
        ? const <String>[]
        : Regions.citiesOf(_country, _state!);
    return Scaffold(
      backgroundColor: Appcolors.section,
      appBar: AppHeader(
        title: _editing ? 'Edit Delivery Address' : 'Add Delivery Address',
        actions: [
          if (_editing)
            IconButton(
              tooltip: 'Delete address',
              onPressed: _delete,
              icon: const Icon(Icons.delete_outline_rounded),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ShakeX(
          trigger: _shake,
          child: ListView(
            padding: EdgeInsets.zero,
            children: staggered([
              SectionCard(
                title: 'Country / Region',
                child: AppDropdown<String>(
                  items: Regions.countries,
                  value: _country,
                  labelOf: (v) => v,
                  onChanged: (v) => setState(() {
                    _country = v ?? _country;
                    _state = null;
                    _city = null;
                  }),
                ),
              ),
              SectionCard(
                title: 'Contact Information',
                child: Column(
                  children: [
                    LabeledField(
                      label: 'First Name',
                      required: true,
                      child: TextFormField(
                        controller: _first,
                        textCapitalization: TextCapitalization.words,
                        autofillHints: const [AutofillHints.givenName],
                        validator: (v) => Validators.required(v, 'First name'),
                        decoration: const InputDecoration(
                          hintText: 'First name',
                        ),
                      ),
                    ),
                    LabeledField(
                      label: 'Last Name',
                      required: true,
                      child: TextFormField(
                        controller: _last,
                        textCapitalization: TextCapitalization.words,
                        autofillHints: const [AutofillHints.familyName],
                        validator: (v) => Validators.required(v, 'Last name'),
                        decoration: const InputDecoration(
                          hintText: 'Last name',
                        ),
                      ),
                    ),
                    LabeledField(
                      label: 'Company Name',
                      child: TextFormField(
                        controller: _company,
                        decoration: const InputDecoration(
                          hintText: 'Company name',
                        ),
                      ),
                    ),
                    LabeledField(
                      label: 'Phone Number',
                      required: true,
                      child: PhoneField(
                        controller: _phone,
                        prefix: Regions.phoneCodes[_country] ?? '',
                      ),
                    ),
                  ],
                ),
              ),
              SectionCard(
                title: 'Shipping Address',
                child: Column(
                  children: [
                    LabeledField(
                      label: 'Address Line 1',
                      required: true,
                      child: TextFormField(
                        controller: _line1,
                        autofillHints: const [AutofillHints.streetAddressLine1],
                        validator: (v) => Validators.required(v, 'Address'),
                        decoration: const InputDecoration(
                          hintText: 'Street name and number',
                        ),
                      ),
                    ),
                    LabeledField(
                      label: 'Address Line 2',
                      child: TextFormField(
                        controller: _line2,
                        autofillHints: const [AutofillHints.streetAddressLine2],
                        decoration: const InputDecoration(
                          hintText:
                              'Building/apt/block., floor, entrance code, etc.',
                        ),
                      ),
                    ),
                    LabeledField(
                      label: 'State/Province',
                      required: true,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 260),
                        child: KeyedSubtree(
                          key: ValueKey('state-$_country'),
                          child: AppDropdown<String>(
                            items: states,
                            value: _state,
                            hint: 'State/Province',
                            labelOf: (v) => v,
                            validator: (v) =>
                                v == null ? 'Select a state' : null,
                            onChanged: (v) => setState(() {
                              _state = v;
                              _city = null;
                            }),
                          ),
                        ),
                      ),
                    ),
                    LabeledField(
                      label: 'City',
                      required: true,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 260),
                        child: KeyedSubtree(
                          key: ValueKey('city-$_country-$_state'),
                          child: AppDropdown<String>(
                            items: cities,
                            value: _city,
                            hint: 'City',
                            labelOf: (v) => v,
                            validator: (v) =>
                                v == null ? 'Select a city' : null,
                            onChanged: cities.isEmpty
                                ? null
                                : (v) => setState(() => _city = v),
                          ),
                        ),
                      ),
                    ),
                    LabeledField(
                      label: 'Post/Zip Code',
                      required: true,
                      child: TextFormField(
                        controller: _postal,
                        autofillHints: const [AutofillHints.postalCode],
                        validator: Validators.postalCode,
                        decoration: const InputDecoration(
                          hintText: 'Post/Zip code',
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () => setState(() => _isDefault = !_isDefault),
                      child: Row(
                        children: [
                          Checkbox(
                            value: _isDefault,
                            onChanged: (v) =>
                                setState(() => _isDefault = v ?? false),
                          ),
                          const Text(
                            'Set as default shipping address',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
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
                        label: 'Save',
                        loading: addresses.isSaving.value,
                        onPressed: _save,
                      ),
                    ),
                    const EncryptedNote(),
                  ],
                ),
              ),
            ], stepMs: 60),
          ),
        ),
      ),
    );
  }
}

/// Phone input with a country prefix ("UK +44 | Enter your phone number").
class PhoneField extends StatelessWidget {
  const PhoneField({super.key, required this.controller, required this.prefix});

  final TextEditingController controller;
  final String prefix;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.phone,
      autofillHints: const [AutofillHints.telephoneNumberNational],
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9 \-]'))],
      validator: Validators.localPhone,
      decoration: InputDecoration(
        hintText: 'Enter your phone number',
        prefixIcon: prefix.isEmpty
            ? null
            : Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                margin: const EdgeInsets.only(right: 10),
                decoration: const BoxDecoration(
                  border: Border(right: BorderSide(color: Appcolors.border)),
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: Text(
                    prefix,
                    key: ValueKey(prefix),
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
        prefixIconConstraints: const BoxConstraints(minHeight: 24, minWidth: 0),
      ),
    );
  }
}
