# AWS VPC Peering: Technical Viva & Architecture Defense

**Student Name:** Aman Kumar  
**Batch:** AWS Architect Associate (October 2026)  
**Project:** EWB-VPC-Peering  
**Region:** Asia Pacific (Mumbai) / `ap-south-1`

---

## 1. Why is the return route needed?

### Technical Answer:
In IP networking and AWS Virtual Private Clouds, **routing is stateless and hop-by-hop**. Even though AWS VPC Peering creates a private bidirectional network conduit between two VPCs at the SDN (Software Defined Networking) layer, each VPC relies exclusively on its own custom **Route Table** to determine where outbound packets must be dispatched.

When `App-A` (`10.10.2.10`) transmits an ICMP Echo Request or TCP packet to `App-B` (`10.20.1.10`):
1. `App-A` consults `ewb-rt-a-private`. It matches the route `10.20.0.0/16 -> pcx-ID` and successfully forwards the frame across the peering link.
2. `App-B` receives the packet and generates an ICMP Echo Reply (or TCP SYN-ACK). The destination IP of this reply is `10.10.2.10`.
3. To forward this reply, `App-B` consults its own associated subnet route table: `ewb-rt-b-private`.
4. If `ewb-rt-b-private` lacks an explicit route for `10.10.0.0/16 -> pcx-ID`, the router has no destination target for `10.10.2.10`. It either matches nothing or falls back to a default route (which does not exist in VPC B). The packet is discarded immediately inside VPC B.

Therefore, establishing VPC peering without symmetric return routes creates a **black hole** for reply traffic. A working communication channel strictly requires both forward and return route entries.

---

## 2. Why is the App-B SSH source the bastion private IP?

### Technical Answer:
When connecting to `App-B` from a local workstation via OpenSSH using `ProxyJump`:
```text
Host ewb-app-b
    HostName 10.20.1.10
    ProxyJump ewb-bastion
```

The SSH connection operates in two distinct stages:
1. **Stage 1 (Client to Bastion):** The local workstation establishes an encrypted SSH session to the Bastion host over the public internet targeting `ewb-bastion`'s public IP on port 22.
2. **Stage 2 (Bastion to Target):** Through the established channel, the client instructs the SSH daemon / client on the Bastion to open a new TCP socket directly to `10.20.1.10:22`.

Because the Bastion host is the machine that opens the outbound TCP socket to `App-B`, the operating system kernel on the Bastion assigns its own local interface IP address (`10.10.1.10`) as the **source IP** of the TCP SYN packet. 

Consequently:
* `App-B`’s network stack sees incoming TCP packets arriving from `10.10.1.10` (the Bastion’s private IP), **not** the developer’s home public IP.
* Therefore, the security group on `App-B` (`ewb-sg-app-b`) must authorize inbound port 22 traffic specifically from `10.10.1.10/32` (or the bastion SG). Putting the client's home IP in `ewb-sg-app-b` would fail because that IP never appears on VPC B's interface.

---

## 3. Why does Active peering not guarantee a successful ping?

### Technical Answer:
An **Active** VPC Peering connection status in the AWS Management Console (`status: active`) simply verifies that:
1. The peering request was created and formally accepted by both VPC owners.
2. The AWS SDN fabric has registered the logical relationship between the two VPC IDs.

However, an Active peering connection does **not** automate or validate the following necessary layers of the OSI stack:
1. **Layer 3 Routing (VPC Route Tables):** By design, AWS does not automatically inject routes into either VPC’s route tables when peering is accepted. Both requester and accepter route tables must be manually updated with destination CIDRs pointing to the `pcx-ID`.
2. **Layer 4 Filtering (Security Groups):** Even if routes exist, AWS Security Groups act as instance-level stateful firewalls. If the destination instance's security group does not explicitly permit inbound ICMP Echo Request (`type 8, code 0`) from the source IP or CIDR, the hypervisor silently drops the packet.
3. **Subnet Network ACLs (NACLs):** If custom NACLs are in place, they must permit both outbound and inbound traffic on both subnets.
4. **Target Instance OS & Firewall:** The destination host must be booted, healthy, and its local OS firewall (`iptables` / `nftables` / Windows Firewall) must not reject ICMP packets.

Hence, an "Active" peering connection is merely the physical highway; the route tables and security groups are the on-ramps and toll booths that actually allow traffic through.

---

## 4. Can VPC B use VPC A's internet gateway over peering?

### Technical Answer:
**No.** AWS VPC Peering has a strict architectural restriction: **Edge to Edge Routing (Transitive Routing) is not supported**.

In this architecture:
* VPC A has an Internet Gateway (`ewb-igw-a`).
* VPC B is peered with VPC A (`ewb-a-b-peer`).
* VPC B has no Internet Gateway of its own.

Traffic originating from an instance in VPC B cannot hop across the VPC peering connection into VPC A and then exit out of VPC A's Internet Gateway to reach the public internet. Similarly, internet traffic entering `ewb-igw-a` cannot traverse peering into VPC B.

AWS explicitly prohibits:
* Transit through a peered VPC to reach an Internet Gateway, NAT Gateway, Virtual Private Gateway (VPN), or AWS Direct Connect connection.

### How to achieve internet access for VPC B if needed in production?
If VPC B requires internet access without provisioning its own Internet Gateway, the supported enterprise architecture patterns are:
1. **AWS Transit Gateway (TGW):** Deploy an AWS Transit Gateway hub with centralized egress through a dedicated egress VPC containing NAT Gateways and IGW.
2. **Proxy Appliance / Forward Proxy:** Deploy an HTTP/HTTPS forward proxy (e.g., Squid, Envoy, or HAProxy) on an EC2 instance in VPC A. VPC B instances can send web requests to the proxy's private IP (`10.10.x.x`), which then fetches web resources via VPC A's NAT/IGW.

---

## 5. Summary of Core Architectural Principles

| Concept | Explanation |
|---|---|
| **Non-transitive Peering** | If VPC A is peered with VPC B, and VPC A is peered with VPC C, VPC B cannot communicate with VPC C through VPC A. Direct peering between B and C is required. |
| **CIDR Non-overlap** | VPC Peering requires non-overlapping IPv4 CIDRs. `10.10.0.0/16` and `10.20.0.0/16` are fully disjoint. Subnet divisions (`/24`) cannot resolve an overlapping `/16` parent VPC CIDR. |
| **Security Group Statefulness** | Inbound allowed traffic automatically permits corresponding outbound return packets, regardless of outbound security group rules. |
| **Principle of Least Privilege** | Inbound rules in this project are strictly scoped to single `/32` host IPs rather than open `/16` VPC ranges or public `0.0.0.0/0`. |
