import 'package:flutter/material.dart';
import 'package:get/get.dart';

// Imports do 6amMart (Padrão)
import 'package:sixam_mart_delivery/features/order/controllers/order_controller.dart';
import 'package:sixam_mart_delivery/features/profile/controllers/profile_controller.dart';
import 'package:sixam_mart_delivery/util/images.dart';
import 'package:sixam_mart_delivery/util/styles.dart';
import 'package:sixam_mart_delivery/helper/price_converter_helper.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const Color _blueTech = Color(0xFF2962FF);
  static const double _headerRadius = 30.0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // Carrega os dados do entregador ao abrir
  Future<void> _loadData() async {
    await Get.find<ProfileController>().getProfile();
    await Get.find<OrderController>().getCurrentOrders();
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
                            profile?.fName ?? "Entregador",
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
                    )
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
                // Cálculos de meta
                final earnings = profileController.profileModel?.todaysEarning ?? 0.0;
                final goal = 200.0; // Meta fixa ou vinda do backend
                final percent = (earnings / goal).clamp(0.0, 1.0);

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
                          Text("Ganhos de Hoje", style: robotoMedium.copyWith(color: Colors.grey[600], fontSize: 16)),
                          Icon(Icons.trending_up_rounded, color: _blueTech),
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
                              value: percent.toDouble(),
                              backgroundColor: Colors.grey[200],
                              color: _blueTech,
                              minHeight: 8,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text("Meta: ${PriceConverterHelper.convertPrice(goal)}", style: robotoRegular.copyWith(fontSize: 12, color: Colors.grey)),
                              Text("${(percent * 100).toInt()}%", style: robotoBold.copyWith(fontSize: 12, color: _blueTech)),
                            ],
                          )
                        ],
                      )
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
                    _buildStatCard(Icons.local_shipping_outlined, "Entregas", "${profile?.todaysOrderCount ?? 0}"),
                    _buildStatCard(Icons.access_time, "Horas Online", "—"),
                    _buildStatCard(Icons.attach_money, "Gorjetas", PriceConverterHelper.convertPrice(0)),
                    _buildStatCard(Icons.map_outlined, "Km Rodados", "—"),
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
                  onTap: () => profileController.updateActiveStatus(),
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
                        )
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(isOnline ? Icons.power_settings_new : Icons.flash_on_rounded, color: Colors.white, size: 28),
                        const SizedBox(width: 12),
                        Text(
                          isOnline ? "PARAR DE RODAR" : "FICAR ONLINE",
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
    if (hour < 12) return "Bom dia,";
    if (hour < 18) return "Boa tarde,";
    return "Boa noite,";
  }

}
