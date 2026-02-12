import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ChatBubble extends StatefulWidget {
  final String message;
  final String? mediaUrl; // 📸 Added for media support
  final bool isCurrentUser;
  final DateTime? timestamp;
  final bool showCenteredTimestamp;

  const ChatBubble({
    super.key,
    required this.message,
    this.mediaUrl, // 📸 Added for media support
    required this.isCurrentUser,
    this.timestamp,
    this.showCenteredTimestamp = false,
  });

  @override
  State<ChatBubble> createState() => _ChatBubbleState();
}

class _ChatBubbleState extends State<ChatBubble> {
  bool _showTimestamp = false;

  String _formatTimestamp(DateTime? dateTime) {
    if (dateTime == null) return '';
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      return DateFormat('h:mm a').format(dateTime);
    } else if (difference.inDays == 1) {
      return 'Yesterday ${DateFormat('h:mm a').format(dateTime)}';
    } else {
      return DateFormat('MMM d, h:mm a').format(dateTime);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Centered timestamp
        if (widget.showCenteredTimestamp && widget.timestamp != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black26, // Darker for better visibility on backgrounds
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _formatTimestamp(widget.timestamp),
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),

        // Message/Media bubble
        GestureDetector(
          onTap: () {
            setState(() => _showTimestamp = !_showTimestamp);
            Future.delayed(const Duration(seconds: 3), () {
              if (mounted) setState(() => _showTimestamp = false);
            });
          },
          child: Container(
            alignment: widget.isCurrentUser ? Alignment.centerRight : Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: widget.isCurrentUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.7,
                  ),
                  margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
                  decoration: BoxDecoration(
                    color: widget.isCurrentUser
                        ? Colors.blueAccent.withOpacity(0.9)
                        : Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // --- SHOW IMAGE IF mediaUrl EXISTS ---
                        if (widget.mediaUrl != null)
                          Image.network(
                            widget.mediaUrl!,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return const Padding(
                                padding: EdgeInsets.all(20.0),
                                child: CircularProgressIndicator(strokeWidth: 2),
                              );
                            },
                          ),
                        
                        // --- SHOW TEXT MESSAGE ---
                        if (widget.message.isNotEmpty && widget.message != '📷 Photo' && widget.message != '🎥 Video')
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            child: Text(
                              widget.message,
                              style: TextStyle(
                                color: widget.isCurrentUser ? Colors.white : Colors.black87,
                                fontSize: 16,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                
                // Timestamp below
                if (_showTimestamp && widget.timestamp != null && !widget.showCenteredTimestamp)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                    child: Text(
                      _formatTimestamp(widget.timestamp),
                      style: const TextStyle(fontSize: 11, color: Colors.white70),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}