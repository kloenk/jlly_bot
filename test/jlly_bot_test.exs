defmodule JllyBotTest do
  use ExUnit.Case
  doctest JllyBot

  test "greets the world" do
    assert JllyBot.hello() == :world
  end
end
