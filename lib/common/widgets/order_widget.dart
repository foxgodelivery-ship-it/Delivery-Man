import 'package:sixam_mart_delivery/common/widgets/custom_card.dart';
import 'package:sixam_mart_delivery/features/order/domain/models/order_model.dart';
import 'package:sixam_mart_delivery/helper/route_helper.dart';
import 'package:sixam_mart_delivery/util/color_resources.dart';
import 'package:sixam_mart_delivery/util/dimensions.dart';
import 'package:sixam_mart_delivery/util/images.dart';
import 'package:sixam_mart_delivery/util/styles.dart';
import 'package:sixam_mart_delivery/common/widgets/custom_snackbar_widget.dart';
import 'package:sixam_mart_delivery/features/order/screens/order_details_screen.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher_string.dart';

class OrderWidget extends StatelessWidget {
  final OrderModel orderModel;
  final bool isRunningOrder;
  final int orderIndex;
  final double cardWidth;
  const OrderWidget({super.key, required this.orderModel, required this.isRunningOrder, required this.orderIndex, required this.cardWidth});

  bool _isValidValue(String? value) => value != null && value.trim().isNotEmpty;

  String _formatAddress(DeliveryAddress? address) {
    if(address == null) {
      return '';
    }
    final List<String> parts = [];
    if(_isValidValue(address.address)) {
      parts.add(address.address!.trim());
    }
    if(_isValidValue(address.streetNumber)) {
      parts.add(address.streetNumber!.trim());
    }
    if(_isValidValue(address.house)) {
      parts.add(address.house!.trim());
    }
    if(_isValidValue(address.floor)) {
      parts.add(address.floor!.trim());
    }
    return parts.join(', ');
  }

  Future<void> _openNavigation({
    required String? latitude,
    required String? longitude,
    required String? fallbackAddress,
  }) async {
    final bool hasCoordinates = _isValidValue(latitude) && _isValidValue(longitude) && latitude != '0' && longitude != '0';
    final String destination = hasCoordinates
        ? '${latitude!},${longitude!}'
        : Uri.encodeComponent(fallbackAddress ?? '');
    if(destination.isEmpty) {
      showCustomSnackBar('address_not_found'.tr);
      return;
    }
    final String url = 'https://www.google.com/maps/dir/?api=1&destination=$destination&mode=d';
    if (await canLaunchUrlString(url)) {
      await launchUrlString(url, mode: LaunchMode.externalApplication);
    } else {
      showCustomSnackBar('${'could_not_launch'.tr} $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    bool parcel = orderModel.orderType == 'parcel';
    final String pickupAddress = parcel
        ? _formatAddress(orderModel.deliveryAddress)
        : (orderModel.storeAddress ?? '');
    final String deliveryAddress = parcel
        ? _formatAddress(orderModel.receiverDetails)
        : _formatAddress(orderModel.deliveryAddress);
    final String pickupAddressText = pickupAddress.isNotEmpty ? pickupAddress : 'address_not_found'.tr;
    final String deliveryAddressText = deliveryAddress.isNotEmpty ? deliveryAddress : 'address_not_found'.tr;

    return InkWell(
      onTap: () {
        Get.toNamed(
          RouteHelper.getOrderDetailsRoute(orderModel.id),
          arguments: OrderDetailsScreen(orderId: orderModel.id, isRunningOrder: isRunningOrder, orderIndex: orderIndex),
        );
      },
      child: CustomCard(
        isBorder: true,
        child: Column(children: [

          Container(
            padding: const EdgeInsets.all(Dimensions.paddingSizeSmall),
            child: Row(children: [

              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(parcel ? 'parcel'.tr : 'order'.tr, style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: Theme.of(context).hintColor)),

                Row(children: [
                  Text('# ${orderModel.id} ', style: robotoBold.copyWith(fontSize: Dimensions.fontSizeDefault)),

                  parcel ? const SizedBox() : Text('(${orderModel.detailsCount} ${'item'.tr})', style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall)),
                ]),
              ]),

              const Expanded(child: SizedBox()),

              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [

                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeSmall, vertical: 2),
                  decoration: BoxDecoration(
                    color: orderModel.paymentStatus == 'paid' ? ColorResources.green.withValues(alpha: 0.1) : ColorResources.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
                  ),
                  child: Text(
                    orderModel.paymentStatus == 'paid' ? 'paid'.tr : 'unpaid'.tr,
                    style: robotoBold.copyWith(fontSize: Dimensions.fontSizeSmall, color: orderModel.paymentStatus == 'paid' ? ColorResources.green : ColorResources.red),
                  ),
                ),
                const SizedBox(height: 2),

                Text(
                  orderModel.paymentMethod == 'cash_on_delivery' ? 'cod'.tr : orderModel.paymentMethod == 'partial_payment' ? 'partially_pay'.tr : 'digitally_paid'.tr,
                  style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: Theme.of(context).hintColor),
                ),

              ]),
            ]),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeSmall, vertical: 0),
            child: Column(children: [
              Row(crossAxisAlignment: CrossAxisAlignment.center, mainAxisAlignment: MainAxisAlignment.start, children: [
                parcel
                    ? Image.asset((parcel || orderModel.orderStatus == 'picked_up') ? Images.personIcon : Images.house, width: 20, height: 20)
                    : Icon(Icons.store, size: 18, color: Theme.of(context).hintColor),
                const SizedBox(width: Dimensions.paddingSizeExtraSmall),

                Expanded(
                  child: Text(
                    parcel ? 'customer_location'.tr : orderModel.storeName?? 'store_not_found'.tr,
                    style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeSmall),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                  ),
                ),

                const SizedBox(),

              ]),
              const SizedBox(height: Dimensions.paddingSizeSmall),

              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('RETIRADA', style: robotoMedium.copyWith(fontSize: Dimensions.fontSizeSmall)),
                const SizedBox(height: Dimensions.paddingSizeExtraSmall),
                Text(
                  pickupAddressText,
                  style: robotoRegular.copyWith(color: Theme.of(context).hintColor, fontSize: Dimensions.fontSizeSmall),
                  maxLines: 2, overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: Dimensions.paddingSizeSmall),
                Text('ENTREGA', style: robotoMedium.copyWith(fontSize: Dimensions.fontSizeSmall)),
                const SizedBox(height: Dimensions.paddingSizeExtraSmall),
                Text(
                  deliveryAddressText,
                  style: robotoRegular.copyWith(color: Theme.of(context).hintColor, fontSize: Dimensions.fontSizeSmall),
                  maxLines: 2, overflow: TextOverflow.ellipsis,
                ),
              ]),
              const SizedBox(height: Dimensions.paddingSizeSmall),

            ]),
          ),
          // Spacer(),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeSmall),
            decoration: BoxDecoration(
              color: Theme.of(context).disabledColor.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(Dimensions.radiusDefault), bottomRight: Radius.circular(Dimensions.radiusDefault),
              ),
            ),
            child: Column(children: [
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                TextButton(
                  onPressed: () {
                    Get.toNamed(
                      RouteHelper.getOrderDetailsRoute(orderModel.id),
                      arguments: OrderDetailsScreen(orderId: orderModel.id, isRunningOrder: isRunningOrder, orderIndex: orderIndex),
                    );
                  },
                  style: TextButton.styleFrom(
                    backgroundColor: Theme.of(context).cardColor,
                    minimumSize: const Size(100, 35),
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
                      side: BorderSide(color: Theme.of(context).disabledColor.withValues(alpha: 0.3)),
                    ),
                  ),
                  child: Text(
                    'details'.tr,
                    style: robotoMedium.copyWith(color: Theme.of(context).textTheme.bodyLarge!.color, fontSize: Dimensions.fontSizeSmall),
                  ),
                ),
              ]),
              const SizedBox(height: Dimensions.paddingSizeSmall),
              Row(children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => _openNavigation(
                      latitude: parcel ? orderModel.deliveryAddress?.latitude : orderModel.storeLat,
                      longitude: parcel ? orderModel.deliveryAddress?.longitude : orderModel.storeLng,
                      fallbackAddress: pickupAddressText,
                    ),
                    style: TextButton.styleFrom(
                      backgroundColor: Theme.of(context).cardColor,
                      minimumSize: const Size(100, 35),
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
                        side: BorderSide(color: Theme.of(context).disabledColor.withValues(alpha: 0.3)),
                      ),
                    ),
                    icon: Icon(Icons.navigation, size: 16, color: Theme.of(context).primaryColor),
                    label: Text(
                      'Navegar para Loja',
                      style: robotoMedium.copyWith(color: Theme.of(context).primaryColor, fontSize: Dimensions.fontSizeSmall),
                    ),
                  ),
                ),
                const SizedBox(width: Dimensions.paddingSizeSmall),
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => _openNavigation(
                      latitude: parcel ? orderModel.receiverDetails?.latitude : orderModel.deliveryAddress?.latitude,
                      longitude: parcel ? orderModel.receiverDetails?.longitude : orderModel.deliveryAddress?.longitude,
                      fallbackAddress: deliveryAddressText,
                    ),
                    style: TextButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      minimumSize: const Size(100, 35),
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
                        side: BorderSide(color: Theme.of(context).disabledColor.withValues(alpha: 0.5)),
                      ),
                    ),
                    icon: Icon(Icons.navigation, size: 16, color: Theme.of(context).cardColor),
                    label: Text(
                      'Navegar para Cliente',
                      style: robotoMedium.copyWith(color: Theme.of(context).cardColor, fontSize: Dimensions.fontSizeSmall),
                    ),
                  ),
                ),
              ]),
            ]),
          ),

        ]),
      ),
    );
  }
}
