import 'package:flutter/material.dart';
import 'package:xprex/theme.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search videos, users, tags...',
            border: InputBorder.none,
            hintStyle: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          style: theme.textTheme.bodyLarge,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // Perform search logic later
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.manage_search, size: 80, color: theme.colorScheme.surfaceContainerHighest),
            const SizedBox(height: 16),
            Text(
              'Explore XpreX', 
              style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)
            ),
          ],
        ),
      ),
    );
  }
}
