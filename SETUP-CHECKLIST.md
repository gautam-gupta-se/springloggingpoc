# ✅ Implementation Checklist

## Step 1: Choose Your Method
- [ ] **Understand the 4 approaches** (read ARCHITECTURE-GUIDE.md if needed)
- [ ] **Identify your environment**:
  - [ ] Local development (Docker Desktop / Minikube) → **NodePort**
  - [ ] Cloud platform (AWS/GCP/Azure) → **LoadBalancer**
  - [ ] Production setup → **Ingress or Ingress+TLS**

---

## Step 2: NodePort Setup (Recommended for Most Users)

### Prerequisites
- [ ] Kubernetes cluster running
- [ ] Spring app deployment active: `kubectl get pods`

### Implementation
- [ ] Run: `kubectl apply -f service-nodeport.yaml`
- [ ] Verify: `kubectl get svc spring-app-nodeport`
- [ ] Check status shows Port: `8080:30080/TCP`

### Verification
```bash
# Copy this command and run it:
kubectl get svc spring-app-nodeport
```
- [ ] Service Status shows "ClusterIP" with port mapping
- [ ] Pod should be in "Running" state: `kubectl get pods`

### Access Test
- [ ] Open browser: `http://localhost:30080`
- [ ] See Spring Boot default page
- [ ] Try endpoint: `http://localhost:30080/helloMessage`
- [ ] Get expected response

### Success Indicator
```
✅ You can access the app without running kubectl port-forward
✅ Terminal is not blocked
✅ You can access from other machines on your network
```

---

## Step 3: LoadBalancer Setup (For Cloud Users)

### Prerequisites
- [ ] Kubernetes running on cloud provider (AWS, GCP, Azure)
- [ ] Cloud provider credentials configured
- [ ] Sufficient cloud credits/permissions

### Implementation
- [ ] Run: `kubectl apply -f service-loadbalancer.yaml`
- [ ] Wait for external IP: `kubectl get svc spring-app-loadbalancer --watch`
- [ ] Ctrl+C when you see EXTERNAL-IP (not `<pending>`)

### Verification
```bash
# Copy this command and run it:
kubectl get svc spring-app-loadbalancer
```
- [ ] EXTERNAL-IP column shows an actual IP address
- [ ] Ports column shows: `80:8080/TCP`

### Access Test
- [ ] Copy the EXTERNAL-IP from output
- [ ] Open browser: `http://<EXTERNAL-IP>`
- [ ] See Spring Boot default page

### Success Indicator
```
✅ Cloud provider assigned external IP
✅ App accessible from the internet
✅ Ready for production
```

---

## Step 4: Ingress Setup (For Production)

### Step 4a: Install NGINX Ingress Controller
- [ ] Check if already installed: `kubectl get ingressclass`
- [ ] If no output, install:
```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/cloud/deploy.yaml
```
- [ ] Wait for controller: `kubectl get pods -n ingress-nginx`
- [ ] Verify all pods are "Running"

### Step 4b: Apply ClusterIP Service
- [ ] Run: `kubectl apply -f service-clusterip.yaml`
- [ ] Verify: `kubectl get svc spring-app-service`

### Step 4c: Apply Ingress
- [ ] Run: `kubectl apply -f ingress-basic.yaml`
- [ ] Check: `kubectl get ingress`
- [ ] Describe to see IP: `kubectl describe ingress spring-app-ingress`

### Step 4d: Configure Hosts File
```bash
# Get the Ingress IP
kubectl get ingress spring-app-ingress -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
```
- [ ] Copy the IP from output
- [ ] Edit `/etc/hosts`: `sudo nano /etc/hosts`
- [ ] Add line: `<INGRESS-IP> spring-app.local`
- [ ] Save (Ctrl+X, Y, Enter)

### Step 4e: Verification
```bash
# Test DNS resolution
ping spring-app.local

# Or just open in browser
http://spring-app.local
```
- [ ] Can resolve `spring-app.local`
- [ ] App accessible at `http://spring-app.local`
- [ ] Endpoint works: `http://spring-app.local/helloMessage`

### Success Indicator
```
✅ Hostname-based access working
✅ Multiple apps can coexist on same cluster
✅ Production-ready routing
```

---

## Step 5: Ingress + TLS Setup (Enterprise)

### Prerequisites
- [ ] Ingress Controller installed (from Step 4a)
- [ ] cert-manager **not** installed, run:
```bash
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml
```
- [ ] Wait for pods: `kubectl get pods -n cert-manager`
- [ ] All pods should be "Running"

### Implementation
- [ ] Have a **domain name** ready (e.g., spring-app.example.com)
- [ ] Have an **email address** ready (for Let's Encrypt notifications)
- [ ] Run setup script: `./setup-access.sh` (choose option 4)
- [ ] Or manually edit `ingress-tls.yaml`:
  - [ ] Replace `spring-app.example.com` with your domain
  - [ ] Replace `your-email@example.com` with your email
  - [ ] Run: `kubectl apply -f ingress-tls.yaml`

### Verification
```bash
# Watch certificate provisioning
kubectl get certificate --watch
```
- [ ] Status changes from "Pending" to "True"
- [ ] Should complete in 1-5 minutes

### Access Test
- [ ] Update `/etc/hosts` with your domain and ingress IP
- [ ] Open: `https://spring-app.example.com`
- [ ] Should show HTTPS lock icon
- [ ] Certificate issued by "Let's Encrypt"

### Success Indicator
```
✅ HTTPS connection with valid certificate
✅ Automatic certificate renewal
✅ Enterprise-grade security
```

---

## Step 6: Verification Across All Methods

### Check All Resources
```bash
# See all services
kubectl get svc

# See all ingresses
kubectl get ingress

# See all deployments
kubectl get deployment

# See complete overview
kubectl get all
```

### Pod Health Check
```bash
# Check pods are running
kubectl get pods

# View pod logs
kubectl logs -l app=spring-app --all-containers=true

# Test connectivity from within cluster
kubectl exec -it <pod-name> -- curl localhost:8080
```

### Network Diagnostics
```bash
# Test from debug container
kubectl run -it --rm debug --image=busybox --restart=Never -- sh
# Inside the container, try:
# wget -O- http://spring-app-service:8080/helloMessage
```

---

## Step 7: Clean Up Old Method

- [ ] Stop running `kubectl port-forward` (if you were using it)
  - Simply Ctrl+C in the terminal where it's running
  - No cleanup needed
- [ ] No port-forward means terminal is free!

---

## Step 8: Documentation

- [ ] Bookmark key files for reference:
  - [ ] `QUICK-REFERENCE.md` - One-liners and basics
  - [ ] `KUBERNETES-ACCESS-GUIDE.md` - Complete guide
  - [ ] `ARCHITECTURE-GUIDE.md` - Visual explanations
- [ ] Share this checklist with your team
- [ ] Document your chosen method in your project README

---

## Troubleshooting Checklist

### Service Shows No Endpoints
```bash
# Check if pods are running
kubectl get pods
# Should show pods in "Running" state

# Check pod labels match service selector
kubectl get pods --show-labels
# Should show label: app=spring-app
```
- [ ] Fix: Ensure deployment has correct labels
- [ ] Restart if needed: `kubectl rollout restart deployment/spring-app-logging-poc`

### Can't Access Service
```bash
# Verify service exists
kubectl get svc

# Check service endpoints
kubectl get endpoints spring-app-service

# Test internal connectivity
kubectl run -it --rm curl --image=curlimages/curl --restart=Never -- \
  curl http://spring-app-service:8080
```
- [ ] Fix: Verify deployment is running and healthy

### Ingress Shows No IP
```bash
# Check ingress controller is running
kubectl get pods -n ingress-nginx

# Check ingress status
kubectl describe ingress spring-app-ingress
```
- [ ] Fix: Ensure ingress controller is installed and running

### Certificate Won't Issue
```bash
# Check cert-manager logs
kubectl logs -n cert-manager deploy/cert-manager

# Check certificate status
kubectl describe certificate spring-app-tls-secret

# Check ClusterIssuer
kubectl describe clusterissuer letsencrypt-prod
```
- [ ] Fix: Verify domain is accessible, email is correct

---

## Success Criteria

You've successfully completed the setup when:

- [ ] Service is deployed: `kubectl get svc`
- [ ] Pods are healthy: `kubectl get pods` shows "Running"
- [ ] Service has endpoints: `kubectl get endpoints`
- [ ] App is accessible without port-forward
- [ ] Can access from another machine on network (NodePort)
- [ ] Terminal is not blocked by port-forward process
- [ ] Can test endpoints: `/helloMessage` returns expected response

---

## Rollback Checklist

If you need to go back to port-forward:

- [ ] Delete service: `kubectl delete svc spring-app-nodeport`
- [ ] Delete ingress: `kubectl delete ingress spring-app-ingress`
- [ ] Go back to port-forward: `kubectl port-forward deployment/spring-app-logging-poc 8080:8080`

**Note:** Deployment itself is not affected, you can switch methods anytime!

---

## Post-Setup Maintenance

### Regular Checks
- [ ] Monitor pod health: `kubectl logs -f <pod-name>`
- [ ] Watch service metrics: `kubectl top pods`
- [ ] Review certificates: `kubectl get certificate`

### When Scaling Up
- [ ] Increase replicas: `kubectl scale deployment spring-app-logging-poc --replicas=3`
- [ ] Service automatically handles load balancing

### When Troubleshooting
- [ ] Collect logs: `kubectl logs -l app=spring-app`
- [ ] Describe resources: `kubectl describe svc/pod/ingress`
- [ ] Check events: `kubectl get events`

---

## Next Steps After Setup

1. **Update your README** to reflect new access method
2. **Remove port-forward instructions** from documentation
3. **Share this guide** with team members
4. **Consider production setup** (Ingress + TLS) for future
5. **Monitor and maintain** your chosen access method

---

**Questions?** Refer to KUBERNETES-ACCESS-GUIDE.md or ARCHITECTURE-GUIDE.md

**Ready to start?** Pick your method and work through the checklist!

🚀 Good luck with your setup!

