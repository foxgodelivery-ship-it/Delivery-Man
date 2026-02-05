import 'package:sixam_mart_delivery/features/order/domain/models/order_model.dart';
import 'package:sixam_mart_delivery/util/dimensions.dart';
import 'package:sixam_mart_delivery/util/styles.dart';
import 'package:sixam_mart_delivery/common/widgets/custom_image_widget.dart';
import 'package:sixam_mart_delivery/common/widgets/custom_snackbar_widget.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher_string.dart';

class InfoCardWidget extends StatelessWidget {
  final String title;
  final String image;
  final String? name;
  final DeliveryAddress? address;
  final String? phone;
  final String? latitude;
  final String? longitude;
  final bool showButton;
  final bool isStore;
  final Function? messageOnTap;
  final OrderModel order;
  final bool isChatAllow;
  final bool showCallButton;
  const InfoCardWidget({super.key, required this.title, required this.image, required this.name, required this.address, required this.phone,
    required this.latitude, required this.longitude, required this.showButton, this.messageOnTap, this.isStore = false, required this.order,
    required this.isChatAllow, this.showCallButton = true});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: Dimensions.paddingSizeSmall),
      padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeSmall),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
        boxShadow: Get.isDarkMode ? null : [BoxShadow(color: Colors.black.withValues(alpha: 0.08), spreadRadius: 1, blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: Dimensions.paddingSizeSmall),

        Text(title, style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: Theme.of(context).disabledColor)),
        const SizedBox(height: Dimensions.paddingSizeSmall),

        (name != null && name!.isNotEmpty) ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [

          ClipOval(child: CustomImageWidget(
            image: image,
            height: 40, width: 40, fit: BoxFit.cover,
          )),
          const SizedBox(width: Dimensions.paddingSizeSmall),

          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            Text(name!, style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeSmall)),
            const SizedBox(height: Dimensions.paddingSizeExtraSmall),

            Text(
              address!.address ?? '',
              style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: Theme.of(context).disabledColor), maxLines: 2, overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: address!.address != null ? Dimensions.paddingSizeExtraSmall : 0),

            Wrap(children: [
              _buildAddressNumber(context, address),
              (address!.floor != null && address!.floor!.isNotEmpty) ? Text('${'floor'.tr}: ${address!.floor!}' ,
                style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: Theme.of(context).disabledColor), maxLines: 1, overflow: TextOverflow.ellipsis,
              ) : const SizedBox(),

            ]),

            showButton ? Row(children: [

              (isStore && showCallButton && phone != null && phone!.isNotEmpty) ? TextButton.icon(
                onPressed: () async {
                  if(await canLaunchUrlString('tel:$phone')) {
                    launchUrlString('tel:$phone', mode: LaunchMode.externalApplication);
                  }else {
                    showCustomSnackBar('invalid_phone_number_found');
                  }
                },
                icon: Icon(Icons.call, color: Theme.of(context).primaryColor, size: 20),
                label: Text(
                  'call'.tr,
                  style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: Theme.of(context).primaryColor),
                ),
              ) : const SizedBox(),

              isStore && isChatAllow ? order.isGuest! ? const SizedBox() : TextButton.icon(
                onPressed: messageOnTap as void Function()?,
                icon: Icon(Icons.message, color: Theme.of(context).primaryColor, size: 20),
                label: Text(
                  'chat'.tr,
                  style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: Theme.of(context).primaryColor),
                ),
              ) : const SizedBox(),

              TextButton.icon(
                onPressed: () async {
                  String url ='https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude&mode=d';
                  if (await canLaunchUrlString(url)) {
                    await launchUrlString(url, mode: LaunchMode.externalApplication);
                  } else {
                    throw '${'could_not_launch'.tr} $url';
                  }
                },
                icon: Icon(Icons.directions, color: Theme.of(context).disabledColor, size: 20),
                label: Text(
                  'direction'.tr,
                  style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: Theme.of(context).disabledColor),
                ),
              ),

            ]) : const SizedBox(height: Dimensions.paddingSizeDefault),

          ])),

        ]) : Center(child: Padding(padding: const EdgeInsets.symmetric(vertical: Dimensions.paddingSizeSmall),
          child: Text('no_store_data_found'.tr, style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeSmall)))),

      ]),
    );
  }

  Widget _buildAddressNumber(BuildContext context, DeliveryAddress? address) {
    if (address == null) {
      return const SizedBox();
    }
    final String? number = (address.house != null && address.house!.isNotEmpty)
        ? address.house
        : (address.streetNumber != null && address.streetNumber!.isNotEmpty)
            ? address.streetNumber
            : null;
    if (number == null || number.isEmpty) {
      return const SizedBox();
    }
    final String label = (address.house != null && address.house!.isNotEmpty) ? 'house'.tr : 'street_number'.tr;
    return Text('$label: $number, ',
      style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: Theme.of(context).disabledColor),
      maxLines: 1, overflow: TextOverflow.ellipsis,
    );
  }
}
