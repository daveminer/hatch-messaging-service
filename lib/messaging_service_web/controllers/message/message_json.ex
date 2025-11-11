defmodule MessagingServiceWeb.MessageJSON do
  @moduledoc """
  Renders JSON responses for MessageController.
  """

  def bad_request(%{missing_fields: missing_fields}) do
    %{
      reason: "Payload is missing required fields",
      errors: missing_fields |> Enum.map(fn field -> "'#{field}' is required" end)
    }
  end

  def bad_request() do
    %{
      reason: "Bad request",
      errors: []
    }
  end
end
