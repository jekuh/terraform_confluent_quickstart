variable "confluent_cloud_api_key" {
  description = "Confluent Cloud Admin API Key (also referred as Cloud API ID)"
  type        = string
}

variable "confluent_cloud_api_secret" {
  description = "Confluent Cloud Admin API Secret"
  type        = string
  sensitive   = true
}




