# Projet Kubernetes - Application Fleetman

Déploiement d'une application distribuée de suivi de flotte de véhicules sur Kubernetes.

## 📋 Table des Matières

- [Vue d'ensemble](#vue-densemble)
- [Prérequis](#prérequis)
- [Architecture](#architecture)
- [Installation rapide](#installation-rapide)
- [Déploiement détaillé](#déploiement-détaillé)
- [Vérification](#vérification)
- [Accès à l'application](#accès-à-lapplication)
- [Maintenance](#maintenance)
- [Dépannage](#dépannage)

---

## 🎯 Vue d'ensemble

Cette application permet de suivre en temps réel une flotte de véhicules effectuant des livraisons. Elle est composée de 6 microservices déployés sur Kubernetes :

- **fleetman-position-simulator** : Génère des positions fictives de véhicules
- **fleetman-queue** : Queue ActiveMQ pour le messaging
- **fleetman-position-tracker** : API RESTful pour gérer les positions
- **fleetman-mongodb** : Base de données pour la persistance
- **fleetman-api-gateway** : Point d'entrée pour l'application web
- **fleetman-web-app** : Interface web pour visualiser les véhicules

---

## 📦 Prérequis

### Cluster Kubernetes

- **Kubernetes** : v1.24 ou supérieur
- **Nœuds** : 1 master + 2 workers (minimum)
- **kubectl** : Installé et configuré

### Ressources minimales

- **CPU total** : 4 cores
- **RAM totale** : 8 GB
- **Stockage** : 20 GB disponibles

### Vérification

```bash
# Vérifier la version de Kubernetes
kubectl version --short

# Vérifier les nœuds
kubectl get nodes

# Vérifier les ressources disponibles
kubectl top nodes
```

---

## 🏗️ Architecture

### Composants déployés

| Service | Type | Replicas | Port | Accès |
|---------|------|----------|------|-------|
| fleetman-queue | ClusterIP + NodePort | 1 | 61616, 8161 | Interne + Admin (30161) |
| fleetman-position-simulator | ClusterIP | 1 | 8080 | Interne |
| fleetman-position-tracker | ClusterIP | 2 | 8080 | Interne |
| fleetman-mongodb | ClusterIP | 1 | 27017 | Interne |
| fleetman-api-gateway | ClusterIP | 2 | 8080 | Interne |
| fleetman-web-app | NodePort | 2 | 80 | Externe (30080) |

### Flux de données

```
Position Simulator → ActiveMQ Queue → Position Tracker → MongoDB
                                              ↓
                            API Gateway ← MongoDB
                                  ↓
                              Web App
```

### Haute disponibilité

- **Replicas multiples** : Les services critiques (web-app, api-gateway, position-tracker) ont 2 replicas
- **Anti-affinity** : Les pods sont distribués sur différents nœuds workers
- **Probes** : Liveness et Readiness probes configurées pour tous les services

---

## ⚡ Installation Rapide

### Option 1 : Déploiement complet

```bash
# 1. Cloner ou extraire le projet
cd ProjetFinal

# 2. Créer le répertoire de stockage sur CHAQUE worker
# Sur worker-1 et worker-2 :
sudo mkdir -p /mnt/data/mongodb
sudo chmod 777 /mnt/data/mongodb

# 3. Déployer tous les manifestes
kubectl apply -f k8s-manifests/

# 4. Attendre que tous les pods soient prêts
kubectl wait --for=condition=ready pod --all -n fleetman --timeout=5m

# 5. Accéder à l'application
kubectl get nodes -o wide
# Ouvrir http://<WORKER_IP>:30080 dans le navigateur
```

### Option 2 : Déploiement pas à pas

```bash
# Déployer dans l'ordre
kubectl apply -f k8s-manifests/00-namespace.yaml
kubectl apply -f k8s-manifests/01-mongodb-storage.yaml
kubectl apply -f k8s-manifests/02-mongodb-deployment.yaml
kubectl apply -f k8s-manifests/02-mongodb-service.yaml
kubectl apply -f k8s-manifests/03-queue-deployment.yaml
kubectl apply -f k8s-manifests/03-queue-service.yaml
kubectl apply -f k8s-manifests/03-queue-admin-service.yaml
kubectl apply -f k8s-manifests/04-position-simulator-deployment.yaml
kubectl apply -f k8s-manifests/04-position-simulator-service.yaml
kubectl apply -f k8s-manifests/05-position-tracker-deployment.yaml
kubectl apply -f k8s-manifests/05-position-tracker-service.yaml
kubectl apply -f k8s-manifests/06-api-gateway-deployment.yaml
kubectl apply -f k8s-manifests/06-api-gateway-service.yaml
kubectl apply -f k8s-manifests/07-web-app-deployment.yaml
kubectl apply -f k8s-manifests/07-web-app-service.yaml
```

---

## 📖 Déploiement Détaillé

### Étape 1 : Préparation du stockage

Le service MongoDB nécessite un stockage persistant. Sur **chaque nœud worker**, créer le répertoire :

```bash
# Se connecter sur worker-1
ssh user@worker-1
sudo mkdir -p /mnt/data/mongodb
sudo chmod 777 /mnt/data/mongodb
exit

# Se connecter sur worker-2
ssh user@worker-2
sudo mkdir -p /mnt/data/mongodb
sudo chmod 777 /mnt/data/mongodb
exit
```

### Étape 2 : Créer le namespace

```bash
kubectl apply -f k8s-manifests/00-namespace.yaml

# Vérifier
kubectl get namespaces
```

### Étape 3 : Déployer le stockage MongoDB

```bash
kubectl apply -f k8s-manifests/01-mongodb-storage.yaml

# Vérifier
kubectl get pv
kubectl get pvc -n fleetman
```

Le PVC doit être en état `Bound`.

### Étape 4 : Déployer MongoDB

```bash
kubectl apply -f k8s-manifests/02-mongodb-deployment.yaml
kubectl apply -f k8s-manifests/02-mongodb-service.yaml

# Vérifier
kubectl get pods -n fleetman -l app=fleetman-mongodb
kubectl get svc -n fleetman fleetman-mongodb
```

Attendre que le pod MongoDB soit `Running` avant de continuer.

### Étape 5 : Déployer ActiveMQ Queue

```bash
kubectl apply -f k8s-manifests/03-queue-deployment.yaml
kubectl apply -f k8s-manifests/03-queue-service.yaml
kubectl apply -f k8s-manifests/03-queue-admin-service.yaml

# Vérifier
kubectl get pods -n fleetman -l app=fleetman-queue
kubectl get svc -n fleetman | grep queue
```

### Étape 6 : Déployer Position Simulator

```bash
kubectl apply -f k8s-manifests/04-position-simulator-deployment.yaml
kubectl apply -f k8s-manifests/04-position-simulator-service.yaml

# Vérifier
kubectl get pods -n fleetman -l app=fleetman-position-simulator
```

### Étape 7 : Déployer Position Tracker

```bash
kubectl apply -f k8s-manifests/05-position-tracker-deployment.yaml
kubectl apply -f k8s-manifests/05-position-tracker-service.yaml

# Vérifier
kubectl get pods -n fleetman -l app=fleetman-position-tracker
```

Ce service a 2 replicas pour la haute disponibilité.

### Étape 8 : Déployer API Gateway

```bash
kubectl apply -f k8s-manifests/06-api-gateway-deployment.yaml
kubectl apply -f k8s-manifests/06-api-gateway-service.yaml

# Vérifier
kubectl get pods -n fleetman -l app=fleetman-api-gateway
```

### Étape 9 : Déployer Web App

```bash
kubectl apply -f k8s-manifests/07-web-app-deployment.yaml
kubectl apply -f k8s-manifests/07-web-app-service.yaml

# Vérifier
kubectl get pods -n fleetman -l app=fleetman-web-app
kubectl get svc -n fleetman fleetman-web-app
```

---

## ✅ Vérification

### Vérifier tous les pods

```bash
kubectl get pods -n fleetman

# Tous les pods doivent être en état Running
# Résultat attendu :
# NAME                                          READY   STATUS    RESTARTS   AGE
# fleetman-api-gateway-xxxxx                    1/1     Running   0          2m
# fleetman-api-gateway-yyyyy                    1/1     Running   0          2m
# fleetman-mongodb-xxxxx                        1/1     Running   0          5m
# fleetman-position-simulator-xxxxx             1/1     Running   0          3m
# fleetman-position-tracker-xxxxx               1/1     Running   0          3m
# fleetman-position-tracker-yyyyy               1/1     Running   0          3m
# fleetman-queue-xxxxx                          1/1     Running   0          4m
# fleetman-web-app-xxxxx                        1/1     Running   0          1m
# fleetman-web-app-yyyyy                        1/1     Running   0          1m
```

### Vérifier tous les services

```bash
kubectl get svc -n fleetman

# Résultat attendu :
# NAME                        TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)
# fleetman-api-gateway        ClusterIP   10.96.xxx.xxx    <none>        8080/TCP
# fleetman-mongodb            ClusterIP   10.96.xxx.xxx    <none>        27017/TCP
# fleetman-position-simulator ClusterIP   10.96.xxx.xxx    <none>        8080/TCP
# fleetman-position-tracker   ClusterIP   10.96.xxx.xxx    <none>        8080/TCP
# fleetman-queue              ClusterIP   10.96.xxx.xxx    <none>        61616/TCP,8161/TCP
# fleetman-queue-admin        NodePort    10.96.xxx.xxx    <none>        8161:30161/TCP
# fleetman-web-app            NodePort    10.96.xxx.xxx    <none>        80:30080/TCP
```

### Vérifier la distribution des pods

```bash
kubectl get pods -n fleetman -o wide

# Les pods avec replicas multiples doivent être sur des nœuds différents
```

### Vérifier les logs

```bash
# Logs de la queue
kubectl logs -n fleetman -l app=fleetman-queue

# Logs du position tracker
kubectl logs -n fleetman -l app=fleetman-position-tracker

# Logs de l'API gateway
kubectl logs -n fleetman -l app=fleetman-api-gateway
```

Si des erreurs apparaissent, consultez la section [Dépannage](#dépannage).

---

## 🌐 Accès à l'Application

### Application Web Fleetman

1. Récupérer l'IP d'un nœud worker :

```bash
kubectl get nodes -o wide
# Noter la INTERNAL-IP ou EXTERNAL-IP d'un worker
```

2. Ouvrir dans un navigateur :

```
http://<WORKER_IP>:30080
```

Vous devriez voir :
- Une carte avec des épingles représentant les véhicules
- Une liste de véhicules sur la droite
- Les positions se mettent à jour automatiquement

### Interface Admin ActiveMQ (optionnel)

Pour accéder à l'interface d'administration ActiveMQ :

```
http://<WORKER_IP>:30161
```

Identifiants par défaut :
- **Username** : admin
- **Password** : admin

### Accès depuis kubectl port-forward (alternative)

Si les NodePort ne fonctionnent pas, utiliser port-forward :

```bash
# Web App
kubectl port-forward -n fleetman svc/fleetman-web-app 8080:80

# Accéder à http://localhost:8080
```

---

## 🔧 Maintenance

### Scaler les déploiements

```bash
# Augmenter le nombre de replicas du web-app
kubectl scale deployment fleetman-web-app -n fleetman --replicas=3

# Vérifier
kubectl get pods -n fleetman -l app=fleetman-web-app
```

### Redémarrer un service

```bash
# Redémarrer la queue (utile si les positions ne s'affichent pas)
kubectl rollout restart deployment fleetman-queue -n fleetman

# Suivre le redémarrage
kubectl rollout status deployment fleetman-queue -n fleetman
```

### Mettre à jour une image

```bash
# Exemple : mettre à jour le web-app
kubectl set image deployment/fleetman-web-app \
  web-app=supinfo4kube/web-app:1.0.1 \
  -n fleetman

# Suivre la mise à jour
kubectl rollout status deployment fleetman-web-app -n fleetman
```

### Voir les événements

```bash
# Tous les événements du namespace
kubectl get events -n fleetman --sort-by='.lastTimestamp'

# Événements d'un pod spécifique
kubectl describe pod <nom-du-pod> -n fleetman
```

---

## 🐛 Dépannage

### Problème : Les pods restent en Pending

**Causes possibles :**
- Ressources insuffisantes sur les nœuds
- PersistentVolume non disponible

**Solutions :**

```bash
# Vérifier les ressources
kubectl describe pod <nom-du-pod> -n fleetman
kubectl top nodes

# Vérifier le PV
kubectl get pv
kubectl describe pv mongodb-pv
```

### Problème : MongoDB ne démarre pas

**Solution :**

```bash
# Vérifier que le répertoire existe sur les workers
kubectl get pods -n fleetman -l app=fleetman-mongodb -o wide
# Noter sur quel nœud le pod est planifié

# Se connecter au nœud et vérifier
ssh user@<node>
ls -la /mnt/data/mongodb
sudo chown -R 999:999 /mnt/data/mongodb  # UID de MongoDB
```

### Problème : Les positions ne s'affichent pas

**Solutions :**

```bash
# 1. Redémarrer la queue
kubectl rollout restart deployment fleetman-queue -n fleetman

# 2. Vérifier les logs
kubectl logs -n fleetman -l app=fleetman-position-simulator
kubectl logs -n fleetman -l app=fleetman-position-tracker

# 3. Vérifier la connectivité entre les services
kubectl run -it --rm debug --image=busybox --restart=Never -n fleetman -- sh
# Dans le pod :
wget -O- http://fleetman-queue:61616
wget -O- http://fleetman-api-gateway:8080
```

### Problème : Impossible d'accéder au web-app via NodePort

**Solutions :**

```bash
# Vérifier le service
kubectl get svc -n fleetman fleetman-web-app

# Vérifier les règles de firewall
# Sur chaque worker :
sudo ufw status
sudo ufw allow 30080/tcp
sudo ufw allow 30161/tcp

# Vérifier que kube-proxy fonctionne
kubectl get pods -n kube-system | grep kube-proxy
```

### Problème : L'application ne résiste pas à la panne d'un worker

**Vérifications :**

```bash
# Vérifier que les pods ont plusieurs replicas
kubectl get deployments -n fleetman

# Vérifier la distribution des pods
kubectl get pods -n fleetman -o wide

# Vérifier l'anti-affinity
kubectl describe pod <nom-du-pod> -n fleetman | grep -A 10 "Affinity"
```

### Commandes de diagnostic

```bash
# Obtenir des informations complètes sur un pod
kubectl describe pod <nom-du-pod> -n fleetman

# Accéder à un pod pour déboguer
kubectl exec -it <nom-du-pod> -n fleetman -- /bin/sh

# Voir l'utilisation des ressources
kubectl top pods -n fleetman

# Dump de la configuration
kubectl get all -n fleetman -o yaml > fleetman-dump.yaml
```

---

## 🧹 Nettoyage

### Supprimer l'application

```bash
# Supprimer tous les ressources
kubectl delete -f k8s-manifests/

# Ou supprimer le namespace (supprime tout)
kubectl delete namespace fleetman

# Supprimer le PersistentVolume
kubectl delete pv mongodb-pv
```

### Nettoyer les données sur les workers

```bash
# Sur chaque worker
ssh user@worker
sudo rm -rf /mnt/data/mongodb
```

---

## 📊 Test de Résilience

### Test de défaillance d'un nœud

```bash
# 1. Noter la distribution initiale des pods
kubectl get pods -n fleetman -o wide

# 2. Simuler une panne en stoppant kubelet sur worker-1
# Sur worker-1 :
sudo systemctl stop kubelet

# 3. Observer la migration des pods (attendre ~5 minutes)
kubectl get pods -n fleetman -o wide --watch

# 4. Vérifier que l'application reste accessible
curl http://<WORKER_2_IP>:30080

# 5. Redémarrer le worker
# Sur worker-1 :
sudo systemctl start kubelet

# 6. Vérifier que tout revient à la normale
kubectl get pods -n fleetman -o wide
```

---

## 📚 Documentation Complémentaire

- **Documentation du cluster** : Voir `documentation-cluster-kubernetes.md` pour la mise en place du cluster
- **Sujet du projet** : Voir `sujet.md` pour les détails du projet
- **Manifestes Kubernetes** : Tous les fichiers YAML sont dans `k8s-manifests/`

---

## 🎓 Points d'Évaluation

### Checklist de validation (40 points)

- [x] **Déploiement position-simulator** (2 pts) - Fichiers `04-position-simulator-deployment.yaml`, `04-position-simulator-service.yaml`
- [x] **Déploiement queue** (2 pts) - Fichiers `03-queue-deployment.yaml`, `03-queue-service.yaml`, `03-queue-admin-service.yaml`
- [x] **Déploiement position-tracker** (2 pts) - Fichiers `05-position-tracker-deployment.yaml`, `05-position-tracker-service.yaml`
- [x] **Déploiement api-gateway** (2 pts) - Fichiers `06-api-gateway-deployment.yaml`, `06-api-gateway-service.yaml`
- [x] **Déploiement web-app** (2 pts) - Fichiers `07-web-app-deployment.yaml`, `07-web-app-service.yaml`
- [x] **MongoDB persisté** (7 pts) - Fichiers `01-mongodb-storage.yaml`, `02-mongodb-deployment.yaml`, `02-mongodb-service.yaml`
- [x] **Isolation appropriée** (3 pts) - Namespace dédié + services ClusterIP/NodePort appropriés
- [x] **Documentation cluster** (13 pts) - Fichier `documentation-cluster-kubernetes.md`
- [x] **Instructions claires** (3 pts) - Ce fichier README.md
- [x] **Résilience worker** (4 pts) - Replicas + Anti-affinity configurés

**Total : 40 points**

---

## 📝 Notes

- Cette application a été déployée et testée sur un cluster Kubernetes 1.28
- Les manifestes sont numérotés pour faciliter le déploiement dans l'ordre
- Les services utilisent `production-microservice` comme profil Spring
- L'image du web-app est `1.0.0` (et non `1.0.0-dockercompose`)
- La haute disponibilité est assurée par des replicas multiples et l'anti-affinity

---

## 👥 Auteurs

Projet réalisé dans le cadre du cours Kubernetes - SupInfo 4ème année

---

## 📞 Support

En cas de problème :
1. Consulter la section [Dépannage](#dépannage)
2. Vérifier les logs : `kubectl logs -n fleetman <nom-du-pod>`
3. Consulter la documentation complète : `documentation-cluster-kubernetes.md`

---

**Bon déploiement ! 🚀**

