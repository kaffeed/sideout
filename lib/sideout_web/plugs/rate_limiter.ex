defmodule SideoutWeb.Plugs.RateLimiter do
  @moduledoc """
  Rate limiting plug to prevent brute-force attacks on authentication endpoints.
  """
  import Plug.Conn
  import Phoenix.Controller

  def init(opts), do: opts

  @doc """
  Rate limits login attempts by IP address.
  Allows 5 attempts per minute per IP.
  """
  def call(conn, _opts) do
    ip_address = get_ip_address(conn)
    key = "login:#{ip_address}"

    case Hammer.check_rate(key, 60_000, 5) do
      {:allow, _count} ->
        conn

      {:deny, _limit} ->
        conn
        |> put_flash(:error, "Too many login attempts. Please try again in a minute.")
        |> redirect(to: "/users/log_in")
        |> halt()
    end
  end

  defp get_ip_address(conn) do
    case get_req_header(conn, "x-forwarded-for") do
      [ip | _] ->
        ip

      [] ->
        case conn.remote_ip do
          {a, b, c, d} -> "#{a}.#{b}.#{c}.#{d}"
          ip -> to_string(ip)
        end
    end
  end
end
