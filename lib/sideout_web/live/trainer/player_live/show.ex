defmodule SideoutWeb.Trainer.PlayerLive.Show do
  use SideoutWeb, :live_view

  alias Sideout.Scheduling

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _url, socket) do
    player = Scheduling.get_player!(id)
    stats = Scheduling.get_player_stats(player)
    upcoming_registrations = Scheduling.get_player_upcoming_sessions(player)

    # Get registration history (past sessions)
    past_registrations =
      Scheduling.get_player_registration_history(player, limit: 20, status: :past)

    {:noreply,
     socket
     |> assign(:page_title, player.name)
     |> assign(:player, player)
     |> assign(:stats, stats)
     |> assign(:upcoming_registrations, upcoming_registrations)
     |> assign(:past_registrations, past_registrations)}
  end

  defp format_date(date) do
    Calendar.strftime(date, "%b %d, %Y")
  end

  defp format_time(time) do
    Calendar.strftime(time, "%H:%M")
  end

  defp status_badge_class(:confirmed), do: "bg-green-50 text-green-700 ring-green-600/20"
  defp status_badge_class(:waitlisted), do: "bg-yellow-50 text-yellow-700 ring-yellow-600/20"
  defp status_badge_class(:attended), do: "bg-blue-50 text-blue-700 ring-blue-600/20"
  defp status_badge_class(:no_show), do: "bg-red-50 text-red-700 ring-red-600/20"
  defp status_badge_class(:cancelled), do: "bg-gray-50 text-gray-700 ring-gray-600/20"
  defp status_badge_class(_), do: "bg-gray-50 text-gray-700 ring-gray-600/20"

  defp status_text(status) do
    status |> Atom.to_string() |> String.replace("_", " ") |> String.capitalize()
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="px-4 py-8 sm:px-6 lg:px-8">
      <div class="mx-auto max-w-7xl">
        <!-- Header with back button -->
        <div class="mb-6">
          <.link
            navigate={~p"/trainer/players"}
            class="text-sm font-medium text-indigo-600 hover:text-indigo-500"
          >
            ← Back to Players
          </.link>
        </div>

    <!-- Player Info Card -->
        <div class="mb-8 overflow-hidden bg-white shadow sm:rounded-lg">
          <div class="px-4 py-5 sm:px-6 flex justify-between items-start">
            <div>
              <h1 class="text-3xl font-bold text-gray-900">{@player.name}</h1>
              <div class="mt-2 space-y-1">
                <%= if @player.email do %>
                  <p class="text-sm text-gray-600">
                    <span class="font-medium">Email:</span>
                    {@player.email}
                  </p>
                <% end %>
                <%= if @player.phone do %>
                  <p class="text-sm text-gray-600">
                    <span class="font-medium">Phone:</span>
                    {@player.phone}
                  </p>
                <% end %>
              </div>
            </div>
            <div class="flex gap-2">
              <.link
                patch={~p"/trainer/players/#{@player.id}/edit"}
                class="rounded-md bg-white px-3 py-2 text-sm font-semibold text-gray-900 shadow-sm ring-1 ring-inset ring-gray-300 hover:bg-gray-50"
              >
                Edit
              </.link>
            </div>
          </div>

          <%= if @player.notes do %>
            <div class="border-t border-gray-200 px-4 py-5 sm:px-6">
              <h3 class="text-sm font-medium text-gray-900 mb-2">Notes</h3>
              <p class="text-sm text-gray-600 whitespace-pre-wrap">{@player.notes}</p>
            </div>
          <% end %>
        </div>

    <!-- Statistics Cards -->
        <div class="mb-8 grid grid-cols-1 gap-5 sm:grid-cols-2 lg:grid-cols-4">
          <!-- Total Sessions -->
          <div class="overflow-hidden rounded-lg bg-white px-4 py-5 shadow sm:p-6">
            <dt class="truncate text-sm font-medium text-gray-500">Total Sessions</dt>
            <dd class="mt-1 text-3xl font-semibold tracking-tight text-gray-900">
              {@stats.total_sessions}
            </dd>
          </div>

    <!-- Completed Sessions -->
          <div class="overflow-hidden rounded-lg bg-white px-4 py-5 shadow sm:p-6">
            <dt class="truncate text-sm font-medium text-gray-500">Completed Sessions</dt>
            <dd class="mt-1 text-3xl font-semibold tracking-tight text-gray-900">
              {@stats.completed_sessions}
            </dd>
          </div>

    <!-- Attendance Rate -->
          <div class="overflow-hidden rounded-lg bg-white px-4 py-5 shadow sm:p-6">
            <dt class="truncate text-sm font-medium text-gray-500">Attendance Rate</dt>
            <dd class={[
              "mt-1 text-3xl font-semibold tracking-tight",
              if(@stats.attendance_rate >= 80, do: "text-green-600", else: "text-yellow-600")
            ]}>
              {@stats.attendance_rate}%
            </dd>
            <p class="mt-1 text-xs text-gray-500">
              {@stats.attended} attended / {@stats.completed_sessions} total
            </p>
          </div>

    <!-- No-Show Rate -->
          <div class="overflow-hidden rounded-lg bg-white px-4 py-5 shadow sm:p-6">
            <dt class="truncate text-sm font-medium text-gray-500">No-Show Rate</dt>
            <dd class={[
              "mt-1 text-3xl font-semibold tracking-tight",
              if(@stats.no_show_rate <= 10, do: "text-green-600", else: "text-red-600")
            ]}>
              {@stats.no_show_rate}%
            </dd>
            <p class="mt-1 text-xs text-gray-500">
              {@stats.no_shows} no-shows / {@stats.completed_sessions} total
            </p>
          </div>
        </div>

    <!-- Upcoming Sessions -->
        <div class="mb-8">
          <h2 class="text-xl font-bold text-gray-900 mb-4">Upcoming Sessions</h2>
          <%= if @upcoming_registrations == [] do %>
            <div class="rounded-lg bg-gray-50 px-4 py-12 text-center">
              <p class="text-sm text-gray-600">No upcoming sessions</p>
            </div>
          <% else %>
            <div class="overflow-hidden bg-white shadow sm:rounded-lg">
              <table class="min-w-full divide-y divide-gray-300">
                <thead class="bg-gray-50">
                  <tr>
                    <th
                      scope="col"
                      class="py-3.5 pl-4 pr-3 text-left text-sm font-semibold text-gray-900 sm:pl-6"
                    >
                      Date & Time
                    </th>
                    <th scope="col" class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">
                      Template
                    </th>
                    <th scope="col" class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">
                      Status
                    </th>
                    <th scope="col" class="relative py-3.5 pl-3 pr-4 sm:pr-6">
                      <span class="sr-only">Actions</span>
                    </th>
                  </tr>
                </thead>
                <tbody class="divide-y divide-gray-200 bg-white">
                  <%= for registration <- @upcoming_registrations do %>
                    <tr class="hover:bg-gray-50">
                      <td class="whitespace-nowrap py-4 pl-4 pr-3 text-sm text-gray-900 sm:pl-6">
                        {format_date(registration.session.date)}<br />
                        <span class="text-gray-500">
                          {format_time(registration.session.start_time)} - {format_time(
                            registration.session.end_time
                          )}
                        </span>
                      </td>
                      <td class="whitespace-nowrap px-3 py-4 text-sm text-gray-500">
                        <%= if registration.session.session_template do %>
                          {registration.session.session_template.name}
                        <% else %>
                          <span class="text-gray-400">One-off session</span>
                        <% end %>
                      </td>
                      <td class="whitespace-nowrap px-3 py-4 text-sm">
                        <span class={[
                          "inline-flex items-center rounded-full px-2 py-1 text-xs font-medium ring-1 ring-inset",
                          status_badge_class(registration.status)
                        ]}>
                          {status_text(registration.status)}
                        </span>
                        <%= if registration.status == :waitlisted && registration.priority_score do %>
                          <span class="ml-2 text-xs text-gray-500">
                            Priority: {Decimal.round(registration.priority_score, 1)}
                          </span>
                        <% end %>
                      </td>
                      <td class="relative whitespace-nowrap py-4 pl-3 pr-4 text-right text-sm font-medium sm:pr-6">
                        <.link
                          navigate={~p"/trainer/sessions/#{registration.session.id}"}
                          class="text-indigo-600 hover:text-indigo-900"
                        >
                          View Session
                        </.link>
                      </td>
                    </tr>
                  <% end %>
                </tbody>
              </table>
            </div>
          <% end %>
        </div>

    <!-- Registration History -->
        <div class="mb-8">
          <h2 class="text-xl font-bold text-gray-900 mb-4">Registration History</h2>
          <%= if @past_registrations == [] do %>
            <div class="rounded-lg bg-gray-50 px-4 py-12 text-center">
              <p class="text-sm text-gray-600">No past sessions</p>
            </div>
          <% else %>
            <div class="overflow-hidden bg-white shadow sm:rounded-lg">
              <table class="min-w-full divide-y divide-gray-300">
                <thead class="bg-gray-50">
                  <tr>
                    <th
                      scope="col"
                      class="py-3.5 pl-4 pr-3 text-left text-sm font-semibold text-gray-900 sm:pl-6"
                    >
                      Date & Time
                    </th>
                    <th scope="col" class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">
                      Template
                    </th>
                    <th scope="col" class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">
                      Status
                    </th>
                  </tr>
                </thead>
                <tbody class="divide-y divide-gray-200 bg-white">
                  <%= for registration <- @past_registrations do %>
                    <tr class="hover:bg-gray-50">
                      <td class="whitespace-nowrap py-4 pl-4 pr-3 text-sm text-gray-900 sm:pl-6">
                        {format_date(registration.session.date)}<br />
                        <span class="text-gray-500">
                          {format_time(registration.session.start_time)} - {format_time(
                            registration.session.end_time
                          )}
                        </span>
                      </td>
                      <td class="whitespace-nowrap px-3 py-4 text-sm text-gray-500">
                        <%= if registration.session.session_template do %>
                          {registration.session.session_template.name}
                        <% else %>
                          <span class="text-gray-400">One-off session</span>
                        <% end %>
                      </td>
                      <td class="whitespace-nowrap px-3 py-4 text-sm">
                        <span class={[
                          "inline-flex items-center rounded-full px-2 py-1 text-xs font-medium ring-1 ring-inset",
                          status_badge_class(registration.status)
                        ]}>
                          {status_text(registration.status)}
                        </span>
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
    """
  end
end
