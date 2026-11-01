import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/widgets/action_buttons.dart';
import '../../shared/widgets/address_search_field.dart';
import 'providers/profile_provider.dart';
import 'widgets/profile_widgets.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  late final TextEditingController _homeController;
  late final TextEditingController _workController;
  late final TextEditingController _favoriteController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final profile = context.read<ProfileProvider>();
    _homeController = TextEditingController(text: profile.addressHome);
    _workController = TextEditingController(text: profile.addressWork);
    _favoriteController = TextEditingController(text: profile.addressFavorite);
  }

  @override
  void dispose() {
    _homeController.dispose();
    _workController.dispose();
    _favoriteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Избранные адреса'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.deferToChild,
        child: Consumer<ProfileProvider>(
          builder: (context, profile, _) {
            final hasAny = profile.addressHome.isNotEmpty ||
                profile.addressWork.isNotEmpty ||
                profile.addressFavorite.isNotEmpty;

            return ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                if (!hasAny)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: ProfileEmptyState(
                      icon: Icons.place_outlined,
                      title: 'Адреса не сохранены',
                      subtitle:
                          'Укажите дом, работу и избранное — они появятся при заказе',
                    ),
                  ),
                ProfileFormCard(
                  child: Column(
                    children: [
                      AddressSearchField(
                        controller: _homeController,
                        label: 'Дом',
                        hintText: 'Адрес дома',
                        icon: Icons.home_outlined,
                        iconColor: AppColors.purple,
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 14),
                      AddressSearchField(
                        controller: _workController,
                        label: 'Работа',
                        hintText: 'Адрес работы',
                        icon: Icons.work_outline_rounded,
                        iconColor: AppColors.gold,
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 14),
                      AddressSearchField(
                        controller: _favoriteController,
                        label: 'Избранное',
                        hintText: 'Любимый адрес',
                        icon: Icons.star_outline_rounded,
                        iconColor: AppColors.success,
                        textInputAction: TextInputAction.done,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                PurpleActionButton(
                  label: _saving ? 'Сохранение…' : 'Сохранить адреса',
                  onPressed: _saving
                      ? null
                      : () async {
                          setState(() => _saving = true);
                          try {
                            await profile.saveAddresses(
                              home: _homeController.text,
                              work: _workController.text,
                              favorite: _favoriteController.text,
                            );
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Адреса сохранены'),
                                ),
                              );
                            }
                          } catch (_) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Не удалось синхронизировать адреса с сервером',
                                  ),
                                ),
                              );
                            }
                          } finally {
                            if (mounted) setState(() => _saving = false);
                          }
                        },
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
