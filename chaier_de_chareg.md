Description du mini-projet : Développement d'une application de

signalement d'incidents urbains

Dans le cadre de ce mini-projet, vous devez développer une application mobile permettant aux
utilisateurs de signaler divers incidents urbains (incendies, accidents, etc.) en capturant une
photo, en fournissant une description (textuelle ou vocale) et en indiquant la localisation précise
de l'incident.
Fonctionnalités requises
1. Authentification et autorisation sécurisées
o Rôles utilisateurs : Deux rôles distincts, citoyen et administrateur.
o Méthodes d'authentification :
▪ Authentification basée sur JSON Web Token (JWT)
▪ Authentification basée sur les données biométriques (empreinte digitale,
reconnaissance faciale)

2. Signalement des incidents
o Permettre aux utilisateurs d'envoyer des rapports d'incidents incluant :
▪ Une photo de l'incident
▪ Une description de l'incident, avec le choix entre une saisie textuelle ou
vocale
▪ La localisation géographique

3. Gestion en mode hors ligne
o Stockage temporaire des incidents dans une base de données locale lorsque
l'accès au serveur est indisponible.

4. Synchronisation des données
o Mise en place d'un mécanisme de synchronisation qui transfère les incidents
stockés localement vers l'API dès que la connexion est rétablie.

5. Historique des incidents
o Consultation de l'historique des incidents signalés par chaque utilisateur.
o Possibilité d'afficher le trajet associé à chaque incident via Google Maps.
6. Gestion de l'état de l'application
o Implémenter l'une des approches de gestion d'état (par exemple, Getx, Bloc,
provider, etc.) afin d'assurer une expérience utilisateur fluide et réactive.

7. Choix de la technologie back-end
o Vous êtes libre d'utiliser la technologie back-end de votre choix selon vos
préférences et compétences.