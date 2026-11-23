# Lab: allocate Kubernetes costs with OpenCost

This lab goes with the guide **FinOps for Containerized Environments: How to Allocate Their Costs** on [finops.how](https://finops.how).

You run a Kubernetes cluster on your laptop, install OpenCost, run four team workloads, and read the cost of each team. One `terraform apply` builds everything. The lab needs no cloud account and costs nothing.

## What you build

```text
laptop (Docker)
└── kind cluster "finops-lab" (1 node, 8 vCPU)
    ├── prometheus-system   Prometheus: stores usage metrics
    ├── opencost            OpenCost: turns requests, usage and prices into cost
    └── checkout, search, data, platform   four team workloads
```

## The tools and why you need them

| Tool | What it is | Why this lab uses it |
| :-- | :-- | :-- |
| Docker | Runs containers on your laptop. | kind runs the Kubernetes node as a Docker container. |
| Terraform | Creates infrastructure from code files (`*.tf`). | One `terraform apply` creates the cluster and installs every chart. One `terraform destroy` removes it. |
| kind | Kubernetes in Docker: a full cluster inside one container. | A real cluster on a laptop, at no cost. Terraform drives it through the `tehcyx/kind` provider. |
| Helm | The package manager of Kubernetes. A chart is a package. | Prometheus, OpenCost and the four teams install as charts. Terraform drives Helm through the `hashicorp/helm` provider, so you do not install the Helm CLI. |
| Prometheus | A time-series database for metrics. | It records the CPU and memory that each container uses. OpenCost reads usage from it. |
| OpenCost | An open source (CNCF) tool that computes Kubernetes cost. | It combines requests, usage and prices into cost per namespace, pod and label. |
| kubectl | The command line of Kubernetes. | You check the pods and open a tunnel to OpenCost. |
| jq, curl | A JSON filter and an HTTP client. | `scripts/costs.sh` calls the OpenCost API and prints tables. |

## Step 1: Install the prerequisites

Install Docker Desktop and give it **8 CPUs** (Settings, then Resources). The node gets the CPUs of Docker, and the numbers in this lab assume 8.

```bash
# macOS (Homebrew)
brew install terraform kubectl jq

# Windows (Chocolatey)
choco install terraform kubernetes-cli jq
```

On Linux, install Terraform, kubectl and jq from their official docs or your package manager. You do not need the kind or Helm command lines: the Terraform providers include them.

Check the tools:

```bash
docker info --format '{{.NCPU}} CPUs'
terraform version
kubectl version --client
jq --version
```

You should see `8 CPUs` and one version line for each tool.

## Step 2: Get the code

```bash
git clone https://github.com/oliverassad/finops-how-demos.git
cd finops-how-demos/container-cost-allocation/terraform
```

| File | What it does |
| :-- | :-- |
| `terraform/main.tf` | The cluster, Prometheus, OpenCost and the teams chart. |
| `terraform/values-opencost.yaml` | Points OpenCost at Prometheus and sets the lab price. |
| `terraform/values-prometheus.yaml` | Tells Prometheus to scrape OpenCost. |
| `charts/teams/templates/teams.yaml` | Four namespaces and four Deployments with labels and CPU requests. |
| `scripts/costs.sh` | Calls the OpenCost API and prints three cost tables. |

## Step 3: Build the lab

```bash
terraform init
terraform apply
```

Type `yes` when Terraform asks. The apply takes about 2 minutes. `terraform init` downloads the providers. `terraform apply` then:

1. Creates the kind cluster `finops-lab`.
2. Installs Prometheus in `prometheus-system`.
3. Installs OpenCost in `opencost`.
4. Installs the four teams.

You should see this at the end:

```text
Apply complete! Resources: 4 added, 0 changed, 0 destroyed.
```

Point kubectl at the new cluster and check the pods:

```bash
export KUBECONFIG="$(terraform output -raw kubeconfig_path)"
kubectl get pods -A -L team
```

You should see every pod `Running`. The four team pods show their `TEAM` value. System pods have an empty `TEAM` column.

### The lab price

kind has no cloud price list. So `values-opencost.yaml` sets a custom price: 0.136986 USD per vCPU-hour, which is **$100 per vCPU per month** (730 hours). Without it, OpenCost prices the node at $0 and idle cost stays at $0.

### The four teams

Each team requests CPU and uses about half of it. A `busybox` loop is busy for some seconds, then sleeps.

| Team | CPU request | Busy, then sleep | Average use |
| :-- | --: | :-- | --: |
| checkout | 1800m | 9s, 1s | 0.9 vCPU |
| search | 1400m | 7s, 3s | 0.7 vCPU |
| data | 1000m | 5s, 5s | 0.5 vCPU |
| platform | 600m | 5s, 5s | 0.3 vCPU |

The unit `m` is a thousandth of a vCPU, so 1800m is 1.8 vCPU.

## Step 4: Wait 15 minutes

OpenCost needs data before it shows costs. Cost appears after 1 to 2 minutes. Wait 15 minutes, so the numbers settle.

## Step 5: Open the OpenCost UI

Open a tunnel from your laptop to OpenCost. Keep this command running in its own terminal.

```bash
kubectl port-forward -n opencost service/opencost 9003 9090
```

Open <http://localhost:9090>. Click "Skip tutorial". You should see the cost per namespace. `checkout` is the highest of the four teams and `platform` is the lowest. The UI shows the last 7 days, so it includes the first minutes, before the data settled. The API in step 6 gives the clean numbers.

## Step 6: Read the costs from the API

In a new terminal, from `container-cost-allocation/`:

```bash
./scripts/costs.sh
```

The script asks the OpenCost allocation API for the last 15 minutes. It projects each cost to a month: cost, divided by the minutes of data, times 43,800 minutes. It prints three tables.

You should see three tables like these (from a run on 2026-11-23):

```text
== Cost per namespace (idle on its own line)
NAME                CPU_REQUEST  CPU_USED  USD_PER_MONTH
__idle__            0m           0m        241
checkout            1800m        900m      181
search              1400m        701m      141
data                1000m        500m      100
kube-system         950m         46m       97
platform            600m         303m      60
opencost            20m          1m        2
prometheus-system   0m           5m        2
local-path-storage  0m           0m        0
```

```text
== Cost per team label (idle on its own line)
NAME             CPU_REQUEST  CPU_USED  USD_PER_MONTH
__idle__         0m           0m        241
checkout         1800m        900m      181
search           1400m        701m      141
__unallocated__  970m         52m       101
data             1000m        500m      100
platform         600m         303m      60
```

```text
== Cost per team label (idle shared)
NAME             CPU_REQUEST  CPU_USED  USD_PER_MONTH
checkout         1800m        900m      253
search           1400m        701m      197
__unallocated__  970m         52m       149
data             1000m        500m      140
platform         600m         303m      85
```

## Step 7: Read the results

- **Each team pays for its request.** `checkout` requests 1800m and uses about 900m. It pays for 1.8 vCPU at $100, plus a little memory. A workload pays for the greater of request and usage.
- **`__idle__` is capacity that no pod requested.** The node has 8 vCPU, and the pods request about 5.8 vCPU. The rest is idle.
- **`__unallocated__` is cost with no `team` label.** These are the system pods: `kube-system`, OpenCost and Prometheus.
- **`shareIdle=true` spreads idle over the teams.** The `__idle__` line goes away, and each team total goes up. The sum stays the same.

## Step 8: Clean up

Stop the port-forward with Ctrl+C. Then remove everything:

```bash
terraform destroy
```

Type `yes`. You should see `Destroy complete!`. The kind cluster is gone.

## Versions used

| Tool | Version |
| :-- | :-- |
| Terraform | 1.17.1 |
| Provider `tehcyx/kind` | 0.13.0 |
| Provider `hashicorp/helm` | 3.3.0 |
| Kubernetes node (`kindest/node`) | v1.37.0 |
| Docker Engine | 29.9.3 |
| Prometheus chart | 30.0.0 (Prometheus v3.16.0) |
| OpenCost chart | 2.5.34 (OpenCost 1.121.4) |
| Workload image | `busybox:1.37.0` |

## Sources

- [OpenCost: install with Helm](https://opencost.io/docs/installation/helm/)
- [OpenCost: Prometheus](https://opencost.io/docs/installation/prometheus/)
- [OpenCost: on-prem pricing](https://opencost.io/docs/configuration/on-prem)
- [OpenCost: API](https://opencost.io/docs/integrations/api/)
