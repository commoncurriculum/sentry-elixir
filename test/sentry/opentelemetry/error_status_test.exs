defmodule Sentry.OpenTelemetry.ErrorStatusTest do
  use Sentry.Case, async: false

  @moduletag send_result: :none

  require OpenTelemetry.Tracer, as: Tracer

  import Sentry.TestHelpers

  setup do
    setup_bypass()
  end

  @tag span_storage: true
  test "a captured exception fails the current span", %{bypass: bypass} do
    put_test_config(traces_sample_rate: 1.0)
    ref = setup_bypass_envelope_collector(bypass)

    Tracer.with_span "work" do
      Sentry.capture_exception(%RuntimeError{message: "boom"})
    end

    [tx] = collect_sentry_transactions(ref, 1)
    assert tx["contexts"]["trace"]["data"]["otel.status_code"] == "ERROR"
    assert tx["contexts"]["trace"]["data"]["otel.status_description"] == "boom"
    assert tx["contexts"]["trace"]["data"]["error.type"] == "RuntimeError"
  end

  @tag span_storage: true
  test "a captured error message fails the current span", %{bypass: bypass} do
    put_test_config(traces_sample_rate: 1.0)
    ref = setup_bypass_envelope_collector(bypass)

    Tracer.with_span "work" do
      Sentry.capture_message("payment failed", level: :error)
    end

    [tx] = collect_sentry_transactions(ref, 1)
    assert tx["contexts"]["trace"]["data"]["otel.status_code"] == "ERROR"
    assert tx["contexts"]["trace"]["data"]["otel.status_description"] == "payment failed"
    assert tx["contexts"]["trace"]["data"]["error.type"] == "_OTHER"
  end

  @tag span_storage: true
  test "a warning, or an event before_send drops, leaves the span alone", %{bypass: bypass} do
    put_test_config(traces_sample_rate: 1.0)
    ref = setup_bypass_envelope_collector(bypass)

    Tracer.with_span "work" do
      Sentry.capture_message("slow", level: :warning)

      Sentry.capture_exception(%RuntimeError{message: "boom"},
        before_send: fn _event -> false end
      )
    end

    [tx] = collect_sentry_transactions(ref, 1)
    refute Map.has_key?(tx["contexts"]["trace"]["data"], "otel.status_code")
    refute Map.has_key?(tx["contexts"]["trace"]["data"], "error.type")
  end
end
