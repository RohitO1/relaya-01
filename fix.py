import os

path = 'c:/Users/Anurag/meetra_app/lib/main.dart'

with open(path, 'r', encoding='utf-8') as f:
    text = f.read()

text = text.replace(
    "if (currentUid != null && act['user_id'].toString() == currentUid) return false;",
    "// if (currentUid != null && act['user_id'].toString() == currentUid) return false;"
)

text = text.replace(
    "child: Center(child: Text('No Live Rush-Ins nearby right now.', style: TextStyle(color: Colors.white54))),",
    "child: Center(child: Text('No events or Rush-Ins nearby right now.', style: TextStyle(color: Colors.white54))),"
)

with open(path, 'w', encoding='utf-8') as f:
    f.write(text)

print("done")
