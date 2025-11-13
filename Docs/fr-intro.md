# Pupero — Présentation et fonctionnement (Niveau non technique)

Pupero est une petite plateforme autonome pour simuler du trading pair‑à‑pair (P2P) de Monero (XMR) de façon sûre et adaptée aux tests. Elle s’exécute comme un ensemble de services prêts à l’emploi dans Docker, ce qui permet de tout démarrer avec une seule commande et d’explorer un parcours de trading de bout en bout.

Idées clés
- Facile à lancer en local (testnet Monero par défaut).
- Rôles bien séparés : une application web pour les utilisateurs, de petites API pour les fonctionnalités, et des tâches en arrière‑plan pour les actions on‑chain.
- Briques réalistes : connexion avec 2FA, liste d’offres, échanges simples, et un gestionnaire de portefeuille capable d’envoyer du XMR sur la blockchain.

Les éléments principaux
- Site web (frontend) : Interface simple pour s’inscrire, se connecter, parcourir les offres et simuler des échanges.
- API d’authentification : Vérifie les utilisateurs et sécurise les sessions (mots de passe, jetons, 2FA en option).
- API Offres : Stocke les offres d’achat/vente affichées sur le site.
- API Transactions/Ledger : Déplace les soldes simulés lorsqu’un échange est confirmé.
- Gestionnaire de Portefeuille : Dialogue avec le logiciel monero‑wallet‑rpc et peut exécuter des retraits on‑chain.
- Nœud Monero et wallet : Composants Monero réels en mode test par défaut.
- API Manager : Point d’entrée unique qui achemine les requêtes vers le bon service.

À quoi ressemble un parcours type
1) Vous vous inscrivez et vous connectez sur le site (2FA possible).
2) Vous parcourez les offres et lancez un échange.
3) Le site guide les deux parties via une double confirmation (« J’ai envoyé l’argent » / « J’ai reçu l’argent »).
4) Une fois les deux confirmations faites, le système transfère le solde simulé du vendeur vers l’acheteur.
5) Si vous retirez vers une adresse Monero, une tâche est mise en file et exécutée plus tard on‑chain par le Gestionnaire de Portefeuille.

Ce pour quoi c’est utile
- Démo et apprentissage : Voir toutes les pièces d’un marché P2P au même endroit.
- Expérimentations locales : Tester sans risque grâce au testnet par défaut.
- Base extensible : Chaque brique est un service, on peut en remplacer l’implémentation plus tard.

Ce que ce n’est pas (encore)
- Pas un échange complet prêt production. Le durcissement sécurité, la conformité et l’exploitation restent à votre charge.
- Pas un service d’escrow. Le flux d’échange actuel est une démonstration simple et basée sur la confiance.

Comment l’exécuter
- Construisez les images puis lancez l’ensemble avec docker compose. Le site est sur http://localhost:5000 et le point d’entrée API sur http://localhost:8000. L’arrêt se fait aussi en une commande. Voir le document technique pour les commandes exactes.

En bref : Pupero est un bac à sable réaliste et sûr pour expérimenter les concepts de trading P2P Monero, conçu pour être facile à lancer et à comprendre.