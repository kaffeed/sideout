defmodule SideoutWeb.CancellationLive do
  use SideoutWeb, :live_view

  alias Sideout.Scheduling

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    case Scheduling.get_registration_by_token(token) do
      nil ->
        {:ok,
         socket
         |> assign(:page_title, "Invalid Cancellation Link")
         |> assign(:error, :invalid_token)
         |> assign(:registration, nil)
         |> assign(:session, nil)}

      registration ->
        session = registration.session |> Sideout.Repo.preload([:session_template, :user])

        # Check if registration is already cancelled
        if registration.status == :cancelled do
          {:ok,
           socket
           |> assign(:page_title, "Already Cancelled")
           |> assign(:error, :already_cancelled)
           |> assign(:registration, registration)
           |> assign(:session, session)}
        else
          # Check if cancellation deadline has passed
          deadline_passed = cancellation_deadline_passed?(session, registration)

          {:ok,
           socket
           |> assign(:page_title, "Cancel Registration")
           |> assign(:error, nil)
           |> assign(:registration, registration)
           |> assign(:session, session)
           |> assign(:deadline_passed, deadline_passed)
           |> assign(:cancellation_reason, "")
           |> assign(:cancelling, false)
           |> assign(:cancelled_successfully, false)}
        end
    end
  end

  @impl true
  def handle_event("cancel_registration", %{"reason" => reason}, socket) do
    registration = socket.assigns.registration
    deadline_passed = socket.assigns.deadline_passed

    socket = assign(socket, :cancelling, true)

    # Allow cancellation even if deadline passed, but warn the user
    case Scheduling.cancel_registration(registration, reason) do
      {:ok, updated_registration} ->
        {:noreply,
         socket
         |> assign(:registration, updated_registration)
         |> assign(:cancelled_successfully, true)
         |> assign(:cancelling, false)
         |> assign(:deadline_warning, deadline_passed)}

      {:error, _changeset} ->
        {:noreply,
         socket
         |> assign(:error, :cancellation_failed)
         |> assign(:cancelling, false)}
    end
  end

  def handle_event("update_reason", %{"reason" => reason}, socket) do
    {:noreply, assign(socket, :cancellation_reason, reason)}
  end

  defp cancellation_deadline_passed?(session, _registration) do
    # Calculate the deadline datetime
    session_datetime = DateTime.new!(session.date, session.start_time)
    deadline = DateTime.add(session_datetime, -session.cancellation_deadline_hours, :hour)
    
    # Compare with current time
    DateTime.compare(DateTime.utc_now(), deadline) == :gt
  end

  defp cancellation_deadline_datetime(session) do
    session_datetime = DateTime.new!(session.date, session.start_time)
    DateTime.add(session_datetime, -session.cancellation_deadline_hours, :hour)
  end

  defp format_datetime(datetime) do
    Calendar.strftime(datetime, "%B %d, %Y at %I:%M %p")
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

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-50 px-4 py-16 sm:px-6 lg:px-8">
      <div class="mx-auto max-w-md">
        <!-- Invalid Token Error -->
        <%= if @error == :invalid_token do %>
          <div class="rounded-lg bg-white p-8 shadow">
            <div class="text-center">
              <svg class="mx-auto h-12 w-12 text-red-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
              </svg>
              <h2 class="mt-4 text-2xl font-bold text-gray-900">Invalid Cancellation Link</h2>
              <p class="mt-2 text-sm text-gray-600">
                This cancellation link is invalid or has expired. Please contact your trainer if you need assistance.
              </p>
            </div>
          </div>
        <% end %>

        <!-- Already Cancelled Error -->
        <%= if @error == :already_cancelled do %>
          <div class="rounded-lg bg-white p-8 shadow">
            <div class="text-center">
              <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
              </svg>
              <h2 class="mt-4 text-2xl font-bold text-gray-900">Already Cancelled</h2>
              <p class="mt-2 text-sm text-gray-600">
                This registration has already been cancelled.
              </p>
              <%= if @registration.cancelled_at do %>
                <p class="mt-1 text-xs text-gray-500">
                  Cancelled on <%= format_datetime(@registration.cancelled_at) %>
                </p>
              <% end %>
            </div>
          </div>
        <% end %>

        <!-- Cancellation Failed Error -->
        <%= if @error == :cancellation_failed do %>
          <div class="mb-4 rounded-lg bg-red-50 p-4">
            <div class="flex">
              <div class="flex-shrink-0">
                <svg class="h-5 w-5 text-red-400" viewBox="0 0 20 20" fill="currentColor">
                  <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd" />
                </svg>
              </div>
              <div class="ml-3">
                <h3 class="text-sm font-medium text-red-800">Cancellation Failed</h3>
                <p class="mt-1 text-sm text-red-700">
                  There was an error cancelling your registration. Please try again or contact your trainer.
                </p>
              </div>
            </div>
          </div>
        <% end %>

        <!-- Success Message -->
        <%= if @cancelled_successfully do %>
          <div class="rounded-lg bg-white p-8 shadow">
            <div class="text-center">
              <svg class="mx-auto h-12 w-12 text-green-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
              </svg>
              <h2 class="mt-4 text-2xl font-bold text-gray-900">Registration Cancelled</h2>
              <p class="mt-2 text-sm text-gray-600">
                Your registration has been successfully cancelled.
              </p>

              <%= if @deadline_warning do %>
                <div class="mt-4 rounded-md bg-yellow-50 p-4">
                  <p class="text-sm text-yellow-800">
                    Note: This cancellation was made after the deadline. Please be mindful of cancellation deadlines in the future.
                  </p>
                </div>
              <% end %>

              <div class="mt-6">
                <p class="text-sm text-gray-600 text-center">
                  If you have any questions or need to register for another session, please contact your trainer directly.
                </p>
              </div>
            </div>
          </div>
        <% end %>

        <!-- Cancellation Form -->
        <%= if !@error && !@cancelled_successfully do %>
          <div class="rounded-lg bg-white p-8 shadow">
            <div>
              <h2 class="text-2xl font-bold text-gray-900">Cancel Registration</h2>
              <p class="mt-2 text-sm text-gray-600">
                Are you sure you want to cancel your registration for this session?
              </p>
            </div>

            <!-- Session Details -->
            <div class="mt-6 border-t border-gray-200 pt-6">
              <dl class="space-y-4">
                <div>
                  <dt class="text-sm font-medium text-gray-500">Session Date</dt>
                  <dd class="mt-1 text-sm text-gray-900"><%= format_date(@session.date) %></dd>
                </div>
                <div>
                  <dt class="text-sm font-medium text-gray-500">Time</dt>
                  <dd class="mt-1 text-sm text-gray-900">
                    <%= format_time(@session.start_time) %> - <%= format_time(@session.end_time) %>
                  </dd>
                </div>
                <div>
                  <dt class="text-sm font-medium text-gray-500">Skill Level</dt>
                  <dd class="mt-1 text-sm text-gray-900"><%= skill_level_text(@session) %></dd>
                </div>
                <div>
                  <dt class="text-sm font-medium text-gray-500">Your Status</dt>
                  <dd class="mt-1">
                    <span class={[
                      "inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium",
                      if(@registration.status == :confirmed, 
                        do: "bg-green-100 text-green-800", 
                        else: "bg-yellow-100 text-yellow-800")
                    ]}>
                      <%= String.capitalize(to_string(@registration.status)) %>
                    </span>
                  </dd>
                </div>
              </dl>
            </div>

            <!-- Deadline Warning -->
            <%= if @deadline_passed do %>
              <div class="mt-6 rounded-md bg-yellow-50 p-4">
                <div class="flex">
                  <div class="flex-shrink-0">
                    <svg class="h-5 w-5 text-yellow-400" viewBox="0 0 20 20" fill="currentColor">
                      <path fill-rule="evenodd" d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z" clip-rule="evenodd" />
                    </svg>
                  </div>
                  <div class="ml-3">
                    <h3 class="text-sm font-medium text-yellow-800">Late Cancellation</h3>
                    <p class="mt-1 text-sm text-yellow-700">
                      The cancellation deadline was <%= format_datetime(cancellation_deadline_datetime(@session)) %>. 
                      You can still cancel, but please be mindful of deadlines in the future.
                    </p>
                  </div>
                </div>
              </div>
            <% end %>

            <!-- Cancellation Form -->
            <form phx-submit="cancel_registration" class="mt-6">
              <div>
                <label for="reason" class="block text-sm font-medium text-gray-700">
                  Reason for Cancellation <span class="text-gray-400">(optional)</span>
                </label>
                <textarea
                  id="reason"
                  name="reason"
                  rows="3"
                  phx-change="update_reason"
                  value={@cancellation_reason}
                  class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
                  placeholder="Let us know why you're cancelling..."
                ></textarea>
              </div>

              <div class="mt-6">
                <button
                  type="submit"
                  disabled={@cancelling}
                  class="w-full rounded-md bg-red-600 px-3 py-2 text-sm font-semibold text-white shadow-sm hover:bg-red-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-red-600 disabled:opacity-50 disabled:cursor-not-allowed"
                >
                  <%= if @cancelling, do: "Cancelling...", else: "Cancel Registration" %>
                </button>
                <p class="mt-4 text-center text-sm text-gray-600">
                  Changed your mind? Just close this page to keep your registration.
                </p>
              </div>
            </form>
          </div>
        <% end %>
      </div>
    </div>
    """
  end
end
