import 'package:flutter/material.dart';

class CustomHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Color primaryColor;
  final Color? secondaryColor;
  final double expandedHeight;
  final List<Widget>? actions;

  const CustomHeader({
    Key? key,
    required this.title,
    this.subtitle,
    required this.primaryColor,
    this.secondaryColor,
    this.expandedHeight = 50.0,
    this.actions,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: expandedHeight,
      pinned: true,
      actions: actions,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              primaryColor,
              secondaryColor ?? primaryColor.withOpacity(0.7),
            ],
          ),
        ),
        child: FlexibleSpaceBar(
          title: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                  ),
                ),
            ],
          ),
          centerTitle: false,
          background: Stack(
            fit: StackFit.expand,
            children: [
              // Decorative background elements
              Positioned(
                right: -40,
                top: -20,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Positioned(
                left: 30,
                bottom: 0,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
