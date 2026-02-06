defmodule SideoutWeb.Trainer.SessionLive.FormComponent do
  use SideoutWeb, :live_component

  alias Sideout.Scheduling
  alias Sideout.Scheduling.ConstraintResolver
  alias Sideout.Clubs

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        {@title}
        <:subtitle>
          {if @action == :new, do: "Create a new training session", else: "Update session details"}
        </:subtitle>
      </.header>

      <.simple_form
        for={@form}
        id="session-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <!-- Club Selector -->
        <div>
          <.label>Club</.label>
          <p class="mt-1 text-sm text-neutral-600 dark:text-neutral-400">
            Select which club this session belongs to
          </p>
          <.input field={@form[:club_id]} type="select" options={@club_options} required />
        </div>
        
    <!-- Template Selector (only for new sessions) -->
        <%= if @action == :new do %>
          <div>
            <.label>Start from Template (Optional)</.label>
            <p class="mt-1 text-sm text-neutral-600 dark:text-neutral-400">
              Select a template to auto-populate fields, or leave blank for a one-off session
            </p>
            <.input
              field={@form[:session_template_id]}
              type="select"
              options={[{"-- No Template (One-off Session) --", nil}] ++ @template_options}
              phx-target={@myself}
              phx-change="template_selected"
            />
          </div>
        <% end %>
        
    <!-- Date -->
        <.input field={@form[:date]} type="date" label="Session Date" required />
        
    <!-- Time Range -->
        <div class="grid grid-cols-2 gap-4">
          <.input field={@form[:start_time]} type="time" label="Start Time" required />
          <.input field={@form[:end_time]} type="time" label="End Time" required />
        </div>
        
    <!-- Fields Available -->
        <.input
          field={@form[:fields_available]}
          type="number"
          label="Fields Available"
          min="1"
          required
        />
        
    <!-- Capacity Constraints -->
        <div>
          <.label>Capacity Constraints</.label>
          <p class="mt-1 text-sm text-neutral-600 dark:text-neutral-400">
            Define capacity rules (comma-separated). Examples: max_18, min_12, even, per_field_9
          </p>
          <.input
            field={@form[:capacity_constraints]}
            type="text"
            placeholder="e.g., max_18,min_12"
            required
          />

          <div class="mt-2 rounded-md bg-info-50 p-3 dark:bg-info-900/30">
            <p class="text-xs font-medium text-info-800 dark:text-info-400">Available Constraints:</p>
            <ul class="mt-1 space-y-1 text-xs text-info-700 dark:text-info-300">
              <%= for constraint <- @available_constraints do %>
                <li>
                  <code class="rounded bg-info-100 px-1 py-0.5 dark:bg-info-900/50">
                    {constraint.example}
                  </code>
                  - {constraint.description}
                </li>
              <% end %>
            </ul>
          </div>
        </div>
        
    <!-- Cancellation Deadline -->
        <.input
          field={@form[:cancellation_deadline_hours]}
          type="number"
          label="Cancellation Deadline (hours before session)"
          min="0"
        />
        
    <!-- Notes -->
        <.input field={@form[:notes]} type="textarea" label="Notes (optional)" rows="3" />
        
    <!-- Co-trainers (multi-select) -->
        <%= if @action == :new || @action == :edit do %>
          <div>
            <.label>Co-trainers (Optional)</.label>
            <p class="mt-1 text-sm text-neutral-600 dark:text-neutral-400">
              Select trainers from your club to help manage this session
            </p>
            <select
              name="cotrainer_ids[]"
              multiple
              class="block w-full rounded-md border-neutral-300 shadow-sm focus:border-primary-500 focus:ring-primary-500 sm:text-sm dark:border-secondary-600 dark:bg-secondary-700 dark:text-neutral-100"
              size="5"
            >
              <%= for trainer <- @available_cotrainers do %>
                <option value={trainer.id} selected={trainer.id in @selected_cotrainer_ids}>
                  {trainer.email}
                </option>
              <% end %>
            </select>
          </div>
          
    <!-- Guest Clubs (multi-select) -->
          <div>
            <.label>Guest Clubs (Optional)</.label>
            <p class="mt-1 text-sm text-neutral-600 dark:text-neutral-400">
              Invite other clubs to participate in this session
            </p>
            <select
              name="guest_club_ids[]"
              multiple
              class="block w-full rounded-md border-neutral-300 shadow-sm focus:border-primary-500 focus:ring-primary-500 sm:text-sm dark:border-secondary-600 dark:bg-secondary-700 dark:text-neutral-100"
              size="5"
            >
              <%= for club <- @available_guest_clubs do %>
                <option value={club.id} selected={club.id in @selected_guest_club_ids}>
                  {club.name}
                </option>
              <% end %>
            </select>
          </div>
        <% end %>
        
    <!-- Status (only when editing) -->
        <%= if @action == :edit do %>
          <.input
            field={@form[:status]}
            type="select"
            label="Session Status"
            options={[
              {"Scheduled", :scheduled},
              {"In Progress", :in_progress},
              {"Completed", :completed},
              {"Cancelled", :cancelled}
            ]}
          />
        <% end %>

        <:actions>
          <.button phx-disable-with="Saving...">
            {if @action == :new, do: "Create Session", else: "Update Session"}
          </.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(%{session: session} = assigns, socket) do
    changeset = Scheduling.change_session(session)
    available_constraints = ConstraintResolver.available_constraints()

    user = assigns.current_user

    # Get list of active templates for the dropdown
    templates =
      Scheduling.list_session_templates(
        user.id,
        active_only: true
      )

    template_options =
      Enum.map(templates, fn t ->
        {"#{t.name} (#{format_day(t.day_of_week)})", t.id}
      end)

    # Get user's clubs for club selector
    user_clubs = Clubs.list_clubs_for_user(user.id)

    club_options =
      Enum.map(user_clubs, fn membership ->
        {membership.club.name, membership.club.id}
      end)

    # Get available co-trainers (club members, excluding current user)
    available_cotrainers =
      if session.club_id do
        Clubs.list_members(session.club_id)
        |> Enum.map(& &1.user)
        |> Enum.reject(&(&1.id == user.id))
      else
        []
      end

    # Get existing co-trainers for this session
    selected_cotrainer_ids =
      if session.id do
        Scheduling.list_cotrainers(session)
        |> Enum.map(& &1.id)
      else
        []
      end

    # Get all clubs except the primary club for guest club selector
    all_clubs = Clubs.list_clubs()

    available_guest_clubs =
      if session.club_id do
        Enum.reject(all_clubs, &(&1.id == session.club_id))
      else
        all_clubs
      end

    # Get existing guest clubs for this session
    selected_guest_club_ids =
      if session.id do
        Scheduling.list_guest_clubs(session)
        |> Enum.map(& &1.club_id)
      else
        []
      end

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:available_constraints, available_constraints)
     |> assign(:template_options, template_options)
     |> assign(:templates, templates)
     |> assign(:club_options, club_options)
     |> assign(:available_cotrainers, available_cotrainers)
     |> assign(:selected_cotrainer_ids, selected_cotrainer_ids)
     |> assign(:available_guest_clubs, available_guest_clubs)
     |> assign(:selected_guest_club_ids, selected_guest_club_ids)
     |> assign_form(changeset)}
  end

  @impl true
  def handle_event("template_selected", %{"session" => %{"session_template_id" => ""}}, socket) do
    # No template selected, clear form
    {:noreply, socket}
  end

  def handle_event(
        "template_selected",
        %{"session" => %{"session_template_id" => template_id}},
        socket
      ) do
    case Integer.parse(template_id) do
      {id, ""} ->
        template = Enum.find(socket.assigns.templates, &(&1.id == id))

        if template do
          # Pre-populate form with template values
          attrs = %{
            "start_time" => Time.to_string(template.start_time),
            "end_time" => Time.to_string(template.end_time),
            "fields_available" => template.fields_available,
            "capacity_constraints" => template.capacity_constraints,
            "cancellation_deadline_hours" => template.cancellation_deadline_hours,
            "session_template_id" => template_id
          }

          changeset =
            socket.assigns.session
            |> Scheduling.change_session(attrs)
            |> Map.put(:action, :validate)

          {:noreply, assign_form(socket, changeset)}
        else
          {:noreply, socket}
        end

      _ ->
        {:noreply, socket}
    end
  end

  def handle_event("validate", %{"session" => session_params}, socket) do
    changeset =
      socket.assigns.session
      |> Scheduling.change_session(session_params)
      |> Map.put(:action, :validate)

    # Check if club_id changed - if so, refresh available co-trainers
    socket = maybe_update_cotrainers(socket, session_params)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("save", %{"session" => session_params} = params, socket) do
    # Extract cotrainer and guest club IDs
    cotrainer_ids = Map.get(params, "cotrainer_ids", []) |> Enum.map(&String.to_integer/1)
    guest_club_ids = Map.get(params, "guest_club_ids", []) |> Enum.map(&String.to_integer/1)

    save_session(socket, socket.assigns.action, session_params, cotrainer_ids, guest_club_ids)
  end

  defp maybe_update_cotrainers(socket, session_params) do
    user = socket.assigns.current_user
    new_club_id = Map.get(session_params, "club_id")
    current_club_id = socket.assigns.session.club_id

    # Only update if club_id actually changed
    club_id_changed =
      case new_club_id do
        nil ->
          false

        "" ->
          current_club_id != nil

        id when is_binary(id) ->
          new_id = String.to_integer(id)
          new_id != current_club_id

        id when is_integer(id) ->
          id != current_club_id
      end

    if club_id_changed do
      available_cotrainers =
        case new_club_id do
          nil ->
            []

          "" ->
            []

          id when is_binary(id) ->
            Clubs.list_members(String.to_integer(id))
            |> Enum.map(& &1.user)
            |> Enum.reject(&(&1.id == user.id))

          id when is_integer(id) ->
            Clubs.list_members(id)
            |> Enum.map(& &1.user)
            |> Enum.reject(&(&1.id == user.id))
        end

      # Also update available guest clubs
      all_clubs = Clubs.list_clubs()

      available_guest_clubs =
        case new_club_id do
          nil ->
            all_clubs

          "" ->
            all_clubs

          id when is_binary(id) ->
            new_id = String.to_integer(id)
            Enum.reject(all_clubs, &(&1.id == new_id))

          id when is_integer(id) ->
            Enum.reject(all_clubs, &(&1.id == id))
        end

      socket
      |> assign(:available_cotrainers, available_cotrainers)
      |> assign(:available_guest_clubs, available_guest_clubs)
    else
      socket
    end
  end

  defp save_session(socket, :edit, session_params, cotrainer_ids, guest_club_ids) do
    session = socket.assigns.session
    user = socket.assigns.current_user

    case Scheduling.update_session(session, session_params) do
      {:ok, updated_session} ->
        # Update co-trainers
        update_cotrainers(updated_session, cotrainer_ids, user.id)

        # Update guest clubs
        update_guest_clubs(updated_session, guest_club_ids, user.id)

        notify_parent({:saved, updated_session})

        {:noreply,
         socket
         |> put_flash(:info, "Session updated successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp save_session(socket, :new, session_params, cotrainer_ids, guest_club_ids) do
    user = socket.assigns.current_user

    case Scheduling.create_session(user, session_params) do
      {:ok, session} ->
        # Add co-trainers
        update_cotrainers(session, cotrainer_ids, user.id)

        # Add guest clubs
        update_guest_clubs(session, guest_club_ids, user.id)

        notify_parent({:saved, session})

        {:noreply,
         socket
         |> put_flash(:info, "Session created successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp update_cotrainers(session, cotrainer_ids, added_by_user_id) do
    # Get existing co-trainer IDs
    existing_ids = Scheduling.list_cotrainers(session) |> Enum.map(& &1.id)

    # Remove co-trainers that are no longer selected
    to_remove = existing_ids -- cotrainer_ids

    Enum.each(to_remove, fn cotrainer_id ->
      Scheduling.remove_cotrainer(session, cotrainer_id)
    end)

    # Add new co-trainers
    to_add = cotrainer_ids -- existing_ids

    Enum.each(to_add, fn cotrainer_id ->
      Scheduling.add_cotrainer(session, cotrainer_id, added_by_user_id)
    end)
  end

  defp update_guest_clubs(session, guest_club_ids, invited_by_user_id) do
    # Get existing guest club IDs
    existing_ids = Scheduling.list_guest_clubs(session) |> Enum.map(& &1.club_id)

    # Remove guest clubs that are no longer selected
    to_remove = existing_ids -- guest_club_ids

    Enum.each(to_remove, fn club_id ->
      Scheduling.remove_guest_club(session, club_id)
    end)

    # Add new guest clubs
    to_add = guest_club_ids -- existing_ids

    Enum.each(to_add, fn club_id ->
      Scheduling.invite_guest_club(session, club_id, invited_by_user_id)
    end)
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset))
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})

  defp format_day(day) do
    day |> Atom.to_string() |> String.capitalize()
  end
end
