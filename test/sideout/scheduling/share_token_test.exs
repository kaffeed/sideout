defmodule Sideout.Scheduling.ShareTokenTest do
  use ExUnit.Case, async: true

  alias Sideout.Scheduling.ShareToken

  describe "generate/0" do
    test "generates a 21 character token" do
      token = ShareToken.generate()
      assert String.length(token) == 21
    end

    test "generates unique tokens" do
      token1 = ShareToken.generate()
      token2 = ShareToken.generate()

      assert token1 != token2
    end

    test "generates URL-safe tokens" do
      token = ShareToken.generate()

      # Should only contain alphanumeric characters, hyphens, and underscores
      assert token =~ ~r/^[A-Za-z0-9_-]+$/
    end

    test "generates multiple unique tokens" do
      tokens = for _ <- 1..100, do: ShareToken.generate()
      unique_tokens = Enum.uniq(tokens)

      # All 100 tokens should be unique
      assert length(unique_tokens) == 100
    end
  end

  describe "valid?/1" do
    test "returns true for valid 21-character token" do
      token = ShareToken.generate()
      assert ShareToken.valid?(token) == true
    end

    test "returns false for nil" do
      assert ShareToken.valid?(nil) == false
    end

    test "returns false for empty string" do
      assert ShareToken.valid?("") == false
    end

    test "returns false for token that's too short" do
      assert ShareToken.valid?("short") == false
    end

    test "returns false for token that's too long" do
      assert ShareToken.valid?("this_token_is_way_too_long_to_be_valid") == false
    end

    test "returns false for token with invalid characters" do
      assert ShareToken.valid?("invalid token with spaces") == false
      assert ShareToken.valid?("invalid@token#here!") == false
    end
  end
end
