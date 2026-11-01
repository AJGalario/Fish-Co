# 🐟 FISH-CO: Adoption Frenzy (Godot 4)

A chaotic aquatic party game inspired by **Move or Die**, **Mario Party**, **Pico Park**, and **Machine Party**.

---

## 🌟 New Features & Minigame Catalogue

### 1. 🏠 Interactive Aquarium Lobby (`scenes/aquarium_lobby/`)
- A physical fish tank menu scene.
- Whenever a player connects or is added, an **aquarium owner's hand reaches into the tank and drops the new fish in with smooth tween physics!**
- Switch between **Co-Op Mode** and **VS. Adoption Mode** directly from the tank controls.

### 2. ⚔️ VS. Mode (The Adoption Grand Prix)
Compete against rivals to accumulate points. The ultimate winner is selected by the owner to be adopted into a luxury fish palace!

1. **Typing Reef Race (`mg_typing_race`):**
   - A paragraph prompt is shown on screen.
   - Players type in real-time — each correct letter propels the fish forward with water thrust. First to finish the paragraph wins!
2. **Flappy Fish (`mg_flappy_fish`):**
   - Flappy Bird style vertical swim rhythm.
   - Press Jump to flap upward through scrolling hazardous coral pillars. Crash and you're out!
3. **Debris Dash (`mg_debris_dash`):**
   - High-speed autoscrolling obstacle course.
   - Dodge sinking ship junk, anchors, and metal scrap. If a fish falls behind the left camera edge, they are swept away and eliminated.
4. **Pellet Frenzy (`mg_pellet_catch` — osu!catch + Slap Stun):**
   - Golden fish flakes rain down across the screen.
   - **Twist:** Press Action (`Space` / `Enter` / Gamepad button) to perform a **Tail Slap** that **stuns nearby rival fishes for 1.5 seconds**, preventing them from collecting pellets!

### 3. 🤝 Co-Op Mode
- Team puzzles requiring simultaneous actions and communication (e.g., `mg_pico_leak` where all fish must coordinate to plug leaks before oxygen runs out).

---

## 🎮 Controls

| Action | Player 1 | Player 2 | Player 3 | Player 4 |
| :--- | :--- | :--- | :--- | :--- |
| **Move Left / Right** | `A` / `D` | `Left` / `Right` Arrow | `J` / `L` | `Numpad 4` / `6` |
| **Jump / Flap** | `W` | `Up` Arrow | `I` | `Numpad 8` |
| **Action / Slap** | `Space` | `Enter` | `U` | `Numpad 5` |
| **Gamepads** | Gamepad 0 | Gamepad 1 | Gamepad 2 | Gamepad 3 |

---

## 🚀 Running the Project

1. Open **Godot 4.x**.
2. Click **Import** and choose `C:\Users\Aaron John\Documents\fish-co\project.godot`.
3. Press **F5** to start from the Main Menu into the Aquarium Lobby!
