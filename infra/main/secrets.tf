# Laravel APP_KEY. Terraform only creates the secret (the container for the
# value); the value itself is written once from outside Terraform with
# `aws secretsmanager put-secret-value`, so it never appears in the code, the
# plan or the state.
#
# The database password does not need a secret here: RDS manages it
# (see rds.tf, manage_master_user_password).

resource "aws_secretsmanager_secret" "app_key" {
  name        = "${var.project}/app-key"
  description = "Laravel APP_KEY for ${var.project}"

  # Delete immediately on destroy instead of the default 30-day recovery
  # window, so the same name can be reused right away. Production would keep
  # a recovery window.
  recovery_window_in_days = 0
}
