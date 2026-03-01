import { AgentSnapshot, SimulationSnapshot } from '../types/snapshot';

export class SoundManager {
  private audioCtx: AudioContext | null = null;
  private masterGain: GainNode | null = null;
  private ambientGain: GainNode | null = null;
  private sfxGain: GainNode | null = null;
  private ambientAudio: HTMLAudioElement | null = null;
  private brookNode: MediaElementAudioSourceNode | null = null;
  private birdTimeout: ReturnType<typeof setTimeout> | null = null;
  private cricketTimeout: ReturnType<typeof setTimeout> | null = null;
  private cricketActive = false;
  private _enabled = false;

  // TTS
  private speechAudioCache = new Map<string, HTMLAudioElement>();
  private lastSpokenHash = new Map<string, string>();

  get enabled() { return this._enabled; }

  toggle() {
    if (!this.audioCtx) {
      this.initAudio();
      return;
    }
    this._enabled = !this._enabled;
    if (this._enabled) {
      this.audioCtx.resume();
      this.masterGain!.gain.value = 1.0;
      this.ambientGain!.gain.value = 0.35;
      if (!this.brookNode) this.startBrookSound();
      this.ambientAudio?.play().catch(() => {});
      this.scheduleBirdChirp();
    } else {
      this.masterGain!.gain.value = 0;
      this.ambientAudio?.pause();
      this.stopBrookSound();
      if (this.birdTimeout) clearTimeout(this.birdTimeout);
      if (this.cricketTimeout) clearTimeout(this.cricketTimeout);
      this.cricketActive = false;
    }
  }

  private initAudio() {
    this.audioCtx = new AudioContext();
    this.masterGain = this.audioCtx.createGain();
    this.masterGain.gain.value = 1.0;
    this.masterGain.connect(this.audioCtx.destination);

    this.ambientGain = this.audioCtx.createGain();
    this.ambientGain.gain.value = 0.35;
    this.ambientGain.connect(this.masterGain);

    this.sfxGain = this.audioCtx.createGain();
    this.sfxGain.gain.value = 0.4;
    this.sfxGain.connect(this.masterGain);

    this._enabled = true;
    this.startBrookSound();
    this.scheduleBirdChirp();
  }

  private startBrookSound() {
    if (this.brookNode) return;
    this.ambientAudio = new Audio('/village-ambient.mp3');
    this.ambientAudio.loop = true;
    this.ambientAudio.volume = 1.0;
    this.ambientAudio.play().catch(() => {});

    if (this.audioCtx) {
      const source = this.audioCtx.createMediaElementSource(this.ambientAudio);
      source.connect(this.ambientGain!);
      this.brookNode = source;
    }
  }

  private stopBrookSound() {
    if (this.ambientAudio) {
      this.ambientAudio.pause();
      this.ambientAudio.currentTime = 0;
    }
    if (this.brookNode) {
      try { this.brookNode.disconnect(); } catch { /* ignore */ }
    }
    this.brookNode = null;
  }

  // Bird chirps
  private scheduleBirdChirp() {
    if (!this._enabled) return;
    const delay = 3000 + Math.random() * 5000;
    this.birdTimeout = setTimeout(() => {
      if (!this._enabled) return;
      this.playBirdChirp();
      if (Math.random() < 0.4) {
        setTimeout(() => { if (this._enabled) this.playBirdChirp(); }, 200 + Math.random() * 150);
      }
      this.scheduleBirdChirp();
    }, delay);
  }

  private playBirdChirp() {
    if (!this.audioCtx || !this._enabled) return;
    const now = this.audioCtx.currentTime;
    const noteCount = 2 + Math.floor(Math.random() * 4);
    let freq = 2400 + Math.random() * 1600;
    let t = now;

    for (let i = 0; i < noteCount; i++) {
      const noteDur = 0.04 + Math.random() * 0.04;
      const osc = this.audioCtx.createOscillator();
      const gain = this.audioCtx.createGain();
      osc.type = 'sine';
      osc.frequency.setValueAtTime(freq, t);
      gain.gain.setValueAtTime(0, t);
      gain.gain.linearRampToValueAtTime(0.07, t + 0.005);
      gain.gain.linearRampToValueAtTime(0, t + noteDur);
      osc.connect(gain);
      gain.connect(this.ambientGain!);
      osc.start(t);
      osc.stop(t + noteDur + 0.01);
      t += noteDur + 0.005;
      freq += (Math.random() - 0.4) * 600;
      freq = Math.max(2400, Math.min(4000, freq));
    }
  }

  // Crickets (night only)
  updateCrickets(snapshot: SimulationSnapshot | null) {
    const isNight = snapshot?.dayPeriod === 'night';
    if (isNight && this._enabled && !this.cricketActive) {
      this.cricketActive = true;
      this.scheduleCricketBurst();
    } else if (!isNight && this.cricketActive) {
      this.cricketActive = false;
      if (this.cricketTimeout) clearTimeout(this.cricketTimeout);
    }
  }

  private scheduleCricketBurst() {
    if (!this.cricketActive || !this._enabled) return;
    const delay = 5000 + Math.random() * 10000;
    this.cricketTimeout = setTimeout(() => {
      if (!this.cricketActive || !this._enabled) return;
      this.playCricketBurst();
      this.scheduleCricketBurst();
    }, delay);
  }

  private playCricketBurst() {
    if (!this.audioCtx || !this._enabled) return;
    const now = this.audioCtx.currentTime;
    const duration = 0.5 + Math.random() * 1.5;

    const osc = this.audioCtx.createOscillator();
    osc.type = 'sine';
    osc.frequency.value = 4800;

    const modOsc = this.audioCtx.createOscillator();
    modOsc.type = 'square';
    modOsc.frequency.value = 28;

    const modGain = this.audioCtx.createGain();
    modGain.gain.value = 0;

    const shaper = this.audioCtx.createGain();
    shaper.gain.value = 0.03;

    osc.connect(shaper);
    modOsc.connect(modGain);
    modGain.connect(shaper.gain);

    const env = this.audioCtx.createGain();
    env.gain.setValueAtTime(0, now);
    env.gain.linearRampToValueAtTime(1, now + 0.05);
    env.gain.setValueAtTime(1, now + duration - 0.05);
    env.gain.linearRampToValueAtTime(0, now + duration);

    shaper.connect(env);
    env.connect(this.ambientGain!);

    modOsc.start(now);
    osc.start(now);
    modOsc.stop(now + duration);
    osc.stop(now + duration);
  }

  // SFX
  sfxFoodDrop() {
    if (!this.audioCtx || !this._enabled) return;
    const now = this.audioCtx.currentTime;
    const osc = this.audioCtx.createOscillator();
    const gain = this.audioCtx.createGain();
    osc.type = 'sine';
    osc.frequency.setValueAtTime(600, now);
    osc.frequency.exponentialRampToValueAtTime(200, now + 0.15);
    gain.gain.setValueAtTime(0.3, now);
    gain.gain.exponentialRampToValueAtTime(0.001, now + 0.2);
    osc.connect(gain);
    gain.connect(this.sfxGain!);
    osc.start(now);
    osc.stop(now + 0.25);
  }

  sfxSpeech() {
    if (!this.audioCtx || !this._enabled) return;
    const now = this.audioCtx.currentTime;
    const osc = this.audioCtx.createOscillator();
    const gain = this.audioCtx.createGain();
    osc.type = 'triangle';
    osc.frequency.setValueAtTime(800 + Math.random() * 400, now);
    gain.gain.setValueAtTime(0.12, now);
    gain.gain.exponentialRampToValueAtTime(0.001, now + 0.1);
    osc.connect(gain);
    gain.connect(this.sfxGain!);
    osc.start(now);
    osc.stop(now + 0.12);
  }

  sfxEat() {
    if (!this.audioCtx || !this._enabled) return;
    const now = this.audioCtx.currentTime;
    const freqs = [300, 400];
    for (let i = 0; i < 2; i++) {
      const osc = this.audioCtx.createOscillator();
      const gain = this.audioCtx.createGain();
      osc.type = 'square';
      osc.frequency.setValueAtTime(freqs[i], now + i * 0.08);
      gain.gain.setValueAtTime(0.08, now + i * 0.08);
      gain.gain.exponentialRampToValueAtTime(0.001, now + i * 0.08 + 0.08);
      osc.connect(gain);
      gain.connect(this.sfxGain!);
      osc.start(now + i * 0.08);
      osc.stop(now + i * 0.08 + 0.1);
    }
  }

  sfxCelebration() {
    if (!this.audioCtx || !this._enabled) return;
    const now = this.audioCtx.currentTime;
    const freqs = [400, 500, 600, 800];
    for (let i = 0; i < freqs.length; i++) {
      const osc = this.audioCtx.createOscillator();
      const gain = this.audioCtx.createGain();
      osc.type = 'sine';
      osc.frequency.setValueAtTime(freqs[i], now + i * 0.1);
      gain.gain.setValueAtTime(0.15, now + i * 0.1);
      gain.gain.exponentialRampToValueAtTime(0.001, now + i * 0.1 + 0.15);
      osc.connect(gain);
      gain.connect(this.sfxGain!);
      osc.start(now + i * 0.1);
      osc.stop(now + i * 0.1 + 0.2);
    }
  }

  // TTS
  playTTS(agent: AgentSnapshot) {
    if (!this._enabled || !agent.currentSpeech) return;
    const hash = agent.speechHash;
    if (!hash) { this.sfxSpeech(); return; }
    if (this.lastSpokenHash.get(agent.id) === hash) return;
    this.lastSpokenHash.set(agent.id, hash);

    const url = '/api/tts/' + hash + '.mp3';

    const cached = this.speechAudioCache.get(hash);
    if (cached) {
      cached.currentTime = 0;
      cached.play().catch(() => {});
      return;
    }

    const audio = new Audio(url);
    audio.volume = 0.7;
    audio.addEventListener('canplaythrough', () => {
      this.speechAudioCache.set(hash, audio);
      audio.play().catch(() => {});
    }, { once: true });
    audio.addEventListener('error', () => {
      this.sfxSpeech();
    }, { once: true });
    audio.load();
  }

  destroy() {
    this.stopBrookSound();
    if (this.birdTimeout) clearTimeout(this.birdTimeout);
    if (this.cricketTimeout) clearTimeout(this.cricketTimeout);
    if (this.audioCtx) this.audioCtx.close();
  }
}
