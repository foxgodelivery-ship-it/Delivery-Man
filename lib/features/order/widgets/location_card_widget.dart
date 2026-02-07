import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:sixam_mart_delivery/features/order/controllers/order_controller.dart';
import 'package:sixam_mart_delivery/features/address/controllers/address_controller.dart';
import 'package:sixam_mart_delivery/features/order/domain/models/order_model.dart';
import 'package:sixam_mart_delivery/helper/date_converter_helper.dart';
import 'package:sixam_mart_delivery/helper/price_converter_helper.dart';
import 'package:sixam_mart_delivery/helper/route_helper.dart';
import 'package:sixam_mart_delivery/util/dimensions.dart';
import 'package:sixam_mart_delivery/util/images.dart';
import 'package:sixam_mart_delivery/util/styles.dart';
import 'package:sixam_mart_delivery/common/widgets/confirmation_dialog_widget.dart';
import 'package:sixam_mart_delivery/common/widgets/custom_button_widget.dart';
import 'package:sixam_mart_delivery/features/order/screens/order_details_screen.dart';

class LocationCardWidget extends StatelessWidget {
  final OrderModel orderModel;
  final OrderController orderController;
  final int index;
  final Function onTap;
  final bool fromNotification;
  const LocationCardWidget({
    super.key,
    required this.orderModel,
    required this.orderController,
    required this.index,
    required this.onTap,
    this.fromNotification = false,
  });

  @override
  Widget build(BuildContext context) {
    bool parcel = orderModel.orderType == 'parcel';
    double restaurantDistance = Get.find<AddressController>().getRestaurantDistance(
      LatLng(double.parse(parcel ? orderModel.deliveryAddress?.latitude ?? '0' : orderModel.storeLat ?? '0'), double.parse(parcel ? orderModel.deliveryAddress?.longitude ?? '0' : orderModel.storeLng ?? '0')),
      customerLatLng: currentLatLng,
    );
    double restaurantToCustomerDistance = Get.find<AddressController>().getRestaurantDistance(
      LatLng(double.parse(parcel ? orderModel.deliveryAddress?.latitude ?? '0' : orderModel.storeLat ?? '0'), double.parse(parcel ? orderModel.deliveryAddress?.longitude ?? '0' : orderModel.storeLng ?? '0')),
      customerLatLng: LatLng(double.parse(parcel ? orderModel.receiverDetails?.latitude ?? '0' : orderModel.deliveryAddress?.latitude ?? '0'), double.parse(parcel ? orderModel.receiverDetails?.longitude ?? '0' : orderModel.deliveryAddress?.longitude ?? '0')),
    );

    final double totalDistance = restaurantDistance + restaurantToCustomerDistance;
    final double baseEarning = orderModel.originalDeliveryCharge ?? orderModel.deliveryCharge ?? 0;
    final double tips = orderModel.dmTips ?? 0;
    final String sourceAddress = parcel ? (orderModel.deliveryAddress?.address ?? '') : (orderModel.storeAddress ?? '');
    final String destinationAddress = parcel ? (orderModel.receiverDetails?.address ?? '') : (orderModel.deliveryAddress?.address ?? '');
    final String deliveryTime = _deliveryTimeLabel(orderModel.scheduleAt);

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 18)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withValues(alpha: 0.18),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  child: Text(
                    parcel ? 'Entrega Parcel' : 'Entrega Food',
                    style: robotoBold,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                child: Row(children: [
                  Expanded(
                    child: Text(
                      PriceConverterHelper.convertPrice(baseEarning + tips),
                      style: robotoBold.copyWith(fontSize: 44, height: 1),
                    ),
                  ),
                  if (tips > 0)
                    Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: Text('+${PriceConverterHelper.convertPrice(tips)}', style: robotoBold.copyWith(fontSize: 20)),
                    ),
                  if (deliveryTime.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(left: 8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Text('Entregar\naté $deliveryTime', style: robotoRegular.copyWith(fontSize: 14)),
                    ),
                ]),
              ),
              Container(height: 4, color: Theme.of(context).primaryColor),
            ]),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(children: [
              const Icon(Icons.route_rounded, size: 24),
              const SizedBox(width: 8),
              Text('Distância total ', style: robotoRegular.copyWith(fontSize: 22)),
              Text('${totalDistance.toStringAsFixed(1)} km', style: robotoBold.copyWith(fontSize: 22)),
            ]),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(children: [
              _AddressLine(color: Colors.amber.shade700, text: sourceAddress),
              const SizedBox(height: 6),
              _AddressLine(color: Colors.deepOrangeAccent, text: destinationAddress),
            ]),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: CustomButtonWidget(
              height: 62,
              radius: 20,
              color: Theme.of(context).primaryColor,
              buttonText: 'accept'.tr,
              onPressed: () => Get.dialog(ConfirmationDialogWidget(
                icon: Images.warning,
                title: 'are_you_sure_to_accept'.tr,
                description: parcel ? 'you_want_to_accept_this_delivery'.tr : 'you_want_to_accept_this_order'.tr,
                onYesPressed: () {
                  orderController.acceptOrder(orderModel.id, index, orderModel).then((isSuccess) {
                    if (isSuccess) {
                      onTap();
                      orderModel.orderStatus = (orderModel.orderStatus == 'pending' || orderModel.orderStatus == 'confirmed') ? 'accepted' : orderModel.orderStatus;
                      Get.toNamed(
                        RouteHelper.getOrderDetailsRoute(orderModel.id),
                        arguments: OrderDetailsScreen(
                          orderId: orderModel.id,
                          isRunningOrder: true,
                          orderIndex: orderController.currentOrderList!.length - 1,
                          fromLocationScreen: true,
                        ),
                      );
                    } else {
                      Get.find<OrderController>().getLatestOrders();
                    }
                  });
                },
              ), barrierDismissible: false),
            ),
          ),

          if (!fromNotification)
            Align(
              alignment: Alignment.center,
              child: TextButton(
                onPressed: () => Get.dialog(ConfirmationDialogWidget(
                  icon: Images.warning,
                  title: 'are_you_sure_to_ignore'.tr,
                  description: parcel ? 'you_want_to_ignore_this_delivery'.tr : 'you_want_to_ignore_this_order'.tr,
                  onYesPressed: () {
                    orderController.ignoreOrder(index);
                    Get.back();
                    Get.back();
                  },
                ), barrierDismissible: false),
                child: Text('ignore'.tr, style: robotoRegular.copyWith(color: Theme.of(context).disabledColor)),
              ),
            ),
        ],
      ),
    );
  }

  String _deliveryTimeLabel(String? scheduleAt) {
    if (scheduleAt == null || scheduleAt.isEmpty) {
      return '';
    }
    try {
      return DateConverterHelper.dateTimeStringToDateTime(scheduleAt).split(' ').last;
    } catch (_) {
      return '';
    }
  }
}

class _AddressLine extends StatelessWidget {
  final Color color;
  final String text;
  const _AddressLine({required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Column(children: [
        Container(height: 14, width: 14, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(height: 2),
        Container(height: 16, width: 2, color: Colors.black12),
      ]),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          text,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: robotoRegular.copyWith(fontSize: 20),
        ),
      ),
    ]);
  }
}
