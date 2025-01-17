#!/bin/bash
apt update -y
apt upgrade -y
apt install vim
rm -rf /etc/resolv.conf
cat > /etc/resolv.conf <<EOF
nameserver 1.1.1.2
nameserver 1.0.0.2
EOF

systemctl disable --now systemd-resolved

cat >> /etc/hosts <<EOF
10.0.0.20 k3s-server-1
10.0.0.22 k3s-worker-1
10.0.0.23 k3s-worker-2
EOF

if [[ $(uname -a) =~ "Ubuntu" ]]; then
  iptables -F
  netfilter-persistent save

fi;

mkdir -p /etc/rancher/k3s
mkdir -p /var/lib/rancher/k3s/server/manifests

cat > /etc/rancher/k3s/config.yaml <<EOF
write-kubeconfig-mode: "0644"
token: "${token}"
disable:
  - traefik
  - servicelb
tls-san:
  - "api.${nlb_public_ip}.nip.io"
  - "api.${nlb_private_ip}.nip.io"
  - "api.${custom_domain}"
etcd-snapshot-schedule-cron: "10 */4 * * *"
etcd-s3: true
etcd-s3-endpoint: ${oci_bucket_namespace}.compat.objectstorage.eu-frankfurt-1.oraclecloud.com
etcd-s3-access-key: "${oci_bucket_ak}"
etcd-s3-secret-key: "${oci_bucket_sk}"
etcd-s3-bucket: "${oci_bucket}"
etcd-s3-folder: "${oci_bucket_folder}"
EOF

curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server --cluster-init" INSTALL_K3S_VERSION=${k3s_version} sh -
cat > /var/lib/rancher/k3s/server/manifests/00-ingress-nginx-helmchart.yaml <<EOF
---
apiVersion: v1
kind: Namespace
metadata:
  name: ingress-nginx
---
apiVersion: helm.cattle.io/v1
kind: HelmChart
metadata:
  name: ingress-nginx
  namespace: ingress-nginx
spec:
  repo: https://kubernetes.github.io/ingress-nginx
  chart: ingress-nginx
  set:
    global.systemDefaultRegistry: ""
  valuesContent: |-
    controller:
      kind: DaemonSet
      ingressClassResource:
        default: true
      hostNetwork: true
EOF
cat > /var/lib/rancher/k3s/server/manifests/01-cert-manager-helmchart.yaml <<EOF
---
apiVersion: v1
kind: Namespace
metadata:
  name: cert-manager
---
apiVersion: helm.cattle.io/v1
kind: HelmChart
metadata:
  name: cert-manager
  namespace: cert-manager
spec:
  repo: https://charts.jetstack.io
  chart: cert-manager
  version: v1.7.2
  set:
    global.systemDefaultRegistry: ""
  valuesContent: |-
    installCRDs: true
EOF
cat > /var/lib/rancher/k3s/server/manifests/02-cert-manager-staging-issuer.yaml <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-staging
spec:
  acme:
    # You must replace this email address with your own.
    # Let's Encrypt will use this to contact you about expiring
    # certificates, and issues related to your account.
    email: ${email_address}
    server: https://acme-staging-v02.api.letsencrypt.org/directory
    privateKeySecretRef:
      # Secret resource that will be used to store the account's private key.
      name: letsencrypt-staging-key
    # Add a single challenge solver, HTTP01 using nginx
    solvers:
    - http01:
        ingress:
          class: nginx
EOF
cat > /var/lib/rancher/k3s/server/manifests/02-cert-manager-prod-http-issuer.yaml <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod-http
spec:
  acme:
    # You must replace this email address with your own.
    # Let's Encrypt will use this to contact you about expiring
    # certificates, and issues related to your account.
    email: ${email_address}
    server: https://acme-v02.api.letsencrypt.org/directory
    privateKeySecretRef:
      # Secret resource that will be used to store the account's private key.
      name: letsencrypt-prod-key
    # Add a single challenge solver, HTTP01 using nginx
    solvers:
    - http01:
        ingress:
          class: nginx
EOF
cat > /var/lib/rancher/k3s/server/manifests/03-nullserv-helmchart.yaml <<EOF
apiVersion: helm.cattle.io/v1
kind: HelmChart
metadata:
  name: nullserv
  namespace: default
spec:
  repo: https://k8s-at-home.com/charts/
  chart: nullserv
  set:
    global.systemDefaultRegistry: ""
  valuesContent: |-
    ingress:
      main:
        # -- Enables or disables the ingress
        enabled: true
        ingressClassName: "nginx"
        annotations:
          cert-manager.io/cluster-issuer: letsencrypt-staging
        hosts:
          - host: nullserv.${nlb_public_ip}.nip.io
            paths:
              -  # -- Path.  Helm template can be passed.
                path: /
                # -- Ignored if not kubeVersion >= 1.14-0
                pathType: Prefix
        tls:
          - hosts:
              - nullserv.${nlb_public_ip}.nip.io
            secretName: nullserv-tls
EOF