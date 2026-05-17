const fs = require('fs');
let code = fs.readFileSync('c:/Users/Anurag/meetra_app/lib/main.dart', 'utf8');

// 1. Fix .toString() on mapped IDs in _fetchRequestedIds
code = code.replace(
    `_requestedRushInIds = (response as List).map((e) => e['target_id']).toList();`,
    `_requestedRushInIds = (response as List).map((e) => e['target_id'].toString()).toList();`
);
code = code.replace(
    `_approvedRushInIds = (response as List).where((e) => e['status'] == 'approved').map((e) => e['target_id']).toList();`,
    `_approvedRushInIds = (response as List).where((e) => e['status'] == 'approved').map((e) => e['target_id'].toString()).toList();`
);

// 2. Fix the filter in liveActs to not strip out requested items IF they are approved
code = code.replace(
    `if (_requestedRushInIds.contains(act['id'].toString())) return false;`,
    `if (_requestedRushInIds.contains(act['id'].toString()) && !_approvedRushInIds.contains(act['id'].toString())) return false;`
);

fs.writeFileSync('c:/Users/Anurag/meetra_app/lib/main.dart', code, 'utf8');
console.log('Fixed approved mapping logic!');
