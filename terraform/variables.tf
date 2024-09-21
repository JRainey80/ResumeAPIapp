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