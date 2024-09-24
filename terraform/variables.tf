variable "db_connection_string" {
  type        = string
  description = "connect string"
  default = "DefaultEndpointsProtocol=https;AccountName=resume-db-1;AccountKey=bs8omr9qxEBdx8INi2oqFankW0i9n0mNiHfUXavknpN0osxdqb15CKI37rxCdJpwxigIMMzy2oJoACDb0ZlCYg==;TableEndpoint=https://resume-db-1.table.cosmos.azure.com:443/;"
}

variable "db_table" {
  type        = string
  description = "table name"
  default = "VisitorCounts"
}

variable "run_from_package" {
  type        = string
  description = "URL for run from package"
  default     = "https://resumeapi9cbf.blob.core.windows.net/github-actions-deploy/Functionapp_202492404946986.zip?sv=2023-11-03&st=2024-09-24T00%3A44%3A47Z&se=2025-09-24T00%3A49%3A47Z&sr=b&sp=r&sig=qjn6vTgLzHgbq6BY11IT3TjXF5UrhWTzX0xsvQNovTo%3D"
}

variable "python_version" {
  type        = string
  description = "python version"
  default     = "3.10"
}