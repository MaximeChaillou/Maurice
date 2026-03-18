# Maurice

Application macOS de transcription audio avec édition Markdown.

## Installation

### Via Homebrew (recommandé)

```bash
brew tap MaximeChaillou/maurice https://github.com/MaximeChaillou/Maurice
brew install --cask maurice
```

### Téléchargement manuel

Télécharger la dernière version depuis la page [Releases](https://github.com/MaximeChaillou/Maurice/releases).

### Débloquer Gatekeeper

Maurice n'est pas signé avec un compte Apple Developer. macOS bloquera l'application au premier lancement.

**Méthode 1 — Clic droit :**
1. Ouvrir le Finder et aller dans `/Applications`
2. Faire **clic droit** (ou Ctrl+clic) sur Maurice.app
3. Cliquer sur **Ouvrir**
4. Confirmer dans la boîte de dialogue

**Méthode 2 — Terminal :**

```bash
xattr -cr /Applications/Maurice.app
```

Cette commande supprime les attributs de quarantaine. Il suffit de la lancer une seule fois.

## Fonctionnalités

- Transcription audio en temps réel (Speech Recognition)
- Édition Markdown
- Organisation par date
- Système de mémoire et de tâches
- Interface Liquid Glass (macOS 26)

## Licence

MIT
