import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'dart:math';

class FinancialNews extends StatefulWidget {
  const FinancialNews({super.key});

  @override
  _FinancialNewsState createState() => _FinancialNewsState();
}

class _FinancialNewsState extends State<FinancialNews> {
  List<Map<String, dynamic>> _news = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchNews();
  }

  Future<void> _fetchNews() async {
    final url =
        'https://newsapi.org/v2/top-headlines/sources?apiKey=9f38e484b241421ebafc6b6971ffb5af&category=business&language=en';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _news = List<Map<String, dynamic>>.from(
            (data['sources'] as List<dynamic>).map((item) {
              return {
                'title': item['name'] ?? 'No Title',
                'source': item['description'] ?? 'No Description',
                'url': item['url'] ?? '',
              };
            }),
          );
          _loading = false;
        });
      } else {
        throw Exception(
          'Failed to load news. Status code: ${response.statusCode}',
        );
      }
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Failed to load news: $e';
      });
    }
  }

  void _launchURL(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      print('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Determine the maximum height needed for 3 ListTiles (approx 72px each)
    // Add space for error/loading indicator padding.
    const double maxListHeight = 3 * 72.0 + 20.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 16.0, top: 16.0, right: 16.0),
          child: Text(
            'Top 3 Financial News Sources 📰',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 8),

        // --- FIX APPLIED HERE ---
        // Wrap the content with a fixed height to avoid unbounded errors
        // when FinancialNews is placed inside a larger, scrollable parent (like a ListView).
        SizedBox(
          height: maxListHeight,
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                )
              : ListView.builder(
                  // Telling the ListView to only occupy the space needed by its children
                  // up to the height of the parent SizedBox.
                  shrinkWrap: true,
                  // Disable scrolling, as the parent SizedBox already defines the limit
                  // and prevents scrolling beyond the 3 items.
                  physics: const NeverScrollableScrollPhysics(),

                  itemCount: min(_news.length, 3),
                  itemBuilder: (context, index) {
                    final newsItem = _news[index];
                    final title = newsItem['title'] ?? 'No Title';
                    final description = newsItem['source']?.length > 100
                        ? '${newsItem['source'].substring(0, 100)}...'
                        : newsItem['source'] ?? 'No Description';
                    final url = newsItem['url'] ?? '';

                    return ListTile(
                      title: Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: const Icon(Icons.open_in_new),
                      onTap: () {
                        if (url.isNotEmpty) {
                          _launchURL(url);
                        }
                      },
                    );
                  },
                ),
        ),
        // ------------------------
      ],
    );
  }
}
