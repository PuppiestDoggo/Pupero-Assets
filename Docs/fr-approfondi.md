# Pupero — Approfondi technique

Ce document détaille l’architecture, les flux de données, les API, les traitements en arrière‑plan et les aspects d’exploitation.

1. Architecture (services et responsabilités)
- Frontend (Pupero-LoginFrontEnd, Flask) :
  - Sert les templates HTML. Gère les cookies de session (HttpOnly), l’option « se souvenir de moi », les flags SameSite et Secure via variables d’environnement.
  - Appelle les APIs internes via l’API Manager (proxy). Implémente l’UI du flux d’échange simple.
- API Manager (Pupero-APIManager, FastAPI) :
  - Petit reverse‑proxy/passerelle. Endpoint de santé /healthz. Redirige les routes vers les services aval.
- Backend Login (Pupero-LoginBackend, FastAPI) :
  - Endpoints pour inscription/connexion, émission/refresh de JWT, gestion TOTP, opérations de profil, suppression de compte.
  - Hachage mots de passe via Argon2 (passlib). JWT HS256 avec durées configurables. TOTP via pyotp.
- Offres (Pupero-Offers, FastAPI) :
  - CRUD des offres (liste/création/mes offres/détail). Persisté avec SQLModel + MariaDB.
- Transactions/Ledger (dans le repo, FastAPI) :
  - Enregistre les transferts internes entre utilisateurs quand un échange est confirmé. Met les retraits en file RabbitMQ.
- Gestionnaire de Portefeuille (Pupero-MoneroWalletManager, FastAPI) :
  - Dialogue avec monero-wallet-rpc (transfer_split, get_balance, get_height, etc.).
  - Lit périodiquement RabbitMQ pour exécuter les retraits on‑chain. Expose /healthz et des endpoints admin.
- RabbitMQ :
  - File pour les retraits. Producteur : Transactions. Consommateur : Wallet Manager (boucle périodique).
- Base de données (MariaDB) :
  - Contient utilisateurs, offres, soldes, échanges. ORM SQLModel côté Python.
- Démon Monero (monerod) + monero-wallet-rpc :
  - monerod se synchronise ; wallet‑rpc ouvre le wallet Pupero et accepte les appels RPC (auth MONERO_RPC_USER/PASSWORD).
- Supervision optionnelle (Pupero-Elastic) :
  - Prometheus + Grafana pour le scraping et les tableaux de bord (non requis pour le cœur fonctionnel).
- Matrix optionnel (Pupero-Matrix) :
  - Exemple de Synapse pour le chat en dev ; non intégré au flux d’échange cœur.

2. Réseau et ports (overlay dev)
- Frontend : 5000
- API Manager : 8000
- Login : 8001
- Offres : 8002
- Transactions : 8003
- Wallet Manager : 8004
- RabbitMQ : 15672 (UI) + 5672 (AMQP interne)
- Monerod/Wallet RPC : depuis .env (MONEROD_RPC_PORT, WALLET_RPC_PORT)

3. Configuration (Pupero-Assets/.env)
- Base : DB_ROOT_PASSWORD, DB_NAME
- RabbitMQ : RABBITMQ_USER, RABBITMQ_PASSWORD, RABBITMQ_QUEUE
- Monero : MONEROD_ARGS (« --testnet » par défaut), MONEROD_P2P_PORT, MONEROD_RPC_PORT
- Wallet RPC : WALLET_RPC_PORT, MONERO_RPC_USER, MONERO_RPC_PASSWORD, MONERO_RPC_AUTH_SCHEME
- Wallet Manager :
  - RABBITMQ_POLL_INTERVAL_SECONDS (1800 par défaut) — fréquence de lecture de la file retraits
- Sweeper :
  - SWEEP_INTERVAL_SECONDS, MIN_SWEEP_XMR — crédit périodique on‑chain vers la base (si activé)
- Frontend :
  - REMEMBER_ME_DAYS, SECURE_COOKIES, SESSION_COOKIE_SAMESITE

4. Modèle de données (vue d’ensemble)
- Utilisateurs : id, email, username, password_hash (argon2), secret 2FA (optionnel), champs profil.
- Offres : id, user_id (propriétaire), côté (achat/vente), prix, montant, statut, timestamps.
- Échanges : id, buyer_id, seller_id, offer_id, état, timestamps de confirmations.
- Soldes/Ledger : unités XMR internes par utilisateur pour la démo (pas de fonds on‑chain). Transferts atomiques.
- Retraits : messages en file avec user_id, montant, adresse, clé d’idempotence.

5. Périmètre API (extraits)
- Backend Login
  - POST /register — créer un utilisateur
  - POST /login — émettre le couple de jetons (access+refresh)
  - POST /token/refresh — renouveler l’access
  - GET /me — profil ; PUT /me — mise à jour
  - POST /2fa/enable, POST /2fa/confirm, POST /2fa/disable
  - DELETE /me — supprimer le compte
- Offres
  - GET /offers — liste ; POST /offers — créer
  - GET /offers/{id} — détail
  - GET /me/offers — offres de l’utilisateur courant
- Transactions
  - POST /transactions/transfer — transfert interne lors de la confirmation d’échange
  - POST /withdraw — mise en file d’un retrait on‑chain
  - GET /balances/{user_id} — lecture du solde
- Wallet Manager
  - GET /healthz — readiness
  - POST /admin/withdraw/execute — exécution d’un retrait en file (normalement par la boucle consommateur)

6. Séquences : échange et retrait
- Confirmation d’échange (cas nominal)
  1) L’acheteur clique « Argent envoyé » dans le Frontend.
  2) Le vendeur clique « J’ai reçu l’argent ».
  3) Le Frontend appelle /transactions/transfer (seller->buyer) côté Transactions.
  4) Transactions écrit l’entrée de ledger et met à jour les soldes de façon atomique.
- Retrait
  1) L’utilisateur demande un retrait (adresse + montant) dans le Frontend.
  2) Le Frontend appelle /withdraw côté Transactions, qui met un message dans RabbitMQ.
  3) La boucle du Wallet Manager (fréquence RABBITMQ_POLL_INTERVAL_SECONDS) lit, valide, et appelle transfer_split de monero‑wallet‑rpc.
  4) En succès, le Wallet Manager marque la tâche comme effectuée (et peut enregistrer les txids en base si activé).

7. Sécurité
- Hachage : Argon2id via passlib ; jamais de mots de passe en clair.
- Jetons : JWT HS256 ; garder la clé secrète en dehors du VCS en production.
- 2FA : TOTP (codes à usage unique temporels). Codes de secours hors périmètre de la démo.
- Cookies : Activer Secure=true et SameSite=Lax/Strict derrière HTTPS en production.
- Secrets : .env conservé au dépôt pour la démo ; ne mettez pas de secrets réels. En prod, utilisez des variables/gestionnaires de secrets.
- Réseau : En mode prod compose, seuls Frontend et API Manager sont exposés ; maintenir les autres en réseau interne, avec un reverse proxy TLS en frontal.

8. Exploitation
- Ordre de démarrage : monerod -> wallet‑rpc -> wallet manager ; DB/RabbitMQ avant les services dépendants ; API Manager attend la santé des services cœur.
- Healthchecks :
  - curl http://localhost:8000/healthz
  - curl http://localhost:8001/healthz
  - curl http://localhost:8002/healthz
  - curl http://localhost:8003/healthz
  - curl http://localhost:8004/healthz
  - curl http://localhost:5000/
- Journaux : docker compose logs NOM_SERVICE ; ajouter -f pour suivre.
- Sauvegardes : dump DB depuis son conteneur ; copier les fichiers wallet et les répertoires de données du daemon en sécurité.
- Réinitialisation : docker compose … down -v (supprime les volumes). Pour test/dev uniquement.

9. Passage au mainnet
- Dans .env, retirer --testnet de MONEROD_ARGS et ouvrir les ports nécessaires. Comprendre les implications sécurité/légales. Protéger les clés du wallet.

10. Dépannage
- Envoi bloqué : s’assurer que wallet‑rpc a bien ouvert le wallet et est authentifié ; alimenter le wallet sur le réseau choisi.
- File non consommée : vérifier les variables RABBITMQ_* et que la boucle consommateur tourne (logs du Wallet Manager).
- API 5xx : consulter les logs du service concerné ; vérifier la présence/migration du schéma DB.
- Timeouts : Les composants Monero peuvent mettre du temps à se synchroniser ; les endpoints de santé reflètent l’état de readiness.

11. Extensions possibles
- Remplacer le flux simple par de l’escrow ou du multisig.
- Ajouter rate limiting, journaux d’audit, WebAuthn ou CAPTCHA sur l’auth.
- Implémenter des clés d’idempotence et la déduplication des retraits côté base.
- Exposer des métriques Prometheus et créer des dashboards Grafana.

Cet approfondi reflète l’état actuel du dépôt et ses défauts. Référez‑vous aux READMEs et au code pour le comportement définitif.