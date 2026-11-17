# Test Technique Candidat : Audit, Débogage & Modularisation Terraform / AWS

Ce document constitue le kit complet pour faire passer un test technique d'évaluation à un candidat DevOps / Cloud / SRE (niveaux Confirmé à Senior) à partir de ce dépôt d'infrastructure WordPress sur AWS.

---

## Sommaire
1. [Fiche Synthétique du Test](#1-fiche-synthétique-du-test)
2. [Guide du Recruteur : Mise en place de la branche Candidat](#2-guide-du-recruteur--mise-en-place-de-la-branche-candidat)
3. [Énoncé du Test (à transmettre au Candidat)](#3-énoncé-du-test-à-transmettre-au-candidat)
4. [Corrigé Détaillé & Réponses Attendues](#4-corrigé-détaillé--réponses-attendues)
   - [Défi 1 : Débogage Syntaxique](#défi-1--débogage-syntaxique)
   - [Défi 2 : Débogage Réseau, Sécurité & Fonctionnel](#défi-2--débogage-réseau-sécurité--fonctionnel)
   - [Défi 3 : Modularisation & Blocs `moved`](#défi-3--modularisation--blocs-moved-le-point-clé)
   - [Défi 4 : FinOps & Architecture Zero-Cost / Gratuité](#défi-4--finops--architecture-zero-cost--gratuité)
5. [Grille d'Évaluation & Barème de Notation](#5-grille-dévaluation--barème-de-notation)
6. [Questions d'Approfondissement pour l'Entretien Oral](#6-questions-dapprofondissement-pour-lentretien-oral)

---

## 1. Fiche Synthétique du Test

| Paramètre | Valeur |
| :--- | :--- |
| **Intitulé** | Test Technique Terraform & AWS Cloud Architecture |
| **Rôle ciblé** | Ingénieur DevOps / Cloud Engineer / SRE (Confirmé à Senior) |
| **Durée recommandée** | 1h30 à 2h00 (ou exercice asynchrone sur 24-48h) |
| **Technologies évaluées** | Terraform (HCL, State Management, Modules, `moved`), AWS (VPC, Subnets, Routing, SG, EC2, EFS), FinOps, Git |
| **Objectif Principal** | Évaluer la méthodologie de débogage, la rigueur d'organisation, la maîtrise des subtilités d'état Terraform (`moved`) et la sensibilité aux coûts cloud (FinOps). |

---

## 2. Guide du Recruteur : Mise en place de la branche Candidat

Pour faire passer le test à un candidat sans toucher à votre branche principale `main` (qui contient la version saine et optimisée) :

### Étape 1 : Créer la branche du test
```bash
git checkout -b test-candidat
```

### Étape 2 : Injecter les bugs préparés
Pour injecter rapidement les bugs dans la branche `test-candidat`, appliquez les modifications suivantes :

1. **Dans `terraform/instances.tf` :**
   - Introduire une faute de frappe sur une variable : remplacer `var.ami_image` par `var.ami_imge` sur l'instance `proxy`.
   - Casser la syntaxe HCL : supprimer l'accolade fermante `}` à la fin du bloc `resource "aws_instance" "db"`.
   - Casser la référence à la ressource : remplacer `key_name = aws_key_pair.wp_key.key_name` par `key_name = aws_key_pair.wp_key.name` (attribut inexistant).

2. **Dans `terraform/vpc.tf` :**
   - **Bug réseau sortant (NAT)** : Dans la table de routage privée `aws_default_route_table.private`, supprimer la route vers la passerelle NAT ou mettre `cidr_block = "10.0.0.0/8"` au lieu de `"0.0.0.0/0"`. (Empêche `dnf` de télécharger les paquets sur web et db).
   - **Bug Security Group DB** : Dans `aws_security_group.wordpress_db`, changer la règle MySQL 3306 pour autoriser `aws_subnet.wordpress_public.cidr_block` au lieu de `wordpress_private` ou `wordpress_web`. (Empêche WordPress de contacter la BDD).
   - **Attribut déprécié** : Ajouter une ressource EIP avec `vpc = true` (syntaxe dépréciée dans AWS provider v5).

3. **Créer le fichier `EXERCICE.md`** à la racine de la branche en copiant la **Section 3** de ce document.

4. **Committer sur la branche :**
```bash
git add terraform/ EXERCICE.md
git commit -m "feat: initial test candidate setup"
git push origin test-candidat
```

---

## 3. Énoncé du Test (à transmettre au Candidat)

> *Ce bloc peut être copié tel quel dans un fichier `EXERCICE.md` sur la branche remise au candidat.*

```markdown
# Test Technique DevOps / Terraform : Audit, Débogage & Refactoring

Bienvenue dans ce test technique !

## Contexte
Vous intégrez notre équipe technique. Un précédent prestataire a commencé à poser les bases d'un déploiement WordPress haute disponibilité sur AWS avec Terraform et Ansible.
Malheureusement, le code livré ne fonctionne pas :
- Des erreurs de syntaxe empêchent toute validation du code.
- Même si la syntaxe était corrigée, des incohérences réseau et sécurité empêcheraient les instances de communiquer et de s'initialiser.
- L'architecture n'est pas modulaire et le code est monolithique.
- L'infrastructure coûte inutilement cher sur le compte AWS (facturation d'éléments inutiles).

Votre mission est de remettre ce projet en état de marche professionnel, de le modulariser et de l'optimiser pour le Free Tier d'AWS.

---

## Vos Objectifs & Défis

### Défi 1 : Diagnostic & Débogage Syntaxique
- Utilisez les outils standards de Terraform (`terraform fmt`, `terraform validate`) pour identifier et corriger les erreurs de syntaxe et de typage qui empêchent le code de compiler.
- Veillez à ce que `terraform validate` retourne un succès sans aucun warning.

### Défi 2 : Débogage Réseau, Sécurité & Fonctionnel
- Analysez le plan d'adressage VPC, les tables de routage et les Security Groups dans `vpc.tf` et `instances.tf`.
- Identifiez les blocages réseau qui empêcheraient :
  1. Les instances privées (`web` et `db`) d'accéder à Internet pour installer leurs paquets (`dnf`).
  2. Le serveur web d'accéder à la base de données MySQL sur le port 3306.
  3. Le proxy d'administrer les machines via SSH.
- Corrigez ces blocages en respectant le principe du moindre privilège (Least Privilege).

### Défi 3 : Modularisation & Gestion d'État (CRUCIAL)
- Notre équipe souhaite réutiliser la couche Compute. Vous devez refactorer les instances EC2 (`proxy`, `web`, `db`) ainsi que la clé SSH et l'EFS dans un module dédié : `modules/compute`.
- **CONTRAINTE CRITIQUE DE PRODUCTION :** 
  L'infrastructure est considérée comme déjà déployée en pré-production avec un fichier d'état `terraform.tfstate`.
  **Vous avez interdiction absolue de détruire et recréer les ressources existantes !**
  Si vous refactorez simplement le code dans un module, `terraform plan` va proposer de détruire les instances existantes pour les recréer sous la nouvelle adresse `module.compute.aws_instance.xxx`.
  **Consigne :** Implémentez la mécanique déclarative native de Terraform permettant d'assurer la migration d'adresses d'état sans aucune destruction/recréation (`0 to add, 0 to change, 0 to destroy`).

### Défi 4 : FinOps & Optimisation des Coûts AWS (Objectif 0 € / Free Tier)
- La facture AWS a explosé lors des derniers tests. Analysez l'architecture :
  1. Pourquoi l'ancienne architecture avec un AWS NAT Gateway managé coûtait-elle plus de 35 $/mois même au repos ? Quelle alternative sans surcoût pouvez-vous mettre en place ?
  2. Depuis le 1er février 2024, quelle est la nouvelle politique tarifaire d'AWS concernant les adresses IPv4 publiques ?
  3. Quelles sont les solutions concrètes pour que cette infrastructure soit **100% gratuite (0,00 €)** ou ne coûte que quelques centimes d'euros pour une démo ?

---

## Modalités de Rendu
- Travaillez sur votre branche de test.
- Effectuez des commits git atomiques et explicites (ex: `fix(syntax): ...`, `refactor(module): ...`).
- Rédigez un court compte-rendu dans un fichier `NOTES.md` expliquant :
  1. Les bugs trouvés et comment vous les avez résolus.
  2. La solution retenue pour le refactoring en module sans interruption de service.
  3. Vos recommandations FinOps.
```

---

## 4. Corrigé Détaillé & Réponses Attendues

Cette section est strictement réservée à l'évaluateur pour analyser le travail du candidat.

---

### Défi 1 : Débogage Syntaxique

#### Ce que le candidat doit exécuter en premier :
```bash
terraform fmt -check
terraform init
terraform validate
```

#### Bugs identifiés et corrections :
1. **Accolade manquante / bloc non fermé (`instances.tf`)** :
   - *Erreur levée :* `Error: Argument or block definition required` ou `Unterminated block`.
   - *Correction :* Refermer le bloc `resource "aws_instance" "db" { ... }`.
2. **Variable mal orthographiée (`var.ami_imge`)** :
   - *Erreur levée :* `Error: Reference to undeclared input variable: An input variable with the name "ami_imge" has not been declared. Did you mean "ami_image"?`
   - *Correction :* Remplacer par `var.ami_image`.
3. **Attribut invalide sur ressource (`aws_key_pair.wp_key.name`)** :
   - *Erreur levée :* `This object has no argument, nested block, or exported attribute named "name". Did you mean "key_name"?`
   - *Correction :* Utiliser `aws_key_pair.wp_key.key_name`.
4. **Attribut déprécié dans AWS Provider v5/v6 (`aws_eip.vpc = true`)** :
   - *Erreur levée :* `Argument is deprecated: use domain instead`.
   - *Correction :* Remplacer par `domain = "vpc"` ou supprimer l'EIP inutile.

**Attitude attendue du candidat :**
- Il ne modifie pas les fichiers au hasard : il lit le message d'erreur précis renvoyé par Terraform (qui indique la ligne et la colonne exacte).
- Il structure les variables dans un `variables.tf` dédié s'il souhaite assainir le code.

---

### Défi 2 : Débogage Réseau, Sécurité & Fonctionnel

#### 1. Problème de routage Internet pour les subnets privés
- **Constat :** Les instances `web` et `db` sont dans le subnet privé (`10.1.2.0/24`). Elles n'ont pas d'IP publique. Pour que le playbook Ansible installe `apache2`, `php` ou `percona-server`, elles doivent obligatoirement pouvoir contacter les dépôts de paquets sur Internet.
- **Mauvaise solution :** Mettre les instances web et db dans le subnet public avec `map_public_ip_on_launch = true`. (Rupture des règles de sécurité DMZ/LAN).
- **Bonne solution :** 
  - Dans la table de routage privée (`aws_default_route_table.private` ou `aws_route_table.private`), créer une route `0.0.0.0/0` pointant soit vers un NAT Gateway, soit vers la carte réseau (`network_interface_id`) de l'instance Proxy configurée en NAT instance (avec `source_dest_check = false`).
  - Ou router l'IPv6 vers une `aws_egress_only_internet_gateway`.

#### 2. Problème du Security Group MySQL (Port 3306)
- **Constat :** Le Security Group `wordpress_db` autorise le port 3306 depuis le CIDR public ou n'autorise rien.
- **Correction attendue :**
  ```hcl
  resource "aws_security_group" "wordpress_db" {
    name        = "wordpress_db"
    vpc_id      = aws_vpc.wordpress.id

    ingress {
      description     = "MySQL from web instances"
      from_port       = 3306
      to_port         = 3306
      protocol        = "tcp"
      security_groups = [aws_security_group.wordpress_web.id] # Idéalement par référence de SG
      # ou cidr_blocks = [aws_subnet.wordpress_private.cidr_block]
    }
  }
  ```
  *Remarque Senior :* L'utilisation de `security_groups = [aws_security_group.wordpress_web.id]` (référence croisée de SG) est bien plus sécurisée et idiomatique AWS que de filtrer uniquement par bloc CIDR.

#### 3. Problème de l'inventaire Ansible dynamique (`inventory.tf`)
- **Constat :** `${aws_instance.web[1].private_ip}` déclenche une erreur `Index out of range` si `count` est égal à 1.
- **Correction attendue :** Utilisation d'une boucle HCL :
  ```hcl
  [web]
  %{ for instance in aws_instance.web ~}
  ${instance.private_ip}
  %{ endfor ~}
  ```

---

### Défi 3 : Modularisation & Blocs `moved` (Le Point Clé !)

C'est l'étape discriminante qui sépare un profil Junior d'un profil Senior.

#### Le Problème sous-jacent :
Quand une ressource `aws_instance.proxy` est déplacée dans un module nommé `compute` :
Son identifiant Terraform change :
`aws_instance.proxy` ➔ `module.compute.aws_instance.proxy`

Si le candidat se contente de déplacer le code, `terraform plan` affiche :
```text
Plan: 3 to add, 0 to change, 3 to destroy.
- aws_instance.proxy (destroy)
- aws_instance.web[0] (destroy)
- aws_instance.db (destroy)
+ module.compute.aws_instance.proxy (create)
+ module.compute.aws_instance.web[0] (create)
+ module.compute.aws_instance.db (create)
```
**En production, ceci détruit immédiatement la base de données et les serveurs applicatifs, provoquant une coupure de service totale et une perte de données !**

#### La Solution Déclarative Attendue (depuis Terraform 1.1+) : Les blocs `moved`
Le candidat doit ajouter des blocs `moved` dans son code (dans `main.tf` ou `moved.tf`) :

```hcl
# moved.tf

moved {
  from = tls_private_key.ssh
  to   = module.compute.tls_private_key.ssh
}

moved {
  from = aws_key_pair.wp_key
  to   = module.compute.aws_key_pair.wp_key
}

moved {
  from = local_file.ssh_private_key
  to   = module.compute.local_file.ssh_private_key
}

moved {
  from = aws_instance.proxy
  to   = module.compute.aws_instance.proxy
}

moved {
  from = aws_instance.web
  to   = module.compute.aws_instance.web
}

moved {
  from = aws_instance.db
  to   = module.compute.aws_instance.db
}

moved {
  from = aws_efs_file_system.web_content
  to   = module.compute.aws_efs_file_system.web_content
}

moved {
  from = aws_efs_mount_target.private_subnet
  to   = module.compute.aws_efs_mount_target.private_subnet
}
```

#### Résultat vérifiable avec `terraform plan` :
```text
module.compute.aws_instance.proxy has moved to aws_instance.proxy
module.compute.aws_instance.web has moved to aws_instance.web
module.compute.aws_instance.db has moved to aws_instance.db

No changes. Your infrastructure matches the configuration.
Plan: 0 to add, 0 to change, 0 to destroy.
```

#### Alternative acceptable (mais moins moderne) :
- Exécution de commandes manuelles CLI : `terraform state mv aws_instance.proxy module.compute.aws_instance.proxy`.
- *Pourquoi le bloc `moved` est supérieur :* Le bloc `moved` est versionné dans Git, s'applique automatiquement à tous les membres de l'équipe et dans les pipelines CI/CD sans intervention manuelle sur le state. Si le candidat mentionne cette différence, attribuez le maximum de points.

---

### Défi 4 : FinOps & Architecture Zero-Cost / Gratuité

#### 1. Le Piège du NAT Gateway AWS managé
- **Analyse des coûts :** 
  - AWS NAT Gateway coûte **0,045 $ par heure**, soit environ **32,40 $ par mois** fixe, rien que pour exister (sans compter le coût des données traitées à 0,045 $/Go).
  - Il n'existe **AUCUN Free Tier** pour le NAT Gateway AWS. Dès la première seconde, il est facturé.
  - De plus, il nécessite une Elastic IP (EIP) qui coûte 0,005 $/h = **3,65 $/mois**.
  - **Coût total du composant : ~36 $ / mois.**
- **Alternative 100% Gratuite (NAT Instance sur Proxy) :**
  - Le serveur `proxy` (Traefik) est déjà situé dans le subnet public avec une interface réseau.
  - On désactive la vérification d'adresse : `source_dest_check = false`.
  - On active l'IP forwarding et la règle iptables MASQUERADE dans `user_data` :
    ```bash
    sysctl -w net.ipv4.ip_forward=1
    iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
    ```
  - La table de routage privée route `0.0.0.0/0` vers `network_interface_id = aws_instance.proxy.primary_network_interface_id`.
  - **Surcoût : 0,00 € !** On économise 36 $ par mois immédiatement.

#### 2. La Nouvelle Facturation des Adresses IPv4 Publiques (1er Février 2024)
- **Ce que le candidat doit savoir :**
  - Depuis le **1er février 2024**, AWS facture **toutes les adresses IPv4 publiques** (qu'elles soient des Elastic IP ou des adresses publiques auto-assignées sur des instances EC2 en cours d'exécution).
  - Tarif : **0,005 $ / heure par adresse IPv4** (soit environ **3,65 $ / mois par IP**).
  - Exception Free Tier : Les nouveaux comptes AWS bénéficient de 750 heures d'IPv4 publique par mois pendant les 12 premiers mois, uniquement sur les instances EC2 `t2.micro` ou `t3.micro`. Passé 12 mois, toute IPv4 publique est payante.
- **Comment avoir une infra 100% Gratuite (0,00 €) ?**
  1. **Libération de l'IP à l'arrêt :** Une instance avec IP publique auto-assignée (`map_public_ip_on_launch = true`) **libère son IP** lorsqu'elle est arrêtée (`stopped`). Dès lors, AWS ne facture plus l'adresse IP ! À l'inverse, une Elastic IP (`aws_eip`) attachée à une instance arrêtée ou non attachée est **facturée 24h/24** ! Supprimer les Elastic IP persistantes permet donc d'arrêter les coûts.
  2. **IPv6 gratuit (Zero Cost IPv6) :**
     - Les adresses IPv6 publiques sur AWS sont **100% gratuites**.
     - L'attribution d'un bloc IPv6 à un VPC (`assign_generated_ipv6_cidr_block = true`) est **gratuite**.
     - L'**Egress-Only Internet Gateway** (`aws_egress_only_internet_gateway`) pour les instances privées est **gratuite** (contrairement au NAT Gateway IPv4 !).
  3. **EC2 Instance Connect Endpoint (EICE) :**
     - Permet d'administrer des instances privées en SSH via le backbone AWS, sans aucune adresse IP publique, sans bastion et sans passerelle NAT. Service 100% gratuit.
  4. **Cycle de vie éphémère :**
     - Exécuter `terraform destroy` dès la fin du test ou de la démo. Pour un test de 2 heures, 1 IP publique coûte 2 x 0,005 $ = **0,01 $ (1 centime)**.
  5. **Émulation locale (LocalStack) :**
     - Utiliser LocalStack pour exécuter Terraform localement sans jamais contacter AWS. Coût : 0,00 €.

#### 3. Optimisation du nombre d'instances EC2
- L'AWS Free Tier offre **750 heures cumulées** par mois d'instances `t2.micro` ou `t3.micro`.
- Avec 4 instances (`proxy` + 2 `web` + 1 `db`), 750 heures correspondent à seulement ~7 jours d'exécution dans le mois !
- Le candidat doit proposer de paramétrer le nombre d'instances via une variable (ex: `web_instance_count = 1` par défaut en environnement de test).

---

## 5. Grille d'Évaluation & Barème de Notation

Barème sur **20 points** :

| Axe d'évaluation | Critères observables | Points |
| :--- | :--- | :---: |
| **1. Rigueur & Méthodologie Git** | - Commits clairs, atomiques et préfixés (Conventional Commits).<br>- Utilisation systématique de `terraform fmt` et `terraform validate`.<br>- Qualité et clarté des explications dans `NOTES.md`. | / 4 |
| **2. Débogage & Maîtrise HCL** | - Correction rapide et propre des erreurs de syntaxe.<br>- Typage rigoureux des variables (`string`, `number`, descriptions).<br>- Suppression des avertissements et des arguments dépréciés. | / 4 |
| **3. Architecture Réseau & Sécurité** | - Compréhension du modèle VPC (public vs privé).<br>- Résolution du routage sortant pour `dnf`.<br>- Security Groups restreints au juste nécessaire (ports 80, 22, 3306, 2049) sans ouverture `0.0.0.0/0` abusive. | / 4 |
| **4. Modularisation & Blocs `moved`** | - Création propre du module (`variables.tf`, `outputs.tf`, `main.tf`).<br>- **Utilisation des blocs `moved`** évitant toute destruction de ressource.<br>- Justification de la stratégie de migration d'état sans downtime. | / 5 |
| **5. Sensibilité FinOps (Coûts AWS)** | - Identification immédiate du coût du NAT Gateway (~32$/mois).<br>- Connaissance de la tarification IPv4 (0,005$/h depuis fév 2024).<br>- Proposition de solutions de gratuité (NAT instance, IPv6, EICE, arrêt programmé). | / 3 |

### Grille de Profilage :
- **< 10 / 20 (Insuffisant) :** Bloque sur les erreurs de syntaxe de base, ne comprend pas le routage VPC, détruit les ressources lors de la modularisation.
- **11 à 15 / 20 (Profil Confirmé) :** Corrige tous les bugs syntaxiques et réseau. Réalise la modularisation mais oublie `moved` (ou utilise `terraform state mv` manuellement après avoir vu le `destroy`). Conscience moyenne des coûts.
- **16 à 20 / 20 (Profil Senior / Tech Lead) :** Démarche méthodique immédiate (`fmt`, `validate`). Pense spontanément aux blocs `moved` avant même d'appliquer le plan. Connaît parfaitement les impacts FinOps récents (tarifs IPv4 2024, NAT Gateway) et propose des architectures alternatives gratuites et résilientes.

---

## 6. Questions d'Approfondissement pour l'Entretien Oral

Pour compléter l'évaluation lors de l'entretien de debriefing :

1. **Sur le bloc `moved` :**
   - *"Pourquoi avez-vous préféré utiliser des blocs `moved` plutôt que la commande `terraform state mv` ?"*
   - *Réponse attendue :* `moved` est déclaratif, stocké dans Git, et s'exécute automatiquement en CI/CD et pour tous les développeurs sans nécessiter un accès direct au bucket de state S3.
2. **Sur la gestion des secrets :**
   - *"Actuellement, les mots de passe de la BDD sont gérés avec Ansible Vault. Comment pourrions-nous gérer ces secrets de manière plus 'Cloud-Native' avec AWS et Terraform ?"*
   - *Réponse attendue :* AWS Secrets Manager ou SSM Parameter Store (SecureString), avec injection dynamique ou intégration IAM Instance Profile pour éviter tout stockage de clé en clair.
3. **Sur la haute disponibilité :**
   - *"L'instance DB MySQL tourne sur une simple instance EC2 t2.micro. Quels sont les risques et que recommanderiez-vous pour une production critique ?"*
   - *Réponse attendue :* Pas de réplication automatique, SPOF en cas de panne de l'AZ `eu-west-3a`. En production : AWS Aurora ou RDS Multi-AZ avec sauvegardes automatiques et read-replicas.
4. **Sur la sécurité SSH :**
   - *"Nous utilisons une clé SSH et un bastion Proxy pour nous connecter en SSH aux machines privées. Quelle fonctionnalité AWS native plus moderne et sécurisée permettrait de supprimer totalement le port 22 et les clés SSH ?"*
   - *Réponse attendue :* **AWS Systems Manager (SSM) Session Manager** ou **EC2 Instance Connect Endpoint**. Permet d'ouvrir un shell via le protocole HTTPS/TLS sécurisé par les politiques IAM, avec traçabilité dans CloudTrail et sans aucun port ouvert sur l'extérieur.
