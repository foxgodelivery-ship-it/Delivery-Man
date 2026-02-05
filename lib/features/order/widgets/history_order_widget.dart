import 'package:sixam_mart_delivery/features/order/domain/models/order_model.dart';
import 'package:sixam_mart_delivery/helper/date_converter_helper.dart';
import 'package:sixam_mart_delivery/util/dimensions.dart';
import 'package:sixam_mart_delivery/util/styles.dart';
import 'package:sixam_mart_delivery/common/widgets/custom_image_widget.dart';
import 'package:sixam_mart_delivery/features/order/screens/order_details_screen.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sixam_mart_delivery/common/widgets/custom_snackbar_widget.dart';
import 'package:url_launcher/url_launcher_string.dart';

class HistoryOrderWidget extends StatelessWidget {
  final OrderModel orderModel;
  final bool isRunning;
  final int index;
  const HistoryOrderWidget({super.key, required this.orderModel, required this.isRunning, required this.index});

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
    final String pickupAddress = parcel
        ? _formatAddress(orderModel.deliveryAddress)
        : (orderModel.storeAddress ?? '');
    final String deliveryAddress = parcel
        ? _formatAddress(orderModel.receiverDetails)
        : _formatAddress(orderModel.deliveryAddress);
    final String pickupAddressText = pickupAddress.isNotEmpty ? pickupAddress : 'address_not_found'.tr;
    final String deliveryAddressText = deliveryAddress.isNotEmpty ? deliveryAddress : 'address_not_found'.tr;

    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => OrderDetailsScreen(orderId: orderModel.id, isRunningOrder: isRunning, orderIndex: index))),
      child: Container(
        padding: const EdgeInsets.all(Dimensions.paddingSizeSmall),
        margin: const EdgeInsets.only(bottom: Dimensions.paddingSizeSmall),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          boxShadow: Get.isDarkMode ? null : [BoxShadow(color: Colors.grey[200]!, spreadRadius: 1, blurRadius: 5)],
          borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
        ),
        child: Column(children: [
          Row(children: [

          Container(
            height: 70, width: 70, alignment: Alignment.center,
            decoration: parcel ? BoxDecoration(
              borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
              color: Theme.of(context).primaryColor.withValues(alpha: 0.2),
            ) : null,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
              child: CustomImageWidget(
                image: parcel ? '${orderModel.parcelCategory != null ? orderModel.parcelCategory!.imageFullUrl : ''}' : orderModel.storeLogoFullUrl ?? '',
                height: parcel ? 45 : 70, width: parcel ? 45 : 70, fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: Dimensions.paddingSizeSmall),

          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

              Row(children: [
                Text(
                  '${parcel ? 'delivery_id'.tr : 'order_id'.tr}:',
                  style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeSmall),
                ),
                const SizedBox(width: Dimensions.paddingSizeExtraSmall),
                Expanded(child: Text(
                  '#${orderModel.id}',
                  style: robotoMedium.copyWith(fontSize: Dimensions.fontSizeSmall),
                )),
                parcel ? Container(
                  padding: const EdgeInsets.all(Dimensions.paddingSizeExtraSmall),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
                    color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                  ),
                  child: Text('parcel'.tr, style: robotoMedium.copyWith(
                    fontSize: Dimensions.fontSizeExtraSmall, color: Theme.of(context).primaryColor,
                  )),
                ) : const SizedBox(),
              ]),
              const SizedBox(height: Dimensions.paddingSizeExtraSmall),

              Text(
                parcel ? orderModel.parcelCategory != null ? orderModel.parcelCategory!.name! : 'no_parcel_category_data_found'.tr : orderModel.storeName ?? 'no_store_data_found'.tr,
                style: robotoMedium.copyWith(fontSize: Dimensions.fontSizeSmall, color: Theme.of(context).primaryColor),
              ),
              const SizedBox(height: Dimensions.paddingSizeExtraSmall),

              Row(children: [
                const Icon(Icons.access_time, size: 15),
                const SizedBox(width: Dimensions.paddingSizeExtraSmall),
                Text(
                  DateConverterHelper.dateTimeStringToDateTime(orderModel.createdAt!),
                  style: robotoRegular.copyWith(color: Theme.of(context).disabledColor, fontSize: Dimensions.fontSizeSmall),
                ),
              ]),

            ]),
          ),

          ]),
          const SizedBox(height: Dimensions.paddingSizeSmall),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('RETIRADA', style: robotoMedium.copyWith(fontSize: Dimensions.fontSizeSmall)),
            const SizedBox(height: Dimensions.paddingSizeExtraSmall),
            Text(
              pickupAddressText,
              style: robotoRegular.copyWith(color: Theme.of(context).disabledColor, fontSize: Dimensions.fontSizeSmall),
              maxLines: 2, overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: Dimensions.paddingSizeSmall),
            Text('ENTREGA', style: robotoMedium.copyWith(fontSize: Dimensions.fontSizeSmall)),
            const SizedBox(height: Dimensions.paddingSizeExtraSmall),
            Text(
              deliveryAddressText,
              style: robotoRegular.copyWith(color: Theme.of(context).disabledColor, fontSize: Dimensions.fontSizeSmall),
              maxLines: 2, overflow: TextOverflow.ellipsis,
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
                  padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeSmall, vertical: 4),
                  minimumSize: const Size(0, 28),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: Icon(Icons.navigation, size: 16, color: Theme.of(context).primaryColor),
                label: Text(
                  'Navegar para Loja',
                  style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: Theme.of(context).primaryColor),
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
                  padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeSmall, vertical: 4),
                  minimumSize: const Size(0, 28),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: Icon(Icons.navigation, size: 16, color: Theme.of(context).primaryColor),
                label: Text(
                  'Navegar para Cliente',
                  style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: Theme.of(context).primaryColor),
                ),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}
