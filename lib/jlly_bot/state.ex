defmodule JllyBot.State do
  use GenServer
  require Logger

  def sub_tiktok(guild_id, tiktok_id) do
    GenServer.call(__MODULE__, {:add_tiktok_sub, guild_id, tiktok_id})
  end

  def guild_reset(guild_id) do
    GenServer.call(__MODULE__, {:reset_guild, guild_id})
  end

  def guild_config(guild_id) do
    GenServer.call(__MODULE__, {:get_guild_config, guild_id})
  end

  def save() do
    GenServer.cast(__MODULE__, :save)
  end

  # genServer
  @filename "./state.etf"

  def start_link(_ \\ nil) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  @impl GenServer
  def init(_) do
    state =
      with {:ok, file} <- File.read(@filename) do
        :erlang.binary_to_term(file)
      else
        {:error, :enoent} ->
          Logger.info("State could not be found. Creating new")
          %{}
      end

    {:ok, state}
  end

  @impl GenServer
  def handle_call({:add_tiktok_sub, guild_id, tiktok_id}, _from, state) do
    guild = Map.get(state, guild_id, %{})
    guild_tiktoks = Map.get(guild, :tiktok, %{})
    |> Map.put_new(tiktok_id, 0)

    guild = Map.put(guild, :tiktok, guild_tiktoks)
    state = Map.put(state, guild_id, guild)

    {:reply, :ok, state, {:continue, :save}}
  end

  @impl GenServer
  def handle_call({:reset_guild, id}, _from, state) do
    guild = Map.get(state, id)
    state = Map.delete(state, id)
    {:reply, guild, state, {:continue, :save}}
  end

  @impl GenServer
  def handle_call({:get_guild_config, guild_id}, _from, state) do
    {:reply, Map.get(state, guild_id), state}
  end

  @impl GenServer
  def handle_continue(:save, state) do
    save(state)
  end

  @impl GenServer
  def handle_cast(:save, state) do
    save(state)
  end

  defp save(state) do
    File.write(@filename, :erlang.term_to_binary(state))

    {:noreply, state, state}
  end
end
