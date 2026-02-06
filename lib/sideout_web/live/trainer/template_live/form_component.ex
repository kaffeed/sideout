defmodule SideoutWeb.Trainer.TemplateLive.FormComponent do
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
          Create a reusable template for recurring training sessions.
        </:subtitle>
      </.header>

      <.simple_form
        for={@form}
        id="template-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.input field={@form[:name]} type="text" label="Template Name" required />

        <.input
          field={@form[:day_of_week]}
          type="select"
          label="Day of Week"
          options={[
            {"Monday", :monday},
            {"Tuesday", :tuesday},
            {"Wednesday", :wednesday},
            {"Thursday", :thursday},
            {"Friday", :friday},
            {"Saturday", :saturday},
            {"Sunday", :sunday}
          ]}
          required
        />

        <div class="grid grid-cols-2 gap-4">
          <.input field={@form[:start_time]} type="time" label="Start Time" required />
          <.input field={@form[:end_time]} type="time" label="End Time" required />
        </div>

        <.input
          field={@form[:skill_level]}
          type="select"
          label="Skill Level"
          options={[
            {"Beginner", :beginner},
            {"Intermediate", :intermediate},
            {"Advanced", :advanced},
            {"Mixed", :mixed}
          ]}
          required
        />

        <.input
          field={@form[:fields_available]}
          type="number"
          label="Fields Available"
          min="1"
          required
        />

        <div>
          <.label>Capacity Constraints</.label>
          <p class="mt-1 text-sm text-neutral-600 dark:text-neutral-400">
            Define capacity rules (comma-separated). Examples: max_18, min_12, even, per_field_9, divisible_by_6
          </p>
          <.input
            field={@form[:capacity_constraints]}
            type="text"
            placeholder="e.g., max_18,min_12"
            required
          />

          <div class="mt-2 rounded-md bg-info-50 dark:bg-info-900/30 p-3">
            <p class="text-xs font-medium text-info-800 dark:text-info-400">Available Constraints:</p>
            <ul class="mt-1 space-y-1 text-xs text-info-700 dark:text-info-300">
              <%= for constraint <- @available_constraints do %>
                <li>
                  <code class="rounded bg-info-100 dark:bg-info-900/50 px-1 py-0.5"><%= constraint.example %></code>
                  - <%= constraint.description %>
                </li>
              <% end %>
            </ul>
          </div>
        </div>

        <.input
          field={@form[:cancellation_deadline_hours]}
          type="number"
          label="Cancellation Deadline (hours before session)"
          min="0"
          value={24}
        />

        <.input field={@form[:active]} type="checkbox" label="Active" />

        <:actions>
          <.button phx-disable-with="Saving...">Save Template</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(%{template: template} = assigns, socket) do
    changeset = Scheduling.change_session_template(template)
    available_constraints = ConstraintResolver.available_constraints()

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:available_constraints, available_constraints)
     |> assign_form(changeset)}
  end

  @impl true
  def handle_event("validate", %{"session_template" => template_params}, socket) do
    changeset =
      socket.assigns.template
      |> Scheduling.change_session_template(template_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("save", %{"session_template" => template_params}, socket) do
    save_template(socket, socket.assigns.action, template_params)
  end

  defp save_template(socket, :edit, template_params) do
    case Scheduling.update_session_template(socket.assigns.template, template_params) do
      {:ok, template} ->
        notify_parent({:saved, template})

        {:noreply,
         socket
         |> put_flash(:info, "Template updated successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp save_template(socket, :new, template_params) do
    case Scheduling.create_session_template(socket.assigns.current_user, template_params) do
      {:ok, template} ->
        notify_parent({:saved, template})

        {:noreply,
         socket
         |> put_flash(:info, "Template created successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset))
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
