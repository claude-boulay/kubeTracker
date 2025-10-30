# Documentation - Mise en Place d'un Cluster Kubernetes

**Projet :** Déploiement Application Fleetman  
**Configuration requise :** 1 nœud master + 2 nœuds worker  
**Date :** Octobre 2025

---

## Table des Matières

1. [Prérequis](#prérequis)
2. [Option 1 : Installation avec kubeadm](#option-1--installation-avec-kubeadm)
3. [Option 2 : Installation avec K3s](#option-2--installation-avec-k3s-alternative-légère)
4. [Vérification du cluster](#vérification-du-cluster)
5. [Configuration post-installation](#configuration-post-installation)
6. [Résolution de problèmes](#résolution-de-problèmes)

---

## Prérequis

### Matériel requis

Pour chaque nœud (master et workers) :
- **CPU :** Minimum 2 cores
- **RAM :** Minimum 2 GB (4 GB recommandé pour le master)
- **Disque :** Minimum 20 GB
- **Réseau :** Connexion entre tous les nœuds

### Système d'exploitation

- Ubuntu 20.04 LTS ou 22.04 LTS (recommandé)
- Debian 11 ou plus récent
- CentOS 7/8 ou Rocky Linux 8

### Préparation sur TOUS les nœuds

```bash
# 1. Mettre à jour le système
sudo apt update && sudo apt upgrade -y

# 2. Désactiver le swap (obligatoire pour Kubernetes)
sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab

# 3. Charger les modules kernel nécessaires
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

# 4. Configurer les paramètres sysctl
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sudo sysctl --system

# 5. Installer containerd (runtime de conteneurs)
sudo apt install -y containerd
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml
sudo systemctl restart containerd
sudo systemctl enable containerd
```

---

## Option 1 : Installation avec kubeadm

### Étape 1 : Installation des composants Kubernetes (TOUS les nœuds)

```bash
# 1. Ajouter les dépôts Kubernetes
sudo apt-get install -y apt-transport-https ca-certificates curl gpg
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list

# 2. Installer kubelet, kubeadm et kubectl
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

# 3. Activer kubelet
sudo systemctl enable kubelet
```

### Étape 2 : Initialisation du nœud master

```bash
# Sur le nœud MASTER uniquement
sudo kubeadm init --pod-network-cidr=10.244.0.0/16

# Configurer kubectl pour l'utilisateur
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

**Important :** Sauvegarder la commande `kubeadm join` affichée, elle sera nécessaire pour joindre les workers.

Exemple :
```bash
kubeadm join 192.168.1.100:6443 --token abcdef.0123456789abcdef \
    --discovery-token-ca-cert-hash sha256:1234567890abcdef...
```

### Étape 3 : Installation du réseau pod (Flannel)

```bash
# Sur le nœud MASTER
kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml

# Vérifier que les pods système démarrent
kubectl get pods -n kube-system
```

### Étape 4 : Joindre les nœuds workers

```bash
# Sur CHAQUE nœud WORKER, exécuter la commande kubeadm join sauvegardée précédemment
sudo kubeadm join 192.168.1.100:6443 --token abcdef.0123456789abcdef \
    --discovery-token-ca-cert-hash sha256:1234567890abcdef...
```

### Étape 5 : Vérifier que les nœuds sont joints

```bash
# Sur le nœud MASTER
kubectl get nodes

# Résultat attendu :
# NAME       STATUS   ROLES           AGE   VERSION
# master     Ready    control-plane   10m   v1.28.0
# worker-1   Ready    <none>          5m    v1.28.0
# worker-2   Ready    <none>          5m    v1.28.0
```

---

## Option 2 : Installation avec K3s (Alternative légère)

K3s est une distribution Kubernetes légère, idéale pour les environnements de développement et les ressources limitées.

### Étape 1 : Installation du nœud master

```bash
# Sur le nœud MASTER
curl -sfL https://get.k3s.io | sh -s - --write-kubeconfig-mode 644

# Récupérer le token pour joindre les workers
sudo cat /var/lib/rancher/k3s/server/node-token
```

### Étape 2 : Joindre les nœuds workers

```bash
# Sur CHAQUE nœud WORKER
curl -sfL https://get.k3s.io | K3S_URL=https://<MASTER_IP>:6443 K3S_TOKEN=<TOKEN> sh -

# Exemple :
# curl -sfL https://get.k3s.io | K3S_URL=https://192.168.1.100:6443 K3S_TOKEN=K10abc123... sh -
```

### Étape 3 : Vérifier le cluster

```bash
# Sur le nœud MASTER
kubectl get nodes
```

---

## Vérification du Cluster

### Vérifier l'état des nœuds

```bash
kubectl get nodes -o wide
```

### Vérifier les composants système

```bash
kubectl get pods -n kube-system
```

Tous les pods doivent être en état `Running`.

### Vérifier la connectivité réseau

```bash
# Déployer un pod de test
kubectl run test-pod --image=nginx --restart=Never
kubectl get pods

# Nettoyer
kubectl delete pod test-pod
```

### Vérifier les ressources

```bash
kubectl top nodes
kubectl describe nodes
```

---

## Configuration Post-Installation

### 1. Configurer kubectl sur votre machine locale

```bash
# Copier le fichier de configuration depuis le master
scp user@master-ip:/home/user/.kube/config ~/.kube/config

# Vérifier la connexion
kubectl get nodes
```

### 2. Installer Metrics Server (pour kubectl top)

```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Si erreur TLS, ajouter --kubelet-insecure-tls
kubectl patch deployment metrics-server -n kube-system --type='json' \
  -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-insecure-tls"}]'
```

### 3. Configurer le stockage local (pour PersistentVolume)

```bash
# Sur CHAQUE nœud worker, créer le répertoire de stockage
sudo mkdir -p /mnt/data/mongodb
sudo chmod 777 /mnt/data/mongodb
```

### 4. Labelliser les nœuds (optionnel)

```bash
# Ajouter des labels pour identifier les workers
kubectl label node worker-1 node-role.kubernetes.io/worker=worker
kubectl label node worker-2 node-role.kubernetes.io/worker=worker
```

---

## Déploiement de l'Application Fleetman

### Méthode 1 : Déploiement avec kubectl

```bash
# Se placer dans le dossier des manifestes
cd k8s-manifests

# Appliquer tous les manifestes dans l'ordre
kubectl apply -f 00-namespace.yaml
kubectl apply -f 01-mongodb-storage.yaml
kubectl apply -f 02-mongodb-deployment.yaml
kubectl apply -f 02-mongodb-service.yaml
kubectl apply -f 03-queue-deployment.yaml
kubectl apply -f 03-queue-service.yaml
kubectl apply -f 03-queue-admin-service.yaml
kubectl apply -f 04-position-simulator-deployment.yaml
kubectl apply -f 04-position-simulator-service.yaml
kubectl apply -f 05-position-tracker-deployment.yaml
kubectl apply -f 05-position-tracker-service.yaml
kubectl apply -f 06-api-gateway-deployment.yaml
kubectl apply -f 06-api-gateway-service.yaml
kubectl apply -f 07-web-app-deployment.yaml
kubectl apply -f 07-web-app-service.yaml

# Ou appliquer tous les fichiers d'un coup
kubectl apply -f .
```

### Méthode 2 : Utiliser kustomization

Créer un fichier `kustomization.yaml` :

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - 00-namespace.yaml
  - 01-mongodb-storage.yaml
  - 02-mongodb-deployment.yaml
  - 02-mongodb-service.yaml
  - 03-queue-deployment.yaml
  - 03-queue-service.yaml
  - 03-queue-admin-service.yaml
  - 04-position-simulator-deployment.yaml
  - 04-position-simulator-service.yaml
  - 05-position-tracker-deployment.yaml
  - 05-position-tracker-service.yaml
  - 06-api-gateway-deployment.yaml
  - 06-api-gateway-service.yaml
  - 07-web-app-deployment.yaml
  - 07-web-app-service.yaml
```

Puis déployer :

```bash
kubectl apply -k .
```

### Vérifier le déploiement

```bash
# Vérifier tous les pods
kubectl get pods -n fleetman

# Vérifier tous les services
kubectl get svc -n fleetman

# Vérifier les PersistentVolumeClaims
kubectl get pvc -n fleetman

# Suivre les logs d'un pod
kubectl logs -f <nom-du-pod> -n fleetman
```

### Accéder à l'application

```bash
# Récupérer l'IP d'un worker
kubectl get nodes -o wide

# L'application est accessible sur : http://<WORKER_IP>:30080
# Interface admin ActiveMQ sur : http://<WORKER_IP>:30161
```

---

## Résolution de Problèmes

### Problème : Les nœuds ne passent pas à l'état Ready

```bash
# Vérifier les logs kubelet
sudo journalctl -u kubelet -f

# Vérifier l'état du réseau pod
kubectl get pods -n kube-system
kubectl logs -n kube-system <pod-flannel> -c kube-flannel
```

### Problème : Les pods restent en Pending

```bash
# Vérifier les événements
kubectl describe pod <nom-du-pod> -n fleetman

# Vérifier les ressources disponibles
kubectl top nodes
kubectl describe nodes
```

### Problème : PersistentVolume ne se lie pas

```bash
# Vérifier le PV et PVC
kubectl get pv
kubectl get pvc -n fleetman
kubectl describe pvc mongodb-pvc -n fleetman

# Vérifier que le répertoire existe sur les workers
ls -la /mnt/data/mongodb
```

### Problème : Les positions ne s'affichent pas

```bash
# Redémarrer le pod queue
kubectl rollout restart deployment fleetman-queue -n fleetman

# Vérifier les logs
kubectl logs -n fleetman -l app=fleetman-queue
kubectl logs -n fleetman -l app=fleetman-position-tracker
```

### Commandes utiles pour déboguer

```bash
# Voir tous les événements du namespace
kubectl get events -n fleetman --sort-by='.lastTimestamp'

# Entrer dans un pod pour déboguer
kubectl exec -it <nom-du-pod> -n fleetman -- /bin/sh

# Tester la connectivité réseau entre pods
kubectl run -it --rm debug --image=busybox --restart=Never -- sh
# Puis dans le pod : wget -O- http://fleetman-queue.fleetman.svc.cluster.local:61616
```

---

## Haute Disponibilité et Résilience

### Test de défaillance d'un nœud worker

```bash
# 1. Vérifier la distribution des pods
kubectl get pods -n fleetman -o wide

# 2. Simuler une panne en arrêtant un worker
# Sur le worker-1 :
sudo systemctl stop kubelet

# 3. Observer la migration des pods
kubectl get pods -n fleetman -o wide --watch

# 4. Vérifier que l'application reste accessible
curl http://<WORKER_2_IP>:30080

# 5. Redémarrer le worker
sudo systemctl start kubelet
```

### Scaling manuel

```bash
# Augmenter le nombre de replicas
kubectl scale deployment fleetman-web-app -n fleetman --replicas=3

# Vérifier
kubectl get pods -n fleetman -l app=fleetman-web-app
```

---

## Nettoyage et Suppression

### Supprimer l'application

```bash
# Supprimer tous les ressources du namespace
kubectl delete namespace fleetman

# Supprimer le PersistentVolume
kubectl delete pv mongodb-pv
```

### Réinitialiser le cluster (si nécessaire)

```bash
# Sur chaque worker
sudo kubeadm reset -f
sudo rm -rf /etc/cni/net.d
sudo rm -rf $HOME/.kube

# Sur le master
sudo kubeadm reset -f
sudo rm -rf /etc/cni/net.d
sudo rm -rf $HOME/.kube
```

---

## Annexes

### Architecture du Cluster

```
┌─────────────────────────────────────────────────────────┐
│                     Master Node                         │
│  - API Server                                           │
│  - Scheduler                                            │
│  - Controller Manager                                   │
│  - etcd                                                 │
└─────────────────────────────────────────────────────────┘
                           │
           ┌───────────────┴───────────────┐
           │                               │
┌──────────▼──────────┐         ┌──────────▼──────────┐
│   Worker Node 1     │         │   Worker Node 2     │
│  - kubelet          │         │  - kubelet          │
│  - kube-proxy       │         │  - kube-proxy       │
│  - containerd       │         │  - containerd       │
│  - Pods Fleetman    │         │  - Pods Fleetman    │
└─────────────────────┘         └─────────────────────┘
```

### Checklist de Validation

- [ ] Tous les nœuds sont en état `Ready`
- [ ] Tous les pods système sont en état `Running`
- [ ] Le namespace `fleetman` est créé
- [ ] Les 6 déploiements sont créés et fonctionnels
- [ ] Les services sont créés avec les bons types (ClusterIP/NodePort)
- [ ] Le PersistentVolume est lié au PVC
- [ ] L'application web est accessible sur http://WORKER_IP:30080
- [ ] Les positions des véhicules s'affichent sur la carte
- [ ] L'application reste disponible après arrêt d'un worker

---

## Ressources Complémentaires

- Documentation officielle Kubernetes : https://kubernetes.io/docs/
- Guide kubeadm : https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/
- K3s Documentation : https://docs.k3s.io/
- Flannel CNI : https://github.com/flannel-io/flannel
- Troubleshooting Kubernetes : https://kubernetes.io/docs/tasks/debug/

---

**Note :** Cette documentation a été rédigée dans le cadre du projet final Kubernetes.
Les commandes ont été testées sur Ubuntu 22.04 LTS avec Kubernetes v1.28.

