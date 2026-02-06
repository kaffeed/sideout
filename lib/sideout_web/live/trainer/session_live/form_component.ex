defmodule SideoutWeb.Trainer.SessionLive.FormComponent do
  use SideoutWeb, :live_component

  alias Sideout.Scheduling
  alias Sideout.Scheduling.ConstraintResolver

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        <%= @title %>
        <:subtitle>
          <%= if @action == :new, do: "Create a new training session", else: "Update session details" %>
        </:subtitle>
      </.header>

      <.simple_form
        for={@form}
        id="session-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <!-- Template Selector (only for new sessions) -->
        <%= if @action == :new do %>
          <div>
            <.label>Start from Template (Optional)</.label>
            <p class="mt-1 text-sm text-gray-500">
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
          <p class="mt-1 text-sm text-gray-500">
            Define capacity rules (comma-separated). Examples: max_18, min_12, even, per_field_9
          </p>
          <.input
            field={@form[:capacity_constraints]}
            type="text"
            placeholder="e.g., max_18,min_12"
            required
          />

          <div class="mt-2 rounded-md bg-blue-50 p-3">
            <p class="text-xs font-medium text-blue-800">Available Constraints:</p>
            <ul class="mt-1 space-y-1 text-xs text-blue-700">
              <%= for constraint <- @available_constraints do %>
                <li>
                  <code class="rounded bg-blue-100 px-1 py-0.5"><%= constraint.example %></code>
                  - <%= constraint.description %>
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
            <%= if @action == :new, do: "Create Session", else: "Update Session" %>
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
    
    # Get list of active templates for the dropdown
    templates = Scheduling.list_session_templates(
      assigns.current_user.id, 
      active_only: true
    )
    
    template_options = 
      Enum.map(templates, fn t -> 
        {"#{t.name} (#{format_day(t.day_of_week)})", t.id}
      end)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:available_constraints, available_constraints)
     |> assign(:template_options, template_options)
     |> assign(:templates, templates)
     |> assign_form(changeset)}
  end

  @impl true
  def handle_event("template_selected", %{"session" => %{"session_template_id" => ""}}, socket) do
    # No template selected, clear form
    {:noreply, socket}
  end

  def handle_event("template_selected", %{"session" => %{"session_template_id" => template_id}}, socket) do
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

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("save", %{"session" => session_params}, socket) do
    save_session(socket, socket.assigns.action, session_params)
  end

  defp save_session(socket, :edit, session_params) do
    case Scheduling.update_session(socket.assigns.session, session_params) do
      {:ok, session} ->
        notify_parent({:saved, session})

        {:noreply,
         socket
         |> put_flash(:info, "Session updated successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp save_session(socket, :new, session_params) do
    case Scheduling.create_session(socket.assigns.current_user, session_params) do
      {:ok, session} ->
        notify_parent({:saved, session})

        {:noreply,
         socket
         |> put_flash(:info, "Session created successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset))
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})

  defp format_day(day) do
    day |> Atom.to_string() |> String.capitalize()
  end
end
