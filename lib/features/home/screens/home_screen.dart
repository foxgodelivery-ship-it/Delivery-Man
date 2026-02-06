import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shimmer_animation/shimmer_animation.dart';
import 'package:sixam_mart_delivery/features/auth/controllers/auth_controller.dart';
import 'package:sixam_mart_delivery/features/home/widgets/order_count_card_widget.dart';
import 'package:sixam_mart_delivery/features/notification/controllers/notification_controller.dart';
import 'package:sixam_mart_delivery/features/order/controllers/order_controller.dart';
import 'package:sixam_mart_delivery/features/profile/controllers/profile_controller.dart';
import 'package:sixam_mart_delivery/features/refer_and_earn/screens/refer_and_earn_screen.dart';
import 'package:sixam_mart_delivery/features/refer_and_earn/widgets/refer_bottom_sheet.dart';
import 'package:sixam_mart_delivery/features/splash/controllers/splash_controller.dart';
import 'package:sixam_mart_delivery/helper/price_converter_helper.dart';
import 'package:sixam_mart_delivery/helper/route_helper.dart';
import 'package:sixam_mart_delivery/util/app_constants.dart';
import 'package:sixam_mart_delivery/util/color_resources.dart';
import 'package:sixam_mart_delivery/util/dimensions.dart';
import 'package:sixam_mart_delivery/util/images.dart';
import 'package:sixam_mart_delivery/util/styles.dart';
import 'package:sixam_mart_delivery/common/widgets/custom_button_widget.dart';
import 'package:sixam_mart_delivery/common/widgets/order_shimmer_widget.dart';
import 'package:sixam_mart_delivery/common/widgets/order_widget.dart';
import 'package:sixam_mart_delivery/common/widgets/title_widget.dart';
import 'package:sixam_mart_delivery/common/widgets/confirmation_dialog_widget.dart';
import 'package:sixam_mart_delivery/features/home/widgets/count_card_widget.dart';
import 'package:sixam_mart_delivery/features/home/widgets/earning_widget.dart';
import 'package:sixam_mart_delivery/features/order/screens/running_order_screen.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {

  late final AppLifecycleListener _listener;
  bool _isNotificationPermissionGranted = true;
  bool _isBatteryOptimizationGranted = true;
  GoogleMapController? _mapController;
  StreamSubscription<Position>? _posSub;

  LatLng? _liveLatLng;
  final Set<Marker> _liveMarkers = <Marker>{};
  bool _locationGranted = false;

  Timer? _dotsTimer;
  int _dots = 1;

  @override
  void initState() {
    super.initState();

    _checkSystemNotification();

    _listener = AppLifecycleListener(
      onStateChange: _onStateChanged,
    );

    _loadData();
    _startDots();
    _startLiveLocation();

    Future.delayed(const Duration(milliseconds: 200), () {
      checkPermission();
    });
  }

  Future<void> _loadData() async {
    Get.find<OrderController>().getIgnoreList();
    Get.find<OrderController>().removeFromIgnoreList();
    await Get.find<ProfileController>().getProfile();
    await Get.find<OrderController>().getCurrentOrders();
    await Get.find<NotificationController>().getNotificationList();
  }

  Future<void> _checkSystemNotification() async {
    if(await Permission.notification.status.isDenied || await Permission.notification.status.isPermanentlyDenied) {
      await Get.find<AuthController>().setNotificationActive(false);
    }
  }

  // Listen to the app lifecycle state changes
  void _onStateChanged(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.detached:
        break;
      case AppLifecycleState.resumed:
        checkPermission();
        break;
      case AppLifecycleState.inactive:
        break;
      case AppLifecycleState.hidden:
        break;
      case AppLifecycleState.paused:
        break;
    }
  }

  Future<void> checkPermission() async {
    var notificationStatus = await Permission.notification.status;
    var batteryStatus = await Permission.ignoreBatteryOptimizations.status;

    if(notificationStatus.isDenied || notificationStatus.isPermanentlyDenied) {
      setState(() {
        _isNotificationPermissionGranted = false;
        _isBatteryOptimizationGranted = true;
      });

      await Get.find<AuthController>().setNotificationActive(!notificationStatus.isDenied);

    } else if(batteryStatus.isDenied) {
      setState(() {
        _isBatteryOptimizationGranted = false;
        _isNotificationPermissionGranted = true;
      });
    } else {
      setState(() {
        _isNotificationPermissionGranted = true;
        _isBatteryOptimizationGranted = true;
      });
      Get.find<ProfileController>().setBackgroundNotificationActive(true);
    }

    if(batteryStatus.isDenied) {
      Get.find<ProfileController>().setBackgroundNotificationActive(false);
    }
  }

  Future<void> requestNotificationPermission() async {
    if (await Permission.notification.request().isGranted) {
      checkPermission();
      return;
    } else {
      await openAppSettings();
    }

    checkPermission();
  }

  void requestBatteryOptimization() async {
    var status = await Permission.ignoreBatteryOptimizations.status;

    if (status.isGranted) {
      return;
    } else if(status.isDenied) {
      await Permission.ignoreBatteryOptimizations.request();
    } else {
      openAppSettings();
    }

    checkPermission();
  }

  void _startDots() {
    _dotsTimer?.cancel();
    _dotsTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if(!mounted) return;
      setState(() {
        _dots = _dots >= 3 ? 1 : _dots + 1;
      });
    });
  }

  Future<void> _startLiveLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if(permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if(permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        if(!mounted) return;
        setState(() => _locationGranted = false);
        return;
      }

      if(!mounted) return;
      setState(() => _locationGranted = true);

      final Position first = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
      );
      _applyLivePosition(first);

      _posSub?.cancel();
      _posSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 10,
        ),
      ).listen(_applyLivePosition);

    } catch (_) {
      if(!mounted) return;
      setState(() => _locationGranted = false);
    }
  }

  void _applyLivePosition(Position p) {
    if(!mounted) return;

    final LatLng next = LatLng(p.latitude, p.longitude);

    setState(() {
      _liveLatLng = next;
      _liveMarkers
        ..clear()
        ..add(
          Marker(
            markerId: const MarkerId('me'),
            position: next,
            anchor: const Offset(0.5, 0.5),
          ),
        );
    });

    _mapController?.animateCamera(CameraUpdate.newLatLng(next));
  }

  Widget _buildMapLayer() {
    final initial = _liveLatLng ?? const LatLng(0, 0);

    return GoogleMap(
      initialCameraPosition: CameraPosition(target: initial, zoom: 16),
      zoomControlsEnabled: false,
      myLocationButtonEnabled: false,
      myLocationEnabled: _locationGranted,
      compassEnabled: false,
      mapToolbarEnabled: false,
      buildingsEnabled: true,
      markers: _liveMarkers,
      onMapCreated: (c) => _mapController = c,
    );
  }

  Widget _buildSearchingButton(BuildContext context) {
    final double safeBottom = MediaQuery.of(context).padding.bottom;
    final String dots = '.' * _dots;

    return Positioned(
      left: 16,
      right: 16,
      bottom: safeBottom + 12,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: Theme.of(context).primaryColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Text(
            'Buscando Pedidos$dots',
            key: ValueKey(dots),
            style: robotoBold.copyWith(
              color: Colors.white,
              fontSize: Dimensions.fontSizeLarge,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopCards() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Column(
          children: [

            // Card 1: Status + Saldo + botão Conectar (somente quando Offline)
            GetBuilder<ProfileController>(builder: (profileController) {
              final bool isOnline = profileController.profileModel?.active == 1;
              final String balance = profileController.profileModel != null
                  ? PriceConverterHelper.convertPrice(profileController.profileModel!.balance)
                  : '--';

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(Get.context!).cardColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: isOnline ? const Color(0xFF10B981) : Colors.grey,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                isOnline ? 'Online' : 'Offline',
                                style: robotoMedium.copyWith(
                                  fontSize: Dimensions.fontSizeDefault,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Saldo',
                            style: robotoRegular.copyWith(
                              color: Theme.of(Get.context!).disabledColor,
                              fontSize: Dimensions.fontSizeSmall,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            balance,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: robotoBold.copyWith(
                              fontSize: Dimensions.fontSizeOverLarge,
                            ),
                          ),
                        ],
                      ),
                    ),

                    if(!isOnline)
                      SizedBox(
                        height: 40,
                        child: CustomButtonWidget(
                          width: 120,
                          height: 40,
                          fontSize: Dimensions.fontSizeDefault,
                          isBold: true,
                          buttonText: 'Conectar',
                          onPressed: () {
                            profileController.updateActiveStatus();
                          },
                        ),
                      ),
                  ],
                ),
              );
            }),

            const SizedBox(height: 12),

            // Card 2: Pedido ativo (somente quando existir)
            GetBuilder<OrderController>(builder: (orderController) {
              final bool hasActive = orderController.currentOrderList != null && orderController.currentOrderList!.isNotEmpty;
              if(!hasActive) return const SizedBox();

              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(Get.context!).cardColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: OrderWidget(
                  orderModel: orderController.currentOrderList![0],
                  isRunningOrder: true,
                  orderIndex: 0,
                  cardWidth: double.infinity,
                ),
              );
            }),

          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _dotsTimer?.cancel();
    _mapController?.dispose();
    _listener.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        leading: Builder(builder: (context) {
          return IconButton(
            icon: Icon(Icons.menu, color: Theme.of(context).textTheme.bodyLarge!.color),
            onPressed: () => Scaffold.of(context).openDrawer(),
            tooltip: 'Menu',
          );
        }),
        titleSpacing: 0,
        title: Text('Fox Entregador', maxLines: 1, overflow: TextOverflow.ellipsis, style: robotoMedium.copyWith(
          color: Theme.of(context).textTheme.bodyLarge!.color, fontSize: Dimensions.fontSizeDefault,
        )),

      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: Theme.of(context).primaryColor),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Image.asset(Images.logo, height: 40, width: 40),
                  const SizedBox(height: Dimensions.paddingSizeSmall),
                  Text(AppConstants.appName, style: robotoMedium.copyWith(color: Colors.white)),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.assignment_outlined),
              title: const Text('Atividades'),
              onTap: () {
                Get.back();
                Get.toNamed(RouteHelper.getMainRoute('order'));
              },
            ),
            ListTile(
              leading: const Icon(Icons.account_balance_wallet_outlined),
              title: const Text('Ganhos'),
              onTap: () {
                Get.back();
                Get.toNamed(RouteHelper.getMyEarningRoute());
              },
            ),
            ListTile(
              leading: const Icon(Icons.payments_outlined),
              title: const Text('Carteira / Saques'),
              onTap: () {
                Get.back();
                Get.toNamed(RouteHelper.getWithdrawMethodRoute());
              },
            ),
            ListTile(
              leading: const Icon(Icons.chat_bubble_outline),
              title: const Text('Chat'),
              onTap: () {
                Get.back();
                Get.toNamed(RouteHelper.getConversationListRoute());
              },
            ),
            ListTile(
              leading: const Icon(Icons.notifications_outlined),
              title: const Text('Notificações'),
              onTap: () {
                Get.back();
                Get.toNamed(RouteHelper.getNotificationRoute());
              },
            ),
            ListTile(
              leading: const Icon(Icons.card_giftcard_outlined),
              title: const Text('Refer & Ganhe'),
              onTap: () {
                Get.back();
                Get.to(() => const ReferAndEarnScreen());
              },
            ),
            ListTile(
              leading: const Icon(Icons.support_agent_outlined),
              title: const Text('Suporte / SOS'),
              onTap: () {
                Get.back();
                Get.toNamed(RouteHelper.getConversationListRoute());
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.description_outlined),
              title: const Text('Termos'),
              onTap: () {
                Get.back();
                Get.toNamed(RouteHelper.getTermsRoute());
              },
            ),
            ListTile(
              leading: const Icon(Icons.privacy_tip_outlined),
              title: const Text('Privacidade'),
              onTap: () {
                Get.back();
                Get.toNamed(RouteHelper.getPrivacyRoute());
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Sair'),
              onTap: () {
                Get.back();
                Get.dialog(ConfirmationDialogWidget(
                  icon: Images.support,
                  description: 'are_you_sure_to_logout'.tr,
                  isLogOut: true,
                  onYesPressed: () {
                    Get.find<AuthController>().clearSharedData();
                    Get.find<ProfileController>().stopLocationRecord();
                    Get.offAllNamed(RouteHelper.getSignInRoute());
                  },
                ));
              },
            ),
          ],
        ),
      ),

      body: Stack(
        children: [

          // MAPA FUNDO 100%
          Positioned.fill(child: _buildMapLayer()),

          // OVERLAY GRADIENTE PARA LEGIBILIDADE DO TOPO
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.center,
                    colors: [
                      Color(0x99000000),
                      Color(0x00000000),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // CARDS SUPERIORES (FLOTA NO MAPA)
          _buildTopCards(),

          // PAINEL INFERIOR ARRASTÁVEL COM TODO O CONTEÚDO QUE EXISTIA ANTES
          DraggableScrollableSheet(
            initialChildSize: 0.22,
            minChildSize: 0.18,
            maxChildSize: 0.88,
            builder: (context, scrollController) {
              return Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 20,
                      offset: const Offset(0, -6),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Theme.of(context).disabledColor.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(50),
                      ),
                    ),
                    const SizedBox(height: 10),

                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: () async => await _loadData(),
                        child: SingleChildScrollView(
                          controller: scrollController,
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.only(bottom: 110),
                          child: Column(
                            children: [

                              // MANTER permission warnings (sem mudar lógica)
                              if(!_isNotificationPermissionGranted)
                                permissionWarning(
                                  isBatteryPermission: false,
                                  onTap: requestNotificationPermission,
                                  closeOnTap: () {
                                    setState(() {
                                      _isNotificationPermissionGranted = true;
                                    });
                                  },
                                ),

                              if(!_isBatteryOptimizationGranted)
                                permissionWarning(
                                  isBatteryPermission: true,
                                  onTap: requestBatteryOptimization,
                                  closeOnTap: () {
                                    setState(() {
                                      _isBatteryOptimizationGranted = true;
                                    });
                                  },
                                ),

                              GetBuilder<ProfileController>(builder: (profileController) {

                                bool showReferAndEarn = Get.find<ProfileController>().profileModel != null && Get.find<ProfileController>().profileModel!.earnings == 1
                                    && (Get.find<SplashController>().configModel?.dmReferralData?.dmReferalStatus == true
                                        || (Get.find<ProfileController>().profileModel?.referalEarning != null && Get.find<ProfileController>().profileModel!.referalEarning! > 0));

                                return Column(children: [

                                  GetBuilder<OrderController>(builder: (orderController) {

                                    bool hasActiveOrder = orderController.currentOrderList == null || orderController.currentOrderList!.isNotEmpty;
                                    bool hasMoreOrder = orderController.currentOrderList != null && orderController.currentOrderList!.length > 1;

                                    return Container(
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                                      ),
                                      padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeDefault),
                                      child: Column(children: [
                                        const SizedBox(height: Dimensions.paddingSizeSmall),

                                        hasActiveOrder ? TitleWidget(
                                          title: 'active_order'.tr, showOrderCount: true, orderCount: orderController.currentOrderList?.length ?? 0,
                                            onTap: hasMoreOrder ? () {
                                            Get.toNamed(RouteHelper.getRunningOrderRoute(), arguments: const RunningOrderScreen());
                                          } : null,
                                        ) : const SizedBox(),
                                        SizedBox(height: hasActiveOrder ? Dimensions.paddingSizeExtraSmall : 0),

                                        orderController.currentOrderList == null || orderController.currentOrderList!.isNotEmpty
                                            ? LayoutBuilder(builder: (context, constraints) {
                                          final double cardWidth = constraints.maxWidth >= 700 ? 520 : constraints.maxWidth * 0.9;
                                          final Widget orderCard = orderController.currentOrderList == null
                                              ? OrderShimmerWidget(isEnabled: orderController.currentOrderList == null)
                                              : OrderWidget(
                                                orderModel: orderController.currentOrderList![0],
                                                isRunningOrder: true,
                                                orderIndex: 0,
                                                cardWidth: cardWidth,
                                              );
                                          return Align(
                                            alignment: Alignment.topCenter,
                                            child: SizedBox(width: cardWidth, child: orderCard),
                                          );
                                        })
                                            : const SizedBox(),
                                        SizedBox(height: hasActiveOrder ? Dimensions.paddingSizeDefault : 0),

                                      ]),
                                    );
                                  }),

                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeDefault, vertical: Dimensions.paddingSizeSmall),
                                    child: Column(children: [
                                      (profileController.profileModel != null && profileController.profileModel!.earnings == 1) ? Column(children: [

                                        TitleWidget(title: 'earnings'.tr),
                                        const SizedBox(height: Dimensions.paddingSizeSmall),

                                        Container(
                                          padding: const EdgeInsets.all(Dimensions.paddingSizeLarge),
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
                                            color: Theme.of(context).primaryColor,
                                          ),
                                          child: Column(children: [

                                            Row(mainAxisAlignment: MainAxisAlignment.start, children: [

                                              const SizedBox(width: Dimensions.paddingSizeSmall),
                                              Container(
                                                decoration: BoxDecoration(
                                                  color: Theme.of(context).cardColor.withValues(alpha: 0.1),
                                                  borderRadius: BorderRadius.circular(50),
                                                ),
                                                padding: const EdgeInsets.only(bottom: Dimensions.paddingSizeDefault, left: Dimensions.paddingSizeDefault, top: Dimensions.paddingSizeSmall, right: Dimensions.paddingSizeSmall),
                                                child: Image.asset(Images.wallet, width: 40, height: 40),
                                              ),
                                              const SizedBox(width: Dimensions.paddingSizeLarge),

                                              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                                                Text(
                                                  'balance'.tr,
                                                  style: robotoMedium.copyWith(fontSize: Dimensions.fontSizeSmall, color: Theme.of(context).cardColor.withValues(alpha: 0.9)),
                                                ),
                                                const SizedBox(height: Dimensions.paddingSizeExtraSmall),

                                                profileController.profileModel != null ? Text(
                                                  PriceConverterHelper.convertPrice(profileController.profileModel!.balance),
                                                  style: robotoBold.copyWith(fontSize: 24, color: Theme.of(context).cardColor),
                                                  maxLines: 1, overflow: TextOverflow.ellipsis,
                                                ) : Container(height: 30, width: 60, color: Colors.white),

                                              ]),
                                            ]),
                                            const SizedBox(height: Dimensions.paddingSizeLarge),
                                            Row(children: [

                                              EarningWidget(
                                                title: 'today'.tr,
                                                amount: profileController.profileModel?.todaysEarning,
                                              ),
                                              Container(height: 30, width: 1, color: Theme.of(context).cardColor.withValues(alpha: 0.8)),

                                              EarningWidget(
                                                title: 'this_week'.tr,
                                                amount: profileController.profileModel?.thisWeekEarning,
                                              ),
                                              Container(height: 30, width: 1, color: Theme.of(context).cardColor.withValues(alpha: 0.8)),

                                              EarningWidget(
                                                title: 'this_month'.tr,
                                                amount: profileController.profileModel?.thisMonthEarning,
                                              ),

                                            ]),

                                          ]),
                                        ),
                                        const SizedBox(height: Dimensions.paddingSizeDefault),
                                      ]) : const SizedBox(),

                                      TitleWidget(title: 'orders'.tr),
                                      const SizedBox(height: Dimensions.paddingSizeExtraSmall),

                                      (profileController.profileModel != null && profileController.profileModel!.earnings == 1) ? Row(children: [

                                        OrderCountCardWidget(
                                          title: 'todays_orders'.tr,
                                          value: profileController.profileModel?.todaysOrderCount.toString(),
                                        ),
                                        const SizedBox(width: Dimensions.paddingSizeDefault),

                                        OrderCountCardWidget(
                                          title: 'this_week_orders'.tr,
                                          value: profileController.profileModel?.thisWeekOrderCount.toString(),
                                        ),
                                        const SizedBox(width: Dimensions.paddingSizeDefault),

                                        OrderCountCardWidget(
                                          title: 'total_orders'.tr,
                                          value: profileController.profileModel?.orderCount.toString(),
                                        ),

                                      ]) : Column(children: [

                                        Row(children: [

                                          Expanded(child: CountCardWidget(
                                            title: 'todays_orders'.tr, backgroundColor: const Color(0xffE5EAFF), height: 180,
                                            value: profileController.profileModel?.todaysOrderCount.toString(),
                                          )),
                                          const SizedBox(width: Dimensions.paddingSizeSmall),

                                          Expanded(child: CountCardWidget(
                                            title: 'this_week_orders'.tr, backgroundColor: const Color(0xffE84E50).withValues(alpha: 0.2), height: 180,
                                            value: profileController.profileModel?.thisWeekOrderCount.toString(),
                                          )),

                                        ]),
                                        const SizedBox(height: Dimensions.paddingSizeSmall),

                                        CountCardWidget(
                                          title: 'total_orders'.tr, backgroundColor: const Color(0xffE1FFD8), height: 140,
                                          value: profileController.profileModel?.orderCount.toString(),
                                        ),

                                      ]),
                                      const SizedBox(height: Dimensions.paddingSizeLarge),

                                      profileController.profileModel != null ? profileController.profileModel!.cashInHands! > 0 ? Container(
                                        width: MediaQuery.of(context).size.width,
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).cardColor,
                                          borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
                                          border: Border.all(color: Theme.of(context).disabledColor, width: 0.2),
                                          boxShadow: [BoxShadow(color: Get.isDarkMode ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05), blurRadius: 20, spreadRadius: 0, offset: const Offset(0, 5))],

                                        ),
                                        padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeDefault, vertical: Dimensions.paddingSizeLarge),
                                        child: Column(children: [

                                          Container(
                                            decoration: BoxDecoration(
                                              color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(50),
                                            ),
                                            padding: const EdgeInsets.all(10),
                                            child: Image.asset(Images.payMoney, height: 40,),
                                          ),
                                          const SizedBox(height: Dimensions.paddingSizeSmall),

                                          Text(
                                            PriceConverterHelper.convertPrice(profileController.profileModel!.cashInHands),
                                            style: robotoBold.copyWith(fontSize: Dimensions.fontSizeOverLarge),
                                          ),
                                          const SizedBox(height: Dimensions.paddingSizeSmall),

                                          RichText(
                                            text: TextSpan(
                                              children: [
                                                TextSpan(text: 'cash_in_your_hand'.tr, style: robotoRegular.copyWith(color: Theme.of(context).textTheme.bodyLarge!.color!.withValues(alpha: 0.8))),

                                                if((profileController.profileModel!.dmMaxMyAccount != null) && (profileController.profileModel!.dmMaxMyAccount! > 0) && (profileController.profileModel!.cashInHands! > profileController.profileModel!.dmMaxMyAccount!))
                                                  TextSpan(text: ' (${'limit_exceeded'.tr})', style: robotoRegular.copyWith(color: ColorResources.red, fontSize: Dimensions.fontSizeSmall - 2)),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(height: Dimensions.paddingSizeLarge),

                                          CustomButtonWidget(
                                            width: 90, height: 40,
                                            isBold: false,
                                            fontSize: Dimensions.fontSizeDefault,
                                            buttonText: 'pay_now'.tr,
                                            backgroundColor: Theme.of(context).primaryColor,
                                            onPressed: () => Get.toNamed(RouteHelper.getMyAccountRoute()),
                                          ),

                                        ]),
                                      ) : const SizedBox() : Shimmer(
                                        duration: const Duration(seconds: 2),
                                        enabled: true,
                                        child: Container(
                                          height: 85, width: MediaQuery.of(context).size.width,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
                                            color: Theme.of(context).shadowColor,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: Dimensions.paddingSizeLarge),

                                      if(showReferAndEarn)
                                        InkWell(
                                        onTap: () {
                                          Get.to(()=> const ReferAndEarnScreen());
                                        },
                                        child: Container(
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
                                            color: Theme.of(context).disabledColor.withValues(alpha: 0.125),
                                          ),
                                          padding: const EdgeInsets.symmetric(vertical: Dimensions.paddingSizeSmall, horizontal: Dimensions.paddingSizeLarge),
                                          child: Row(mainAxisAlignment: MainAxisAlignment.start, children: [
                                            Expanded(
                                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                                Text('invite_and_get_rewards'.tr, style: robotoBold.copyWith(fontSize: Dimensions.fontSizeLarge)),
                                                const SizedBox(height: Dimensions.paddingSizeSmall),

                                                Text('share_code_with_your_friends'.tr, style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: Theme.of(context).textTheme.bodyLarge!.color!.withValues(alpha: 0.7))),
                                                const SizedBox(height: Dimensions.paddingSizeExtraSmall),

                                                Row(
                                                  children: [
                                                    CustomButtonWidget(
                                                      height: 30, width: 130,
                                                      buttonText: 'invite_friends'.tr,
                                                      fontSize: Dimensions.fontSizeSmall,
                                                      onPressed: (){
                                                        Get.bottomSheet(const ReferBottomSheet(), isScrollControlled: true);
                                                      },
                                                    ),
                                                  ],
                                                ),

                                              ]),
                                            ),
                                            const SizedBox(width: Dimensions.paddingSizeSmall),

                                            Image.asset(Images.shareImage, width: 100,)
                                          ]),
                                        ),
                                      ),

                                    ]),
                                  ),



                                ]);
                              }),

                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          // BOTÃO FIXO INFERIOR
          _buildSearchingButton(context),

        ],
      ),
    );
  }

  Widget permissionWarning({required bool isBatteryPermission, required Function() onTap, required Function() closeOnTap}) {
    return GetPlatform.isAndroid ? Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).textTheme.bodyLarge!.color?.withValues(alpha: 0.7),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(Dimensions.paddingSizeSmall),
          child: Row(children: [

            if(isBatteryPermission)
              Padding(
                padding: EdgeInsets.only(right: 8.0),
                child: Image.asset(Images.allertIcon, height: 20, width: 20),
              ),

            Expanded(
              child: Row(children: [
                Flexible(
                  child: Text(
                    isBatteryPermission ? 'for_better_performance_allow_notification_to_run_in_background'.tr
                        : 'notification_is_disabled_please_allow_notification'.tr,
                    maxLines: 2, style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: Colors.white),
                  ),
                ),
                const SizedBox(width: Dimensions.paddingSizeSmall),
                const Icon(Icons.arrow_circle_right_rounded, color: Colors.white, size: 24,),
              ]),
            ),

            // const SizedBox(width: 20),
          ]),
        ),
      ),
    ) : const SizedBox();
  }
}
