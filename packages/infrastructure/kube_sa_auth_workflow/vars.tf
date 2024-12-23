variable "service_account" {
  description = "The name of the service account that should be able to assume the AWS permissions."
  type        = string
}

variable "service_account_namespace" {
  description = "The namespace of the service account."
  type        = string
}

variable "ip_allow_list" {
  description = "A list of IPs that can use the service account token to authenticate with AWS API"
  type        = list(string)
  default     = []
}

variable "annotate_service_account" {
  description = "Whether or not to annotate the service account with the AWS role ARN"
  type        = bool
  default     = true
}

variable "extra_aws_permissions" {
  description = "Extra JSON-encoded AWS permissions to assign to the workflow"
  type        = string
  default     = "{}"
}
