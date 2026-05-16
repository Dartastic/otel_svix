// Licensed under the Apache License, Version 2.0
// Copyright 2025, Mindful Software LLC, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry/testing.dart';
import 'package:otel_svix/otel_svix.dart';
import 'package:test/test.dart';

void main() {
  late TestHarness harness;
  late InMemorySpanExporter spans;

  setUpAll(() async {
    harness = await maybeInitializeOtelForTest(
      serviceName: 'otel_svix-test',
    );
    spans = harness.spans;
  });

  setUp(() => harness.clear());

  Map<String, Object> attrsOf(Span s) =>
      {for (final a in s.attributes.toList()) a.key: a.value};

  test('message.create records app + event + channels', () async {
    await tracedSvix<String>(
      operation: 'message.create',
      invoke: () async => const SvixCallResult(
        value: 'ok',
        result: SvixResult(
          appId: 'app_1',
          messageId: 'msg_1',
          eventType: 'invoice.paid',
          channels: 'tenant_a,billing',
          status: 'success',
          attemptNumber: 1,
          endpointStatusCode: 200,
          statusCode: 200,
        ),
      ),
    );
    final a = attrsOf(spans.findSpanByName('svix message.create')!);
    expect(a['svix.app.id'], 'app_1');
    expect(a['svix.message.id'], 'msg_1');
    expect(a['svix.event.type'], 'invoice.paid');
    expect(a['svix.channels'], 'tenant_a,billing');
    expect(a['svix.status'], 'success');
  });

  test('auto-disabled endpoint sets span error', () async {
    await tracedSvix<String>(
      operation: 'message.attempt.resend',
      invoke: () async => const SvixCallResult(
        value: 'ok',
        result: SvixResult(
          endpointId: 'ep_1',
          status: 'fail',
          attemptNumber: 16,
          disabledEndpoint: true,
        ),
      ),
    );
    final s = spans.findSpanByName('svix message.attempt.resend')!;
    expect(s.status, SpanStatusCode.Error);
    final a = attrsOf(s);
    expect(a['svix.endpoint.disabled'], true);
    expect(a['svix.attempt.number'], 16);
  });

  test('suppression skips spans', () async {
    await runWithoutSvixInstrumentationAsync(() async {
      await tracedSvix<String>(
        operation: 'endpoint.create',
        invoke: () async => const SvixCallResult(value: 'v'),
      );
    });
    expect(spans.findSpansStartingWith('svix '), isEmpty);
  });
}
