defmodule SideoutWeb.Trainer.AttendanceLive do
  use SideoutWeb, :live_view

  alias Sideout.Scheduling

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _url, socket) do
    session =
      Scheduling.get_session!(id, preload: [:user, :session_template, registrations: :player])

    if connected?(socket) do
      Phoenix.PubSub.subscribe(Sideout.PubSub, "sessions:#{id}")
    end

    confirmed_registrations = get_confirmed_registrations(session)
    stats = Scheduling.get_session_attendance_stats(session)

    {:noreply,
     socket
     |> assign(:page_title, "Mark Attendance")
     |> assign(:session, session)
     |> assign(:registrations, confirmed_registrations)
     |> assign(:stats, stats)
     |> assign(:selected_ids, [])}
  end

  @impl true
  def handle_event("mark_attended", %{"registration_id" => registration_id}, socket) do
    {id, ""} = Integer.parse(registration_id)
    registration = Scheduling.get_registration!(id)

    case Scheduling.mark_attendance(registration, :attended) do
      {:ok, _updated_registration} ->
        {:noreply,
         socket
         |> put_flash(:info, "Marked as attended")
         |> reload_session()}

      {:error, _changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to mark attendance")
         |> reload_session()}
    end
  end

  def handle_event("mark_no_show", %{"registration_id" => registration_id}, socket) do
    {id, ""} = Integer.parse(registration_id)
    registration = Scheduling.get_registration!(id)

    case Scheduling.mark_attendance(registration, :no_show) do
      {:ok, _updated_registration} ->
        {:noreply,
         socket
         |> put_flash(:info, "Marked as no-show")
         |> reload_session()}

      {:error, _changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to mark attendance")
         |> reload_session()}
    end
  end

  def handle_event("mark_all_attended", _params, socket) do
    session = socket.assigns.session
    confirmed_registrations = get_confirmed_registrations(session)
    registration_ids = Enum.map(confirmed_registrations, & &1.id)

    case Scheduling.bulk_mark_attendance(session, registration_ids, :attended) do
      {:ok, count} when count > 0 ->
        {:noreply,
         socket
         |> put_flash(:info, "Marked #{count} player(s) as attended")
         |> reload_session()}

      {:ok, 0} ->
        {:noreply,
         socket
         |> put_flash(:info, "No pending registrations to mark")
         |> reload_session()}
    end
  end

  @impl true
  def handle_info({:session_updated, _event, _data}, socket) do
    {:noreply, reload_session(socket)}
  end

  def handle_info({:attendance_marked, _data}, socket) do
    {:noreply, reload_session(socket)}
  end

  def handle_info(_msg, socket) do
    {:noreply, socket}
  end

  defp reload_session(socket) do
    session =
      Scheduling.get_session!(socket.assigns.session.id,
        preload: [:user, :session_template, registrations: :player]
      )

    confirmed_registrations = get_confirmed_registrations(session)
    stats = Scheduling.get_session_attendance_stats(session)

    socket
    |> assign(:session, session)
    |> assign(:registrations, confirmed_registrations)
    |> assign(:stats, stats)
  end

  defp get_confirmed_registrations(session) do
    session.registrations
    |> Enum.filter(&(&1.status in [:confirmed, :attended, :no_show]))
    |> Enum.sort_by(& &1.registered_at, DateTime)
  end

  defp format_date(date) do
    Calendar.strftime(date, "%B %-d, %Y")
  end

  defp format_time(time) do
    Calendar.strftime(time, "%I:%M %p")
  end

  defp status_badge_class(status) do
    case status do
      :confirmed -> "bg-info-50 dark:bg-info-900/30 text-info-600 dark:text-info-400"
      :attended -> "bg-success-100 dark:bg-success-900/30 text-success-800 dark:text-success-400"
      :no_show -> "bg-danger-100 dark:bg-danger-900/30 text-danger-800 dark:text-danger-400"
      _ -> "bg-neutral-100 dark:bg-secondary-700 text-neutral-800 dark:text-neutral-100"
    end
  end

  defp status_text(status) do
    case status do
      :confirmed -> "Pending"
      :attended -> "Attended"
      :no_show -> "No-Show"
      _ -> String.capitalize(to_string(status))
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="px-4 py-8 sm:px-6 lg:px-8">
      <div class="mx-auto max-w-6xl">
        <!-- Back Button -->
        <div class="mb-6">
          <.link
            navigate={~p"/trainer/sessions/#{@session}"}
            class="inline-flex items-center text-sm font-medium text-neutral-500 dark:text-neutral-400 hover:text-neutral-700 dark:hover:text-neutral-300"
          >
            <svg class="mr-2 h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M15 19l-7-7 7-7"
              />
            </svg>
            Back to Session
          </.link>
        </div>

        <!-- Session Header -->
        <div class="mb-8">
          <h1 class="text-3xl font-bold text-neutral-900 dark:text-neutral-100">Mark Attendance</h1>
          <p class="mt-2 text-lg text-neutral-600 dark:text-neutral-400">
            {format_date(@session.date)} • {format_time(@session.start_time)} - {format_time(@session.end_time)}
          </p>
        </div>

        <!-- Attendance Statistics -->
        <div class="mb-8 grid grid-cols-1 gap-4 sm:grid-cols-4">
          <div class="rounded-lg bg-white dark:bg-secondary-800 px-4 py-5 shadow-sporty border-t-4 border-primary-500">
            <dt class="truncate text-sm font-medium text-neutral-500 dark:text-neutral-400">Total Confirmed</dt>
            <dd class="mt-1 text-3xl font-semibold tracking-tight text-neutral-900 dark:text-neutral-100">
              {@stats.total_confirmed}
            </dd>
          </div>

          <div class="rounded-lg bg-success-50 dark:bg-success-900/30 px-4 py-5 shadow-sporty border-t-4 border-success-600">
            <dt class="truncate text-sm font-medium text-success-600 dark:text-success-400">Attended</dt>
            <dd class="mt-1 text-3xl font-semibold tracking-tight text-success-900 dark:text-success-400">
              {@stats.attended}
            </dd>
          </div>

          <div class="rounded-lg bg-danger-50 dark:bg-danger-900/30 px-4 py-5 shadow-sporty border-t-4 border-danger-600">
            <dt class="truncate text-sm font-medium text-danger-600 dark:text-danger-400">No-Shows</dt>
            <dd class="mt-1 text-3xl font-semibold tracking-tight text-danger-900 dark:text-danger-400">
              {@stats.no_shows}
            </dd>
          </div>

          <div class="rounded-lg bg-info-50 dark:bg-info-900/30 px-4 py-5 shadow-sporty border-t-4 border-info-600">
            <dt class="truncate text-sm font-medium text-info-600 dark:text-info-400">Pending</dt>
            <dd class="mt-1 text-3xl font-semibold tracking-tight text-info-900 dark:text-info-400">
              {@stats.pending}
            </dd>
          </div>
        </div>

        <!-- Attendance Rate -->
        <%= if @stats.total_confirmed > 0 do %>
          <div class="mb-6 rounded-lg bg-primary-50 dark:bg-primary-900/30 p-4 border-t-4 border-primary-500">
            <div class="flex items-center justify-between">
              <div>
                <p class="text-sm font-medium text-primary-800 dark:text-primary-400">Attendance Rate</p>
                <p class="text-xs text-primary-600 dark:text-primary-300">
                  {@stats.attended} out of {@stats.total_confirmed} confirmed players
                </p>
              </div>
              <div class="text-3xl font-bold text-primary-900 dark:text-primary-400">
                {@stats.attendance_rate}%
              </div>
            </div>
          </div>
        <% end %>

        <!-- Bulk Actions -->
        <%= if @stats.pending > 0 do %>
          <div class="mb-6 flex items-center justify-between rounded-lg border border-neutral-200 dark:border-secondary-700 bg-white dark:bg-secondary-800 p-4 shadow-sm">
            <div>
              <h3 class="text-sm font-medium text-neutral-900 dark:text-neutral-100">Bulk Actions</h3>
              <p class="text-xs text-neutral-500 dark:text-neutral-400">Mark all pending check-ins at once</p>
            </div>
            <button
              phx-click="mark_all_attended"
              class="rounded-md bg-success-600 dark:bg-success-600 px-4 py-2 text-sm font-semibold text-white shadow-md hover:shadow-sporty hover:bg-success-500 dark:hover:bg-success-500 transition-all duration-200 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-success-600"
            >
              Mark All Attended
            </button>
          </div>
        <% end %>

        <!-- Player List -->
        <div class="overflow-hidden rounded-lg bg-white dark:bg-secondary-800 shadow-sporty border-t-4 border-primary-500">
          <div class="px-6 py-4 border-b border-neutral-200 dark:border-secondary-700">
            <h2 class="text-lg font-semibold text-neutral-900 dark:text-neutral-100">
              Players ({length(@registrations)})
            </h2>
          </div>

          <%= if Enum.empty?(@registrations) do %>
            <div class="px-6 py-12 text-center">
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
              <h3 class="mt-2 text-sm font-semibold text-neutral-900 dark:text-neutral-100">No players registered</h3>
              <p class="mt-1 text-sm text-neutral-500 dark:text-neutral-400">
                No confirmed players for this session yet.
              </p>
            </div>
          <% else %>
            <div class="overflow-x-auto">
              <table class="min-w-full divide-y divide-neutral-200 dark:divide-secondary-700">
                <thead class="bg-neutral-50 dark:bg-secondary-900">
                  <tr>
                    <th
                      scope="col"
                      class="px-6 py-3 text-left text-xs font-medium uppercase tracking-wider text-neutral-500 dark:text-neutral-400"
                    >
                      Player
                    </th>
                    <th
                      scope="col"
                      class="px-6 py-3 text-left text-xs font-medium uppercase tracking-wider text-neutral-500 dark:text-neutral-400"
                    >
                      Contact
                    </th>
                    <th
                      scope="col"
                      class="px-6 py-3 text-left text-xs font-medium uppercase tracking-wider text-neutral-500 dark:text-neutral-400"
                    >
                      Status
                    </th>
                    <th
                      scope="col"
                      class="px-6 py-3 text-right text-xs font-medium uppercase tracking-wider text-neutral-500 dark:text-neutral-400"
                    >
                      Actions
                    </th>
                  </tr>
                </thead>
                <tbody class="divide-y divide-neutral-200 dark:divide-secondary-700 bg-white dark:bg-secondary-800">
                  <%= for registration <- @registrations do %>
                    <tr>
                      <td class="whitespace-nowrap px-6 py-4">
                        <div class="text-sm font-medium text-neutral-900 dark:text-neutral-100">
                          {registration.player.name}
                        </div>
                      </td>
                      <td class="whitespace-nowrap px-6 py-4">
                        <div class="text-sm text-neutral-900 dark:text-neutral-100">
                          <%= if registration.player.email do %>
                            {registration.player.email}
                          <% else %>
                            <span class="text-neutral-400 dark:text-neutral-500">No email</span>
                          <% end %>
                        </div>
                        <%= if registration.player.phone do %>
                          <div class="text-xs text-neutral-500 dark:text-neutral-400">
                            {registration.player.phone}
                          </div>
                        <% end %>
                      </td>
                      <td class="whitespace-nowrap px-6 py-4">
                        <span class={[
                          "inline-flex rounded-full px-2 py-1 text-xs font-semibold",
                          status_badge_class(registration.status)
                        ]}>
                          {status_text(registration.status)}
                        </span>
                      </td>
                      <td class="whitespace-nowrap px-6 py-4 text-right text-sm font-medium">
                        <%= if registration.status == :confirmed do %>
                          <button
                            phx-click="mark_attended"
                            phx-value-registration_id={registration.id}
                            class="inline-flex items-center gap-1 rounded-md bg-success-600 dark:bg-success-600 px-3 py-1.5 text-sm font-semibold text-white shadow-md hover:shadow-sporty hover:bg-success-500 dark:hover:bg-success-500 transition-all duration-200 mr-2"
                          >
                            <svg class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                              <path
                                stroke-linecap="round"
                                stroke-linejoin="round"
                                stroke-width="2"
                                d="M5 13l4 4L19 7"
                              />
                            </svg>
                            Attended
                          </button>
                          <button
                            phx-click="mark_no_show"
                            phx-value-registration_id={registration.id}
                            class="inline-flex items-center gap-1 rounded-md bg-danger-600 dark:bg-danger-600 px-3 py-1.5 text-sm font-semibold text-white shadow-md hover:shadow-sporty hover:bg-danger-500 dark:hover:bg-danger-500 transition-all duration-200"
                          >
                            <svg class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                              <path
                                stroke-linecap="round"
                                stroke-linejoin="round"
                                stroke-width="2"
                                d="M6 18L18 6M6 6l12 12"
                              />
                            </svg>
                            No-Show
                          </button>
                        <% else %>
                          <span class="text-neutral-500 dark:text-neutral-400 italic">
                            Marked
                          </span>
                        <% end %>
                      </td>
                    </tr>
                  <% end %>
                </tbody>
              </table>
            </div>
          <% end %>
        </div>

        <!-- Complete Session Notice -->
        <%= if @stats.pending == 0 and @stats.total_confirmed > 0 do %>
          <div class="mt-6 rounded-lg bg-success-50 dark:bg-success-900/30 p-4">
            <div class="flex">
              <div class="flex-shrink-0">
                <svg class="h-5 w-5 text-success-400 dark:text-success-400" viewBox="0 0 20 20" fill="currentColor">
                  <path
                    fill-rule="evenodd"
                    d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z"
                    clip-rule="evenodd"
                  />
                </svg>
              </div>
              <div class="ml-3">
                <h3 class="text-sm font-medium text-success-800 dark:text-success-400">Attendance Complete</h3>
                <div class="mt-2 text-sm text-success-700 dark:text-success-400">
                  <p>
                    All players have been marked. You can now return to the session details.
                  </p>
                </div>
              </div>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end
end
