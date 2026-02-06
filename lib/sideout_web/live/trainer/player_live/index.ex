defmodule SideoutWeb.Trainer.PlayerLive.Index do
  use SideoutWeb, :live_view

  alias Sideout.Scheduling
  alias Sideout.Scheduling.Player

  @impl true
  def mount(_params, _session, socket) do
    {:ok, load_players(socket, %{})}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Players")
    |> assign(:player, nil)
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Player")
    |> assign(:player, %Player{})
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    player = Scheduling.get_player!(id)

    socket
    |> assign(:page_title, "Edit Player")
    |> assign(:player, player)
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    player = Scheduling.get_player!(id)
    {:ok, _} = Scheduling.delete_player(player)

    {:noreply, load_players(socket, socket.assigns.search_params)}
  end

  @impl true
  def handle_event("search", %{"search" => search}, socket) do
    search_params = %{search: search}
    {:noreply, load_players(socket, search_params)}
  end

  @impl true
  def handle_event("clear_search", _params, socket) do
    {:noreply, load_players(socket, %{})}
  end

  @impl true
  def handle_event("sort", %{"field" => field}, socket) do
    current_sort = socket.assigns.sort_by
    current_order = socket.assigns.sort_order

    # Toggle order if clicking same field, otherwise default to asc
    {new_field, new_order} =
      if to_string(current_sort) == field do
        {String.to_atom(field), toggle_order(current_order)}
      else
        {String.to_atom(field), :asc}
      end

    socket =
      socket
      |> assign(:sort_by, new_field)
      |> assign(:sort_order, new_order)
      |> load_players(socket.assigns.search_params)

    {:noreply, socket}
  end

  @impl true
  def handle_info({SideoutWeb.Trainer.PlayerLive.FormComponent, {:saved, _player}}, socket) do
    {:noreply, load_players(socket, socket.assigns.search_params)}
  end

  defp load_players(socket, search_params) do
    search = Map.get(search_params, :search)
    sort_by = Map.get(socket.assigns, :sort_by, :name)

    opts = [
      search: search,
      order_by: sort_by
    ]

    players = Scheduling.list_players(opts)

    # Calculate stats for each player
    players_with_stats =
      Enum.map(players, fn player ->
        stats = Scheduling.get_player_stats(player)
        Map.put(player, :stats, stats)
      end)

    socket
    |> assign(:players, players_with_stats)
    |> assign(:search_params, search_params)
    |> assign(:sort_by, sort_by)
    |> assign(:sort_order, Map.get(socket.assigns, :sort_order, :asc))
  end

  defp toggle_order(:asc), do: :desc
  defp toggle_order(:desc), do: :asc

  defp sort_icon(assigns, field) do
    if assigns.sort_by == field do
      if assigns.sort_order == :asc do
        "↑"
      else
        "↓"
      end
    else
      ""
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="px-4 py-8 sm:px-6 lg:px-8">
      <div class="mx-auto max-w-7xl">
        <!-- Header -->
        <div class="sm:flex sm:items-center sm:justify-between">
          <div>
            <h1 class="text-3xl font-bold text-neutral-900 dark:text-neutral-100">Players</h1>
            <p class="mt-2 text-sm text-neutral-600 dark:text-neutral-400">
              Manage player profiles, view statistics, and track attendance history.
            </p>
          </div>
          <div class="mt-4 sm:ml-16 sm:mt-0 sm:flex-none">
            <.link
              patch={~p"/trainer/players/new"}
              class="block rounded-md bg-primary-500 px-3 py-2 text-center text-sm font-semibold text-white shadow-md hover:bg-primary-600 hover:shadow-sporty focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary-600 transition-all duration-200"
            >
              Add Player
            </.link>
          </div>
        </div>
        
    <!-- Search Bar -->
        <div class="mt-6">
          <form phx-submit="search" phx-change="search" class="flex gap-2">
            <div class="flex-1">
              <input
                type="text"
                name="search"
                value={Map.get(@search_params, :search, "")}
                placeholder="Search by name or email..."
                class="block w-full rounded-md border-0 py-1.5 text-neutral-900 dark:text-neutral-100 shadow-sm ring-1 ring-inset ring-neutral-300 dark:ring-secondary-600 placeholder:text-neutral-400 dark:placeholder:text-neutral-500 focus:ring-2 focus:ring-inset focus:ring-primary-600 sm:text-sm sm:leading-6 dark:bg-secondary-700"
              />
            </div>
            <%= if Map.get(@search_params, :search) do %>
              <button
                type="button"
                phx-click="clear_search"
                class="rounded-md bg-white px-3 py-2 text-sm font-semibold text-neutral-900 shadow-sm ring-1 ring-inset ring-neutral-300 hover:bg-neutral-50 transition-all duration-200 dark:bg-secondary-700 dark:text-neutral-100 dark:ring-secondary-600 dark:hover:bg-secondary-600"
              >
                Clear
              </button>
            <% end %>
          </form>
        </div>
        
    <!-- Players List -->
        <div class="mt-8">
          <%= if @players == [] do %>
            <div class="text-center">
              <svg
                class="mx-auto h-12 w-12 text-neutral-400 dark:text-neutral-500"
                fill="none"
                viewBox="0 0 24 24"
                stroke="currentColor"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z"
                />
              </svg>
              <h3 class="mt-2 text-sm font-semibold text-neutral-900 dark:text-neutral-100">
                No players found
              </h3>
              <p class="mt-1 text-sm text-neutral-600 dark:text-neutral-400">
                <%= if Map.get(@search_params, :search) do %>
                  Try adjusting your search or add a new player.
                <% else %>
                  Get started by adding your first player.
                <% end %>
              </p>
              <div class="mt-6">
                <.link
                  patch={~p"/trainer/players/new"}
                  class="inline-flex items-center rounded-md bg-primary-500 px-3 py-2 text-sm font-semibold text-white shadow-md hover:bg-primary-600 hover:shadow-sporty transition-all duration-200"
                >
                  Add Player
                </.link>
              </div>
            </div>
          <% else %>
            <div class="overflow-hidden bg-white dark:bg-secondary-800 shadow-sporty border-t-4 border-primary-500 sm:rounded-lg">
              <table class="min-w-full divide-y divide-neutral-300 dark:divide-secondary-700">
                <thead class="bg-neutral-50 dark:bg-secondary-900">
                  <tr>
                    <th
                      scope="col"
                      class="py-3.5 pl-4 pr-3 text-left text-sm font-semibold text-neutral-900 dark:text-neutral-100 sm:pl-6 cursor-pointer hover:bg-neutral-100 dark:hover:bg-secondary-800 transition-colors"
                      phx-click="sort"
                      phx-value-field="name"
                    >
                      Name {sort_icon(assigns, :name)}
                    </th>
                    <th
                      scope="col"
                      class="px-3 py-3.5 text-left text-sm font-semibold text-neutral-900 dark:text-neutral-100"
                    >
                      Contact
                    </th>
                    <th
                      scope="col"
                      class="px-3 py-3.5 text-left text-sm font-semibold text-neutral-900 dark:text-neutral-100 cursor-pointer hover:bg-neutral-100 dark:hover:bg-secondary-800 transition-colors"
                      phx-click="sort"
                      phx-value-field="total_registrations"
                    >
                      Total Sessions {sort_icon(assigns, :total_registrations)}
                    </th>
                    <th
                      scope="col"
                      class="px-3 py-3.5 text-left text-sm font-semibold text-neutral-900 dark:text-neutral-100"
                    >
                      Attendance Rate
                    </th>
                    <th
                      scope="col"
                      class="px-3 py-3.5 text-left text-sm font-semibold text-neutral-900 dark:text-neutral-100 cursor-pointer hover:bg-neutral-100 dark:hover:bg-secondary-800 transition-colors"
                      phx-click="sort"
                      phx-value-field="last_attendance_date"
                    >
                      Last Attended {sort_icon(assigns, :last_attendance_date)}
                    </th>
                    <th scope="col" class="relative py-3.5 pl-3 pr-4 sm:pr-6">
                      <span class="sr-only">Actions</span>
                    </th>
                  </tr>
                </thead>
                <tbody class="divide-y divide-neutral-200 dark:divide-secondary-700 bg-white dark:bg-secondary-800">
                  <%= for player <- @players do %>
                    <tr class="hover:bg-neutral-50 dark:hover:bg-secondary-700 transition-colors">
                      <td class="whitespace-nowrap py-4 pl-4 pr-3 text-sm font-medium text-neutral-900 dark:text-neutral-100 sm:pl-6">
                        {player.name}
                      </td>
                      <td class="whitespace-nowrap px-3 py-4 text-sm text-neutral-600 dark:text-neutral-400">
                        <%= if player.email do %>
                          <div>{player.email}</div>
                        <% end %>
                        <%= if player.phone do %>
                          <div class="text-neutral-500 dark:text-neutral-500">{player.phone}</div>
                        <% end %>
                        <%= if !player.email && !player.phone do %>
                          <span class="text-neutral-400 dark:text-neutral-500">No contact info</span>
                        <% end %>
                      </td>
                      <td class="whitespace-nowrap px-3 py-4 text-sm text-neutral-600 dark:text-neutral-400">
                        {player.total_registrations}
                      </td>
                      <td class="whitespace-nowrap px-3 py-4 text-sm text-neutral-600 dark:text-neutral-400">
                        <%= if player.stats.completed_sessions > 0 do %>
                          <div class="flex items-center gap-2">
                            <span class={[
                              "inline-flex items-center rounded-full px-2 py-1 text-xs font-medium",
                              if(player.stats.attendance_rate >= 80,
                                do:
                                  "bg-success-50 text-success-700 ring-1 ring-inset ring-success-600/20 dark:bg-success-900/30 dark:text-success-400 dark:ring-success-400/30",
                                else:
                                  "bg-warning-50 text-warning-700 ring-1 ring-inset ring-warning-600/20 dark:bg-warning-900/30 dark:text-warning-400 dark:ring-warning-400/30"
                              )
                            ]}>
                              {player.stats.attendance_rate}%
                            </span>
                            <span class="text-xs text-neutral-500 dark:text-neutral-500">
                              ({player.stats.attended}/{player.stats.completed_sessions})
                            </span>
                          </div>
                        <% else %>
                          <span class="text-neutral-400 dark:text-neutral-500">No sessions yet</span>
                        <% end %>
                      </td>
                      <td class="whitespace-nowrap px-3 py-4 text-sm text-neutral-600 dark:text-neutral-400">
                        <%= if player.last_attendance_date do %>
                          {Calendar.strftime(player.last_attendance_date, "%b %d, %Y")}
                        <% else %>
                          <span class="text-neutral-400 dark:text-neutral-500">Never</span>
                        <% end %>
                      </td>
                      <td class="relative whitespace-nowrap py-4 pl-3 pr-4 text-right text-sm font-medium sm:pr-6">
                        <div class="flex justify-end gap-2">
                          <.link
                            navigate={~p"/trainer/players/#{player.id}"}
                            class="text-primary-600 hover:text-primary-500 dark:text-primary-400 dark:hover:text-primary-300 transition-colors"
                          >
                            View
                          </.link>
                          <.link
                            patch={~p"/trainer/players/#{player.id}/edit"}
                            class="text-primary-600 hover:text-primary-500 dark:text-primary-400 dark:hover:text-primary-300 transition-colors"
                          >
                            Edit
                          </.link>
                          <.link
                            phx-click="delete"
                            phx-value-id={player.id}
                            data-confirm="Are you sure you want to delete this player? This will also delete all their registrations."
                            class="text-danger-600 hover:text-danger-500 dark:text-danger-400 dark:hover:text-danger-300 transition-colors"
                          >
                            Delete
                          </.link>
                        </div>
                      </td>
                    </tr>
                  <% end %>
                </tbody>
              </table>
            </div>
          <% end %>
        </div>
      </div>
    </div>

    <.modal
      :if={@live_action in [:new, :edit]}
      id="player-modal"
      show
      on_cancel={JS.patch(~p"/trainer/players")}
    >
      <.live_component
        module={SideoutWeb.Trainer.PlayerLive.FormComponent}
        id={@player.id || :new}
        title={@page_title}
        action={@live_action}
        player={@player}
        patch={~p"/trainer/players"}
      />
    </.modal>
    """
  end
end
