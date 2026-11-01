import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/models/api_models.dart';
import '../../core/geo/geo_config.dart';
import '../../core/geo/geo_search_service.dart';
import '../../core/theme/app_theme.dart';

/// Поле адреса с подсказками (debounce, loading / empty / error).
class AddressSearchField extends StatefulWidget {
  const AddressSearchField({
    super.key,
    required this.controller,
    required this.label,
    this.hintText = 'Начните вводить адрес',
    this.icon = Icons.place_outlined,
    this.iconColor = AppColors.purple,
    this.onChanged,
    this.onSuggestionSelected,
    this.onUseCurrentLocation,
    this.onOpenMap,
    this.onRemove,
    this.enabled = true,
    this.textInputAction = TextInputAction.next,
    this.focusNode,
    this.geoSearch,
  });

  final TextEditingController controller;
  final String label;
  final String hintText;
  final IconData icon;
  final Color iconColor;
  final ValueChanged<String>? onChanged;
  final ValueChanged<AddressSuggestionDto>? onSuggestionSelected;
  /// Кнопка «Моё местоположение» (обычно для поля «Откуда»).
  final VoidCallback? onUseCurrentLocation;
  final VoidCallback? onOpenMap;
  final VoidCallback? onRemove;
  final bool enabled;
  final TextInputAction textInputAction;
  final FocusNode? focusNode;
  final GeoSearchService? geoSearch;

  @override
  State<AddressSearchField> createState() => _AddressSearchFieldState();
}

class _AddressSearchFieldState extends State<AddressSearchField> {
  late final FocusNode _focusNode;
  late final bool _ownsFocusNode;
  Timer? _debounce;
  int _requestId = 0;

  List<AddressSuggestionDto> _suggestions = [];
  bool _loading = false;
  String? _error;
  bool _showPanel = false;
  bool _suppressNextSuggest = false;

  GeoSearchService get _geo {
    return widget.geoSearch ?? context.read<GeoSearchService>();
  }

  @override
  void initState() {
    super.initState();
    _ownsFocusNode = widget.focusNode == null;
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_onFocusChanged);
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _focusNode.removeListener(_onFocusChanged);
    widget.controller.removeListener(_onControllerChanged);
    if (_ownsFocusNode) _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (!_focusNode.hasFocus) {
      // Небольшая задержка, чтобы успел сработать onTap по подсказке.
      Future<void>.delayed(const Duration(milliseconds: 120), () {
        if (!mounted || _focusNode.hasFocus) return;
        setState(() => _showPanel = false);
      });
      return;
    }
    final q = widget.controller.text.trim();
    if (q.length >= GeoConfig.minQueryLength) {
      setState(() => _showPanel = true);
      _scheduleSuggest(q);
    }
  }

  void _onControllerChanged() {
    if (_suppressNextSuggest) {
      _suppressNextSuggest = false;
      return;
    }
    // Внешний sync контроллера без фокуса — не дёргаем поиск.
    if (!_focusNode.hasFocus) return;
    widget.onChanged?.call(widget.controller.text);
    final q = widget.controller.text.trim();
    if (q.length < GeoConfig.minQueryLength) {
      _debounce?.cancel();
      setState(() {
        _suggestions = [];
        _loading = false;
        _error = null;
        _showPanel = false;
      });
      return;
    }
    setState(() => _showPanel = true);
    _scheduleSuggest(q);
  }

  void _scheduleSuggest(String query) {
    _debounce?.cancel();
    _debounce = Timer(GeoConfig.debounce, () => _runSuggest(query));
  }

  Future<void> _runSuggest(String query) async {
    final id = ++_requestId;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final items = await _geo.suggest(query);
      if (!mounted || id != _requestId) return;
      setState(() {
        _suggestions = items;
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted || id != _requestId) return;
      setState(() {
        _suggestions = [];
        _loading = false;
        _error = 'Не удалось загрузить подсказки';
      });
    }
  }

  void _select(AddressSuggestionDto item) {
    _debounce?.cancel();
    _suppressNextSuggest = true;
    final text = item.displayAddress;
    widget.controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    widget.onChanged?.call(text);
    widget.onSuggestionSelected?.call(item);
    setState(() {
      _showPanel = false;
      _suggestions = [];
      _loading = false;
      _error = null;
    });
    _focusNode.unfocus();
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final focused = _focusNode.hasFocus;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.backgroundElevated,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: focused ? AppColors.purple : AppColors.border,
              width: focused ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(widget.icon, color: widget.iconColor, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  focusNode: _focusNode,
                  enabled: widget.enabled,
                  keyboardType: TextInputType.streetAddress,
                  textInputAction: widget.textInputAction,
                  textCapitalization: TextCapitalization.sentences,
                  autocorrect: false,
                  enableSuggestions: true,
                  scrollPadding: const EdgeInsets.only(bottom: 160),
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                  ),
                  decoration: InputDecoration(
                    labelText: widget.label,
                    hintText: widget.hintText,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onTap: () {
                    final q = widget.controller.text.trim();
                    if (q.length >= GeoConfig.minQueryLength) {
                      setState(() => _showPanel = true);
                      _scheduleSuggest(q);
                    }
                  },
                  onSubmitted: (_) => _focusNode.unfocus(),
                ),
              ),
              if (_loading && _showPanel)
                const Padding(
                  padding: EdgeInsets.only(right: 4),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else if (widget.controller.text.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  color: AppColors.textMuted,
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Очистить',
                  onPressed: widget.enabled
                      ? () {
                          _suppressNextSuggest = true;
                          widget.controller.clear();
                          widget.onChanged?.call('');
                          setState(() {
                            _suggestions = [];
                            _showPanel = false;
                            _error = null;
                            _loading = false;
                          });
                        }
                      : null,
                ),
              if (widget.onUseCurrentLocation != null)
                IconButton(
                  icon: const Icon(Icons.my_location_rounded, size: 18),
                  color: AppColors.purple,
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Моё местоположение',
                  onPressed:
                      widget.enabled ? widget.onUseCurrentLocation : null,
                ),
              if (widget.onOpenMap != null)
                IconButton(
                  icon: const Icon(Icons.map_outlined, size: 18),
                  color: AppColors.gold,
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Р’С‹Р±СЂР°С‚СЊ РЅР° РєР°СЂС‚Рµ',
                  onPressed: widget.enabled ? widget.onOpenMap : null,
                ),
              if (widget.onRemove != null)
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline, size: 18),
                  color: AppColors.textMuted,
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Удалить поле',
                  onPressed: widget.onRemove,
                ),
            ],
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: _showPanel ? _SuggestionsPanel(
            loading: _loading,
            error: _error,
            suggestions: _suggestions,
            query: widget.controller.text.trim(),
            onRetry: () => _runSuggest(widget.controller.text.trim()),
            onSelect: _select,
          ) : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _SuggestionsPanel extends StatelessWidget {
  const _SuggestionsPanel({
    required this.loading,
    required this.error,
    required this.suggestions,
    required this.query,
    required this.onRetry,
    required this.onSelect,
  });

  final bool loading;
  final String? error;
  final List<AddressSuggestionDto> suggestions;
  final String query;
  final VoidCallback onRetry;
  final ValueChanged<AddressSuggestionDto> onSelect;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Material(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(12),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 220),
            child: _buildBody(),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (error != null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              error!,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Повторить'),
            ),
          ],
        ),
      );
    }

    if (loading && suggestions.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            const SizedBox(height: 10),
            Text(
              'Ищем адреса…',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
          ],
        ),
      );
    }

    if (!loading && suggestions.isEmpty) {
      final emptyText = query.length < GeoConfig.minQueryLength
          ? 'Введите минимум ${GeoConfig.minQueryLength} символа'
          : 'Ничего не найдено';
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
        child: Text(
          emptyText,
          style: TextStyle(color: AppColors.textMuted, fontSize: 13),
          textAlign: TextAlign.center,
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: suggestions.length,
      separatorBuilder: (_, __) => Divider(
        height: 1,
        color: AppColors.divider,
      ),
      itemBuilder: (context, index) {
        final item = suggestions[index];
        return InkWell(
          onTap: () => onSelect(item),
          borderRadius: index == 0
              ? const BorderRadius.vertical(top: Radius.circular(12))
              : index == suggestions.length - 1
                  ? const BorderRadius.vertical(bottom: Radius.circular(12))
                  : BorderRadius.zero,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: AppColors.purple.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.location_on_outlined,
                    size: 18,
                    color: AppColors.gold,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (item.subtitle.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          item.subtitle,
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
