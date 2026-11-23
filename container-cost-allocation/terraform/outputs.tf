output "kubeconfig_path" {
  description = "Kubeconfig file for kubectl."
  value       = kind_cluster.lab.kubeconfig_path
}

output "next_steps" {
  description = "What to run after apply."
  value       = <<-EOT
    export KUBECONFIG=${kind_cluster.lab.kubeconfig_path}
    kubectl port-forward -n opencost service/opencost 9003 9090
    Open http://localhost:9090, then run ../scripts/costs.sh in a new terminal.
  EOT
}
