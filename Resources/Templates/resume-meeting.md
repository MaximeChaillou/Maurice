---
description: Résumé concis d'une réunion à partir d'un transcript local.
---

# Résumé de réunion

## Instructions

1. Lis le fichier transcript depuis `$0`
2. Génère un résumé concis en markdown avec la structure suivante :

```markdown
---
date: YYYY-MM-DD
participants: [liste des participants identifiés]
durée: estimation
---

# Résumé — [Titre/sujet principal de la réunion]

## Points clés
- Les décisions prises et conclusions importantes (bullet points concis)

## Discussions
- Résumé des sujets abordés, regroupés par thème (pas un verbatim, juste l'essentiel)

## Actions
- [ ] Action identifiée — @responsable (si identifiable)

## Notes
- Tout élément notable qui ne rentre pas ailleurs (tensions, signaux faibles, contexte important)
```

4. Sauvegarde le fichier markdown **dans le même dossier que le transcript**, avec le même nom de fichier mais l'extension `.md`
5. Si le fichier est déjà en `.md`, suffixe avec `-resume.md`

## Règles
- Sois **concis** : le résumé doit tenir sur un écran max
- Langue : français
- Ne paraphrase pas chaque intervention — synthétise
- Mets en avant les **décisions** et les **actions**
- Si des participants sont dans `Memory/Annuaire.md`, utilise leurs prénoms
