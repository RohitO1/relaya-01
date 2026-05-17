const fs = require('fs');
let code = fs.readFileSync('c:/Users/Anurag/meetra_app/lib/main.dart', 'utf8');

const targetImport = `import 'rush_in_consumer_detail_view.dart';`;
const newImport = targetImport + '\n' + `import 'admin_dashboard_screen.dart';`;
code = code.replace(targetImport, newImport);

const targetBtn = `                    ),
                  ),`;
const newBtn = `                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminDashboardScreen())),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.orangeAccent.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.orangeAccent.withOpacity(0.4)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.admin_panel_settings, color: Colors.orangeAccent, size: 14),
                          SizedBox(width: 6),
                          Text('Admin', style: TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                        ],
                      ),
                    ),
                  ),`;

let index = code.lastIndexOf(targetBtn);
if(index !== -1) {
   code = code.substring(0, index) + newBtn + code.substring(index + targetBtn.length);
   fs.writeFileSync('c:/Users/Anurag/meetra_app/lib/main.dart', code, 'utf8');
   console.log('Successfully injected Admin Panel to main.dart');
} else {
   console.log('Could not find targetBtn');
}
