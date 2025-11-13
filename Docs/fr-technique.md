# Pupero — Vue technique (Accessible)

Ce document explique comment exécuter Pupero et le rôle de chaque composant, sans entrer trop dans les détails internes.

Contenu de la pile
- API Manager (port 8000) : Point d’entrée unique qui redirige vers les bons backends.
- Backend Login (port 8001) : Service FastAPI pour l’authentification (inscription, connexion, JWT, TOTP 2FA, profil, suppression de compte).
- Offres (port 8002) : Service FastAPI qui stocke et publie les offres d’achat/vente.
- Transactions/Ledger (port 8003) : Service FastAPI qui enregistre les transferts internes pour les échanges et met les retraits en file.
- Gestionnaire de Portefeuille Monero (port 8004) : Service FastAPI qui dialogue avec monero-wallet-rpc et exécute les envois on‑chain. Consomme aussi périodiquement les retraits depuis RabbitMQ.
- RabbitMQ (port 15672 pour l’UI) : File de messages pour les retraits.
- Base de données (MariaDB) : Stocke utilisateurs, offres, soldes et échanges.
- Frontend (port 5000) : Site web Flask pour les utilisateurs.
- Démon Monero + wallet-rpc : Composants Monero réels (testnet par défaut).
- Optionnel : Matrix/Element pour le chat, Prometheus/Grafana pour la supervision.

Exécution locale (développement)
1) Construire les images (à faire une fois ou après une modification du code) :
   - cd Pupero-Assets
   - ./build_all_docker.sh
2) Copier le fichier d’environnement :
   - Dans Pupero-Assets, copier .env.example vers .env et ajuster si besoin (testnet par défaut).
3) Démarrer les services (l’overlay dev publie plusieurs ports) :
   - docker compose -f docker-compose.base.yml -f docker-compose.dev.yml --env-file .env up -d
4) Ouvrir :
   - Frontend : http://localhost:5000
   - API Manager : http://localhost:8000/healthz
   - Login : http://localhost:8001/healthz
   - Offres : http://localhost:8002/healthz
   - Transactions : http://localhost:8003/healthz
   - Wallet Manager : http://localhost:8004/healthz
   - RabbitMQ UI : http://localhost:15672
5) Arrêter :
   - docker compose -f docker-compose.base.yml -f docker-compose.dev.yml down
   - Ajouter -v pour supprimer les volumes (p. ex. réinitialiser la base).

Mode proche production (sans reverse proxy)
- docker compose -f docker-compose.base.yml -f docker-compose.prod.yml --env-file .env up -d
- Ceci ne publie que l’API Manager (8000) et le Frontend (5000). Placez votre reverse proxy/TLS devant.

Variables d’environnement (vue d’ensemble)
- Base de données : identifiants et nom de base.
- RabbitMQ : utilisateur, mot de passe, nom de file.
- Monero : paramètres/ports de monerod, port et authentification de wallet‑rpc.
- Frontend : options de session et cookies.
- Sweeper/Wallet Manager : intervalles de balayage/traitement des retraits ; montant minimum de sweep.

Flux principaux
- Inscription/Connexion : Le Frontend appelle le Backend Login via l’API Manager ; identifiants stockés en base avec Argon2 ; 2FA TOTP optionnelle.
- Parcours d’offre et échange : Le Frontend récupère les offres ; un flux de confirmation en deux étapes est utilisé.
- Transfert de solde : Quand les deux parties confirment, le service Transactions enregistre un transfert entre soldes utilisateurs.
- Retrait on‑chain : Transactions met un message de retrait en file ; le Wallet Manager lit périodiquement RabbitMQ et appelle monero‑wallet‑rpc pour envoyer.

Testnet vs mainnet
- Par défaut : testnet (sûr pour expérimenter). Données dans Pupero-Assets/.bitmonero et wallets dans Pupero-Assets/wallets.
- Passer en mainnet : modifier MONEROD_ARGS dans .env (retirer --testnet) et ajuster réseau/pare‑feu.

Sauvegardes et données
- Volume base de données : db_data (faire un dump depuis le conteneur DB si nécessaire).
- Données Monero : Pupero-Assets/.bitmonero et Pupero-Assets/wallets — protégez ces secrets si vous utilisez des fonds réels.

Dépannage de base
- Vérifier les endpoints de santé.
- docker compose logs NOM_SERVICE pour les erreurs.
- S’assurer que monerod est démarré avant wallet‑rpc puis le Wallet Manager.

C’est tout pour comprendre et exploiter Pupero au quotidien. Pour les détails internes, voir le document « Approfondi ».