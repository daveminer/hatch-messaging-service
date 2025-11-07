defmodule HatchMessagingService.Repo do
  use Ecto.Repo,
    otp_app: :hatch_messaging_service,
    adapter: Ecto.Adapters.Postgres
end
