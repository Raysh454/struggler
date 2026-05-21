# STRUGGLER: The Architect's Trial

STRUGGLER is a dynamic, 2D action platformer powered by **Google Antigravity**. Unlike traditional games with static levels, STRUGGLER features an adversarial Antigravity agent known as "The Architect." Acting as the game's core orchestrator and intelligent "Dungeon Master," this agent monitors your gameplay, learns from your telemetry, and generates both the physical map layouts and the dynamic difficulty parameters specifically tailored to torment and challenge you, ensuring infinite variety and a personalized rivalry.

## Overall Design & Architecture

The solution is built using **Flutter** and the **Flame Game Engine**, ensuring a performant, cross-platform 2D platforming experience. The game architecture is structured to separate core gameplay logic from AI-driven generation.

### Core Components
1. **Game Engine Layer (Flame)**: Handles physics, collision detection, sprite rendering, audio management, and player inputs (both keyboard and touch controls).
2. **Entity & Component System**: Built on Flame's component system. Entities include the Player, Companion Cat ("Hope"), diverse enemy types (Skeletons, Goblins, Nightborne, Bringers, Archers, Wizards), obstacles (lava, spikes), and items (diamonds, health).
3. **Antigravity Agent Layer**: Serves as the primary orchestrator. Uses structured agent workflows to manage the "brain" of the game, generating endless, balanced challenges and live narrative events.
4. **Validation System**: A critical `LevelValidator` acts as a "referee," running locally to guarantee that the agent-generated maps are physically solvable and fair. Unsolvable maps trigger an Antigravity self-correction retry loop or a fallback.

## Google Antigravity & Agentic Workflows

The centerpiece of STRUGGLER is **The Architect**, a Google Antigravity-powered adversarial agent acting as the level designer and game orchestrator. The Architect is developed using a two-phase structured reasoning workflow to maintain game fluidity, driving gameplay logic and creating a deeply engaging Action → Feedback → Reward loop.

### 1. Phase 1: Map Layout Generation (N-1 Telemetry)
- **Agent Role**: Drives the core logic for the environment. Designs the physical structure of the next level (tiles, enemy placements, and item spawns) to provide **Infinite Variety**.
- **Mechanism**: While the player is actively playing Level N, the game pre-fetches the map layout for Level N+1 in the background. It sends structured telemetry from Level N-1 (deaths, damage taken, time taken, perfect dodges) to the Antigravity orchestrator.
- **Output**: The agent reasons through the game state and outputs a JSON blueprint detailing a grid mapping out safe zones, platforms, hazards, and enemy coordinates.

### 2. Phase 2: Dynamic Difficulty & Narrative Tuning (Live N Telemetry)
- **Agent Role**: Tunes the difficulty of the *current* and *next* levels on-the-fly, acting as a **Smart Rival** and driving a **Living Narrative** through contextual, mocking dialogue.
- **Mechanism**: Triggered mid-level (based on proximity to the exit or remaining enemies), this phase sends live telemetry from the current level to assess real-time player behavior.
- **Output**: The Antigravity agent returns health/damage multipliers and narrative events/taunts. These multipliers dynamically adjust the stats of enemies already spawned in the current level, ensuring real-time responsiveness and an evolving, personalized rivalry.

## Integrations Implemented & APIs Used

### Agentic Execution APIs
- **Google Antigravity / Generative AI (Gemini 2.5 Flash)**: The core reasoning intelligence powering The Architect agent workflow.
- **Cloud Functions Relay Gateway**: Integrated via an asynchronous HTTP relay gateway (`https://us-central1-struggler-496812.cloudfunctions.net/architect-relay`). This serves as a secure proxy to forward structured telemetry payloads to Gemini/Vertex AI, eliminating the need to compile local API keys or store Application Default Credentials (ADC) on client/mobile devices.

### Integration Flow
1. **State Serialization**: The `PlayerState` and `GameState` serialize complex gameplay metrics into precise JSON structures.
2. **Prompt Engineering**: Highly specialized system prompts define the persona, strict JSON compliance rules, and the mechanics/boundaries of the game world.
3. **Asynchronous Generation**: The `ArchitectAgent` handles HTTP POST requests asynchronously to the Cloud Functions relay gateway. Responses are deserialized, parsed into internal `LevelData` objects, validated, and cached for the Flame engine to render upon portal transition.

## Technologies Used
- **Dart & Flutter**: Application framework.
- **Flame (`flame`)**: High-performance 2D game engine for Flutter.
- **HTTP client**: For secure, lightweight REST communications with the Cloud Functions relay gateway.
- **Audioplayers / Flame Audio**: For dynamic BGM and sound effects.

## How to Play
- **Controls**: Use D-Pad/Arrow keys to move. Jump, Dodge, Attack, and Heal using the on-screen action buttons or mapped keyboard inputs.
- **Objective**: Survive the Architect's trials, collect diamonds for Guardian upgrades, and reach the final boss level to decide the Architect's fate.
