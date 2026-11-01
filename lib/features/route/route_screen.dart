import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/api/models/api_models.dart';
import '../../core/api/services/api_services.dart';
import '../../core/geo/geo_math.dart';
import '../../core/geo/geo_search_service.dart';
import '../../core/location/device_location.dart';
import '../../core/router/app_router.dart';
import '../../core/session/active_order_store.dart';
import '../../core/services/payment_service.dart';
import '../../core/theme/app_theme.dart';
import '../../data/mock_trips.dart';
import '../../data/tariff_groups.dart';
import '../../models/client_vehicle.dart';
import '../../models/payment_method.dart';
import '../../features/booking/providers/booking_provider.dart';
import '../../features/map/location_permission_flow.dart';
import '../../features/map/map_camera_controller.dart';
import '../../features/map/map_geo.dart';
import '../../features/map/map_host.dart';
import '../../features/map/map_pin_mode.dart';
import '../../features/map/map_trip_ui.dart';
import '../../features/profile/providers/profile_provider.dart';
import '../../features/profile/providers/settings_provider.dart';
import '../../features/profile/providers/vehicles_provider.dart';
import '../../features/route/booking_flow_step.dart';
import '../../features/route/widgets/destination_map_sheet.dart';
import '../../features/route/widgets/destination_search_sheet.dart';
import '../../features/route/widgets/go_home_sheet.dart';
import '../../features/route/widgets/order_options_sheet.dart';
import '../../features/route/widgets/payment_method_sheet.dart';
import '../../features/route/widgets/tariff_select_sheet.dart';
import '../../shared/utils/app_snackbar.dart';
import '../../shared/widgets/fare_breakdown_sheet.dart';
import '../../shared/widgets/service_type_selector.dart';

class RouteScreen extends StatefulWidget {
  const RouteScreen({super.key});

  @override
  State<RouteScreen> createState() => _RouteScreenState();
}

class _RouteScreenState extends State<RouteScreen> {
  late final TextEditingController _fromController;
  late final TextEditingController _toController;
  late final FocusNode _toFocusNode;
  bool _askedLocation = false;
  List<String> _recentDestinations = const [];
  String? _tariffsRouteKey;
  bool _mapMoving = false;
  String? _locationFallbackMessage;
  TariffTab _tariffTab = TariffTab.all;
  Timer? _geocodeDebounce;
  Timer? _sheetReturnDelay;
  int _geocodeRequestId = 0;
  final _mapCamera = MapCameraController();

  @override
  void initState() {
    super.initState();
    final booking = context.read<BookingProvider>().booking;
    _fromController = TextEditingController(text: booking.fromAddress);
    _toController = TextEditingController(text: booking.toAddress);
    _toFocusNode = FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (await _redirectActiveOrderIfNeeded()) return;
      _maybeAskLocation();
      _loadRecent();
      _bootstrapPickupIfNeeded();
    });
  }

  Future<bool> _redirectActiveOrderIfNeeded() async {
    final orderId = await ActiveOrderStore.load();
    if (!mounted || orderId == null || orderId.isEmpty) return false;
    try {
      final active = await context
          .read<BookingProvider>()
          .apiServices
          .order
          .fetchActiveOrder();
      if (!mounted) return false;
      if (active == null || !active.isActive) {
        await ActiveOrderStore.clear();
        return false;
      }
      context.read<BookingProvider>().restoreFromOrder(active);
      context.go(AppRoutes.activeTrip);
      return true;
    } catch (_) {
      if (!mounted) return false;
      context.go(AppRoutes.activeTrip);
      return true;
    }
  }

  Future<void> _bootstrapPickupIfNeeded() async {
    final provider = context.read<BookingProvider>();
    if (provider.booking.fromLat != null) return;
    await _useCurrentLocation(silent: true);
  }

  Future<void> _maybeAskLocation() async {
    if (_askedLocation || !mounted) return;
    _askedLocation = true;
    await LocationPermissionFlow.ensure(context);
  }

  Future<void> _loadRecent() async {
    final seen = <String>{};
    final recent = <String>[];

    void add(String? raw) {
      final v = (raw ?? '').trim();
      if (v.isEmpty || v.length < 3) return;
      final key = v.toLowerCase();
      if (seen.contains(key)) return;
      seen.add(key);
      recent.add(v);
    }

    final useMock = context.read<SettingsProvider>().useMockApi ||
        ApiConfigStore.instance.useMockApi;
    final local = await context.read<ProfileProvider>().loadOrderHistory();
    for (final item in local) {
      add(item['to']?.toString());
      if (recent.length >= 3) break;
    }

    if (!useMock) {
      final api = ApiServices();
      try {
        final orders = await api.order.fetchClientOrders();
        for (final o in orders) {
          add(o.toAddress);
          if (recent.length >= 3) break;
        }
      } catch (_) {
        // chips from local/mock only
      } finally {
        api.dispose();
      }
    }

    if (recent.length < 3 && useMock) {
      for (final trip in MockTrips.all) {
        add(trip.toAddress);
        if (recent.length >= 3) break;
      }
    }

    if (!mounted) return;
    setState(() => _recentDestinations = recent.take(3).toList());
  }

  List<SavedPlaceItem> _savedPlaces(ProfileProvider profile) {
    final items = <SavedPlaceItem>[];
    if (profile.addressHome.trim().isNotEmpty) {
      items.add(SavedPlaceItem(
        label: 'Дом',
        address: profile.addressHome.trim(),
        icon: Icons.home_outlined,
      ));
    }
    if (profile.addressWork.trim().isNotEmpty) {
      items.add(SavedPlaceItem(
        label: 'Работа',
        address: profile.addressWork.trim(),
        icon: Icons.work_outline_rounded,
      ));
    }
    if (profile.addressFavorite.trim().isNotEmpty) {
      items.add(SavedPlaceItem(
        label: 'Избранное',
        address: profile.addressFavorite.trim(),
        icon: Icons.star_outline_rounded,
      ));
    }
    return items;
  }

  Future<void> _selectKnownAddress(
    String address, {
    required bool asDestination,
  }) async {
    final normalized = address.trim();
    if (normalized.isEmpty) return;
    final suggestion =
        await context.read<GeoSearchService>().geocode(normalized);
    if (!mounted) return;
    if (suggestion == null || !suggestion.hasCoordinates) {
      showAppSnackBar(
        context,
        'Не удалось определить координаты адреса',
        isError: true,
      );
      return;
    }
    final display = suggestion.displayAddress;
    final provider = context.read<BookingProvider>();
    if (asDestination) {
      _toController.text = display;
      provider.updateToAddressWithCoords(
        display,
        lat: suggestion.lat!,
        lng: suggestion.lng!,
      );
      provider.setFlowStep(BookingFlowStep.tariffs);
    } else {
      _fromController.text = display;
      provider.updateFromAddressWithCoords(
        display,
        lat: suggestion.lat!,
        lng: suggestion.lng!,
      );
      context.read<GeoSearchService>().setSearchCenter(
            lat: suggestion.lat!,
            lng: suggestion.lng!,
          );
      if (_locationFallbackMessage != null) {
        _setLocationFallback(
          'Ближайших водителей ищем от выбранного адреса',
        );
      }
    }
  }

  Future<void> _useCurrentLocation({bool silent = true}) async {
    final provider = context.read<BookingProvider>();

    final status = await LocationPermissionFlow.ensure(context);
    if (!mounted) return;
    if (!status.isGranted && !status.isLimited) {
      _setLocationFallback(
        provider.booking.fromLat != null
            ? 'GPS недоступен — поиск считаем от выбранного адреса'
            : 'GPS недоступен — выберите адрес подачи вручную',
      );
      if (!silent) {
        showAppSnackBar(
          context,
          DeviceLocationCopy.denied,
          isError: true,
        );
      }
      return;
    }

    final pos = await DeviceLocation.getCurrentPosition();
    if (!mounted) return;
    if (pos == null) {
      _setLocationFallback(
        provider.booking.fromLat != null
            ? 'Нет сигнала GPS — поиск считаем от выбранного адреса'
            : 'Нет сигнала GPS — выберите адрес подачи вручную',
      );
      if (!silent) {
        showAppSnackBar(
          context,
          DeviceLocationCopy.failed,
          isError: true,
        );
      }
      return;
    }

    var label = 'Моё местоположение';
    try {
      final geo = context.read<GeoSearchService>()
        ..setSearchCenter(lat: pos.lat, lng: pos.lng);
      final reversed = await geo.geocode('${pos.lng},${pos.lat}');
      if (reversed != null && reversed.displayAddress.isNotEmpty) {
        label = reversed.displayAddress;
      }
    } catch (_) {}

    if (!mounted) return;
    _setLocationFallback(null);
    _fromController.text = label;
    provider.updateFromAddressWithCoords(label, lat: pos.lat, lng: pos.lng);
    context.read<GeoSearchService>().setSearchCenter(
          lat: pos.lat,
          lng: pos.lng,
        );
    _mapCamera.moveTo(pos.lat, pos.lng, zoom: 16.5);
  }

  void _onFromSuggestion(AddressSuggestionDto item) {
    final text = item.displayAddress;
    _fromController.text = text;
    final provider = context.read<BookingProvider>();
    if (item.hasCoordinates) {
      provider.updateFromAddressWithCoords(
        text,
        lat: item.lat!,
        lng: item.lng!,
      );
      context.read<GeoSearchService>().setSearchCenter(
            lat: item.lat!,
            lng: item.lng!,
          );
      if (_locationFallbackMessage != null) {
        _setLocationFallback(
          'Ближайших водителей ищем от выбранного адреса',
        );
      }
    } else {
      provider.updateFromAddress(text);
    }
  }

  void _setLocationFallback(String? message) {
    if (!mounted || _locationFallbackMessage == message) return;
    setState(() => _locationFallbackMessage = message);
  }

  void _onToSuggestion(AddressSuggestionDto item) {
    final text = item.displayAddress;
    _toController.text = text;
    final provider = context.read<BookingProvider>();
    if (item.hasCoordinates) {
      provider.updateToAddressWithCoords(
        text,
        lat: item.lat!,
        lng: item.lng!,
      );
      provider.setFlowStep(BookingFlowStep.tariffs);
    } else {
      provider.updateToAddress(text);
    }
  }

  void _ensureTariffsLoaded(BookingProvider provider) {
    final booking = provider.booking;
    if (provider.tariffsState == TariffsLoadState.loading) return;
    final key = [
      booking.serviceType.name,
      booking.fromAddress,
      booking.toAddress,
    ].join('|');
    if (_tariffsRouteKey == key && provider.availableTariffs.isNotEmpty) {
      return;
    }
    _tariffsRouteKey = key;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<BookingProvider>().loadTariffs();
    });
  }

  void _onCameraMoving() {
    final step = context.read<BookingProvider>().flowStep;
    if (step != BookingFlowStep.pickup &&
        step != BookingFlowStep.destinationMap) {
      return;
    }
    _scheduleSheetReturn(const Duration(milliseconds: 420));
    if (_mapMoving) return;
    setState(() => _mapMoving = true);
  }

  void _scheduleSheetReturn(Duration delay) {
    _sheetReturnDelay?.cancel();
    _sheetReturnDelay = Timer(delay, () {
      if (!mounted || !_mapMoving) return;
      setState(() => _mapMoving = false);
    });
  }

  void _onCameraIdle(double lat, double lng) {
    final provider = context.read<BookingProvider>();
    final step = provider.flowStep;
    if (step != BookingFlowStep.pickup &&
        step != BookingFlowStep.destinationMap) {
      if (_mapMoving) {
        _scheduleSheetReturn(const Duration(milliseconds: 300));
      }
      return;
    }
    if (_mapMoving) {
      _scheduleSheetReturn(const Duration(milliseconds: 300));
    }

    _geocodeDebounce?.cancel();
    _geocodeDebounce = Timer(const Duration(milliseconds: 350), () {
      unawaited(_reverseGeocodePin(lat, lng, step));
    });
  }

  Future<void> _reverseGeocodePin(
    double lat,
    double lng,
    BookingFlowStep step,
  ) async {
    final requestId = ++_geocodeRequestId;
    AddressSuggestionDto? reversed;
    try {
      final geo = context.read<GeoSearchService>()
        ..setSearchCenter(lat: lat, lng: lng);
      reversed = await geo.geocode('$lng,$lat');
    } catch (_) {}
    if (!mounted || requestId != _geocodeRequestId) return;
    final label = reversed?.displayAddress.isNotEmpty == true
        ? reversed!.displayAddress
        : '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';
    final provider = context.read<BookingProvider>();
    if (step == BookingFlowStep.pickup) {
      _fromController.text = label;
      provider.updateFromAddressWithCoords(label, lat: lat, lng: lng);
      context.read<GeoSearchService>().setSearchCenter(lat: lat, lng: lng);
    } else if (step == BookingFlowStep.destinationMap) {
      _toController.text = label;
      provider.updateToAddressWithCoords(label, lat: lat, lng: lng);
    }
  }

  Future<void> _submitInlineOrder(BookingProvider provider) async {
    final booking = provider.booking;
    if (!booking.isReadyToOrder) {
      showAppSnackBar(
        context,
        booking.hasRouteCoords
            ? 'Выберите тариф'
            : 'Выберите адреса из подсказок, чтобы построить маршрут',
        isError: true,
      );
      return;
    }

    final method = booking.paymentMethod;
    final payment = PaymentService.instance;
    if (method != PaymentMethod.cash && !await payment.isAvailable(method)) {
      if (!mounted) return;
      showAppSnackBar(context, payment.unavailableMessage(method),
          isError: true);
      return;
    }

    final success = await provider.submitOrder();
    if (!mounted) return;
    if (!success) {
      final error = provider.booking.submitError ?? 'Не удалось создать заказ';
      if (error.toLowerCase().contains('active order')) {
        final active = await provider.apiServices.order.fetchActiveOrder();
        if (!mounted) return;
        if (active != null) {
          await ActiveOrderStore.save(active.id);
          if (!mounted) return;
          context.go(AppRoutes.activeTrip);
          return;
        }
      }
      showAppSnackBar(
        context,
        _friendlySubmitError(error),
        isError: true,
      );
      return;
    }

    final orderId = provider.booking.orderId;
    if (method != PaymentMethod.cash && orderId != null) {
      final result =
          await payment.startForOrder(orderId: orderId, method: method);
      if (!mounted) return;
      if (result == PaymentHandleResult.unavailable) {
        showAppSnackBar(
          context,
          'Заказ создан, но платёжную страницу открыть не удалось',
          isError: true,
        );
      }
    }

    if (!mounted) return;
    context.go(AppRoutes.activeTrip);
  }

  String _friendlySubmitError(String error) {
    final lower = error.toLowerCase();
    if (lower.contains('active order')) {
      return 'У вас уже есть активный заказ';
    }
    if (lower.contains('network') || lower.contains('socket')) {
      return 'Нет связи с сервером. Попробуйте ещё раз';
    }
    return error;
  }

  Future<void> _pickDate(BuildContext context, BookingProvider provider) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: provider.booking.date ?? now.add(const Duration(hours: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 30)),
      locale: const Locale('ru', 'RU'),
      builder: (context, child) =>
          Theme(data: Theme.of(context), child: child!),
    );
    if (date == null || !context.mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
        provider.booking.date ?? now.add(const Duration(hours: 1)),
      ),
      builder: (context, child) =>
          Theme(data: Theme.of(context), child: child!),
    );
    if (time == null || !context.mounted) return;

    provider.setDate(
      DateTime(date.year, date.month, date.day, time.hour, time.minute),
    );
  }

  MapPinMode _pinModeFor(BookingFlowStep step) {
    return switch (step) {
      BookingFlowStep.pickup => MapPinMode.pickup,
      BookingFlowStep.destinationMap => MapPinMode.destination,
      _ => MapPinMode.none,
    };
  }

  @override
  void dispose() {
    _geocodeDebounce?.cancel();
    _fromController.dispose();
    _toController.dispose();
    _toFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.paddingOf(context).top;
    final p = context.palette;

    return Scaffold(
      body: Consumer2<BookingProvider, ProfileProvider>(
        builder: (context, provider, profile, _) {
          final booking = provider.booking;
          final step = provider.flowStep;
          final pinMode = _pinModeFor(step);
          final points = booking.routePoints.length >= 2
              ? booking.routePoints
              : routePointsForBooking(
                  fromLat: booking.fromLat,
                  fromLng: booking.fromLng,
                  toLat: booking.toLat,
                  toLng: booking.toLng,
                );

          // For pin modes, feed at least the known endpoint so map has context.
          final mapPoints = switch (pinMode) {
            MapPinMode.pickup when booking.fromLat != null => <MapPoint>[
                (lat: booking.fromLat!, lng: booking.fromLng!),
                if (booking.toLat != null)
                  (lat: booking.toLat!, lng: booking.toLng!),
              ],
            MapPinMode.destination when booking.fromLat != null => <MapPoint>[
                (lat: booking.fromLat!, lng: booking.fromLng!),
                if (booking.toLat != null)
                  (lat: booking.toLat!, lng: booking.toLng!),
              ],
            _ => points,
          };

          if (step == BookingFlowStep.tariffs) {
            _ensureTariffsLoaded(provider);
          }

          final canOrder = booking.isReadyToOrder &&
              !booking.isSubmitting &&
              provider.canUseCurrentPrice &&
              !provider.priceQuoteLoading &&
              provider.tariffsState != TariffsLoadState.loading;

          final sheetCollapsed = _mapMoving &&
              (step == BookingFlowStep.pickup ||
                  step == BookingFlowStep.destinationMap);

          return Stack(
            children: [
              Positioned.fill(
                child: MapHost(
                  routePoints: mapPoints,
                  showUserPin: pinMode == MapPinMode.none,
                  showDriverMarker: false,
                  showSetupHint: false,
                  pinMode: pinMode,
                  nightMode: context.isDarkTheme,
                  cameraController: _mapCamera,
                  onCameraMoving: _onCameraMoving,
                  onCameraIdle: _onCameraIdle,
                ),
              ),
              if (pinMode != MapPinMode.none)
                Positioned.fill(
                  child: CenterMapPin(
                    mode: pinMode,
                    lifting: _mapMoving,
                    etaMinutes: 5,
                  ),
                ),
              if (_locationFallbackMessage != null &&
                  step != BookingFlowStep.destinationSearch)
                Positioned(
                  top: topPad + 8,
                  left: 12,
                  right: 92,
                  child: _LocationFallbackChip(
                    message: _locationFallbackMessage!,
                    onRetry: () => _useCurrentLocation(silent: false),
                  ),
                ),
              if (step != BookingFlowStep.destinationSearch)
                Positioned(
                  top: topPad + 8,
                  right: 6,
                  child: Column(
                    children: [
                      Material(
                        color: p.bgSecondary.withValues(alpha: 0.94),
                        shape: const CircleBorder(),
                        elevation: 3,
                        shadowColor: Colors.black38,
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => _useCurrentLocation(),
                          child: const SizedBox(
                            width: 48,
                            height: 48,
                            child: Icon(
                              Icons.my_location_rounded,
                              color: AppColors.gold,
                              size: 22,
                            ),
                          ),
                        ),
                      ),
                      if (step == BookingFlowStep.tariffs &&
                          booking.fromLat != null) ...[
                        const SizedBox(height: 10),
                        Material(
                          color: p.bgSecondary.withValues(alpha: 0.94),
                          borderRadius: BorderRadius.circular(14),
                          elevation: 3,
                          shadowColor: Colors.black38,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () {
                              provider.setFlowStep(BookingFlowStep.pickup);
                              if (booking.fromLat != null) {
                                _mapCamera.moveTo(
                                  booking.fromLat!,
                                  booking.fromLng!,
                                  zoom: 16.5,
                                );
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 22,
                                    height: 22,
                                    alignment: Alignment.center,
                                    decoration: const BoxDecoration(
                                      color: AppColors.purple,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Text(
                                      'А',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Подача',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13,
                                      color: p.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              if (step == BookingFlowStep.pickup)
                MapBottomSheet(
                  collapsed: sheetCollapsed,
                  halfHeightFactor: 0.35,
                  maxHeightFactor: 0.52,
                  fitChild: false,
                  padding: EdgeInsets.fromLTRB(
                    16,
                    10,
                    16,
                    MediaQuery.paddingOf(context).bottom + 12,
                  ),
                  child: GoHomeSheet(
                    recentDestinations: _recentDestinations,
                    savedPlaces: _savedPlaces(profile),
                    serviceType: booking.serviceType,
                    pickupAddress: booking.fromAddress,
                    onConfirmPickup: booking.toAddress.trim().isNotEmpty
                        ? () => provider.setFlowStep(BookingFlowStep.tariffs)
                        : null,
                    onWhereTo: () {
                      provider.setFlowStep(BookingFlowStep.destinationSearch);
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _toFocusNode.requestFocus();
                      });
                    },
                    onSelectRecent: (address) =>
                        _selectKnownAddress(address, asDestination: true),
                    onSelectSaved: (address) =>
                        _selectKnownAddress(address, asDestination: true),
                  ),
                ),
              if (step == BookingFlowStep.destinationMap)
                MapBottomSheet(
                  collapsed: sheetCollapsed,
                  halfHeightFactor: 0.28,
                  maxHeightFactor: 0.28,
                  expandable: false,
                  padding: EdgeInsets.fromLTRB(
                    16,
                    8,
                    16,
                    MediaQuery.paddingOf(context).bottom + 12,
                  ),
                  child: DestinationMapSheet(
                    address: booking.toAddress,
                    geocoding: false,
                    onBack: () =>
                        provider.setFlowStep(BookingFlowStep.destinationSearch),
                    onDone: () {
                      if (booking.toLat == null) return;
                      provider.setFlowStep(BookingFlowStep.tariffs);
                    },
                  ),
                ),
              if (step == BookingFlowStep.tariffs)
                MapBottomSheet(
                  halfHeightFactor: 0.365,
                  maxHeightFactor: 0.42,
                  padding: EdgeInsets.fromLTRB(
                    16,
                    10,
                    16,
                    MediaQuery.paddingOf(context).bottom + 8,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (booking.isSoberMode) ...[
                        ServiceTypeSelector(
                          selected: booking.serviceType,
                          onChanged: provider.setServiceType,
                          compact: true,
                        ),
                        const SizedBox(height: 8),
                        Consumer<VehiclesProvider>(
                          builder: (context, vehicles, _) {
                            if (!vehicles.loaded) {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                vehicles.load();
                              });
                            }
                            final selected = vehicles.selectedVehicle;
                            if (selected != null &&
                                booking.selectedVehicleId != selected.id) {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                provider.selectVehicle(
                                  selected.id,
                                  vehicleDescription: selected.description,
                                );
                              });
                            }
                            return _VehiclePicker(
                              vehicles: vehicles.vehicles,
                              selectedId: booking.selectedVehicleId,
                              onSelect: (v) => provider.selectVehicle(
                                v?.id,
                                vehicleDescription: v?.description,
                              ),
                              onManage: () => context.push(AppRoutes.vehicles),
                            );
                          },
                        ),
                        const SizedBox(height: 8),
                      ],
                      TariffSelectSheet(
                        fromAddress: booking.fromAddress,
                        toAddress: booking.toAddress,
                        tariffs: provider.availableTariffs,
                        selected: booking.selectedTariff,
                        tab: _tariffTab,
                        loading:
                            provider.tariffsState == TariffsLoadState.loading,
                        routeReady: booking.isRouteComplete,
                        priceFor: provider.estimateForTariff,
                        etaMinutes: booking.routeDurationSec != null
                            ? (booking.routeDurationSec! / 60)
                                .ceil()
                                .clamp(1, 180)
                            : null,
                        paymentMethod: booking.paymentMethod,
                        canOrder: canOrder,
                        isSubmitting: booking.isSubmitting,
                        pricingLoading: provider.priceQuoteLoading,
                        priceError: provider.priceQuoteError,
                        onTabChanged: (tab) => setState(() => _tariffTab = tab),
                        onSelectTariff: provider.selectTariff,
                        onEditRoute: () => provider
                            .setFlowStep(BookingFlowStep.destinationSearch),
                        onPriceTap: () => showFareBreakdownSheet(
                          context,
                          booking: booking,
                          discountPercent: booking.discountPercent,
                        ),
                        onPaymentTap: () async {
                          final method = await showPaymentMethodSheet(
                            context: context,
                            current: booking.paymentMethod,
                          );
                          if (method != null && mounted) {
                            provider.selectPaymentMethod(method);
                          }
                        },
                        onOptionsTap: () => showOrderOptionsSheet(
                          context: context,
                          provider: provider,
                          onPickDate: () => _pickDate(context, provider),
                        ),
                        onOrder: () => _submitInlineOrder(provider),
                        onRetryPrice: provider.refreshPriceQuote,
                      ),
                    ],
                  ),
                ),
              if (step == BookingFlowStep.destinationSearch)
                Positioned.fill(
                  child: ColoredBox(
                    color: Colors.black.withValues(alpha: 0.35),
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: FractionallySizedBox(
                        heightFactor: 0.92,
                        child: DestinationSearchSheet(
                          fromController: _fromController,
                          toController: _toController,
                          toFocusNode: _toFocusNode,
                          recentDestinations: _recentDestinations,
                          savedPlaces: _savedPlaces(profile),
                          onClose: () =>
                              provider.setFlowStep(BookingFlowStep.pickup),
                          onFromChanged: provider.updateFromAddress,
                          onToChanged: provider.updateToAddress,
                          onFromSuggestion: _onFromSuggestion,
                          onToSuggestion: _onToSuggestion,
                          onUseCurrentLocation: () => _useCurrentLocation(),
                          onOpenMap: () => provider
                              .setFlowStep(BookingFlowStep.destinationMap),
                          onSelectRecent: (address) => _selectKnownAddress(
                            address,
                            asDestination: true,
                          ),
                          onSelectSaved: (address) => _selectKnownAddress(
                            address,
                            asDestination: true,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _VehiclePicker extends StatelessWidget {
  const _VehiclePicker({
    required this.vehicles,
    required this.selectedId,
    required this.onSelect,
    required this.onManage,
  });

  final List<ClientVehicle> vehicles;
  final String? selectedId;
  final void Function(ClientVehicle? vehicle) onSelect;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    if (vehicles.isEmpty) {
      return OutlinedButton.icon(
        onPressed: onManage,
        icon: const Icon(Icons.directions_car_outlined, size: 18),
        label: const Text('Добавить автомобиль для трезвого водителя'),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Ваш автомобиль',
          style: TextStyle(
            color: AppColors.textMuted,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue:
              selectedId != null && vehicles.any((v) => v.id == selectedId)
                  ? selectedId
                  : null,
          decoration: const InputDecoration(
            isDense: true,
            prefixIcon: Icon(Icons.directions_car_filled_outlined),
          ),
          hint: const Text('Выберите автомобиль'),
          items: vehicles
              .map(
                (v) => DropdownMenuItem<String>(
                  value: v.id,
                  child: Text(v.label),
                ),
              )
              .toList(),
          onChanged: (id) {
            if (id == null) {
              onSelect(null);
              return;
            }
            for (final v in vehicles) {
              if (v.id == id) {
                onSelect(v);
                break;
              }
            }
          },
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: onManage,
            child: const Text('Управление автомобилями'),
          ),
        ),
      ],
    );
  }
}

class _LocationFallbackChip extends StatelessWidget {
  const _LocationFallbackChip({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Material(
      color: p.bgSecondary.withValues(alpha: 0.96),
      borderRadius: BorderRadius.circular(14),
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.16),
      child: InkWell(
        onTap: onRetry,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
          child: Row(
            children: [
              const Icon(
                Icons.location_off_rounded,
                color: AppColors.gold,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: p.textPrimary,
                    fontSize: 11.5,
                    height: 1.2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
