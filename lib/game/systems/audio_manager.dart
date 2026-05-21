import 'dart:math';
import 'package:flame_audio/flame_audio.dart';
import 'package:audioplayers/audioplayers.dart';

/// Centralized audio manager for all SFX and BGM in the game.
///
/// All audio file names reference files in `assets/audio/`.
/// Call [preloadAll] once during game initialization to cache assets.
class AudioManager {
  AudioManager._();

  static bool _initialized = false;

  // Volume controls
  static double sfxVolume = 0.7;
  static double bgmVolume = 0.5;

  // Current BGM track name (to avoid restarting the same track)
  static String? _currentBgm;

  // SFX Player Pool to avoid GStreamer file descriptor leaks / crash
  static const int _poolSize = 8;
  static final List<AudioPlayer> _sfxPlayers = [];
  static int _sfxIndex = 0;

  static AudioPlayer _createSfxPlayer() {
    final player = AudioPlayer();
    player.setAudioContext(AudioContext(
      android: const AudioContextAndroid(
        stayAwake: false,
        contentType: AndroidContentType.sonification,
        usageType: AndroidUsageType.game,
        audioFocus: AndroidAudioFocus.none,
      ),
      iOS: AudioContextIOS(
        category: AVAudioSessionCategory.ambient,
      ),
    ));
    return player;
  }

  // Footstep throttle
  static double _footstepTimer = 0;
  static const double _footstepInterval = 0.28;

  // Random for variant picking
  static final Random _rng = Random();

  // ── Audio file constants ──────────────────────────────────────────────────

  // Music
  static const String musicMenu = 'Anthem_for_the_Unmade.mp3';
  static const String musicGameplay = 'background_music.wav';

  // Player SFX
  static const String sfxSwordAttack1 = 'Sword Attack 1.wav';
  static const String sfxSwordAttack2 = 'Sword Attack 2.wav';
  static const String sfxSwordAttack3 = 'Sword Attack 3.wav';
  static const String sfxSwordHit1 = 'Sword Impact Hit 1.wav';
  static const String sfxSwordHit2 = 'Sword Impact Hit 2.wav';
  static const String sfxSwordHit3 = 'Sword Impact Hit 3.wav';
  static const String sfxPlungeAttack = 'plunge_attack.wav';
  static const String sfxJump = 'Stone Jump.wav';
  static const String sfxLand = 'Stone Land.wav';
  static const String sfxFootstep = 'Stone Run 2.wav';
  static const String sfxDodge = 'dodge.wav';
  static const String sfxSpikeDamage = 'spike_damage.wav';
  static const String sfxLavaDamage = 'lava_damage.wav';
  static const String sfxDiamond = 'diamond.wav';
  static const String sfxHeart = 'heart.wav';
  static const String sfxIndomitable = 'indomitable.wav';

  // Enemy SFX
  static const String sfxBowAttack = 'Bow Attack 2.wav';
  static const String sfxBowHit = 'Bow Impact Hit 1.wav';
  static const String sfxFireball = 'Fireball 1.wav';
  static const String sfxSpellHit = 'Spell Impact 1.wav';
  static const String sfxThunderImpact = 'thunder_hand_impact.wav';
  static const String sfxNightborneExplosion = 'nightborne_explosion.wav';
  static const String sfxNightborneAttack = 'nightborne_attack.wav';
  static const String sfxHopeAttack = 'hope_attack.wav';
  // UI SFX
  static const String sfxSelect = 'select_1.wav';

  // ── Preloading ────────────────────────────────────────────────────────────

  /// Pre-cache all audio assets. Call once during game onLoad.
  static Future<void> preloadAll() async {
    if (_initialized) return;
    try {
      await FlameAudio.audioCache.loadAll([
        sfxSwordAttack1,
        sfxSwordAttack2,
        sfxSwordAttack3,
        sfxSwordHit1,
        sfxSwordHit2,
        sfxSwordHit3,
        sfxPlungeAttack,
        sfxJump,
        sfxLand,
        sfxFootstep,
        sfxBowAttack,
        sfxBowHit,
        sfxFireball,
        sfxSpellHit,
        sfxThunderImpact,
        sfxNightborneExplosion,
        sfxNightborneAttack,
        sfxHopeAttack,
        sfxDodge,
        sfxSpikeDamage,
        sfxLavaDamage,
        sfxDiamond,
        sfxHeart,
        sfxIndomitable,
        sfxSelect,
        musicGameplay,
        musicMenu,
      ]);

      // Initialize SFX Player Pool
      _sfxPlayers.clear();
      for (int i = 0; i < _poolSize; i++) {
        _sfxPlayers.add(_createSfxPlayer());
      }

      _initialized = true;
      print('[AudioManager] All audio assets preloaded.');
    } catch (e) {
      print('[AudioManager] WARNING: Failed to preload audio: $e');
    }
  }

  // ── SFX ────────────────────────────────────────────────────────────────────

  /// Play a one-shot sound effect using the fixed player pool.
  static void playSfx(String filename, {double volume = 1.0}) async {
    try {
      if (_sfxPlayers.isEmpty) {
        // Fallback initialization if preloadAll wasn't called/finished yet
        for (int i = 0; i < _poolSize; i++) {
          _sfxPlayers.add(_createSfxPlayer());
        }
      }
      final player = _sfxPlayers[_sfxIndex];
      _sfxIndex = (_sfxIndex + 1) % _poolSize;

      // Stop previous playing sound on this player, set volume, and play
      await player.stop();
      await player.setVolume(volume * sfxVolume);
      // audioplayers package automatically prefixes with assets/
      await player.play(AssetSource('audio/$filename'));
    } catch (e) {
      print('[AudioManager] SFX play error ($filename): $e');
    }
  }

  /// Play a random player sword attack sound (combo variants).
  static void playPlayerAttack(int comboStep) {
    switch (comboStep) {
      case 0:
        playSfx(sfxSwordAttack1);
        break;
      case 1:
        playSfx(sfxSwordAttack2);
        break;
      default:
        playSfx(sfxSwordAttack3);
        break;
    }
  }

  /// Play a random melee enemy sword attack sound.
  static void playEnemyMeleeAttack() {
    playSfx(_rng.nextBool() ? sfxSwordAttack2 : sfxSwordAttack3);
  }

  /// Play a random melee enemy hit-on-player sound.
  static void playEnemyMeleeHit() {
    playSfx(_rng.nextBool() ? sfxSwordHit2 : sfxSwordHit3);
  }

  /// Play footstep sound, throttled to avoid spam. Call every frame while moving.
  /// Returns true if the sound was actually played.
  static bool playFootstep(double dt) {
    _footstepTimer -= dt;
    if (_footstepTimer <= 0) {
      _footstepTimer = _footstepInterval;
      playSfx(sfxFootstep, volume: 0.4);
      return true;
    }
    return false;
  }

  /// Reset footstep timer (e.g. when player stops moving).
  static void resetFootstepTimer() {
    _footstepTimer = 0;
  }

  // ── BGM ────────────────────────────────────────────────────────────────────

  /// Play background music (looping). Skips if already playing the same track.
  static void playBgm(String filename) {
    if (_currentBgm == filename) return;
    try {
      _currentBgm = filename;
      FlameAudio.bgm.play(filename, volume: bgmVolume);
      print('[AudioManager] BGM playing: $filename');
    } catch (e) {
      print('[AudioManager] BGM play error ($filename): $e');
    }
  }

  /// Stop the current background music.
  static void stopBgm() {
    try {
      _currentBgm = null;
      FlameAudio.bgm.stop();
      print('[AudioManager] BGM stopped.');
    } catch (e) {
      print('[AudioManager] BGM stop error: $e');
    }
  }

  /// Pause the current background music.
  static void pauseBgm() {
    try {
      FlameAudio.bgm.pause();
    } catch (e) {
      print('[AudioManager] BGM pause error: $e');
    }
  }

  /// Resume the paused background music.
  static void resumeBgm() {
    try {
      FlameAudio.bgm.resume();
    } catch (e) {
      print('[AudioManager] BGM resume error: $e');
    }
  }

  /// Play the appropriate music for a given level.
  static void playMusicForLevel(int levelId) {
    if (levelId == 10) {
      // Boss fight — epic anthem
      playBgm(musicMenu); // Anthem_for_the_Unmade.mp3
    } else if (levelId == -1) {
      // Guardian Realm — keep current music
    } else {
      // Normal gameplay levels
      playBgm(musicGameplay);
    }
  }

  /// Play the main menu music.
  static void playMenuMusic() {
    playBgm(musicMenu);
  }

  /// Dispose BGM resources. Call on app shutdown.
  static void dispose() {
    try {
      FlameAudio.bgm.dispose();
      for (final player in _sfxPlayers) {
        player.dispose();
      }
      _sfxPlayers.clear();
    } catch (e) {
      print('[AudioManager] Dispose error: $e');
    }
  }
}
