defmodule Sideout.Scheduling.ShareToken do
  @moduledoc """
  Generates and validates share tokens for session signup links.
  Uses nanoid for URL-safe, unique identifiers.
  """

  @doc """
  Generates a new share token using nanoid.
  Returns a 21-character URL-safe string.
  """
  def generate do
    Nanoid.generate(21)
  end

  @doc """
  Validates that a token matches the expected format.
  Returns true if the token is a 21-character string containing only
  URL-safe characters (A-Z, a-z, 0-9, _, -).
  """
  def valid?(token) when is_binary(token) do
    String.match?(token, ~r/^[A-Za-z0-9_-]{21}$/)
  end

  def valid?(_), do: false
end
