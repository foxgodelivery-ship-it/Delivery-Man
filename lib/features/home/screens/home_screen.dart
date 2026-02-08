import 'dart:math';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Imports do 6amMart (Padrão)
import 'package:sixam_mart_delivery/features/order/controllers/order_controller.dart';
import 'package:sixam_mart_delivery/features/profile/controllers/profile_controller.dart';
import 'package:sixam_mart_delivery/helper/price_converter_helper.dart';
import 'package:sixam_mart_delivery/util/app_constants.dart';
import 'package:sixam_mart_delivery/util/images.dart';
import 'package:sixam_mart_delivery/util/styles.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const Color _blueTech = Color(0xFF2962FF);
  static const double _headerRadius = 30.0;

  late final SharedPreferences _sharedPreferences;

  double _goalValue = 200;
  DateTime? _onlineStartTime;
  Duration _onlineDuration = Duration.zero;
  Timer? _onlineTimer;
  double _todayCompletedDistanceKm = 0;

  @override
  void initState() {
    super.initState();
    _sharedPreferences = Get.find<SharedPreferences>();
    _loadPersistedGoal();
    _loadData();
  }

  @override
  void dispose() {
    _onlineTimer?.cancel();
    super.dispose();
  }

  // Carrega os dados do entregador ao abrir
  Future<void> _loadData() async {
    await Get.find<ProfileController>().getProfile();
    await Get.find<OrderController>().getCurrentOrders();
    await Get.find<OrderController>().getCompletedOrders(1, willUpdate: false);

    _syncOnlineStartTimeWithStatus();
    _calculateTodayCompletedDistance();
  }

  void _loadPersistedGoal() {
    _goalValue = _sharedPreferences.getDouble(AppConstants.homeDailyGoalValue) ?? 200;
  }

  void _syncOnlineStartTimeWithStatus() {
    final isOnline = Get.find<ProfileController>().profileModel?.active == 1;
    final savedStartMillis = _sharedPreferences.getInt(AppConstants.onlineStartTime);

    if (!isOnline) {
      _sharedPreferences.remove(AppConstants.onlineStartTime);
      _onlineStartTime = null;
      _onlineDuration = Duration.zero;
      _onlineTimer?.cancel();
      if (mounted) {
        setState(() {});
      }
      return;
    }

    if (savedStartMillis != null) {
      _onlineStartTime = DateTime.fromMillisecondsSinceEpoch(savedStartMillis);
    } else {
      _onlineStartTime = DateTime.now();
      _sharedPreferences.setInt(AppConstants.onlineStartTime, _onlineStartTime!.millisecondsSinceEpoch);
    }

    _updateOnlineDuration();
    _onlineTimer?.cancel();
    _onlineTimer = Timer.periodic(const Duration(seconds: 30), (_) => _updateOnlineDuration());

    if (mounted) {
      setState(() {});
    }
  }

  void _updateOnlineDuration() {
    if (_onlineStartTime == null) {
      _onlineDuration = Duration.zero;
      return;
    }

    _onlineDuration = DateTime.now().difference(_onlineStartTime!);
    if (mounted) {
      setState(() {});
    }
  }

  void _calculateTodayCompletedDistance() {
    final completedOrders = Get.find<OrderController>().completedOrderList ?? [];
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final tomorrowStart = todayStart.add(const Duration(days: 1));

    double totalKm = 0;

    for (final order in completedOrders) {
      final completedAt = _parseDateTime(order.updatedAt ?? order.createdAt);
      if (completedAt == null || completedAt.isBefore(todayStart) || !completedAt.isBefore(tomorrowStart)) {
        continue;
      }

      final storeLat = double.tryParse(order.storeLat ?? '');
      final storeLng = double.tryParse(order.storeLng ?? '');
      final userLat = double.tryParse(order.deliveryAddress?.latitude ?? '');
      final userLng = double.tryParse(order.deliveryAddress?.longitude ?? '');

      if (storeLat == null || storeLng == null || userLat == null || userLng == null) {
        continue;
      }

      totalKm += _haversineInKm(
        lat1: storeLat,
        lon1: storeLng,
        lat2: userLat,
        lon2: userLng,
      );
    }

    _todayCompletedDistanceKm = totalKm;
    if (mounted) {
      setState(() {});
    }
  }

  DateTime? _parseDateTime(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    return DateTime.tryParse(value)?.toLocal();
  }

  double _haversineInKm({
    required double lat1,
    required double lon1,
    required double lat2,
    required double lon2,
  }) {
    const earthRadiusKm = 6371;
    final dLat = _degreesToRadians(lat2 - lat1);
    final dLon = _degreesToRadians(lon2 - lon1);

    final a =
        (sin(dLat / 2) * sin(dLat / 2)) +
            cos(_degreesToRadians(lat1)) *
                cos(_degreesToRadians(lat2)) *
                (sin(dLon / 2) * sin(dLon / 2));

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadiusKm * c;
  }

  double _degreesToRadians(double degrees) => degrees * (3.1415926535897932 / 180);

  Future<void> _showGoalEditDialog() async {
    final controller = TextEditingController(text: _goalValue.toStringAsFixed(0));

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Editar meta diária'),
          content: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(hintText: 'Ex: 200'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () {
                final parsedValue = double.tryParse(controller.text.replaceAll(',', '.'));
                if (parsedValue == null || parsedValue <= 0) {
                  Get.snackbar('Meta inválida', 'Informe um valor maior que zero.');
                  return;
                }

                _sharedPreferences.setDouble(AppConstants.homeDailyGoalValue, parsedValue);
                setState(() {
                  _goalValue = parsedValue;
                });
                Navigator.pop(context);
              },
              child: const Text('Salvar'),
            ),
          ],
        );
      },
    );

    controller.dispose();
  }

  String _formatOnlineDuration() {
    final totalMinutes = _onlineDuration.inMinutes;
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    return '${hours}h ${minutes.toString().padLeft(2, '0')}m';
  }

  @override
  Widget build(BuildContext context) {
    // Pega o tamanho da tela para ajustar layout
    final media = MediaQuery.of(context);

    return Scaffold(
      backgroundColor: Colors.grey[50], // Fundo levemente cinza para contraste
      body: RefreshIndicator(
        onRefresh: _loadData,
        color: Theme.of(context).primaryColor,
        child: SizedBox(
          height: media.size.height,
          width: media.size.width,
          child: Stack(
            children: [
              // =================================================
              // 1. CABEÇALHO (HEADER) – cor primária do tema
              // =================================================
              Container(
                height: media.size.height * 0.32, // Ocupa 32% da tela
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(_headerRadius),
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(24, 60, 24, 0),
                child: GetBuilder<ProfileController>(builder: (profileController) {
                  final profile = profileController.profileModel;
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Avatar do Entregador
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: CircleAvatar(
                          radius: 28,
                          backgroundColor: Colors.white,
                          backgroundImage: (profile?.imageFullUrl != null && profile!.imageFullUrl!.isNotEmpty)
                              ? NetworkImage(profile.imageFullUrl!) as ImageProvider
                              : const AssetImage(Images.placeholder) as ImageProvider,
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Texto de Boas-vindas
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _saudacao(),
                              style: robotoRegular.copyWith(color: Colors.white.withOpacity(0.9), fontSize: 16),
                            ),
                            Text(
                              profile?.fName ?? 'Entregador',
                              style: robotoBold.copyWith(color: Colors.white, fontSize: 22),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      // Ícone de Notificação
                      IconButton(
                        icon: const Icon(Icons.notifications_none_rounded, color: Colors.white, size: 30),
                        onPressed: () {
                          // Ação do sino (se tiver rota de notificação)
                        },
                      ),
                    ],
                  );
                }),
              ),

              // =================================================
              // 2. CARD FLUTUANTE DE GANHOS (CARD AZUL/BRANCO)
              // =================================================
              Positioned(
                top: media.size.height * 0.20,
                left: 20,
                right: 20,
                child: GetBuilder<ProfileController>(builder: (profileController) {
                  final earnings = profileController.profileModel?.todaysEarning ?? 0.0;
                  final safeGoal = _goalValue <= 0 ? 1 : _goalValue;
                  final progressPercent = (earnings / safeGoal) * 100;
                  final percent = (progressPercent / 100).clamp(0.0, 1.0);

                  return Container(
                    height: 160,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, 8)),
                      ],
                    ),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Ganhos de Hoje', style: robotoMedium.copyWith(color: Colors.grey[600], fontSize: 16)),
                            Row(
                              children: [
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  onPressed: _showGoalEditDialog,
                                  icon: const Icon(Icons.edit_note_rounded),
                                  color: _blueTech,
                                  tooltip: 'Editar meta',
                                ),
                                Icon(Icons.trending_up_rounded, color: _blueTech),
                              ],
                            ),
                          ],
                        ),
                        // Valor Grande
                        Text(
                          PriceConverterHelper.convertPrice(earnings),
                          style: robotoBold.copyWith(color: _blueTech, fontSize: 36),
                        ),
                        // Barra de Meta
                        Column(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: LinearProgressIndicator(
                                value: percent,
                                backgroundColor: Colors.grey[200],
                                color: _blueTech,
                                minHeight: 8,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Meta: ${PriceConverterHelper.convertPrice(_goalValue)}',
                                  style: robotoRegular.copyWith(fontSize: 12, color: Colors.grey),
                                ),
                                Text(
                                  '${progressPercent.toStringAsFixed(0)}%',
                                  style: robotoBold.copyWith(fontSize: 12, color: _blueTech),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }),
              ),

              // =================================================
              // 3. GRID DE ESTATÍSTICAS (ICONES)
              // =================================================
              Positioned.fill(
                top: media.size.height * 0.42, // Começa abaixo do card de ganhos
                bottom: 110 + media.padding.bottom,
                child: GetBuilder<ProfileController>(builder: (profileController) {
                  final profile = profileController.profileModel;
                  return GridView.count(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    crossAxisCount: 2,
                    childAspectRatio: 1.3,
                    mainAxisSpacing: 15,
                    crossAxisSpacing: 15,
                    children: [
                      _buildStatCard(Icons.local_shipping_outlined, 'Entregas', '${profile?.todaysOrderCount ?? 0}'),
                      _buildStatCard(Icons.access_time, 'Horas Online', _formatOnlineDuration()),
                      _buildStatCard(Icons.attach_money, 'Gorjetas', PriceConverterHelper.convertPrice(0)),
                      _buildStatCard(Icons.map_outlined, 'Km Rodados', '${_todayCompletedDistanceKm.toStringAsFixed(1)} km'),
                    ],
                  );
                }),
              ),

              // =================================================
              // 4. BOTÃO GIGANTE (ONLINE/OFFLINE)
              // =================================================
              Positioned(
                bottom: 20 + media.padding.bottom,
                left: 20,
                right: 20,
                child: GetBuilder<ProfileController>(builder: (profileController) {
                  final isOnline = profileController.profileModel?.active == 1;
                  return GestureDetector(
                    onTap: () async {
                      final success = await profileController.updateActiveStatus();
                      if (!success) {
                        return;
                      }
                      _syncOnlineStartTimeWithStatus();
                    },
                    child: Container(
                      height: 65,
                      decoration: BoxDecoration(
                        color: isOnline ? Colors.grey[800] : _blueTech,
                        borderRadius: BorderRadius.circular(32),
                        boxShadow: [
                          BoxShadow(
                            color: (isOnline ? Colors.black : _blueTech).withOpacity(0.3),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(isOnline ? Icons.power_settings_new : Icons.flash_on_rounded, color: Colors.white, size: 28),
                          const SizedBox(width: 12),
                          Text(
                            isOnline ? 'PARAR DE RODAR' : 'FICAR ONLINE',
                            style: robotoBold.copyWith(color: Colors.white, fontSize: 20, letterSpacing: 1),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Widgets Auxiliares ---

  Widget _buildStatCard(IconData icon, String title, String value) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: _blueTech, size: 28),
          const Spacer(),
          Text(value, style: robotoBold.copyWith(fontSize: 20, color: Colors.black87)),
          Text(title, style: robotoRegular.copyWith(fontSize: 13, color: Colors.grey[600])),
        ],
      ),
    );
  }

  String _saudacao() {
    var hour = DateTime.now().hour;
    if (hour < 12) return 'Bom dia,';
    if (hour < 18) return 'Boa tarde,';
    return 'Boa noite,';
  }
}
