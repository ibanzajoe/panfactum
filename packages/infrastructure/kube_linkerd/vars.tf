variable "linkerd_helm_version" {
  description = "The version of the linkerd-crd and linkerd-control-plane helm charts to deploy (edge)"
  type        = string
  default     = "2024.5.1"
}

variable "vault_ca_crt" {
  description = "The vault certificate authority public certificate."
  type        = string
}

variable "vpa_enabled" {
  description = "Whether the VPA resources should be enabled"
  type        = bool
  default     = false
}

variable "pull_through_cache_enabled" {
  description = "Whether to use the ECR pull through cache for the deployed images"
  type        = bool
  default     = false
}

variable "log_level" {
  description = "The log level for the Linkerd pods"
  type        = string
  default     = "warn"
  validation {
    condition     = contains(["info", "error", "trace", "warn", "debug"], var.log_level)
    error_message = "Invalid log_level provided."
  }
}

