# Recherche STT macOS Apple Silicon (Swift) — Mars 2026

## Contexte
Objectif : intégrer du Speech-to-Text local dans une app macOS Swift sur Apple Silicon.
Critères : multilingue, diarisation souhaitée, on-device.

---

## Options principales

### 1. WhisperKit (Argmax) — Recommandé pour la transcription
- **Swift natif** (SPM), optimisé Neural Engine (ANE)
- **99+ langues** (modèles Whisper multilingues large-v3)
- Pas de diarisation en open-source (disponible via Argmax Pro SDK à $0.42/device/mois)
- Performances : ~27x temps réel sur M4 (modèle tiny)
- **Licence MIT** | macOS 14+ | Xcode 16+
- https://github.com/argmaxinc/WhisperKit

### 2. whisper.cpp + SwiftWhisper
- Port C/C++ mature de Whisper avec bindings Swift via SPM (SwiftWhisper)
- **99+ langues**, accélération Metal + CoreML
- Pas de diarisation intégrée
- Intégration Swift moyenne (bridging C++)
- **Licence MIT**
- https://github.com/ggml-org/whisper.cpp
- https://swiftpackageindex.com/exPHAT/SwiftWhisper
- Note : c'est ce qu'utilise l'app **Handy** (https://github.com/cjpais/Handy)

### 3. FluidAudio — Recommandé pour la diarisation
- SDK Swift natif avec **diarisation temps réel** (pyannote CoreML + clustering)
- Transcription via **Parakeet TDT v3** (25 langues européennes)
- 60x temps réel sur M1 pour la diarisation (0.017 RTF)
- Diarisation online (streaming) et offline (batch)
- **Licence Apache 2.0** | macOS 14+ / iOS 17+
- https://github.com/FluidInference/FluidAudio

### 4. Apple SpeechAnalyzer (WWDC 2025, macOS 26)
- Remplace `SFSpeechRecognizer`, 100% on-device
- API Swift first-class, streaming temps réel, long-form audio
- Liste de langues en expansion, pas de diarisation
- **Nécessite macOS 26** (disponible fin 2025/2026)
- https://developer.apple.com/videos/play/wwdc2025/277/

### 5. speech-swift / MLX-Audio-Swift (Qwen3 ASR)
- Toolkit Swift via MLX (pas de CoreML) : ASR + VAD + diarisation
- **52 langues** via Qwen3 ASR
- Diarisation incluse (Silero VAD v5 + pyannote segmentation 3.0 + WeSpeaker ResNet34)
- Plus récent, moins éprouvé
- https://github.com/ivan-digital/qwen3-asr-swift
- https://github.com/Blaizzy/mlx-audio-swift

### 6. Moonshine (Useful Sensors)
- Modèles légers (27M params pour tiny), optimisés edge
- Anglais principalement + 6 langues séparées (arabe, chinois, japonais, coréen, ukrainien, vietnamien)
- Pas de diarisation, pas multilingue unifié
- Swift package via SPM (ONNX Runtime)
- **Licence MIT**
- https://github.com/moonshine-ai/moonshine
- https://github.com/moonshine-ai/MoonshineNoteTaker

### 7. NVIDIA Parakeet / Canary (via CoreML)
- Parakeet TDT 0.6B v2/v3 : anglais + 25 langues européennes
- Disponible en CoreML via FluidInference
- Canary 1B v2 : multilingue, plus précis, plus lourd
- Intégration via FluidAudio ou chargement CoreML direct
- **Licence Apache 2.0**
- https://huggingface.co/FluidInference/parakeet-tdt-0.6b-v2-coreml

---

## Comparatif

| Solution | Langues | Diarisation | Swift natif | Licence | Maturité |
|---|---|---|---|---|---|
| **WhisperKit** | 99+ | Non (Pro: oui) | Excellente | MIT | Haute |
| **whisper.cpp** | 99+ | Non | Moyenne | MIT | Très haute |
| **FluidAudio** | 25 EU | **Oui** | Excellente | Apache 2.0 | Moyenne |
| **SpeechAnalyzer** | ~croissante | Non | Excellente | Apple | Nouvelle |
| **speech-swift** | 52 | **Oui** | Bonne | Varies | Early |
| **Moonshine** | EN + 6 | Non | Bonne | MIT | Moyenne |

---

## Architecture recommandée

### Option A : Combo open-source (recommandé)
**WhisperKit** (transcription, 99+ langues, MIT) + **FluidAudio** (diarisation, Apache 2.0)
- Les deux sont Swift natifs, optimisés ANE, licences permissives.

### Option B : Tout-en-un payant
**Argmax Pro SDK** : Parakeet V3 (transcription) + pyannoteAI (diarisation)
- $0.42/device/mois

### Option C : Tout-en-un open-source
**speech-swift** (Qwen3 ASR + diarisation via MLX)
- Le plus complet mais le plus jeune/moins éprouvé.

### Option D : Futur Apple-native
Attendre **SpeechAnalyzer** (macOS 26) pour la transcription + **FluidAudio** pour la diarisation.
