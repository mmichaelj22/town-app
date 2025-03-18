import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  final double detectionRadius;
  final ValueChanged<double> onRadiusChanged;

  const SettingsScreen({
    super.key,
    required this.detectionRadius,
    required this.onRadiusChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.white,
        elevation: 4,
        titleTextStyle: const TextStyle(color: Colors.black, fontSize: 20),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Detection Radius', style: TextStyle(fontSize: 18)),
            Slider(
              value: detectionRadius,
              min: 50.0,
              max: 500.0,
              divisions: 9,
              label: '${detectionRadius.round()} ft',
              onChanged: onRadiusChanged,
            ),
            Text('Current radius: ${detectionRadius.round()} feet'),
          ],
        ),
      ),
    );
  }
}
