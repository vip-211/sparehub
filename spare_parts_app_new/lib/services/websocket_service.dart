import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:stomp_dart_client/stomp_dart_client.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../utils/constants.dart';

class WebSocketService {
  StompClient? _client;
  static final StreamController<Map<String, dynamic>> orderUpdates =
      StreamController<Map<String, dynamic>>.broadcast();

  // Connectivity and Retry logic
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isManualDisconnect = false;
  int _retryCount = 0;
  static const int _maxRetries = 10;
  static const Duration _baseRetryDelay = Duration(seconds: 2);

  void connect(Function(Map<String, dynamic>) onMessageReceived,
      {String? role, int? userId}) async {
    if (!Constants.useRemote || !Constants.enableWebSocket) {
      if (kDebugMode) {
        debugPrint('WebSocket Mock: Standalone mode active');
      }
      return;
    }

    _isManualDisconnect = false;
    _retryCount = 0;

    // Start listening for connectivity changes
    _connectivitySubscription?.cancel();
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((results) {
      final isConnected = results.any((r) => r != ConnectivityResult.none);
      if (isConnected && _client != null && !_client!.connected && !_isManualDisconnect) {
        if (kDebugMode) debugPrint('WebSocket: Network restored, attempting reconnect...');
        _client?.activate();
      }
    });

    final wsUrl = Constants.wsUrl;
    if (kDebugMode) {
      debugPrint('Connecting to WebSocket: $wsUrl');
    }

    _client = StompClient(
      config: StompConfig(
        url: wsUrl,
        stompConnectHeaders: const {
          'heart-beat': '10000,10000',
        },
        // Exponential backoff implemented via onWebSocketError instead of fixed reconnectDelay
        reconnectDelay: const Duration(seconds: 0), 
        onConnect: (frame) {
          _retryCount = 0;
          if (kDebugMode) {
            debugPrint('WebSocket Connected: ${frame.headers}');
          }

          // 1. Subscribe to general broadcast notifications
          _client?.subscribe(
            destination: '/topic/notifications',
            callback: (frame) {
              if (frame.body != null) {
                final data = jsonDecode(frame.body!);
                onMessageReceived(data);
              }
            },
          );

          // 2. Subscribe to role-specific notifications
          if (role != null && role.isNotEmpty) {
            final roles = role
                .split(',')
                .map((e) => e.trim())
                .where((e) => e.isNotEmpty)
                .toList();
            bool isAdmin = false;
            for (final r in roles) {
              _client?.subscribe(
                destination: '/topic/notifications/$r',
                callback: (frame) {
                  if (frame.body != null) {
                    final data = jsonDecode(frame.body!);
                    onMessageReceived(data);
                  }
                },
              );
              if (r == 'ROLE_ADMIN' || r == 'ROLE_SUPER_MANAGER') {
                isAdmin = true;
              }
            }
            // Admin/Super Manager: subscribe to all order updates once
            if (isAdmin) {
              _client?.subscribe(
                destination: '/topic/admin/orders',
                callback: (frame) {
                  if (frame.body != null) {
                    final data = jsonDecode(frame.body!);
                    orderUpdates.add(data);
                    onMessageReceived({'type': 'ORDER_UPDATE', ...data});
                  }
                },
              );
            }
          }

          // 3. Subscribe to user-specific notifications
          if (userId != null) {
            _client?.subscribe(
              destination: '/user/$userId/queue/notifications',
              callback: (frame) {
                if (frame.body != null) {
                  final data = jsonDecode(frame.body!);
                  onMessageReceived(data);
                }
              },
            );
            // User-specific order updates
            _client?.subscribe(
              destination: '/user/$userId/queue/orders',
              callback: (frame) {
                if (frame.body != null) {
                  final data = jsonDecode(frame.body!);
                  orderUpdates.add(data);
                  onMessageReceived({'type': 'ORDER_UPDATE', ...data});
                }
              },
            );
          }
        },
        onWebSocketError: (error) async {
          if (_isManualDisconnect) return;

          final connectivity = await Connectivity().checkConnectivity();
          final hasNetwork = connectivity.any((r) => r != ConnectivityResult.none);

          if (!hasNetwork) {
            if (kDebugMode) debugPrint('WebSocket: No network. Waiting for connectivity change...');
            return;
          }

          if (_retryCount < _maxRetries) {
            _retryCount++;
            final delaySeconds = (_baseRetryDelay.inSeconds * _retryCount).clamp(2, 30);
            if (kDebugMode) debugPrint('WebSocket Error: $error. Retrying in $delaySeconds s (Attempt $_retryCount/$_maxRetries)');
            
            Future.delayed(Duration(seconds: delaySeconds), () {
              if (!_isManualDisconnect && (_client == null || !_client!.connected)) {
                _client?.activate();
              }
            });
          } else {
            if (kDebugMode) debugPrint('WebSocket: Max retries reached. Stopping reconnect loop.');
          }
        },
        onStompError: (frame) => debugPrint('STOMP Error: ${frame.body}'),
        onDisconnect: (frame) {
          if (kDebugMode) debugPrint('WebSocket Disconnected');
        },
      ),
    );

    _client?.activate();
  }

  void disconnect() {
    _isManualDisconnect = true;
    _connectivitySubscription?.cancel();
    _client?.deactivate();
  }
}
