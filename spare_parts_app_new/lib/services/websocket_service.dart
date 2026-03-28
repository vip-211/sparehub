import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:stomp_dart_client/stomp_dart_client.dart';
import '../utils/constants.dart';

class WebSocketService {
  StompClient? _client;
  static final StreamController<Map<String, dynamic>> orderUpdates =
      StreamController<Map<String, dynamic>>.broadcast();

  void connect(Function(Map<String, dynamic>) onMessageReceived,
      {String? role, int? userId}) {
    if (!Constants.useRemote || !Constants.enableWebSocket) {
      if (kDebugMode) {
        debugPrint('WebSocket Mock: Standalone mode active');
      }
      return;
    }

    final wsUrl = Constants.wsUrl;
    if (kDebugMode) {
      debugPrint('Connecting to WebSocket: $wsUrl');
    }

    _client = StompClient(
      config: StompConfig(
        url: wsUrl,
        stompConnectHeaders: const {
          // request heartbeats: 10s outgoing, 10s incoming
          'heart-beat': '10000,10000',
        },
        reconnectDelay: const Duration(seconds: 5), // Auto-reconnect after 5s
        onConnect: (frame) {
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
        onWebSocketError: (error) {
          debugPrint('WebSocket Error: $error');
          if (error.toString().contains('Failed host lookup')) {
            debugPrint(
                'Check your internet connection and the host URL: $wsUrl');
          }
        },
        onStompError: (frame) => debugPrint('STOMP Error: ${frame.body}'),
        onDisconnect: (frame) => debugPrint('WebSocket Disconnected'),
      ),
    );

    _client?.activate();
  }

  void disconnect() {
    _client?.deactivate();
  }
}
