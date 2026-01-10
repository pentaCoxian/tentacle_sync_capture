import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'database/database.dart';
import 'decoders/hypothesis_decoder.dart';
import 'services/ble_service.dart';
import 'services/session_manager.dart';
import 'ui/screens/scan_screen.dart';
import 'ui/screens/sessions_screen.dart';
import 'ui/screens/live_monitor_screen.dart';

/// Global key to access the main navigation state
final GlobalKey<MainNavigationScreenState> mainNavigationKey = GlobalKey<MainNavigationScreenState>();

/// Notifier for monitor configuration - allows passing device/offset to monitor tab
class MonitorConfigNotifier extends ChangeNotifier {
  TimecodeMonitorConfig? _config;

  TimecodeMonitorConfig? get config => _config;

  void setConfig(TimecodeMonitorConfig? config) {
    _config = config;
    notifyListeners();
  }

  void clearConfig() {
    _config = null;
    notifyListeners();
  }
}

void main() {
  runApp(const TentacleSyncCaptureApp());
}

class TentacleSyncCaptureApp extends StatefulWidget {
  const TentacleSyncCaptureApp({super.key});

  @override
  State<TentacleSyncCaptureApp> createState() => _TentacleSyncCaptureAppState();
}

class _TentacleSyncCaptureAppState extends State<TentacleSyncCaptureApp> {
  late final AppDatabase _database;
  late final BleService _bleService;
  late final SessionManager _sessionManager;

  @override
  void initState() {
    super.initState();
    _database = AppDatabase();
    _bleService = BleService();
    _sessionManager = SessionManager(
      database: _database,
      bleService: _bleService,
    );
  }

  @override
  void dispose() {
    _sessionManager.dispose();
    _database.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AppDatabase>.value(value: _database),
        Provider<BleService>.value(value: _bleService),
        ChangeNotifierProvider<SessionManagerNotifier>(
          create: (_) => SessionManagerNotifier(_sessionManager),
        ),
        ChangeNotifierProvider<MonitorConfigNotifier>(
          create: (_) => MonitorConfigNotifier(),
        ),
      ],
      child: MaterialApp(
        title: 'Tentacle Sync Capture',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.deepPurple,
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        home: MainNavigationScreen(key: mainNavigationKey),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

class SessionManagerNotifier extends ChangeNotifier {
  final SessionManager sessionManager;

  SessionManagerNotifier(this.sessionManager) {
    sessionManager.sessionStream.listen((_) => notifyListeners());
    sessionManager.statsStream.listen((_) => notifyListeners());
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => MainNavigationScreenState();
}

class MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;

  /// Switch to the monitor tab (index 1)
  void switchToMonitorTab() {
    setState(() {
      _selectedIndex = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Watch the monitor config to pass to the LiveMonitorScreen
    final monitorConfig = context.watch<MonitorConfigNotifier>().config;

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          const ScanScreen(),
          LiveMonitorScreen(monitorConfig: monitorConfig),
          const SessionsScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.bluetooth_searching),
            selectedIcon: Icon(Icons.bluetooth_connected),
            label: 'Scan',
          ),
          NavigationDestination(
            icon: Icon(Icons.timer_outlined),
            selectedIcon: Icon(Icons.timer),
            label: 'Monitor',
          ),
          NavigationDestination(
            icon: Icon(Icons.history),
            selectedIcon: Icon(Icons.history),
            label: 'Sessions',
          ),
        ],
      ),
    );
  }
}
