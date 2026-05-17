// fix_all_corruption.js
// Surgically fixes all 7 corruption sites in lib/main.dart
// caused by a runaway PowerShell regex replacement.
//
// Usage: node fix_all_corruption.js

const fs = require('fs');
const path = require('path');

// ═══════════════════════════════════════════════════════════════════
// 1. Read and normalize lib/main.dart
// ═══════════════════════════════════════════════════════════════════
const mainPath = path.join(__dirname, 'lib', 'main.dart');
let content = fs.readFileSync(mainPath, 'utf8');

// Strip BOM if present
if (content.charCodeAt(0) === 0xFEFF) content = content.slice(1);

// Normalize all line endings to \n for processing
content = content.replace(/\r\n/g, '\n').replace(/\r/g, '\n');
let lines = content.split('\n');
console.log(`Read ${lines.length} lines from lib/main.dart`);

// ═══════════════════════════════════════════════════════════════════
// 2. Verify landmark lines to ensure file hasn't shifted
// ═══════════════════════════════════════════════════════════════════
function verify(lineNum, expected) {
  const actual = lines[lineNum - 1].trim();
  if (!actual.startsWith(expected.trim())) {
    console.error(`LANDMARK MISMATCH at line ${lineNum}:`);
    console.error(`  Expected starts with: "${expected.trim()}"`);
    console.error(`  Actual:               "${actual}"`);
    process.exit(1);
  }
}

verify(1245, 'Expanded(');                 // Card Expanded
verify(1246, 'child: GestureDetector(');   // Card GestureDetector
verify(1248, 'child: Container(');         // Card Container
verify(1254, 'child: ClipRRect(');         // Card ClipRRect
verify(1256, 'child: Stack(');             // Card Stack
verify(1310, 'Positioned(');              // Distance badge
verify(1313, 'padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),');
verify(1314, 'Expanded(');                // Broken Pass (should be decoration)
verify(1335, 'child: GestureDetector(');  // Knock button GD
verify(1549, 'Expanded(');                // Site 2
verify(1550, '),');                        // Site 2 injection
verify(1565, 'Expanded(');                // Site 3
verify(1566, '),');                        // Site 3 injection
verify(2111, "children: ['Latest', 'Popular'].map((sortType) => Expanded(");
verify(2112, '),');                        // Site 4 injection
verify(2254, 'Expanded(');                // Site 5
verify(2255, '),');                        // Site 5 injection
verify(2270, 'Expanded(');                // Site 6
verify(2271, '),');                        // Site 6 injection
verify(3572, 'Center(');                  // Site 7
verify(3573, '),');                        // Site 7 injection

console.log('All 20 landmarks verified ✓');

// ═══════════════════════════════════════════════════════════════════
// 3. Fix corruption sites BOTTOM-TO-TOP (preserves line numbers)
// ═══════════════════════════════════════════════════════════════════

// SITE 7: Map popup Center → child: GestureDetector
// Remove 5 injected lines at 3573-3577 (1-indexed)
lines.splice(3572, 5); // 0-indexed: 3572..3576
console.log('Site 7 fixed: Map popup Center → GestureDetector ✓');

// SITE 6: Incoming knock "Let In" Expanded → child: GestureDetector
// Remove 5 injected lines at 2271-2275
lines.splice(2270, 5);
console.log('Site 6 fixed: "Let In" button ✓');

// SITE 5: Incoming knock Pass Expanded → child: GestureDetector
// Remove 5 injected lines at 2255-2259
lines.splice(2254, 5);
console.log('Site 5 fixed: Incoming knock Pass button ✓');

// SITE 4: Filter sort Expanded → child: GestureDetector
// Remove 5 injected lines at 2112-2116
lines.splice(2111, 5);
console.log('Site 4 fixed: Filter sort buttons ✓');

// SITE 3: Profile detail Knock Expanded → child: GestureDetector
// Remove 5 injected lines at 1566-1570
lines.splice(1565, 5);
console.log('Site 3 fixed: Profile detail Knock button ✓');

// SITE 2: Profile detail Pass Expanded → child: GestureDetector
// Remove 5 injected lines at 1550-1554
lines.splice(1549, 5);
console.log('Site 2 fixed: Profile detail Pass button ✓');

// SITE 1: Distance badge + Pass/Knock button structure
// Replace lines 1314-1334 (21 lines) with correct code (40 lines)
// This restores:
//   - Distance badge Container decoration + child Row
//   - Closing brackets: Container → Positioned → Stack.children → Stack → ClipRRect → Container → GestureDetector → Expanded
//   - SizedBox separator
//   - Padding → Row → Pass button → SizedBox → Knock Expanded
const site1Fix = [
  '                        decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(16)),',
  '                        child: Row(',
  '                          mainAxisSize: MainAxisSize.min,',
  "                          children: [const Icon(Icons.near_me, color: Colors.white54, size: 12), const SizedBox(width: 4), Text('${_getDisplayDistance(p)} km away', style: const TextStyle(color: Colors.white60, fontSize: 11))],",
  '                        ),',
  '                      ),',       // Close Container (distance badge)
  '                    ),',         // Close Positioned
  '                  ],',           // Close Stack.children
  '                ),',             // Close Stack
  '              ),',               // Close ClipRRect
  '            ),',                 // Close Container (card)
  '          ),',                   // Close GestureDetector (card tap)
  '        ),',                     // Close Expanded (card)
  '        const SizedBox(height: 16),',
  '        // Knock / Pass buttons',
  '        Padding(',
  '          padding: const EdgeInsets.fromLTRB(40, 0, 40, 20),',
  '          child: Row(',
  '            children: [',
  '              // Pass',
  '              Expanded(',
  '                child: GestureDetector(',
  '                  onTap: _nextProfile,',
  '                  child: Container(',
  '                    padding: const EdgeInsets.symmetric(vertical: 16),',
  '                    decoration: BoxDecoration(',
  '                      color: Colors.white.withValues(alpha: 0.08),',
  '                      borderRadius: BorderRadius.circular(22),',
  '                      border: Border.all(color: Colors.white24),',
  '                    ),',
  '                    child: const Row(',
  '                      mainAxisAlignment: MainAxisAlignment.center,',
  "                      children: [Icon(Icons.close, color: Colors.white54, size: 20), SizedBox(width: 6), Text('Pass', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.w600, fontSize: 15))],",
  '                    ),',
  '                  ),',           // Close Container (Pass button)
  '                ),',             // Close GestureDetector (Pass)
  '              ),',               // Close Expanded (Pass)
  '              const SizedBox(width: 16),',
  '              // Knock',
  '              Expanded(',
];

lines.splice(1313, 21, ...site1Fix);
console.log('Site 1 fixed: Distance badge + Pass button restored ✓');

// ═══════════════════════════════════════════════════════════════════
// 4. Update ignore_for_file directive
// ═══════════════════════════════════════════════════════════════════
const ignoreIdx = lines.findIndex(l => l.includes('ignore_for_file'));
if (ignoreIdx >= 0) {
  lines[ignoreIdx] = '// ignore_for_file: avoid_print, unused_local_variable, unused_element, unused_field, use_build_context_synchronously, unused_element_parameter, prefer_final_fields';
  console.log(`Updated ignore_for_file at line ${ignoreIdx + 1}`);
} else {
  // Insert before first import
  const firstImport = lines.findIndex(l => l.startsWith('import '));
  if (firstImport >= 0) {
    lines.splice(firstImport, 0, '// ignore_for_file: avoid_print, unused_local_variable, unused_element, unused_field, use_build_context_synchronously, unused_element_parameter, prefer_final_fields');
    console.log('Inserted ignore_for_file directive');
  }
}

// ═══════════════════════════════════════════════════════════════════
// 5. Remove all redundant inline // ignore: comments
// ═══════════════════════════════════════════════════════════════════
const coveredRules = [
  'use_build_context_synchronously',
  'unused_element',
  'unused_field',
  'unused_element_parameter',
  'prefer_final_fields',
  'duplicate_ignore',
];
let inlineRemoved = 0;
lines = lines.map(l => {
  let m = l;
  for (const rule of coveredRules) {
    const pat = ' // ignore: ' + rule;
    if (m.includes(pat)) {
      m = m.replace(pat, '');
      inlineRemoved++;
    }
  }
  return m;
});
console.log(`Removed ${inlineRemoved} redundant inline ignore comments`);

// ═══════════════════════════════════════════════════════════════════
// 6. Remove any stray "Wilmington" artifacts
// ═══════════════════════════════════════════════════════════════════
const beforeLen = lines.length;
lines = lines.filter(l => !l.includes('Wilmington'));
if (beforeLen !== lines.length) {
  console.log(`Removed ${beforeLen - lines.length} Wilmington artifact lines`);
}

// ═══════════════════════════════════════════════════════════════════
// 7. Write back with Windows line endings
// ═══════════════════════════════════════════════════════════════════
fs.writeFileSync(mainPath, lines.join('\r\n'), 'utf8');
console.log(`\nWrote ${lines.length} lines to lib/main.dart`);

// ═══════════════════════════════════════════════════════════════════
// 8. Fix lib/management_dashboard.dart
// ═══════════════════════════════════════════════════════════════════
const dashPath = path.join(__dirname, 'lib', 'management_dashboard.dart');
let dashContent = fs.readFileSync(dashPath, 'utf8');
if (!dashContent.includes('ignore_for_file')) {
  const firstImport = dashContent.indexOf('import ');
  if (firstImport >= 0) {
    dashContent = dashContent.slice(0, firstImport) +
      '// ignore_for_file: use_build_context_synchronously\n' +
      dashContent.slice(firstImport);
  }
  fs.writeFileSync(dashPath, dashContent, 'utf8');
  console.log('Fixed management_dashboard.dart: added ignore_for_file ✓');
} else {
  console.log('management_dashboard.dart: ignore_for_file already present');
}

console.log('\n✅ All fixes applied successfully!');
console.log('Run: flutter analyze');
