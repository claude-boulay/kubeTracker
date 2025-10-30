# Projet Final Kubernetes - Fleetman Application

## Informations Générales

**Durée :** 2 semaines  
**Équipe :** 2 à 3 étudiants

## Contexte du Projet

Pour ce mini-projet, on vous donne une application distribuée permettant de suivre en temps réel une flotte de véhicules effectuant des livraisons.

### Fonctionnalités de l'Application

- Vue cartographique en temps réel des véhicules (représentés par des épingles)
- Mise à jour automatique des positions sans rafraîchissement de page
- Visualisation du trajet détaillé de chaque véhicule via sélection dans la liste

### Architecture de l'Application

Cette application distribuée est composée des éléments suivants :

- **fleetman-position-simulator** : Application Spring Boot émettant en continu des positions fictives de véhicules
- **fleetman-queue** : Queue Apache ActiveMQ qui reçoit puis transmet ces positions
- **fleetman-position-tracker** : Application Spring Boot qui consomme ces positions reçues pour les stocker dans une base de données MongoDB. Elles sont ensuite disponibles via une API RESTful
- **fleetman-mongodb** : Instance de la base de données MongoDB
- **fleetman-api-gateway** : API Gateway servant de point d'entrée pour l'application web
- **fleetman-web-app** : Application web frontend

## Fichier Docker Compose Fourni

Les développeurs de l'application vous fournissent le fichier Docker Compose qu'ils ont utilisé localement :

```yaml
services:
  fleetman-queue:
    image: supinfo4kube/queue:1.0.1
    ports:
      - 8161:8161
      - 61616:61616
    networks:
      - fleetman

  fleetman-position-simulator:
    image: supinfo4kube/position-simulator:1.0.1
    depends_on:
      - fleetman-queue
    environment:
      - SPRING_PROFILES_ACTIVE=local-microservice
    networks:
      - fleetman

  fleetman-position-tracker:
    image: supinfo4kube/position-tracker:1.0.1
    ports:
      - 30010:8080
    environment:
      - SPRING_PROFILES_ACTIVE=local-microservice
    networks:
      - fleetman

  fleetman-api-gateway:
    image: supinfo4kube/api-gateway:1.0.1
    ports:
      - 30020:8080
    environment:
      - SPRING_PROFILES_ACTIVE=local-microservice
    networks:
      - fleetman

  fleetman-webapp:
    image: supinfo4kube/web-app:1.0.0-dockercompose
    ports:
      - 30080:80
    depends_on:
      - fleetman-api-gateway
    networks:
      - fleetman

  fleetman-mongodb:
    image: mongo:3.6.23
    ports:
      - 27017:27017
    volumes:
      - mongo-data:/data/db
    networks:
      - fleetman

networks:
  fleetman:

volumes:
  mongo-data:
```

## Notes Importantes

⚠️ **Points de configuration à modifier pour Kubernetes :**

1. **Profil Spring** : Vous devrez utiliser le profil Spring `production-microservice` plutôt que `local-microservice` (à remplacer dans `SPRING_PROFILES_ACTIVE`) pour que les applications puissent communiquer entre elles une fois dans Kubernetes.

2. **Tag de l'image web-app** : On changera le tag de l'image `supinfo4kube/web-app` de `1.0.0-dockercompose` à `1.0.0` une fois dans Kubernetes.

3. **Troubleshooting** : Il se peut que les positions ne s'affichent pas dans l'interface web. Pour corriger le problème, vous pouvez redémarrer `fleetman-queue` et attendre que les positions s'affichent à nouveau.

## Travail à Réaliser

### Objectif Principal

Déployer cette application distribuée sur un cluster Kubernetes en utilisant les informations présentes dans le fichier Docker Compose.

### Étapes de Déploiement Kubernetes

1. **Créer un déploiement pour chaque conteneur**

2. **Créer un service pour chaque déploiement**  
   Vous veillerez à utiliser un service interne (ClusterIP) ou externe (NodePort/LoadBalancer) selon ce qui est le plus approprié.

3. **Configurer un volume pour la base de données**  
   Assurer la persistance des données MongoDB.

📝 *Note* : Pour des raisons de simplicité, on se contentera d'accéder directement au service web-app sans passer par un ingress controller.

### Partie Recherche : Mise en Place d'un Cluster

Ce mini-projet inclut une partie de recherche. Vous devrez déployer votre application sur un **cluster Kubernetes autre que celui de Docker Desktop ou Minikube**.

**Spécifications du cluster :**
- 1 nœud master
- 2 nœuds worker
- Options d'installation possibles : kubeadm, kops, kubespray, etc.

⚠️ Le cluster n'est pas à rendre, mais vous devrez **rédiger un document détaillant le processus de mise en place** de ce cluster.

## Livrable

Un fichier `.zip` comportant (aucun autre format ne pourra être reçu) :

1. **Vos manifestes Kubernetes** (fichiers YAML de déploiements, services, volumes, etc.)

2. **Un document texte** dans le format de votre choix (`.md`, `.docx`, ou `.pdf`) reprenant :
   - Toutes les étapes nécessaires pour bâtir votre cluster
   - Les informations que vous jugerez indispensables pour le correcteur

⚠️ Toutes les ressources sont permises, mais on ne trompera en aucun cas le correcteur avec du code qui n'est pas le vôtre.

## Barème (40 points)

| Critère | Points |
|---------|--------|
| Un déploiement et un service existent pour **fleetman-position-simulator** | 2 points |
| Un déploiement et un service existent pour **fleetman-queue** | 2 points |
| Un déploiement et un service existent pour **fleetman-position-tracker** | 2 points |
| Un déploiement et un service existent pour **fleetman-api-gateway** | 2 points |
| Un déploiement et un service existent pour **fleetman-web-app** | 2 points |
| La base de données MongoDB est présente et persistée | 7 points |
| Les composants du projet sont isolés de manière appropriée | 3 points |
| Un document prouve qu'un cluster Kubernetes a été monté | 13 points |
| Les instructions fournies sont claires et concises | 3 points |
| L'application reste disponible si l'un des deux nœuds worker est en échec | 4 points |
| **TOTAL** | **40 points** |

---

## Analyse du Projet

### Composants à Déployer

L'application Fleetman est une architecture microservices composée de 6 services :

1. **fleetman-queue** (ActiveMQ) - Service interne avec exposition pour debug
2. **fleetman-position-simulator** - Service interne (pas d'accès externe requis)
3. **fleetman-position-tracker** - Service interne avec API RESTful
4. **fleetman-mongodb** - Service interne avec PersistentVolume
5. **fleetman-api-gateway** - Service interne (point d'entrée pour le frontend)
6. **fleetman-web-app** - Service externe (NodePort pour accès utilisateur)

### Services Kubernetes Recommandés

- **ClusterIP** (internes) : position-simulator, position-tracker, mongodb, api-gateway, queue (pour communication interne)
- **NodePort** (externe) : web-app (pour accès utilisateur), optionnellement queue (pour interface admin ActiveMQ sur port 8161)

### Persistance des Données

Pour MongoDB, il faudra créer :
- Un **PersistentVolumeClaim** (PVC) pour demander du stockage
- Un **PersistentVolume** (PV) pour fournir le stockage (selon la configuration du cluster)

### Haute Disponibilité

Pour satisfaire le critère "L'application reste disponible si l'un des deux nœuds worker est en échec", il faudra :
- Définir des **replicas** appropriés dans les déploiements
- Utiliser des **PodAntiAffinity** pour distribuer les pods sur différents nœuds
- Configurer des **readinessProbe** et **livenessProbe** pour la santé des pods
