import 'dart:io';

void main() {
  final file = File('lib/spark_screen.dart');
  var c = file.readAsStringSync();

  // 1. Default to map view
  c = c.replaceFirst('String _activeView = \'list\';', 'String _activeView = \'map\';');

  // 2. Add realtime subscription
  final stateStart = c.indexOf('class _SparkScreenState extends State<SparkScreen> with TickerProviderStateMixin {');
  if (stateStart > -1) {
    // Insert RealtimeChannel? _activitiesSub; right after
    final insIdx = c.indexOf('\n', stateStart) + 1;
    c = c.substring(0, insIdx) + '  RealtimeChannel? _activitiesSub;\n' + c.substring(insIdx);
  }

  // Update initState
  final initStart = c.indexOf('void initState() {');
  if (initStart > -1) {
    final initEnd = c.indexOf('}', initStart);
    final initBody = c.substring(initStart, initEnd);
    if (!initBody.contains('_activitiesSub =')) {
      final newInitBody = initBody + '''
    _activitiesSub = Supabase.instance.client.channel('public:activities')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'activities',
        callback: (payload) {
          _fetchActivities();
        }
      ).subscribe();
''';
      c = c.replaceFirst(initBody, newInitBody);
    }
  }

  // Update dispose
  final disposeStart = c.indexOf('void dispose() {');
  if (disposeStart > -1) {
    final disposeEnd = c.indexOf('}', disposeStart);
    final disposeBody = c.substring(disposeStart, disposeEnd);
    if (!disposeBody.contains('_activitiesSub?.unsubscribe()')) {
      final newDisposeBody = disposeBody.replaceFirst('super.dispose();', '  _activitiesSub?.unsubscribe();\n    super.dispose();');
      c = c.replaceFirst(disposeBody, newDisposeBody);
    }
  }

  // 3. Update Map Markers
  // User Marker
  final userMarkerOld = '''                    if (locationService.activeLat != null && locationService.activeLng != null)
                      Marker(
                        point: LatLng(locationService.activeLat!, locationService.activeLng!),
                        width: 50, height: 50,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: SparkColors.red.withValues(alpha: 0.2),
                            border: Border.all(color: SparkColors.red.withValues(alpha: 0.6), width: 2),
                          ),
                          child: Center(
                            child: Container(
                              width: 16, height: 16,
                              decoration: const BoxDecoration(color: SparkColors.red, shape: BoxShape.circle),
                            ),
                          ),
                        ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(begin: const Offset(0.8, 0.8), end: const Offset(1.2, 1.2)),
                      ),''';
  
  final userMarkerNew = '''                    if (locationService.activeLat != null && locationService.activeLng != null)
                      Marker(
                        point: LatLng(locationService.activeLat!, locationService.activeLng!),
                        width: 60, height: 60,
                        alignment: Alignment.center,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 60, height: 60,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: SparkColors.blue.withValues(alpha: 0.2),
                              ),
                            ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(begin: const Offset(0.5, 0.5), end: const Offset(1.0, 1.0)).fade(end: 0),
                            Container(
                              width: 24, height: 24,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: SparkColors.blue,
                                border: Border.all(color: Colors.white, width: 3),
                                boxShadow: [BoxShadow(color: SparkColors.blue.withValues(alpha: 0.5), blurRadius: 10)],
                              ),
                              child: const Icon(Icons.person, color: Colors.white, size: 14),
                            ),
                          ],
                        ),
                      ),''';

  if (c.contains(userMarkerOld)) {
    c = c.replaceFirst(userMarkerOld, userMarkerNew);
  } else {
    print("Warning: old user marker not found");
  }

  // Activity/Rush Markers
  final itemMarkersOld = '''                    ...sparkDataStore.values.map((v) => Marker(
                      point: LatLng(v.lat, v.lng), 
                      width: 44, height: 44,
                      child: GestureDetector(
                        onTap: () {
                          final parent = context.findAncestorStateOfType<_SparkScreenState>();
                          if (parent != null) parent._showDetailSheet(v);
                        },
                        child: v.isApproved
                        ? Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(colors: [Color(0xFF34D399), Color(0xFF059669)]), // Emerald Neon
                              border: Border.all(color: Colors.white, width: 2.5),
                              boxShadow: const [BoxShadow(color: Color(0xFF10B981), blurRadius: 15, spreadRadius: 3)],
                            ),
                            alignment: Alignment.center,
                            child: Icon(v.type == 'rush' ? Icons.flash_on : Icons.check, color: Colors.white, size: 18),
                          ).animate(onPlay: (c)=>c.repeat(reverse: true)).scale(end: const Offset(1.2, 1.2))
                        : v.type == 'rush' 
                          ? Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(colors: [SparkColors.yellow, SparkColors.orange]),
                                border: Border.all(color: SparkColors.yellow.withValues(alpha: 0.6), width: 3),
                                boxShadow: [BoxShadow(color: SparkColors.yellow.withValues(alpha: 0.3), blurRadius: 10, spreadRadius: 2)],
                              ),
                              alignment: Alignment.center,
                              child: const Text('?', style: TextStyle(fontSize: 18)),
                            ).animate(onPlay: (c)=>c.repeat(reverse: true)).scale(end: const Offset(1.15, 1.15))
                          : Container(
                              alignment: Alignment.topCenter,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: const LinearGradient(colors: [SparkColors.actPrimary, SparkColors.actSecondary]),
                                      border: Border.all(color: Colors.white, width: 2),
                                      boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 4, offset: Offset(0, 2))],
                                    ),
                                    child: const Icon(Icons.location_on, color: Colors.white, size: 14),
                                  ),
                                ],
                              ),
                            ).animate().fadeIn(),
                      ),
                    )),''';

  final itemMarkersNew = '''                    ...sparkDataStore.values.map((v) => Marker(
                      point: LatLng(v.lat, v.lng), 
                      width: 50, height: 60,
                      alignment: Alignment.topCenter, // Pointing tip at location
                      child: GestureDetector(
                        onTap: () {
                          final parent = context.findAncestorStateOfType<_SparkScreenState>();
                          if (parent != null) parent._showDetailSheet(v);
                        },
                        child: v.isApproved
                        ? Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 36, height: 36,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: const LinearGradient(colors: [Color(0xFF34D399), Color(0xFF059669)]),
                                  border: Border.all(color: Colors.white, width: 2.5),
                                  boxShadow: const [BoxShadow(color: Color(0xFF10B981), blurRadius: 10)],
                                ),
                                child: const Icon(Icons.check, color: Colors.white, size: 18),
                              ).animate(onPlay: (c)=>c.repeat(reverse: true)).scale(end: const Offset(1.1, 1.1)),
                              Icon(Icons.arrow_drop_down, color: const Color(0xFF10B981), size: 24),
                            ],
                          )
                        : v.type == 'rush' 
                          ? Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 40, height: 40,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: const LinearGradient(colors: [SparkColors.yellow, SparkColors.orange]),
                                    border: Border.all(color: Colors.white, width: 2),
                                    boxShadow: [BoxShadow(color: SparkColors.orange, blurRadius: 10)],
                                  ),
                                  child: const Center(child: Text('?', style: TextStyle(fontSize: 18))),
                                ).animate(onPlay: (c)=>c.repeat(reverse: true)).shimmer(duration: 2.seconds),
                                const Icon(Icons.arrow_drop_down, color: SparkColors.orange, size: 24),
                              ],
                            )
                          : Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 40, height: 40,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: const LinearGradient(colors: [SparkColors.actPrimary, SparkColors.actSecondary]),
                                    border: Border.all(color: Colors.white, width: 2),
                                    boxShadow: [BoxShadow(color: SparkColors.actPrimary, blurRadius: 10)],
                                  ),
                                  child: const Icon(Icons.calendar_today, color: Colors.white, size: 16),
                                ).animate().fadeIn(),
                                const Icon(Icons.arrow_drop_down, color: SparkColors.actPrimary, size: 24),
                              ],
                            ),
                      ),
                    )),''';

  if (c.contains(itemMarkersOld)) {
    c = c.replaceFirst(itemMarkersOld, itemMarkersNew);
  } else {
    print("Warning: old item markers not found");
    
    // Find the marker layer dynamically if replace failed
    final markerLayerStart = c.indexOf('MarkerLayer(');
    if (markerLayerStart > -1) {
      print("Found MarkerLayer, attempting manual replacement");
    }
  }

  // Update Legend to reflect new icons and colors
  c = c.replaceFirst("_legendItem(SparkColors.red, 'Rush-in')", "_legendItem(SparkColors.orange, 'Rush-in')");
  // Blue already 'You', actPrimary already 'Activity'. 

  file.writeAsStringSync(c);
  print('Done spark_screen.dart modifications.');
}
