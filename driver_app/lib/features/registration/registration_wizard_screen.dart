import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/auth/phone_utils.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../data/mock_data.dart';
import '../../models/registration_draft.dart';
import '../../providers/app_providers.dart';
import '../../providers/auth_provider.dart';
import '../../shared/photo_picker.dart';
import '../../shared/widgets.dart';
import 'widgets/photo_upload_tile.dart';

class RegistrationWizardScreen extends StatefulWidget {
  const RegistrationWizardScreen({super.key});

  @override
  State<RegistrationWizardScreen> createState() =>
      _RegistrationWizardScreenState();
}

class _RegistrationWizardScreenState extends State<RegistrationWizardScreen> {
  final _pageController = PageController();
  int _step = 0;
  bool _submitting = false;

  late RegistrationDraft _draft;
  late final TextEditingController _fullNameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _carMakeController;
  late final TextEditingController _carModelController;
  late final TextEditingController _carColorController;
  late final TextEditingController _carPlateController;

  @override
  void initState() {
    super.initState();
    final authPhone = context.read<AuthProvider>().phone ?? '';
    _draft = RegistrationDraft(
      phone: authPhone,
      servedClasses: const ['Стандарт'],
      docsSigned: true,
    );
    _fullNameController = TextEditingController();
    _phoneController =
        TextEditingController(text: formatPhoneForDisplay(authPhone));
    _carMakeController = TextEditingController();
    _carModelController = TextEditingController();
    _carColorController = TextEditingController();
    _carPlateController = TextEditingController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _fullNameController.dispose();
    _phoneController.dispose();
    _carMakeController.dispose();
    _carModelController.dispose();
    _carColorController.dispose();
    _carPlateController.dispose();
    super.dispose();
  }

  void _syncDraftFromFields() {
    _draft = _draft.copyWith(
      fullName: _fullNameController.text,
      phone: normalizePhone(_phoneController.text),
      carMake: _carMakeController.text,
      carModel: _carModelController.text,
      carColor: _carColorController.text,
      carPlate: _carPlateController.text.toUpperCase(),
    );
  }

  bool _validateStep(int step) {
    _syncDraftFromFields();
    return switch (step) {
      0 => _draft.personalComplete,
      1 => _draft.photosComplete,
      2 => _draft.carComplete,
      3 => _draft.tariffsComplete,
      _ => false,
    };
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 30),
      firstDate: DateTime(1950),
      lastDate: DateTime(now.year - 18),
      locale: const Locale('ru', 'RU'),
      helpText: 'Дата рождения',
    );
    if (picked != null) {
      setState(() => _draft = _draft.copyWith(birthDate: picked));
    }
  }

  Future<void> _pickPhoto(String tag, void Function(String) setter) async {
    final result = await pickImageBase64OrMock(
      context,
      mockTag: tag,
    );
    if (!mounted || result == null) return;
    final (base64, usedMock) = result;
    setter(base64);
    setState(() {});
    if (usedMock) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Фото «$tag»: демо (выбор отменён или недоступен)'),
        ),
      );
    }
  }

  Future<void> _next() async {
    if (!_validateStep(_step)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Заполните все обязательные поля шага')),
      );
      return;
    }
    if (_step < 3) {
      setState(() => _step += 1);
      await _pageController.nextPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
      return;
    }
    await _submit();
  }

  Future<void> _submit() async {
    _syncDraftFromFields();
    if (!_draft.readyToSubmit) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Заполните все данные и загрузите фото')),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      await context.read<DriverProvider>().submitRegistration(_draft);
      if (!mounted) return;
      context.go(AppRoutes.registrationStatus);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка отправки: $e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final birthLabel = _draft.birthDate == null
        ? 'Выберите дату'
        : DateFormat('d MMMM yyyy', 'ru_RU').format(_draft.birthDate!);

    return Scaffold(
      appBar: AppBar(
        title: Text('Регистрация · шаг ${_step + 1}/4'),
        leading: _step > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () async {
                  setState(() => _step -= 1);
                  await _pageController.previousPage(
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOutCubic,
                  );
                },
              )
            : null,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                for (var i = 0; i < 4; i++) ...[
                  Expanded(
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color:
                            i <= _step ? AppColors.gold : context.tokens.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  if (i < 3) const SizedBox(width: 6),
                ],
              ],
            ),
          ),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _StepScroll(
                  title: 'Личные данные',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _fullNameController,
                        decoration: const InputDecoration(
                          labelText: 'ФИО',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Телефон',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Дата рождения'),
                        subtitle: Text(birthLabel),
                        trailing: const Icon(Icons.calendar_today_outlined,
                            color: AppColors.gold),
                        onTap: _pickBirthDate,
                      ),
                    ],
                  ),
                ),
                _StepScroll(
                  title: 'Фото документов',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Нажмите на плитку, чтобы сделать фото или выбрать из галереи.',
                        style: TextStyle(
                            color: context.tokens.textMuted, fontSize: 13),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: PhotoUploadTile(
                              label: 'Паспорт\n(разворот)',
                              icon: Icons.badge_outlined,
                              uploaded: _draft.passportFrontBase64 != null,
                              onPick: () => _pickPhoto(
                                'passport',
                                (v) => _draft =
                                    _draft.copyWith(passportFrontBase64: v),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: PhotoUploadTile(
                              label: 'Селфи с\nпаспортом',
                              icon: Icons.face_retouching_natural_outlined,
                              uploaded: _draft.selfieBase64 != null,
                              onPick: () => _pickPhoto(
                                'selfie',
                                (v) =>
                                    _draft = _draft.copyWith(selfieBase64: v),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: PhotoUploadTile(
                              label: 'ВУ\n(лицевая)',
                              icon: Icons.credit_card_outlined,
                              uploaded: _draft.driverLicenseFrontBase64 != null,
                              onPick: () => _pickPhoto(
                                'license_front',
                                (v) => _draft = _draft.copyWith(
                                    driverLicenseFrontBase64: v),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: PhotoUploadTile(
                              label: 'ВУ\n(оборот)',
                              icon: Icons.credit_card_outlined,
                              uploaded: _draft.driverLicenseBackBase64 != null,
                              onPick: () => _pickPhoto(
                                'license_back',
                                (v) => _draft =
                                    _draft.copyWith(driverLicenseBackBase64: v),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: PhotoUploadTile(
                              label: 'СТС',
                              icon: Icons.description_outlined,
                              uploaded: _draft.stsBase64 != null,
                              onPick: () => _pickPhoto(
                                'sts',
                                (v) => _draft = _draft.copyWith(stsBase64: v),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: PhotoUploadTile(
                              label: 'Подпись',
                              icon: Icons.draw_outlined,
                              uploaded: _draft.signatureBase64 != null,
                              onPick: () => _pickPhoto(
                                'signature',
                                (v) => _draft = _draft.copyWith(
                                  signatureBase64: v,
                                  docsSigned: true,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                _StepScroll(
                  title: 'Автомобиль',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _carMakeController,
                        decoration: const InputDecoration(
                          labelText: 'Марка',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _carModelController,
                        decoration: const InputDecoration(
                          labelText: 'Модель',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _carColorController,
                        decoration: const InputDecoration(
                          labelText: 'Цвет',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _carPlateController,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(
                          labelText: 'Госномер',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      PhotoUploadTile(
                        label: 'Фото автомобиля',
                        icon: Icons.directions_car_filled_outlined,
                        uploaded: _draft.carPhotoBase64 != null,
                        onPick: () => _pickPhoto(
                          'car',
                          (v) => _draft = _draft.copyWith(carPhotoBase64: v),
                        ),
                      ),
                    ],
                  ),
                ),
                _StepScroll(
                  title: 'Классы тарифов',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Выберите классы, которые готовы обслуживать',
                        style: TextStyle(color: context.tokens.textSecondary),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: TariffClasses.all.map((c) {
                          final selected = _draft.servedClasses.contains(c);
                          return FilterChip(
                            label: Text(c),
                            selected: selected,
                            onSelected: (_) {
                              final next =
                                  List<String>.from(_draft.servedClasses);
                              if (selected) {
                                if (next.length <= 1) return;
                                next.remove(c);
                              } else {
                                next.add(c);
                              }
                              setState(() => _draft =
                                  _draft.copyWith(servedClasses: next));
                            },
                            selectedColor:
                                AppColors.purple.withValues(alpha: 0.3),
                            checkmarkColor: AppColors.gold,
                            labelStyle: TextStyle(
                              color: selected
                                  ? AppColors.gold
                                  : AppColors.textSecondary,
                              fontWeight:
                                  selected ? FontWeight.w600 : FontWeight.w400,
                            ),
                            side: BorderSide(
                              color: selected
                                  ? AppColors.gold
                                  : context.tokens.border,
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: ElevatedButton(
              onPressed: _submitting ? null : _next,
              child: _submitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_step < 3 ? 'Далее' : 'Отправить на проверку'),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepScroll extends StatelessWidget {
  const _StepScroll({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppColors.gold,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 16),
        SectionCard(child: child),
      ],
    );
  }
}
