# AWS VPC Peering Lab

This project connects two VPCs in `ap-south-1` using VPC peering. App-A and App-B use private IPs. A bastion in VPC A is used to reach them over SSH.

The Terraform files build the network and three EC2 instances. The scripts include an AWS CLI deployment, cleanup, connectivity checks and a small ICMP failure exercise.

## Network plan

| Resource | Address |
|---|---|
| VPC A (`ewb-vpc-a`) | `10.10.0.0/16` |
| Public subnet (`ewb-a-public`) | `10.10.1.0/24` |
| Private subnet (`ewb-a-private`) | `10.10.2.0/24` |
| VPC B (`ewb-vpc-b`) | `10.20.0.0/16` |
| Private subnet (`ewb-b-private`) | `10.20.1.0/24` |
| Bastion | `10.10.1.10` and a public IPv4 |
| App-A | `10.10.2.10`, no public IPv4 |
| App-B | `10.20.1.10`, no public IPv4 |

VPC B has no internet gateway. The peer routes are added to both private route tables. VPC A's public route table also needs a route to VPC B so the bastion can reach App-B.

## Deploy with Terraform

You need Terraform, AWS CLI credentials, an EC2 key pair in the selected Region and your current public IPv4 address. The bastion SSH rule accepts a single `/32`; the example IP below is reserved for documentation and will not work as your address.

```bash
git clone https://github.com/0-Aman/AWS-_VPC-_peering-_lab-_project.git
cd AWS-_VPC-_peering-_lab-_project/terraform
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`: set `admin_source_ip` to your public IPv4 `/32` and `key_name` to your EC2 key pair. The example starts with peering disabled so the baseline check can be done first.

```bash
terraform init
terraform apply -var="enable_peering=false"
```

Use `terraform output bastion_public_ip` to finish `ssh/config.example`. Connect to App-A and run the baseline ping before creating peering:

```bash
ssh ewb-app-a "ping -c 4 10.20.1.10"
```

It should get no replies at this stage. Save the terminal output. Then create the peering connection and routes:

```bash
terraform apply -var="enable_peering=true"
```

## Connect and check

Copy the host entries from `ssh/config.example` into `~/.ssh/config` and replace `BASTION_PUBLIC_IP`. Keep the `.pem` key on your computer. On Linux or WSL, set its permissions with `chmod 400 ~/.ssh/ewb-lab.pem`.

```bash
ssh ewb-bastion
ssh ewb-app-a
ssh ewb-app-b
```

With peering enabled, run the connectivity checks from the repository root:

```bash
bash scripts/test-connectivity.sh
```

The failure exercise briefly removes App-B's ICMP Echo Request rule, checks that ping stops while SSH remains available, restores the rule and checks ping again:

```bash
bash scripts/controlled-failure-test.sh
```

Capture your own output in `test-evidence/`, along with the real AWS resource IDs and screenshots of the route tables and security groups. There are no live AWS results in this repository yet; the report marks those checks as pending.

## Clean up

Save your evidence first, then run this from the `terraform` directory:

```bash
terraform destroy
```

Check the AWS console for leftover volumes or public IPv4 allocations after destroy finishes.

## Files

- `terraform/` contains the network, routes, security groups and EC2 resources.
- `scripts/` contains AWS CLI deployment, cleanup and verification scripts.
- `ssh/config.example` shows the SSH `ProxyJump` setup.
- `docs/` contains the report and short viva notes.
- `test-evidence/README.md` lists the evidence to capture during a real run.

