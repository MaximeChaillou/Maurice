---
description: Summarize a meeting from its transcript.
---

# Meeting Summary

## Instructions

1. **Read the transcript** from `$0`
2. **Gather context:**
   - Check if a preparation note already exists for today in the same folder (`YYYY-MM-DD.md`). If so, use it as a base.
   - Identify participants from the transcript
   - Read `Memory/Directory.md` to identify participants and their context
   - For each participant with a file in `Memory/People/`, read it — use their context, patterns, and focus areas to better understand the discussion
   - Read project files in `Memory/Projects/` linked to discussed topics
3. **Update or create the meeting note** (`YYYY-MM-DD.md` in the same folder as the transcript):

```markdown
---
date: YYYY-MM-DD
participants: [list of identified participants]
---

# Summary — [Main topic of the meeting]

## Key points
- Important decisions and conclusions (concise bullet points)

## Discussions
- Topics discussed, grouped by theme (not a verbatim — just the essentials)

## Actions
- [ ] Identified action — @owner (if identifiable)

## Notes
- Anything notable that doesn't fit elsewhere (tensions, weak signals, important context)
```

4. **Present a concise summary** highlighting key decisions and actions
5. **Extract and update memory** — First, produce a structured extraction block at the end of the meeting note:

```markdown
## Extraction mémoire
- **Personnes mises à jour** : prenom-nom (nouveau fait), prenom-nom (nouveau fait)
- **Projets mis à jour** : projet (décision/changement)
- **Nouveaux faits** : prenom-nom → fait appris
- **Faits obsolètes** : prenom-nom → ~~ancien fait~~ remplacé par nouveau fait
- **Nouvelles personnes** : prenom-nom (rôle, équipe, contexte)
```

   Then apply the memory update protocol defined in CLAUDE.md:
   - Update `Memory/Directory.md` if new participants or role changes
   - Update `Memory/People/` files for participants with new relevant info (topics raised, positions taken, patterns observed). Date each new fact with `[YYYY-MM]`. Strikethrough obsolete facts. Update `updated` field.
   - Create a `Memory/People/` file for any participant seen in 3+ meetings who doesn't have one yet
   - Update `Memory/Projects/` files with decisions, status changes, or metrics discussed
   - Ensure cross-references are consistent (`people[].projects` ↔ `projects[].people`)
   - Add identified actions to `Tasks.md`

## Rules
- Be **concise**: the summary should fit on one screen max
- Language: French
- Don't paraphrase every intervention — synthesize
- Highlight **decisions** and **actions**
