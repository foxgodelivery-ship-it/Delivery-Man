import 'dart:async';
import 'dart:io';
import 'package:sixam_mart_delivery/features/auth/controllers/auth_controller.dart';
import 'package:sixam_mart_delivery/features/order/controllers/order_controller.dart';
import 'package:sixam_mart_delivery/features/disbursement/helper/disbursement_helper.dart';
import 'package:sixam_mart_delivery/features/profile/controllers/profile_controller.dart';
import 'package:sixam_mart_delivery/helper/notification_helper.dart';
import 'package:sixam_mart_delivery/helper/route_helper.dart';
import 'package:sixam_mart_delivery/main.dart';
import 'package:sixam_mart_delivery/util/dimensions.dart';
import 'package:sixam_mart_delivery/common/widgets/custom_alert_dialog_widget.dart';
import 'package:sixam_mart_delivery/features/dashboard/widgets/bottom_nav_item_widget.dart';
import 'package:sixam_mart_delivery/features/dashboard/widgets/new_request_dialog_widget.dart';
import 'package:sixam_mart_delivery/features/order/domain/models/order_model.dart';
import 'package:sixam_mart_delivery/features/order/screens/order_location_screen.dart';
import 'package:sixam_mart_delivery/features/home/screens/home_screen.dart';
import 'package:sixam_mart_delivery/features/profile/screens/profile_screen.dart';
import 'package:sixam_mart_delivery/features/order/screens/order_request_screen.dart';
import 'package:sixam_mart_delivery/features/order/screens/order_screen.dart';
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
    
    _stream = FirebaseMessaging.onMessage.listen((RemoteMessage message) async {

      String? type = message.data['body_loc_key'] ?? message.data['type'];
      String? orderID = message.data['title_loc_key'] ?? message.data['order_id'];
      bool isParcel = (message.data['order_type'] == 'parcel_order');
      if(type != 'assign' && type != 'new_order' && type != 'message' && type != 'order_request' && type != 'order_status') {
        NotificationHelper.showNotification(message, flutterLocalNotificationsPlugin);
      }

      if(type == 'new_order' || type == 'order_request' || type == 'assign') {
        await Get.find<OrderController>().getCurrentOrders();
        await Get.find<OrderController>().getLatestOrders();

        int? incomingOrderId = int.tryParse((message.data['order_id'] ?? orderID ?? '').toString());
        OrderModel? incomingOrder = _findIncomingOrderById(incomingOrderId);

        if(incomingOrder != null) {
          Get.to(() => OrderLocationScreen(
            orderModel: incomingOrder,
            orderController: Get.find<OrderController>(),
            index: _findLatestOrderIndex(incomingOrder.id),
            onTap: _navigateRequestPage,
            fromNotification: true,
          ));
        } else {
          Get.dialog(NewRequestDialogWidget(
            isRequest: type == 'new_order' || type == 'order_request',
            orderId: incomingOrderId ?? 0,
            isParcel: isParcel,
            onTap: () {
              if(type == 'assign' && orderID != null && orderID.isNotEmpty) {
                Get.offAllNamed(RouteHelper.getOrderDetailsRoute(int.parse(orderID), fromNotification: true));
              } else {
                _navigateRequestPage();
              }
            },
          ));
        }
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

  void _navigateRequestPage() {
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
            BottomNavItemWidget(iconData: Images.home, label: 'home'.tr, isSelected: _pageIndex == 0, onTap: () => _setPage(0)),
            BottomNavItemWidget(iconData: Images.request, label: 'request'.tr, isSelected: _pageIndex == 1, pageIndex: 1, onTap: () {
              _navigateRequestPage();
            }),
            BottomNavItemWidget(iconData: Images.bag, label: 'orders'.tr, isSelected: _pageIndex == 2, onTap: () => _setPage(2)),
            BottomNavItemWidget(iconData: Images.userP, label: 'profile'.tr, isSelected: _pageIndex == 3, onTap: () => _setPage(3)),
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


  OrderModel? _findIncomingOrderById(int? orderId) {
    if(orderId == null) {
      return null;
    }

    final OrderController orderController = Get.find<OrderController>();
    final latest = orderController.latestOrderList;
    if(latest != null) {
      for(final order in latest) {
        if(order.id == orderId) {
          return order;
        }
      }
    }

    final current = orderController.currentOrderList;
    if(current != null) {
      for(final order in current) {
        if(order.id == orderId) {
          return order;
        }
      }
    }
    return null;
  }

  int _findLatestOrderIndex(int? orderId) {
    final latest = Get.find<OrderController>().latestOrderList;
    if(latest == null || orderId == null) {
      return 0;
    }
    final index = latest.indexWhere((order) => order.id == orderId);
    return index < 0 ? 0 : index;
  }

  void _setPage(int pageIndex) {
    setState(() {
      _pageController!.jumpToPage(pageIndex);
      _pageIndex = pageIndex;
    });
  }
}
