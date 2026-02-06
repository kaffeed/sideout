defmodule Sideout.Scheduling.SessionTemplate do
  use Ecto.Schema
  import Ecto.Changeset

  alias Sideout.Accounts.User
  alias Sideout.Scheduling.ConstraintResolver

  schema "session_templates" do
    field :active, :boolean, default: true
    field :name, :string
    field :day_of_week, Ecto.Enum, values: [:monday, :tuesday, :wednesday, :thursday, :friday, :saturday, :sunday]
    field :start_time, :time
    field :end_time, :time
    field :skill_level, Ecto.Enum, values: [:beginner, :intermediate, :advanced, :mixed]
    field :fields_available, :integer, default: 1
    field :capacity_constraints, :string
    field :cancellation_deadline_hours, :integer, default: 24

    # Virtual field for parsed constraints (list of individual specs)
    field :constraint_list, {:array, :any}, virtual: true

    # Virtual field for composed specification (single spec using AND composition)
    field :capacity_spec, :any, virtual: true

    belongs_to :user, User
    belongs_to :club, Sideout.Clubs.Club

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(session_template, attrs) do
    session_template
    |> cast(attrs, [:name, :day_of_week, :start_time, :end_time, :skill_level, :fields_available, :capacity_constraints, :cancellation_deadline_hours, :active, :user_id, :club_id])
    |> validate_required([:name, :day_of_week, :start_time, :end_time, :skill_level, :capacity_constraints, :club_id])
    |> validate_number(:fields_available, greater_than: 0)
    |> validate_number(:cancellation_deadline_hours, greater_than_or_equal_to: 0)
    |> validate_time_order()
    |> validate_constraint_format()
  end

  defp validate_time_order(changeset) do
    start_time = get_field(changeset, :start_time)
    end_time = get_field(changeset, :end_time)

    if start_time && end_time && Time.compare(start_time, end_time) != :lt do
      add_error(changeset, :end_time, "must be after start time")
    else
      changeset
    end
  end

  defp validate_constraint_format(changeset) do
    case get_change(changeset, :capacity_constraints) do
      nil -> changeset
      "" -> add_error(changeset, :capacity_constraints, "cannot be empty")
      constraints -> 
        # Basic validation - just check it's a string with comma-separated values
        if String.match?(constraints, ~r/^[a-z_0-9]+(,[a-z_0-9]+)*$/) do
          changeset
        else
          add_error(changeset, :capacity_constraints, "must be comma-separated constraint names (e.g., 'max_18,min_12')")
        end
    end
  end

  @doc """
  Returns template with parsed constraint list in virtual field.

  ## Examples

      iex> template = get_template!(1)
      iex> template |> SessionTemplate.with_parsed_constraints()
      %SessionTemplate{constraint_list: [%MaxCapacityConstraint{...}, ...]}

  """
  def with_parsed_constraints(%__MODULE__{} = template) do
    constraints = ConstraintResolver.parse_constraints(
      template.capacity_constraints,
      template.fields_available
    )
    %{template | constraint_list: constraints}
  end

  @doc """
  Returns template with composed specification in virtual field.

  The composed specification combines all constraints using AND logic.

  ## Examples

      iex> template = get_template!(1)
      iex> template |> SessionTemplate.with_capacity_spec()
      %SessionTemplate{capacity_spec: %AndSpecification{...}}

  """
  def with_capacity_spec(%__MODULE__{capacity_spec: spec} = template) when not is_nil(spec) do
    # If capacity_spec is already set, return as-is
    template
  end

  def with_capacity_spec(%__MODULE__{} = template) do
    # Parse from string and compose with AND
    spec = ConstraintResolver.parse_to_specification(
      template.capacity_constraints,
      template.fields_available
    )
    %{template | capacity_spec: spec}
  end
end
