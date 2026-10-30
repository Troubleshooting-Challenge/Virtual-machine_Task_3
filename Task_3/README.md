Student Tasks:
1. Identify why the Load Balancer health probe is failing.
2. Verify the NGINX listening port on both Linux VMs.
3. Identify the mismatch between the health probe, backend port and NGINX port.
4. Correct the Load Balancer rule and health probe.
5. Verify that both VMs are added to the backend pool.
6. Check the NSG rules and allow the required application traffic.
7. Identify why the autoscaling configuration is targeting an individual VM instead of a VM Scale Set.
8. Correct the autoscaling target to use the VM Scale Set resource ID.
9. Configure a scale-out rule when CPU utilization exceeds 80%.
10. Configure a scale-in rule when CPU utilization drops below 30%.
11. Generate CPU load and monitor autoscaling.
12. Verify that the Load Balancer continues serving traffic when one VM becomes unhealthy.