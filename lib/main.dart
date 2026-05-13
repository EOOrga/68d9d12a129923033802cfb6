import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const bool kScreenshotMode = bool.fromEnvironment('SCREENSHOT_MODE');

const Color _brandBlue = Color(0xFF2B3D58);
const Color _brandNavy = Color(0xFF25344B);
const Color _brandGold = Color(0xFFC79A49);
const Color _brandGreen = Color(0xFF2E7D62);
const Color _pageBackground = Color(0xFFF4F7FA);

void main() {
  runApp(
    PelletierRogerApp(store: OperationsStore(screenshotMode: kScreenshotMode)),
  );
}

class PelletierRogerApp extends StatelessWidget {
  const PelletierRogerApp({super.key, required this.store});

  final OperationsStore store;

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _brandBlue,
      brightness: Brightness.light,
      primary: _brandBlue,
      secondary: _brandGold,
      tertiary: _brandGreen,
      surface: Colors.white,
    );

    return MaterialApp(
      title: 'PELLETIER ROGER',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme,
        scaffoldBackgroundColor: _pageBackground,
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          backgroundColor: _brandNavy,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: Color(0xFFE0E7EF)),
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: Colors.white,
          indicatorColor: _brandGold.withValues(alpha: 0.22),
          labelTextStyle: WidgetStateProperty.resolveWith(
            (states) => TextStyle(
              fontSize: 12,
              fontWeight: states.contains(WidgetState.selected)
                  ? FontWeight.w700
                  : FontWeight.w500,
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          filled: true,
          fillColor: const Color(0xFFF9FBFD),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
      home: OperationsHome(store: store),
    );
  }
}

class OperationsStore extends ChangeNotifier {
  OperationsStore({required this.screenshotMode}) {
    if (screenshotMode) {
      _seedScreenshotData();
      _loaded = true;
    }
  }

  static const _checkoutsKey = 'checkouts';
  static const _ordersKey = 'orders';
  static const _containersKey = 'containers';
  static const _reportsKey = 'reports';
  static const _settingsKey = 'settings';

  final bool screenshotMode;
  bool _loaded = false;

  List<EquipmentCheckout> _checkouts = <EquipmentCheckout>[];
  List<WorkOrder> _orders = <WorkOrder>[];
  List<ContainerRecord> _containers = <ContainerRecord>[];
  List<ComplianceReport> _reports = <ComplianceReport>[];
  OperationsSettings _settings = const OperationsSettings(
    defaultSite: 'Main yard',
    shiftLead: 'Operations desk',
    priorityMarkers: true,
  );

  bool get isLoaded => _loaded;
  List<EquipmentCheckout> get checkouts => List.unmodifiable(_checkouts);
  List<WorkOrder> get orders => List.unmodifiable(_orders);
  List<ContainerRecord> get containers => List.unmodifiable(_containers);
  List<ComplianceReport> get reports => List.unmodifiable(_reports);
  OperationsSettings get settings => _settings;

  int get openOrderCount =>
      _orders.where((order) => order.status != 'Closed').length;
  int get activeCheckoutCount =>
      _checkouts.where((checkout) => checkout.status != 'Returned').length;
  int get containerInTransitCount =>
      _containers.where((container) => container.status == 'In transit').length;
  int get unresolvedComplianceCount =>
      _reports.where((report) => report.result != 'Resolved').length;

  Future<void> load() async {
    if (_loaded) {
      return;
    }
    if (screenshotMode) {
      _seedScreenshotData();
      _loaded = true;
      notifyListeners();
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    _checkouts = _decodeList(
      prefs.getString(_checkoutsKey),
      EquipmentCheckout.fromJson,
    );
    _orders = _decodeList(prefs.getString(_ordersKey), WorkOrder.fromJson);
    _containers = _decodeList(
      prefs.getString(_containersKey),
      ContainerRecord.fromJson,
    );
    _reports = _decodeList(
      prefs.getString(_reportsKey),
      ComplianceReport.fromJson,
    );
    _settings = OperationsSettings.fromJson(
      _decodeMap(prefs.getString(_settingsKey)),
    );
    _loaded = true;
    notifyListeners();
  }

  Future<void> addCheckout({
    required String equipment,
    required String operatorName,
    required String site,
    required String dueBy,
    required String notes,
  }) async {
    _checkouts.insert(
      0,
      EquipmentCheckout(
        id: _nextId('eq'),
        equipment: equipment,
        operatorName: operatorName,
        site: site,
        dueBy: dueBy,
        status: 'Checked out',
        notes: notes,
      ),
    );
    await _commit();
  }

  Future<void> markReturned(String id) async {
    _checkouts = _checkouts
        .map(
          (checkout) => checkout.id == id
              ? checkout.copyWith(status: 'Returned')
              : checkout,
        )
        .toList();
    await _commit();
  }

  Future<void> addOrder({
    required String title,
    required String area,
    required String priority,
    required String notes,
  }) async {
    _orders.insert(
      0,
      WorkOrder(
        id: _nextId('wo'),
        title: title,
        area: area,
        priority: priority,
        status: 'Open',
        openedAt: _todayLabel(),
        notes: notes,
      ),
    );
    await _commit();
  }

  Future<void> closeOrder(String id) async {
    _orders = _orders
        .map(
          (order) => order.id == id ? order.copyWith(status: 'Closed') : order,
        )
        .toList();
    await _commit();
  }

  Future<void> addContainer({
    required String containerId,
    required String route,
    required String seal,
    required String eta,
  }) async {
    _containers.insert(
      0,
      ContainerRecord(
        id: containerId,
        route: route,
        status: 'Queued',
        seal: seal,
        eta: eta,
        lastCheck: _todayLabel(),
      ),
    );
    await _commit();
  }

  Future<void> advanceContainer(String id) async {
    _containers = _containers.map((container) {
      if (container.id != id) {
        return container;
      }
      final next = switch (container.status) {
        'Queued' => 'Loaded',
        'Loaded' => 'In transit',
        'In transit' => 'Arrived',
        'Arrived' => 'Released',
        _ => 'Queued',
      };
      return container.copyWith(status: next, lastCheck: _todayLabel());
    }).toList();
    await _commit();
  }

  Future<void> addReport({
    required String title,
    required String area,
    required String result,
    required int findingCount,
  }) async {
    _reports.insert(
      0,
      ComplianceReport(
        id: _nextId('cr'),
        title: title,
        area: area,
        result: result,
        reportedAt: _todayLabel(),
        findingCount: findingCount,
      ),
    );
    await _commit();
  }

  Future<void> resolveReport(String id) async {
    _reports = _reports
        .map(
          (report) =>
              report.id == id ? report.copyWith(result: 'Resolved') : report,
        )
        .toList();
    await _commit();
  }

  Future<void> updateSettings(OperationsSettings settings) async {
    _settings = settings;
    await _commit();
  }

  Future<void> _commit() async {
    notifyListeners();
    if (screenshotMode) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _checkoutsKey,
      jsonEncode(_checkouts.map((item) => item.toJson()).toList()),
    );
    await prefs.setString(
      _ordersKey,
      jsonEncode(_orders.map((item) => item.toJson()).toList()),
    );
    await prefs.setString(
      _containersKey,
      jsonEncode(_containers.map((item) => item.toJson()).toList()),
    );
    await prefs.setString(
      _reportsKey,
      jsonEncode(_reports.map((item) => item.toJson()).toList()),
    );
    await prefs.setString(_settingsKey, jsonEncode(_settings.toJson()));
  }

  void _seedScreenshotData() {
    _settings = const OperationsSettings(
      defaultSite: 'South yard',
      shiftLead: 'Roger desk',
      priorityMarkers: true,
    );
    _checkouts = <EquipmentCheckout>[
      EquipmentCheckout(
        id: 'eq-310',
        equipment: 'Telehandler TH-42',
        operatorName: 'M. Laurent',
        site: 'South yard',
        dueBy: '18:00 today',
        status: 'Checked out',
        notes: 'Fork inspection completed before handoff.',
      ),
      EquipmentCheckout(
        id: 'eq-287',
        equipment: 'Generator GEN-18',
        operatorName: 'A. Martin',
        site: 'Dock 4',
        dueBy: '08:30 tomorrow',
        status: 'Reserved',
        notes: 'Fuel card stored with yard desk.',
      ),
      EquipmentCheckout(
        id: 'eq-219',
        equipment: 'Scanner kit SK-09',
        operatorName: 'Night receiving',
        site: 'Gatehouse',
        dueBy: 'Returned',
        status: 'Returned',
        notes: 'Battery pack returned at 92 percent.',
      ),
    ];
    _orders = <WorkOrder>[
      WorkOrder(
        id: 'wo-1458',
        title: 'Repair dock leveler sensor',
        area: 'Dock 2',
        priority: 'High',
        status: 'Open',
        openedAt: 'Today',
        notes: 'Sensor reads clear while container is parked.',
      ),
      WorkOrder(
        id: 'wo-1454',
        title: 'Replace aisle markers',
        area: 'Warehouse B',
        priority: 'Medium',
        status: 'Scheduled',
        openedAt: 'Yesterday',
        notes: 'Use reflective markers on freezer approach.',
      ),
      WorkOrder(
        id: 'wo-1449',
        title: 'Inspect compressor vibration',
        area: 'Utility room',
        priority: 'Critical',
        status: 'Open',
        openedAt: 'May 10',
        notes: 'Escalate if reading remains above threshold.',
      ),
    ];
    _containers = <ContainerRecord>[
      ContainerRecord(
        id: 'PRCU-482019',
        route: 'Le Havre to North yard',
        status: 'In transit',
        seal: 'S-78442',
        eta: '16:45 today',
        lastCheck: '12:20 today',
      ),
      ContainerRecord(
        id: 'PRCU-481774',
        route: 'Dock 4 to overflow',
        status: 'Loaded',
        seal: 'S-78211',
        eta: '09:15 tomorrow',
        lastCheck: '08:00 today',
      ),
      ContainerRecord(
        id: 'PRCU-481502',
        route: 'Inspection lane to release',
        status: 'Arrived',
        seal: 'S-77905',
        eta: 'Ready',
        lastCheck: 'Yesterday',
      ),
    ];
    _reports = <ComplianceReport>[
      ComplianceReport(
        id: 'cr-902',
        title: 'Forklift pre-use checklist',
        area: 'South yard',
        result: 'Passed',
        reportedAt: 'Today',
        findingCount: 0,
      ),
      ComplianceReport(
        id: 'cr-897',
        title: 'Spill station audit',
        area: 'Dock 1',
        result: 'Action needed',
        reportedAt: 'Yesterday',
        findingCount: 2,
      ),
      ComplianceReport(
        id: 'cr-889',
        title: 'Container seal review',
        area: 'Gatehouse',
        result: 'Resolved',
        reportedAt: 'May 9',
        findingCount: 1,
      ),
    ];
  }

  static List<T> _decodeList<T>(
    String? source,
    T Function(Map<String, Object?> json) fromJson,
  ) {
    if (source == null || source.isEmpty) {
      return <T>[];
    }
    try {
      final decoded = jsonDecode(source);
      if (decoded is! List) {
        return <T>[];
      }
      return decoded
          .whereType<Map>()
          .map((item) => fromJson(item.cast<String, Object?>()))
          .toList();
    } on FormatException {
      return <T>[];
    }
  }

  static Map<String, Object?> _decodeMap(String? source) {
    if (source == null || source.isEmpty) {
      return const <String, Object?>{};
    }
    try {
      final decoded = jsonDecode(source);
      if (decoded is Map) {
        return decoded.cast<String, Object?>();
      }
    } on FormatException {
      return const <String, Object?>{};
    }
    return const <String, Object?>{};
  }

  static String _nextId(String prefix) =>
      '$prefix-${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';

  static String _todayLabel() {
    final now = DateTime.now();
    return '${now.month}/${now.day}/${now.year}';
  }
}

class EquipmentCheckout {
  const EquipmentCheckout({
    required this.id,
    required this.equipment,
    required this.operatorName,
    required this.site,
    required this.dueBy,
    required this.status,
    required this.notes,
  });

  final String id;
  final String equipment;
  final String operatorName;
  final String site;
  final String dueBy;
  final String status;
  final String notes;

  EquipmentCheckout copyWith({String? status}) => EquipmentCheckout(
    id: id,
    equipment: equipment,
    operatorName: operatorName,
    site: site,
    dueBy: dueBy,
    status: status ?? this.status,
    notes: notes,
  );

  factory EquipmentCheckout.fromJson(Map<String, Object?> json) =>
      EquipmentCheckout(
        id: json['id'] as String? ?? '',
        equipment: json['equipment'] as String? ?? '',
        operatorName: json['operatorName'] as String? ?? '',
        site: json['site'] as String? ?? '',
        dueBy: json['dueBy'] as String? ?? '',
        status: json['status'] as String? ?? 'Checked out',
        notes: json['notes'] as String? ?? '',
      );

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'equipment': equipment,
    'operatorName': operatorName,
    'site': site,
    'dueBy': dueBy,
    'status': status,
    'notes': notes,
  };
}

class WorkOrder {
  const WorkOrder({
    required this.id,
    required this.title,
    required this.area,
    required this.priority,
    required this.status,
    required this.openedAt,
    required this.notes,
  });

  final String id;
  final String title;
  final String area;
  final String priority;
  final String status;
  final String openedAt;
  final String notes;

  WorkOrder copyWith({String? status}) => WorkOrder(
    id: id,
    title: title,
    area: area,
    priority: priority,
    status: status ?? this.status,
    openedAt: openedAt,
    notes: notes,
  );

  factory WorkOrder.fromJson(Map<String, Object?> json) => WorkOrder(
    id: json['id'] as String? ?? '',
    title: json['title'] as String? ?? '',
    area: json['area'] as String? ?? '',
    priority: json['priority'] as String? ?? 'Medium',
    status: json['status'] as String? ?? 'Open',
    openedAt: json['openedAt'] as String? ?? '',
    notes: json['notes'] as String? ?? '',
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'title': title,
    'area': area,
    'priority': priority,
    'status': status,
    'openedAt': openedAt,
    'notes': notes,
  };
}

class ContainerRecord {
  const ContainerRecord({
    required this.id,
    required this.route,
    required this.status,
    required this.seal,
    required this.eta,
    required this.lastCheck,
  });

  final String id;
  final String route;
  final String status;
  final String seal;
  final String eta;
  final String lastCheck;

  ContainerRecord copyWith({String? status, String? lastCheck}) =>
      ContainerRecord(
        id: id,
        route: route,
        status: status ?? this.status,
        seal: seal,
        eta: eta,
        lastCheck: lastCheck ?? this.lastCheck,
      );

  factory ContainerRecord.fromJson(Map<String, Object?> json) =>
      ContainerRecord(
        id: json['id'] as String? ?? '',
        route: json['route'] as String? ?? '',
        status: json['status'] as String? ?? 'Queued',
        seal: json['seal'] as String? ?? '',
        eta: json['eta'] as String? ?? '',
        lastCheck: json['lastCheck'] as String? ?? '',
      );

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'route': route,
    'status': status,
    'seal': seal,
    'eta': eta,
    'lastCheck': lastCheck,
  };
}

class ComplianceReport {
  const ComplianceReport({
    required this.id,
    required this.title,
    required this.area,
    required this.result,
    required this.reportedAt,
    required this.findingCount,
  });

  final String id;
  final String title;
  final String area;
  final String result;
  final String reportedAt;
  final int findingCount;

  ComplianceReport copyWith({String? result}) => ComplianceReport(
    id: id,
    title: title,
    area: area,
    result: result ?? this.result,
    reportedAt: reportedAt,
    findingCount: findingCount,
  );

  factory ComplianceReport.fromJson(Map<String, Object?> json) =>
      ComplianceReport(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? '',
        area: json['area'] as String? ?? '',
        result: json['result'] as String? ?? 'Passed',
        reportedAt: json['reportedAt'] as String? ?? '',
        findingCount: (json['findingCount'] as num?)?.toInt() ?? 0,
      );

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'title': title,
    'area': area,
    'result': result,
    'reportedAt': reportedAt,
    'findingCount': findingCount,
  };
}

class OperationsSettings {
  const OperationsSettings({
    required this.defaultSite,
    required this.shiftLead,
    required this.priorityMarkers,
  });

  final String defaultSite;
  final String shiftLead;
  final bool priorityMarkers;

  OperationsSettings copyWith({
    String? defaultSite,
    String? shiftLead,
    bool? priorityMarkers,
  }) => OperationsSettings(
    defaultSite: defaultSite ?? this.defaultSite,
    shiftLead: shiftLead ?? this.shiftLead,
    priorityMarkers: priorityMarkers ?? this.priorityMarkers,
  );

  factory OperationsSettings.fromJson(Map<String, Object?> json) =>
      OperationsSettings(
        defaultSite: json['defaultSite'] as String? ?? 'Main yard',
        shiftLead: json['shiftLead'] as String? ?? 'Operations desk',
        priorityMarkers: json['priorityMarkers'] as bool? ?? true,
      );

  Map<String, Object?> toJson() => <String, Object?>{
    'defaultSite': defaultSite,
    'shiftLead': shiftLead,
    'priorityMarkers': priorityMarkers,
  };
}

class OperationsHome extends StatefulWidget {
  const OperationsHome({super.key, required this.store});

  final OperationsStore store;

  @override
  State<OperationsHome> createState() => _OperationsHomeState();
}

class _OperationsHomeState extends State<OperationsHome> {
  int _index = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    widget.store.addListener(_refresh);
    _loading = !widget.store.isLoaded;
    widget.store.load().then((_) {
      if (mounted) {
        setState(() => _loading = false);
      }
    });
  }

  @override
  void dispose() {
    widget.store.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      DashboardScreen(
        store: widget.store,
        onSelectTab: (index) => setState(() => _index = index),
      ),
      EquipmentScreen(store: widget.store),
      WorkOrdersScreen(store: widget.store),
      ContainersScreen(store: widget.store),
      ComplianceScreen(store: widget.store),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_index]),
        actions: [
          IconButton(
            key: const Key('settingsButton'),
            tooltip: 'Settings',
            onPressed: () => _showSettings(context),
            icon: const Icon(Icons.tune),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(child: pages[_index]),
      floatingActionButton: _buildFab(context),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) => setState(() => _index = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.space_dashboard_outlined),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            label: 'Equipment',
          ),
          NavigationDestination(
            icon: Icon(Icons.assignment_outlined),
            label: 'Orders',
          ),
          NavigationDestination(
            icon: Icon(Icons.local_shipping_outlined),
            label: 'Containers',
          ),
          NavigationDestination(
            icon: Icon(Icons.fact_check_outlined),
            label: 'Reports',
          ),
        ],
      ),
    );
  }

  static const _titles = <String>[
    'PELLETIER ROGER',
    'Equipment checkout',
    'Work orders',
    'Container tracking',
    'Compliance reports',
  ];

  Widget? _buildFab(BuildContext context) {
    return switch (_index) {
      1 => FloatingActionButton.extended(
        key: const Key('newCheckoutFab'),
        onPressed: () => _showCheckoutSheet(context),
        icon: const Icon(Icons.add),
        label: const Text('New checkout'),
      ),
      2 => FloatingActionButton.extended(
        key: const Key('newOrderFab'),
        onPressed: () => _showOrderSheet(context),
        icon: const Icon(Icons.add_task),
        label: const Text('New order'),
      ),
      3 => FloatingActionButton.extended(
        key: const Key('newContainerFab'),
        onPressed: () => _showContainerSheet(context),
        icon: const Icon(Icons.add_location_alt_outlined),
        label: const Text('Track container'),
      ),
      4 => FloatingActionButton.extended(
        key: const Key('newReportFab'),
        onPressed: () => _showReportSheet(context),
        icon: const Icon(Icons.post_add),
        label: const Text('New report'),
      ),
      _ => null,
    };
  }

  void _showSettings(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => SettingsSheet(store: widget.store),
    );
  }

  void _showCheckoutSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => CheckoutSheet(store: widget.store),
    );
  }

  void _showOrderSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => OrderSheet(store: widget.store),
    );
  }

  void _showContainerSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => ContainerSheet(store: widget.store),
    );
  }

  void _showReportSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => ReportSheet(store: widget.store),
    );
  }
}

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({
    super.key,
    required this.store,
    required this.onSelectTab,
  });

  final OperationsStore store;
  final ValueChanged<int> onSelectTab;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: _brandNavy,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Operations desk',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white70,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Daily control for equipment, orders, compliance, and containers.',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _InfoPill(
                    icon: Icons.place_outlined,
                    text: store.settings.defaultSite,
                  ),
                  _InfoPill(
                    icon: Icons.person_outline,
                    text: store.settings.shiftLead,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final cardWidth = (constraints.maxWidth - 12) / 2;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                MetricCard(
                  width: cardWidth,
                  icon: Icons.inventory_2_outlined,
                  value: '${store.activeCheckoutCount}',
                  label: 'Active checkouts',
                  color: _brandBlue,
                ),
                MetricCard(
                  width: cardWidth,
                  icon: Icons.assignment_outlined,
                  value: '${store.openOrderCount}',
                  label: 'Open work orders',
                  color: const Color(0xFF8A5A12),
                ),
                MetricCard(
                  width: cardWidth,
                  icon: Icons.local_shipping_outlined,
                  value: '${store.containerInTransitCount}',
                  label: 'Containers moving',
                  color: _brandGreen,
                ),
                MetricCard(
                  width: cardWidth,
                  icon: Icons.fact_check_outlined,
                  value: '${store.unresolvedComplianceCount}',
                  label: 'Compliance items',
                  color: const Color(0xFF9C3D3D),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 20),
        const SectionTitle(title: 'Focus queue'),
        const SizedBox(height: 8),
        ActionCard(
          icon: Icons.priority_high,
          title: store.orders.isEmpty
              ? 'No open work'
              : store.orders.first.title,
          subtitle: store.orders.isEmpty
              ? 'Create a work order when maintenance needs attention.'
              : '${store.orders.first.area} - ${store.orders.first.priority} priority',
          actionLabel: 'View orders',
          onPressed: () => onSelectTab(2),
        ),
        const SizedBox(height: 10),
        ActionCard(
          icon: Icons.qr_code_2_outlined,
          title: store.containers.isEmpty
              ? 'No containers tracked'
              : store.containers.first.id,
          subtitle: store.containers.isEmpty
              ? 'Track container route, seal, status, and next handoff.'
              : '${store.containers.first.status} - ${store.containers.first.eta}',
          actionLabel: 'View containers',
          onPressed: () => onSelectTab(3),
        ),
      ],
    );
  }
}

class EquipmentScreen extends StatelessWidget {
  const EquipmentScreen({super.key, required this.store});

  final OperationsStore store;

  @override
  Widget build(BuildContext context) {
    if (store.checkouts.isEmpty) {
      return const EmptyState(
        icon: Icons.inventory_2_outlined,
        title: 'No equipment checked out',
        message:
            'Use New checkout to assign equipment to an operator and site.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      itemCount: store.checkouts.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final checkout = store.checkouts[index];
        return OperationCard(
          leading: Icons.inventory_2_outlined,
          title: checkout.equipment,
          subtitle: '${checkout.operatorName} - ${checkout.site}',
          meta: 'Due: ${checkout.dueBy}',
          status: checkout.status,
          statusColor: checkout.status == 'Returned' ? _brandGreen : _brandBlue,
          trailing: checkout.status == 'Returned'
              ? null
              : TextButton(
                  onPressed: () => store.markReturned(checkout.id),
                  child: const Text('Return'),
                ),
          onTap: () => showRecordSheet(
            context,
            title: checkout.equipment,
            rows: {
              'Operator': checkout.operatorName,
              'Site': checkout.site,
              'Due': checkout.dueBy,
              'Status': checkout.status,
              'Notes': checkout.notes,
            },
          ),
        );
      },
    );
  }
}

class WorkOrdersScreen extends StatelessWidget {
  const WorkOrdersScreen({super.key, required this.store});

  final OperationsStore store;

  @override
  Widget build(BuildContext context) {
    if (store.orders.isEmpty) {
      return const EmptyState(
        icon: Icons.assignment_outlined,
        title: 'No work orders',
        message: 'Use New order to capture repair tasks and handoffs.',
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        const SectionTitle(title: 'Open and scheduled'),
        const SizedBox(height: 8),
        ...store.orders.map(
          (order) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: OperationCard(
              leading: Icons.assignment_outlined,
              title: order.title,
              subtitle: '${order.area} - opened ${order.openedAt}',
              meta: order.notes,
              status: '${order.priority} / ${order.status}',
              statusColor: _priorityColor(order.priority),
              trailing: order.status == 'Closed'
                  ? null
                  : TextButton(
                      onPressed: () => store.closeOrder(order.id),
                      child: const Text('Close'),
                    ),
              onTap: () => showRecordSheet(
                context,
                title: order.title,
                rows: {
                  'Area': order.area,
                  'Priority': order.priority,
                  'Status': order.status,
                  'Opened': order.openedAt,
                  'Notes': order.notes,
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  static Color _priorityColor(String priority) => switch (priority) {
    'Critical' => const Color(0xFF9C3D3D),
    'High' => const Color(0xFF8A5A12),
    'Medium' => _brandBlue,
    _ => _brandGreen,
  };
}

class ContainersScreen extends StatelessWidget {
  const ContainersScreen({super.key, required this.store});

  final OperationsStore store;

  @override
  Widget build(BuildContext context) {
    if (store.containers.isEmpty) {
      return const EmptyState(
        icon: Icons.local_shipping_outlined,
        title: 'No containers tracked',
        message: 'Use Track container to log route, seal, status, and ETA.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      itemCount: store.containers.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final container = store.containers[index];
        return OperationCard(
          leading: Icons.local_shipping_outlined,
          title: container.id,
          subtitle: container.route,
          meta: 'Seal ${container.seal} - ETA ${container.eta}',
          status: container.status,
          statusColor: container.status == 'Released'
              ? _brandGreen
              : _brandBlue,
          trailing: TextButton(
            onPressed: () => store.advanceContainer(container.id),
            child: const Text('Advance'),
          ),
          onTap: () => showRecordSheet(
            context,
            title: container.id,
            rows: {
              'Route': container.route,
              'Status': container.status,
              'Seal': container.seal,
              'ETA': container.eta,
              'Last check': container.lastCheck,
            },
          ),
        );
      },
    );
  }
}

class ComplianceScreen extends StatelessWidget {
  const ComplianceScreen({super.key, required this.store});

  final OperationsStore store;

  @override
  Widget build(BuildContext context) {
    if (store.reports.isEmpty) {
      return const EmptyState(
        icon: Icons.fact_check_outlined,
        title: 'No compliance reports',
        message: 'Use New report to record checklist results and findings.',
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        const SectionTitle(title: 'Recent reports'),
        const SizedBox(height: 8),
        ...store.reports.map(
          (report) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: OperationCard(
              leading: Icons.fact_check_outlined,
              title: report.title,
              subtitle: '${report.area} - ${report.reportedAt}',
              meta:
                  '${report.findingCount} finding${report.findingCount == 1 ? '' : 's'}',
              status: report.result,
              statusColor: report.result == 'Action needed'
                  ? const Color(0xFF9C3D3D)
                  : report.result == 'Resolved'
                  ? _brandGreen
                  : _brandBlue,
              trailing: report.result == 'Resolved'
                  ? null
                  : TextButton(
                      onPressed: () => store.resolveReport(report.id),
                      child: const Text('Resolve'),
                    ),
              onTap: () => showRecordSheet(
                context,
                title: report.title,
                rows: {
                  'Area': report.area,
                  'Result': report.result,
                  'Reported': report.reportedAt,
                  'Findings': '${report.findingCount}',
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.width,
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  final double width;
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: 118,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color),
              const Spacer(),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class OperationCard extends StatelessWidget {
  const OperationCard({
    super.key,
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.meta,
    required this.status,
    required this.statusColor,
    this.trailing,
    this.onTap,
  });

  final IconData leading;
  final String title;
  final String subtitle;
  final String meta;
  final String status;
  final Color statusColor;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(leading, color: statusColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  ?trailing,
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      meta,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF53606F),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  StatusPill(label: status, color: statusColor),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ActionCard extends StatelessWidget {
  const ActionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: _brandGold.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: const Color(0xFF8A5A12)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            TextButton(onPressed: onPressed, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 132),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: _brandBlue),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            text,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class CheckoutSheet extends StatefulWidget {
  const CheckoutSheet({super.key, required this.store});

  final OperationsStore store;

  @override
  State<CheckoutSheet> createState() => _CheckoutSheetState();
}

class _CheckoutSheetState extends State<CheckoutSheet> {
  late final TextEditingController _equipment;
  late final TextEditingController _operator;
  late final TextEditingController _site;
  late final TextEditingController _due;
  late final TextEditingController _notes;

  @override
  void initState() {
    super.initState();
    _equipment = TextEditingController(
      text: kScreenshotMode ? 'Lift truck LT-12' : '',
    );
    _operator = TextEditingController(text: kScreenshotMode ? 'C. Moreau' : '');
    _site = TextEditingController(text: widget.store.settings.defaultSite);
    _due = TextEditingController(text: kScreenshotMode ? '17:30 today' : '');
    _notes = TextEditingController(
      text: kScreenshotMode ? 'Battery checked before dispatch.' : '',
    );
  }

  @override
  void dispose() {
    _equipment.dispose();
    _operator.dispose();
    _site.dispose();
    _due.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FormShell(
      title: 'New equipment checkout',
      saveLabel: 'Save checkout',
      onSave: () async {
        await widget.store.addCheckout(
          equipment: _equipment.text.trim(),
          operatorName: _operator.text.trim(),
          site: _site.text.trim(),
          dueBy: _due.text.trim(),
          notes: _notes.text.trim(),
        );
        if (context.mounted) {
          Navigator.pop(context);
        }
      },
      children: [
        TextField(
          key: const Key('equipmentField'),
          controller: _equipment,
          decoration: const InputDecoration(labelText: 'Equipment'),
        ),
        TextField(
          controller: _operator,
          decoration: const InputDecoration(labelText: 'Operator'),
        ),
        TextField(
          controller: _site,
          decoration: const InputDecoration(labelText: 'Site'),
        ),
        TextField(
          controller: _due,
          decoration: const InputDecoration(labelText: 'Due back'),
        ),
        TextField(
          controller: _notes,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(labelText: 'Notes'),
        ),
      ],
    );
  }
}

class OrderSheet extends StatefulWidget {
  const OrderSheet({super.key, required this.store});

  final OperationsStore store;

  @override
  State<OrderSheet> createState() => _OrderSheetState();
}

class _OrderSheetState extends State<OrderSheet> {
  late final TextEditingController _title;
  late final TextEditingController _area;
  late final TextEditingController _notes;
  String _priority = 'High';

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(
      text: kScreenshotMode ? 'Inspect yard lighting' : '',
    );
    _area = TextEditingController(text: widget.store.settings.defaultSite);
    _notes = TextEditingController(
      text: kScreenshotMode ? 'North row flickers after 20:00.' : '',
    );
  }

  @override
  void dispose() {
    _title.dispose();
    _area.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FormShell(
      title: 'New work order',
      saveLabel: 'Save order',
      onSave: () async {
        await widget.store.addOrder(
          title: _title.text.trim(),
          area: _area.text.trim(),
          priority: _priority,
          notes: _notes.text.trim(),
        );
        if (context.mounted) {
          Navigator.pop(context);
        }
      },
      children: [
        TextField(
          key: const Key('orderTitleField'),
          controller: _title,
          decoration: const InputDecoration(labelText: 'Work order title'),
        ),
        TextField(
          key: const Key('orderAreaField'),
          controller: _area,
          decoration: const InputDecoration(labelText: 'Area'),
        ),
        DropdownButtonFormField<String>(
          initialValue: _priority,
          decoration: const InputDecoration(labelText: 'Priority'),
          items: const ['Critical', 'High', 'Medium', 'Low']
              .map(
                (priority) =>
                    DropdownMenuItem(value: priority, child: Text(priority)),
              )
              .toList(),
          onChanged: (value) => setState(() => _priority = value ?? _priority),
        ),
        TextField(
          key: const Key('orderNotesField'),
          controller: _notes,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(labelText: 'Notes'),
        ),
      ],
    );
  }
}

class ContainerSheet extends StatefulWidget {
  const ContainerSheet({super.key, required this.store});

  final OperationsStore store;

  @override
  State<ContainerSheet> createState() => _ContainerSheetState();
}

class _ContainerSheetState extends State<ContainerSheet> {
  late final TextEditingController _id;
  late final TextEditingController _route;
  late final TextEditingController _seal;
  late final TextEditingController _eta;

  @override
  void initState() {
    super.initState();
    _id = TextEditingController(text: kScreenshotMode ? 'PRCU-482155' : '');
    _route = TextEditingController(
      text: kScreenshotMode ? 'Gatehouse to dock 3' : '',
    );
    _seal = TextEditingController(text: kScreenshotMode ? 'S-78504' : '');
    _eta = TextEditingController(text: kScreenshotMode ? '14:10 today' : '');
  }

  @override
  void dispose() {
    _id.dispose();
    _route.dispose();
    _seal.dispose();
    _eta.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FormShell(
      title: 'Track container',
      saveLabel: 'Save container',
      onSave: () async {
        await widget.store.addContainer(
          containerId: _id.text.trim(),
          route: _route.text.trim(),
          seal: _seal.text.trim(),
          eta: _eta.text.trim(),
        );
        if (context.mounted) {
          Navigator.pop(context);
        }
      },
      children: [
        TextField(
          controller: _id,
          decoration: const InputDecoration(labelText: 'Container ID'),
        ),
        TextField(
          controller: _route,
          decoration: const InputDecoration(labelText: 'Route'),
        ),
        TextField(
          controller: _seal,
          decoration: const InputDecoration(labelText: 'Seal'),
        ),
        TextField(
          controller: _eta,
          decoration: const InputDecoration(labelText: 'ETA'),
        ),
      ],
    );
  }
}

class ReportSheet extends StatefulWidget {
  const ReportSheet({super.key, required this.store});

  final OperationsStore store;

  @override
  State<ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<ReportSheet> {
  late final TextEditingController _title;
  late final TextEditingController _area;
  late final TextEditingController _findings;
  String _result = 'Passed';

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(
      text: kScreenshotMode ? 'PPE station review' : '',
    );
    _area = TextEditingController(text: widget.store.settings.defaultSite);
    _findings = TextEditingController(text: kScreenshotMode ? '0' : '');
  }

  @override
  void dispose() {
    _title.dispose();
    _area.dispose();
    _findings.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FormShell(
      title: 'New compliance report',
      saveLabel: 'Save report',
      onSave: () async {
        await widget.store.addReport(
          title: _title.text.trim(),
          area: _area.text.trim(),
          result: _result,
          findingCount: int.tryParse(_findings.text.trim()) ?? 0,
        );
        if (context.mounted) {
          Navigator.pop(context);
        }
      },
      children: [
        TextField(
          controller: _title,
          decoration: const InputDecoration(labelText: 'Checklist or report'),
        ),
        TextField(
          controller: _area,
          decoration: const InputDecoration(labelText: 'Area'),
        ),
        DropdownButtonFormField<String>(
          initialValue: _result,
          decoration: const InputDecoration(labelText: 'Result'),
          items: const ['Passed', 'Action needed', 'Resolved']
              .map(
                (result) =>
                    DropdownMenuItem(value: result, child: Text(result)),
              )
              .toList(),
          onChanged: (value) => setState(() => _result = value ?? _result),
        ),
        TextField(
          controller: _findings,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Finding count'),
        ),
      ],
    );
  }
}

class SettingsSheet extends StatefulWidget {
  const SettingsSheet({super.key, required this.store});

  final OperationsStore store;

  @override
  State<SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<SettingsSheet> {
  late final TextEditingController _site;
  late final TextEditingController _lead;
  late bool _priorityMarkers;

  @override
  void initState() {
    super.initState();
    _site = TextEditingController(text: widget.store.settings.defaultSite);
    _lead = TextEditingController(text: widget.store.settings.shiftLead);
    _priorityMarkers = widget.store.settings.priorityMarkers;
  }

  @override
  void dispose() {
    _site.dispose();
    _lead.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FormShell(
      title: 'Settings and privacy',
      saveLabel: 'Save settings',
      onSave: () async {
        await widget.store.updateSettings(
          OperationsSettings(
            defaultSite: _site.text.trim(),
            shiftLead: _lead.text.trim(),
            priorityMarkers: _priorityMarkers,
          ),
        );
        if (context.mounted) {
          Navigator.pop(context);
        }
      },
      children: [
        TextField(
          key: const Key('defaultSiteField'),
          controller: _site,
          decoration: const InputDecoration(labelText: 'Default site'),
        ),
        TextField(
          controller: _lead,
          decoration: const InputDecoration(labelText: 'Shift lead label'),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Highlight priority work'),
          subtitle: const Text('Stored only on this device.'),
          value: _priorityMarkers,
          onChanged: (value) => setState(() => _priorityMarkers = value),
        ),
        const Divider(height: 24),
        const ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.lock_outline),
          title: Text('Local records only'),
          subtitle: Text(
            'No accounts, cloud sync, analytics, or network features.',
          ),
        ),
        const ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.support_agent),
          title: Text('Support'),
          subtitle: Text('support@pelletierroger.com'),
        ),
      ],
    );
  }
}

class FormShell extends StatelessWidget {
  const FormShell({
    super.key,
    required this.title,
    required this.saveLabel,
    required this.onSave,
    required this.children,
  });

  final String title;
  final String saveLabel;
  final Future<void> Function() onSave;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...children.expand((child) => [child, const SizedBox(height: 12)]),
            FilledButton(onPressed: onSave, child: Text(saveLabel)),
          ],
        ),
      ),
    );
  }
}

void showRecordSheet(
  BuildContext context, {
  required String title,
  required Map<String, String> rows,
}) {
  showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    builder: (context) => Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              IconButton(
                tooltip: 'Close',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...rows.entries.map(
            (entry) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 92,
                    child: Text(
                      entry.key,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: const Color(0xFF53606F),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      entry.value,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}
