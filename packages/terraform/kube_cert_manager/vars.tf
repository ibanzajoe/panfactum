variable "cert_manager_version" {
  description = "The version of cert-manager to deploy"
  type        = string
  default     = "1.14.4"
}

variable "vpa_enabled" {
  description = "Whether the VPA resources should be enabled"
  type        = bool
  default     = false
}

variable "log_verbosity" {
  description = "The log verbosity (0-9) for the cert-manager pods"
  type        = number
  default     = 0
}

variable "self_generated_certs_enabled" {
  description = "Whether to enable self-generated webhook certs (only use on initial installation)"
  type        = bool
  default     = true
}
