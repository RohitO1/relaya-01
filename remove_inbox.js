const fs = require('fs');
let code = fs.readFileSync('c:/Users/Anurag/meetra_app/lib/main.dart', 'utf8');

let startIndex = code.indexOf("const Text('Recent Inbox'");
if (startIndex > -1) {
    let startCut = code.lastIndexOf("const SizedBox(height: 30)", startIndex);
    let endCut = code.indexOf("GestureDetector(", startIndex);
    
    if (startCut > -1 && endCut > -1) {
        let before = code.substring(0, startCut);
        let after = code.substring(endCut);
        fs.writeFileSync('c:/Users/Anurag/meetra_app/lib/main.dart', before + after, 'utf8');
        console.log('Cut successful.');
    } else {
        console.log('Found string but not bounds.', startCut, endCut);
    }
} else {
    console.log('Could not find string');
}
