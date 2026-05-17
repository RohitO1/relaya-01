const fs = require('fs');
let code = fs.readFileSync('c:/Users/Anurag/meetra_app/lib/main.dart', 'utf8');

// 1. Add state variable
if (!code.includes('Map<String, dynamic>? _selectedMapActivity;')) {
    code = code.replace(
        `bool _showLayerPicker = false;`,
        `bool _showLayerPicker = false;\n  Map<String, dynamic>? _selectedMapActivity;`
    );
}

// 2. Add the popup UI method
if (!code.includes('_buildMapPopupCard')) {
    const popupCardCode = `  Widget _buildMapPopupCard(Map<String, dynamic> act) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 220,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF65666A),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 5))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundImage: NetworkImage('https://picsum.photos/seed/\${act['user_id']}/100'),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(act['host_name'] ?? ('User ' + (act['user_id']?.toString().substring(0, 4) ?? '')), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
                            const Text('is hosting', style: TextStyle(color: Colors.white60, fontSize: 11)),
                          ],
                        ),
                      )
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text((act['category'] ?? 'EVENT').toUpperCase(), style: const TextStyle(color: Color(0xFFFF4081), fontWeight: FontWeight.bold, fontSize: 11)),
                  const SizedBox(height: 8),
                  Text(act['hook'] ?? act['title'] ?? 'Anyone up a musical war.', style: const TextStyle(color: Colors.white70, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 16),
                  Center(
                    child: GestureDetector(
                      onTap: () => _openDetailView(act),
                      child: const Text('View Details', style: TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                  )
                ],
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: () => setState(() => _selectedMapActivity = null),
                child: const Icon(Icons.close, color: Colors.white30, size: 16),
              ),
            )
          ],
        ),
        CustomPaint(
          size: const Size(16, 12),
          painter: _TrianglePainter(color: const Color(0xFF65666A)),
        )
      ],
    );
  }

`;
    code = code.replace(
        `Widget _buildMapLiveCard(Map<String, dynamic> act) {`,
        popupCardCode + `  Widget _buildMapLiveCard(Map<String, dynamic> act) {`
    );
}

// 3. Update _buildFlutterMap
code = code.replace(
    `    final locationMarkers = _myLocation != null`,
    `    final popupMarkers = _selectedMapActivity != null
        ? [
            Marker(
              point: LatLng(
                _selectedMapActivity!['lat'] as double? ?? _selectedMapActivity!['latitude'] as double? ?? 40.7128,
                _selectedMapActivity!['lng'] as double? ?? _selectedMapActivity!['longitude'] as double? ?? -74.0060,
              ),
              width: 250,
              height: 250,
              alignment: Alignment.topCenter,
              child: _buildMapPopupCard(_selectedMapActivity!),
            )
          ]
        : <Marker>[];

    final locationMarkers = _myLocation != null`
);

code = code.replace(
    `MarkerLayer(markers: [...activityMarkers, ...locationMarkers]),`,
    `MarkerLayer(markers: [...activityMarkers, ...locationMarkers, ...popupMarkers]),`
);

// 4. MapOptions onTap
code = code.replace(
    `options: MapOptions(`,
    `options: MapOptions(
                                  onTap: (_, __) => setState(() => _selectedMapActivity = null),`
);

// 5. Update _buildActivityMarker to support pinpoint and onTap
code = code.replace(
    `onTap: () => _openDetailView(act),`,
    `onTap: () {
          setState(() { _selectedMapActivity = act; });
          _mapController.move(LatLng(lat, lng), 15.0);
        },`
);

code = code.replace(
    `: _StandardActivityMarker(color: accent, icon: Icons.event, userId: act['user_id']?.toString()),`,
    `: _StandardActivityMarker(color: const Color(0xFF101015), icon: Icons.maps_ugc_rounded, userId: null),`
);


fs.writeFileSync('c:/Users/Anurag/meetra_app/lib/main.dart', code, 'utf8');
console.log('Script ran successfully!');
