#!/bin/bash

# Quick Setup Script for Kubernetes Direct Access
# Choose your preferred method and run the corresponding commands

echo "🚀 Kubernetes Direct Access Setup"
echo "=================================="
echo ""
echo "Choose your environment:"
echo "1) NodePort (Local/On-Premise) - RECOMMENDED FOR LOCAL"
echo "2) LoadBalancer (Cloud Provider) - RECOMMENDED FOR CLOUD"
echo "3) Ingress (Production)"
echo "4) Ingress with TLS (Production-Ready)"
echo "5) Show all options"
echo ""
read -p "Enter your choice (1-5): " choice

case $choice in
  1)
    echo ""
    echo "📋 Setting up NodePort Service..."
    kubectl apply -f service-nodeport.yaml
    echo ""
    echo "✅ NodePort service created!"
    echo ""
    echo "Getting access details..."
    sleep 2
    echo ""
    echo "Your app will be accessible at:"
    NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="ExternalIP")].address}')
    if [ -z "$NODE_IP" ]; then
      NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
    fi
    NODE_PORT=$(kubectl get svc spring-app-nodeport -o jsonpath='{.spec.ports[0].nodePort}')

    echo ""
    echo "🌐 http://$NODE_IP:$NODE_PORT"
    echo "🌐 http://$NODE_IP:$NODE_PORT/helloMessage"
    echo ""
    echo "For Docker Desktop: http://localhost:$NODE_PORT"
    echo "For Docker Desktop: http://localhost:$NODE_PORT/helloMessage"
    ;;

  2)
    echo ""
    echo "📋 Setting up LoadBalancer Service..."
    kubectl apply -f service-loadbalancer.yaml
    echo ""
    echo "✅ LoadBalancer service created!"
    echo ""
    echo "⏳ Waiting for external IP (this may take 1-5 minutes)..."
    echo ""
    kubectl get svc spring-app-loadbalancer --watch
    ;;

  3)
    echo ""
    echo "📋 Setting up Ingress..."
    echo ""
    echo "First, checking if NGINX Ingress Controller is installed..."
    if kubectl get ingressclass nginx &> /dev/null; then
      echo "✅ NGINX Ingress Controller found!"
    else
      echo "⚠️  NGINX Ingress Controller not found."
      read -p "Install it now? (y/n): " install_nginx
      if [ "$install_nginx" = "y" ]; then
        echo "Installing NGINX Ingress Controller..."
        kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/cloud/deploy.yaml
        echo "⏳ Waiting for ingress controller to be ready..."
        kubectl wait --namespace ingress-nginx --for=condition=ready pod --selector=app.kubernetes.io/component=controller --timeout=120s
      fi
    fi

    echo ""
    echo "Applying ClusterIP Service..."
    kubectl apply -f service-clusterip.yaml

    echo "Applying Ingress..."
    kubectl apply -f ingress-basic.yaml

    echo ""
    echo "✅ Ingress setup complete!"
    echo ""
    echo "Getting Ingress IP..."
    INGRESS_IP=$(kubectl get ingress spring-app-ingress -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

    if [ -z "$INGRESS_IP" ]; then
      INGRESS_HOSTNAME=$(kubectl get ingress spring-app-ingress -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
      echo ""
      echo "🌐 Ingress Hostname: $INGRESS_HOSTNAME"
    else
      echo ""
      echo "🌐 Ingress IP: $INGRESS_IP"
    fi

    echo ""
    echo "📝 Add this to your /etc/hosts file:"
    echo "$INGRESS_IP spring-app.local"
    echo ""
    echo "Then access at:"
    echo "http://spring-app.local"
    echo "http://spring-app.local/helloMessage"
    ;;

  4)
    echo ""
    echo "📋 Setting up Ingress with TLS..."
    echo ""
    echo "This requires:"
    echo "1. cert-manager"
    echo "2. A domain name (or local domain)"
    echo ""
    read -p "Do you have cert-manager installed? (y/n): " has_cert_manager

    if [ "$has_cert_manager" != "y" ]; then
      echo ""
      echo "Installing cert-manager..."
      kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml
      echo "⏳ Waiting for cert-manager to be ready..."
      kubectl wait --namespace cert-manager --for=condition=ready pod --selector=app=cert-manager --timeout=120s
    fi

    echo ""
    echo "Applying ClusterIP Service..."
    kubectl apply -f service-clusterip.yaml

    echo "Applying Ingress with TLS..."
    read -p "Enter your domain name (e.g., spring-app.example.com): " domain
    read -p "Enter your email for Let's Encrypt: " email

    # Create ClusterIssuer
    kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: $email
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
EOF

    # Apply ingress with TLS
    kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: spring-app-ingress-tls
  namespace: default
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
spec:
  ingressClassName: nginx
  tls:
    - hosts:
        - $domain
      secretName: spring-app-tls-secret
  rules:
    - host: $domain
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: spring-app-service
                port:
                  number: 8080
EOF

    echo ""
    echo "✅ TLS Ingress setup complete!"
    echo ""
    echo "⏳ Certificate is being created. This may take a few minutes..."
    echo ""
    echo "Check certificate status:"
    echo "kubectl get certificate"
    echo ""
    echo "Once ready, access at:"
    echo "https://$domain"
    echo "https://$domain/helloMessage"
    ;;

  5)
    echo ""
    echo "📖 Available Kubernetes manifests:"
    echo ""
    echo "1️⃣  NodePort: service-nodeport.yaml"
    echo "    kubectl apply -f service-nodeport.yaml"
    echo ""
    echo "2️⃣  LoadBalancer: service-loadbalancer.yaml"
    echo "    kubectl apply -f service-loadbalancer.yaml"
    echo ""
    echo "3️⃣  ClusterIP + Ingress: service-clusterip.yaml + ingress-basic.yaml"
    echo "    kubectl apply -f service-clusterip.yaml"
    echo "    kubectl apply -f ingress-basic.yaml"
    echo ""
    echo "4️⃣  ClusterIP + Ingress+TLS: service-clusterip.yaml + ingress-tls.yaml"
    echo "    kubectl apply -f service-clusterip.yaml"
    echo "    kubectl apply -f ingress-tls.yaml"
    echo ""
    echo "📚 For detailed guide, read: KUBERNETES-ACCESS-GUIDE.md"
    ;;

  *)
    echo "Invalid choice. Please run the script again."
    exit 1
    ;;
esac

echo ""
echo "✨ Done! You can now access your app without port-forwarding!"

