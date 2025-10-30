#!/bin/bash

##############################################################################
# Script de création du livrable final pour le projet Kubernetes
##############################################################################

ARCHIVE_NAME="ProjetFinal-Fleetman-Kubernetes.zip"
TEMP_DIR="livrable-temp"

echo "=========================================="
echo "  CRÉATION DU LIVRABLE"
echo "=========================================="
echo ""

# Créer un répertoire temporaire
echo "[1/4] Création du répertoire temporaire..."
rm -rf $TEMP_DIR
mkdir -p $TEMP_DIR/ProjetFinal

# Copier les fichiers nécessaires
echo "[2/4] Copie des fichiers..."

# Manifestes Kubernetes
cp -r k8s-manifests $TEMP_DIR/ProjetFinal/

# Documentation
cp documentation-cluster-kubernetes.md $TEMP_DIR/ProjetFinal/
cp README.md $TEMP_DIR/ProjetFinal/
cp INSTRUCTIONS.md $TEMP_DIR/ProjetFinal/

# Scripts
cp deploy.sh $TEMP_DIR/ProjetFinal/
cp undeploy.sh $TEMP_DIR/ProjetFinal/

# Sujet (optionnel)
cp sujet.md $TEMP_DIR/ProjetFinal/

# Créer l'archive
echo "[3/4] Création de l'archive ZIP..."
cd $TEMP_DIR
zip -r ../$ARCHIVE_NAME ProjetFinal/ > /dev/null 2>&1
cd ..

# Nettoyer
echo "[4/4] Nettoyage..."
rm -rf $TEMP_DIR

# Vérifier le résultat
if [ -f $ARCHIVE_NAME ]; then
    SIZE=$(du -h $ARCHIVE_NAME | cut -f1)
    echo ""
    echo "=========================================="
    echo "  ✅ LIVRABLE CRÉÉ AVEC SUCCÈS"
    echo "=========================================="
    echo ""
    echo "Fichier : $ARCHIVE_NAME"
    echo "Taille  : $SIZE"
    echo ""
    echo "Contenu :"
    echo "  ✓ Manifestes Kubernetes (8 fichiers)"
    echo "  ✓ Documentation cluster (30+ pages)"
    echo "  ✓ README complet"
    echo "  ✓ Instructions pour le correcteur"
    echo "  ✓ Scripts de déploiement"
    echo ""
    echo "Vous pouvez maintenant soumettre : $ARCHIVE_NAME"
    echo ""
else
    echo ""
    echo "❌ ERREUR : Impossible de créer l'archive"
    exit 1
fi

