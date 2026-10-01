import 'package:personal_memory_os/core/models/memory_document.dart';
import 'package:personal_memory_os/core/services/memory_service.dart';
import 'package:personal_memory_os/core/services/api_client.dart';
import 'package:personal_memory_os/core/services/api_mapper.dart';

/// Real implementation of [MemoryService] that calls the FastAPI backend.
class ApiMemoryService implements MemoryService {
  final ApiClient _client;

  ApiMemoryService(this._client);

  @override
  Future<List<MemoryDocument>> fetchMemoryDocuments() async {
    final data = await _client.get('/memory') as List<dynamic>;
    return data
        .map((j) => memoryFromApi(j))
        .toList();
  }

  @override
  Future<List<MemoryDocument>> searchMemory(String query) async {
    final data = await _client.get(
      '/memory/search',
      query: {'q': query},
    ) as List<dynamic>;
    return data
        .map((j) => memoryFromApi(j))
        .toList();
  }
}
