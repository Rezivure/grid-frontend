import 'package:flutter/material.dart';
import 'package:random_avatar/random_avatar.dart';

class UserMapMarker extends StatelessWidget {
  final String userId;

  UserMapMarker({required this.userId});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none, // Allow overflow for the triangle
      children: [
        // Triangle at the bottom
        Positioned(
          bottom: -10, // Adjust as needed
          child: CustomPaint(
            size: Size(20, 10),
            painter: TrianglePainter(color: Colors.white),
          ),
        ),
        // Circle Avatar with white border
        Container(
          padding: EdgeInsets.all(3), // Border width
          decoration: BoxDecoration(
            color: Colors.white, // Border color
            shape: BoxShape.circle,
          ),
          child: ClipOval(
            child: RandomAvatar(
              (userId.split(':')[0]
                  .replaceFirst('@', '')),
              height: 40,
              width: 40,
            ),
          ),
        ),
      ],
    );
  }
}

class TrianglePainter extends CustomPainter {
  final Color color;

  TrianglePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final Path path = Path();

    path.moveTo(0, 0);
    path.lineTo(size.width / 2, size.height);
    path.lineTo(size.width, 0);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(TrianglePainter oldDelegate) => false;
}
