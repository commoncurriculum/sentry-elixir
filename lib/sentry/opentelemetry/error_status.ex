if Sentry.OpenTelemetry.VersionChecker.tracing_compatible?() do
  defmodule Sentry.OpenTelemetry.ErrorStatus do
    @moduledoc false

    require OpenTelemetry.Tracer, as: Tracer

    alias Sentry.Event

    @spec mark_current_span(Event.t()) :: :ok
    def mark_current_span(%Event{level: level} = event) when level in [:error, :fatal] do
      if Sentry.Config.tracing?() do
        {error_type, message} = error(event)
        Tracer.set_attribute(:"error.type", error_type)
        Tracer.set_status(:error, message)
      end

      :ok
    end

    def mark_current_span(%Event{}), do: :ok

    defp error(%Event{original_exception: exception}) when is_exception(exception),
      do: {inspect(exception.__struct__), Exception.message(exception)}

    defp error(%Event{message: %Sentry.Interfaces.Message{formatted: message}}),
      do: {"_OTHER", message}

    defp error(%Event{}), do: {"_OTHER", ""}
  end
end
