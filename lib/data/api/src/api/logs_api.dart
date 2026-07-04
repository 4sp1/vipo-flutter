// ignore_for_file: type=lint
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

import 'dart:async';

// ignore: unused_import
import 'dart:convert';
import 'package:vipo/data/api/src/deserialize.dart';
import 'package:dio/dio.dart';

import 'package:vipo/data/api/src/model/create_log_entry_request.dart';
import 'package:vipo/data/api/src/model/error.dart';
import 'package:vipo/data/api/src/model/log_action.dart';
import 'package:vipo/data/api/src/model/log_entry.dart';
import 'package:vipo/data/api/src/model/log_entry_list.dart';
import 'package:vipo/data/api/src/model/pomodoro_state.dart';

class LogsApi {

  final Dio _dio;

  const LogsApi(this._dio);

  /// Create a log entry
  /// 
  ///
  /// Parameters:
  /// * [createLogEntryRequest] 
  /// * [cancelToken] - A [CancelToken] that can be used to cancel the operation
  /// * [headers] - Can be used to add additional headers to the request
  /// * [extras] - Can be used to add flags to the request
  /// * [validateStatus] - A [ValidateStatus] callback that can be used to determine request success based on the HTTP status of the response
  /// * [onSendProgress] - A [ProgressCallback] that can be used to get the send progress
  /// * [onReceiveProgress] - A [ProgressCallback] that can be used to get the receive progress
  ///
  /// Returns a [Future] containing a [Response] with a [LogEntry] as data
  /// Throws [DioException] if API call or serialization fails
  Future<Response<LogEntry>> createLogEntry({ 
    required CreateLogEntryRequest createLogEntryRequest,
    CancelToken? cancelToken,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? extra,
    ValidateStatus? validateStatus,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    final _path = r'/logs';
    final _options = Options(
      method: r'POST',
      headers: <String, dynamic>{
        ...?headers,
      },
      extra: <String, dynamic>{
        'secure': <Map<String, String>>[],
        ...?extra,
      },
      contentType: 'application/json',
      validateStatus: validateStatus,
    );

    dynamic _bodyData;

    try {
      _bodyData = jsonEncode(createLogEntryRequest);

    } catch(error, stackTrace) {
      throw DioException(
         requestOptions: _options.compose(
          _dio.options,
          _path,
        ),
        type: DioExceptionType.unknown,
        error: error,
        stackTrace: stackTrace,
      );
    }

    final _response = await _dio.request<Object>(
      _path,
      data: _bodyData,
      options: _options,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
    );

    LogEntry? _responseData;

    try {
final rawData = _response.data;
_responseData = rawData == null ? null : deserialize<LogEntry, LogEntry>(rawData, 'LogEntry', growable: true);

    } catch (error, stackTrace) {
      throw DioException(
        requestOptions: _response.requestOptions,
        response: _response,
        type: DioExceptionType.unknown,
        error: error,
        stackTrace: stackTrace,
      );
    }

    return Response<LogEntry>(
      data: _responseData,
      headers: _response.headers,
      isRedirect: _response.isRedirect,
      requestOptions: _response.requestOptions,
      redirects: _response.redirects,
      statusCode: _response.statusCode,
      statusMessage: _response.statusMessage,
      extra: _response.extra,
    );
  }

  /// List log entries
  /// 
  ///
  /// Parameters:
  /// * [action] 
  /// * [session] 
  /// * [from] - Filter entries from this timestamp (inclusive)
  /// * [to] - Filter entries up to this timestamp (inclusive)
  /// * [limit] 
  /// * [offset] 
  /// * [cancelToken] - A [CancelToken] that can be used to cancel the operation
  /// * [headers] - Can be used to add additional headers to the request
  /// * [extras] - Can be used to add flags to the request
  /// * [validateStatus] - A [ValidateStatus] callback that can be used to determine request success based on the HTTP status of the response
  /// * [onSendProgress] - A [ProgressCallback] that can be used to get the send progress
  /// * [onReceiveProgress] - A [ProgressCallback] that can be used to get the receive progress
  ///
  /// Returns a [Future] containing a [Response] with a [LogEntryList] as data
  /// Throws [DioException] if API call or serialization fails
  Future<Response<LogEntryList>> listLogEntries({ 
    LogAction? action,
    PomodoroState? session,
    DateTime? from,
    DateTime? to,
    int? limit = 50,
    int? offset = 0,
    CancelToken? cancelToken,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? extra,
    ValidateStatus? validateStatus,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    final _path = r'/logs';
    final _options = Options(
      method: r'GET',
      headers: <String, dynamic>{
        ...?headers,
      },
      extra: <String, dynamic>{
        'secure': <Map<String, String>>[],
        ...?extra,
      },
      validateStatus: validateStatus,
    );

    final _queryParameters = <String, dynamic>{
      if (action != null) r'action': action,
      if (session != null) r'session': session,
      if (from != null) r'from': from,
      if (to != null) r'to': to,
      if (limit != null) r'limit': limit,
      if (offset != null) r'offset': offset,
    };

    final _response = await _dio.request<Object>(
      _path,
      options: _options,
      queryParameters: _queryParameters,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
    );

    LogEntryList? _responseData;

    try {
final rawData = _response.data;
_responseData = rawData == null ? null : deserialize<LogEntryList, LogEntryList>(rawData, 'LogEntryList', growable: true);

    } catch (error, stackTrace) {
      throw DioException(
        requestOptions: _response.requestOptions,
        response: _response,
        type: DioExceptionType.unknown,
        error: error,
        stackTrace: stackTrace,
      );
    }

    return Response<LogEntryList>(
      data: _responseData,
      headers: _response.headers,
      isRedirect: _response.isRedirect,
      requestOptions: _response.requestOptions,
      redirects: _response.redirects,
      statusCode: _response.statusCode,
      statusMessage: _response.statusMessage,
      extra: _response.extra,
    );
  }

}
