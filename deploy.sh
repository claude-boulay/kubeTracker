#!/bin/bash

##############################################################################
# Script de déploiement de l'application Fleetman sur Kubernetes
##############################################################################

set -e  # Arrêter en cas d'erreur

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Fonction pour afficher les messages
info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Fonction pour vérifier si kubectl est installé
check_kubectl() {
    if ! command -v kubectl &> /dev/null; then
        error "kubectl n'est pas installé. Veuillez l'installer avant de continuer."
        exit 1
    fi
    success "kubectl est installé"
}

# Fonction pour vérifier la connexion au cluster
check_cluster() {
    if ! kubectl cluster-info &> /dev/null; then
        error "Impossible de se connecter au cluster Kubernetes."
        error "Veuillez vérifier votre configuration kubectl."
        exit 1
    fi
    success "Connexion au cluster Kubernetes réussie"
}

# Fonction pour vérifier les nœuds
check_nodes() {
    info "Vérification des nœuds du cluster..."
    NODE_COUNT=$(kubectl get nodes --no-headers | wc -l)
    READY_COUNT=$(kubectl get nodes --no-headers | grep -c " Ready")
    
    echo "Nœuds total: $NODE_COUNT"
    echo "Nœuds Ready: $READY_COUNT"
    
    if [ "$READY_COUNT" -lt 2 ]; then
        warning "Le cluster a moins de 2 nœuds workers prêts."
        warning "La haute disponibilité peut être compromise."
    fi
    
    kubectl get nodes
}

# Fonction pour créer le répertoire de stockage
setup_storage() {
    info "Configuration du stockage pour MongoDB..."
    warning "ATTENTION: Vous devez créer le répertoire /mnt/data/mongodb sur CHAQUE worker node"
    warning "Commandes à exécuter sur chaque worker:"
    echo "  sudo mkdir -p /mnt/data/mongodb"
    echo "  sudo chmod 777 /mnt/data/mongodb"
    echo ""
    read -p "Avez-vous créé ce répertoire sur tous les workers? (o/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Oo]$ ]]; then
        error "Veuillez créer le répertoire avant de continuer."
        exit 1
    fi
    success "Configuration du stockage confirmée"
}

# Fonction pour déployer les manifestes
deploy_manifests() {
    info "Déploiement des manifestes Kubernetes..."
    
    cd k8s-manifests
    
    # Namespace
    info "Création du namespace fleetman..."
    kubectl apply -f 00-namespace.yaml
    
    # Stockage MongoDB
    info "Configuration du stockage MongoDB..."
    kubectl apply -f 01-mongodb-storage.yaml
    sleep 2
    
    # MongoDB
    info "Déploiement de MongoDB..."
    kubectl apply -f 02-mongodb-deployment.yaml
    kubectl apply -f 02-mongodb-service.yaml
    info "Attente du démarrage de MongoDB (30s)..."
    sleep 30
    
    # Queue ActiveMQ
    info "Déploiement de ActiveMQ Queue..."
    kubectl apply -f 03-queue-deployment.yaml
    kubectl apply -f 03-queue-service.yaml
    kubectl apply -f 03-queue-admin-service.yaml
    sleep 10
    
    # Position Simulator
    info "Déploiement de Position Simulator..."
    kubectl apply -f 04-position-simulator-deployment.yaml
    kubectl apply -f 04-position-simulator-service.yaml
    sleep 5
    
    # Position Tracker
    info "Déploiement de Position Tracker..."
    kubectl apply -f 05-position-tracker-deployment.yaml
    kubectl apply -f 05-position-tracker-service.yaml
    sleep 5
    
    # API Gateway
    info "Déploiement de API Gateway..."
    kubectl apply -f 06-api-gateway-deployment.yaml
    kubectl apply -f 06-api-gateway-service.yaml
    sleep 5
    
    # Web App
    info "Déploiement de Web App..."
    kubectl apply -f 07-web-app-deployment.yaml
    kubectl apply -f 07-web-app-service.yaml
    
    cd ..
    
    success "Tous les manifestes ont été déployés"
}

# Fonction pour attendre que les pods soient prêts
wait_for_pods() {
    info "Attente que tous les pods soient prêts (jusqu'à 5 minutes)..."
    
    if kubectl wait --for=condition=ready pod --all -n fleetman --timeout=300s 2>/dev/null; then
        success "Tous les pods sont prêts"
    else
        warning "Certains pods ne sont pas encore prêts. Vérification du statut..."
        kubectl get pods -n fleetman
    fi
}

# Fonction pour afficher le statut
show_status() {
    info "État du déploiement:"
    echo ""
    
    echo "=== PODS ==="
    kubectl get pods -n fleetman -o wide
    echo ""
    
    echo "=== SERVICES ==="
    kubectl get svc -n fleetman
    echo ""
    
    echo "=== PERSISTENT VOLUMES ==="
    kubectl get pv,pvc -n fleetman
    echo ""
}

# Fonction pour afficher les informations d'accès
show_access_info() {
    info "Récupération des informations d'accès..."
    
    # Récupérer les IPs des workers
    WORKER_IPS=$(kubectl get nodes -l node-role.kubernetes.io/worker -o jsonpath='{.items[*].status.addresses[?(@.type=="InternalIP")].address}')
    
    if [ -z "$WORKER_IPS" ]; then
        # Si pas de label worker, prendre tous les nœuds sauf master
        WORKER_IPS=$(kubectl get nodes -o jsonpath='{.items[?(@.metadata.name!="master")].status.addresses[?(@.type=="InternalIP")].address}')
    fi
    
    if [ -z "$WORKER_IPS" ]; then
        warning "Impossible de récupérer automatiquement les IPs des workers"
        info "Utilisez: kubectl get nodes -o wide"
    else
        FIRST_WORKER_IP=$(echo $WORKER_IPS | awk '{print $1}')
        success "Application déployée avec succès!"
        echo ""
        echo "=========================================="
        echo "  ACCÈS À L'APPLICATION"
        echo "=========================================="
        echo ""
        echo "🌐 Application Web Fleetman:"
        echo "   http://${FIRST_WORKER_IP}:30080"
        echo ""
        echo "🔧 Interface Admin ActiveMQ:"
        echo "   http://${FIRST_WORKER_IP}:30161"
        echo "   Username: admin / Password: admin"
        echo ""
        echo "📋 Worker IPs disponibles:"
        for ip in $WORKER_IPS; do
            echo "   - http://${ip}:30080"
        done
        echo ""
        echo "=========================================="
    fi
}

# Fonction pour afficher les commandes utiles
show_useful_commands() {
    echo ""
    info "Commandes utiles:"
    echo "  # Voir tous les pods"
    echo "  kubectl get pods -n fleetman"
    echo ""
    echo "  # Voir les logs d'un pod"
    echo "  kubectl logs -n fleetman <nom-du-pod>"
    echo ""
    echo "  # Redémarrer la queue (si les positions ne s'affichent pas)"
    echo "  kubectl rollout restart deployment fleetman-queue -n fleetman"
    echo ""
    echo "  # Supprimer l'application"
    echo "  kubectl delete namespace fleetman"
    echo ""
}

# Fonction principale
main() {
    echo ""
    echo "=========================================="
    echo "  DÉPLOIEMENT FLEETMAN SUR KUBERNETES"
    echo "=========================================="
    echo ""
    
    # Vérifications préalables
    check_kubectl
    check_cluster
    check_nodes
    echo ""
    
    # Configuration du stockage
    setup_storage
    echo ""
    
    # Déploiement
    deploy_manifests
    echo ""
    
    # Attendre que les pods soient prêts
    wait_for_pods
    echo ""
    
    # Afficher le statut
    show_status
    
    # Afficher les informations d'accès
    show_access_info
    
    # Afficher les commandes utiles
    show_useful_commands
    
    echo ""
    success "Déploiement terminé! 🚀"
    echo ""
}

# Point d'entrée
main "$@"

