import 'package:flutter/material.dart';

import '../../../core/api/models/api_models.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/address_search_field.dart';

class SavedPlaceItem {
  const SavedPlaceItem({
    required this.label,
    required this.address,
    required this.icon,
  });

  final String label;
  final String address;
  final IconData icon;
}

/// Destination search: from / to + recent / saved.
class DestinationSearchSheet extends StatelessWidget {
  const DestinationSearchSheet({
    super.key,
    required this.fromController,
    required this.toController,
    required this.toFocusNode,
    required this.recentDestinations,
    required this.savedPlaces,
    required this.onClose,
    required this.onFromChanged,
    required this.onToChanged,
    required this.onFromSuggestion,
    required this.onToSuggestion,
    required this.onUseCurrentLocation,
    required this.onOpenMap,
    required this.onSelectRecent,
    required this.onSelectSaved,
  });

  final TextEditingController fromController;
  final TextEditingController toController;
  final FocusNode toFocusNode;
  final List<String> recentDestinations;
  final List<SavedPlaceItem> savedPlaces;
  final VoidCallback onClose;
  final ValueChanged<String> onFromChanged;
  final ValueChanged<String> onToChanged;
  final ValueChanged<AddressSuggestionDto> onFromSuggestion;
  final ValueChanged<AddressSuggestionDto> onToSuggestion;
  final VoidCallback onUseCurrentLocation;
  final VoidCallback onOpenMap;
  final ValueChanged<String> onSelectRecent;
  final ValueChanged<String> onSelectSaved;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Material(
      color: p.bgSecondary,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 10, 16, bottom + 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: onClose,
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  Expanded(
                    child: Text(
                      'Куда едем?',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: p.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              AddressSearchField(
                label: 'Откуда',
                icon: Icons.trip_origin,
                iconColor: AppColors.purple,
                controller: fromController,
                textInputAction: TextInputAction.next,
                onChanged: onFromChanged,
                onSuggestionSelected: onFromSuggestion,
                onUseCurrentLocation: onUseCurrentLocation,
              ),
              const SizedBox(height: 8),
              AddressSearchField(
                label: 'Куда',
                hintText: 'Куда едем?',
                icon: Icons.location_on,
                iconColor: AppColors.gold,
                controller: toController,
                focusNode: toFocusNode,
                textInputAction: TextInputAction.done,
                onChanged: onToChanged,
                onSuggestionSelected: onToSuggestion,
                onOpenMap: onOpenMap,
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    if (savedPlaces.isNotEmpty) ...[
                      Text(
                        'Избранное',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: p.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      ...savedPlaces.map(
                        (place) => _PlaceTile(
                          icon: place.icon,
                          title: place.label,
                          subtitle: place.address,
                          onTap: () => onSelectSaved(place.address),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (recentDestinations.isNotEmpty) ...[
                      Text(
                        'Недавние',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: p.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      ...recentDestinations.take(3).map(
                        (address) => _PlaceTile(
                          icon: Icons.history_rounded,
                          title: address,
                          onTap: () => onSelectRecent(address),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlaceTile extends StatelessWidget {
  const _PlaceTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
          child: Row(
            children: [
              Icon(icon, color: AppColors.gold, size: 21),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: p.textPrimary,
                      ),
                    ),
                    if ((subtitle ?? '').isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: p.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
