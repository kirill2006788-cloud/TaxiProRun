import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/router/app_router.dart';
import '../../core/config/feature_flags.dart';
import '../../core/theme/app_theme.dart';
import '../../data/mock_data.dart';
import '../../features/info/info_screens.dart';
import '../../providers/app_providers.dart';
import '../../shared/photo_picker.dart';
import '../../shared/registration_status_badge.dart';
import '../../shared/widgets.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _requestedFullProfile = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_requestedFullProfile) return;
    _requestedFullProfile = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<DriverProvider>().loadFullProfile();
    });
  }

  Future<void> _uploadAvatar(BuildContext context) async {
    final result = await pickImageBase64OrMock(
      context,
      mockTag: 'avatar',
    );
    if (!context.mounted || result == null) return;
    final (base64, usedMock) = result;
    final provider = context.read<DriverProvider>();
    final saved = await provider.uploadProfileMedia(
      field: 'avatarBase64',
      base64: base64,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          !saved
              ? provider.profileError ?? 'Не удалось сохранить фото профиля'
              : usedMock
                  ? 'Фото профиля: демо (выбор отменён или недоступен)'
                  : 'Фото профиля обновлено',
        ),
      ),
    );
  }

  Future<void> _uploadCarPhoto(BuildContext context) async {
    final result = await pickImageBase64OrMock(
      context,
      mockTag: 'car',
    );
    if (!context.mounted || result == null) return;
    final (base64, usedMock) = result;
    final provider = context.read<DriverProvider>();
    final saved = await provider.uploadProfileMedia(
      field: 'carPhotoBase64',
      base64: base64,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          !saved
              ? provider.profileError ?? 'Не удалось сохранить фото автомобиля'
              : usedMock
                  ? 'Фото авто: демо (выбор отменён или недоступен)'
                  : 'Фото авто обновлено',
        ),
      ),
    );
  }

  Future<void> _uploadDoc(BuildContext context, String doc) async {
    final result = await pickImageBase64OrMock(
      context,
      mockTag: doc,
    );
    if (!context.mounted || result == null) return;
    final (base64, usedMock) = result;
    final provider = context.read<DriverProvider>();
    const fields = <String, String>{
      'passport': 'passportFrontBase64',
      'selfie': 'selfieBase64',
      'license': 'driverLicenseBackBase64',
      'sts': 'stsBase64',
      'osago': 'osagoBase64',
    };
    final field = fields[doc];
    if (field == null) return;
    final saved =
        await provider.uploadProfileMedia(field: field, base64: base64);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          !saved
              ? provider.profileError ?? 'Не удалось сохранить документ'
              : usedMock
                  ? 'Документ «$doc»: демо (выбор отменён или недоступен)'
                  : 'Документ «$doc» загружен',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final driver = context.watch<DriverProvider>();
    final profile = driver.profile;
    final car = profile.car;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Профиль'),
        actions: [
          IconButton(
            tooltip: 'Настройки',
            onPressed: () => context.push(AppRoutes.settings),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _ProfileHeader(
            name: profile.name,
            phone: profile.phone,
            rating: profile.rating,
            reviewCount: profile.reviewCount,
            isVerified: profile.isVerified,
            hasAvatar: profile.hasAvatar,
            avatarBase64: profile.avatarBase64,
            registrationStatus: profile.registrationStatus,
            onUploadAvatar: () => _uploadAvatar(context),
          ),
          const SizedBox(height: 16),
          if (!profile.registrationComplete)
            SectionCard(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Статус регистрации',
                          style: TextStyle(
                            color: context.tokens.textMuted,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 8),
                        RegistrationStatusBadge(
                            status: profile.registrationStatus),
                        const SizedBox(height: 8),
                        Text(
                          registrationStatusSubtitle(profile),
                          style: TextStyle(
                            color: context.tokens.textSecondary,
                            fontSize: 13,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      if (profile.needsRegistration) {
                        context.push(AppRoutes.registration);
                      } else {
                        context.push(AppRoutes.registrationStatus);
                      }
                    },
                    child: const Text('Открыть'),
                  ),
                ],
              ),
            ),
          if (!profile.registrationComplete) const SizedBox(height: 8),
          _EarningsWidget(
            today: profile.earningsToday,
            week: profile.earningsWeek,
            month: profile.earningsMonth,
            tipsToday: profile.tipsToday,
            commissionPercent: profile.commissionPercent,
          ),
          const SizedBox(height: 8),
          const SectionTitle('Автомобиль'),
          _CarSection(
            makeModel: car.makeModel,
            color: car.color,
            plate: car.plateNumber,
            hasPhoto: car.hasPhoto,
            servedClasses: car.servedClasses,
            licenseOk: car.licenseOk,
            stsOk: car.stsOk,
            osagoOk: car.osagoOk,
            passportOk: car.passportOk,
            selfieOk: car.selfieOk,
            driverLicenseOk: car.driverLicenseOk,
            docsSigned: car.docsSigned,
            licenseExpiry: car.licenseExpiry,
            stsExpiry: car.stsExpiry,
            osagoExpiry: car.osagoExpiry,
            onPickPhoto: () => _uploadCarPhoto(context),
            onUploadDoc: (doc) => _uploadDoc(context, doc),
            onToggleClass: (c) {
              context.read<DriverProvider>().toggleTariffClass(c);
            },
          ),
          const SizedBox(height: 8),
          SectionCard(
            child: Row(
              children: [
                Expanded(
                  child: _StatTile(
                    label: 'Принято заказов',
                    value: '${profile.acceptedOrders}',
                    icon: Icons.check_circle_outline,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatTile(
                    label: 'Завершено поездок',
                    value: '${profile.trips}',
                    icon: Icons.route_outlined,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const SectionTitle('Сервис'),
          SectionCard(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Column(
              children: [
                if (FeatureFlags.enableDemoMode) ...[
                  SettingsTile(
                    icon: Icons.play_circle_outline,
                    title: 'Демо-заказ',
                    subtitle: 'Проверить принятие и этапы поездки',
                    onTap: () {
                      context.read<OrdersProvider>().startDemoOrder();
                      context.go(AppRoutes.orders);
                    },
                  ),
                  const Divider(),
                ],
                SettingsTile(
                  icon: Icons.settings_outlined,
                  title: 'Настройки',
                  onTap: () => context.push(AppRoutes.settings),
                ),
                const Divider(),
                SettingsTile(
                  icon: Icons.support_agent_rounded,
                  title: 'Поддержка',
                  onTap: () => context.push(AppRoutes.support),
                ),
                const Divider(),
                SettingsTile(
                  icon: Icons.privacy_tip_outlined,
                  title: 'Политика конфиденциальности',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => LegalDocumentScreen.privacy(),
                      ),
                    );
                  },
                ),
                const Divider(),
                SettingsTile(
                  icon: Icons.description_outlined,
                  title: 'Пользовательское соглашение',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => LegalDocumentScreen.agreement(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const SectionTitle('Рейтинг и отзывы'),
          _RatingBreakdown(
            rating: profile.rating,
            reviewCount: profile.reviewCount,
            breakdown: profile.ratingBreakdown,
          ),
          const SizedBox(height: 12),
          ...profile.reviews.map(
            (r) => SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: context.tokens.elevated,
                        child: Text(
                          r.clientName.isNotEmpty ? r.clientName[0] : '?',
                          style: TextStyle(
                            color: AppColors.gold,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              r.clientName,
                              style: TextStyle(
                                color: context.tokens.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            GoldStarRow(
                              rating: r.stars.toDouble(),
                              size: 14,
                              showValue: false,
                            ),
                          ],
                        ),
                      ),
                      Text(
                        r.dateLabel,
                        style: TextStyle(
                          color: context.tokens.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    r.comment,
                    style: TextStyle(
                      color: context.tokens.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.name,
    required this.phone,
    required this.rating,
    required this.reviewCount,
    required this.isVerified,
    required this.hasAvatar,
    required this.avatarBase64,
    required this.registrationStatus,
    required this.onUploadAvatar,
  });

  final String name;
  final String phone;
  final double rating;
  final int reviewCount;
  final bool isVerified;
  final bool hasAvatar;
  final String? avatarBase64;
  final String registrationStatus;
  final VoidCallback onUploadAvatar;

  ImageProvider? get _avatarImage {
    final raw = avatarBase64?.trim();
    if (raw == null || raw.isEmpty) return null;
    final comma = raw.indexOf(',');
    final normalized = comma >= 0 ? raw.substring(comma + 1) : raw;
    try {
      return MemoryImage(base64Decode(normalized));
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final avatarImage = _avatarImage;
    return SectionCard(
      child: Column(
        children: [
          GestureDetector(
            onTap: onUploadAvatar,
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: context.tokens.elevated,
                    image: avatarImage == null
                        ? null
                        : DecorationImage(
                            image: avatarImage,
                            fit: BoxFit.cover,
                          ),
                    border: Border.all(color: AppColors.gold, width: 2),
                    gradient: hasAvatar && avatarImage == null
                        ? const LinearGradient(
                            colors: [AppColors.purpleDark, AppColors.goldDark],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                  ),
                  child: avatarImage != null
                      ? null
                      : hasAvatar
                          ? Center(
                              child: Text(
                                name.isNotEmpty ? name[0].toUpperCase() : '?',
                                style: TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.w800,
                                  color: context.tokens.textPrimary,
                                ),
                              ),
                            )
                          : Icon(
                              Icons.person_rounded,
                              size: 48,
                              color: context.tokens.textMuted,
                            ),
                ),
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.purple,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: context.tokens.surface,
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    Icons.camera_alt_rounded,
                    size: 16,
                    color: context.tokens.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            name,
            style: TextStyle(
              color: context.tokens.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            phone,
            style: TextStyle(color: context.tokens.textSecondary),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GoldStarRow(rating: rating),
              const SizedBox(width: 8),
              Text(
                '($reviewCount отзывов)',
                style: TextStyle(
                  color: context.tokens.textMuted,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          if (isVerified) ...[
            const SizedBox(height: 12),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.success.withValues(alpha: 0.35),
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.verified_rounded,
                    size: 18,
                    color: AppColors.success,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'Верифицирован',
                    style: TextStyle(
                      color: AppColors.success,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            const SizedBox(height: 12),
            RegistrationStatusBadge(status: registrationStatus, compact: true),
          ],
          const SizedBox(height: 8),
          TextButton(
            onPressed: onUploadAvatar,
            child: const Text('Загрузить фото'),
          ),
        ],
      ),
    );
  }
}

class _EarningsWidget extends StatelessWidget {
  const _EarningsWidget({
    required this.today,
    required this.week,
    required this.month,
    required this.tipsToday,
    this.commissionPercent,
  });

  final double today;
  final double week;
  final double month;
  final double tipsToday;
  final double? commissionPercent;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final gold = t.isDark ? AppColors.gold : AppColors.goldDark;
    final commissionLabel = commissionPercent != null
        ? '${commissionPercent!.toStringAsFixed(0)}%'
        : '—';
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Заработок',
            style: TextStyle(
              color: t.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Сегодня',
            style: TextStyle(color: t.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 2),
          Text(
            formatMoney(today),
            style: TextStyle(
              color: gold,
              fontSize: 32,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 14),
          _EarningsRow(label: 'За неделю', value: formatMoney(week)),
          const SizedBox(height: 8),
          _EarningsRow(label: 'За месяц', value: formatMoney(month)),
          const SizedBox(height: 8),
          _EarningsRow(label: 'Чаевые сегодня', value: formatMoney(tipsToday)),
          const SizedBox(height: 8),
          _EarningsRow(label: 'Комиссия сервиса', value: commissionLabel),
        ],
      ),
    );
  }
}

class _EarningsRow extends StatelessWidget {
  const _EarningsRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: t.elevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: t.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: t.textSecondary, fontSize: 13),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: t.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _CarSection extends StatelessWidget {
  const _CarSection({
    required this.makeModel,
    required this.color,
    required this.plate,
    required this.hasPhoto,
    required this.servedClasses,
    required this.licenseOk,
    required this.stsOk,
    required this.osagoOk,
    required this.passportOk,
    required this.selfieOk,
    required this.driverLicenseOk,
    required this.docsSigned,
    this.licenseExpiry,
    this.stsExpiry,
    this.osagoExpiry,
    required this.onPickPhoto,
    required this.onUploadDoc,
    required this.onToggleClass,
  });

  final String makeModel;
  final String color;
  final String plate;
  final bool hasPhoto;
  final List<String> servedClasses;
  final bool licenseOk;
  final bool stsOk;
  final bool osagoOk;
  final bool passportOk;
  final bool selfieOk;
  final bool driverLicenseOk;
  final bool docsSigned;
  final String? licenseExpiry;
  final String? stsExpiry;
  final String? osagoExpiry;
  final VoidCallback onPickPhoto;
  final ValueChanged<String> onUploadDoc;
  final ValueChanged<String> onToggleClass;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: onPickPhoto,
            child: Container(
              height: 140,
              width: double.infinity,
              decoration: BoxDecoration(
                color: context.tokens.elevated,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: context.tokens.border),
                gradient: hasPhoto
                    ? LinearGradient(
                        colors: [
                          context.tokens.elevated,
                          AppColors.purple.withValues(alpha: 0.25),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      )
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    hasPhoto
                        ? Icons.directions_car_filled_rounded
                        : Icons.add_a_photo_outlined,
                    size: 40,
                    color: hasPhoto ? AppColors.gold : context.tokens.textMuted,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    hasPhoto ? 'Фото автомобиля' : 'Добавить фото авто',
                    style: TextStyle(
                      color: hasPhoto
                          ? context.tokens.textPrimary
                          : context.tokens.textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            makeModel,
            style: TextStyle(
              color: context.tokens.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$color · $plate',
            style: TextStyle(
              color: context.tokens.textSecondary,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Классы тарифов',
            style: TextStyle(
              color: context.tokens.textMuted,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: TariffClasses.all.map((c) {
              final selected = servedClasses.contains(c);
              return FilterChip(
                label: Text(c),
                selected: selected,
                onSelected: (_) => onToggleClass(c),
                selectedColor: AppColors.purple.withValues(alpha: 0.3),
                checkmarkColor: AppColors.gold,
                labelStyle: TextStyle(
                  color:
                      selected ? AppColors.gold : context.tokens.textSecondary,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
                side: BorderSide(
                  color: selected ? AppColors.gold : context.tokens.border,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          Text(
            'Документы и верификация',
            style: TextStyle(
              color: context.tokens.textMuted,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _DocTile(
                label: 'Паспорт',
                ok: passportOk,
                onTap: passportOk ? null : () => onUploadDoc('passport'),
              ),
              _DocTile(
                label: 'Селфи',
                ok: selfieOk,
                onTap: selfieOk ? null : () => onUploadDoc('selfie'),
              ),
              _DocTile(
                label: 'ВУ (оборот)',
                ok: driverLicenseOk,
                onTap: driverLicenseOk ? null : () => onUploadDoc('license'),
              ),
              StatusChip(label: 'ВУ', ok: licenseOk),
              _DocTile(
                label: 'СТС',
                ok: stsOk,
                onTap: stsOk ? null : () => onUploadDoc('sts'),
              ),
              _DocTile(
                label: 'ОСАГО',
                ok: osagoOk,
                onTap: osagoOk ? null : () => onUploadDoc('osago'),
              ),
              StatusChip(label: 'Подпись', ok: docsSigned),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Сроки действия документов',
            style: TextStyle(
              color: context.tokens.textMuted,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          _ExpiryRow(label: 'Водительское удостоверение', value: licenseExpiry),
          _ExpiryRow(label: 'СТС', value: stsExpiry),
          _ExpiryRow(label: 'ОСАГО', value: osagoExpiry),
        ],
      ),
    );
  }
}

class _ExpiryRow extends StatelessWidget {
  const _ExpiryRow({required this.label, this.value});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final shown = (value ?? '').trim().isEmpty ? '—' : value!.trim();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: t.textSecondary, fontSize: 13),
            ),
          ),
          Text(
            shown,
            style: TextStyle(
              color: t.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _DocTile extends StatelessWidget {
  const _DocTile({
    required this.label,
    required this.ok,
    this.onTap,
  });

  final String label;
  final bool ok;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(
        ok ? Icons.check_circle : Icons.upload_file_outlined,
        size: 18,
        color: ok ? AppColors.success : AppColors.gold,
      ),
      label: Text(label),
      onPressed: onTap,
      backgroundColor: ok
          ? AppColors.success.withValues(alpha: 0.12)
          : context.tokens.elevated,
      side: BorderSide(
        color: ok
            ? AppColors.success.withValues(alpha: 0.4)
            : context.tokens.border,
      ),
      labelStyle: TextStyle(
        color: ok ? AppColors.success : context.tokens.textPrimary,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.purple, size: 20),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            color: AppColors.gold,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          label,
          style: TextStyle(color: context.tokens.textMuted, fontSize: 12),
        ),
      ],
    );
  }
}

class _RatingBreakdown extends StatelessWidget {
  const _RatingBreakdown({
    required this.rating,
    required this.reviewCount,
    required this.breakdown,
  });

  final double rating;
  final int reviewCount;
  final Map<int, int> breakdown;

  @override
  Widget build(BuildContext context) {
    final maxCount = breakdown.values.fold<int>(1, (a, b) => a > b ? a : b);

    return SectionCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Text(
                rating.toStringAsFixed(2),
                style: TextStyle(
                  color: AppColors.gold,
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                ),
              ),
              GoldStarRow(rating: rating, size: 16, showValue: false),
              const SizedBox(height: 4),
              Text(
                '$reviewCount отзывов',
                style: TextStyle(
                  color: context.tokens.textMuted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              children: [
                for (var stars = 5; stars >= 1; stars--)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 18,
                          child: Text(
                            '$stars',
                            style: TextStyle(
                              color: context.tokens.textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.star_rounded,
                          size: 12,
                          color: AppColors.gold,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: (breakdown[stars] ?? 0) / maxCount,
                              minHeight: 8,
                              backgroundColor: context.tokens.elevated,
                              color: AppColors.gold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 28,
                          child: Text(
                            '${breakdown[stars] ?? 0}',
                            textAlign: TextAlign.end,
                            style: TextStyle(
                              color: context.tokens.textMuted,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
