import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../models/client_vehicle.dart';
import '../../shared/widgets/async_state_widgets.dart';
import 'providers/vehicles_provider.dart';

class VehiclesScreen extends StatefulWidget {
  const VehiclesScreen({super.key});

  @override
  State<VehiclesScreen> createState() => _VehiclesScreenState();
}

class _VehiclesScreenState extends State<VehiclesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<VehiclesProvider>().load();
    });
  }

  Future<void> _showEditor({ClientVehicle? existing}) async {
    final makeCtrl = TextEditingController(text: existing?.make ?? '');
    final modelCtrl = TextEditingController(text: existing?.model ?? '');
    final plateCtrl = TextEditingController(text: existing?.plate ?? '');
    final colorCtrl = TextEditingController(text: existing?.color ?? '');
    final yearCtrl = TextEditingController(text: existing?.year ?? '');

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.backgroundSecondary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final bottom = MediaQuery.viewInsetsOf(ctx).bottom;
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                existing == null ? 'Новый автомобиль' : 'Редактировать',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: makeCtrl,
                decoration: const InputDecoration(labelText: 'Марка'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: modelCtrl,
                decoration: const InputDecoration(labelText: 'Модель'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: plateCtrl,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(labelText: 'Гос. номер'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: colorCtrl,
                decoration: const InputDecoration(labelText: 'Цвет (необязательно)'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: yearCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Год (необязательно)'),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  if (makeCtrl.text.trim().isEmpty ||
                      modelCtrl.text.trim().isEmpty ||
                      plateCtrl.text.trim().isEmpty) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(
                        content: Text('Укажите марку, модель и номер'),
                      ),
                    );
                    return;
                  }
                  Navigator.pop(ctx, true);
                },
                child: Text(existing == null ? 'Добавить' : 'Сохранить'),
              ),
            ],
          ),
        );
      },
    );

    if (saved != true || !mounted) {
      makeCtrl.dispose();
      modelCtrl.dispose();
      plateCtrl.dispose();
      colorCtrl.dispose();
      yearCtrl.dispose();
      return;
    }

    final provider = context.read<VehiclesProvider>();
    if (existing == null) {
      await provider.addVehicle(
        make: makeCtrl.text,
        model: modelCtrl.text,
        plate: plateCtrl.text,
        color: colorCtrl.text,
        year: yearCtrl.text,
      );
    } else {
      await provider.updateVehicle(
        ClientVehicle(
          id: existing.id,
          make: makeCtrl.text.trim(),
          model: modelCtrl.text.trim(),
          plate: plateCtrl.text.trim().toUpperCase(),
          color: colorCtrl.text.trim(),
          year: yearCtrl.text.trim(),
        ),
      );
    }

    makeCtrl.dispose();
    modelCtrl.dispose();
    plateCtrl.dispose();
    colorCtrl.dispose();
    yearCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Мои автомобили'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: Consumer<VehiclesProvider>(
        builder: (context, vehicles, _) {
          if (!vehicles.loaded) {
            return const Center(child: CircularProgressIndicator());
          }

          if (vehicles.vehicles.isEmpty) {
            return EmptyStateView(
              icon: Icons.directions_car_outlined,
              title: 'Нет сохранённых авто',
              subtitle:
                  'Добавьте автомобиль для режима «Трезвый водитель» и перегона',
              actionLabel: 'Добавить автомобиль',
              onAction: () => _showEditor(),
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
            children: [
              Text(
                'Выберите автомобиль для заказа трезвого водителя',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 12),
              ...vehicles.vehicles.map((v) {
                final selected = vehicles.selectedVehicleId == v.id;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Material(
                    color: AppColors.backgroundSecondary,
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      onTap: () => vehicles.selectVehicle(v.id),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: selected
                                ? AppColors.purple
                                : AppColors.border,
                            width: selected ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.directions_car_filled_outlined,
                              color: selected
                                  ? AppColors.purple
                                  : AppColors.textSecondary,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${v.make} ${v.model}'.trim(),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (v.plate.isNotEmpty)
                                    Text(
                                      v.plate,
                                      style: TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 13,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Изменить',
                              onPressed: () => _showEditor(existing: v),
                              icon: const Icon(Icons.edit_outlined, size: 20),
                            ),
                            IconButton(
                              tooltip: 'Удалить',
                              onPressed: () => vehicles.removeVehicle(v.id),
                              icon: const Icon(
                                Icons.delete_outline,
                                size: 20,
                                color: AppColors.error,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showEditor(),
        icon: const Icon(Icons.add),
        label: const Text('Добавить'),
      ),
    );
  }
}
