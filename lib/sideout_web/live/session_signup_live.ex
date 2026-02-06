defmodule SideoutWeb.SessionSignupLive do
  use SideoutWeb, :live_view

  alias Sideout.Scheduling

  @impl true
  def mount(%{"share_token" => token}, _session, socket) do
    case Scheduling.get_session_by_share_token(token, preload: [:session_template, :user, registrations: :player]) do
      nil ->
        {:ok,
         socket
         |> assign(:error_type, get_error_type(token))
         |> assign(:page_title, "Session Not Found")}

      session ->
        if connected?(socket) do
          Phoenix.PubSub.subscribe(Sideout.PubSub, "sessions:updates")
          Phoenix.PubSub.subscribe(Sideout.PubSub, "session:#{session.id}")
        end

        {:ok,
         socket
         |> assign(:session, session)
         |> assign(:error_type, nil)
         |> assign(:capacity_info, capacity_info(session))
         |> assign(:page_title, "Register for Session")
         |> assign(:form, to_form(%{"player_name" => "", "email" => "", "phone" => ""}))
         |> assign(:registration_result, nil)
         |> assign(:errors, [])}
    end
  end

  @impl true
  def handle_event("register", %{"player_name" => name, "email" => email, "phone" => phone}, socket) do
    session = socket.assigns.session

    # Validate required fields
    if String.trim(name) == "" do
      {:noreply, assign(socket, :errors, ["Name is required"])}
    else
      # Get or create player
      player_attrs = %{
        "name" => String.trim(name),
        "email" => if(String.trim(email) != "", do: String.trim(email), else: nil),
        "phone" => if(String.trim(phone) != "", do: String.trim(phone), else: nil)
      }

      case Scheduling.get_or_create_player_by_name(player_attrs["name"], player_attrs) do
        {:ok, player} ->
          # Check if player is already registered
          case check_existing_registration(session, player) do
            {:ok, :not_registered} ->
              # Register the player
              case Scheduling.register_player(session, player) do
                {:ok, registration} ->
                  # Clear form and show success
                  {:noreply,
                   socket
                   |> assign(:form, to_form(%{"player_name" => "", "email" => "", "phone" => ""}))
                   |> assign(:registration_result, {:success, registration})
                   |> assign(:errors, [])
                   |> reload_session()}

                {:error, changeset} ->
                  errors = extract_errors(changeset)
                  {:noreply, assign(socket, :errors, errors)}
              end

            {:error, message} ->
              {:noreply, assign(socket, :errors, [message])}
          end

        {:error, changeset} ->
          errors = extract_errors(changeset)
          {:noreply, assign(socket, :errors, errors)}
      end
    end
  end

  def handle_event("clear_result", _params, socket) do
    {:noreply, assign(socket, :registration_result, nil)}
  end

  @impl true
  def handle_info({:session_updated, payload}, socket) do
    if socket.assigns.error_type == nil && payload.session_id == socket.assigns.session.id do
      {:noreply, reload_session(socket)}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:registration_changed, _payload}, socket) do
    if socket.assigns.error_type == nil do
      {:noreply, reload_session(socket)}
    else
      {:noreply, socket}
    end
  end

  defp reload_session(socket) do
    session = Scheduling.get_session!(socket.assigns.session.id, preload: [:session_template, :user, registrations: :player])

    socket
    |> assign(:session, session)
    |> assign(:capacity_info, capacity_info(session))
  end

  defp get_error_type(token) do
    if Sideout.Scheduling.ShareToken.valid?(token) do
      # Token is valid format, check if it exists or is expired
      case Sideout.Repo.get_by(Sideout.Scheduling.Session, share_token: token) do
        nil -> :invalid_token
        %{status: :cancelled} -> :cancelled_session
        %{status: :completed} -> :expired_session
        %{date: date} ->
          if Date.compare(date, Date.utc_today()) == :lt do
            :expired_session
          else
            :invalid_token
          end
      end
    else
      :invalid_token
    end
  end

  defp check_existing_registration(session, player) do
    existing = Enum.find(session.registrations, fn reg ->
      reg.player_id == player.id && reg.status in [:confirmed, :waitlisted]
    end)

    case existing do
      nil -> {:ok, :not_registered}
      reg ->
        status_text = if reg.status == :confirmed, do: "confirmed", else: "waitlisted"
        {:error, "You are already registered for this session (#{status_text})"}
    end
  end

  defp extract_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
    |> Enum.map(fn {field, errors} ->
      "#{field}: #{Enum.join(errors, ", ")}"
    end)
  end

  defp capacity_info(session) do
    capacity_status = Scheduling.get_capacity_status(session)
    max_capacity = Scheduling.get_max_capacity(session)

    %{
      confirmed: capacity_status.confirmed,
      max: max_capacity,
      waitlisted: capacity_status.waitlist,
      spots_available: max_capacity - capacity_status.confirmed,
      is_full: capacity_status.confirmed >= max_capacity
    }
  end

  defp format_date(date) do
    Calendar.strftime(date, "%A, %B %d, %Y")
  end

  defp format_time(time) do
    Calendar.strftime(time, "%I:%M %p")
  end

  defp skill_level_text(session) do
    if session.session_template do
      session.session_template.skill_level
      |> to_string()
      |> String.capitalize()
    else
      "Mixed"
    end
  end

  defp confirmed_registrations(session) do
    Enum.filter(session.registrations, &(&1.status == :confirmed))
    |> Enum.sort_by(& &1.registered_at)
  end

  defp waitlisted_registrations(session) do
    Enum.filter(session.registrations, &(&1.status == :waitlisted))
    |> Enum.sort_by(& &1.priority_score, :desc)
  end

  defp cancellation_url(registration) do
    if registration.cancellation_token do
      ~p"/cancel/#{registration.cancellation_token}"
    else
      nil
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <%= if @error_type do %>
      <div class="min-h-screen bg-gray-50 flex items-center justify-center px-4">
        <div class="max-w-md w-full">
          <div class="text-center">
            <svg class="mx-auto h-12 w-12 text-red-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
            </svg>

            <h2 class="mt-6 text-2xl font-bold text-gray-900">
              <%= case @error_type do %>
                <% :invalid_token -> %>Session Not Found
                <% :expired_session -> %>Session Expired
                <% :cancelled_session -> %>Session Cancelled
              <% end %>
            </h2>

            <p class="mt-2 text-sm text-gray-600">
              <%= case @error_type do %>
                <% :invalid_token -> %>
                  This session link is invalid or doesn't exist. Please check the link and try again.
                <% :expired_session -> %>
                  This session has already passed. Registration is no longer available.
                <% :cancelled_session -> %>
                  This session has been cancelled by the trainer.
              <% end %>
            </p>

            <div class="mt-6">
              <p class="text-sm text-gray-500">
                If you believe this is an error, please contact the session organizer.
              </p>
            </div>
          </div>
        </div>
      </div>
    <% else %>
      <div class="min-h-screen bg-gray-50">
        <!-- Header -->
        <div class="bg-white shadow">
          <div class="mx-auto max-w-7xl px-4 py-6 sm:px-6 lg:px-8">
            <div class="md:flex md:items-center md:justify-between">
              <div class="min-w-0 flex-1">
                <h1 class="text-3xl font-bold text-gray-900">Session Registration</h1>
              </div>
            </div>
          </div>
        </div>

        <div class="mx-auto max-w-7xl px-4 py-8 sm:px-6 lg:px-8">
          <div class="grid gap-8 lg:grid-cols-3">
            <!-- Session Information (Left Column) -->
            <div class="lg:col-span-2 space-y-6">
              <!-- Main Info Card -->
              <div class="overflow-hidden rounded-lg bg-white shadow">
                <div class="px-6 py-5">
                  <div class="flex items-start justify-between">
                    <div>
                      <h2 class="text-2xl font-bold text-gray-900">
                        <%= format_date(@session.date) %>
                      </h2>
                      <p class="mt-1 text-lg text-gray-600">
                        <%= format_time(@session.start_time) %> - <%= format_time(@session.end_time) %>
                      </p>
                    </div>
                    <span class={[
                      "inline-flex items-center rounded-full px-3 py-1 text-sm font-medium",
                      if(@capacity_info.is_full,
                        do: "bg-red-100 text-red-800",
                        else: "bg-green-100 text-green-800")
                    ]}>
                      <%= if @capacity_info.is_full, do: "Full", else: "Open" %>
                    </span>
                  </div>

                  <dl class="mt-6 grid grid-cols-1 gap-x-4 gap-y-6 sm:grid-cols-2">
                    <div>
                      <dt class="text-sm font-medium text-gray-500">Skill Level</dt>
                      <dd class="mt-1 text-sm text-gray-900"><%= skill_level_text(@session) %></dd>
                    </div>
                    <div>
                      <dt class="text-sm font-medium text-gray-500">Fields Available</dt>
                      <dd class="mt-1 text-sm text-gray-900"><%= @session.fields_available %></dd>
                    </div>
                    <div>
                      <dt class="text-sm font-medium text-gray-500">Capacity</dt>
                      <dd class="mt-1 text-sm text-gray-900">
                        <%= @capacity_info.confirmed %> / <%= @capacity_info.max %> players
                      </dd>
                    </div>
                    <div>
                      <dt class="text-sm font-medium text-gray-500">Cancellation Deadline</dt>
                      <dd class="mt-1 text-sm text-gray-900">
                        <%= @session.cancellation_deadline_hours %> hours before
                      </dd>
                    </div>
                  </dl>

                  <%= if @session.notes do %>
                    <div class="mt-6">
                      <dt class="text-sm font-medium text-gray-500">Session Notes</dt>
                      <dd class="mt-1 text-sm text-gray-900"><%= @session.notes %></dd>
                    </div>
                  <% end %>
                </div>
              </div>

              <!-- Registered Players -->
              <div class="overflow-hidden rounded-lg bg-white shadow">
                <div class="px-6 py-5">
                  <h3 class="text-lg font-medium text-gray-900">
                    Confirmed Players (<%= length(confirmed_registrations(@session)) %>)
                  </h3>
                  <div class="mt-4">
                    <%= if Enum.empty?(confirmed_registrations(@session)) do %>
                      <p class="text-sm text-gray-500">No players registered yet</p>
                    <% else %>
                      <ul class="divide-y divide-gray-200">
                        <%= for registration <- confirmed_registrations(@session) do %>
                          <li class="py-3">
                            <div class="flex items-center justify-between">
                              <span class="text-sm font-medium text-gray-900">
                                <%= registration.player.name %>
                              </span>
                              <span class="text-xs text-gray-500">
                                Registered <%= Calendar.strftime(registration.registered_at, "%b %d") %>
                              </span>
                            </div>
                          </li>
                        <% end %>
                      </ul>
                    <% end %>
                  </div>
                </div>
              </div>

              <!-- Waitlist -->
              <%= if @capacity_info.waitlisted > 0 do %>
                <div class="overflow-hidden rounded-lg bg-white shadow">
                  <div class="px-6 py-5">
                    <h3 class="text-lg font-medium text-gray-900">
                      Waitlist (<%= @capacity_info.waitlisted %>)
                    </h3>
                    <div class="mt-4">
                      <ul class="divide-y divide-gray-200">
                        <%= for {registration, index} <- Enum.with_index(waitlisted_registrations(@session), 1) do %>
                          <li class="py-3">
                            <div class="flex items-center justify-between">
                              <div>
                                <span class="text-xs font-medium text-gray-500 mr-2">#<%= index %></span>
                                <span class="text-sm font-medium text-gray-900">
                                  <%= registration.player.name %>
                                </span>
                              </div>
                              <span class="text-xs text-gray-500">
                                Priority: <%= Decimal.round(registration.priority_score || 0, 1) %>
                              </span>
                            </div>
                          </li>
                        <% end %>
                      </ul>
                    </div>
                  </div>
                </div>
              <% end %>
            </div>

            <!-- Registration Form (Right Column) -->
            <div class="lg:col-span-1">
              <div class="sticky top-8">
                <!-- Success Message -->
                <%= if @registration_result do %>
                  <div class="mb-6 rounded-lg bg-green-50 p-4">
                    <div class="flex">
                      <div class="flex-shrink-0">
                        <svg class="h-5 w-5 text-green-400" viewBox="0 0 20 20" fill="currentColor">
                          <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd" />
                        </svg>
                      </div>
                      <div class="ml-3">
                        <% {_, registration} = @registration_result %>
                        <h3 class="text-sm font-medium text-green-800">
                          <%= if registration.status == :confirmed do %>
                            Successfully Registered!
                          <% else %>
                            Added to Waitlist
                          <% end %>
                        </h3>
                        <div class="mt-2 text-sm text-green-700">
                          <p>
                            <%= if registration.status == :confirmed do %>
                              You're confirmed for this session.
                            <% else %>
                              You're on the waitlist. We'll notify you if a spot opens up.
                            <% end %>
                          </p>
                          <%= if cancellation_url(registration) do %>
                            <p class="mt-2">
                              To cancel, visit:
                              <.link href={cancellation_url(registration)} class="font-medium underline">
                                Cancellation Link
                              </.link>
                            </p>
                          <% end %>
                        </div>
                        <button
                          phx-click="clear_result"
                          class="mt-3 text-sm font-medium text-green-800 underline hover:text-green-900"
                        >
                          Dismiss
                        </button>
                      </div>
                    </div>
                  </div>
                <% end %>

                <!-- Error Messages -->
                <%= if !Enum.empty?(@errors) do %>
                  <div class="mb-6 rounded-lg bg-red-50 p-4">
                    <div class="flex">
                      <div class="flex-shrink-0">
                        <svg class="h-5 w-5 text-red-400" viewBox="0 0 20 20" fill="currentColor">
                          <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd" />
                        </svg>
                      </div>
                      <div class="ml-3">
                        <h3 class="text-sm font-medium text-red-800">Registration Error</h3>
                        <div class="mt-2 text-sm text-red-700">
                          <ul class="list-disc space-y-1 pl-5">
                            <%= for error <- @errors do %>
                              <li><%= error %></li>
                            <% end %>
                          </ul>
                        </div>
                      </div>
                    </div>
                  </div>
                <% end %>

                <!-- Registration Form -->
                <div class="overflow-hidden rounded-lg bg-white shadow">
                  <div class="px-6 py-5">
                    <h3 class="text-lg font-medium text-gray-900">Register for Session</h3>
                    <p class="mt-1 text-sm text-gray-500">
                      <%= if @capacity_info.is_full do %>
                        Session is full. You will be added to the waitlist.
                      <% else %>
                        <%= @capacity_info.spots_available %> spot<%= if @capacity_info.spots_available != 1, do: "s" %> remaining
                      <% end %>
                    </p>

                    <form phx-submit="register" class="mt-6 space-y-4">
                      <div>
                        <label for="player_name" class="block text-sm font-medium text-gray-700">
                          Name <span class="text-red-600">*</span>
                        </label>
                        <input
                          type="text"
                          name="player_name"
                          id="player_name"
                          required
                          value={@form[:player_name].value}
                          class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
                          placeholder="Your full name"
                        />
                      </div>

                      <div>
                        <label for="email" class="block text-sm font-medium text-gray-700">
                          Email <span class="text-gray-400">(optional)</span>
                        </label>
                        <input
                          type="email"
                          name="email"
                          id="email"
                          value={@form[:email].value}
                          class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
                          placeholder="your.email@example.com"
                        />
                      </div>

                      <div>
                        <label for="phone" class="block text-sm font-medium text-gray-700">
                          Phone <span class="text-gray-400">(optional)</span>
                        </label>
                        <input
                          type="tel"
                          name="phone"
                          id="phone"
                          value={@form[:phone].value}
                          class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
                          placeholder="(555) 123-4567"
                        />
                      </div>

                      <button
                        type="submit"
                        class="w-full rounded-md bg-indigo-600 px-3 py-2 text-sm font-semibold text-white shadow-sm hover:bg-indigo-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600"
                      >
                        <%= if @capacity_info.is_full do %>
                          Join Waitlist
                        <% else %>
                          Register Now
                        <% end %>
                      </button>
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
