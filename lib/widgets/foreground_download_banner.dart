import 'dart:async';
import 'package:flutter/material.dart';
import 'package:tlucalendar/services/download_foreground_service.dart';

/// Banner that shows real-time progress of foreground download service
/// Polls SharedPreferences every 2 seconds to get progress
class ForegroundDownloadBanner extends StatefulWidget {
  const ForegroundDownloadBanner({Key? key}) : super(key: key);

  @override
  State<ForegroundDownloadBanner> createState() => _ForegroundDownloadBannerState();
}

class _ForegroundDownloadBannerState extends State<ForegroundDownloadBanner> {
  Timer? _pollTimer;
  bool _isDownloading = false;
  bool _isComplete = false;
  int _total = 0;
  int _completed = 0;
  String _currentSemester = '';
  bool _shouldHide = false;
  bool _completionMessageShown = false; // Track if we've already shown completion

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    // Check immediately
    _checkProgress();
    
    // Then check every second for faster updates
    _pollTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _checkProgress();
    });
  }

  Future<void> _checkProgress() async {
    if (!mounted) return;

    try {
      final progress = await DownloadForegroundService.getProgress();
      final inProgress = progress['inProgress'] as bool;
      final complete = progress['complete'] as bool;
      final total = progress['total'] as int;
      final completed = progress['completed'] as int;
      final currentSemester = progress['currentSemester'] as String;

      if (mounted) {
        setState(() {
          _isDownloading = inProgress;
          _isComplete = complete;
          _total = total;
          _completed = completed;
          _currentSemester = currentSemester;
        });

        // Auto-hide completion message after 5 seconds
        if (complete && !inProgress && !_shouldHide && !_completionMessageShown) {
          _completionMessageShown = true; // Mark as shown to prevent multiple triggers
          Future.delayed(const Duration(seconds: 5), () {
            if (mounted) {
              setState(() {
                _shouldHide = true;
              });
              // Stop polling after hide
              _pollTimer?.cancel();
            }
          });
        }
        
        // Reset completion flag if download starts again
        if (inProgress && _completionMessageShown) {
          _completionMessageShown = false;
          _shouldHide = false;
        }
      }
    } catch (e) {
      debugPrint('[ForegroundDownloadBanner] Error checking progress: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Don't show if not downloading and not showing completion
    if (!_isDownloading && (!_isComplete || _shouldHide)) {
      return const SizedBox.shrink();
    }

    final percent = _total > 0 ? ((_completed / _total) * 100).toInt() : 0;

    return Material(
      elevation: 4,
      color: _isComplete 
          ? Colors.green.withOpacity(0.95) 
          : Theme.of(context).primaryColor.withOpacity(0.95),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  if (_isDownloading)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  else
                    const Icon(Icons.check_circle, color: Colors.white, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isComplete 
                              ? '✅ Tải dữ liệu hoàn tất!'
                              : 'Đang tải dữ liệu offline...',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _currentSemester.isEmpty 
                              ? 'Đang xử lý...'
                              : _currentSemester,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$percent%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: percent / 100,
                  backgroundColor: Colors.white24,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                  minHeight: 6,
                ),
              ),
              if (_total > 0) ...[
                const SizedBox(height: 8),
                Text(
                  'Học kỳ: $_completed/$_total',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              if (_isComplete) ...[
                const SizedBox(height: 8),
                const Text(
                  '✓ Ứng dụng có thể hoạt động hoàn toàn offline',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ] else ...[
                const SizedBox(height: 8),
                const Text(
                  '📱 Bạn có thể tắt app, quá trình tải sẽ tiếp tục',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
