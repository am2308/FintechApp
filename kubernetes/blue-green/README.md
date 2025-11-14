Blue/Green deployment overlays

- Services select by label `color: blue|green`.
- Deployments include `color` label in pod template.
- Switch traffic by updating Service selector.

Usage:
- Apply base namespace and MySQL first.
- Deploy color using: kubectl apply -f kubernetes/blue-green/deployments/<color>/
- Flip traffic by applying services for the color: kubernetes/blue-green/services/<color>/
