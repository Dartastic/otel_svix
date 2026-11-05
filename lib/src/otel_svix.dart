// Licensed under the Apache License, Version 2.0
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';

import 'otel_svix_suppression.dart';

const _tracerName = 'dartastic_otel_libs_svix';

APITracer _tracer() => OTelAPI.tracerProvider().getTracer(_tracerName);

class SvixResult {
  /// Creates a result.
  const SvixResult({
    this.appId,
    this.endpointId,
    this.messageId,
    this.attemptId,
    this.eventType,
    this.channels,
    this.status,
    this.attemptNumber,
    this.endpointStatusCode,
    this.endpointLatencyMs,
    this.disabledEndpoint,
    this.statusCode,
  });

  /// Svix application (tenant scope).
  final String? appId;

  final String? endpointId;
  final String? messageId;
  final String? attemptId;
  final String? eventType;

  /// Comma-separated channels (Svix filters delivery by channel).
  final String? channels;

  /// `success` / `pending` / `fail` / `sending`.
  final String? status;

  /// 1 for first send; subsequent values are retries from Svix's
  /// exponential schedule.
  final int? attemptNumber;

  /// Customer endpoint's HTTP response code.
  final int? endpointStatusCode;

  final int? endpointLatencyMs;

  /// `true` when Svix auto-disabled the endpoint after repeated
  /// failures.
  final bool? disabledEndpoint;

  /// Svix control-plane API status code.
  final int? statusCode;
}

/// What a traced call returned: the value for the caller plus fields
/// recorded on the span.
class SvixCallResult<T> {
  /// Creates a call result.
  const SvixCallResult({required this.value, this.result});

  /// The value returned to the caller.
  final T value;
  final SvixResult? result;
}

/// Wraps a Svix API call in a CLIENT span. [operation] is one of
/// `message.create`, `message.get`, `message.attempt.list`,
/// `message.attempt.resend`, `application.create`, `endpoint.create`,
/// `endpoint.recover`, `event_type.create`.
Future<T> tracedSvix<T>({
  required String operation,
  required Future<SvixCallResult<T>> Function() invoke,
}) async {
  if (svixInstrumentationSuppressed()) {
    final r = await invoke();
    return r.value;
  }
  final m = <String, Object>{
    'rpc.system': 'svix',
    'rpc.method': operation,
    'svix.operation': operation,
  };

  final span = _tracer().startSpan(
    'svix $operation',
    kind: SpanKind.client,
    attributes: OTelAPI.attributesFromMap(m),
  );
  try {
    final r = await invoke();
    if (r.result != null) {
      final extras = <Attribute<Object>>[];
      if (r.result!.appId != null) {
        extras.add(OTelAPI.attributeString('svix.app.id', r.result!.appId!));
      }
      if (r.result!.endpointId != null) {
        extras.add(OTelAPI.attributeString(
          'svix.endpoint.id',
          r.result!.endpointId!,
        ));
      }
      if (r.result!.messageId != null) {
        extras.add(OTelAPI.attributeString(
          'svix.message.id',
          r.result!.messageId!,
        ));
      }
      if (r.result!.attemptId != null) {
        extras.add(OTelAPI.attributeString(
          'svix.attempt.id',
          r.result!.attemptId!,
        ));
      }
      if (r.result!.eventType != null) {
        extras.add(OTelAPI.attributeString(
          'svix.event.type',
          r.result!.eventType!,
        ));
      }
      if (r.result!.channels != null) {
        extras
            .add(OTelAPI.attributeString('svix.channels', r.result!.channels!));
      }
      if (r.result!.status != null) {
        extras.add(OTelAPI.attributeString('svix.status', r.result!.status!));
        if (r.result!.status == 'fail') {
          span.setStatus(SpanStatusCode.Error, 'Svix delivery failed');
        }
      }
      if (r.result!.attemptNumber != null) {
        extras.add(OTelAPI.attributeInt(
          'svix.attempt.number',
          r.result!.attemptNumber!,
        ));
      }
      if (r.result!.endpointStatusCode != null) {
        extras.add(OTelAPI.attributeInt(
          'svix.endpoint.response.status_code',
          r.result!.endpointStatusCode!,
        ));
      }
      if (r.result!.endpointLatencyMs != null) {
        extras.add(OTelAPI.attributeInt(
          'svix.endpoint.response.latency_ms',
          r.result!.endpointLatencyMs!,
        ));
      }
      if (r.result!.disabledEndpoint != null) {
        extras.add(OTelAPI.attributeBool(
          'svix.endpoint.disabled',
          r.result!.disabledEndpoint!,
        ));
        if (r.result!.disabledEndpoint!) {
          span.setStatus(
            SpanStatusCode.Error,
            'Svix endpoint auto-disabled',
          );
        }
      }
      if (r.result!.statusCode != null) {
        extras.add(OTelAPI.attributeInt(
          'http.response.status_code',
          r.result!.statusCode!,
        ));
        if (r.result!.statusCode! >= 400) {
          span.setStatus(
            SpanStatusCode.Error,
            'Svix HTTP ${r.result!.statusCode}',
          );
        }
      }
      if (extras.isNotEmpty) span.addAttributes(OTelAPI.attributes(extras));
    }
    return r.value;
  } catch (e, st) {
    span.addAttributes(OTelAPI.attributes([
      OTelAPI.attributeString(
        ErrorAttributes.errorType.key,
        e.runtimeType.toString(),
      ),
    ]));
    span.recordException(e, stackTrace: st);
    span.setStatus(SpanStatusCode.Error, e.toString());
    rethrow;
  } finally {
    span.end();
  }
}
