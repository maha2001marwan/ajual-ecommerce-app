import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../controllers/auth_controller.dart';
import '../../core/animations/motion.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/validators.dart';
import '../../models/address.dart';
import '../../models/user_profile.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/app_header.dart';
import '../../widgets/common/avatar.dart';
import '../../widgets/common/ui.dart';
import '../checkout/add_address_screen.dart';
import '../../core/utils/navigation.dart';

/// Edit Profile (design page 33).
/// Animations: avatar flies in from the account header (Hero), avatar picker
/// sheet with pop selection, staggered fields, shake on invalid input.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final AuthController auth = Get.find<AuthController>();
  final _formKey = GlobalKey<FormState>();
  late final UserProfile? _profile = auth.userProfile;
  late final _first = TextEditingController(text: _profile?.firstName);
  late final _last = TextEditingController(text: _profile?.lastName);
  late final _phone = TextEditingController(text: _profile?.phoneNumber);
  late String _phoneCode = _profile?.phoneCode ?? 'PS +970';
  late String? _gender = _profile?.gender;
  late DateTime? _birthday = _profile?.birthday;
  late int? _avatarId = _profile?.avatarId;
  int _shake = 0;

  static const _genders = ['Female', 'Male', 'Prefer not to say'];

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _pickBirthday() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthday ?? DateTime(now.year - 20),
      firstDate: DateTime(1920),
      lastDate: DateTime(now.year - 10, now.month, now.day),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(
            context,
          ).colorScheme.copyWith(primary: Appcolors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _birthday = picked);
  }

  Future<void> _pickAvatar() async {
    final picked = await showModalBottomSheet<int>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Choose an avatar',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              const Text(
                'Photo upload needs Cloud Storage (Blaze plan).',
                style: TextStyle(fontSize: 12, color: Appcolors.secondaryText),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: staggered(
                  [
                    for (var i = 0; i < AvatarPresets.all.length; i++)
                      PressableScale(
                        onTap: () => Navigator.pop(context, i),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _avatarId == i
                                  ? Appcolors.primary
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: CircleAvatar(
                            radius: 26,
                            backgroundColor: AvatarPresets.all[i].$1,
                            child: Icon(
                              AvatarPresets.all[i].$2,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                  ],
                  stepMs: 35,
                  offset: const Offset(0, 0.4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (picked != null) setState(() => _avatarId = picked);
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      HapticFeedback.heavyImpact();
      setState(() => _shake++);
      return;
    }
    FocusScope.of(context).unfocus();
    final saved = await auth.updateProfile(
      firstName: _first.text,
      lastName: _last.text,
      phoneCode: _phoneCode,
      phoneNumber: _phone.text,
      gender: _gender,
      birthday: _birthday,
      avatarId: _avatarId,
    );
    if (saved && mounted) popPage();
  }

  @override
  Widget build(BuildContext context) {
    final preview = (_profile ?? UserProfile(uid: '')).copyWith(
      avatarId: _avatarId,
      displayName: '${_first.text} ${_last.text}'.trim(),
    );
    final codes = Regions.phoneCodes.values.toList();
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const AppHeader(title: 'Edit Profile'),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
          children: [
            Center(
              child: GestureDetector(
                onTap: _pickAvatar,
                child: Stack(
                  children: [
                    Hero(
                      tag: 'profile-avatar',
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        transitionBuilder: (child, animation) =>
                            ScaleTransition(scale: animation, child: child),
                        child: UserAvatar(
                          key: ValueKey(_avatarId),
                          profile: preview,
                          radius: 42,
                        ),
                      ),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Appcolors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(
                          Icons.edit_rounded,
                          size: 13,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            ShakeX(
              trigger: _shake,
              child: Column(
                children: staggered([
                  LabeledField(
                    label: 'First Name',
                    required: true,
                    child: TextFormField(
                      controller: _first,
                      textCapitalization: TextCapitalization.words,
                      onChanged: (_) => setState(() {}),
                      validator: (v) => Validators.required(v, 'First name'),
                      decoration: const InputDecoration(hintText: 'First name'),
                    ),
                  ),
                  LabeledField(
                    label: 'Last Name',
                    required: true,
                    child: TextFormField(
                      controller: _last,
                      textCapitalization: TextCapitalization.words,
                      onChanged: (_) => setState(() {}),
                      validator: (v) => Validators.required(v, 'Last name'),
                      decoration: const InputDecoration(hintText: 'Last name'),
                    ),
                  ),
                  LabeledField(
                    label: 'Phone Number',
                    required: true,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 118,
                          child: AppDropdown<String>(
                            items: codes,
                            value: codes.contains(_phoneCode)
                                ? _phoneCode
                                : codes.first,
                            labelOf: (v) => v,
                            onChanged: (v) =>
                                setState(() => _phoneCode = v ?? _phoneCode),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: PhoneField(controller: _phone, prefix: ''),
                        ),
                      ],
                    ),
                  ),
                  LabeledField(
                    label: 'Email',
                    required: true,
                    child: TextFormField(
                      initialValue: _profile?.email ?? '',
                      readOnly: true,
                      decoration: const InputDecoration(
                        hintText: 'Email',
                        suffixIcon: Tooltip(
                          message: 'Email is managed by your sign-in method',
                          child: Icon(Icons.lock_outline_rounded, size: 18),
                        ),
                      ),
                    ),
                  ),
                  LabeledField(
                    label: 'Gender',
                    child: AppDropdown<String>(
                      items: _genders,
                      value: _gender,
                      labelOf: (v) => v,
                      onChanged: (v) => setState(() => _gender = v),
                    ),
                  ),
                  LabeledField(
                    label: 'Birthday',
                    child: InkWell(
                      onTap: _pickBirthday,
                      borderRadius: BorderRadius.circular(8),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          suffixIcon: Icon(Icons.keyboard_arrow_down_rounded),
                        ),
                        child: Text(
                          _birthday == null
                              ? 'mm/dd/yyyy'
                              : DateFormats.numeric(_birthday!),
                          style: TextStyle(
                            fontSize: 14,
                            color: _birthday == null
                                ? Appcolors.hint
                                : Appcolors.text,
                          ),
                        ),
                      ),
                    ),
                  ),
                ], stepMs: 50),
              ),
            ),
            const SizedBox(height: 12),
            Obx(
              () => AppButton(
                label: 'Save',
                loading: auth.isBusy.value,
                onPressed: _save,
              ),
            ),
            const EncryptedNote(),
          ],
        ),
      ),
    );
  }
}
