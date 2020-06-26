module "service" {
  source                 = "../../modules/ecs_service"
  region                 = "${var.region}"
  project_name           = "${var.project_name}"
  environment_name       = "${var.environment_name}"
  short_environment_name = "${var.short_environment_name}"
  tags                   = "${var.tags}"

  service_name          = "${local.app_name}"
  container_definition  = "${data.template_file.container_definition.rendered}"
  required_cpu          = "${local.pwm_config["cpu"]}"
  required_memory       = "${local.pwm_config["memory"]}"
  min_capacity          = "${local.pwm_config["ecs_scaling_min_capacity"]}"
  max_capacity          = "${local.pwm_config["ecs_scaling_min_capacity"]}"
  target_cpu_usage      = "${local.pwm_config["ecs_target_cpu"]}"
  vpc_id                = "${data.terraform_remote_state.vpc.vpc_id}"
  lb_stickiness_enabled = true

  ecs_cluster = {
    name         = "${data.terraform_remote_state.ecs_cluster.shared_ecs_cluster_name}"
    cluster_id   = "${data.terraform_remote_state.ecs_cluster.shared_ecs_cluster_id}"
    namespace_id = "${data.terraform_remote_state.ecs_cluster.private_cluster_namespace["id"]}"
  }

  subnets = [
    "${data.terraform_remote_state.vpc.vpc_private-subnet-az1}",
    "${data.terraform_remote_state.vpc.vpc_private-subnet-az2}",
    "${data.terraform_remote_state.vpc.vpc_private-subnet-az3}",
  ]

  security_groups = [
    "${data.terraform_remote_state.vpc_security_groups.sg_ssh_bastion_in_id}",
    "${data.terraform_remote_state.vpc_security_groups.sg_smtp_ses}",
    "${data.terraform_remote_state.delius_core_security_groups.sg_pwm_instances_id}",
    "${data.terraform_remote_state.delius_core_security_groups.sg_common_out_id}",
  ]

  required_ssm_parameters = [
    "arn:aws:ssm:${var.region}:${data.aws_caller_identity.current.account_id}:parameter/${var.environment_name}/${var.project_name}/pwm/pwm/security_key",
    "arn:aws:ssm:${var.region}:${data.aws_caller_identity.current.account_id}:parameter/${var.environment_name}/${var.project_name}/pwm/pwm/config_password",
    "arn:aws:ssm:${var.region}:${data.aws_caller_identity.current.account_id}:parameter/${var.environment_name}/${var.project_name}/apacheds/apacheds/ldap_admin_password",
  ]
}
