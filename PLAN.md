# Implementation Plan: Mass Improvements, Optimizations & Fixes

## Phase 1: Critical Crash Prevention (Data Safety)

### Step 1.1: Add try-catch to jsonDecode in 4 services
Wrap `jsonDecode()` calls with try-catch and fallback to defaults (matching the pattern already used in `StatsService` and `AdaptiveDifficultyService`).

**Files to edit:**
- `lib/services/progress_service.dart` — `_loadProgress()` line 75: wrap `jsonDecode(raw)` in try-catch, fallback to `_progress = {}`
- `lib/services/high_score_service.dart` — `getHighScores()` line 74: wrap `jsonDecode(raw)` in try-catch, return `[]`
- `lib/services/review_service.dart` — `_loadReviews()` line 39: wrap `jsonDecode(raw)` in try-catch, fallback to `_reviews = {}`
- `lib/services/streak_service.dart` — `_load()` line 41: wrap `jsonDecode(raw)` in try-catch, fallback to defaults (0 streak)

### Step 1.2: Add ProgressService dispose + flush in app.dart
- Add `dispose()` method to `ProgressService` that cancels `_saveTimer` and calls `_flushSave()`
- Add `_progressService.dispose()` call in `app.dart` `dispose()` (line 195)

### Step 1.3: Add WidgetsBindingObserver for app lifecycle
In `app.dart` `_ReadingSproutAppState`:
- Add `with WidgetsBindingObserver` mixin
- Register in `initState()`: `WidgetsBinding.instance.addObserver(this)`
- Remove in `dispose()`: `WidgetsBinding.instance.removeObserver(this)`
- Implement `didChangeAppLifecycleState()`:
  - On `paused`/`inactive`: call `_adaptiveMusicService.pause()` and `_progressService.flushSave()`
  - On `resumed`: call `_adaptiveMusicService.resume()`

---

## Phase 2: Null Safety & Crash Prevention

### Step 2.1: Fix 53 Color.lerp force unwraps in avatar_widget.dart
Replace all `Color.lerp(a, b, t)!` with `Color.lerp(a, b, t) ?? a` (fallback to the first color argument). This is a mechanical find-and-replace with contextual awareness:
- Lines 991, 992, 999, 1026, 1045, 1063, 1118, 1137 (skin colors — fallback to `skinColor`)
- Lines 1184, 1185, 1206, 1215, 1236 (ear/nose — fallback to first arg)
- Lines 1498-1595 (eye colors — fallback to `eyeColor`)
- Lines 1670-1798 (eye highlights — fallback to first arg)
- Lines 2043-2077 (effects — fallback to first arg)
- Lines 2210-2512 (mouth — fallback to first arg)
- Lines 2797-3024 (nose — fallback to first arg)
- Lines 3303-3493 (eyebrow/shadow — fallback to first arg)

### Step 2.2: Fix HSLColor.lerp in avatar_options.dart
- Line 87: Replace `HSLColor.lerp(hslA, hslB, t)!.toColor()` with `(HSLColor.lerp(hslA, hslB, t) ?? hslA).toColor()`

### Step 2.3: Fix skeleton bone getters
In `lib/avatar/animation/skeleton.dart` lines 171-193, add debug assertions to the 23 bone getters:
```dart
Bone get head { assert(bones.containsKey('head'), 'head bone missing'); return bones['head']!; }
```
This preserves non-nullable return types (needed throughout avatar rendering) while catching initialization bugs in debug mode.

### Step 2.4: Fix unsafe .first/.last access on dynamic lists
- `lib/screens/mini_games/paint_splash_game.dart` line ~904: Guard `_blobs.first` with isEmpty check
- `lib/screens/mini_games/rhyme_time_game.dart` line ~256: Guard `familyWords.first` with isEmpty check
- `lib/services/high_score_service.dart` line 90: Guard `scores.first` with isEmpty check

---

## Phase 3: Profile & Data Integrity

### Step 3.1: Add switchProfile() to AvatarPersonalityService
In `lib/services/avatar_personality_service.dart`:
- Add `switchProfile(String profileId)` method that:
  - Saves current `_active` if dirty
  - Clears `_active`, `_activeProfileId`, `_sessionCorrect`, `_sessionTotal`
  - Sets `_activeProfileId = profileId`
- Call it from `app.dart` `_applyProfileScope()`

### Step 3.2: Add try-catch to HighScoreService.saveScore()
The `saveScore()` method at line 56 also calls `jsonDecode` indirectly through `getHighScores()`. Ensure the full save path is safe.

---

## Phase 4: Performance — Game Loop Optimization

### Step 4.1: Strategy overview
The key insight: **Element Lab already uses the efficient pattern** (ValueNotifier, no setState). **FloatingHeartsBackground** uses the ChangeNotifier + CustomPainter pattern. We'll adapt games to separate their rendering from widget tree rebuilds.

For each game, the approach is:
1. Extract game state into a `ChangeNotifier` simulation class
2. Move physics/update logic into `tick()` on the simulation
3. Use `CustomPainter(repaint: simulation)` to drive canvas repaints
4. Keep UI overlay widgets (score, buttons) updated via `ValueListenableBuilder` or targeted `setState()` only when score/lives/state changes (not every frame)

### Step 4.2: Games to optimize (by priority — largest/most complex first)
Given the scope (17 games, 25K+ total lines), this is a large refactor. Prioritize by complexity and user-facing impact:

**High priority** (continuous physics, many particles):
1. `word_bubbles_game.dart` (2036 lines) — bubble physics, fish, seaweed, particles
2. `unicorn_flight_game.dart` (2328 lines) — flight physics, obstacles, particles
3. `falling_letters_game.dart` (1899 lines) — gravity, shockwaves, fragments
4. `cat_letter_toss_game.dart` (1613 lines) — projectile physics, targets
5. `paint_splash_game.dart` (1486 lines) — splat physics, particles
6. `star_catcher_game.dart` (1455 lines) — star movement, catching

**Medium priority** (simpler animations):
7. `word_ninja_game.dart` (1330 lines)
8. `word_rocket_game.dart` (977 lines)
9. `word_train_game.dart` (1183 lines)
10. `ladybug_game.dart` (1718 lines)
11. `rhyme_time_game.dart` (1433 lines)
12. `lightning_speller_game.dart` (1509 lines)
13. `letter_drop_game.dart` (1604 lines) — uses Forge2D physics engine

**Low priority** (event-driven, minimal continuous rendering):
14. `memory_match_game.dart` (921 lines) — discrete animations, no game loop
15. `spelling_bee_game.dart` (811 lines)
16. `sight_word_safari_game.dart` (800 lines)
17. `element_lab_game.dart` (4847 lines) — **already optimized** (ValueNotifier pattern)

### Step 4.3: Fix unremoved AnimationController listeners
In `lib/screens/game_screen.dart` (lines 213-230):
- Store `_shakeStatusListener` and `_nudgeStatusListener` as named functions
- Remove them in `dispose()` before calling `.dispose()` on controllers

---

## Phase 5: Image & Asset Optimization

### Step 5.1: Add cacheWidth/cacheHeight to Image.asset() calls
Search all `Image.asset()` calls and add `cacheWidth`/`cacheHeight` where explicit dimensions are provided. Key files:
- `lib/app.dart` (logo)
- `lib/screens/` (any screen with images)

### Step 5.2: Add service init timing
In `app.dart` `_init()`, wrap each service init in a Stopwatch and log any that take > 500ms:
```dart
final sw = Stopwatch()..start();
await _progressService.init(prefs);
if (sw.elapsedMilliseconds > 500) debugPrint('SLOW: ProgressService ${sw.elapsedMilliseconds}ms');
```

---

## Execution Order & Dependencies

```
Phase 1 (Critical) ──→ Phase 2 (Null Safety) ──→ Phase 3 (Data) ──→ Phase 4 (Perf) ──→ Phase 5 (Polish)
  ~30 min                ~45 min                  ~15 min             ~3-4 hrs            ~20 min
```

- Phases 1-3 are independent of each other and can be done in parallel
- Phase 4 is the largest effort and can be done incrementally (game by game)
- Phase 5 is low-risk polish

## Out of Scope (Noted for Future)
- Generating missing `assets/audio/music/` files (requires external tools/composers)
- Generating missing `assets/audio/phrases/` files (requires TTS generation scripts)
- Integrating mini games into adventure mode levels
- Integrating 49 bonus words into adventure
- Screen reader Semantics labels
- Streak data migration from SharedPreferences to Hive
