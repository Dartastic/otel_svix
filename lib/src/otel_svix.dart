// Licensed under the Apache License, Version 2.0
// Copyright 2025, Mindful Software LLC, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';

import 'otel_svix_suppression.dart';

const _tracerName = 'dartastic_otel_libs_svix';

Tracer _tracer() => OTel.tracerProvider().getTracer(_tracerName);

class SvixResult {
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

class SvixCallResult<T> {
  const SvixCallResult({required this.value, this.result});
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
    attributes: OTel.attributesFromMap(m),
  );
  try {
    final r = await invoke();
    if (r.result != null) {
      final extras = <Attribute<Object>>[];
      if (r.result!.appId != null) {
        extras.add(OTel.attributeString('svix.app.id', r.result!.appId!));
      }
      if (r.result!.endpointId != null) {
        extras.add(OTel.attributeString(
          'svix.endpoint.id',
          r.result!.endpointId!,
        ));
      }
      if (r.result!.messageId != null) {
        extras.add(OTel.attributeString(
          'svix.message.id',
          r.result!.messageId!,
        ));
      }
      if (r.result!.attemptId != null) {
        extras.add(OTel.attributeString(
          'svix.attempt.id',
          r.result!.attemptId!,
        ));
      }
      if (r.result!.eventType != null) {
        extras.add(OTel.attributeString(
          'svix.event.type',
          r.result!.eventType!,
        ));
      }
      if (r.result!.channels != null) {
        extras.add(OTel.attributeString('svix.channels', r.result!.channels!));
      }
      if (r.result!.status != null) {
        extras.add(OTel.attributeString('svix.status', r.result!.status!));
        if (r.result!.status == 'fail') {
          span.setStatus(SpanStatusCode.Error, 'Svix delivery failed');
        }
      }
      if (r.result!.attemptNumber != null) {
        extras.add(OTel.attributeInt(
          'svix.attempt.number',
          r.result!.attemptNumber!,
        ));
      }
      if (r.result!.endpointStatusCode != null) {
        extras.add(OTel.attributeInt(
          'svix.endpoint.response.status_code',
          r.result!.endpointStatusCode!,
        ));
      }
      if (r.result!.endpointLatencyMs != null) {
        extras.add(OTel.attributeInt(
          'svix.endpoint.response.latency_ms',
          r.result!.endpointLatencyMs!,
        ));
      }
      if (r.result!.disabledEndpoint != null) {
        extras.add(OTel.attributeBool(
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
        extras.add(OTel.attributeInt(
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
      if (extras.isNotEmpty) span.addAttributes(OTel.attributes(extras));
    }
    return r.value;
  } catch (e, st) {
    span.addAttributes(OTel.attributes([
      OTel.attributeString(
        ErrorResource.errorType.key,
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
