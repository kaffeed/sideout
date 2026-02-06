defmodule SideoutWeb.Trainer.DashboardLive do
  use SideoutWeb, :live_view

  alias Sideout.Scheduling

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      # Subscribe to session updates
      Phoenix.PubSub.subscribe(Sideout.PubSub, "sessions:updates")
    end

    {:ok, load_data(socket)}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_info({:session_updated, _payload}, socket) do
    {:noreply, load_data(socket)}
  end

  defp load_data(socket) do
    user = socket.assigns.current_user
    today = Date.utc_today()
    two_weeks_later = Date.add(today, 14)

    # Get upcoming sessions for the next 2 weeks
    sessions =
      Scheduling.list_sessions(
        user_id: user.id,
        from_date: today,
        to_date: two_weeks_later,
        preload: [:registrations]
      )

    # Get active templates
    templates = Scheduling.list_session_templates(user.id, active_only: true)

    socket
    |> assign(:sessions, sessions)
    |> assign(:templates, templates)
    |> assign(:page_title, "Trainer Dashboard")
    |> assign_session_stats(sessions)
  end

  defp assign_session_stats(socket, sessions) do
    stats = %{
      total_sessions: length(sessions),
      total_registrations:
        Enum.reduce(sessions, 0, fn session, acc ->
          acc + count_registrations(session, :confirmed)
        end),
      sessions_with_low_attendance:
        Enum.count(sessions, fn session ->
          capacity_status = Scheduling.get_capacity_status(session)
          capacity_status.confirmed < 8
        end)
    }

    assign(socket, :stats, stats)
  end

  defp count_registrations(session, status) do
    Enum.count(session.registrations, &(&1.status == status))
  end

  defp format_time(time) do
    Calendar.strftime(time, "%H:%M")
  end

  defp format_date(date) do
    Calendar.strftime(date, "%a, %b %-d")
  end

  defp capacity_badge_class(session) do
    capacity_status = Scheduling.get_capacity_status(session)
    confirmed = capacity_status.confirmed

    cond do
      confirmed >= 15 -> "bg-green-100 text-green-800"
      confirmed >= 10 -> "bg-yellow-100 text-yellow-800"
      true -> "bg-red-100 text-red-800"
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="px-4 py-8 sm:px-6 lg:px-8">
      <div class="mx-auto max-w-7xl">
        <!-- Header -->
        <div class="mb-8">
          <h1 class="text-3xl font-bold text-gray-900">Trainer Dashboard</h1>
          <p class="mt-2 text-sm text-gray-600">
            Manage your volleyball sessions and players
          </p>
        </div>

        <!-- Quick Stats -->
        <div class="mb-8 grid grid-cols-1 gap-5 sm:grid-cols-3">
          <div class="overflow-hidden rounded-lg bg-white px-4 py-5 shadow sm:p-6">
            <dt class="truncate text-sm font-medium text-gray-500">Total Sessions (2 weeks)</dt>
            <dd class="mt-1 text-3xl font-semibold tracking-tight text-gray-900">
              <%= @stats.total_sessions %>
            </dd>
          </div>

          <div class="overflow-hidden rounded-lg bg-white px-4 py-5 shadow sm:p-6">
            <dt class="truncate text-sm font-medium text-gray-500">Total Registrations</dt>
            <dd class="mt-1 text-3xl font-semibold tracking-tight text-gray-900">
              <%= @stats.total_registrations %>
            </dd>
          </div>

          <div class="overflow-hidden rounded-lg bg-white px-4 py-5 shadow sm:p-6">
            <dt class="truncate text-sm font-medium text-gray-500">Low Attendance Sessions</dt>
            <dd class="mt-1 text-3xl font-semibold tracking-tight text-gray-900">
              <%= @stats.sessions_with_low_attendance %>
            </dd>
          </div>
        </div>

        <!-- Quick Actions -->
        <div class="mb-8">
          <h2 class="mb-4 text-lg font-semibold text-gray-900">Quick Actions</h2>
          <div class="flex flex-wrap gap-3">
            <.link
              navigate={~p"/trainer/sessions/new"}
              class="inline-flex items-center rounded-md bg-indigo-600 px-3 py-2 text-sm font-semibold text-white shadow-sm hover:bg-indigo-500"
            >
              Create Session
            </.link>
            <.link
              navigate={~p"/trainer/templates/new"}
              class="inline-flex items-center rounded-md bg-white px-3 py-2 text-sm font-semibold text-gray-900 shadow-sm ring-1 ring-inset ring-gray-300 hover:bg-gray-50"
            >
              Create Template
            </.link>
            <.link
              navigate={~p"/trainer/players"}
              class="inline-flex items-center rounded-md bg-white px-3 py-2 text-sm font-semibold text-gray-900 shadow-sm ring-1 ring-inset ring-gray-300 hover:bg-gray-50"
            >
              Manage Players
            </.link>
          </div>
        </div>

        <!-- Upcoming Sessions -->
        <div>
          <div class="mb-4 flex items-center justify-between">
            <h2 class="text-lg font-semibold text-gray-900">Upcoming Sessions</h2>
            <.link
              navigate={~p"/trainer/sessions"}
              class="text-sm font-medium text-indigo-600 hover:text-indigo-500"
            >
              View all sessions →
            </.link>
          </div>

          <%= if @sessions == [] do %>
            <div class="rounded-lg bg-white px-4 py-12 text-center shadow">
              <svg
                class="mx-auto h-12 w-12 text-gray-400"
                fill="none"
                viewBox="0 0 24 24"
                stroke="currentColor"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"
                />
              </svg>
              <h3 class="mt-2 text-sm font-semibold text-gray-900">No sessions scheduled</h3>
              <p class="mt-1 text-sm text-gray-500">Get started by creating a new session.</p>
              <div class="mt-6">
                <.link
                  navigate={~p"/trainer/sessions/new"}
                  class="inline-flex items-center rounded-md bg-indigo-600 px-3 py-2 text-sm font-semibold text-white shadow-sm hover:bg-indigo-500"
                >
                  Create Session
                </.link>
              </div>
            </div>
          <% else %>
            <div class="overflow-hidden bg-white shadow sm:rounded-lg">
              <ul role="list" class="divide-y divide-gray-200">
                <%= for session <- @sessions do %>
                  <li>
                    <.link
                      navigate={~p"/trainer/sessions/#{session.id}"}
                      class="block hover:bg-gray-50"
                    >
                      <div class="px-4 py-4 sm:px-6">
                        <div class="flex items-center justify-between">
                          <div class="flex-1">
                            <div class="flex items-center justify-between">
                              <p class="truncate text-sm font-medium text-indigo-600">
                                <%= format_date(session.date) %> - <%= format_time(
                                  session.start_time
                                ) %> to <%= format_time(session.end_time) %>
                              </p>
                              <div class="ml-2 flex flex-shrink-0">
                                <span class={[
                                  "inline-flex rounded-full px-2 text-xs font-semibold leading-5",
                                  capacity_badge_class(session)
                                ]}>
                                  <%= count_registrations(session, :confirmed) %> / <%= Scheduling.get_capacity_status(
                                    session
                                  ).description %>
                                </span>
                              </div>
                            </div>
                            <div class="mt-2 sm:flex sm:justify-between">
                              <div class="sm:flex">
                                <p class="flex items-center text-sm text-gray-500">
                                  <%= count_registrations(session, :confirmed) %> confirmed
                                  <%= if count_registrations(session, :waitlisted) > 0 do %>
                                    · <%= count_registrations(session, :waitlisted) %> waitlisted
                                  <% end %>
                                </p>
                              </div>
                              <div class="mt-2 flex items-center text-sm text-gray-500 sm:mt-0">
                                <svg
                                  class="mr-1.5 h-5 w-5 flex-shrink-0 text-gray-400"
                                  fill="currentColor"
                                  viewBox="0 0 20 20"
                                >
                                  <path
                                    fill-rule="evenodd"
                                    d="M5.05 4.05a7 7 0 119.9 9.9L10 18.9l-4.95-4.95a7 7 0 010-9.9zM10 11a2 2 0 100-4 2 2 0 000 4z"
                                    clip-rule="evenodd"
                                  />
                                </svg>
                                <%= session.fields_available %> field(s)
                              </div>
                            </div>
                          </div>
                        </div>
                      </div>
                    </.link>
                  </li>
                <% end %>
              </ul>
            </div>
          <% end %>
        </div>

        <!-- Active Templates -->
        <div class="mt-8">
          <div class="mb-4 flex items-center justify-between">
            <h2 class="text-lg font-semibold text-gray-900">Active Templates</h2>
            <.link
              navigate={~p"/trainer/templates"}
              class="text-sm font-medium text-indigo-600 hover:text-indigo-500"
            >
              Manage templates →
            </.link>
          </div>

          <%= if @templates == [] do %>
            <div class="rounded-lg border-2 border-dashed border-gray-300 bg-white px-4 py-8 text-center">
              <p class="text-sm text-gray-500">
                No active templates. Create templates to quickly schedule recurring sessions.
              </p>
            </div>
          <% else %>
            <div class="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
              <%= for template <- @templates do %>
                <div class="overflow-hidden rounded-lg bg-white shadow">
                  <div class="px-4 py-5 sm:p-6">
                    <h3 class="text-base font-semibold text-gray-900"><%= template.name %></h3>
                    <div class="mt-2 text-sm text-gray-500">
                      <p>
                        <%= template.day_of_week |> Atom.to_string() |> String.capitalize() %> · <%= format_time(
                          template.start_time
                        ) %> - <%= format_time(template.end_time) %>
                      </p>
                      <p class="mt-1">
                        <%= template.skill_level |> Atom.to_string() |> String.capitalize() %>
                      </p>
                    </div>
                  </div>
                </div>
              <% end %>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end
end
