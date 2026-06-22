import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import 'bolroom_config.dart';
import 'services/doodle_theme.dart';

class VirtualMeetScreen extends StatefulWidget {
  final String peerName;
  final String channelId;

  const VirtualMeetScreen({super.key, required this.peerName, required this.channelId});

  @override
  State<VirtualMeetScreen> createState() => _VirtualMeetScreenState();
}

class _VirtualMeetScreenState extends State<VirtualMeetScreen> {
  late RtcEngine _engine;
  bool _localUserJoined = false;
  int? _remoteUid;
  bool _muted = false;
  bool _videoDisabled = false;

  @override
  void initState() {
    super.initState();
    _initAgora();
  }

  Future<void> _initAgora() async {
    await [Permission.microphone, Permission.camera].request();

    _engine = createAgoraRtcEngine();
    await _engine.initialize(const RtcEngineContext(
      appId: BolRoomConfig.agoraAppId,
      channelProfile: ChannelProfileType.channelProfileCommunication,
    ));

    _engine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          setState(() => _localUserJoined = true);
        },
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          setState(() => _remoteUid = remoteUid);
        },
        onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
          setState(() => _remoteUid = null);
        },
      ),
    );

    await _engine.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
    await _engine.enableVideo();
    await _engine.startPreview();

    await _engine.joinChannel(
      token: '', // using empty token for testing, production needs a real token server
      channelId: widget.channelId,
      uid: 0,
      options: const ChannelMediaOptions(
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
        publishCameraTrack: true,
        publishMicrophoneTrack: true,
      ),
    );
  }

  @override
  void dispose() {
    _engine.leaveChannel();
    _engine.release();
    super.dispose();
  }

  void _toggleMute() {
    setState(() => _muted = !_muted);
    _engine.muteLocalAudioStream(_muted);
  }

  void _toggleVideo() {
    setState(() => _videoDisabled = !_videoDisabled);
    _engine.muteLocalVideoStream(_videoDisabled);
  }

  void _endCall() {
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: isDoodleMode(context) ? DoodleColors.cream : Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Remote Video
            Center(
              child: _remoteUid != null
                  ? AgoraVideoView(
                      controller: VideoViewController.remote(
                        rtcEngine: _engine,
                        canvas: VideoCanvas(uid: _remoteUid),
                        connection: RtcConnection(channelId: widget.channelId),
                      ),
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(color: Color(0xFFFF6B00)),
                        const SizedBox(height: 16),
                        Text('Waiting for ${widget.peerName} to join...', style: const TextStyle(color: Colors.white70)),
                      ],
                    ),
            ),
            
            // Top Bar
            Positioned(
              top: 16, left: 16, right: 16,
              child: Row(
                children: [
                  GestureDetector(
                    onTap: _endCall,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.arrow_back, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text('Meeting with ${widget.peerName}', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
            ),

            // Local Video
            Positioned(
              bottom: 100, right: 16,
              width: 120, height: 160,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white38, width: 2),
                  boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 10)],
                ),
                clipBehavior: Clip.hardEdge,
                child: _localUserJoined && !_videoDisabled
                    ? AgoraVideoView(
                        controller: VideoViewController(
                          rtcEngine: _engine,
                          canvas: const VideoCanvas(uid: 0),
                        ),
                      )
                    : Container(color: Colors.grey.shade900, child: const Center(child: Icon(Icons.videocam_off, color: Colors.white54))),
              ),
            ),

            // Controls
            Positioned(
              bottom: 30, left: 0, right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _controlBtn(
                    icon: _muted ? Icons.mic_off : Icons.mic,
                    color: _muted ? Colors.red : Colors.white24,
                    onTap: _toggleMute,
                  ),
                  const SizedBox(width: 20),
                  _controlBtn(
                    icon: Icons.call_end,
                    color: Colors.red,
                    onTap: _endCall,
                    size: 64,
                    iconSize: 32,
                  ),
                  const SizedBox(width: 20),
                  _controlBtn(
                    icon: _videoDisabled ? Icons.videocam_off : Icons.videocam,
                    color: _videoDisabled ? Colors.red : Colors.white24,
                    onTap: _toggleVideo,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _controlBtn({required IconData icon, required Color color, required VoidCallback onTap, double size = 56, double iconSize = 24}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size, height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: iconSize),
      ),
    );
  }
}
