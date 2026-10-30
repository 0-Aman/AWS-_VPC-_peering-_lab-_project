# Test evidence

No AWS test evidence is included yet. Capture the real terminal output from your own lab deployment and save it here. Keep the command, host, date, and result with each capture. Do not copy expected output or example resource IDs as evidence.

Capture these checks:

1. App-A to App-B baseline before peering is created.
2. Forward and reverse ping after the peering routes are active.
3. SSH to App-B through the bastion.
4. App-A and App-B public IPv4 audit.
5. ICMP failure while the App-B inbound Echo Request rule is temporarily removed, with SSH still working.
6. Ping recovery after the rule is restored.

Run the post-deployment checks with `../scripts/test-connectivity.sh` and the failure experiment with `../scripts/controlled-failure-test.sh`.
