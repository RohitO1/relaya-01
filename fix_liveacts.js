const fs = require('fs');
let code = fs.readFileSync('c:/Users/Anurag/meetra_app/lib/main.dart', 'utf8');

// Check if Rush-In filter already exists
if (code.includes("Rush-Ins belong ONLY to the Rush-In Live section")) {
  console.log('Filter already applied!');
  process.exit(0);
}

// Find the liveActs filter by locating the unique comment nearby
const marker = "// Filter out non-RushIns and expired ones";
const idx = code.indexOf(marker);
if (idx === -1) {
  console.log('Could not find marker comment');
  process.exit(1);
}

// Find the start of "final liveActs = acts.where"
const liveActsStart = code.indexOf("final liveActs = acts.where", idx);
// Find the end: ".toList();" after that
const toListEnd = code.indexOf(".toList();", liveActsStart) + ".toList();".length;

const before = code.substring(0, liveActsStart);
const after = code.substring(toListEnd);

const newFilter = `final liveActs = acts.where((act) {
                      if (act['is_active'] != true) return false;
                      // Rush-Ins belong ONLY to the Rush-In Live section
                      if (act['is_rush_in'] == true) return false;
                      // Prevent seeing hidden items
                      if (_hiddenRushIns.contains(act['id'].toString())) return false;
                      // Prevent seeing already-requested items
                      if (_requestedRushInIds.contains(act['id'].toString())) return false;
                      return true;
                    }).toList();`;

fs.writeFileSync('c:/Users/Anurag/meetra_app/lib/main.dart', before + newFilter + after, 'utf8');
console.log('Successfully injected Rush-In exclusion filter into liveActs block.');
