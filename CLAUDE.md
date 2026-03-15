# Maurice

Maurice est une application macOS de transcription audio avec édition Markdown.

## General
- Never add unrequested UI changes (shadows, animations, styling). Only change what was explicitly asked for. Respect user's editorial deletions - never reintroduce content the user removed.

## Architecture

- **Clean Architecture** : Domain → Presentation → Data
- **SwiftUI + AppKit** : NSViewRepresentable pour le rendu Markdown (NSTextView)
- **Swift Concurrency** : async/await dans les ViewModels et UseCases

## Structure

```
Sources/
├── App/              # Point d'entrée (MauriceApp)
├── Presentation/     # Vues SwiftUI, ViewModels
├── Domain/           # Entités, protocoles, cas d'utilisation
└── Data/             # Stockage fichier, reconnaissance vocale
```

## Code Quality

- **Background threads** : Toujours déplacer le file I/O, le JSON encode/decode, le directory scanning et tout calcul lourd hors du main thread. Utiliser `Task.detached { }` pour le travail fire-and-forget (ex: saves), et `Task { await Task.detached { ... }.value }` pour charger des données puis mettre à jour l'UI. Ne jamais bloquer le main thread.
- **SwiftLint** : Toujours corriger tous les warnings et erreurs SwiftLint. Lancer `swiftlint lint --config .swiftlint.yml` et résoudre chaque problème avant de considérer une tâche terminée. Ne jamais utiliser `// swiftlint:disable` pour contourner une règle — toujours corriger le code sous-jacent (extraire des structs, refactorer les paramètres, etc.).
- **Réutilisation du code** : Réutiliser au maximum le code existant. Avant de créer une nouvelle fonction, vérifier s'il existe déjà une implémentation similaire dans le projet. Extraire les patterns communs en méthodes/extensions partagées plutôt que dupliquer du code.

## UI

- **Liquid Glass** : Utiliser le style Liquid Glass (macOS 26) pour tous les éléments d'interface — `.glassEffect()`, boutons, barres, panneaux. Préférer les matériaux translucides et les formes arrondies.

## Conventions

- Langue de l'interface : français
- Stockage des données : `~/Documents/Maurice/`
- Thème Markdown : `~/Documents/Maurice/theme.json`
- Fichiers mémoire : `~/Documents/Maurice/Memory/`

## Build & Run

- Utiliser **XcodeBuildMCP** pour build, run et test. Ne pas utiliser `xcodebuild` en shell.
- Appeler `session_show_defaults` avant le premier build de la session.
- C'est une app **macOS** : utiliser le workflow macOS de XcodeBuildMCP (pas simulator iOS).
- Après chaque tâche terminée, **relancer l'app** pour vérifier.
- Après une grosse tâche, lancer **SwiftLint** (`swiftlint lint --config .swiftlint.yml`) et corriger tous les problèmes.

## Xcode Project

- Ne **jamais** installer de dépendance Ruby (xcodeproj gem, etc.) pour modifier le projet.
- Pour ajouter des fichiers au projet Xcode, modifier directement le `project.pbxproj` (PBXFileReference, PBXGroup, PBXBuildFile, PBXSourcesBuildPhase).
