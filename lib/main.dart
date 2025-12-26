import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math;

void main() {
  runApp(const NuclearApp());
}

class NuclearApp extends StatelessWidget {
  const NuclearApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Courier',
      ),
      home: const ControlPanelPage(),
    );
  }
}

class ControlPanelPage extends StatefulWidget {
  const ControlPanelPage({super.key});

  @override
  State<ControlPanelPage> createState() => _ControlPanelPageState();
}

class _ControlPanelPageState extends State<ControlPanelPage>
    with TickerProviderStateMixin {
  // =====================
  // ESTADO
  // =====================
  // AHORA SOLO 3 TURBINAS
  List<bool> turbinas = [true, true, true];
  late List<AnimationController> turbinaControllers;

  int segundos = 30; // 30 segundos según el documento
  Timer? timer;

  // Variables de simulación
  double nivelAgua = 75.0;
  double tempAgua = 60.0;
  double tempReactor = 120.0;
  double energiaMWe = 1200.0; // Megavatios eléctricos

  // Variables de Checklist
  bool ventilado = false;
  bool aguaVaciada = false;
  bool aguaRellenada = false;
  bool reactorApagado = false;

  // =====================
  // INIT
  // =====================
  @override
  void initState() {
    super.initState();

    turbinaControllers = List.generate(
      3,
      (_) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 800),
      )..repeat(),
    );

    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (segundos > 0) {
        setState(() {
          segundos--;
          // Simulación básica de temperatura subiendo si no hay agua
          if (nivelAgua < 50) {
            tempReactor += 5;
            tempAgua += 2;
          } else {
            if (tempReactor > 100) tempReactor -= 1;
            if (tempAgua > 40) tempAgua -= 0.5;
          }
          
          // Energía depende de turbinas activas
          int activas = turbinas.where((t) => t).length;
          energiaMWe = activas * 400.0;
        });
      }
    });
  }

  @override
  void dispose() {
    for (var c in turbinaControllers) {
      c.dispose();
    }
    timer?.cancel();
    super.dispose();
  }

  // =====================
  // LOGICA
  // =====================
  void _toggleTurbina(int i) async {
    setState(() {
      turbinas[i] = !turbinas[i];
    });

    bool encendiendo = turbinas[i];
    const int minDuration = 800;
    const int maxDuration = 5000;

    if (encendiendo && !turbinaControllers[i].isAnimating) {
      turbinaControllers[i].duration = const Duration(milliseconds: maxDuration);
      turbinaControllers[i].repeat();
    }

    int startMs = turbinaControllers[i].duration?.inMilliseconds ?? maxDuration;
    int endMs = encendiendo ? minDuration : maxDuration;

    const int steps = 50;
    const int stepDelay = 50;

    for (int step = 1; step <= steps; step++) {
      if (!mounted) return;
      if (turbinas[i] != encendiendo) return;

      double t = step / steps;
      double currentMs = startMs + (endMs - startMs) * t;

      turbinaControllers[i].duration = Duration(milliseconds: currentMs.toInt());
      await Future.delayed(const Duration(milliseconds: stepDelay));
    }

    if (!encendiendo && mounted && turbinas[i] == false) {
      turbinaControllers[i].stop();
    }
  }

  void _vaciarAgua() {
    setState(() {
      aguaVaciada = true;
      if (nivelAgua > 0) nivelAgua -= 10;
      if (nivelAgua < 0) nivelAgua = 0;
    });
  }

  void _rellenarAgua() {
    setState(() {
      aguaRellenada = true;
      if (nivelAgua < 100) nivelAgua += 10;
      if (nivelAgua > 100) nivelAgua = 100;
      // Agua fría enfría el sistema
      if (tempAgua > 20) tempAgua -= 5;
      if (tempReactor > 100) tempReactor -= 2;
    });
  }

  void _ventilar() {
    setState(() {
      ventilado = true;
      // Ventilar ayuda a reducir la temperatura del reactor
      if (tempReactor > 50) tempReactor -= 5;
    });
  }

  void _apagarReactor() {
    setState(() {
      reactorApagado = true;
      // Apagar reactor reduce temperatura drásticamente
      if (tempReactor > 20) tempReactor = 20;
    });
  }

  // =====================
  // UI PRINCIPAL
  // =====================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade200,
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // === IZQUIERDA: MONITORIZACIÓN ===
            Expanded(
              flex: 1,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: _panelDecoration(),
                child: Column(
                  children: [
                    const Text("NIVEL DE AGUA", style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 100,
                      width: 150,
                      child: WaterLevelGauge(level: nivelAgua),
                    ),
                    const SizedBox(height: 20),
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildThermometer("Agua", tempAgua, 100),
                          _buildThermometer("Núcleo", tempReactor, 600), // Escala hasta 600 para ver los 400 de alerta
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    EmergencyButton(
                      enabled: reactorApagado,
                      onPressed: () {
                      setState(() {
                        turbinas = [false, false, false];
                        for(var c in turbinaControllers) c.stop();
                        energiaMWe = 0;
                      });
                    }),
                  ],
                ),
              ),
            ),

            const SizedBox(width: 16),

            // === CENTRO: VISUALIZACIÓN ===
            Expanded(
              flex: 2,
              child: Column(
                children: [
                  _cronometro(),
                  const SizedBox(height: 16),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: _panelDecoration(),
                      child: Column(
                        children: [
                          // MWe Display
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              "GENERACIÓN: ${energiaMWe.toInt()} MWe",
                              style: const TextStyle(
                                color: Colors.greenAccent,
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Expanded(
                            flex: 3,
                            child: ReactorSchematic(
                              nivelAgua: nivelAgua,
                              temperatura: tempAgua,
                              isFlowing: turbinas.contains(true),
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Barra Amarilla (Progreso o Carga)
                          Container(
                            height: 40,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.black, width: 2),
                              color: Colors.white,
                            ),
                            child: Stack(
                              children: [
                                FractionallySizedBox(
                                  widthFactor: (tempReactor / 600).clamp(0.0, 1.0),
                                  child: Container(color: tempReactor > 400 ? Colors.red : Colors.yellow),
                                ),
                                Center(child: Text("TEMPERATURA NÚCLEO: ${tempReactor.toInt()}°C")),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Checklist Placeholder
                          Expanded(
                            flex: 2,
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.black, width: 2),
                                color: Colors.white,
                              ),
                              child: ListView(
                                padding: const EdgeInsets.all(8),
                                children: [
                                  _checkItem("1. Detener Turbinas", !turbinas.contains(true)),
                                  _checkItem("2. Ventilar Radioactividad", ventilado),
                                  _checkItem("3. Evacuar Agua Caliente", aguaVaciada),
                                  _checkItem("4. Ingresar Agua Fría", aguaRellenada),
                                  _checkItem("5. Apagar Reactor", reactorApagado),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 16),

            // === DERECHA: CONTROLES ===
            Expanded(
              flex: 1,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: _panelDecoration(),
                child: Column(
                  children: [
                    const Text("CONTROLES", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    const SizedBox(height: 10),
                    
                    // 3 SWITCHES
                    Expanded(
                      flex: 2,
                      child: SingleChildScrollView(
                        child: Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          alignment: WrapAlignment.center,
                          children: List.generate(
                            3,
                            (i) => switchTurbina(
                              encendida: turbinas[i],
                              bloqueado: segundos == 0,
                              onToggle: () => _toggleTurbina(i),
                            ),
                          ),
                        ),
                      ),
                    ),
                    
                    const Divider(thickness: 2),
                    
                    // CONTROLES DE AGUA
                    const Text("SISTEMA DE AGUA", style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _waterButton(
                          icon: Icons.water_drop_outlined,
                          label: "VACIAR",
                          color: Colors.orange,
                          onTap: _vaciarAgua,
                        ),
                        _waterButton(
                          icon: Icons.water_drop,
                          label: "RELLENAR",
                          color: Colors.blue,
                          onTap: _rellenarAgua,
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),
                    
                    const Text("VENTILACIÓN", style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    _waterButton(
                      icon: Icons.air,
                      label: "VENTILAR",
                      color: Colors.purple,
                      onTap: _ventilar,
                    ),

                    const SizedBox(height: 20),

                    const Text("CONTROL REACTOR", style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    _waterButton(
                      icon: Icons.power_settings_new,
                      label: "APAGAR",
                      color: Colors.redAccent,
                      onTap: _apagarReactor,
                    ),

                    const SizedBox(height: 20),
                    const Divider(thickness: 2),

                    // TURBINAS VISUALES
                    const Text("TURBINAS", style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 80,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: List.generate(
                          3,
                          (i) => turbinaVisual(i),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  BoxDecoration _panelDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.black, width: 2),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.1),
          blurRadius: 5,
          offset: const Offset(2, 2),
        )
      ],
    );
  }

  // =====================
  // WIDGETS AUXILIARES
  // =====================

  Widget _checkItem(String text, bool done) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: done ? Colors.green.shade100 : Colors.grey.shade100,
      child: Row(
        children: [
          Icon(done ? Icons.check_box : Icons.check_box_outline_blank, size: 20),
          const SizedBox(width: 8),
          Text(text, style: TextStyle(decoration: done ? TextDecoration.lineThrough : null)),
        ],
      ),
    );
  }

  Widget _waterButton({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return Column(
      children: [
        Material(
          color: color,
          borderRadius: BorderRadius.circular(10),
          elevation: 4,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 60,
              height: 60,
              alignment: Alignment.center,
              child: Icon(icon, color: Colors.white, size: 30),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _cronometro() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.black, width: 3),
        ),
        child: Text(
          "00:${segundos.toString().padLeft(2, '0')}",
          style: const TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.bold,
            color: Colors.red,
            fontFamily: 'Courier',
          ),
        ),
      );

  Widget _buildThermometer(String label, double temp, double maxTemp) {
    const double maxHeight = 120;
    double height = (temp / maxTemp * maxHeight).clamp(0, maxHeight);
    bool alert = temp > 400;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Stack(
          alignment: Alignment.bottomCenter,
          children: [
            Container(
              width: 24,
              height: maxHeight,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.black),
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              width: 24,
              height: height,
              decoration: BoxDecoration(
                color: alert ? Colors.red : (temp > maxTemp * 0.7 ? Colors.orange : Colors.blue),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text("${temp.toInt()}°", style: TextStyle(fontWeight: FontWeight.bold, color: alert ? Colors.red : Colors.black)),
      ],
    );
  }

  Widget turbinaVisual(int index) {
    return RotationTransition(
      turns: turbinaControllers[index],
      child: Image.asset(
        'assets/images/Turbina.webp',
        width: 60,
        height: 60,
        fit: BoxFit.contain,
      ),
    );
  }

  Widget switchTurbina({
    required bool encendida,
    required bool bloqueado,
    required VoidCallback onToggle,
  }) {
    return _SwitchIndustrial(
      encendida: encendida,
      bloqueado: bloqueado,
      onToggle: onToggle,
    );
  }
}

// ======================================================
// GAUGE (TACOMETRO)
// ======================================================
class WaterLevelGauge extends StatelessWidget {
  final double level;
  const WaterLevelGauge({super.key, required this.level});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: GaugePainter(level),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.only(top: 40),
          child: Text("${level.toInt()}%", style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}

class GaugePainter extends CustomPainter {
  final double level;
  GaugePainter(this.level);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height);
    final radius = math.min(size.width / 2, size.height);
    const strokeWidth = 15.0;

    final rect = Rect.fromCircle(center: center, radius: radius - strokeWidth);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    // Blue Section
    paint.color = Colors.blue;
    canvas.drawArc(rect, math.pi, math.pi / 3, false, paint);

    // Green Section
    paint.color = Colors.green;
    canvas.drawArc(rect, math.pi + math.pi / 3, math.pi / 3, false, paint);

    // Red Section
    paint.color = Colors.red;
    canvas.drawArc(rect, math.pi + 2 * math.pi / 3, math.pi / 3, false, paint);

    // Needle
    final needlePaint = Paint()
      ..color = Colors.black
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    // Map level 0-100 to angle PI to 2PI
    final angle = math.pi + (level / 100) * math.pi;
    final needleLen = radius - 5;
    final needleEnd = Offset(
      center.dx + needleLen * math.cos(angle),
      center.dy + needleLen * math.sin(angle),
    );

    canvas.drawLine(center, needleEnd, needlePaint);
    canvas.drawCircle(center, 5, Paint()..color = Colors.black);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ======================================================
// EMERGENCY BUTTON
// ======================================================
class EmergencyButton extends StatelessWidget {
  final VoidCallback onPressed;
  final bool enabled;
  const EmergencyButton({super.key, required this.onPressed, this.enabled = true});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      height: 140,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black, width: 3),
        color: Colors.white,
      ),
      padding: const EdgeInsets.all(10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onPressed : null,
          borderRadius: BorderRadius.circular(100),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: enabled ? Colors.red : Colors.grey,
              border: Border.all(color: Colors.black, width: 1),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 5,
                  offset: Offset(0, 4),
                )
              ],
            ),
            child: const Center(
              child: Text(
                "BOTÓN DE\nEMERGENCIA",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ======================================================
// SWITCH INDUSTRIAL
// ======================================================
class _SwitchIndustrial extends StatefulWidget {
  final bool encendida;
  final bool bloqueado;
  final VoidCallback onToggle;

  const _SwitchIndustrial({
    required this.encendida,
    required this.bloqueado,
    required this.onToggle,
  });

  @override
  State<_SwitchIndustrial> createState() => _SwitchIndustrialState();
}

class _SwitchIndustrialState extends State<_SwitchIndustrial> {
  @override
  Widget build(BuildContext context) {
    final Color baseColor = widget.encendida
        ? Colors.green.shade600
        : Colors.red.shade600;

    return GestureDetector(
      onTap: widget.bloqueado ? null : widget.onToggle,
      child: Container(
        width: 90,
        height: 100,
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.shade600,
              offset: const Offset(4, 4),
              blurRadius: 10,
            ),
            const BoxShadow(
              color: Colors.white,
              offset: Offset(-4, -4),
              blurRadius: 10,
            ),
          ],
          border: Border.all(color: Colors.grey.shade400),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 30,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.white24,
                    offset: Offset(1, 1),
                    blurRadius: 1,
                  ),
                  BoxShadow(
                    color: Colors.black,
                    offset: Offset(-1, -1),
                    blurRadius: 2,
                  )
                ],
              ),
            ),
            const Positioned(
              top: 10,
              child: Text(
                "OFF",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: Colors.black54,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            const Positioned(
              bottom: 10,
              child: Text(
                "ON",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: Colors.black87,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOutBack,
              top: widget.encendida ? 100 : 35,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: baseColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.6),
                      offset: const Offset(0, 5),
                      blurRadius: 8,
                    ),
                  ],
                  gradient: RadialGradient(
                    center: const Alignment(-0.3, -0.3),
                    radius: 1.2,
                    colors: [
                      Color.lerp(baseColor, Colors.white, 0.4)!,
                      baseColor,
                      Color.lerp(baseColor, Colors.black, 0.6)!,
                    ],
                  ),
                ),
                child: Center(
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          offset: const Offset(1, 1),
                          blurRadius: 1,
                          spreadRadius: 1,
                        )
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ======================================================
// REACTOR SCHEMATIC
// ======================================================
class ReactorSchematic extends StatefulWidget {
  final double nivelAgua;
  final double temperatura;
  final bool isFlowing;

  const ReactorSchematic({
    super.key,
    required this.nivelAgua,
    required this.temperatura,
    required this.isFlowing,
  });

  @override
  State<ReactorSchematic> createState() => _ReactorSchematicState();
}

class _ReactorSchematicState extends State<ReactorSchematic>
    with SingleTickerProviderStateMixin {
  late AnimationController _bubbleController;

  @override
  void initState() {
    super.initState();
    _bubbleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _bubbleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        border: Border.all(color: Colors.black54, width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          children: [
            Container(color: Colors.grey.shade300),
            Align(
              alignment: Alignment.bottomCenter,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.easeInOut,
                    width: double.infinity,
                    height: constraints.maxHeight * (widget.nivelAgua / 100),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.7),
                    ),
                  );
                },
              ),
            ),
            if (widget.isFlowing)
              AnimatedBuilder(
                animation: _bubbleController,
                builder: (context, child) {
                  return Stack(
                    children: List.generate(5, (index) {
                      final double t =
                          (_bubbleController.value + (index * 0.2)) % 1.0;
                      return Positioned(
                        left: 20.0 + (index * 30),
                        bottom: 200 * t,
                        child: Opacity(
                          opacity: 1.0 - t,
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                              color: Colors.white54,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      );
                    }),
                  );
                },
              ),
            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  3,
                  (index) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    width: 15,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade800,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.black),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
