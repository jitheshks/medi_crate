import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';
import 'http_client_factory.dart';
import 'ssl_security_context.dart';

/// Diagnostic result for individual network layers.
enum DiagnosticStatus { pass, fail, skipped }

/// NetworkDiagnosticReport aggregates test results across the complete network pipeline.
class NetworkDiagnosticReport {
  final DiagnosticStatus connectivity;
  final DiagnosticStatus internet;
  final DiagnosticStatus dns;
  final DiagnosticStatus tcp;
  final DiagnosticStatus tls;
  final DiagnosticStatus http;
  final DiagnosticStatus api;
  final DiagnosticStatus dio;
  final Map<String, dynamic> rawDetails;

  const NetworkDiagnosticReport({
    required this.connectivity,
    required this.internet,
    required this.dns,
    required this.tcp,
    required this.tls,
    required this.http,
    required this.api,
    this.dio = DiagnosticStatus.skipped,
    required this.rawDetails,
  });

  String toFormattedSummary() {
    final buffer = StringBuffer();
    buffer.writeln('==================================================');
    buffer.writeln('MEDICRATE NETWORK DIAGNOSTIC REPORT');
    buffer.writeln('==================================================');
    buffer.writeln('NETWORK TRANSPORT : ${_statusStr(connectivity)}');
    buffer.writeln('INTERNET REACHABLE: ${_statusStr(internet)}');
    buffer.writeln('DNS RESOLUTION    : ${_statusStr(dns)}');
    buffer.writeln('TCP (443)         : ${_statusStr(tcp)}');
    buffer.writeln('TLS HANDSHAKE     : ${_statusStr(tls)}');
    buffer.writeln('HTTP BASE         : ${_statusStr(http)}');
    buffer.writeln('API ENDPOINT      : ${_statusStr(api)}');
    buffer.writeln('DIO REQUEST       : ${_statusStr(dio)}');
    buffer.writeln('==================================================');
    return buffer.toString();
  }

  String _statusStr(DiagnosticStatus status) {
    switch (status) {
      case DiagnosticStatus.pass:
        return 'PASS';
      case DiagnosticStatus.fail:
        return 'FAIL';
      case DiagnosticStatus.skipped:
        return 'SKIPPED';
    }
  }
}

/// NetworkDiagnosticService performs safe, non-sensitive connectivity and TLS handshake
/// diagnostics on physical devices to identify root causes for network/TLS discrepancies.
class NetworkDiagnosticService {
  static const String defaultTargetHost =
      'phplaravel-1505866-6585565.cloudwaysapps.com';

  /// Runs comprehensive diagnostic checks across the complete network pipeline.
  static Future<NetworkDiagnosticReport> runDiagnostic({
    String host = defaultTargetHost,
    int port = 443,
  }) async {
    // Ensure TLS SecurityContext is loaded before running diagnostics
    if (!SslSecurityContext.isInitialized) {
      await SslSecurityContext.initialize();
    }

    final results = <String, dynamic>{
      'targetHost': host,
      'targetPort': port,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'platform': Platform.operatingSystem,
      'platformVersion': Platform.operatingSystemVersion,
      'dartVersion': Platform.version,
    };

    debugPrint(
      '🔍 [MEDICRATE_DIAGNOSTIC] Starting network diagnosis for $host:$port...',
    );

    DiagnosticStatus connectivityStatus = DiagnosticStatus.fail;
    DiagnosticStatus internetStatus = DiagnosticStatus.fail;
    DiagnosticStatus dnsStatus = DiagnosticStatus.fail;
    DiagnosticStatus tcpStatus = DiagnosticStatus.fail;
    DiagnosticStatus tlsStatus = DiagnosticStatus.fail;
    DiagnosticStatus httpStatus = DiagnosticStatus.fail;
    DiagnosticStatus apiStatus = DiagnosticStatus.fail;
    DiagnosticStatus dioStatus = DiagnosticStatus.fail;

    // 0a. Layer 1 Transport (connectivity_plus)
    try {
      final transports = await Connectivity().checkConnectivity().timeout(
        const Duration(seconds: 3),
        onTimeout: () => [ConnectivityResult.other],
      );
      results['transports'] = transports.map((t) => t.name).toList();
      final hasTransport =
          transports.isNotEmpty &&
          !transports.every((t) => t == ConnectivityResult.none);
      connectivityStatus = hasTransport
          ? DiagnosticStatus.pass
          : DiagnosticStatus.fail;
      debugPrint(
        '   ${hasTransport ? "✅" : "❌"} TRANSPORT: $connectivityStatus (${results['transports']})',
      );
    } catch (e) {
      results['transportError'] = e.toString();
      connectivityStatus = DiagnosticStatus.fail;
      debugPrint('   ❌ TRANSPORT: FAIL ($e)');
    }

    // 0b. Layer 2 Internet Access (internet_connection_checker_plus)
    try {
      final hasInternet = await InternetConnection().hasInternetAccess.timeout(
        const Duration(seconds: 4),
        onTimeout: () => false,
      );
      results['internetAccess'] = hasInternet;
      internetStatus = hasInternet
          ? DiagnosticStatus.pass
          : DiagnosticStatus.fail;
      debugPrint('   ${hasInternet ? "✅" : "❌"} INTERNET: $internetStatus');
    } catch (e) {
      results['internetError'] = e.toString();
      internetStatus = DiagnosticStatus.fail;
      debugPrint('   ❌ INTERNET: FAIL ($e)');
    }

    // 1. DNS Lookup (IPv4 & IPv6)
    try {
      final addresses = await InternetAddress.lookup(
        host,
      ).timeout(const Duration(seconds: 5));
      if (addresses.isNotEmpty) {
        dnsStatus = DiagnosticStatus.pass;
        results['dnsSuccess'] = true;
        results['resolvedAddresses'] = addresses.map((a) {
          return {
            'address': a.address,
            'type': a.type == InternetAddressType.IPv4 ? 'IPv4' : 'IPv6',
          };
        }).toList();
        debugPrint('   ✅ DNS: PASS (${results['resolvedAddresses']})');
      } else {
        results['dnsSuccess'] = false;
        results['dnsError'] = 'No addresses returned for host';
        debugPrint('   ❌ DNS: FAIL (empty address list)');
      }
    } catch (e) {
      dnsStatus = DiagnosticStatus.fail;
      results['dnsSuccess'] = false;
      results['dnsError'] = e.toString();
      debugPrint('   ❌ DNS: FAIL ($e)');
    }

    // 2. Raw TCP Socket Connect
    try {
      final socket = await Socket.connect(
        host,
        port,
        timeout: const Duration(seconds: 8),
      );
      tcpStatus = DiagnosticStatus.pass;
      results['tcpSuccess'] = true;
      results['remoteAddress'] = socket.remoteAddress.address;
      results['remotePort'] = socket.remotePort;
      await socket.close();
      debugPrint('   ✅ TCP: PASS (connected to $host:$port)');
    } catch (e) {
      tcpStatus = DiagnosticStatus.fail;
      results['tcpSuccess'] = false;
      results['tcpError'] = e.toString();
      if (e is SocketException && e.osError != null) {
        results['tcpErrno'] = e.osError!.errorCode;
        results['tcpOsMessage'] = e.osError!.message;
      }
      debugPrint('   ❌ TCP: FAIL ($e)');
    }

    // 3. TLS Handshake & Certificate Inspection (Augmented SslSecurityContext Validation)
    try {
      final secureSocket = await SecureSocket.connect(
        host,
        port,
        context: SslSecurityContext.context,
        timeout: const Duration(seconds: 10),
      );
      tlsStatus = DiagnosticStatus.pass;
      results['tlsSuccess'] = true;
      results['selectedProtocol'] = secureSocket.selectedProtocol;
      final cert = secureSocket.peerCertificate;
      if (cert != null) {
        results['certificateSubject'] = cert.subject;
        results['certificateIssuer'] = cert.issuer;
        results['certificateStart'] = cert.startValidity.toIso8601String();
        results['certificateEnd'] = cert.endValidity.toIso8601String();
      }
      await secureSocket.close();
      debugPrint(
        '   ✅ TLS: PASS (Protocol: ${results['selectedProtocol']}, Issuer: ${results['certificateIssuer']})',
      );
    } catch (e) {
      tlsStatus = DiagnosticStatus.fail;
      results['tlsSuccess'] = false;
      results['tlsError'] = e.toString();
      results['tlsErrorType'] = e.runtimeType.toString();
      if (e is HandshakeException && e.osError != null) {
        results['tlsOsError'] = e.osError!.message;
        results['tlsOsErrorCode'] = e.osError!.errorCode;
      }
      debugPrint('   ❌ TLS: FAIL ($e)');
    }

    // 4. Basic HTTP Client Check (Augmented HttpClientFactory Validation)
    try {
      final httpClient = HttpClientFactory.createHttpClient(
        connectTimeout: const Duration(seconds: 10),
      );
      final request = await httpClient.getUrl(
        Uri.parse('https://$host/api/v1'),
      );
      final response = await request.close();
      httpStatus = DiagnosticStatus.pass;
      results['httpSuccess'] = true;
      results['httpStatusCode'] = response.statusCode;
      httpClient.close();
      debugPrint('   ✅ HTTP: PASS (status ${response.statusCode})');
    } catch (e) {
      httpStatus = DiagnosticStatus.fail;
      results['httpSuccess'] = false;
      results['httpError'] = e.toString();
      debugPrint('   ❌ HTTP: FAIL ($e)');
    }

    // 5. API Endpoint Check (POST /auth/login)
    try {
      final httpClient = HttpClientFactory.createHttpClient(
        connectTimeout: const Duration(seconds: 10),
      );
      final request = await httpClient.postUrl(
        Uri.parse('https://$host/api/v1/auth/login'),
      );
      request.headers.set('Content-Type', 'application/json');
      request.headers.set('Accept', 'application/json');
      request.write(
        '{"email":"diagnostic_ping@example.com","password":"DiagnosticPing123!"}',
      );
      final response = await request.close();
      apiStatus = DiagnosticStatus.pass;
      results['apiSuccess'] = true;
      results['apiStatusCode'] = response.statusCode;
      httpClient.close();
      debugPrint(
        '   ✅ API: PASS (Laravel responded with status ${response.statusCode})',
      );
    } catch (e) {
      apiStatus = DiagnosticStatus.fail;
      results['apiSuccess'] = false;
      results['apiError'] = e.toString();
      debugPrint('   ❌ API: FAIL ($e)');
    }

    // 6. Dio Client Check (POST /auth/login through Dio with exact production configuration)
    try {
      final dioClient = Dio(
        BaseOptions(
          baseUrl: 'https://$host/api/v1',
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
          sendTimeout: const Duration(seconds: 10),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      );
      dioClient.httpClientAdapter = HttpClientFactory.createAdapter(
        connectTimeout: const Duration(seconds: 10),
      );
      final response = await dioClient.post(
        '/auth/login',
        data: {
          'email': 'diagnostic_ping@example.com',
          'password': 'DiagnosticPing123!',
        },
      );
      dioStatus = DiagnosticStatus.pass;
      results['dioSuccess'] = true;
      results['dioStatusCode'] = response.statusCode;
      debugPrint('   ✅ DIO: PASS (status ${response.statusCode})');
    } on DioException catch (e) {
      if (e.response != null) {
        // Backend responded with HTTP status (e.g. 401 Unauthorized / 422 Validation) -> Network & TLS passed!
        dioStatus = DiagnosticStatus.pass;
        results['dioSuccess'] = true;
        results['dioStatusCode'] = e.response?.statusCode;
        results['dioData'] = e.response?.data;
        debugPrint(
          '   ✅ DIO: PASS (Laravel reached, HTTP ${e.response?.statusCode})',
        );
      } else {
        dioStatus = DiagnosticStatus.fail;
        results['dioSuccess'] = false;
        results['dioError'] = e.toString();
        results['dioType'] = e.type.toString();
        results['dioUnderlyingError'] = e.error?.toString();
        debugPrint('   ❌ DIO: FAIL ($e)');
      }
    } catch (e) {
      dioStatus = DiagnosticStatus.fail;
      results['dioSuccess'] = false;
      results['dioError'] = e.toString();
      debugPrint('   ❌ DIO: FAIL ($e)');
    }

    final report = NetworkDiagnosticReport(
      connectivity: connectivityStatus,
      internet: internetStatus,
      dns: dnsStatus,
      tcp: tcpStatus,
      tls: tlsStatus,
      http: httpStatus,
      api: apiStatus,
      dio: dioStatus,
      rawDetails: results,
    );

    debugPrint(report.toFormattedSummary());
    return report;
  }
}
