# AWS VPC Peering Project

**Student:** Aman Kumar  
**Course:** AWS Architect Associate  
**Region:** `ap-south-1`  
**Project date:** 30 October 2026

## What I built

The lab uses two VPCs with different address ranges. App-A and App-B stay on private IPs. I use a bastion in VPC A to SSH to the two application instances. Peering carries traffic between the VPCs.

## Address plan

| Resource | Address |
|---|---|
| VPC A | `10.10.0.0/16` |
| `ewb-a-public` | `10.10.1.0/24` |
| `ewb-a-private` | `10.10.2.0/24` |
| VPC B | `10.20.0.0/16` |
| `ewb-b-private` | `10.20.1.0/24` |
| Bastion | `10.10.1.10`, public IPv4 assigned by AWS |
| App-A | `10.10.2.10`, no public IPv4 |
| App-B | `10.20.1.10`, no public IPv4 |

## Routes and access

The public subnet in VPC A uses the internet gateway for the bastion. Its route table also sends `10.20.0.0/16` to the peering connection. The private subnet in VPC A sends that same range to peering. VPC B has a return route for `10.10.0.0/16`.

SSH to the bastion is limited to my current public IPv4 `/32`. Both app instances allow SSH from the bastion's private IP (`10.10.1.10/32`). Their ICMP Echo Request rules allow only the other app's private IP. VPC B has no internet gateway.

## Results and evidence

I have not run this setup in AWS yet. The table is left pending until I can record my own results. Resource IDs and terminal captures should be added after deployment; I have not filled these with example values.

| Check | Expected observation | Result |
|---|---|---|
| Before peering | App-A ping to App-B gets no replies | Pending |
| After peering | Ping works in both directions | Pending |
| SSH | App-B opens through the bastion | Pending |
| Public IP check | App-A and App-B have no public IPv4 | Pending |
| ICMP failure | Ping stops when App-B's ICMP rule is removed; SSH still works | Pending |
| Recovery | Ping works again after the ICMP rule is restored | Pending |

## Resource IDs

Add the IDs and bastion public IP printed by Terraform after the AWS deployment.

| Resource | ID or value |
|---|---|
| VPC A | Pending |
| VPC B | Pending |
| Peering connection | Pending |
| Bastion and public IPv4 | Pending |
| App-A | Pending |
| App-B | Pending |

## Cleanup

After saving the evidence, run `terraform destroy` from the Terraform directory. Then check the AWS console for leftover lab volumes or public IPv4 allocations.

