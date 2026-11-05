// Licensed under the Apache License, Version 2.0
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:otel_svix/otel_svix.dart';

/// Traces Svix calls with OpenTelemetry.
///
/// `otel_svix` depends on the OpenTelemetry API only, so the application
/// initializes an SDK once at startup. Wrap each Svix call in
/// [tracedSvix]; the `invoke` callback makes the real call and reports what
/// came back, which is recorded on the span.
Future<void> main() async {
  await OTel.initialize(serviceName: 'svix-example');

  // Wraps a Svix API call in a CLIENT span.
  final svixId = await tracedSvix<String>(
    operation: 'message.create',
    invoke: () async {
      // Make the Svix call here, then report what it returned.
      const id = 'svix_8f3a2c';
      return const SvixCallResult(
          value: id,
          result: SvixResult(
              appId: 'app_8f3a2c',
              endpointId: 'endpoint_8f3a2c',
              messageId: 'message_8f3a2c',
              attemptId: 'attempt_8f3a2c',
              eventType: 'order.created',
              channels: 'orders',
              status: 'success',
              attemptNumber: 1,
              endpointStatusCode: 201,
              endpointLatencyMs: 120,
              disabledEndpoint: true,
              statusCode: 201));
    },
  );
  OTelLog.info('tracedSvix message.create returned $svixId');

  // Calls that should not be traced, such as health checks, run inside
  // runWithoutSvixInstrumentationAsync.
  await runWithoutSvixInstrumentationAsync(
    () => tracedSvix<String>(
      operation: 'message.create',
      invoke: () async {
        const id = 'svix_8f3a2c';
        return const SvixCallResult(
            value: id,
            result: SvixResult(
                appId: 'app_8f3a2c',
                endpointId: 'endpoint_8f3a2c',
                messageId: 'message_8f3a2c',
                attemptId: 'attempt_8f3a2c',
                eventType: 'order.created',
                channels: 'orders',
                status: 'success',
                attemptNumber: 1,
                endpointStatusCode: 201,
                endpointLatencyMs: 120,
                disabledEndpoint: true,
                statusCode: 201));
      },
    ),
  );

  await OTel.shutdown();
}
