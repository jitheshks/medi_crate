import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';

/// NetworkStatusModel encapsulates network interface transport and internet reachability.
class NetworkStatusModel {
  final List<ConnectivityResult> transports;
  final bool hasInternet;

  const NetworkStatusModel({
    required this.transports,
    required this.hasInternet,
  });

  bool get hasTransport =>
      transports.isNotEmpty && !transports.contains(ConnectivityResult.none);

  bool get isOnline => hasTransport && hasInternet;
}

/// ConnectivityService provides a two-layer network detection model:
/// Layer 1: Network Transport (Wi-Fi, Mobile, Ethernet, VPN via connectivity_plus)
/// Layer 2: Actual Internet Reachability (via internet_connection_checker_plus)
class ConnectivityService {
  final Connectivity? _connectivity;
  final InternetConnection? _internetConnection;
  final bool _isTest;
  final StreamController<bool> _controller = StreamController<bool>.broadcast();

  StreamSubscription<List<ConnectivityResult>>? _transportSubscription;
  StreamSubscription<InternetStatus>? _internetSubscription;

  ConnectivityService({
    Connectivity? connectivity,
    InternetConnection? internetConnection,
    bool? autoInitialize,
  }) : _isTest = Platform.environment.containsKey('FLUTTER_TEST'),
       _connectivity =
           connectivity ??
           ((autoInitialize ??
                   !Platform.environment.containsKey('FLUTTER_TEST'))
               ? Connectivity()
               : null),
       _internetConnection =
           internetConnection ??
           ((autoInitialize ??
                   !Platform.environment.containsKey('FLUTTER_TEST'))
               ? InternetConnection()
               : null) {
    if (autoInitialize ?? !Platform.environment.containsKey('FLUTTER_TEST')) {
      _initSubscriptions();
    }
  }

  void _initSubscriptions() {
    // Listen to Layer 1 (Transport changes)
    _transportSubscription = _connectivity?.onConnectivityChanged.listen((
      List<ConnectivityResult> results,
    ) async {
      final hasTransport = _hasTransport(results);
      if (!hasTransport) {
        _emitStatus(false);
      } else {
        // If transport became available, verify actual reachability
        final hasInternet = await _checkInternetAccessSafe();
        _emitStatus(hasInternet);
      }
    });

    // Listen to Layer 2 (Internet status changes)
    _internetSubscription = _internetConnection?.onStatusChange.listen((
      InternetStatus status,
    ) {
      _emitStatus(status == InternetStatus.connected);
    });
  }

  void _emitStatus(bool isOnline) {
    if (!_controller.isClosed) {
      _controller.add(isOnline);
    }
  }

  /// Stream of actual Internet connectivity states.
  Stream<bool> get onConnectivityChanged => _controller.stream;

  /// Layer 1: Gets current active network transports.
  Future<List<ConnectivityResult>> getTransports() async {
    if (_isTest && _connectivity == null) return [ConnectivityResult.none];
    if (_connectivity == null) return [ConnectivityResult.wifi];
    try {
      return await _connectivity.checkConnectivity().timeout(
        const Duration(seconds: 3),
        onTimeout: () => [ConnectivityResult.other],
      );
    } catch (_) {
      return [ConnectivityResult.other];
    }
  }

  /// Layer 2: Checks actual Internet reachability with finite timeout.
  Future<bool> checkInternetAccess() async {
    return await _checkInternetAccessSafe();
  }

  Future<bool> _checkInternetAccessSafe() async {
    if (_isTest && _internetConnection == null) return false;
    if (_internetConnection == null) return true;
    try {
      return await _internetConnection.hasInternetAccess.timeout(
        const Duration(seconds: 3),
        onTimeout: () {
          // If check times out, fallback to true so Dio can attempt the real API call
          return true;
        },
      );
    } catch (_) {
      return true;
    }
  }

  /// Combined two-layer connectivity check.
  /// 1. If no transport exists (e.g. Airplane mode / Wi-Fi off), returns false immediately.
  /// 2. If transport exists, checks actual Internet access with timeout.
  Future<bool> checkConnectivity() async {
    if (_isTest && _connectivity == null) return false;
    try {
      final transports = await getTransports();
      if (!_hasTransport(transports)) {
        return false;
      }
      return await _checkInternetAccessSafe();
    } catch (_) {
      return true;
    }
  }

  bool _hasTransport(List<ConnectivityResult> results) {
    if (results.isEmpty) return true;
    if (results.length == 1 && results.first == ConnectivityResult.none) {
      return false;
    }
    return results.any(
      (r) =>
          r == ConnectivityResult.mobile ||
          r == ConnectivityResult.wifi ||
          r == ConnectivityResult.ethernet ||
          r == ConnectivityResult.vpn ||
          r == ConnectivityResult.other,
    );
  }

  /// Detailed snapshot of current two-layer network state.
  Future<NetworkStatusModel> getDetailedStatus() async {
    final transports = await getTransports();
    final hasTransport = _hasTransport(transports);
    final hasInternet = hasTransport ? await _checkInternetAccessSafe() : false;
    return NetworkStatusModel(transports: transports, hasInternet: hasInternet);
  }

  void dispose() {
    _transportSubscription?.cancel();
    _transportSubscription = null;
    _internetSubscription?.cancel();
    _internetSubscription = null;
    _controller.close();
  }
}
