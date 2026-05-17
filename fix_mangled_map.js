const fs = require('fs');
let code = fs.readFileSync('c:/Users/Anurag/meetra_app/lib/main.dart', 'utf8');

// The replacement tool mangled this section:
// We need to find the stray `      child: ClipRRect(` where _buildMapView used to be and replace it with the proper `_buildMapView` declaration, while also deleting that stray duplicate named argument further down. Wait, we can just replace the whole section from `Widget _buildListView` down to `Widget _buildFlutterMap` to be safe, because the user hasn't made other edits.

// What did the replacement tool do?
// It replaced:
//     );
//   }
// 
//   Widget _buildMapView(List<Map<String, dynamic>> liveActivities) {
//     return ...
//       child: ClipRRect(
//         borderRadius: BorderRadius.circular(25),
//         child: Stack(

// With:
//     );
//   }
// 
//       child: ClipRRect(
//         borderRadius: BorderRadius.circular(25),
//         child: Stack(

const mangledCode = `              child: const Icon(Icons.add, color: Colors.white, size: 28),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(25),
        child: Stack(
          children: [`;

const fixedCode = `              child: const Icon(Icons.add, color: Colors.white, size: 28),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMapView(List<Map<String, dynamic>> liveActivities) {
    return Container(
      key: const ValueKey('map_view'),
      margin: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 90),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.5)),
        boxShadow: [BoxShadow(color: const Color(0xFF00E5FF).withOpacity(0.2), blurRadius: 20)],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(25),
        child: Stack(
          children: [`;


if (code.includes(mangledCode)) {
    code = code.replace(mangledCode, fixedCode);
    console.log('Repaired _buildMapView definition!');
} else {
    // If exact whitespace match fails, let's use indexOf bounds.
    let searchIconAdd = code.indexOf('child: const Icon(Icons.add, color: Colors.white, size: 28),');
    let clipRRectStart = code.indexOf('      child: ClipRRect(', searchIconAdd);
    let childrenStack = code.indexOf('          children: [', clipRRectStart);
    
    if (searchIconAdd !== -1 && clipRRectStart !== -1 && childrenStack !== -1 && clipRRectStart - searchIconAdd < 200) {
        let before = code.substring(0, searchIconAdd + 'child: const Icon(Icons.add, color: Colors.white, size: 28),'.length);
        let after = code.substring(childrenStack);
        
        let bridge = `
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMapView(List<Map<String, dynamic>> liveActivities) {
    return Container(
      key: const ValueKey('map_view'),
      margin: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 90),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.5)),
        boxShadow: [BoxShadow(color: const Color(0xFF00E5FF).withOpacity(0.2), blurRadius: 20)],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(25),
        child: Stack(
`;
        code = before + bridge + after;
        console.log('Repaired _buildMapView bounds via indexOf!');
    } else {
        console.log('Could not find the mangled block to repair.');
    }
}

// NOW, fix the user's actual request: Removing the explicit hard-block on Rush-Ins natively plotting on the map natively inside _buildFlutterMap
const targetFilterStr = `.where((act) => act['is_rush_in'] != true)`;
if (code.includes(targetFilterStr)) {
   code = code.replace(targetFilterStr, ``);
   console.log('Successfully removed .where hard filter in _buildFlutterMap');
}

fs.writeFileSync('c:/Users/Anurag/meetra_app/lib/main.dart', code, 'utf8');
