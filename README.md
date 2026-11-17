# WordPress_demo
Terraform + Ansible deployment for WordPress server on AWS EC2 instances

## Deployment steps
1) Create AWS user with programmatic access and store its credentials in `~/.aws/credentials`. User should have follow permissions:    
```
AmazonEC2FullAccess
AmazonVPCFullAccess
AmazonElasticFileSystemFullAccess
IAMFullAccess (pour le profil d'instance SSM)
```
2) **Zero Clé SSH (AWS SSM Session Manager) :**
   Aucune clé SSH n'est nécessaire ! L'infrastructure utilise l'AMI officielle **Amazon Linux 2023** (`ami-0f00e1cf9df80b6ac` en `eu-west-3`) avec l'agent AWS Systems Manager (SSM) préinstallé et le rôle IAM `AmazonSSMManagedInstanceCore`. Le port 22 est totalement fermé.

3) Apply terraform deployment
   1) Open terraform dir
   2) Init terraform environment  
   `terraform init`
   3) Deploy terraform configuration to AWS  
   `terraform apply`

4) Provide ansible configurations
   1) Install ansible requirements (incluant `community.aws` pour la connexion SSM)

   `$ ansible-galaxy collection install -r requirements.yml`
   
   2) Open directory with ansible configurations (`cd ../ansible`)
   3) Check that `inventory.ini` file exists (généré automatiquement par Terraform avec les IDs d'instances et `ansible_connection = aws_ssm`)
   4) Execute ansible playbook with vault password `ansible`

   `$ ansible-playbook --ask-vault-password playbook.yml`

5) Se connecter aux instances en ligne de commande (sans clé SSH) :
   ```bash
   aws ssm start-session --target <INSTANCE_ID>
   ```

## Requirements
0) Using Terraform create simple AWS resources (EC2 instances within custom VPC) for this deployment.
1) Using Ansible create an automated provision scenario, which deploys a highly available WordPress website.
2) Stack is - MariaDB/MySQL on a separate server, application backend(s), and Traefik as a proxy server.
3) It should be run on Amazon Linux 2023, using security best practices and AWS Systems Manager (SSM).
4) Avoid vendor lock-ins and be sure the scenario is flexible for deployment to any cloud provider.
5) Keep used secrets in the repository in a secure way.
6) Make sure your README tells us how to run it.

## Cloud Architecture
Cloud Architecture due to Requirement #2

![AWS Architecture](docs/WordPress_demo.drawio.svg)

## Optimisations FinOps & Free Tier (Zéro surcoût)
Cette infrastructure a été optimisée pour minimiser les coûts sur AWS et fonctionner au maximum dans le cadre du **AWS Free Tier** :
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

