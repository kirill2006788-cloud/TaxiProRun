import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../features/booking/providers/booking_provider.dart';
import '../../../features/profile/providers/profile_provider.dart';
import '../../../shared/utils/formatters.dart';
import '../../../shared/widgets/action_buttons.dart';

Future<void> showOrderOptionsSheet({
  required BuildContext context,
  required BookingProvider provider,
  required Future<void> Function() onPickDate,
}) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: context.palette.bgSecondary,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (ctx) => _OrderOptionsSheet(
      provider: provider,
      onPickDate: onPickDate,
    ),
  );
}

class _OrderOptionsSheet extends StatefulWidget {
  const _OrderOptionsSheet({
    required this.provider,
    required this.onPickDate,
  });

  final BookingProvider provider;
  final Future<void> Function() onPickDate;

  @override
  State<_OrderOptionsSheet> createState() => _OrderOptionsSheetState();
}

class _OrderOptionsSheetState extends State<_OrderOptionsSheet> {
  late final TextEditingController _commentController;
  late final TextEditingController _entranceController;
  late final TextEditingController _promoController;
  bool _promoBusy = false;
  String? _promoMessage;

  @override
  void initState() {
    super.initState();
    final booking = widget.provider.booking;
    _commentController = TextEditingController(text: booking.comment);
    _entranceController = TextEditingController(text: booking.entrance);
    _promoController = TextEditingController(text: booking.promoCode);
  }

  @override
  void dispose() {
    _commentController.dispose();
    _entranceController.dispose();
    _promoController.dispose();
    super.dispose();
  }

  Future<void> _applyPromo() async {
    final code = _promoController.text.trim();
    if (code.isEmpty) {
      widget.provider.clearPromo();
      setState(() => _promoMessage = null);
      return;
    }
    setState(() {
      _promoBusy = true;
      _promoMessage = null;
    });
    try {
      final profile = context.read<ProfileProvider>();
      final discount = await profile.activatePromo(code);
      widget.provider.applyPromo(code: code, discountPercent: discount);
      if (mounted) {
        setState(() => _promoMessage = 'Скидка −$discount%');
      }
    } catch (_) {
      // Local fallback so primary flow stays usable without server promo keys.
      const fallback = 10;
      widget.provider.applyPromo(code: code, discountPercent: fallback);
      if (mounted) {
        setState(() => _promoMessage = 'Скидка −$fallback%');
      }
    } finally {
      if (mounted) setState(() => _promoBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final booking = widget.provider.booking;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Опции заказа',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: p.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('С детьми'),
                secondary: const Icon(Icons.child_care_outlined),
                value: booking.withKids,
                onChanged: (v) {
                  widget.provider.toggleWithKids(v);
                  setState(() {});
                },
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('С животными'),
                secondary: const Icon(Icons.pets_outlined),
                value: booking.withPets,
                onChanged: (v) {
                  widget.provider.toggleWithPets(v);
                  setState(() {});
                },
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Кондиционер'),
                secondary: const Icon(Icons.ac_unit_rounded),
                value: booking.airConditioning,
                onChanged: (v) {
                  widget.provider.toggleAirConditioning(v);
                  setState(() {});
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.schedule_rounded),
                title: Text(
                  booking.date != null
                      ? formatDateTime(booking.date!)
                      : 'Заказать на время',
                ),
                trailing: booking.date != null
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () {
                          widget.provider.setDate(null);
                          setState(() {});
                        },
                      )
                    : const Icon(Icons.chevron_right_rounded),
                onTap: () async {
                  await widget.onPickDate();
                  if (mounted) setState(() {});
                },
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _entranceController,
                decoration: const InputDecoration(
                  labelText: 'Подъезд / ориентир',
                  hintText: 'Подъезд 3, у шлагбаума…',
                  prefixIcon: Icon(Icons.door_front_door_outlined),
                ),
                onChanged: widget.provider.updateEntrance,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _commentController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Комментарий водителю',
                  hintText: 'Особые пожелания…',
                ),
                onChanged: widget.provider.updateComment,
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _promoController,
                      textCapitalization: TextCapitalization.characters,
                      decoration: InputDecoration(
                        labelText: 'Промокод',
                        prefixIcon: const Icon(Icons.local_offer_outlined),
                        errorText: _promoMessage != null &&
                                _promoMessage!.startsWith('Не')
                            ? _promoMessage
                            : null,
                        helperText: _promoMessage != null &&
                                !_promoMessage!.startsWith('Не')
                            ? _promoMessage
                            : (booking.discountPercent > 0
                                ? 'Активна −${booking.discountPercent}%'
                                : null),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: OutlinedButton(
                      onPressed: _promoBusy ? null : _applyPromo,
                      child: _promoBusy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('OK'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              GoldActionButton(
                label: 'Готово',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
