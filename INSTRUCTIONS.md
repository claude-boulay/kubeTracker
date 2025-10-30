# Instructions pour le Correcteur

## 📦 Contenu du Livrable

Ce projet contient tous les éléments nécessaires pour déployer l'application Fleetman sur un cluster Kubernetes.

### Structure du Projet

```
ProjetFinal/
├── k8s-manifests/                  # Manifestes Kubernetes
│   ├── 00-namespace.yaml           # Namespace fleetman
│   ├── 01-mongodb-storage.yaml     # PV et PVC pour MongoDB
│   ├── 02-mongodb.yaml             # Déploiement + Service MongoDB
│   ├── 03-queue.yaml               # Déploiement + Services ActiveMQ
│   ├── 04-position-simulator.yaml  # Déploiement + Service Position Simulator
│   ├── 05-position-tracker.yaml    # Déploiement + Service Position Tracker
│   ├── 06-api-gateway.yaml         # Déploiement + Service API Gateway
│   ├── 07-web-app.yaml             # Déploiement + Service Web App
│   └── kustomization.yaml          # Fichier Kustomize (optionnel)
│
├── documentation-cluster-kubernetes.md  # Documentation détaillée du cluster
├── README.md                       # Instructions complètes de déploiement
├── deploy.sh                       # Script de déploiement automatique
├── undeploy.sh                     # Script de suppression
├── sujet.md                        # Sujet du projet (reformaté)
└── INSTRUCTIONS.md                 # Ce fichier

```

---

## 🚀 Déploiement Rapide (3 minutes)

### Prérequis
- Cluster Kubernetes avec 1 master + 2 workers configuré
- kubectl installé et configuré

### Étape 1 : Préparation du stockage

**Sur CHAQUE nœud worker**, créer le répertoire pour MongoDB :

```bash
sudo mkdir -p /mnt/data/mongodb
sudo chmod 777 /mnt/data/mongodb
```

### Étape 2 : Déploiement

**Option A - Script automatique (recommandé)** :

```bash
chmod +x deploy.sh
./deploy.sh
```

**Option B - Manuel** :

```bash
kubectl apply -f k8s-manifests/
```

**Option C - Avec Kustomize** :

```bash
kubectl apply -k k8s-manifests/
```

### Étape 3 : Vérification

```bash
# Attendre que tous les pods soient prêts
kubectl get pods -n fleetman --watch

# Quand tous les pods sont Running, accéder à l'application
kubectl get nodes -o wide
# Ouvrir http://<WORKER_IP>:30080
```

---

## 📋 Validation des Critères (40 points)

### Déploiements et Services (10 points)

| Composant | Déploiement | Service | Fichier | Points |
|-----------|-------------|---------|---------|--------|
| position-simulator | ✅ | ✅ | 04-position-simulator.yaml | 2 |
| queue | ✅ | ✅ | 03-queue.yaml | 2 |
| position-tracker | ✅ | ✅ | 05-position-tracker.yaml | 2 |
| api-gateway | ✅ | ✅ | 06-api-gateway.yaml | 2 |
| web-app | ✅ | ✅ | 07-web-app.yaml | 2 |

**Vérification** :
```bash
kubectl get deployments -n fleetman
kubectl get services -n fleetman
```

### MongoDB Persisté (7 points)

- ✅ **PersistentVolume** : Défini dans `01-mongodb-storage.yaml`
- ✅ **PersistentVolumeClaim** : Défini dans `01-mongodb-storage.yaml`
- ✅ **Déploiement MongoDB** : Utilise le PVC dans `02-mongodb.yaml`
- ✅ **Persistance des données** : Volume monté sur `/data/db`

**Vérification** :
```bash
kubectl get pv
kubectl get pvc -n fleetman
kubectl describe deployment fleetman-mongodb -n fleetman | grep -A 5 "Volumes"
```

### Isolation Appropriée (3 points)

- ✅ **Namespace dédié** : `fleetman` (fichier `00-namespace.yaml`)
- ✅ **Services internes** : ClusterIP pour les services non exposés
- ✅ **Services externes** : NodePort uniquement pour web-app et admin queue
- ✅ **Réseau** : Communication interne via noms de services

**Services internes (ClusterIP)** :
- fleetman-mongodb
- fleetman-queue (pour messaging interne)
- fleetman-position-simulator
- fleetman-position-tracker
- fleetman-api-gateway

**Services externes (NodePort)** :
- fleetman-web-app (port 30080)
- fleetman-queue-admin (port 30161, optionnel)

**Vérification** :
```bash
kubectl get namespaces
kubectl get svc -n fleetman
```

### Documentation Cluster (13 points)

Le fichier `documentation-cluster-kubernetes.md` contient :

- ✅ **Prérequis détaillés** : Matériel, système d'exploitation, préparation des nœuds
- ✅ **Installation avec kubeadm** : Guide pas à pas complet
- ✅ **Alternative K3s** : Deuxième option d'installation
- ✅ **Configuration réseau** : Installation de Flannel CNI
- ✅ **Vérifications** : Commandes pour valider le cluster
- ✅ **Post-installation** : Configuration additionnelle
- ✅ **Déploiement application** : Instructions détaillées
- ✅ **Résolution de problèmes** : Section troubleshooting complète
- ✅ **Architecture** : Diagramme et explications
- ✅ **Annexes** : Checklist et ressources

**Total** : 30+ pages de documentation avec captures de commandes et explications.

### Instructions Claires (3 points)

- ✅ **README.md** : Guide complet avec table des matières, exemples, troubleshooting
- ✅ **INSTRUCTIONS.md** : Ce fichier pour le correcteur
- ✅ **Scripts automatiques** : `deploy.sh` et `undeploy.sh`
- ✅ **Commentaires** : Tous les manifestes YAML sont commentés
- ✅ **Organisation** : Fichiers numérotés dans l'ordre de déploiement

### Résilience (4 points)

- ✅ **Replicas multiples** :
  - fleetman-web-app : 2 replicas
  - fleetman-api-gateway : 2 replicas
  - fleetman-position-tracker : 2 replicas

- ✅ **Anti-affinity** : Configurée pour distribuer les pods sur différents nœuds
  ```yaml
  affinity:
    podAntiAffinity:
      preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        podAffinityTerm:
          topologyKey: kubernetes.io/hostname
  ```

- ✅ **Health checks** : Liveness et Readiness probes configurées

- ✅ **Services** : Load balancing automatique entre les replicas

**Test de résilience** :
```bash
# 1. Vérifier la distribution des pods
kubectl get pods -n fleetman -o wide

# 2. Simuler une panne
# Sur worker-1 : sudo systemctl stop kubelet

# 3. Vérifier que l'application reste accessible
curl http://<WORKER_2_IP>:30080

# 4. Observer la migration des pods
kubectl get pods -n fleetman -o wide --watch
```

---

## 🎯 Accès à l'Application

### Application Web Fleetman

```
http://<WORKER_IP>:30080
```

**Fonctionnalités visibles** :
- Carte avec épingles de véhicules
- Liste des véhicules à droite
- Mise à jour en temps réel des positions
- Clic sur un véhicule pour voir son trajet

### Interface Admin ActiveMQ (optionnel)

```
http://<WORKER_IP>:30161
```

Identifiants :
- Username: `admin`
- Password: `admin`

---

## 🔍 Commandes de Vérification

### Vérifier tous les composants

```bash
# État global
kubectl get all -n fleetman

# Pods détaillés avec distribution sur les nœuds
kubectl get pods -n fleetman -o wide

# Services avec ports exposés
kubectl get svc -n fleetman

# Vérifier la persistance
kubectl get pv,pvc -n fleetman

# Vérifier les événements
kubectl get events -n fleetman --sort-by='.lastTimestamp'
```

### Vérifier chaque composant individuellement

```bash
# Position Simulator
kubectl get deployment fleetman-position-simulator -n fleetman
kubectl get svc fleetman-position-simulator -n fleetman

# Queue
kubectl get deployment fleetman-queue -n fleetman
kubectl get svc fleetman-queue -n fleetman

# Position Tracker
kubectl get deployment fleetman-position-tracker -n fleetman
kubectl get svc fleetman-position-tracker -n fleetman

# API Gateway
kubectl get deployment fleetman-api-gateway -n fleetman
kubectl get svc fleetman-api-gateway -n fleetman

# Web App
kubectl get deployment fleetman-web-app -n fleetman
kubectl get svc fleetman-web-app -n fleetman

# MongoDB
kubectl get deployment fleetman-mongodb -n fleetman
kubectl get svc fleetman-mongodb -n fleetman
kubectl describe pvc mongodb-pvc -n fleetman
```

### Vérifier les logs

```bash
# Logs de chaque composant
kubectl logs -n fleetman -l app=fleetman-position-simulator
kubectl logs -n fleetman -l app=fleetman-queue
kubectl logs -n fleetman -l app=fleetman-position-tracker
kubectl logs -n fleetman -l app=fleetman-api-gateway
kubectl logs -n fleetman -l app=fleetman-web-app
kubectl logs -n fleetman -l app=fleetman-mongodb
```

---

## 🛠️ Résolution de Problèmes Courants

### Les positions ne s'affichent pas

```bash
# Redémarrer la queue
kubectl rollout restart deployment fleetman-queue -n fleetman

# Attendre 30 secondes puis vérifier
kubectl get pods -n fleetman
```

### Un pod reste en Pending

```bash
# Diagnostiquer
kubectl describe pod <nom-du-pod> -n fleetman

# Vérifier les ressources
kubectl top nodes

# Vérifier le PV (si c'est MongoDB)
kubectl get pv
kubectl describe pv mongodb-pv
```

### Impossible d'accéder via NodePort

```bash
# Vérifier le service
kubectl get svc -n fleetman fleetman-web-app

# Utiliser port-forward en alternative
kubectl port-forward -n fleetman svc/fleetman-web-app 8080:80
# Puis accéder à http://localhost:8080
```

---

## 🧹 Nettoyage

Pour supprimer complètement l'application :

**Option A - Script** :
```bash
chmod +x undeploy.sh
./undeploy.sh
```

**Option B - Manuel** :
```bash
kubectl delete namespace fleetman
kubectl delete pv mongodb-pv
```

Puis sur chaque worker :
```bash
sudo rm -rf /mnt/data/mongodb
```

---

## 📚 Documentation Complémentaire

- **README.md** : Guide complet d'utilisation avec toutes les commandes
- **documentation-cluster-kubernetes.md** : Documentation de mise en place du cluster (30+ pages)
- **sujet.md** : Sujet du projet reformaté pour plus de clarté

---

## ✅ Checklist Finale pour le Correcteur

- [ ] Cluster Kubernetes avec 1 master + 2 workers configuré
- [ ] Répertoire `/mnt/data/mongodb` créé sur les workers
- [ ] Déploiement effectué (via script ou manuellement)
- [ ] Tous les pods en état `Running` (`kubectl get pods -n fleetman`)
- [ ] Web App accessible sur `http://<WORKER_IP>:30080`
- [ ] Les véhicules s'affichent sur la carte
- [ ] Test de résilience : Arrêt d'un worker → Application toujours accessible
- [ ] Vérification des replicas : `kubectl get pods -n fleetman -o wide`
- [ ] Vérification de la persistance MongoDB : `kubectl get pv,pvc -n fleetman`

---

## 📞 Notes pour le Correcteur

1. **Temps d'initialisation** : Le premier démarrage peut prendre 2-3 minutes pour que tous les pods soient prêts.

2. **Profil Spring** : Les manifestes utilisent bien `production-microservice` (et non `local-microservice`).

3. **Image Web App** : L'image utilisée est `supinfo4kube/web-app:1.0.0` (et non `1.0.0-dockercompose`).

4. **Ordre de déploiement** : Les fichiers sont numérotés pour faciliter le déploiement dans l'ordre de dépendances.

5. **Namespace** : Toutes les ressources sont isolées dans le namespace `fleetman`.

6. **Types de services** :
   - Services internes → ClusterIP (communication inter-pods)
   - Services exposés → NodePort (accès utilisateur)

7. **Haute disponibilité** : 
   - Services critiques avec 2 replicas
   - Anti-affinity configurée pour distribution sur les nœuds
   - Health checks (liveness + readiness probes)

8. **Documentation** : Plus de 30 pages de documentation détaillée couvrant :
   - Installation complète d'un cluster (2 méthodes : kubeadm et K3s)
   - Déploiement de l'application
   - Troubleshooting
   - Architecture et diagrammes

---

**Merci pour votre évaluation ! 🙏**

En cas de problème, toutes les informations de dépannage sont disponibles dans `README.md` et `documentation-cluster-kubernetes.md`.

