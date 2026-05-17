const fs = require('fs');
let code = fs.readFileSync('c:/Users/Anurag/meetra_app/lib/main.dart', 'utf8');

const importRegex = /import 'rush_in_consumer_detail_view\.dart';/;
if (importRegex.test(code)) {
    code = code.replace(importRegex, "import 'rush_in_consumer_detail_view.dart';\nimport 'admin_dashboard_screen.dart';");
    console.log('Added import.');
} else {
    console.log('Import regex not found.');
}

const logoutHook = "              const SizedBox(height: 100),";
if (code.includes(logoutHook)) {
    const adminBtn = `              const SizedBox(height: 16),
              GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminDashboardScreen())),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  decoration: BoxDecoration(
                    color: Colors.orangeAccent.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.orangeAccent.withOpacity(0.3)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.admin_panel_settings, color: Colors.orangeAccent, size: 20),
                      SizedBox(width: 10),
                      Text('Admin Access', style: TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 100),`;
    code = code.replace(logoutHook, adminBtn);
    console.log('Added admin button.');
} else {
    console.log('Logout hook not found.');
}

fs.writeFileSync('c:/Users/Anurag/meetra_app/lib/main.dart', code, 'utf8');
