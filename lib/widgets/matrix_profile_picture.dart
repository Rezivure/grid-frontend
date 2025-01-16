import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:random_avatar/random_avatar.dart';
import 'package:provider/provider.dart';
import 'package:matrix/matrix.dart';
import '../services/user_service.dart';

class MatrixProfilePicture extends StatefulWidget {
  final String userId;
  final double radius;

  const MatrixProfilePicture({
    super.key,
    required this.userId,
    this.radius = 20,
  });

  @override
  State<MatrixProfilePicture> createState() => _MatrixProfilePictureState();
}

class _MatrixProfilePictureState extends State<MatrixProfilePicture> {
  // If the avatar is an HTTP(S) URL, we store it here
  Uri? _avatarUrl;

  // If the avatar is an MXC URL, we store the downloaded bytes here
  Uint8List? _avatarBytes;

  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadProfilePicture();
  }

  @override
  void didUpdateWidget(covariant MatrixProfilePicture oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) {
      _loadProfilePicture();
    }
  }

  Future<void> _loadProfilePicture() async {
    try {
      setState(() {
        _isLoading = true;
        _hasError = false;
        _avatarUrl = null;
        _avatarBytes = null;
      });


      final userService = Provider.of<UserService>(context, listen: false);
      final avatarUri = await userService.getAvatarUrl(widget.userId);
      print('Got avatarUri: $avatarUri');

      if (!mounted) return;

      if (avatarUri == null) {
        // No avatar at all
        setState(() {
          _isLoading = false;
          _hasError = false;
        });
        return;
      }


      if (avatarUri.scheme == 'mxc') {

        final withoutPrefix = avatarUri.toString().replaceFirst('mxc://', '');
        final parts = withoutPrefix.split('/');
        if (parts.length < 2) {
          setState(() {
            _isLoading = false;
            _hasError = true;
          });
          return;
        }

        final serverName = parts[0];
        final mediaId = parts[1];

        // 2) Download the content bytes
        final client = Provider.of<Client>(context, listen: false);
        try {
          final fileResponse = await client.getContent(
            serverName,
            mediaId,
            allowRemote: true,
          );
          // ...
        } catch (e) {
          print('Error details: ${e.toString()}');  // More detailed error logging
          if (e is MatrixException) {
            print('Matrix error code: ${e.errcode}');
            print('Matrix error message: ${e.error}');
          }
          // ... rest of error handling
        }

// 2. Verify the URL components
        print('Server name: $serverName');
        print('Media ID: $mediaId');
        final fileResponse = await client.getContent(
          serverName,
          mediaId,
          allowRemote: true,
        );

        if (!mounted) return;

        // 3) Store the bytes in _avatarBytes
        setState(() {
          _avatarBytes = fileResponse.data; // raw bytes
          _isLoading = false;
          _hasError = false;
        });
      } else if (avatarUri.scheme.startsWith('http')) {
        // It's an HTTP(S) URL, so we can use Image.network
        setState(() {
          _avatarUrl = avatarUri;
          _isLoading = false;
          _hasError = false;
        });
      } else {
        // Some other scheme we don't recognize
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    } catch (e) {
      if (!mounted) return;
      print('Error loading avatar: $e');
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  Widget _buildFallbackAvatar() {
    return CircleAvatar(
      radius: widget.radius,
      backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
      child: RandomAvatar(
        widget.userId.split(':')[0].replaceAll('@', ''),
        height: widget.radius * 2,
        width: widget.radius * 2,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 1) While we’re loading the URL or bytes, show a spinner
    if (_isLoading) {
      return SizedBox(
        width: widget.radius * 2,
        height: widget.radius * 2,
        child: const Center(
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    // 2) If there's an error or nothing loaded, show fallback
    if (_hasError || (_avatarUrl == null && _avatarBytes == null)) {
      return _buildFallbackAvatar();
    }

    // 3) If we have raw bytes, display them
    if (_avatarBytes != null) {
      return CircleAvatar(
        radius: widget.radius,
        backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
        child: ClipOval(
          child: Image.memory(
            _avatarBytes!,
            width: widget.radius * 2,
            height: widget.radius * 2,
            fit: BoxFit.cover,
          ),
        ),
      );
    }

    // 4) Otherwise, we have a valid HTTP URL; display with Image.network
    return CircleAvatar(
      radius: widget.radius,
      backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
      child: ClipOval(
        child: Image.network(
          _avatarUrl.toString(),
          width: widget.radius * 2,
          height: widget.radius * 2,
          fit: BoxFit.cover,
          // If an HTTP load fails, show fallback
          errorBuilder: (context, error, stackTrace) => _buildFallbackAvatar(),
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return const CircularProgressIndicator(strokeWidth: 2);
          },
        ),
      ),
    );
  }
}
