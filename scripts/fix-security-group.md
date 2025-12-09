# Fix Security Group - Guide étape par étape

## Problème
`ERR_CONNECTION_TIMED_OUT` signifie que votre Security Group AWS bloque probablement le trafic entrant.

## Solution : Configurer le Security Group

### Étape 1 : Accéder au Security Group
1. Connectez-vous à la console AWS : https://console.aws.amazon.com
2. Allez dans **EC2** → **Instances**
3. Sélectionnez votre instance : `ec2-15-237-118-159.eu-west-3.compute.amazonaws.com`
4. Dans l'onglet **Security**, cliquez sur le **Security Group ID** (sg-xxxxxxxxx)

### Étape 2 : Modifier les règles entrantes (Inbound Rules)
1. Cliquez sur l'onglet **Inbound rules**
2. Cliquez sur **Edit inbound rules**
3. Ajoutez les règles suivantes :

#### Règle 1 : SSH (si pas déjà présent)
- **Type:** SSH
- **Protocol:** TCP
- **Port Range:** 22
- **Source:** My IP (ou 0.0.0.0/0 pour accès depuis n'importe où)

#### Règle 2 : HTTP (Nginx)
- **Type:** HTTP
- **Protocol:** TCP
- **Port Range:** 80
- **Source:** 0.0.0.0/0
- **Description:** Allow HTTP traffic

#### Règle 3 : FastAPI Direct
- **Type:** Custom TCP
- **Protocol:** TCP
- **Port Range:** 8000
- **Source:** 0.0.0.0/0
- **Description:** Allow FastAPI direct access

4. Cliquez sur **Save rules**

### Configuration finale attendue :
```
Type          Protocol  Port Range  Source        Description
-----------   --------  ----------  ------------  -----------------------
SSH           TCP       22          0.0.0.0/0     SSH access
HTTP          TCP       80          0.0.0.0/0     Allow HTTP traffic
Custom TCP    TCP       8000        0.0.0.0/0     Allow FastAPI direct
```

## Vérification après modification

### 1. Depuis votre terminal local (Windows PowerShell)
Testez la connectivité :

```powershell
# Test ping (peut ne pas fonctionner si ICMP est bloqué)
Test-NetConnection -ComputerName ec2-15-237-118-159.eu-west-3.compute.amazonaws.com -Port 80

# Test port 8000
Test-NetConnection -ComputerName ec2-15-237-118-159.eu-west-3.compute.amazonaws.com -Port 8000
```

### 2. Depuis votre navigateur
Essayez d'accéder à :
- http://ec2-15-237-118-159.eu-west-3.compute.amazonaws.com (port 80)
- http://ec2-15-237-118-159.eu-west-3.compute.amazonaws.com:8000 (port 8000)

### 3. Depuis SSH sur l'instance EC2
Connectez-vous et exécutez le diagnostic :

```bash
cd /home/ubuntu
chmod +x diagnose-ec2.sh
./diagnose-ec2.sh
```

## Autres vérifications importantes

### Network ACL
Si le problème persiste :
1. Allez dans **VPC** → **Network ACLs**
2. Vérifiez que les règles entrantes et sortantes autorisent le trafic HTTP (80) et 8000

### Instance Status
Vérifiez que votre instance :
- État : **running** (vert)
- Status checks : **2/2 checks passed**

## Si l'application n'est pas encore déployée

Connectez-vous en SSH et déployez :

```bash
# Connexion SSH
ssh -i "votre-cle.pem" ubuntu@ec2-15-237-118-159.eu-west-3.compute.amazonaws.com

# Setup initial (première fois seulement)
cd /home/ubuntu
sudo chmod +x setup-ec2.sh
sudo ./setup-ec2.sh

# Cloner votre repository
git clone https://github.com/dousicap/cicdgenaitest.git app
cd app

# Déployer l'application
chmod +x scripts/deploy.sh
./scripts/deploy.sh
```

## Commandes de dépannage

```bash
# Vérifier le service
sudo systemctl status fastapi-app

# Redémarrer le service
sudo systemctl restart fastapi-app

# Voir les logs
sudo journalctl -u fastapi-app -f

# Tester localement
curl http://localhost:8000
curl http://localhost:80
```

## Contacts et ressources
- Documentation AWS Security Groups : https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/security-groups.html
- Region utilisée : eu-west-3 (Paris)
