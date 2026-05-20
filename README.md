# STRUGGLER: The Architect's Trial

STRUGGLER is a dynamic, 2D action platformer powered by AI. Unlike traditional games with static levels, STRUGGLER features an adversarial AI agent known as "The Architect." This AI monitors your gameplay, learns from your telemetry, and generates both the physical map layouts and the dynamic difficulty parameters specifically tailored to torment and challenge you.

## Overall Design & Architecture

The solution is built using **Flutter** and the **Flame Game Engine**, ensuring a performant, cross-platform 2D platforming experience. The game architecture is structured to separate core gameplay logic from AI-driven generation.

### Core Components
1. **Game Engine Layer (Flame)**: Handles physics, collision detection, sprite rendering, audio management, and player inputs (both keyboard and touch controls).
2. **Entity & Component System**: Built on Flame's component system. Entities include the Player, Companion Cat ("Hope"), diverse enemy types (Skeletons, Goblins, Nightborne, Bringers, Archers, Wizards), obstacles (lava, spikes), and items (diamonds, health).
3. **AI Agent Layer**: Interacts with the backend LLM (Gemini) to generate and tune levels. 
4. **Validation System**: A critical `LevelValidator` runs locally to guarantee that the AI-generated maps are physically solvable (e.g., jumps are within maximum allowed heights and gaps). Unsolvable maps trigger a self-correction retry loop or a fallback.

## AI Architecture & Agents Developed

The centerpiece of STRUGGLER is **The Architect**, an LLM-powered adversarial agent acting as the level designer and game master. The Architect is developed using a two-phase architecture to maintain game fluidity without blocking the main loop.

### 1. Phase 1: Map Layout Generation (N-1 Telemetry)
- **Agent Role**: Designs the physical structure of the next level (tiles, enemy placements, and item spawns).
- **Mechanism**: While the player is actively playing Level N, the game pre-fetches the map layout for Level N+1 in the background. It sends telemetry from Level N-1 (deaths, damage taken, time taken, perfect dodges) to the AI.
- **Output**: A JSON blueprint detailing a grid mapping out safe zones, platforms, hazards, and enemy coordinates.

### 2. Phase 2: Dynamic Difficulty & Narrative Tuning (Live N Telemetry)
- **Agent Role**: Tunes the difficulty of the *current* and *next* levels on-the-fly and generates contextual, mocking dialogue.
- **Mechanism**: Triggered mid-level (based on proximity to the exit or remaining enemies), this phase sends live telemetry from the current level.
- **Output**: The AI returns health/damage multipliers and narrative events/taunts. These multipliers dynamically adjust the stats of enemies already spawned in the current level, ensuring real-time responsiveness to the player's immediate performance.

## Integrations Implemented & APIs Used

### Real APIs Used
- **Google Generative AI (Gemini 2.5 Flash)**: The core intelligence powering The Architect. 
- **Google Cloud Platform (Vertex AI)**: Integrated via `googleapis_auth` using Application Default Credentials (ADC). This allows seamless cloud deployment with Vertex AI REST endpoints.
- **Fallback Mechanism**: If ADC is unavailable, the system intelligently falls back to the standard `google_generative_ai` REST client using a standard API Key.

### Integration Flow
1. **State Serialization**: The `PlayerState` and `GameState` serialize complex gameplay metrics into precise JSON structures.
2. **Prompt Engineering**: Highly specialized system prompts define the persona, strict JSON compliance rules, and the mechanics/boundaries of the game world.
3. **Asynchronous Generation**: The `ArchitectAgent` handles HTTP POST requests asynchronously. Responses are deserialized, parsed into internal `LevelData` objects, validated, and cached for the Flame engine to render upon portal transition.

## Technologies Used
- **Dart & Flutter**: Application framework.
- **Flame (`flame`)**: High-performance 2D game engine for Flutter.
- **Google Generative AI SDK**: For LLM interactions.
- **Audioplayers / Flame Audio**: For dynamic BGM and sound effects.

## How to Play
- **Controls**: Use D-Pad/Arrow keys to move. Jump, Dodge, Attack, and Heal using the on-screen action buttons or mapped keyboard inputs.
- **Objective**: Survive the Architect's trials, collect diamonds for Guardian upgrades, and reach the final boss level to decide the Architect's fate.
