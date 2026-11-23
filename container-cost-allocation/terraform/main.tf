# A local Kubernetes cluster (kind runs it inside Docker), then Prometheus,
# OpenCost and four team workloads. No cloud account and no API keys.

resource "kind_cluster" "lab" {
  name           = var.cluster_name
  node_image     = "kindest/node:${var.kubernetes_version}"
  wait_for_ready = true
}

locals {
  cluster = {
    host                   = kind_cluster.lab.endpoint
    client_certificate     = kind_cluster.lab.client_certificate
    client_key             = kind_cluster.lab.client_key
    cluster_ca_certificate = kind_cluster.lab.cluster_ca_certificate
  }
}

provider "helm" {
  kubernetes = local.cluster
}


# Prometheus stores the usage metrics that OpenCost reads.
resource "helm_release" "prometheus" {
  name             = "prometheus"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "prometheus"
  version          = var.prometheus_chart_version
  namespace        = "prometheus-system"
  create_namespace = true
  values           = [file("${path.module}/values-prometheus.yaml")]
  set = [
    { name = "prometheus-pushgateway.enabled", value = "false" },
    { name = "alertmanager.enabled", value = "false" },
  ]
}

# OpenCost turns requests, usage and prices into cost per namespace and label.
resource "helm_release" "opencost" {
  name             = "opencost"
  repository       = "https://opencost.github.io/opencost-helm-chart"
  chart            = "opencost"
  version          = var.opencost_chart_version
  namespace        = "opencost"
  create_namespace = true
  values           = [file("${path.module}/values-opencost.yaml")]
  timeout          = 600
  depends_on       = [helm_release.prometheus]
}

# The four team workloads: one namespace and one Deployment per team.
# A local chart, so Helm installs them in the same apply.
resource "helm_release" "teams" {
  name       = "teams"
  chart      = "${path.module}/../charts/teams"
  namespace  = "default"
  depends_on = [helm_release.opencost]
}
