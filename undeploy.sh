#!/bin/bash

##############################################################################
# Script de suppression de l'application Fleetman de Kubernetes
##############################################################################

set -e

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

echo ""
echo "=========================================="
echo "  SUPPRESSION DE L'APPLICATION FLEETMAN"
echo "=========================================="
echo ""

warning "Cette action va supprimer:"
echo "  - Tous les pods de l'application"
echo "  - Tous les services"
echo "  - Le namespace fleetman"
echo "  - Le PersistentVolume MongoDB"
echo ""
warning "Les données MongoDB seront supprimées!"
echo ""

read -p "Êtes-vous sûr de vouloir continuer? (o/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Oo]$ ]]; then
    info "Annulation de la suppression"
    exit 0
fi

echo ""
info "Suppression de l'application Fleetman..."

# Supprimer le namespace (supprime tous les pods, services, etc.)
info "Suppression du namespace fleetman..."
kubectl delete namespace fleetman --timeout=60s || warning "Le namespace n'existe pas ou a déjà été supprimé"

# Supprimer le PersistentVolume
info "Suppression du PersistentVolume MongoDB..."
kubectl delete pv mongodb-pv --timeout=30s || warning "Le PV n'existe pas ou a déjà été supprimé"

success "Application supprimée avec succès!"

echo ""
warning "N'oubliez pas de nettoyer les données sur les workers:"
echo "  Sur chaque worker, exécuter:"
echo "  sudo rm -rf /mnt/data/mongodb"
echo ""

info "Pour re-déployer l'application:"
echo "  ./deploy.sh"
echo ""

