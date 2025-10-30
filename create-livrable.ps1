# Script PowerShell pour créer le livrable sur Windows

$ArchiveName = "ProjetFinal-Fleetman-Kubernetes.zip"
$TempDir = "livrable-temp"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  CRÉATION DU LIVRABLE" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# Supprimer l'ancienne archive si elle existe
if (Test-Path $ArchiveName) {
    Remove-Item $ArchiveName -Force
}

# Supprimer le répertoire temporaire s'il existe
if (Test-Path $TempDir) {
    Remove-Item $TempDir -Recurse -Force
}

# Créer un répertoire temporaire
Write-Host "[1/4] Création du répertoire temporaire..." -ForegroundColor Yellow
New-Item -ItemType Directory -Path "$TempDir\ProjetFinal" -Force | Out-Null

# Copier les fichiers nécessaires
Write-Host "[2/4] Copie des fichiers..." -ForegroundColor Yellow

# Manifestes Kubernetes
Copy-Item -Path "k8s-manifests" -Destination "$TempDir\ProjetFinal\" -Recurse -Force

# Documentation
Copy-Item -Path "documentation-cluster-kubernetes.md" -Destination "$TempDir\ProjetFinal\" -Force
Copy-Item -Path "README.md" -Destination "$TempDir\ProjetFinal\" -Force
Copy-Item -Path "INSTRUCTIONS.md" -Destination "$TempDir\ProjetFinal\" -Force

# Scripts
Copy-Item -Path "deploy.sh" -Destination "$TempDir\ProjetFinal\" -Force
Copy-Item -Path "undeploy.sh" -Destination "$TempDir\ProjetFinal\" -Force

# Sujet (optionnel)
if (Test-Path "sujet.md") {
    Copy-Item -Path "sujet.md" -Destination "$TempDir\ProjetFinal\" -Force
}

# Créer l'archive ZIP
Write-Host "[3/4] Création de l'archive ZIP..." -ForegroundColor Yellow
Compress-Archive -Path "$TempDir\ProjetFinal" -DestinationPath $ArchiveName -Force

# Nettoyer
Write-Host "[4/4] Nettoyage..." -ForegroundColor Yellow
Remove-Item $TempDir -Recurse -Force

# Vérifier le résultat
if (Test-Path $ArchiveName) {
    $Size = [math]::Round((Get-Item $ArchiveName).Length / 1KB, 2)
    Write-Host ""
    Write-Host "==========================================" -ForegroundColor Green
    Write-Host "  LIVRABLE CREE AVEC SUCCES" -ForegroundColor Green
    Write-Host "==========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Fichier : $ArchiveName" -ForegroundColor Cyan
    Write-Host "Taille  : $Size KB" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Contenu :" -ForegroundColor White
    Write-Host "  - Manifestes Kubernetes (8 fichiers)" -ForegroundColor Green
    Write-Host "  - Documentation cluster (30+ pages)" -ForegroundColor Green
    Write-Host "  - README complet" -ForegroundColor Green
    Write-Host "  - Instructions pour le correcteur" -ForegroundColor Green
    Write-Host "  - Scripts de deploiement" -ForegroundColor Green
    Write-Host ""
    Write-Host "Vous pouvez maintenant soumettre : $ArchiveName" -ForegroundColor Yellow
    Write-Host ""
} else {
    Write-Host ""
    Write-Host "ERREUR : Impossible de creer l'archive" -ForegroundColor Red
    exit 1
}

