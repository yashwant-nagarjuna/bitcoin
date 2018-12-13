defmodule Bitcoin.Repo do
  use Ecto.Repo,
    otp_app: :bitcoin,
    adapter: Ecto.Adapters.Postgres
end
