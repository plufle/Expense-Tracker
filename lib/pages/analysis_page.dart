import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../services/expenses_api_service.dart';
import '../widgets/analysis_chart.dart';

class AnalysisPage extends StatefulWidget {
  const AnalysisPage({super.key});

  @override
  State<AnalysisPage> createState() => _AnalysisPageState();
}

class _AnalysisPageState extends State<AnalysisPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Set your correct apiBase (include stage if needed)
  final ExpensesApiService _api = ExpensesApiService(
    apiBase: dotenv.env['API_BASE_URL'] ?? '',
  );

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Optional: if you navigate via routes, keep a static helper:
  // ignore: unused_element
  static PageRoute route() =>
      MaterialPageRoute(builder: (_) => const AnalysisPage());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analysis'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Week'),
            Tab(text: 'Month'),
            Tab(text: 'Year'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          AnalysisChart(api: _api, period: 'Week'),
          AnalysisChart(api: _api, period: 'Month'),
          AnalysisChart(api: _api, period: 'Year'),
        ],
      ),
    );
  }
}
