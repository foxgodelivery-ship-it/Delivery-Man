import 'dart:async';
import 'dart:collection';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:sixam_mart_delivery/features/order/controllers/order_controller.dart';
import 'package:sixam_mart_delivery/features/order/domain/models/order_model.dart';
import 'package:sixam_mart_delivery/features/profile/controllers/profile_controller.dart';
import 'package:sixam_mart_delivery/util/dimensions.dart';
import 'package:sixam_mart_delivery/util/images.dart';
import 'package:sixam_mart_delivery/features/order/widgets/location_card_widget.dart';

class OrderLocationScreen extends StatefulWidget {
  final OrderModel orderModel;
  final OrderController orderController;
  final int index;
  final Function onTap;
  final bool fromNotification;
  const OrderLocationScreen({
    super.key,
    required this.orderModel,
    required this.orderController,
    required this.index,
    required this.onTap,
    this.fromNotification = false,
  });

  @override
  State<OrderLocationScreen> createState() => _OrderLocationScreenState();
}

class _OrderLocationScreenState extends State<OrderLocationScreen> {
  GoogleMapController? _controller;
  final Set<Marker> _markers = HashSet<Marker>();
  final Set<Polyline> _polylines = HashSet<Polyline>();
  StreamSubscription<Position>? _positionSubscription;
  LatLng? _currentLatLng;


  @override
  void initState() {
    super.initState();
    _initLiveLocation();
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initLiveLocation() async {
    try {
      final Position current = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.bestForNavigation),
      );
      _currentLatLng = LatLng(current.latitude, current.longitude);
      if (mounted) {
        setState(() {});
      }
    } catch (_) {}

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 5,
      ),
    ).listen((Position position) {
      _currentLatLng = LatLng(position.latitude, position.longitude);
      if (mounted) {
        setMarkerAndRoute(widget.orderModel, widget.orderModel.orderType == 'parcel');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    bool parcel = widget.orderModel.orderType == 'parcel';

    return Scaffold(
      body: Stack(children: [

        GoogleMap(
          initialCameraPosition: CameraPosition(target: LatLng(
            double.parse(widget.orderModel.deliveryAddress?.latitude ?? '0'), double.parse(widget.orderModel.deliveryAddress?.longitude ?? '0'),
          ), zoom: 16),
          minMaxZoomPreference: const MinMaxZoomPreference(0, 18),
          zoomControlsEnabled: false,
          myLocationButtonEnabled: false,
          markers: _markers,
          polylines: _polylines,
          onMapCreated: (GoogleMapController controller) {
            _controller = controller;
            setMarkerAndRoute(widget.orderModel, parcel);
          },
        ),

        Positioned(
          top: MediaQuery.of(context).padding.top + 12,
          left: Dimensions.paddingSizeSmall,
          right: Dimensions.paddingSizeSmall,
          child: Row(children: [
            Expanded(
              child: Center(
                child: Text(
                  (widget.orderModel.storeName ?? ' ').toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ),
            _RoundMapButton(icon: Icons.close_rounded, onTap: () => Get.back()),
          ]),
        ),

        Positioned(
          right: Dimensions.paddingSizeSmall,
          top: MediaQuery.of(context).size.height * 0.44,
          child: _RoundMapButton(
            icon: Icons.my_location_rounded,
            onTap: _moveCameraToDeliveryMan,
          ),
        ),

        Positioned(
          bottom: Dimensions.paddingSizeSmall,
          left: Dimensions.paddingSizeSmall,
          right: Dimensions.paddingSizeSmall,
          child: LocationCardWidget(
            orderModel: widget.orderModel,
            orderController: widget.orderController,
            onTap: widget.onTap,
            index: widget.index,
            fromNotification: widget.fromNotification,
            currentLatLng: _currentLatLng,
          ),
        ),

      ]),
    );
  }

  void _moveCameraToDeliveryMan() {
    if(_controller == null) {
      return;
    }
    final lat = _currentLatLng?.latitude ?? Get.find<ProfileController>().recordLocationBody?.latitude;
    final lng = _currentLatLng?.longitude ?? Get.find<ProfileController>().recordLocationBody?.longitude;
    if(lat != null && lng != null) {
      _controller!.animateCamera(CameraUpdate.newLatLngZoom(LatLng(lat, lng), 16));
    }
  }

  void setMarkerAndRoute(OrderModel orderModel, bool parcel) async {
    try {
      Uint8List destinationImageData = await convertAssetToUnit8List(Images.customerMarker, width: 100);
      Uint8List restaurantImageData = await convertAssetToUnit8List(parcel ? Images.userMarker : Images.restaurantMarker, width: parcel ? 70 : 100);
      Uint8List deliveryBoyImageData = await convertAssetToUnit8List(Images.yourMarker, width: 100);

      if (_controller != null) {
        double deliveryLat = double.parse(orderModel.deliveryAddress?.latitude ?? '0');
        double deliveryLng = double.parse(orderModel.deliveryAddress?.longitude ?? '0');
        double storeLat = double.parse(orderModel.storeLat ?? '0');
        double storeLng = double.parse(orderModel.storeLng ?? '0');
        double receiverLat = double.parse(orderModel.receiverDetails?.latitude ?? '0');
        double receiverLng = double.parse(orderModel.receiverDetails?.longitude ?? '0');
        double deliveryManLat = _currentLatLng?.latitude ?? Get.find<ProfileController>().recordLocationBody?.latitude ?? 0;
        double deliveryManLng = _currentLatLng?.longitude ?? Get.find<ProfileController>().recordLocationBody?.longitude ?? 0;

        final List<LatLng> routePoints = [];
        if (deliveryManLat != 0 || deliveryManLng != 0) {
          routePoints.add(LatLng(deliveryManLat, deliveryManLng));
        }
        if (parcel) {
          routePoints.add(LatLng(deliveryLat, deliveryLng));
          routePoints.add(LatLng(receiverLat, receiverLng));
        } else {
          routePoints.add(LatLng(storeLat, storeLng));
          routePoints.add(LatLng(deliveryLat, deliveryLng));
        }

        if (routePoints.length > 1) {
          _polylines
            ..clear()
            ..add(Polyline(
              polylineId: const PolylineId('incoming-order-route'),
              points: routePoints,
              color: Theme.of(context).primaryColor.withValues(alpha: 0.75),
              width: 7,
              jointType: JointType.round,
            ));
        }

        LatLngBounds bounds = _buildBounds(routePoints);
        _controller!.moveCamera(CameraUpdate.newLatLngBounds(bounds, 60));

        _markers.clear();

        if (orderModel.deliveryAddress != null) {
          _markers.add(Marker(
            markerId: const MarkerId('destination'),
            position: LatLng(deliveryLat, deliveryLng),
            infoWindow: InfoWindow(
              title: parcel ? 'Sender' : 'Destination',
              snippet: orderModel.deliveryAddress?.address,
            ),
            icon: BitmapDescriptor.bytes(destinationImageData, height: 40, width: 40),
          ));
        }

        if (parcel && orderModel.receiverDetails != null) {
          _markers.add(Marker(
            markerId: const MarkerId('receiver'),
            position: LatLng(receiverLat, receiverLng),
            infoWindow: InfoWindow(
              title: 'Receiver',
              snippet: orderModel.receiverDetails?.address,
            ),
            icon: BitmapDescriptor.bytes(restaurantImageData, height: 40, width: 40),
          ));
        }

        if (!parcel && orderModel.storeLat != null && orderModel.storeLng != null) {
          _markers.add(Marker(
            markerId: const MarkerId('store'),
            position: LatLng(storeLat, storeLng),
            infoWindow: InfoWindow(
              title: orderModel.storeName,
              snippet: orderModel.storeAddress,
            ),
            icon: BitmapDescriptor.bytes(restaurantImageData, height: 40, width: 40),
          ));
        }

        if (_currentLatLng != null || Get.find<ProfileController>().recordLocationBody != null) {
          _markers.add(Marker(
            markerId: const MarkerId('delivery_boy'),
            position: LatLng(deliveryManLat, deliveryManLng),
            infoWindow: InfoWindow(
              title: 'delivery_man'.tr,
              snippet: Get.find<ProfileController>().recordLocationBody?.location,
            ),
            icon: BitmapDescriptor.bytes(deliveryBoyImageData, height: 40, width: 40),
          ));
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error setting markers: $e');
      }
    }
    setState(() {});
  }

  LatLngBounds _buildBounds(List<LatLng> points) {
    if (points.isEmpty) {
      return const LatLngBounds(
        southwest: LatLng(-90, -180),
        northeast: LatLng(90, 180),
      );
    }

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final point in points) {
      minLat = min(minLat, point.latitude);
      maxLat = max(maxLat, point.latitude);
      minLng = min(minLng, point.longitude);
      maxLng = max(maxLng, point.longitude);
    }

    if (minLat == maxLat) {
      minLat -= 0.01;
      maxLat += 0.01;
    }
    if (minLng == maxLng) {
      minLng -= 0.01;
      maxLng += 0.01;
    }

    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  Future<Uint8List> convertAssetToUnit8List(String imagePath, {int width = 50}) async {
    ByteData data = await rootBundle.load(imagePath);
    Codec codec = await instantiateImageCodec(data.buffer.asUint8List(), targetWidth: width);
    FrameInfo fi = await codec.getNextFrame();
    return (await fi.image.toByteData(format: ImageByteFormat.png))!.buffer.asUint8List();
  }
}

class _RoundMapButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _RoundMapButton({required this.icon, required this.onTap});



  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(28),
      child: Container(
        height: 56,
        width: 56,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 8),
          ],
        ),
        child: Icon(icon, color: Theme.of(context).textTheme.bodyLarge?.color),
      ),
    );
  }
}
