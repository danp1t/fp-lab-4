defmodule FpLab4.Steps.ReportStep do
  require Logger

  def generate_role_report(_params, context) do
    total_users = Map.get(context, :total_users) || %{users: 0}
    admin_users = Map.get(context, :admin_users) || []
    email_groups = Map.get(context, :email_groups) || %{}
    role_samples = Map.get(context, :role_samples) || %{roles: []}

    %{
      total_users: total_users[:users] || 0,
      admin_users_count: length(admin_users),
      email_groups: email_groups,
      role_samples: role_samples[:roles] || [],
      generated_at: DateTime.utc_now(),
      report_type: "role_statistics"
    }
  end
end
