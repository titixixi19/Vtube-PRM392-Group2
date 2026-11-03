import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:vtube/app/routes.dart';
import 'package:vtube/app/theme.dart';
import 'package:vtube/core/network/api_client.dart';
import 'package:vtube/core/network/api_exception.dart';
import 'package:vtube/core/storage/token_storage.dart';
import 'package:vtube/data/models/models.dart';
import 'package:vtube/data/services/search_service.dart';
import 'package:vtube/features/explore/search_screen.dart';

/// Lớp giả lập SearchService cho kiểm thử Màn 9 & 10.
class FakeSearchService extends SearchService {
  FakeSearchService() : super(ApiClient(TokenStorage()));

  int suggestionsCalls = 0;
  String? lastSuggestionsQuery;
  SearchSuggestions returnSuggestions = const SearchSuggestions(
    history: ['flutter', 'vtube', 'react native'],
    suggestions: ['flutter tutorial', 'flutter animation', 'flutter state management'],
  );
  ApiException? suggestionsError;

  /// Map hỗ trợ kiểm tra phản hồi bất đồng bộ theo thứ tự tự định nghĩa (race condition).
  final Map<String, Completer<SearchSuggestions>> queryCompleters = {};

  int deleteCalls = 0;
  String? lastDeletedKeyword;
  ApiException? deleteError;

  @override
  Future<SearchSuggestions> suggestions(String q) async {
    suggestionsCalls++;
    lastSuggestionsQuery = q;
    if (queryCompleters.containsKey(q)) {
      return await queryCompleters[q]!.future;
    }
    if (suggestionsError != null) throw suggestionsError!;
    return returnSuggestions;
  }

  @override
  Future<void> deleteHistory({String? keyword}) async {
    deleteCalls++;
    lastDeletedKeyword = keyword;
    if (deleteError != null) throw deleteError!;
  }
}

/// Helper bọc MaterialApp và MultiProvider cho SearchScreen.
Widget buildTestSearchScreen({
  required FakeSearchService searchService,
  String? initialQuery,
  void Function(String route)? onPushed,
}) {
  final router = GoRouter(
    initialLocation: initialQuery != null && initialQuery.isNotEmpty
        ? '/search?q=${Uri.encodeQueryComponent(initialQuery)}'
        : AppRoutes.search,
    routes: [
      GoRoute(
        path: AppRoutes.search,
        builder: (context, state) => SearchScreen(initialQuery: state.uri.queryParameters['q'] ?? initialQuery),
      ),
      GoRoute(
        path: '/search/results',
        builder: (context, state) {
          final q = state.uri.queryParameters['q'] ?? '';
          onPushed?.call(AppRoutes.searchResults(q));
          return Scaffold(
            appBar: AppBar(
              leading: BackButton(onPressed: () => context.pop()),
            ),
            body: Text('Results: $q'),
          );
        },
      ),
    ],
  );

  return MultiProvider(
    providers: [
      Provider<SearchService>.value(value: searchService),
    ],
    child: MaterialApp.router(
      theme: AppTheme.dark(),
      routerConfig: router,
    ),
  );
}
