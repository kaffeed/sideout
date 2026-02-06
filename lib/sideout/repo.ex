defmodule Sideout.Repo do
  use Ecto.Repo,
    otp_app: :sideout,
    adapter: Ecto.Adapters.Postgres
end
