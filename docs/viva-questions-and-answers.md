# Viva Notes

These are short reminders for the project discussion. Put them in your own words when presenting.

## Why does VPC B need a return route?

The forward route gets a packet from App-A to App-B. App-B also needs a route back to `10.10.0.0/16`. Without it, replies cannot reach VPC A.

## Why does App-B allow SSH from `10.10.1.10/32`?

With `ProxyJump`, the laptop connects to the bastion first. The bastion then opens a separate connection to App-B, so App-B sees the bastion's private IP as the source.

## Why can ping fail when peering is active?

An active peering connection only means the link was accepted. The route tables still need routes on both sides, and the destination security group must allow ICMP Echo Request. Network ACLs or the instance firewall can also block it.

## Can VPC B use VPC A's internet gateway through peering?

No. VPC peering does not provide transitive routing through an internet gateway. VPC B needs its own supported egress setup if internet access is required.

## What does the ICMP failure check show?

Removing App-B's ICMP rule should stop ping from App-A. SSH should keep working because its separate TCP 22 rule remains. Restoring the ICMP rule should make ping work again.

