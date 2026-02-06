defmodule SideoutWeb.Trainer.TemplateLive.Show do
  use SideoutWeb, :live_view

  alias Sideout.Scheduling

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _url, socket) do
    template = Scheduling.get_session_template!(id, preload: [:user])

    {:noreply,
     socket
     |> assign(:page_title, "Template Details")
     |> assign(:template, template)}
  end

  defp format_time(time) do
    Calendar.strftime(time, "%H:%M")
  end

  defp format_day(day) do
    day |> Atom.to_string() |> String.capitalize()
  end

  defp format_skill_level(level) do
    level |> Atom.to_string() |> String.capitalize()
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="px-4 py-8 sm:px-6 lg:px-8">
      <div class="mx-auto max-w-3xl">
        <!-- Header -->
        <div class="mb-6">
          <.link navigate={~p"/trainer/templates"} class="text-sm text-primary-600 hover:text-primary-500 dark:text-primary-400 dark:hover:text-primary-300 transition-colors">
            ← Back to Templates
          </.link>
        </div>

        <div class="overflow-hidden bg-white dark:bg-secondary-800 shadow-sporty border-t-4 border-primary-500 sm:rounded-lg">
          <div class="px-4 py-5 sm:px-6">
            <div class="flex items-center justify-between">
              <div>
                <h3 class="text-base font-semibold leading-6 text-neutral-900 dark:text-neutral-100">
                  <%= @template.name %>
                </h3>
                <p class="mt-1 max-w-2xl text-sm text-neutral-600 dark:text-neutral-400">Template details and configuration</p>
              </div>
              <div class="flex gap-2">
                <.link
                  navigate={~p"/trainer/templates/#{@template.id}/edit"}
                  class="rounded-md bg-white px-3 py-2 text-sm font-semibold text-neutral-900 shadow-sm ring-1 ring-inset ring-neutral-300 hover:bg-neutral-50 transition-all duration-200 dark:bg-secondary-700 dark:text-neutral-100 dark:ring-secondary-600 dark:hover:bg-secondary-600"
                >
                  Edit
                </.link>
              </div>
            </div>
          </div>
          <div class="border-t border-neutral-200 dark:border-secondary-700">
            <dl class="divide-y divide-neutral-200 dark:divide-secondary-700">
              <div class="px-4 py-5 sm:grid sm:grid-cols-3 sm:gap-4 sm:px-6">
                <dt class="text-sm font-medium text-neutral-600 dark:text-neutral-400">Status</dt>
                <dd class="mt-1 text-sm text-neutral-900 dark:text-neutral-100 sm:col-span-2 sm:mt-0">
                  <%= if @template.active do %>
                    <span class="inline-flex items-center rounded-full bg-success-50 px-2 py-1 text-xs font-medium text-success-700 ring-1 ring-inset ring-success-600/20 dark:bg-success-900/30 dark:text-success-400 dark:ring-success-400/30">
                      Active
                    </span>
                  <% else %>
                    <span class="inline-flex items-center rounded-full bg-neutral-100 px-2 py-1 text-xs font-medium text-neutral-600 ring-1 ring-inset ring-neutral-500/10 dark:bg-secondary-700 dark:text-neutral-400 dark:ring-neutral-400/20">
                      Inactive
                    </span>
                  <% end %>
                </dd>
              </div>

              <div class="px-4 py-5 sm:grid sm:grid-cols-3 sm:gap-4 sm:px-6">
                <dt class="text-sm font-medium text-neutral-600 dark:text-neutral-400">Day of Week</dt>
                <dd class="mt-1 text-sm text-neutral-900 dark:text-neutral-100 sm:col-span-2 sm:mt-0">
                  <%= format_day(@template.day_of_week) %>
                </dd>
              </div>

              <div class="px-4 py-5 sm:grid sm:grid-cols-3 sm:gap-4 sm:px-6">
                <dt class="text-sm font-medium text-neutral-600 dark:text-neutral-400">Time</dt>
                <dd class="mt-1 text-sm text-neutral-900 dark:text-neutral-100 sm:col-span-2 sm:mt-0">
                  <%= format_time(@template.start_time) %> - <%= format_time(@template.end_time) %>
                </dd>
              </div>

              <div class="px-4 py-5 sm:grid sm:grid-cols-3 sm:gap-4 sm:px-6">
                <dt class="text-sm font-medium text-neutral-600 dark:text-neutral-400">Skill Level</dt>
                <dd class="mt-1 text-sm text-neutral-900 dark:text-neutral-100 sm:col-span-2 sm:mt-0">
                  <%= format_skill_level(@template.skill_level) %>
                </dd>
              </div>

              <div class="px-4 py-5 sm:grid sm:grid-cols-3 sm:gap-4 sm:px-6">
                <dt class="text-sm font-medium text-neutral-600 dark:text-neutral-400">Fields Available</dt>
                <dd class="mt-1 text-sm text-neutral-900 dark:text-neutral-100 sm:col-span-2 sm:mt-0">
                  <%= @template.fields_available %>
                </dd>
              </div>

              <div class="px-4 py-5 sm:grid sm:grid-cols-3 sm:gap-4 sm:px-6">
                <dt class="text-sm font-medium text-neutral-600 dark:text-neutral-400">Capacity Constraints</dt>
                <dd class="mt-1 text-sm text-neutral-900 dark:text-neutral-100 sm:col-span-2 sm:mt-0">
                  <code class="rounded bg-neutral-100 px-2 py-1 dark:bg-secondary-700 dark:text-neutral-300"><%= @template.capacity_constraints %></code>
                </dd>
              </div>

              <div class="px-4 py-5 sm:grid sm:grid-cols-3 sm:gap-4 sm:px-6">
                <dt class="text-sm font-medium text-neutral-600 dark:text-neutral-400">Cancellation Deadline</dt>
                <dd class="mt-1 text-sm text-neutral-900 dark:text-neutral-100 sm:col-span-2 sm:mt-0">
                  <%= @template.cancellation_deadline_hours %> hours before session
                </dd>
              </div>
            </dl>
          </div>
        </div>

        <!-- Actions -->
        <div class="mt-6 flex gap-3">
          <.link
            navigate={~p"/trainer/sessions/new?template_id=#{@template.id}"}
            class="rounded-md bg-primary-500 px-3 py-2 text-sm font-semibold text-white shadow-md hover:bg-primary-600 hover:shadow-sporty transition-all duration-200"
          >
            Create Session from Template
          </.link>
        </div>
      </div>
    </div>
    """
  end
end
