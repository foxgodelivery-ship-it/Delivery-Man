import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:sixam_mart_delivery/features/order/controllers/order_controller.dart';
import 'package:sixam_mart_delivery/features/address/controllers/address_controller.dart';
import 'package:sixam_mart_delivery/features/profile/controllers/profile_controller.dart';
import 'package:sixam_mart_delivery/features/splash/controllers/splash_controller.dart';
import 'package:sixam_mart_delivery/features/order/domain/models/order_model.dart';
import 'package:sixam_mart_delivery/helper/date_converter_helper.dart';
import 'package:sixam_mart_delivery/helper/price_converter_helper.dart';
import 'package:sixam_mart_delivery/helper/route_helper.dart';
import 'package:sixam_mart_delivery/util/dimensions.dart';
import 'package:sixam_mart_delivery/util/images.dart';
import 'package:sixam_mart_delivery/util/styles.dart';
import 'package:sixam_mart_delivery/common/widgets/confirmation_dialog_widget.dart';
import 'package:sixam_mart_delivery/common/widgets/custom_button_widget.dart';
import 'package:sixam_mart_delivery/common/widgets/custom_image_widget.dart';
import 'package:sixam_mart_delivery/common/widgets/custom_snackbar_widget.dart';
import 'package:sixam_mart_delivery/features/order/screens/order_details_screen.dart';
import 'package:sixam_mart_delivery/features/notification/domain/models/notification_body_model.dart';
import 'package:sixam_mart_delivery/features/chat/domain/models/conversation_model.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher_string.dart';

class OrderRequestWidget extends StatelessWidget {
  final OrderModel orderModel;
  final int index;
  final bool fromDetailsPage;
  final Function onTap;
  const OrderRequestWidget({super.key, required this.orderModel, required this.index, required this.onTap, this.fromDetailsPage = false});

  bool _isValidValue(String? value) => value != null && value.trim().isNotEmpty;

  String _formatAddress(DeliveryAddress? address) {
    if(address == null) {
      return '';
    }
    final List<String> parts = [];
    if(_isValidValue(address.address)) {
      parts.add(address.address!.trim());
    }
    if(_isValidValue(address.house)) {
      parts.add(address.house!.trim());
    } else if(_isValidValue(address.streetNumber)) {
      parts.add(address.streetNumber!.trim());
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
    double distance = Get.find<AddressController>().getRestaurantDistance(
      LatLng(double.parse(parcel ? orderModel.deliveryAddress?.latitude ?? '0' : orderModel.storeLat ?? '0'), double.parse(parcel ? orderModel.deliveryAddress?.longitude ?? '0' : orderModel.storeLng ?? '0')),
    );
    final String pickupTitle = parcel ? 'Remetente' : (orderModel.storeName ?? 'store_not_found'.tr);
    final String pickupAddress = parcel
        ? _formatAddress(orderModel.deliveryAddress)
        : (orderModel.storeAddress ?? 'address_not_found'.tr);
    final String deliveryAddress = parcel ? _formatAddress(orderModel.receiverDetails) : _formatAddress(orderModel.deliveryAddress);
    final String pickupAddressText = pickupAddress.isNotEmpty ? pickupAddress : 'address_not_found'.tr;
    final String deliveryAddressText = deliveryAddress.isNotEmpty ? deliveryAddress : 'address_not_found'.tr;
    final bool hasPickedUp = orderModel.orderStatus == 'picked_up';

    return LayoutBuilder(builder: (context, constraints) {
      final double maxWidth = constraints.maxWidth >= 700 ? 520 : constraints.maxWidth;
      return Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Container(
            margin: const EdgeInsets.only(bottom: Dimensions.paddingSizeSmall),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10)],
            ),
            child: GetBuilder<OrderController>(builder: (orderController) {
              return Column(children: [

          Padding(
            padding: const EdgeInsets.all(Dimensions.paddingSizeSmall),
            child: Column(children: [

              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [

                Container(
                  height: 45, width: 45, alignment: Alignment.center,
                  decoration: parcel ? BoxDecoration(
                    borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
                    color: Theme.of(context).primaryColor.withValues(alpha: 0.2),
                  ) : null,
                  child: ClipRRect(borderRadius: BorderRadius.circular(Dimensions.radiusSmall), child: CustomImageWidget(
                    image: parcel ? '${orderModel.parcelCategory != null ? orderModel.parcelCategory!.imageFullUrl : ''}' : orderModel.storeLogoFullUrl ?? '',
                    height: parcel ? 30 : 45, width: parcel ? 30 : 45, fit: BoxFit.cover,
                  )),
                ),
                const SizedBox(width: Dimensions.paddingSizeSmall),

                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    parcel ? orderModel.parcelCategory != null ? orderModel.parcelCategory!.name ?? ''
                      : '' : orderModel.storeName ?? 'no_store_data_found'.tr, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: robotoMedium.copyWith(fontSize: Dimensions.fontSizeSmall),
                  ),
                  const SizedBox(height: Dimensions.paddingSizeExtraSmall),

                  Text(
                    parcel ? 'parcel'.tr : '${orderModel.detailsCount} ${orderModel.detailsCount! > 1 ? 'items'.tr : 'item'.tr}',
                    style: robotoMedium.copyWith(fontSize: Dimensions.fontSizeSmall, color: Theme.of(context).primaryColor),
                  ),
                  const SizedBox(height: Dimensions.paddingSizeExtraSmall),

                  Text(
                    parcel ? orderModel.parcelCategory != null ? orderModel.parcelCategory!.description ?? '' : '' : orderModel.storeAddress ?? '', maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: Theme.of(context).disabledColor),
                  ),
                ])),
                const SizedBox(width: Dimensions.paddingSizeSmall),

                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                    children: [

                  Text(
                    DateConverterHelper.beforeTimeFormat(orderModel.createdAt!),
                    // '${DateConverterHelper.timeDistanceInMin(orderModel.createdAt!)} ${'mins_ago'.tr}',
                    style: robotoMedium.copyWith(color: Theme.of(context).primaryColor, fontSize: Dimensions.fontSizeSmall),
                  ),
                  const SizedBox(height: Dimensions.paddingSizeSmall),

                  orderModel.deliveryAddress != null ? Container(
                    width: 110,
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeSmall, vertical: Dimensions.paddingSizeSmall),
                    child: Text(
                      '${distance > 1000 ? '1000+' : distance.toStringAsFixed(2)} ${'km_away_from_you'.tr}',
                      style: robotoMedium.copyWith(fontSize: Dimensions.fontSizeSmall), textAlign: TextAlign.center,
                    ),
                  ) : Container(
                    height: 20, width: 30,
                    color: Colors.green,
                  ),
                ]),
              ]),

              const SizedBox(height: Dimensions.paddingSizeSmall),

              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('RETIRADA', style: robotoMedium.copyWith(fontSize: Dimensions.fontSizeSmall)),
                const SizedBox(height: Dimensions.paddingSizeExtraSmall),
                Text(
                  pickupTitle,
                  style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeSmall),
                ),
                const SizedBox(height: Dimensions.paddingSizeExtraSmall),
                Text(
                  pickupAddressText,
                  style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: Theme.of(context).disabledColor),
                ),
                const SizedBox(height: Dimensions.paddingSizeExtraSmall),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => _openNavigation(
                      latitude: parcel ? orderModel.deliveryAddress?.latitude : orderModel.storeLat,
                      longitude: parcel ? orderModel.deliveryAddress?.longitude : orderModel.storeLng,
                      fallbackAddress: pickupAddressText,
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeSmall, vertical: 4),
                      minimumSize: const Size(0, 28),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: Icon(Icons.navigation, size: 16, color: Theme.of(context).primaryColor),
                    label: Text(
                      'Navegar até retirada',
                      style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: Theme.of(context).primaryColor),
                    ),
                  ),
                ),
                const SizedBox(height: Dimensions.paddingSizeSmall),
                Text('ENTREGA', style: robotoMedium.copyWith(fontSize: Dimensions.fontSizeSmall)),
                const SizedBox(height: Dimensions.paddingSizeExtraSmall),
                Text(
                  'Destinatário',
                  style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeSmall),
                ),
                const SizedBox(height: Dimensions.paddingSizeExtraSmall),
                Text(
                  deliveryAddressText,
                  style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: Theme.of(context).disabledColor),
                ),
                const SizedBox(height: Dimensions.paddingSizeExtraSmall),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => _openNavigation(
                      latitude: parcel ? orderModel.receiverDetails?.latitude : orderModel.deliveryAddress?.latitude,
                      longitude: parcel ? orderModel.receiverDetails?.longitude : orderModel.deliveryAddress?.longitude,
                      fallbackAddress: deliveryAddressText,
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeSmall, vertical: 4),
                      minimumSize: const Size(0, 28),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: Icon(Icons.navigation, size: 16, color: Theme.of(context).primaryColor),
                    label: Text(
                      'Navegar até entrega',
                      style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: Theme.of(context).primaryColor),
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: Dimensions.paddingSizeSmall),

              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () {
                    if(hasPickedUp && orderModel.customer != null) {
                      Get.toNamed(RouteHelper.getChatRoute(
                        notificationBody: NotificationBodyModel(
                          orderId: orderModel.id, customerId: orderModel.customer!.id,
                        ),
                        user: User(
                          id: orderModel.customer!.id,
                          fName: orderModel.customer!.fName,
                          lName: orderModel.customer!.lName,
                          imageFullUrl: orderModel.customer!.imageFullUrl,
                        ),
                      ));
                    }else if(orderModel.storeId != null) {
                      Get.toNamed(RouteHelper.getChatRoute(
                        notificationBody: NotificationBodyModel(
                          orderId: orderModel.id, vendorId: orderModel.storeId,
                        ),
                        user: User(
                          id: orderModel.storeId,
                          fName: orderModel.storeName,
                          imageFullUrl: orderModel.storeLogoFullUrl,
                        ),
                      ));
                    }else {
                      showCustomSnackBar('Chat indisponível no momento.');
                    }
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeSmall, vertical: 4),
                    minimumSize: const Size(0, 28),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: Icon(Icons.message, size: 16, color: Theme.of(context).primaryColor),
                  label: Text(
                    'Chat',
                    style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: Theme.of(context).primaryColor),
                  ),
                ),
              ),

            ]),
          ),

          Container(
            height: 80,
            decoration: BoxDecoration(
              color: Theme.of(context).disabledColor.withValues(alpha: 0.05),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(Dimensions.radiusDefault)),
            ),
            padding: const EdgeInsets.all(Dimensions.paddingSizeSmall),
            margin: const EdgeInsets.all(0.2),
            child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [

              Expanded(
                child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [

                  (Get.find<SplashController>().configModel!.showDmEarning! && Get.find<ProfileController>().profileModel != null
                      && Get.find<ProfileController>().profileModel!.earnings == 1) ? Text(
                    PriceConverterHelper.convertPrice(orderModel.originalDeliveryCharge! + orderModel.dmTips!),
                    style: robotoBold.copyWith(fontSize: Dimensions.fontSizeLarge),
                  ) : const SizedBox(),
                  const SizedBox(height: Dimensions.paddingSizeExtraSmall),

                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeSmall, vertical: Dimensions.paddingSizeExtraSmall),
                    child: Text(
                      '${'payment'.tr} - ${orderModel.paymentMethod == 'cash_on_delivery' ? 'cod'.tr : orderModel.paymentMethod == 'wallet' ? 'wallet'.tr : 'digitally_paid'.tr}',
                      style: robotoMedium.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: Theme.of(context).disabledColor),
                    ),
                  ),
                ]),
              ),

              Expanded(
                child: Row(children: [
                  Expanded(child: TextButton(
                    onPressed: () => Get.dialog(ConfirmationDialogWidget(
                      icon: Images.warning, title: 'are_you_sure_to_ignore'.tr,
                      description: parcel ? 'you_want_to_ignore_this_delivery'.tr : 'you_want_to_ignore_this_order'.tr,
                      onYesPressed: ()  {
                        Get.back();
                        orderController.ignoreOrder(index);
                      },
                    ), barrierDismissible: false),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(1170, 40), padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
                        side: BorderSide(width: 1, color: Theme.of(context).disabledColor),
                      ),
                    ),
                    child: Text('ignore'.tr, textAlign: TextAlign.center, style: robotoRegular.copyWith(
                      color: Theme.of(context).textTheme.bodyLarge!.color,
                      fontSize: Dimensions.fontSizeLarge,
                    )),
                  )),
                  const SizedBox(width: Dimensions.paddingSizeSmall),

                  Expanded(child: CustomButtonWidget(
                    height: 40,
                    radius: Dimensions.radiusDefault,
                    buttonText: 'accept'.tr,
                    fontSize: Dimensions.fontSizeDefault,
                    onPressed: () => Get.dialog(ConfirmationDialogWidget(
                      icon: Images.warning, title: 'are_you_sure_to_accept'.tr,
                      description: parcel ? 'you_want_to_accept_this_delivery'.tr : 'you_want_to_accept_this_order'.tr,
                      onYesPressed: () {
                        orderController.acceptOrder(orderModel.id, index, orderModel).then((isSuccess) {
                          if(isSuccess) {
                            onTap();
                            orderModel.orderStatus = (orderModel.orderStatus == 'pending' || orderModel.orderStatus == 'confirmed') ? 'accepted' : orderModel.orderStatus;
                            Get.toNamed(
                              RouteHelper.getOrderDetailsRoute(orderModel.id),
                              arguments: OrderDetailsScreen(
                                orderId: orderModel.id, isRunningOrder: true, orderIndex: orderController.currentOrderList!.length-1,
                              ),
                            );
                          }else {
                            Get.find<OrderController>().getLatestOrders();
                          }
                        });
                      },
                    ), barrierDismissible: false),
                  )),
                ]),
              ),

            ]),
          ),

        ]);
      }),
          ),
        ),
      );
    });
  }
}
