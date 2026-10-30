# AWS VPC Peering & Private Workload Connectivity

This repository contains the architecture, Infrastructure-as-Code (Terraform), automation scripts, and test verification logs for establishing secure, private connectivity between two separate AWS Virtual Private Clouds (VPCs) using **AWS VPC Peering**.

Based on the **EWB Cloud Labs - AWS Architect Associate Project 01** curriculum.

---

## Architecture Overview

```text
               +-------------------------------------------+
               |        Admin Laptop (Local Shell)         |
               |          OpenSSH + ProxyJump              |
               +---------------------+---------------------+
                                     |
                                     | SSH (TCP 22)
                                     v
+-----------------------------------------------------------------------------------------+
| AWS Region: ap-south-1 (Mumbai)                                                         |
|                                                                                         |
|   +-------------------------------------------------------------------+                 |
|   | VPC A (10.10.0.0/16) - ewb-vpc-a                                  |                 |
|   |   Internet Gateway: ewb-igw-a                                     |                 |
|   |                                                                   |                 |
|   |   Public Subnet A (10.10.1.0/24)                                  |                 |
|   |     -> ewb-bastion (Private: 10.10.1.10 | Public IPv4)            |                 |
|   |                                                                   |                 |
|   |   Private Subnet A (10.10.2.0/24)                                 |                 |
|   |     -> ewb-app-a (Private: 10.10.2.10 | No Public IP)             |                 |
|   +---------------------------------+---------------------------------+                 |
|                                     |                                                   |
|                                     |  VPC Peering: ewb-a-b-peer                        |
|                                     |  (created during deployment)                      |
|                                     |                                                   |
|   +---------------------------------+---------------------------------+                 |
|   | VPC B (10.20.0.0/16) - ewb-vpc-b                                  |                 |
|   |   (Isolated Workload VPC - No Internet Gateway)                   |                 |
|   |                                                                   |                 |
|   |   Private Subnet B (10.20.1.0/24)                                 |                 |
|   |     -> ewb-app-b (Private: 10.20.1.10 | No Public IP)             |                 |
|   +-------------------------------------------------------------------+                 |
+-----------------------------------------------------------------------------------------+
```

### Key Highlights
1. **Isolated Application Workloads:** `App-A` (`10.10.2.10`) and `App-B` (`10.20.1.10`) live strictly in private subnets with no public IPv4 addresses and no direct internet access.
2. **Private Peering Transit:** Inter-application communication travels privately across the AWS internal network using VPC peering (`ewb-a-b-peer`).
3. **Zero-Key-Leak Administration:** Server administration is performed via OpenSSH `ProxyJump` using `ewb-bastion` as the transit hop. The private SSH key (`ewb-lab.pem`) stays safely on the local workstation and is never uploaded to any cloud server.
4. **Least-Privilege Security:** Inbound firewall rules are scoped to `/32` host IPs.

---

## IP Addressing & Resource Plan

| Resource Name | Type | CIDR / IPv4 | Route Table / Rules |
|---|---|---|---|
| `ewb-vpc-a` | VPC | `10.10.0.0/16` | DNS hostnames & support enabled |
| `ewb-a-public` | Subnet (VPC A) | `10.10.1.0/24` | Default route (`0.0.0.0/0`) via `ewb-igw-a` |
| `ewb-a-private` | Subnet (VPC A) | `10.10.2.0/24` | Peer route (`10.20.0.0/16`) via `pcx-ID` |
| `ewb-vpc-b` | VPC | `10.20.0.0/16` | Strictly private (No IGW) |
| `ewb-b-private` | Subnet (VPC B) | `10.20.1.0/24` | Return peer route (`10.10.0.0/16`) via `pcx-ID` |
| `ewb-bastion` | EC2 (t3.micro) | `10.10.1.10` + Public IP | Inbound TCP 22 from admin workstation IP |
| `ewb-app-a` | EC2 (t3.micro) | `10.10.2.10` (No Public IP)| Inbound TCP 22 from Bastion; ICMP from App-B |
| `ewb-app-b` | EC2 (t3.micro) | `10.20.1.10` (No Public IP)| Inbound TCP 22 from Bastion; ICMP from App-A |
| `ewb-a-b-peer` | Peering Connection | Active | Bi-directional private routing |

---

## Repository Structure

```text
├── README.md                           # Project documentation & runbook
├── .gitignore                          # Excludes keys, tfstate, and secrets
├── terraform/                          # Infrastructure-as-Code
│   ├── main.tf                         # VPCs, subnets, peering, SGs, EC2 instances
│   ├── variables.tf                    # Region, AZ, CIDRs, IP definitions
│   ├── outputs.tf                      # Resource IDs, public IP, SSH config snippet
│   ├── providers.tf                    # AWS provider with default tagging
│   └── terraform.tfvars.example        # Example variable values
├── scripts/                            # Automation & Testing scripts
│   ├── deploy-aws-cli.sh               # Complete AWS CLI deployment script
│   ├── cleanup-aws-cli.sh              # Safe resource teardown script
│   ├── test-connectivity.sh            # Automated verification test suite
│   └── controlled-failure-test.sh      # Security group failure/recovery experiment
├── ssh/
│   └── config.example                  # OpenSSH ProxyJump configuration template
├── test-evidence/                      # Captures from the actual AWS run
│   └── README.md                       # Evidence capture checklist
└── docs/
    ├── Aman_Kumar_EWB_VPC_Peering_Report.md   # Complete project submission report
    └── viva-questions-and-answers.md          # In-depth architectural viva defense
```

---

## Deployment Guide

### Option 1: Deploy with Terraform (Recommended)

1. **Clone the repository:**
   ```bash
   git clone <your GitHub repository URL>
   cd aws-vpc-peering-lab/terraform
   ```

2. **Configure variables:**
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   # Set admin_source_ip to your public IPv4 /32 and key_name to your EC2 key pair.
   ```

3. **Create the network and instances before peering:**
   ```bash
   terraform init
   terraform apply -var="enable_peering=false"
   ```

4. **Capture the baseline:** use `terraform output bastion_public_ip` to configure the SSH hosts, then run `ssh ewb-app-a "ping -c 4 10.20.1.10"`. Save the failed ping output before continuing.

5. **Create peering and routes:**
   ```bash
   terraform apply -var="enable_peering=true"
   ```

6. **Capture outputs:**
   Terraform will display all instance IDs, private IPs, Bastion public IP, and an automatically formatted SSH config snippet.

---

### Option 2: Deploy with AWS CLI Script

If deploying via bash scripts:
```bash
chmod +x scripts/*.sh
./scripts/deploy-aws-cli.sh
```

---

## SSH Setup & Accessing Instances

Configure your local `~/.ssh/config` using the provided template (`ssh/config.example`):

```ssh-config
Host ewb-bastion
    HostName <BASTION_PUBLIC_IP>
    User ec2-user
    IdentityFile ~/.ssh/ewb-lab.pem
    IdentitiesOnly yes

Host ewb-app-a
    HostName 10.10.2.10
    User ec2-user
    IdentityFile ~/.ssh/ewb-lab.pem
    IdentitiesOnly yes
    ProxyJump ewb-bastion

Host ewb-app-b
    HostName 10.20.1.10
    User ec2-user
    IdentityFile ~/.ssh/ewb-lab.pem
    IdentitiesOnly yes
    ProxyJump ewb-bastion
```

Set permissions on your private key:
```bash
chmod 400 ~/.ssh/ewb-lab.pem
```

Test access directly from your laptop:
```bash
# Connect to Bastion
ssh ewb-bastion

# Connect directly to App-A
ssh ewb-app-a

# Connect directly to App-B (traversing Bastion transparently)
ssh ewb-app-b
```

---

## Verification & Acceptance Criteria

Run the test suite or verify manually according to the criteria below:

| # | Test | Command | Expected Result |
|---|---|---|---|
| **01** | Baseline | `ssh ewb-app-a "ping -c 4 10.20.1.10"` (Pre-peering) | 100% packet loss |
| **02** | Forward Path | `ssh ewb-app-a "ping -c 4 10.20.1.10"` (Post-peering) | 4 replies, 0% packet loss |
| **03** | Reverse Path | `ssh ewb-app-b "ping -c 4 10.10.2.10"` | 4 replies, 0% packet loss |
| **04** | Private SSH | `ssh ewb-app-b` from local laptop | Interactive shell on `10.20.1.10` |
| **05** | Controlled Failure | Revoke App-B ICMP rule, repeat ping | Ping fails, SSH remains active |
| **06** | Recovery | Re-add ICMP rule, repeat ping | Ping succeeds immediately |
| **07** | Isolation Check | `aws ec2 describe-instances` | No public IP on App-A or App-B |

Save your own command output in [`test-evidence/`](test-evidence/). No AWS execution evidence is included in this checkout yet.

---

## Viva & Defense Summary

* **Why is a return route needed?**  
  Routing in AWS VPCs is stateless and hop-by-hop. Outbound packets reach VPC B through VPC A's route table (`10.20.0.0/16 -> pcx-ID`). For App-B's reply to reach App-A, VPC B's route table must explicitly route `10.10.0.0/16` back to `pcx-ID`. Otherwise, reply packets are dropped locally.

* **Why is the App-B SSH source the bastion private IP?**  
  With `ProxyJump`, the local SSH client connects to Bastion, which then originates a new TCP connection to App-B (`10.20.1.10:22`). Because the socket originates on Bastion, the source IP in the packet is `10.10.1.10`.

* **Why does Active peering not guarantee ping success?**  
  Peering status only reflects the logical link between VPCs. Successful communication still requires explicit route table entries, matching security group rules (ICMP Echo Request), and permitted NACLs.

* **Can VPC B access the internet via VPC A's Internet Gateway over peering?**  
  No. AWS VPC Peering does not support transitive routing (edge-to-edge routing). To give VPC B egress, use an AWS Transit Gateway or deploy a forward proxy in VPC A.

Read the full technical analysis in [`docs/viva-questions-and-answers.md`](docs/viva-questions-and-answers.md).

---

## Teardown & Clean Up

To prevent ongoing AWS charges, clean up resources in reverse-dependency order:

```bash
# If deployed with Terraform:
cd terraform
terraform destroy -auto-approve

# If deployed with AWS CLI:
./scripts/cleanup-aws-cli.sh
```

---

## Author

* **Student:** Aman Kumar
* **GitHub:** [@0-Aman](https://github.com/0-Aman)
* **Program:** AWS Architect Associate (October 2026)

