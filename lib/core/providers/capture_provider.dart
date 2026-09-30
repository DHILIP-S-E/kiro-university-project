import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:personal_memory_os/core/models/capture.dart';
import 'package:personal_memory_os/core/services/capture_service.dart';

class CaptureProvider extends ChangeNotifier {
  final CaptureService _service;

  CaptureProvider(this._service);

  List<Capture> _captures = [];
  bool _isLoading = false;
  bool _isUploading = false;
  String? _error;

  List<Capture> get captures => _captures;
  bool get isLoading => _isLoading;
  bool get isUploading => _isUploading;
  String? get error => _error;

  List<Capture> capturesForEvent(String eventId) =>
      _captures.where((c) => c.eventId == eventId).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  List<Capture> get recentCaptures =>
      _captures.take(10).toList();

  Future<void> loadCaptures() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _captures = await _service.fetchCaptures();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> uploadPhoto({required File file, String? eventId}) async {
    _isUploading = true;
    notifyListeners();
    try {
      final capture = await _service.uploadCapture(
        file: file,
        type: CaptureType.photo,
        eventId: eventId,
      );
      _captures.insert(0, capture);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    } finally {
      _isUploading = false;
      notifyListeners();
    }
  }

  Future<void> uploadVoiceNote({required File file, String? eventId}) async {
    _isUploading = true;
    notifyListeners();
    try {
      final capture = await _service.uploadCapture(
        file: file,
        type: CaptureType.voice,
        eventId: eventId,
      );
      _captures.insert(0, capture);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    } finally {
      _isUploading = false;
      notifyListeners();
    }
  }

  Future<void> saveTextNote({required String text, String? eventId}) async {
    try {
      final capture = await _service.saveTextNote(text: text, eventId: eventId);
      _captures.insert(0, capture);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> saveLink({required String url, String? eventId}) async {
    try {
      final capture = await _service.saveLink(url: url, eventId: eventId);
      _captures.insert(0, capture);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteCapture(String id) async {
    try {
      await _service.deleteCapture(id);
      _captures.removeWhere((c) => c.id == id);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  void updateCaptureLocally(Capture updated) {
    final index = _captures.indexWhere((c) => c.id == updated.id);
    if (index != -1) {
      _captures[index] = updated;
      notifyListeners();
    }
  }
}
