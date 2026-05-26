import 'dart:io';

void main() {
  final file = File('lib/spark_screen.dart');
  var c = file.readAsStringSync();

  final start = c.indexOf('MarkerLayer(');
  if (start == -1) {
    print('MarkerLayer not found');
    return;
  }
  
  // Find matching closing parenthesis
  int depth = 0;
  int end = -1;
  for (int i = start; i < c.length; i++) {
    if (c[i] == '(') depth++;
    if (c[i] == ')') {
      depth--;
      if (depth == 0) {
        end = i + 1;
        break;
      }
    }
  }

  if (end == -1) {
    print('End not found');
    return;
  }

  final newStr = '''MarkerLayer(
                  markers: [
                    // User's Live Location Marker
                    if (locationService.activeLat != null && locationService.activeLng != null)
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
                      ),
                    
                    // Spark Activities & Rush-ins
                    ...sparkDataStore.values.map((v) => Marker(
                      point: LatLng(v.lat, v.lng), 
                      width: 50, height: 60,
                      alignment: Alignment.topCenter, // Points EXACTLY at the location
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
                              const Icon(Icons.arrow_drop_down, color: Color(0xFF10B981), size: 24),
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
                                    gradient: const LinearGradient(colors: [SparkColors.orange, SparkColors.pink]),
                                    border: Border.all(color: Colors.white, width: 2),
                                    boxShadow: const [BoxShadow(color: SparkColors.orange, blurRadius: 10)],
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
                                    boxShadow: const [BoxShadow(color: SparkColors.actPrimary, blurRadius: 10)],
                                  ),
                                  child: const Icon(Icons.calendar_today, color: Colors.white, size: 16),
                                ).animate().fadeIn(),
                                const Icon(Icons.arrow_drop_down, color: SparkColors.actPrimary, size: 24),
                              ],
                            ),
                      ),
                    )),
                  ],
                )''';

  c = c.substring(0, start) + newStr + c.substring(end);
  file.writeAsStringSync(c);
  print('Success!');
}
