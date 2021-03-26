module "api" {
  source                   = "../../modules/ecs_service"
  region                   = var.region
  environment_name         = var.environment_name
  short_environment_name   = var.short_environment_name
  remote_state_bucket_name = var.remote_state_bucket_name
  tags                     = var.tags

  # Application Container
  service_name = local.api_name
  container_definitions = [{
    image      = "${local.app_config["api_image_url"]}:${local.app_config["api_version"]}"
    entryPoint = ["java", "-Duser.timezone=Europe/London", "-jar", "/app.jar"]
  }]
  environment = {
    SERVER_SERVLET_CONTEXT_PATH             = "/gdpr/api/"
    SPRING_DATASOURCE_JDBC-URL              = "jdbc:postgresql://${aws_db_instance.primary.endpoint}/${aws_db_instance.primary.name}"
    SPRING_DATASOURCE_USERNAME              = aws_db_instance.primary.username
    SPRING_DATASOURCE_DRIVER-CLASS-NAME     = "org.postgresql.Driver"
    SPRING_SECOND-DATASOURCE_JDBC-URL       = data.terraform_remote_state.database.outputs.jdbc_failover_url
    SPRING_SECOND-DATASOURCE_USERNAME       = "gdpr_pool"
    SPRING_SECOND-DATASOURCE_TYPE           = "oracle.jdbc.pool.OracleDataSource"
    SPRING_JPA_HIBERNATE_DDL-AUTO           = "update"
    SPRING_BATCH_JOB_ENABLED                = "false"
    SPRING_BATCH_INITIALIZE-SCHEMA          = "always"
    ALFRESCO_DMS-PROTOCOL                   = "https"
    ALFRESCO_DMS-HOST                       = "alfresco.${data.terraform_remote_state.vpc.outputs.public_zone_name}"
    SCHEDULE_IDENTIFYDUPLICATES             = local.app_config["cron_identifyduplicates"]
    SCHEDULE_RETAINEDOFFENDERS              = local.app_config["cron_retainedoffenders"]
    SCHEDULE_RETAINEDOFFENDERSIICSA         = local.app_config["cron_retainedoffendersiicsa"]
    SCHEDULE_ELIGIBLEFORDELETION            = local.app_config["cron_eligiblefordeletion"]
    SCHEDULE_DELETEOFFENDERS                = local.app_config["cron_deleteoffenders"]
    SCHEDULE_DESTRUCTIONLOGCLEARING         = local.app_config["cron_destructionlogclearing"]
    SECURITY_OAUTH2_RESOURCE_ID             = "NDelius"
    SECURITY_OAUTH2_CLIENT_CLIENT-ID        = "GDPR-API"
    SECURITY_OAUTH2_RESOURCE_TOKEN-INFO-URI = "http://user-management.ecs.cluster:8080/umt/oauth/check_token"
    LOGGING_LEVEL_UK_GOV_JUSTICE            = local.app_config["log_level"]
  }
  secrets = {
    SPRING_DATASOURCE_PASSWORD           = "/${var.environment_name}/${var.project_name}/delius-gdpr-database/db/admin_password"
    SPRING_SECOND-DATASOURCE_PASSWORD    = "/${var.environment_name}/${var.project_name}/delius-database/db/gdpr_pool_password"
    SECURITY_OAUTH2_CLIENT_CLIENT-SECRET = "/${var.environment_name}/${var.project_name}/gdpr/api/client_secret"
  }

  # Security & Networking
  lb_listener_arn   = data.terraform_remote_state.ndelius.outputs.lb_listener_arn # Attach to NDelius load balancer
  lb_path_patterns  = ["/gdpr/api", "/gdpr/api/*"]
  health_check_path = "/gdpr/api/actuator/health"
  security_groups = [
    data.terraform_remote_state.delius_core_security_groups.outputs.sg_common_out_id,
    data.terraform_remote_state.delius_core_security_groups.outputs.sg_gdpr_api_id,
    data.terraform_remote_state.delius_core_security_groups.outputs.sg_umt_auth_id,
  ]

  # Monitoring
  enable_telemetry = true

  # Scaling
  cpu          = lookup(local.app_config, "api_cpu", var.common_ecs_scaling_config["cpu"])
  memory       = lookup(local.app_config, "api_memory", var.common_ecs_scaling_config["memory"])
  min_capacity = 1
  max_capacity = 1 # Fix to a single instance, as currently the batch processes cannot be scaled horizontally
}

