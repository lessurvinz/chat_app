import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:chat_app/widgets/chat_bubble.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ChatScreen extends StatefulWidget {
  final String chatRoomId;
  final String? userName;

  const ChatScreen({super.key, required this.chatRoomId, this.userName});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();

  String? _backgroundUrl;
  List<Color> _currentGradient = [Colors.white, Colors.grey[200]!];
  bool _isDarkTheme = false;

  @override
  void initState() {
    super.initState();
    _markMessagesAsRead();
    _listenToChatSettings();
  }

  void _listenToChatSettings() {
    _firestore.collection('chats').doc(widget.chatRoomId).snapshots().listen((doc) {
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        setState(() {
          _backgroundUrl = data['themeImageUrl'];
          _isDarkTheme = data['isDarkTheme'] ?? false;
          
          if (data['themeColors'] != null) {
            List<dynamic> colorValues = data['themeColors'];
            _currentGradient = colorValues.map((c) => Color(c as int)).toList();
          }
        });
      }
    });
  }

  Future<void> _updateThemeInFirestore({List<Color>? colors, String? imageUrl, required bool isDark}) async {
    Map<String, dynamic> updateData = {'isDarkTheme': isDark};
    
    if (colors != null) {
      updateData['themeColors'] = colors.map((c) => c.value).toList();
      updateData['themeImageUrl'] = null;
    }
    if (imageUrl != null) {
      updateData['themeImageUrl'] = imageUrl;
      updateData['themeColors'] = null;
    }

    await _firestore.collection('chats').doc(widget.chatRoomId).set(updateData, SetOptions(merge: true));
  }

  Future<void> _pickChatBackground() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (image == null) return;

    String fileName = 'background_${widget.chatRoomId}.jpg';
    Reference ref = _storage.ref().child('themes/$fileName');
    await ref.putFile(File(image.path));
    String downloadUrl = await ref.getDownloadURL();

    await _updateThemeInFirestore(imageUrl: downloadUrl, isDark: true);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _sendMedia(String type) async {
    final XFile? file = type == 'image' 
        ? await _picker.pickImage(source: ImageSource.gallery) 
        : await _picker.pickVideo(source: ImageSource.gallery);
    if (file == null) return;

    String fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.name}';
    Reference ref = _storage.ref().child('chats/${widget.chatRoomId}/$fileName');
    
    UploadTask uploadTask = ref.putFile(File(file.path));
    TaskSnapshot snap = await uploadTask;
    String url = await snap.ref.getDownloadURL();
    String displayMsg = type == 'image' ? '📷 Photo' : '🎥 Video';

    await _firestore.collection('chats').doc(widget.chatRoomId).collection('messages').add({
      'text': displayMsg,
      'mediaUrl': url,
      'mediaType': type,
      'createdAt': FieldValue.serverTimestamp(),
      'senderId': _auth.currentUser!.uid,
    });

    // --- LOGIC FIX START ---
    // If the person sending is NOT the chatRoomId (User), then the Admin is sending.
    bool isAdmin = _auth.currentUser!.uid != widget.chatRoomId;
    String fieldToIncrement = isAdmin ? 'unreadByUserCount' : 'unreadByAdminCount';
    // --- LOGIC FIX END ---

    await _firestore.collection('chats').doc(widget.chatRoomId).set({
      'lastMessage': displayMsg,
      'lastMessageAt': FieldValue.serverTimestamp(),
      fieldToIncrement: FieldValue.increment(1), // Fixed this
    }, SetOptions(merge: true));

    _scrollToBottom();
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;
    final String text = _messageController.text.trim();
    _messageController.clear();

    await _firestore.collection('chats').doc(widget.chatRoomId).collection('messages').add({
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
      'senderId': _auth.currentUser!.uid,
    });
    
    // --- LOGIC FIX START ---
    bool isAdmin = _auth.currentUser!.uid != widget.chatRoomId;
    String fieldToIncrement = isAdmin ? 'unreadByUserCount' : 'unreadByAdminCount';
    // --- LOGIC FIX END ---

    await _firestore.collection('chats').doc(widget.chatRoomId).set({
      'lastMessage': text,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'userEmail': _auth.currentUser!.email,
      fieldToIncrement: FieldValue.increment(1), // Fixed this
    }, SetOptions(merge: true));

    _scrollToBottom();
  }

  void _showThemePicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        height: 280,
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text("Chat Theme", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _themeCircle([const Color(0xFFFF85A1), const Color(0xFF750D37)], true),
                _themeCircle([Colors.blueAccent, Colors.purpleAccent], true),
                _themeCircle([Colors.white, Colors.grey[300]!], false),
              ],
            ),
            const Spacer(),
            ListTile(
              leading: const Icon(Icons.image, color: Colors.deepPurple),
              title: const Text("Select Background from Gallery"),
              onTap: _pickChatBackground,
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _themeCircle(List<Color> colors, bool isDark) {
    return GestureDetector(
      onTap: () => _updateThemeInFirestore(colors: colors, isDark: isDark).then((_) => Navigator.pop(context)),
      child: Container(
        width: 50, height: 50,
        decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: colors)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.black12,
        elevation: 0,
        title: Text(widget.userName ?? 'Chat', style: TextStyle(color: _isDarkTheme ? Colors.white : Colors.black)),
        iconTheme: IconThemeData(color: _isDarkTheme ? Colors.white : Colors.black),
        actions: [IconButton(icon: const Icon(Icons.palette), onPressed: _showThemePicker)],
      ),
      body: Container(
        decoration: BoxDecoration(
          image: _backgroundUrl != null 
            ? DecorationImage(image: NetworkImage(_backgroundUrl!), fit: BoxFit.cover) 
            : null,
          gradient: _backgroundUrl == null ? LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: _currentGradient) : null,
        ),
        child: Column(
          children: [
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _firestore.collection('chats').doc(widget.chatRoomId).collection('messages').orderBy('createdAt', descending: false).snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                  final docs = snapshot.data!.docs;
                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.only(top: 100, bottom: 20),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final data = docs[index].data() as Map<String, dynamic>;
                      return ChatBubble(
                        message: data['text'] ?? '',
                        mediaUrl: data['mediaUrl'],
                        isCurrentUser: data['senderId'] == _auth.currentUser!.uid,
                        timestamp: (data['createdAt'] as Timestamp?)?.toDate(),
                      );
                    },
                  );
                },
              ),
            ),
            _buildInputBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      color: _isDarkTheme ? Colors.black87 : Colors.white,
      child: SafeArea(
        child: Row(
          children: [
            IconButton(icon: const Icon(Icons.add_a_photo, color: Colors.blue), onPressed: () => _sendMedia('image')),
            Expanded(
              child: TextField(
                controller: _messageController,
                style: TextStyle(color: _isDarkTheme ? Colors.white : Colors.black),
                textInputAction: TextInputAction.send, 
                onSubmitted: (value) => _sendMessage(), 
                decoration: const InputDecoration(
                  hintText: "Message...", 
                  hintStyle: TextStyle(color: Colors.grey), 
                  border: InputBorder.none
                ),
              ),
            ),
            IconButton(icon: const Icon(Icons.send, color: Colors.blue), onPressed: _sendMessage),
          ],
        ),
      ),
    );
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(_scrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  Future<void> _markMessagesAsRead() async {
    String field = _auth.currentUser!.uid == widget.chatRoomId ? 'unreadByUserCount' : 'unreadByAdminCount';
    await _firestore.collection('chats').doc(widget.chatRoomId).set({field: 0}, SetOptions(merge: true));
  }
}