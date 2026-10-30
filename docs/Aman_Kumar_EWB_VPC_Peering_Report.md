# AWS VPC Peering Project Report

## Project details

| Field | Value |
|---|---|
| Student | Aman Kumar |
| Course | AWS Architect Associate |
| Project | AWS VPC Peering and Private Connectivity |
| Region | `ap-south-1` |
| Completion date | 30 October 2026 |

## Objective

Connect two non-overlapping VPCs using VPC peering. Keep both application instances on private IPv4 addresses and administer them through a bastion in VPC A.

## Architecture and address plan

```text
Laptop --SSH--> Bastion 10.10.1.10 (public subnet, VPC A)
                    |\
                    | +--SSH ProxyJump--> App-B 10.20.1.10 (VPC B private subnet)
                    +----SSH ProxyJump--> App-A 10.10.2.10 (VPC A private subnet)

App-A 10.10.2.10 <---- VPC peering ----> App-B 10.20.1.10
```

| Resource | CIDR or address | Public IPv4 |
|---|---|---|
| VPC A, `ewb-vpc-a` | `10.10.0.0/16` | N/A |
| Public subnet, `ewb-a-public` | `10.10.1.0/24` | N/A |
| Private subnet, `ewb-a-private` | `10.10.2.0/24` | N/A |
| VPC B, `ewb-vpc-b` | `10.20.0.0/16` | N/A |
| Private subnet, `ewb-b-private` | `10.20.1.0/24` | N/A |
| Bastion, `ewb-bastion` | `10.10.1.10` | Record after deployment |
| App-A, `ewb-app-a` | `10.10.2.10` | None |
| App-B, `ewb-app-b` | `10.20.1.10` | None |

## Route tables

| Route table | Associated subnet | Required routes |
|---|---|---|
| `ewb-rt-a-public` | `ewb-a-public` | Local VPC A; `0.0.0.0/0` to `ewb-igw-a`; `10.20.0.0/16` to peering |
| `ewb-rt-a-private` | `ewb-a-private` | Local VPC A; `10.20.0.0/16` to peering |
| `ewb-rt-b-private` | `ewb-b-private` | Local VPC B; `10.10.0.0/16` to peering |

The VPC B return route is required for replies to App-A and for SSH connections relayed by the bastion. The public route table needs the VPC B route because the bastion starts its own connection to App-B over its private address.

## Security rules

| Security group | Inbound rule | Source |
|---|---|---|
| `ewb-sg-bastion` | TCP 22 | Administrator public IPv4 `/32` |
| `ewb-sg-app-a` | TCP 22 | `10.10.1.10/32` |
| `ewb-sg-app-a` | ICMP Echo Request | `10.20.1.10/32` |
| `ewb-sg-app-b` | TCP 22 | `10.10.1.10/32` |
| `ewb-sg-app-b` | ICMP Echo Request | `10.10.2.10/32` |

Default outbound security group rules are retained. VPC B has no internet gateway, and neither application instance receives a public IPv4 address.

## Deployment and verification

Infrastructure is defined in Terraform under `terraform/`. Follow the deployment and SSH steps in the repository README. Configure a real administrator IPv4 `/32` and an existing EC2 key pair before applying.

Execution evidence has not been captured in this checkout. After deployment, record the real resource IDs, bastion public IP, route table associations and security group rules. Run the baseline before creating peering, then run the post-peering checks and controlled ICMP failure/recovery scripts. Save unedited terminal output in `test-evidence/` and replace this section with the measured results. Do not submit expected results as completed evidence.

| Check | Required observation | Result |
|---|---|---|
| Baseline before peering | App-A cannot reach App-B | Not run in this checkout |
| Forward path | App-A ping to App-B succeeds | Not run in this checkout |
| Reverse path | App-B ping to App-A succeeds | Not run in this checkout |
| Private SSH | Laptop reaches App-B through bastion | Not run in this checkout |
| Isolation | App-A and App-B have no public IPv4 | Not run in this checkout |
| Controlled failure | Removing App-B ICMP rule blocks ping while SSH remains available | Not run in this checkout |
| Recovery | Restoring ICMP rule restores ping | Not run in this checkout |

## Cleanup

Run `terraform destroy` from the Terraform directory after saving verified evidence. Confirm the project VPCs, instances, volumes, public IPv4 allocations and key pair are removed from the lab account.

## Resource inventory

Fill this inventory using the outputs from the actual deployment. No AWS resource IDs are available in this checkout.

| Resource | Actual AWS ID or value |
|---|---|
| VPC A | Pending deployment |
| VPC B | Pending deployment |
| Peering connection | Pending deployment |
| Bastion instance and public IPv4 | Pending deployment |
| App-A instance | Pending deployment |
| App-B instance | Pending deployment |
