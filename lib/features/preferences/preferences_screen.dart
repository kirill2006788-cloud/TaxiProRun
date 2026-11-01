import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../features/booking/providers/booking_provider.dart';
import '../../shared/widgets/action_buttons.dart';
import '../../shared/widgets/app_bar_back.dart';

class PreferencesScreen extends StatefulWidget {
  const PreferencesScreen({super.key});

  @override
  State<PreferencesScreen> createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends State<PreferencesScreen> {
  late final TextEditingController _commentController;

  @override
  void initState() {
    super.initState();
    _commentController = TextEditingController(
      text: context.read<BookingProvider>().booking.comment,
    );
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: appBarWithBack(context, title: 'Пожелания'),
      body: Consumer<BookingProvider>(
        builder: (context, provider, _) {
          final booking = provider.booking;

          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _PreferenceTile(
                      title: 'С детьми',
                      subtitle: 'Детское кресло по запросу',
                      icon: Icons.child_care_outlined,
                      value: booking.withKids,
                      onChanged: provider.toggleWithKids,
                    ),
                    _PreferenceTile(
                      title: 'С животными',
                      subtitle: 'Перевозка домашних животных',
                      icon: Icons.pets_outlined,
                      value: booking.withPets,
                      onChanged: provider.toggleWithPets,
                    ),
                    _PreferenceTile(
                      title: 'Кондиционер',
                      subtitle: 'Климат-контроль в салоне',
                      icon: Icons.ac_unit_outlined,
                      value: booking.airConditioning,
                      onChanged: provider.toggleAirConditioning,
                    ),
                    _PreferenceTile(
                      title: 'Курящий салон',
                      subtitle: 'Разрешено курение в автомобиле',
                      icon: Icons.smoking_rooms_outlined,
                      value: booking.smokingAllowed,
                      onChanged: provider.toggleSmokingAllowed,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Комментарий водителю',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _commentController,
                      onChanged: provider.updateComment,
                      maxLines: 4,
                      style: TextStyle(color: AppColors.textPrimary),
                      decoration: const InputDecoration(
                        hintText: 'Например: встретить у подъезда №3',
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: PurpleActionButton(
                  label: 'Далее',
                  onPressed: () => context.push(AppRoutes.payment),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PreferenceTile extends StatelessWidget {
  const _PreferenceTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: SwitchListTile(
        secondary: Icon(icon, color: value ? AppColors.purple : AppColors.textSecondary),
        title: Text(title),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        value: value,
        onChanged: onChanged,
      ),
    );
  }
}
