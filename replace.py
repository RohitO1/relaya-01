import re

with open('lib/chatroom_live_screen.dart', 'r', encoding='utf-8') as f:
    text = f.read()

# 1. Imports
text = text.replace("import 'package:livekit_client/livekit_client.dart';", "import 'package:agora_rtc_engine/agora_rtc_engine.dart';")

# 2. State vars
text = text.replace("Room? _livekitRoom;", "RtcEngine? _engine;")
text = text.replace("EventsListener<RoomEvent>? _roomListener;", "")

# 3. Disconnect
text = text.replace("await _livekitRoom?.disconnect();", "await _engine?.leaveChannel();\n    await _engine?.release();")

with open('lib/chatroom_live_screen.dart', 'w', encoding='utf-8') as f:
    f.write(text)
