import 'package:flutter/material.dart';

class TechnologiesPage extends StatelessWidget {
  const TechnologiesPage({super.key});

  Widget _buildTechCard(
      BuildContext context, IconData icon, String title, String subtitle) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).primaryColor, size: 30),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Technology Stack')),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildTechCard(
            context,
            Icons.phone_android,
            'Flutter & Dart',
            'Cross-platform UI framework for a beautiful, native experience.',
          ),
          _buildTechCard(
            context,
            Icons.cloud,
            'Google Cloud',
            'Scalable backend, database, and cloud functions for our architecture.',
          ),
          _buildTechCard(
            context,
            Icons.auto_awesome,
            'Gemini / AI Models',
            'Powers the AI prediction engine to forecast future spending habits.',
          ),
          _buildTechCard(
            context,
            Icons.bar_chart,
            'fl_chart',
            'Renders the beautiful, interactive charts on the Analysis page.',
          ),
          _buildTechCard(
            context,
            Icons.account_tree,
            'Provider',
            'Lightweight and efficient state management for the app.',
          ),
          _buildTechCard(
            context,
            Icons.calendar_today,
            'table_calendar',
            'Used for the interactive expense calendar view.',
          ),
        ],
      ),
    );
  }
}
