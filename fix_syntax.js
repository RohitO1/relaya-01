const fs = require('fs');
let code = fs.readFileSync('c:/Users/Anurag/meetra_app/lib/main.dart', 'utf8');

const replacementStr = `  void _startLocationTracking() {
    // Already tracking - just re-center the map
    if (_myLocation != null && _watchId != null) {
      _mapController.move(_myLocation!, 15.0);
      return;
    }
    setState(() => _isFetchingLocation = true);

    final options = js.JsObject.jsify({
      'enableHighAccuracy': true,
      'maximumAge': 0,
      'timeout': 10000,
    });

    bool firstFix = true;
    _watchId = js.context['navigator']['geolocation'].callMethod('watchPosition', [
      (position) {
        final lat     = (position['coords']['latitude']  as num).toDouble();
        final lng     = (position['coords']['longitude'] as num).toDouble();
        // heading is null or NaN when device is stationary
        final rawHead = position['coords']['heading'];
        double? heading;
        if (rawHead != null) {
          final h = (rawHead as num).toDouble();
          if (!h.isNaN) heading = h;
        }
        setState(() {
          _isFetchingLocation = false;
          _myLocation = LatLng(lat, lng);
          if (heading != null) _myHeading = heading;
        });
        // Only fly to location on first fix
        if (firstFix) {
          firstFix = false;
          _mapController.move(LatLng(lat, lng), 15.0);
        }
      },
      (error) {
        setState(() => _isFetchingLocation = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permission denied or unavailable.')),
        );
      },
      options,
    ]) as int?;
  }

  Future<void> _submitJoinRequest(Map<String, dynamic> act) async {
    try {
      final uid = Supabase.instance.client.auth.currentUser!.id;
      final existing = await Supabase.instance.client
          .from('requests')
          .select()
          .eq('sender_id', uid)
          .eq('target_id', act['id'])
          .maybeSingle();

      if (existing != null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You already requested to join!'), backgroundColor: Colors.amber));
        return;
      }

      await Supabase.instance.client.from('requests').insert({
        'sender_id': uid,
        'target_id': act['id'],
        'target_type': 'activity',
        'status': 'pending',
        'message': 'I want to join your Rush-In!'
      });

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Join Request Sent! ⚡'), backgroundColor: Color(0xFF00E5FF)));
      Navigator.pop(context); // Close bottom sheet
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red));
    }
  }`;

let start = code.indexOf('void _startLocationTracking() {');
let end = code.indexOf('void _openDetailView(Map<String, dynamic> act) {', start);

if (start !== -1 && end !== -1) {
    let newCode = code.substring(0, start) + replacementStr + '\n\n  ' + code.substring(end);
    fs.writeFileSync('c:/Users/Anurag/meetra_app/lib/main.dart', newCode, 'utf8');
    console.log('Fixed syntax error!');
} else {
    console.log('Could not find bounds to fix error.', start, end);
}
