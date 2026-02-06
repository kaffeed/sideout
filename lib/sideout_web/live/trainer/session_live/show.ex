defmodule SideoutWeb.Trainer.SessionLive.Show do
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
      Phoenix.PubSub.subscribe(Sideout.PubSub, "sessions:updates")
    end

    attendance_stats = Scheduling.get_session_attendance_stats(session)

    {:noreply,
     socket
     |> assign(:page_title, "Session Details")
     |> assign(:session, session)
     |> assign(:show_qr, false)
     |> assign(:copy_success, false)
     |> assign(:attendance_stats, attendance_stats)
     |> assign_registrations(session)}
  end

  @impl true
  def handle_event("promote", %{"registration_id" => registration_id}, socket) do
    session = socket.assigns.session

    case Integer.parse(registration_id) do
      {id, ""} ->
        registration = Scheduling.get_registration!(id)

        # Manually promote this specific player
        case Scheduling.promote_next_from_waitlist(session, registration.player_id) do
          {:ok, promoted_registration} when not is_nil(promoted_registration) ->
            {:noreply,
             socket
             |> put_flash(:info, "Player promoted to confirmed status")
             |> reload_session()}

          {:ok, nil} ->
            {:noreply,
             socket
             |> put_flash(:error, "Could not promote player - session may be full")
             |> reload_session()}

          {:error, _reason} ->
            {:noreply,
             socket
             |> put_flash(:error, "Failed to promote player")
             |> reload_session()}
        end

      _ ->
        {:noreply, socket}
    end
  end

  def handle_event("cancel_session", _params, socket) do
    {:noreply, assign(socket, :show_cancel_modal, true)}
  end

  def handle_event("confirm_cancel", %{"reason" => reason}, socket) do
    session = socket.assigns.session

    case Scheduling.cancel_session(session, reason) do
      {:ok, _cancelled_session} ->
        {:noreply,
         socket
         |> put_flash(:info, "Session cancelled successfully")
         |> push_navigate(to: ~p"/trainer/sessions")}

      {:error, _changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to cancel session")
         |> assign(:show_cancel_modal, false)}
    end
  end

  def handle_event("close_cancel_modal", _params, socket) do
    {:noreply, assign(socket, :show_cancel_modal, false)}
  end

  def handle_event("toggle_qr", _params, socket) do
    {:noreply, assign(socket, :show_qr, !socket.assigns.show_qr)}
  end

  def handle_event("copy_link", _params, socket) do
    {:noreply, 
     socket
     |> assign(:copy_success, true)
     |> push_event("copy-to-clipboard", %{text: share_url(socket.assigns.session)})}
  end

  def handle_event("reset_copy", _params, socket) do
    {:noreply, assign(socket, :copy_success, false)}
  end

  @impl true
  def handle_info({:session_updated, _payload}, socket) do
    {:noreply, reload_session(socket)}
  end

  def handle_info({:player_promoted, _payload}, socket) do
    {:noreply, reload_session(socket)}
  end

  def handle_info({:player_cancelled, _payload}, socket) do
    {:noreply, reload_session(socket)}
  end

  def handle_info({:player_registered, _payload}, socket) do
    {:noreply, reload_session(socket)}
  end

  def handle_info({:attendance_marked, _payload}, socket) do
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

    attendance_stats = Scheduling.get_session_attendance_stats(session)

    socket
    |> assign(:session, session)
    |> assign(:attendance_stats, attendance_stats)
    |> assign_registrations(session)
  end

  defp assign_registrations(socket, session) do
    confirmed = Scheduling.list_registrations(session, :confirmed)
    waitlisted = Scheduling.list_registrations(session, :waitlisted)

    socket
    |> assign(:confirmed_registrations, confirmed)
    |> assign(:waitlisted_registrations, waitlisted)
    |> assign(:show_cancel_modal, false)
  end

  defp format_time(time) do
    Calendar.strftime(time, "%H:%M")
  end

  defp format_date(date) do
    Calendar.strftime(date, "%A, %B %-d, %Y")
  end

  defp format_datetime(datetime) do
    datetime
    |> DateTime.shift_zone!("Etc/UTC")
    |> Calendar.strftime("%b %-d, %Y at %H:%M")
  end

  defp status_badge_class(status) do
    case status do
      :scheduled -> "bg-blue-100 text-blue-800"
      :in_progress -> "bg-yellow-100 text-yellow-800"
      :completed -> "bg-green-100 text-green-800"
      :cancelled -> "bg-red-100 text-red-800"
    end
  end

  defp status_text(status) do
    status |> Atom.to_string() |> String.capitalize() |> String.replace("_", " ")
  end

  defp share_url(session) do
    uri = SideoutWeb.Endpoint.url()
    "#{uri}/s/#{session.share_token}"
  end

  defp generate_qr_code(session) do
    url = share_url(session)
    
    try do
      url
      |> EQRCode.encode()
      |> EQRCode.svg(width: 200)
    rescue
      _ -> nil
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="px-4 py-8 sm:px-6 lg:px-8" phx-hook="CopyToClipboard" id="session-show-container">
      <div class="mx-auto max-w-5xl">
        <!-- Back Button -->
        <div class="mb-6">
          <.link
            navigate={~p"/trainer/sessions"}
            class="inline-flex items-center text-sm font-medium text-gray-500 hover:text-gray-700"
          >
            <svg class="mr-2 h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M15 19l-7-7 7-7"
              />
            </svg>
            Back to Sessions
          </.link>
        </div>

    <!-- Session Header -->
        <div class="mb-8 overflow-hidden rounded-lg bg-white shadow">
          <div class="px-6 py-5">
            <div class="flex items-start justify-between">
              <div class="flex-1">
                <h1 class="text-2xl font-bold text-gray-900">
                  {format_date(@session.date)}
                </h1>
                <p class="mt-1 text-sm text-gray-500">
                  {format_time(@session.start_time)} - {format_time(@session.end_time)}
                </p>
              </div>
              <span class={[
                "inline-flex rounded-full px-3 py-1 text-sm font-semibold",
                status_badge_class(@session.status)
              ]}>
                {status_text(@session.status)}
              </span>
            </div>

    <!-- Session Info Grid -->
            <div class="mt-6 grid grid-cols-1 gap-6 sm:grid-cols-3">
              <div>
                <dt class="text-sm font-medium text-gray-500">Capacity</dt>
                <dd class="mt-1 text-sm text-gray-900">
                  {Scheduling.get_capacity_status(@session).description}
                </dd>
              </div>

              <div>
                <dt class="text-sm font-medium text-gray-500">Fields Available</dt>
                <dd class="mt-1 text-sm text-gray-900">
                  {@session.fields_available}
                </dd>
              </div>

              <div>
                <dt class="text-sm font-medium text-gray-500">Cancellation Deadline</dt>
                <dd class="mt-1 text-sm text-gray-900">
                  {@session.cancellation_deadline_hours} hours before
                </dd>
              </div>
            </div>

            <%= if @session.notes do %>
              <div class="mt-6">
                <dt class="text-sm font-medium text-gray-500">Notes</dt>
                <dd class="mt-1 text-sm text-gray-900">
                  {@session.notes}
                </dd>
              </div>
            <% end %>

    <!-- Share Link Section -->
            <div class="mt-6 rounded-lg border border-gray-200 bg-gray-50 p-4">
              <div class="flex items-start justify-between">
                <div class="flex-1">
                  <h3 class="text-sm font-medium text-gray-900">Session Share Link</h3>
                  <p class="mt-1 text-xs text-gray-500">
                    Share this link with players to allow them to register
                  </p>
                  <div class="mt-3 flex items-center gap-2">
                    <input
                      type="text"
                      readonly
                      value={share_url(@session)}
                      class="block flex-1 rounded-md border-gray-300 bg-white text-sm shadow-sm focus:border-indigo-500 focus:ring-indigo-500"
                      id="share-link-input"
                    />
                    <button
                      phx-click="copy_link"
                      class={[
                        "inline-flex items-center gap-2 rounded-md px-3 py-2 text-sm font-semibold shadow-sm",
                        if(@copy_success,
                          do: "bg-green-600 text-white hover:bg-green-500",
                          else: "bg-indigo-600 text-white hover:bg-indigo-500"
                        )
                      ]}
                    >
                      <%= if @copy_success do %>
                        <svg class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                          <path
                            stroke-linecap="round"
                            stroke-linejoin="round"
                            stroke-width="2"
                            d="M5 13l4 4L19 7"
                          />
                        </svg>
                        Copied!
                      <% else %>
                        <svg class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                          <path
                            stroke-linecap="round"
                            stroke-linejoin="round"
                            stroke-width="2"
                            d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z"
                          />
                        </svg>
                        Copy
                      <% end %>
                    </button>
                    <button
                      phx-click="toggle_qr"
                      class="inline-flex items-center gap-2 rounded-md bg-white px-3 py-2 text-sm font-semibold text-gray-900 shadow-sm ring-1 ring-inset ring-gray-300 hover:bg-gray-50"
                    >
                      <svg class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path
                          stroke-linecap="round"
                          stroke-linejoin="round"
                          stroke-width="2"
                          d="M12 4v1m6 11h2m-6 0h-2v4m0-11v3m0 0h.01M12 12h4.01M16 20h4M4 12h4m12 0h.01M5 8h2a1 1 0 001-1V5a1 1 0 00-1-1H5a1 1 0 00-1 1v2a1 1 0 001 1zm12 0h2a1 1 0 001-1V5a1 1 0 00-1-1h-2a1 1 0 00-1 1v2a1 1 0 001 1zM5 20h2a1 1 0 001-1v-2a1 1 0 00-1-1H5a1 1 0 00-1 1v2a1 1 0 001 1z"
                        />
                      </svg>
                      QR Code
                    </button>
                  </div>
                  <%= if @show_qr do %>
                    <div class="mt-4 flex justify-center rounded-lg border border-gray-200 bg-white p-4">
                      <%= Phoenix.HTML.raw(generate_qr_code(@session)) %>
                    </div>
                  <% end %>
                </div>
              </div>
            </div>

    <!-- Action Buttons -->
            <div class="mt-6 flex flex-wrap gap-3">
              <.link
                patch={~p"/trainer/sessions/#{@session.id}/edit"}
                class="inline-flex items-center rounded-md bg-white px-3 py-2 text-sm font-semibold text-gray-900 shadow-sm ring-1 ring-inset ring-gray-300 hover:bg-gray-50"
              >
                Edit Session
              </.link>

              <%= if @session.status == :scheduled do %>
                <button
                  phx-click="cancel_session"
                  class="inline-flex items-center rounded-md bg-red-600 px-3 py-2 text-sm font-semibold text-white shadow-sm hover:bg-red-500"
                >
                  Cancel Session
                </button>
              <% end %>

              <.link
                navigate={~p"/trainer/sessions/#{@session.id}/attendance"}
                class="inline-flex items-center rounded-md bg-indigo-600 px-3 py-2 text-sm font-semibold text-white shadow-sm hover:bg-indigo-500"
              >
                Mark Attendance
              </.link>
            </div>
          </div>
        </div>

    <!-- Attendance Statistics -->
        <%= if @attendance_stats.total_confirmed > 0 do %>
          <div class="mb-8 overflow-hidden rounded-lg bg-white shadow">
            <div class="px-6 py-5">
              <h2 class="text-lg font-semibold text-gray-900 mb-4">Attendance Summary</h2>
              <div class="grid grid-cols-1 gap-4 sm:grid-cols-4">
                <div class="rounded-lg bg-gray-50 px-4 py-3">
                  <dt class="text-sm font-medium text-gray-500">Total Confirmed</dt>
                  <dd class="mt-1 text-2xl font-semibold text-gray-900">
                    {@attendance_stats.total_confirmed}
                  </dd>
                </div>

                <div class="rounded-lg bg-green-50 px-4 py-3">
                  <dt class="text-sm font-medium text-green-600">Attended</dt>
                  <dd class="mt-1 text-2xl font-semibold text-green-900">
                    {@attendance_stats.attended}
                  </dd>
                </div>

                <div class="rounded-lg bg-red-50 px-4 py-3">
                  <dt class="text-sm font-medium text-red-600">No-Shows</dt>
                  <dd class="mt-1 text-2xl font-semibold text-red-900">
                    {@attendance_stats.no_shows}
                  </dd>
                </div>

                <div class="rounded-lg bg-blue-50 px-4 py-3">
                  <dt class="text-sm font-medium text-blue-600">Attendance Rate</dt>
                  <dd class="mt-1 text-2xl font-semibold text-blue-900">
                    {@attendance_stats.attendance_rate}%
                  </dd>
                </div>
              </div>
            </div>
          </div>
        <% end %>

    <!-- Confirmed Players -->
        <div class="mb-8">
          <div class="mb-4 flex items-center justify-between">
            <h2 class="text-lg font-semibold text-gray-900">
              Confirmed Players ({length(@confirmed_registrations)})
            </h2>
          </div>

          <%= if @confirmed_registrations == [] do %>
            <div class="rounded-lg border-2 border-dashed border-gray-300 bg-white px-4 py-8 text-center">
              <p class="text-sm text-gray-500">No confirmed registrations yet</p>
            </div>
          <% else %>
            <div class="overflow-hidden rounded-lg bg-white shadow">
              <ul role="list" class="divide-y divide-gray-200">
                <%= for registration <- @confirmed_registrations do %>
                  <li class="px-6 py-4">
                    <div class="flex items-center justify-between">
                      <div class="flex-1">
                        <p class="text-sm font-medium text-gray-900">
                          {registration.player.name}
                        </p>
                        <p class="text-xs text-gray-500">
                          Registered {format_datetime(registration.registered_at)}
                        </p>
                      </div>
                      <%= if registration.player.email do %>
                        <p class="text-sm text-gray-500">{registration.player.email}</p>
                      <% end %>
                    </div>
                  </li>
                <% end %>
              </ul>
            </div>
          <% end %>
        </div>

    <!-- Waitlist -->
        <div>
          <div class="mb-4 flex items-center justify-between">
            <h2 class="text-lg font-semibold text-gray-900">
              Waitlist ({length(@waitlisted_registrations)})
            </h2>
          </div>

          <%= if @waitlisted_registrations == [] do %>
            <div class="rounded-lg border-2 border-dashed border-gray-300 bg-white px-4 py-8 text-center">
              <p class="text-sm text-gray-500">No players on waitlist</p>
            </div>
          <% else %>
            <div class="overflow-hidden rounded-lg bg-white shadow">
              <ul role="list" class="divide-y divide-gray-200">
                <%= for {registration, index} <- Enum.with_index(@waitlisted_registrations, 1) do %>
                  <li class="px-6 py-4">
                    <div class="flex items-center justify-between">
                      <div class="flex flex-1 items-center gap-4">
                        <div class="flex h-8 w-8 items-center justify-center rounded-full bg-gray-100">
                          <span class="text-sm font-semibold text-gray-600">#{index}</span>
                        </div>
                        <div class="flex-1">
                          <p class="text-sm font-medium text-gray-900"></p>
                          {registration.player.name}
                          <p class="text-xs text-gray-500">
                            Priority Score: {if registration.priority_score,
                              do: Decimal.round(registration.priority_score, 2),
                              else: "N/A"} · Registered {format_datetime(registration.registered_at)}
                          </p>
                        </div>
                      </div>
                      <button
                        phx-click="promote"
                        phx-value-registration_id={registration.id}
                        class="ml-4 inline-flex items-center rounded-md bg-indigo-600 px-3 py-2 text-sm font-semibold text-white shadow-sm hover:bg-indigo-500"
                      >
                        Promote
                      </button>
                    </div>
                  </li>
                <% end %>
              </ul>
            </div>
          <% end %>
        </div>
      </div>
    </div>

    <!-- Cancel Session Modal -->
    <%= if @show_cancel_modal do %>
      <div class="relative z-50" role="dialog" aria-modal="true">
        <div class="fixed inset-0 bg-gray-500 bg-opacity-75 transition-opacity"></div>
        <div class="fixed inset-0 z-10 overflow-y-auto">
          <div class="flex min-h-full items-end justify-center p-4 text-center sm:items-center sm:p-0">
            <div class="relative transform overflow-hidden rounded-lg bg-white px-4 pb-4 pt-5 text-left shadow-xl transition-all sm:my-8 sm:w-full sm:max-w-lg sm:p-6">
              <div class="sm:flex sm:items-start">
                <div class="mx-auto flex h-12 w-12 flex-shrink-0 items-center justify-center rounded-full bg-red-100 sm:mx-0 sm:h-10 sm:w-10">
                  <svg
                    class="h-6 w-6 text-red-600"
                    fill="none"
                    viewBox="0 0 24 24"
                    stroke="currentColor"
                  >
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z"
                    />
                  </svg>
                </div>
                <div class="mt-3 text-center sm:ml-4 sm:mt-0 sm:text-left">
                  <h3 class="text-base font-semibold leading-6 text-gray-900">Cancel Session</h3>
                  <div class="mt-2">
                    <p class="text-sm text-gray-500">
                      Are you sure you want to cancel this session? This action cannot be undone.
                      All registered players will need to be notified.
                    </p>
                    <form phx-submit="confirm_cancel" class="mt-4">
                      <label class="block text-sm font-medium text-gray-700">
                        Reason for cancellation
                      </label>
                      <textarea
                        name="reason"
                        rows="3"
                        class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
                        placeholder="Optional: provide a reason for cancelling"
                      ></textarea>
                      <div class="mt-5 sm:mt-4 sm:flex sm:flex-row-reverse">
                        <button
                          type="submit"
                          class="inline-flex w-full justify-center rounded-md bg-red-600 px-3 py-2 text-sm font-semibold text-white shadow-sm hover:bg-red-500 sm:ml-3 sm:w-auto"
                        >
                          Cancel Session
                        </button>
                        <button
                          type="button"
                          phx-click="close_cancel_modal"
                          class="mt-3 inline-flex w-full justify-center rounded-md bg-white px-3 py-2 text-sm font-semibold text-gray-900 shadow-sm ring-1 ring-inset ring-gray-300 hover:bg-gray-50 sm:mt-0 sm:w-auto"
                        >
                          Keep Session
                        </button>
                      </div>
                    </form>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    <% end %>
    """
  end
end
