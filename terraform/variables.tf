variable "db_connection_string" {
  type        = string
  description = "connect string"
}

variable "db_table" {
  type        = string
  description = "table name"
}

variable "run_from_package" {
  type        = string
  description = "URL for run from package"
}

variable "python_version" {
  type        = string
  description = "python version"
}

variable "sub_id" {
  type        = string
  description = "subscription id"
}

variable "key_vault_secret" {
  type        = string
  description = "name of key vault"
}

variable "function_app_host_name" {
  type        = string
  description = "host name of function app"
}

variable "cdn_raineycloud_hostname" {
  type        = string
  description = "host name for the RaineyCloud CDN endpoint"
}