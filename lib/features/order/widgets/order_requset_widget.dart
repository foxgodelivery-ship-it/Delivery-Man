import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sixam_mart_delivery/common/widgets/confirmation_dialog_widget.dart';
import 'package:sixam_mart_delivery/common/widgets/custom_button_widget.dart';
import 'package:sixam_mart_delivery/features/order/controllers/order_controller.dart';
import 'package:sixam_mart_delivery/features/order/domain/models/order_model.dart';
import 'package:sixam_mart_delivery/features/order/screens/order_details_screen.dart';
import 'package:sixam_mart_delivery/helper/price_converter_helper.dart';
import 'package:sixam_mart_delivery/helper/route_helper.dart';
import 'package:sixam_mart_delivery/util/dimensions.dart';
import 'package:sixam_mart_delivery/util/images.dart';
import 'package:sixam_mart_delivery/util/styles.dart';

class OrderRequestWidget extends StatelessWidget {
  final OrderModel orderModel;
  final int index;
  final bool fromDetailsPage;
  final Function onTap;

  const OrderRequestWidget({
    super.key,
    required this.orderModel,
    required this.index,
    required this.onTap,
    this.fromDetailsPage = false,
  });

  @override
  Widget build(BuildContext context) {
    final bool parcel = orderModel.orderType == 'parcel';

    final String pickupText = parcel
        ? (orderModel.parcelCategory?.name ?? orderModel.storeName ?? 'no_store_data_found'.tr)
        : '${orderModel.storeName ?? 'no_store_data_found'.tr} - ${orderModel.storeAddress ?? ''}';

    final String dropText = parcel
        ? (orderModel.receiverDetails?.address ?? orderModel.deliveryAddress?.address ?? '')
        : '${orderModel.deliveryAddress?.contactPersonName ?? ''} - ${orderModel.deliveryAddress?.address ?? ''}';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: Dimensions.paddingSizeSmall),
      padding: const EdgeInsets.all(Dimensions.paddingSizeLarge),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: GetBuilder<OrderController>(builder: (orderController) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Pedido #${orderModel.id ?? ''}',
                  style: robotoRegular.copyWith(
                    color: Theme.of(context).disabledColor,
                    fontSize: Dimensions.fontSizeLarge,
                  ),
                ),
                Text(
                  PriceConverterHelper.convertPrice(orderModel.deliveryCharge),
                  style: robotoBold.copyWith(
                    color: const Color(0xFFE2B106),
                    fontSize: Dimensions.fontSizeOverLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: Dimensions.paddingSizeLarge),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    _RouteMarker(icon: Icons.storefront),
                    const SizedBox(height: 4),
                    const _DottedRouteLine(),
                    const SizedBox(height: 4),
                    _RouteMarker(icon: Icons.person),
                  ],
                ),
                const SizedBox(width: Dimensions.paddingSizeDefault),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          pickupText,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: robotoMedium.copyWith(fontSize: Dimensions.fontSizeLarge),
                        ),
                      ),
                      const SizedBox(height: 28),
                      Text(
                        dropText,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: robotoMedium.copyWith(fontSize: Dimensions.fontSizeLarge),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: Dimensions.paddingSizeLarge),

            SizedBox(
              width: double.infinity,
              child: CustomButtonWidget(
                height: 48,
                radius: 24,
                backgroundColor: Theme.of(context).primaryColor,
                fontColor: Colors.white,
                buttonText: 'Aceitar Corrida',
                fontSize: Dimensions.fontSizeLarge,
                onPressed: () => Get.dialog(
                  ConfirmationDialogWidget(
                    icon: Images.warning,
                    title: 'are_you_sure_to_accept'.tr,
                    description: parcel ? 'you_want_to_accept_this_delivery'.tr : 'you_want_to_accept_this_order'.tr,
                    onYesPressed: () {
                      orderController.acceptOrder(orderModel.id, index, orderModel).then((isSuccess) {
                        if (isSuccess) {
                          onTap();
                          orderModel.orderStatus = (orderModel.orderStatus == 'pending' || orderModel.orderStatus == 'confirmed')
                              ? 'accepted'
                              : orderModel.orderStatus;
                          Get.toNamed(
                            RouteHelper.getOrderDetailsRoute(orderModel.id),
                            arguments: OrderDetailsScreen(
                              orderId: orderModel.id,
                              isRunningOrder: true,
                              orderIndex: orderController.currentOrderList!.length - 1,
                            ),
                          );
                        } else {
                          Get.find<OrderController>().getLatestOrders();
                        }
                      });
                    },
                  ),
                  barrierDismissible: false,
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}

class _RouteMarker extends StatelessWidget {
  final IconData icon;

  const _RouteMarker({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      width: 34,
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 20, color: Colors.white),
    );
  }
}

class _DottedRouteLine extends StatelessWidget {
  const _DottedRouteLine();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      width: 4,
      child: LayoutBuilder(
        builder: (context, constraints) {
          const double dotSize = 3;
          const double spacing = 3;
          final int dotCount = (constraints.maxHeight / (dotSize + spacing)).floor();

          return Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(
              dotCount,
              (_) => Container(
                width: dotSize,
                height: dotSize,
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
