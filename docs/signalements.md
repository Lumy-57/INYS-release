# Signalements des joueurs

Dans le menu titre, « Signaler un bug / une remarque » propose :

- **un bug (GitHub)** et **une remarque (GitHub)** : ouvrent une issue préremplie sur ce dépôt,
  avec les modèles de `.github/ISSUE_TEMPLATE` (labels `bug` et `enhancement`).
  Il faut un compte GitHub.
- **sans compte GitHub** : ouvre un formulaire Google prérempli. Les réponses arrivent
  dans un tableau Google Sheets. Cette entrée n'apparaît que si le formulaire est configuré.

Dans les deux cas, la version du jeu, la plateforme (système et résolution) et le dernier
niveau joué sont remplis d'avance.

## Configurer le formulaire Google

1. Sur [forms.google.com](https://forms.google.com), créer un formulaire avec ces questions :
   - **Type** : choix multiples « Bug » / « Remarque », obligatoire ;
   - **Message** : paragraphe, obligatoire ;
   - **Comment le reproduire ?** : paragraphe, facultatif ;
   - **Niveau**, **Version**, **Plateforme** : réponse courte.
2. Dans Paramètres > Réponses : ne pas collecter les adresses e-mail et ne pas limiter
   à une réponse, sinon le joueur doit se connecter à un compte Google.
3. Onglet Réponses > « Associer à Sheets » pour tout recevoir dans un tableau
   (on peut trier et filtrer par Type, Niveau ou Version).
4. Menu ⋮ > « Obtenir le lien prérempli » : écrire `N` dans Niveau, `V` dans Version,
   `P` dans Plateforme, puis « Obtenir le lien » et le copier. Il ressemble à :

   ```
   https://docs.google.com/forms/d/e/1FAIpQL.../viewform?usp=pp_url&entry.111=N&entry.222=V&entry.333=P
   ```

5. Dans `scripts/bug_report.gd`, mettre la partie avant `?` dans `FORM_URL` et les numéros
   dans `FORM_ENTRIES` :

   ```gdscript
   const FORM_URL := "https://docs.google.com/forms/d/e/1FAIpQL.../viewform"
   const FORM_ENTRIES := {
   	"niveau": "111",
   	"version": "222",
   	"plateforme": "333",
   }
   ```
