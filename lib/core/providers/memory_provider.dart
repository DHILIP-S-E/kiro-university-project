import 'package:flutter/foundation.dart';
import 'package:personal_memory_os/core/models/memory_document.dart';
import 'package:personal_memory_os/core/models/ai_message.dart';
import 'package:personal_memory_os/core/services/memory_service.dart';
import 'package:personal_memory_os/core/services/ai_service.dart';

class MemoryProvider extends ChangeNotifier {
  final MemoryService _memoryService;
  final AiService _aiService;

  MemoryProvider(this._memoryService, this._aiService);

  List<MemoryDocument> _documents = [];
  List<AiMessage> _chatHistory = [];
  List<MemoryDocument> _searchResults = [];
  bool _isLoading = false;
  bool _isSearching = false;
  bool _isAsking = false;
  String _searchQuery = '';
  String? _error;

  List<MemoryDocument> get documents => _documents;
  List<AiMessage> get chatHistory => _chatHistory;
  List<MemoryDocument> get searchResults => _searchResults;
  bool get isLoading => _isLoading;
  bool get isSearching => _isSearching;
  bool get isAsking => _isAsking;
  String get searchQuery => _searchQuery;
  String? get error => _error;

  bool get hasSearchResults => _searchResults.isNotEmpty;

  Future<void> loadMemory() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _documents = await _memoryService.fetchMemoryDocuments();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> search(String query) async {
    if (query.trim().isEmpty) {
      _searchResults = [];
      _searchQuery = '';
      notifyListeners();
      return;
    }
    _isSearching = true;
    _searchQuery = query;
    notifyListeners();
    try {
      _searchResults = await _memoryService.searchMemory(query);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isSearching = false;
      notifyListeners();
    }
  }

  void clearSearch() {
    _searchResults = [];
    _searchQuery = '';
    notifyListeners();
  }

  Future<void> askQuestion(String question) async {
    _chatHistory.add(AiMessage(
      id: DateTime.now().toIso8601String(),
      role: MessageRole.user,
      content: question,
      timestamp: DateTime.now(),
    ));
    _isAsking = true;
    notifyListeners();

    try {
      final response = await _aiService.askMemoryQuestion(question);
      _chatHistory.add(AiMessage(
        id: '${DateTime.now().toIso8601String()}_resp',
        role: MessageRole.assistant,
        content: response.answer,
        sources: response.sources,
        timestamp: DateTime.now(),
      ));
    } catch (e) {
      _chatHistory.add(AiMessage(
        id: '${DateTime.now().toIso8601String()}_err',
        role: MessageRole.assistant,
        content: 'Something went wrong retrieving your memory. Please try again.',
        timestamp: DateTime.now(),
        isError: true,
      ));
    } finally {
      _isAsking = false;
      notifyListeners();
    }
  }

  void clearChat() {
    _chatHistory = [];
    notifyListeners();
  }
}
