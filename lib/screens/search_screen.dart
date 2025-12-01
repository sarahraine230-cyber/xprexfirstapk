import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:xprex/theme.dart';
import 'package:xprex/services/search_service.dart';
import 'package:xprex/models/video_model.dart';
import 'package:xprex/models/profile_model.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> with SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();
  final _searchService = SearchService();
  Timer? _debounce;
  late TabController _tabController;

  List<VideoModel> _videoResults = [];
  List<ProfileModel> _userResults = [];
  bool _searching = false;
  String _currentQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    
    // Wait 500ms after typing stops before hitting database
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (query.trim().isNotEmpty && query != _currentQuery) {
        _performSearch(query);
      }
    });
  }

  Future<void> _performSearch(String query) async {
    setState(() {
      _searching = true;
      _currentQuery = query;
    });

    // Run both searches in parallel
    final results = await Future.wait([
      _searchService.searchVideos(query),
      _searchService.searchUsers(query),
    ]);

    if (mounted) {
      setState(() {
        _videoResults = results[0] as List<VideoModel>;
        _userResults = results[1] as List<ProfileModel>;
        _searching = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Container(
          height: 40,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Search videos, users, tags...',
              border: InputBorder.none,
              prefixIcon: Icon(Icons.search, color: theme.colorScheme.onSurfaceVariant),
              hintStyle: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              contentPadding: const EdgeInsets.only(top: 2), // vertically center text
            ),
            style: theme.textTheme.bodyMedium,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: theme.colorScheme.primary,
          unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
          indicatorColor: theme.colorScheme.primary,
          tabs: const [
            Tab(text: 'Videos'),
            Tab(text: 'People'),
          ],
        ),
      ),
      body: _searching
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                // 1. Video Results Grid
                _videoResults.isEmpty && _currentQuery.isNotEmpty
                    ? _buildEmptyState(theme, 'No videos found')
                    : _buildVideoGrid(theme),
                
                // 2. User Results List
                _userResults.isEmpty && _currentQuery.isNotEmpty
                    ? _buildEmptyState(theme, 'No people found')
                    : _buildUserList(theme),
              ],
            ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_currentQuery.isEmpty) ...[
            Icon(Icons.manage_search, size: 64, color: theme.colorScheme.surfaceContainerHighest),
            const SizedBox(height: 16),
            Text('Explore XpreX', style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ] else ...[
            Icon(Icons.search_off, size: 48, color: theme.colorScheme.surfaceContainerHighest),
            const SizedBox(height: 16),
            Text(message, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ]
        ],
      ),
    );
  }

  Widget _buildVideoGrid(ThemeData theme) {
    if (_currentQuery.isEmpty) return _buildEmptyState(theme, '');
    
    return GridView.builder(
      padding: const EdgeInsets.all(4),
      itemCount: _videoResults.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
        childAspectRatio: 9 / 16,
      ),
      itemBuilder: (context, index) {
        final video = _videoResults[index];
        return GestureDetector(
          onTap: () {
            // TODO: Navigate to video player
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (video.coverImageUrl != null)
                  Image.network(video.coverImageUrl!, fit: BoxFit.cover)
                else
                  Container(color: Colors.grey[900]),
                
                // Gradient overlay for text readability
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [Colors.black.withValues(alpha: 0.8), Colors.transparent],
                      ),
                    ),
                  ),
                ),
                // Title
                Align(
                  alignment: Alignment.bottomLeft,
                  child: Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Text(
                      video.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildUserList(ThemeData theme) {
    if (_currentQuery.isEmpty) return _buildEmptyState(theme, '');

    return ListView.separated(
      itemCount: _userResults.length,
      padding: const EdgeInsets.symmetric(vertical: 8),
      separatorBuilder: (ctx, i) => const Divider(height: 1, indent: 72),
      itemBuilder: (context, index) {
        final user = _userResults[index];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            backgroundImage: user.avatarUrl != null ? NetworkImage(user.avatarUrl!) : null,
            child: user.avatarUrl == null ? const Icon(Icons.person) : null,
          ),
          title: Text(user.displayName),
          subtitle: Text('@${user.username}'),
          onTap: () {
            context.push('/u/${user.authUserId}');
          },
        );
      },
    );
  }
}
