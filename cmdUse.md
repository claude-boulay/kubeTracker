git clone https://github.com/claude-boulay/kubeTracker.git
cd k8s-manifests
//namespace
kubectl apply -f .\00-namespace.yaml 
//PV et PVC
kubectl apply -f .\01-mongodb-storage.yaml 
//déploiement
kubectl apply -f .\02-mongodb-deployment.yaml 
kubectl apply -f .\03-queue-deployment.yaml 
kubectl apply -f .\04-position-simulator-deployment.yaml
kubectl apply -f .\05-position-tracker-deployment.yaml
kubectl apply -f .\06-api-gateway-deployment.yaml
kubectl apply -f .\07-web-app-deployment.yaml
//service
kubectl apply -f .\02-mongodb-service.yaml //service de la base de donnée
kubectl apply -f .\03-queue-admin-service.yaml // à vérifier si nécéssaire
kubectl apply -f .\03-queue-service.yaml
kubectl apply -f .\04-position-simulator-service.yaml 
kubectl apply -f .\05-position-tracker-service.yaml
kubectl apply -f .\06-api-gateway-service.yaml
kubectl apply -f .\07-web-app-service.yaml
kubectl apply -f .\08-ForwardServer.yaml
