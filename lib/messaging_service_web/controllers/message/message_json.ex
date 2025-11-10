defmodule MessagingServiceWeb.MessageJSON do
  @moduledoc """
  Renders JSON responses for MessageController.
  """

  @doc """
  Renders a bad_request response, along with descriptions of the problems in the payload.
  """
  def bad_request(%{missing_fields: missing_fields}) do
    %{
      reason: "Payload is invalid",
      errors: missing_fields |> Enum.map(fn field -> "'#{field}' is required" end)
    }
  end
end
