import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/server_config.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';

class PinScreen extends StatefulWidget {
  final ServerConfig config;
  final ApiService api;

  const PinScreen({
    super.key,
    required this.config,
    required this.api,
  });

  @override
  State<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends State<PinScreen> {
  final _pinController = TextEditingController();
  final _storage = StorageService();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final pin = _pinController.text.trim();
    if (pin.isEmpty) {
      setState(() => _error = 'Nhập PIN hiển thị trên màn hình xe');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final ok = await widget.api.login(pin);
      if (!ok) {
        if (mounted) {
          setState(() {
            _busy = false;
            _error = 'PIN không đúng hoặc đã hết hạn';
          });
        }
        return;
      }
      final cookie = widget.api.sessionCookie;
      if (cookie != null && cookie.isNotEmpty) {
        await _storage.saveSession(widget.config, cookie);
      }
      if (mounted) {
        Navigator.pop(context, true);
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e.message.isNotEmpty ? e.message : 'Đăng nhập thất bại (${e.statusCode})';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Không kết nối được: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF05080F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A1020),
        title: const Text('Nhập PIN', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              const Icon(Icons.lock_outline, size: 56, color: Color(0xFF3DC8FF)),
              const SizedBox(height: 16),
              Text(
                '${widget.config.host}:${widget.config.port}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white54, fontSize: 14),
              ),
              const SizedBox(height: 8),
              const Text(
                'Nhập PIN hiện tại trên màn hình xe để truy cập bản ghi và camera.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 15),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _pinController,
                enabled: !_busy,
                autofocus: true,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(8),
                ],
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  letterSpacing: 8,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  hintText: '••••',
                  hintStyle: const TextStyle(color: Colors.white24, letterSpacing: 8),
                  filled: true,
                  fillColor: const Color(0xFF121A2A),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF3DC8FF), width: 1.5),
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFFFF6B6B), fontSize: 14),
                ),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _busy ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF3DC8FF),
                  foregroundColor: const Color(0xFF05080F),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _busy
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text(
                        'Xác nhận',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
