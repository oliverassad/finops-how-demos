variable "cluster_name" {
  description = "Name of the kind cluster."
  type        = string
  default     = "finops-lab"
}

variable "kubernetes_version" {
  description = "Tag of the kindest/node image."
  type        = string
  default     = "v1.37.0"
}

variable "prometheus_chart_version" {
  description = "Version of the prometheus-community/prometheus chart."
  type        = string
  default     = "30.0.0"
}

variable "opencost_chart_version" {
  description = "Version of the opencost/opencost chart."
  type        = string
  default     = "2.5.34"
}
