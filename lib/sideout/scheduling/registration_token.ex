defmodule Sideout.Scheduling.RegistrationToken do
  @moduledoc """
  Handles generation and verification of cancellation tokens for registrations.

  Tokens are URL-safe, cryptographically random strings that allow players
  to cancel their registrations without authentication.
  """

  @token_length 32

  @doc """
  Generates a unique, URL-safe cancellation token.

  ## Examples

      iex> generate_cancellation_token()
      "a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6"
  """
  def generate_cancellation_token do
    :crypto.strong_rand_bytes(@token_length)
    |> Base.url_encode64(padding: false)
    |> binary_part(0, @token_length)
  end

  @doc """
  Verifies that a token is valid (non-empty and correct length).

  ## Examples

      iex> verify_token("a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6")
      :ok
      
      iex> verify_token("")
      {:error, :invalid_token}
      
      iex> verify_token(nil)
      {:error, :invalid_token}
  """
  def verify_token(token) when is_binary(token) and byte_size(token) == @token_length do
    :ok
  end

  def verify_token(_token) do
    {:error, :invalid_token}
  end

  @doc """
  Checks if a registration has passed its cancellation deadline.

  Returns true if the current time is past the session date minus the
  cancellation deadline hours.

  ## Examples

      iex> session = %{date: ~D[2026-02-10], cancellation_deadline_hours: 24}
      iex> token_expired?(session, ~U[2026-02-08 12:00:00Z])
      false
      
      iex> session = %{date: ~D[2026-02-10], cancellation_deadline_hours: 24}
      iex> token_expired?(session, ~U[2026-02-09 12:00:00Z])
      true
  """
  def token_expired?(session, current_datetime \\ DateTime.utc_now()) do
    session_datetime = DateTime.new!(session.date, ~T[00:00:00], "Etc/UTC")
    deadline = DateTime.add(session_datetime, -session.cancellation_deadline_hours, :hour)

    DateTime.compare(current_datetime, deadline) == :gt
  end
end
