variable "primary_region" {
  description = "Primary AWS region"
  type        = string
  default     = "af-south-1"
}

variable "secondary_region" {
  description = "Secondary AWS region for disaster recovery"
  type        = string
  default     = "me-south-1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
}

variable "db_username" {
  description = "Database master username"
  type        = string
  default     = "omnibus_admin"
}

variable "db_password" {
  description = "Database master password"
  type        = string
  sensitive   = true
}

variable "domain_name" {
  description = "Primary domain name"
  type        = string
  default     = "omnibus.ea"
}
