import 'dart:async';
import 'dart:io';
import 'package:sixam_mart_delivery/features/auth/controllers/auth_controller.dart';
import 'package:sixam_mart_delivery/features/order/controllers/order_controller.dart';
import 'package:sixam_mart_delivery/features/order/domain/models/order_model.dart';
import 'package:sixam_mart_delivery/features/disbursement/helper/disbursement_helper.dart';
import 'package:sixam_mart_delivery/features/profile/controllers/profile_controller.dart';
import 'package:sixam_mart_delivery/helper/notification_helper.dart';
import 'package:sixam_mart_delivery/helper/route_helper.dart';
import 'package:sixam_mart_delivery/main.dart';
import 'package:sixam_mart_delivery/util/dimensions.dart';
import 'package:sixam_mart_delivery/util/app_constants.dart';
import 'package:sixam_mart_delivery/common/widgets/custom_alert_dialog_widget.dart';
import 'package:sixam_mart_delivery/common/widgets/custom_snackbar_widget.dart';
import 'package:sixam_mart_delivery/features/dashboard/widgets/bottom_nav_item_widget.dart';
import 'package:sixam_mart_delivery/features/dashboard/widgets/new_request_dialog_widget.dart';
import 'package:sixam_mart_delivery/features/home/screens/home_screen.dart';
import 'package:sixam_mart_delivery/features/profile/screens/profile_screen.dart';
import 'package:sixam_mart_delivery/features/order/screens/order_request_screen.dart';
import 'package:sixam_mart_delivery/features/order/screens/order_screen.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:sixam_mart_delivery/util/images.dart';

class DashboardScreen extends StatefulWidget {
  final int pageIndex;
  final bool fromOrderDetails;
  const DashboardScreen({super.key, required this.pageIndex, this.fromOrderDetails = false});

  @override
  DashboardScreenState createState() => DashboardScreenState();
}

class DashboardScreenState extends State<DashboardScreen> {
  PageController? _pageController;
  int _pageIndex = 0;
  late List<Widget> _screens;
  final _channel = const MethodChannel('com.sixamtech/app_retain');
  late StreamSubscription _stream;
  DisbursementHelper disbursementHelper = DisbursementHelper();
  bool _canExit = false;

  @override
  void initState() {
    super.initState();

    _pageIndex = widget.pageIndex;
    _pageController = PageController(initialPage: widget.pageIndex);

    _screens = [
      const HomeScreen(),
      OrderRequestScreen(onTap: () => _setPage(0)),
      const OrderScreen(),
      const ProfileScreen(),
    ];

    showDisbursementWarningMessage();
    Get.find<OrderController>().getLatestOrders();
    
    _stream = FirebaseMessaging.onMessage.listen((RemoteMessage message) {

      String? type = message.data['body_loc_key'] ?? message.data['type'];
      String? orderID = message.data['title_loc_key'] ?? message.data['order_id'];
      bool isParcel = (message.data['order_type'] == 'parcel_order');
      if(type != 'assign' && type != 'new_order' && type != 'message' && type != 'order_request' && type != 'order_status') {
        NotificationHelper.showNotification(message, flutterLocalNotificationsPlugin);
      }
      if(type == 'new_order' || type == 'order_request') {
        Get.find<OrderController>().getCurrentOrders();
        Get.find<OrderController>().getLatestOrders();
        Get.dialog(NewRequestDialogWidget(isRequest: true, onTap: () => _navigateRequestPage(), orderId: int.parse(message.data['order_id'].toString()), isParcel: isParcel));
      }else if(type == 'assign' && orderID != null && orderID.isNotEmpty) {
        Get.find<OrderController>().getCurrentOrders();
        Get.find<OrderController>().getLatestOrders();
        Get.dialog(NewRequestDialogWidget(isRequest: false, orderId: int.parse(message.data['order_id'].toString()), isParcel: isParcel, onTap: () {
          Get.offAllNamed(RouteHelper.getOrderDetailsRoute(int.parse(orderID), fromNotification: true));
        }));
      }else if(type == 'block') {
        Get.find<AuthController>().clearSharedData();
        Get.find<ProfileController>().stopLocationRecord();
        Get.offAllNamed(RouteHelper.getSignInRoute());
      }
    });

  }

  Future<void> showDisbursementWarningMessage() async{
    if(!widget.fromOrderDetails){
      disbursementHelper.enableDisbursementWarningMessage(true);
    }
  }

  Future<void> _navigateRequestPage() async {
    final bool hasPendingReturn = await _hasPendingParcelReturn();
    if (hasPendingReturn) {
      showCustomSnackBar('Você possui devolução pendente. Finalize a devolução antes de receber novos pedidos.');
      return;
    }
    if(Get.find<ProfileController>().profileModel != null && Get.find<ProfileController>().profileModel!.active == 1
        && Get.find<OrderController>().currentOrderList != null && Get.find<OrderController>().currentOrderList!.isEmpty) {
      _setPage(1);
    }else {
      if(Get.find<ProfileController>().profileModel == null || Get.find<ProfileController>().profileModel!.active == 0) {
        Get.dialog(CustomAlertDialogWidget(description: 'you_are_offline_now'.tr, onOkPressed: () => Get.back()));
      }else {
        _setPage(1);
      }
    }
  }

  @override
  void dispose() {
    super.dispose();

    _stream.cancel();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async{
        if(_pageIndex != 0) {
          _setPage(0);
        }else {
          if(_canExit) {
            if (GetPlatform.isAndroid) {
              if (Get.find<ProfileController>().profileModel!.active == 1) {
                _channel.invokeMethod('sendToBackground');
              }
              SystemNavigator.pop();
            } else if (GetPlatform.isIOS) {
              exit(0);
            }
          }
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('back_press_again_to_exit'.tr, style: const TextStyle(color: Colors.white)),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
            margin: const EdgeInsets.all(Dimensions.paddingSizeSmall),
          ));
          _canExit = true;

          Timer(const Duration(seconds: 2), () {
            _canExit = false;
          });
        }
      },
      child: Scaffold(
        bottomNavigationBar: GetPlatform.isDesktop ? const SizedBox() : Container(
          height: 70 + MediaQuery.of(context).padding.bottom,
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            boxShadow: [BoxShadow(color: Colors.grey[Get.isDarkMode ? 800 : 200]!, spreadRadius: 1, blurRadius: 5)],
          ),
          padding: EdgeInsets.only(top: 14),
          child: Row(children: [
            BottomNavItemWidget(iconData: Images.home, label: 'Início', isSelected: _pageIndex == 0, onTap: () => _setPage(0)),
            Expanded(
              child: Center(
                child: GetBuilder<ProfileController>(builder: (profileController) {
                  final bool isOnline = profileController.profileModel?.active == 1;
                  return InkWell(
                    onTap: isOnline ? null : _handleConnectTap,
                    borderRadius: BorderRadius.circular(50),
                    child: Container(
                      height: 54,
                      width: 120,
                      decoration: BoxDecoration(
                        color: isOnline ? Theme.of(context).primaryColor : Theme.of(context).colorScheme.error,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        isOnline ? 'Online' : 'Conectar',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                    ),
                  );
                }),
              ),
            ),
            BottomNavItemWidget(iconData: Images.userP, label: 'Conta', isSelected: _pageIndex == 3, onTap: () => _setPage(3)),
          ]),
        ),
        body: PageView.builder(
          controller: _pageController,
          itemCount: _screens.length,
          physics: const NeverScrollableScrollPhysics(),
          itemBuilder: (context, index) {
            return _screens[index];
          },
        ),
      ),
    );
  }

  void _setPage(int pageIndex) {
    setState(() {
      _pageController!.jumpToPage(pageIndex);
      _pageIndex = pageIndex;
    });
  }

  Future<void> _handleConnectTap() async {
    final ProfileController profileController = Get.find<ProfileController>();

    if (profileController.profileModel?.active == 1) {
      return;
    }

    final bool hasPendingReturn = await _hasPendingParcelReturn();
    if (hasPendingReturn) {
      showCustomSnackBar('Você possui devolução pendente. Finalize a devolução antes de ficar Online.');
      return;
    }

    final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      showCustomSnackBar('Ative o GPS para ficar Online.');
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      showCustomSnackBar('Permita o acesso à localização para ficar Online.');
      return;
    }

    if (permission == LocationPermission.deniedForever) {
      showCustomSnackBar('Abra as configurações do Android e permita a localização.');
      return;
    }

    final Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    if (position.isMocked) {
      showCustomSnackBar('Localização inválida detectada. Desative apps de localização falsa para continuar.');
      return;
    }

    await profileController.updateActiveStatus();
  }

  Future<bool> _hasPendingParcelReturn() async {
    final OrderController orderController = Get.find<OrderController>();
    await orderController.getCompletedOrders(1, willUpdate: false);
    final List<OrderModel>? orders = orderController.completedOrderList;
    if (orders == null) {
      return false;
    }
    return orders.any((order) {
      return order.orderType == 'parcel'
          && order.orderStatus == AppConstants.canceled
          && order.parcelCancellation != null
          && order.parcelCancellation?.beforePickup != 1;
    });
  }
}
