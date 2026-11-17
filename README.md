# WordPress_demo
Terraform + Ansible deployment for WordPress server on AWS EC2 instances

## Deployment steps
1) Create AWS user with programmatic access and store its credentials in `~/.aws/credentials`. User should have follow permissions:    
```
AmazonEC2FullAccess
AmazonVPCFullAccess
AmazonElasticFileSystemFullAccess
```
2) **Zero Clé SSH manuelle & Port 22 fermé à Internet (EC2 Instance Connect Endpoint) :**
   - Aucune génération manuelle de clé SSH n'est nécessaire ! Terraform génère automatiquement une paire de clés via le provider TLS pour Ansible.
   - Le port 22 est **totalement fermé à Internet** (`0.0.0.0/0`). L'accès SSH s'effectue exclusivement via un **EC2 Instance Connect Endpoint (EICE)** managé par AWS, **100% gratuit** et directement routé sur le backbone AWS privé.
   - Les instances privées n'ont pas besoin d'accès Internet pour être administrées (aucune dépendance au NAT pour la connexion).

3) Apply terraform deployment
   1) Open terraform dir
   2) Init terraform environment  
   `terraform init`
   3) Deploy terraform configuration to AWS  
   `terraform apply`

4) Provide ansible configurations
   1) Install ansible requirements

   `$ ansible-galaxy collection install -r requirements.yml`
   
   2) Open directory with ansible configurations (`cd ../ansible`)
   3) Check that `inventory.ini` file exists (généré automatiquement par Terraform avec les commandes de tunnel EICE)
   4) Execute ansible playbook with vault password `ansible`

   `$ ansible-playbook --ask-vault-password playbook.yml`

5) Se connecter aux instances en ligne de commande (100% sans clé avec AWS CLI) :
   ```bash
   aws ec2-instance-connect ssh --instance-id <INSTANCE_ID> --connection-type eice
   ```

## Requirements
0) Using Terraform create simple AWS resources (EC2 instances within custom VPC) for this deployment.
1) Using Ansible create an automated provision scenario, which deploys a highly available WordPress website.
2) Stack is - MariaDB/MySQL on a separate server, application backend(s), and Traefik as a proxy server.
3) It should be run on Amazon Linux 2023, using security best practices and EC2 Instance Connect Endpoint (EICE).
4) Avoid vendor lock-ins and be sure the scenario is flexible for deployment to any cloud provider.
5) Keep used secrets in the repository in a secure way.
6) Make sure your README tells us how to run it.

## Cloud Architecture
Cloud Architecture due to Requirement #2

![AWS Architecture](docs/WordPress_demo.drawio.svg)

## Optimisations FinOps & Free Tier (Zéro surcoût)
Cette infrastructure a été optimisée pour minimiser les coûts sur AWS et fonctionner au maximum dans le cadre du **AWS Free Tier** :
- **EC2 Instance Connect Endpoint (EICE) 100% Gratuit (0,00 €)** : Permet d'administrer toutes les instances (publiques et privées) via le réseau privé AWS sans exposer le port 22 à Internet, sans bastion payant et sans aucun coût horaire.
- **Suppression du NAT Gateway AWS managé** (~32 $/mois) et de son **Elastic IP** (~3,65 $/mois) : Le serveur `proxy` (Traefik) situé dans le subnet public assure directement le rôle de passerelle NAT économe (`iptables MASQUERADE` et `source_dest_check = false`) pour permettre aux instances privées d'installer les paquets sans surcoût.
- **Support IPv6 100% gratuit** : Le VPC active un bloc IPv6 avec une passerelle *Egress-Only Internet Gateway* (EIGW) gratuite pour la sortie Internet des instances privées.
- **Facturation des adresses IPv4 (MàJ AWS Fév 2024)** : Aucune Elastic IP persistante n'est conservée. L'IP publique du proxy est éphémère (auto-assignée) et ne génère aucun coût lorsqu'elle est libérée à l'arrêt ou à la destruction de l'infrastructure (`terraform destroy`).
- **Dimensionnement modulable** : Le nombre d'instances web est paramétrable via `var.web_instance_count` (par défaut `1` pour les tests et démos, afin de rester dans la limite des 750h/mois d'instances `t2.micro` offertes).

## Test Technique Recrutement (Évaluation Candidat)
Un kit complet d'exercice d'évaluation technique pour profil DevOps / Cloud / SRE (Confirmé à Senior) est disponible dans le fichier :
👉 **[`EXERCICE_TEST_TECHNIQUE.md`](EXERCICE_TEST_TECHNIQUE.md)**

Il comprend :
- Le guide recruteur pour créer la branche d'exercice et injecter les bugs préparés.
- L'énoncé complet pour le candidat (diagnostic de syntaxe, débogage réseau/SG, refactoring en module avec blocs `moved`, analyse FinOps).
- Le corrigé pas à pas avec code HCL et explications détaillées.
- La grille de notation sur 20 points et les questions d'entretien oral.

