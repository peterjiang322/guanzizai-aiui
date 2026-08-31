const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');

const projectRoot = path.resolve(__dirname, '..');
const appFile = path.join(projectRoot, 'app.json');
const indexFile = path.join(projectRoot, 'pages/index/index.ink');
const meditationFile = path.join(projectRoot, 'pages/meditation/meditation.ink');
const soundscapeFile = path.join(projectRoot, 'pages/soundscape/soundscape.ink');

function extractSetup(source) {
  const match = source.match(/<script setup>\s*([\s\S]*?)<\/script>/);
  assert.ok(match, 'expected an AIUI <script setup> block');
  return match[1]
    .replace(/import wx from ['"]wx['"];?/, '')
    .replace(/export default\s*\{/, 'globalThis.__pageDefinition = {');
}

function loadMeditation(options = {}, sharedWx) {
  const players = [];
  const sounds = [];
  const recognitions = [];
  const intervals = new Map();
  const timeouts = new Map();
  let nextTimerId = 1;

  class FakeAudioPlayer {
    constructor() {
      if (options.audioPlayerConstructorThrows) {
        throw new Error('AudioPlayer constructor failed');
      }
      this.src = '';
      this.loop = false;
      this.volume = 1;
      this.playCalls = 0;
      this.pauseCalls = 0;
      this.stopCalls = 0;
      this.destroyCalls = 0;
      players.push(this);
    }
    play() {
      this.playCalls += 1;
      if (options.audioPlayerErrorOnInitialPlay && this.playCalls === 1 && typeof this.errorHandler === 'function') {
        this.errorHandler(new Error('AudioPlayer initial play emitted an error'));
      }
      if (options.audioPlayerResumeThrows && this.playCalls > 1) {
        throw new Error('AudioPlayer resume failed');
      }
    }
    pause() {
      this.pauseCalls += 1;
      if (options.audioPlayerErrorOnPause && typeof this.errorHandler === 'function') {
        this.errorHandler(new Error('AudioPlayer pause emitted an error'));
      }
      if (options.audioPlayerPauseThrows) {
        throw new Error('AudioPlayer pause failed');
      }
    }
    stop() { this.stopCalls += 1; }
    destroy() { this.destroyCalls += 1; }
    onEnded(handler) { this.endedHandler = handler; }
    onError(handler) { this.errorHandler = handler; }
  }

  if (options.audioPlayerEndedUnavailable) {
    FakeAudioPlayer.prototype.onEnded = undefined;
  }

  class FakeSound {
    constructor(src) {
      this.src = src;
      this.volume = 1;
      this.playCalls = 0;
      this.stopCalls = 0;
      this.destroyCalls = 0;
      sounds.push(this);
    }
    play() {
      this.playCalls += 1;
      if (options.soundPlayThrows) {
        throw new Error('Sound play failed');
      }
    }
    stop() { this.stopCalls += 1; }
    destroy() { this.destroyCalls += 1; }
  }

  const sandboxMath = Object.create(Math);
  sandboxMath.random = options.random || (() => 0);

  const wx = sharedWx || {
    navigateBack() {},
    speech: { playTTS() {} }
  };
  const sandbox = {
    console,
    Math: sandboxMath,
    Date,
    SpeechRecognition: function SpeechRecognition() {
      this.abortCalls = 0;
      this.start = function start() {};
      this.abort = function abort() {
        this.abortCalls += 1;
        if (typeof this.onend === 'function') { this.onend(); }
      };
      recognitions.push(this);
    },
    SpeechSynthesisUtterance: function SpeechSynthesisUtterance(text) { this.text = text; },
    speechSynthesis: { speak() {} },
    wx,
    Sound: FakeSound,
    setInterval(handler) {
      const id = nextTimerId++;
      intervals.set(id, handler);
      return id;
    },
    clearInterval(id) { intervals.delete(id); },
    setTimeout(handler) {
      const id = nextTimerId++;
      timeouts.set(id, handler);
      return id;
    },
    clearTimeout(id) { timeouts.delete(id); }
  };

  if (!options.audioPlayerUnavailable) {
    sandbox.AudioPlayer = FakeAudioPlayer;
  }

  vm.runInNewContext(extractSetup(fs.readFileSync(meditationFile, 'utf8')), sandbox, {
    filename: meditationFile
  });

  const definition = sandbox.__pageDefinition;
  const page = Object.assign({}, definition);
  page.data = JSON.parse(JSON.stringify(definition.data));
  page.setData = function setData(patch) {
    if (options.deferPausedStatus && patch.status === 'paused') {
      return;
    }
    if (options.deferRunningStatus && patch.status === 'running') {
      const withoutStatus = Object.assign({}, patch);
      delete withoutStatus.status;
      Object.assign(page.data, withoutStatus);
      return;
    }
    Object.assign(page.data, patch);
  };

  return {
    page,
    wx,
    players,
    sounds,
    recognitions,
    pendingTimeoutCount() { return timeouts.size; },
    runLatestTimeout() {
      const entries = Array.from(timeouts.entries());
      assert.ok(entries.length > 0, 'expected an active timeout');
      const [id, handler] = entries[entries.length - 1];
      timeouts.delete(id);
      handler();
    },
    runLatestInterval() {
      const handlers = Array.from(intervals.values());
      assert.ok(handlers.length > 0, 'expected an active interval');
      handlers[handlers.length - 1]();
    },
    runAudioLoopInterval() {
      const id = wx._bgmLoopTimer;
      assert.ok(id, 'expected an active audio loop interval');
      const handler = intervals.get(id);
      assert.equal(typeof handler, 'function', 'expected audio loop timer to belong to this page');
      handler();
    },
    runBreathInterval() {
      const id = this.page._breathTimer;
      assert.ok(id, 'expected an active breathing interval');
      const handler = intervals.get(id);
      assert.equal(typeof handler, 'function', 'expected breathing timer to belong to this page');
      handler();
    }
  };
}

test('parses minute and hour voice durations into bounded minutes', () => {
  const { page } = loadMeditation();

  assert.equal(page.parseDuration('1分钟'), 1);
  assert.equal(page.parseDuration('三十分钟'), 30);
  assert.equal(page.parseDuration('90分钟'), 90);
  assert.equal(page.parseDuration('1小时'), 60);
  assert.equal(page.parseDuration('一个小时'), 60);
  assert.equal(page.parseDuration('两小时'), 120);
  assert.equal(page.parseDuration('1小时30分钟'), 90);
  assert.equal(page.parseDuration('一小时十五分钟'), 75);
  assert.equal(page.parseDuration('请设置一小时三十分钟'), 90);
  assert.equal(page.parseDuration('我想冥想30分钟'), 30);
});

test('rejects invalid or out-of-range voice durations', () => {
  const { page } = loadMeditation();

  assert.equal(page.parseDuration('0分钟'), 0);
  assert.equal(page.parseDuration('121分钟'), 0);
  assert.equal(page.parseDuration('3小时'), 0);
  assert.equal(page.parseDuration('随便坐一会儿'), 0);
});

test('cycles forward through all six meditation duration presets', () => {
  const { page } = loadMeditation();
  const seen = [];
  page.data.step = 'duration';

  for (let i = 0; i < 6; i += 1) {
    seen.push(page.data.durationMinutes);
    page.onKeyUp({ code: 'ArrowUp' });
  }

  assert.deepEqual(seen, [10, 20, 30, 60, 1, 5]);
  assert.equal(page.data.durationMinutes, 10);
});

test('duration prompt tells users they can speak minutes or hours', () => {
  const { page } = loadMeditation();

  page.confirmType();

  assert.match(page.data.statusText, /分钟或小时/);
});

test('standalone white-noise entry is removed but its source and assets remain', () => {
  const app = JSON.parse(fs.readFileSync(appFile, 'utf8'));
  const indexSource = fs.readFileSync(indexFile, 'utf8');
  const meditationSource = fs.readFileSync(meditationFile, 'utf8');

  assert.equal(app.pages.includes('pages/soundscape/soundscape'), false);
  assert.equal(indexSource.includes('/pages/soundscape/soundscape'), false);
  assert.equal(indexSource.includes('白噪音'), false);
  assert.match(meditationSource, /\.timer-ring-stage \{[^}]*width: 194px;[^}]*height: 194px;/s);
  assert.match(meditationSource, /\.timer-halo \{[^}]*border: 4px solid #40FF5E;/s);
  assert.match(meditationSource, /\.timer-ring \{[^}]*border: 3px solid transparent;[^}]*background-color: transparent;/s);
  assert.match(meditationSource, /\.timer-ring-inner \{[^}]*background: transparent;/s);
  assert.equal(meditationSource.includes('style="{{ringStyle}} opacity: {{ringOpacity}};"'), false);
  assert.equal(fs.existsSync(soundscapeFile), true);

  for (const file of [
    'morning_temple.wav',
    'rain_zen.wav',
    'stream_forest.wav',
    'ocean_mindfulness.wav',
    'night_temple.wav',
    'incense_chamber.wav'
  ]) {
    assert.equal(fs.existsSync(path.join(projectRoot, 'assets', file)), true, file);
  }
});

test('meditation guide text uses a font size two pixels smaller', () => {
  const meditationSource = fs.readFileSync(meditationFile, 'utf8');

  assert.match(meditationSource, /\.hint-scroll \{[^}]*font-size: 14px;/s);
});

test('each meditation opening guide puts the eye-closing instruction last', () => {
  const meditationSource = fs.readFileSync(meditationFile, 'utf8');

  for (const guide of [
    '将注意力带到鼻尖。吸气，感受清凉的空气进入身体；呼气，感受温热的气息缓缓离开。不必刻意控制呼吸的深浅快慢，只是觉知它本来的样子。缓缓闭上眼睛。',
    '从头顶开始。感受头顶的皮肤，觉察那里细微的触感。慢慢向下，经过额头、眉间，放松眼睑，让面部的每一寸肌肉自然舒展。闭上眼睛。',
    '脊背挺直而不僵硬，如同松树扎根于山间。双手自然安放，舌抵上颚，面带微笑。让身体稳稳地坐着，如山如石。轻轻闭上眼睛。'
  ]) {
    assert.ok(meditationSource.includes('"' + guide + '"'), guide);
  }
});

test('a meditation starts one AudioPlayer track at 15 percent volume', () => {
  const fixture = loadMeditation({ random: () => 0 });
  fixture.page.data.durationMinutes = 5;
  fixture.page.startMeditation();

  assert.equal(fixture.players.length, 1);
  assert.equal(fixture.players[0].src, '../../assets/morning_temple.wav');
  assert.equal(fixture.players[0].loop, false);
  assert.equal(fixture.players[0].volume, 0.15);
  assert.equal(fixture.players[0].playCalls, 1);
  assert.equal(typeof fixture.players[0].endedHandler, 'undefined');
  assert.equal(fixture.wx._bgmPlayCount, 1);
  assert.equal(fixture.wx._bgmMaxPlays, 100);
});

test('meditation stores the shared player on wx._bgm', () => {
  const fixture = loadMeditation({ random: () => 0 });
  fixture.page.startMeditation();

  assert.equal(fixture.wx._bgm, fixture.players[0]);
  assert.equal(fixture.players[0].loop, false);
});

test('hiding the meditation page does not pause or destroy shared background audio', () => {
  const fixture = loadMeditation({ random: () => 0 });
  fixture.page.startMeditation();
  const player = fixture.players[0];

  fixture.page.onHide();

  assert.equal(player.pauseCalls, 0);
  assert.equal(player.stopCalls, 0);
  assert.equal(player.destroyCalls, 0);
  assert.equal(fixture.wx._bgm, player);
});

test('meditation completion stops, destroys, and clears wx._bgm', () => {
  const fixture = loadMeditation({ random: () => 0 });
  fixture.page.startMeditation();
  const player = fixture.players[0];
  fixture.page.data.remainingSeconds = 1;

  fixture.runLatestInterval();

  assert.equal(player.stopCalls, 1);
  assert.equal(player.destroyCalls, 1);
  assert.equal(fixture.wx._bgm, null);
});

test('pause and resume control the same AudioPlayer instance', () => {
  const fixture = loadMeditation({ random: () => 0.5 });
  fixture.page.startMeditation();
  const player = fixture.players[0];

  fixture.page.togglePause();
  assert.equal(fixture.page.data.status, 'paused');
  assert.equal(player.pauseCalls, 1);

  fixture.page.togglePause();
  assert.equal(fixture.page.data.status, 'running');
  assert.equal(player.playCalls, 2);
  assert.equal(fixture.players.length, 1);
});

test('countdown completion stops and destroys playback', () => {
  const fixture = loadMeditation({ random: () => 0 });
  fixture.page.startMeditation();
  const player = fixture.players[0];
  fixture.page.data.remainingSeconds = 1;

  fixture.runLatestInterval();

  assert.equal(player.stopCalls, 1);
  assert.equal(player.destroyCalls, 1);
  assert.equal(fixture.page.data.status, 'completed');
});

test('hiding an active meditation keeps its countdown and shared audio running', () => {
  const fixture = loadMeditation({ random: () => 0 });
  fixture.page.startMeditation();
  const player = fixture.players[0];

  fixture.page.onHide();

  assert.equal(fixture.page.data.status, 'running');
  assert.equal(player.pauseCalls, 0);
  assert.equal(player.stopCalls, 0);
  assert.equal(fixture.wx._bgm, player);
});

test('running meditation breathes from bright to dim and back to bright', () => {
  const fixture = loadMeditation({ random: () => 0 });
  fixture.page.startMeditation();

  assert.ok(fixture.page._breathTimer);
  assert.equal(fixture.page.data.ringOpacity, 1);

  fixture.runBreathInterval();
  assert.ok(fixture.page.data.ringOpacity < 1);
  assert.ok(fixture.page.data.ringOpacity > 0.35);
  const brightHaloStyle = fixture.page.data.haloStyle;
  assert.match(brightHaloStyle, /border-color: rgba\(64,255,94,/);
  assert.equal(brightHaloStyle.includes('transform:'), false);
  const brightWidth = Number(brightHaloStyle.match(/width: ([\d.]+)px/)[1]);
  const brightLeft = Number(brightHaloStyle.match(/left: ([\d.]+)px/)[1]);
  const brightCenter = brightLeft + ((brightWidth + 8) / 2);
  assert.ok(Math.abs(brightCenter - 97) < 0.01);

  for (let i = 0; i < 29; i += 1) {
    fixture.runBreathInterval();
  }
  const dimOpacity = fixture.page.data.ringOpacity;
  assert.ok(dimOpacity <= 0.21);
  const dimHaloStyle = fixture.page.data.haloStyle;
  assert.notEqual(dimHaloStyle, brightHaloStyle);
  const dimWidth = Number(dimHaloStyle.match(/width: ([\d.]+)px/)[1]);
  const dimLeft = Number(dimHaloStyle.match(/left: ([\d.]+)px/)[1]);
  const dimCenter = dimLeft + ((dimWidth + 8) / 2);
  assert.ok(dimWidth < brightWidth);
  assert.ok(Math.abs(dimCenter - 97) < 0.01);

  for (let i = 0; i < 30; i += 1) {
    fixture.runBreathInterval();
  }
  assert.ok(fixture.page.data.ringOpacity > dimOpacity);
  assert.notEqual(fixture.page.data.haloStyle, dimHaloStyle);
  const brightenedWidth = Number(fixture.page.data.haloStyle.match(/width: ([\d.]+)px/)[1]);
  assert.ok(brightenedWidth > dimWidth);
});

test('pausing freezes breath opacity and resume restores one breathing timer', () => {
  const fixture = loadMeditation({ random: () => 0 });
  fixture.page.startMeditation();
  fixture.runBreathInterval();
  const pausedOpacity = fixture.page.data.ringOpacity;
  const pausedHaloStyle = fixture.page.data.haloStyle;

  fixture.page.togglePause();
  assert.equal(fixture.page._breathTimer, null);
  assert.equal(fixture.page.data.ringOpacity, pausedOpacity);
  assert.equal(fixture.page.data.haloStyle, pausedHaloStyle);

  fixture.page.togglePause();
  assert.ok(fixture.page._breathTimer);
  assert.equal(fixture.page.data.ringOpacity, pausedOpacity);
  assert.equal(fixture.page.data.haloStyle, pausedHaloStyle);
});

test('completion and reset clear breathing and restore full opacity', () => {
  const fixture = loadMeditation({ random: () => 0 });
  fixture.page.startMeditation();
  fixture.runBreathInterval();
  fixture.page.data.remainingSeconds = 1;

  fixture.runLatestInterval();
  assert.equal(fixture.page._breathTimer, null);
  assert.equal(fixture.page.data.ringOpacity, 1);
  assert.match(fixture.page.data.haloStyle, /opacity: 0/);

  fixture.page.startMeditation();
  fixture.runBreathInterval();
  fixture.page.resetMeditation();
  assert.equal(fixture.page._breathTimer, null);
  assert.equal(fixture.page.data.ringOpacity, 1);
  assert.match(fixture.page.data.haloStyle, /opacity: 0/);
});

test('Sound fallback uses the selected local track at 15 percent volume', () => {
  const fixture = loadMeditation({ audioPlayerUnavailable: true, random: () => 0 });
  fixture.page.startMeditation();

  assert.equal(fixture.sounds.length, 1);
  assert.equal(fixture.sounds[0].src, '../../assets/morning_temple.wav');
  assert.equal(fixture.sounds[0].volume, 0.15);
  assert.equal(fixture.sounds[0].playCalls, 1);
});

test('Sound fallback is used when AudioPlayer construction fails', () => {
  const fixture = loadMeditation({ audioPlayerConstructorThrows: true, random: () => 0 });
  fixture.page.startMeditation();

  assert.equal(fixture.sounds.length, 1);
  assert.equal(fixture.sounds[0].src, '../../assets/morning_temple.wav');
  assert.equal(fixture.sounds[0].volume, 0.15);
});

test('AudioPlayer without ended events still uses the calculated replay schedule', () => {
  const fixture = loadMeditation({ audioPlayerEndedUnavailable: true, random: () => 0 });
  fixture.page.startMeditation();

  assert.equal(fixture.players.length, 1);
  assert.equal(fixture.players[0].destroyCalls, 0);
  assert.equal(fixture.sounds.length, 0);
  fixture.runAudioLoopInterval();
  assert.equal(fixture.players[0].playCalls, 2);
});

test('an AudioPlayer error while paused does not start audible Sound playback', () => {
  const fixture = loadMeditation({ random: () => 0 });
  fixture.page.startMeditation();
  const player = fixture.players[0];
  fixture.page.togglePause();

  player.errorHandler(new Error('device error'));

  assert.equal(fixture.page.data.status, 'paused');
  assert.equal(fixture.sounds.length, 0);
  assert.equal(player.destroyCalls, 1);
});

test('a failed AudioPlayer pause releases the player so audio cannot leak', () => {
  const fixture = loadMeditation({ audioPlayerPauseThrows: true, random: () => 0 });
  fixture.page.startMeditation();
  const player = fixture.players[0];

  fixture.page.togglePause();

  assert.equal(fixture.page.data.status, 'paused');
  assert.equal(player.stopCalls, 1);
  assert.equal(player.destroyCalls, 1);
});

test('a failed AudioPlayer resume falls back to Sound for the same track', () => {
  const fixture = loadMeditation({ audioPlayerResumeThrows: true, random: () => 0 });
  fixture.page.startMeditation();
  const player = fixture.players[0];
  fixture.page.togglePause();

  fixture.page.togglePause();

  assert.equal(player.destroyCalls, 1);
  assert.equal(fixture.sounds.length, 1);
  assert.equal(fixture.sounds[0].src, '../../assets/morning_temple.wav');
  assert.equal(fixture.sounds[0].volume, 0.15);
});

test('a failed AudioPlayer replay falls back to Sound for the same track', () => {
  const fixture = loadMeditation({ audioPlayerResumeThrows: true, random: () => 0 });
  fixture.page.startMeditation();
  const player = fixture.players[0];

  fixture.runAudioLoopInterval();

  assert.equal(player.destroyCalls, 1);
  assert.equal(fixture.wx._bgmMode, 'sound');
  assert.equal(fixture.sounds.length, 1);
  assert.equal(fixture.sounds[0].src, '../../assets/morning_temple.wav');
  assert.equal(fixture.sounds[0].volume, 0.15);
});

test('AudioPlayer replays the selected track for the calculated meditation count', () => {
  const fixture = loadMeditation({ random: () => 0 });
  fixture.page.data.durationMinutes = 1;
  fixture.page.startMeditation();
  const player = fixture.players[0];

  assert.equal(player.loop, false);
  assert.equal(typeof player.endedHandler, 'undefined');
  assert.equal(fixture.sounds.length, 0);
  assert.equal(fixture.wx._bgmTrack.path, '../../assets/morning_temple.wav');
  assert.equal(fixture.wx._bgmMaxPlays, 20);
  assert.equal(fixture.wx._bgmPlayCount, 1);

  for (let i = 0; i < 19; i += 1) {
    fixture.runAudioLoopInterval();
  }
  assert.equal(player.playCalls, 20);
  assert.equal(fixture.wx._bgmPlayCount, 20);
  fixture.runAudioLoopInterval();
  assert.equal(player.playCalls, 20);
  assert.equal(fixture.wx._bgmLoopTimer, null);
});

test('pausing and resuming preserves the selected track and replay count', () => {
  const fixture = loadMeditation({ random: () => 0 });
  fixture.page.startMeditation();
  const player = fixture.players[0];

  fixture.runAudioLoopInterval();
  assert.equal(fixture.wx._bgmPlayCount, 2);
  fixture.page.togglePause();
  assert.equal(fixture.page.data.status, 'paused');
  assert.equal(fixture.wx._bgm, player);

  fixture.page.togglePause();
  assert.equal(fixture.page.data.status, 'running');
  assert.equal(player.playCalls, 3);
  assert.equal(fixture.wx._bgmTrack.path, '../../assets/morning_temple.wav');
  assert.equal(fixture.wx._bgmPlayCount, 2);
});

test('Sound fallback replays the selected track for the calculated meditation count', () => {
  const fixture = loadMeditation({ audioPlayerUnavailable: true, random: () => 0 });
  fixture.page.data.durationMinutes = 1;

  fixture.page.startMeditation();
  assert.equal(fixture.sounds.length, 1);
  assert.equal(fixture.sounds[0].src, '../../assets/morning_temple.wav');
  assert.equal(fixture.sounds[0].playCalls, 1);
  assert.equal(fixture.wx._bgmMaxPlays, 20);
  assert.equal(fixture.wx._bgmPlayCount, 1);

  fixture.runAudioLoopInterval();
  assert.equal(fixture.sounds.length, 1);
  assert.equal(fixture.sounds[0].playCalls, 2);
  assert.equal(fixture.wx._bgmPlayCount, 2);
});

test('a Sound instance is destroyed when its first play fails', () => {
  const fixture = loadMeditation({
    audioPlayerUnavailable: true,
    soundPlayThrows: true,
    random: () => 0
  });

  fixture.page.startMeditation();

  assert.equal(fixture.sounds.length, 1);
  assert.equal(fixture.sounds[0].stopCalls, 1);
  assert.equal(fixture.sounds[0].destroyCalls, 1);
});

test('Sound pause and resume retain the selected track without overlapping instances', () => {
  const fixture = loadMeditation({ audioPlayerUnavailable: true, random: () => 0 });
  fixture.page.startMeditation();
  const firstSound = fixture.sounds[0];
  fixture.page.togglePause();

  assert.equal(firstSound.stopCalls, 1);
  assert.equal(firstSound.destroyCalls, 1);

  fixture.page.togglePause();
  assert.equal(fixture.sounds.length, 2);
  assert.equal(fixture.sounds[1].src, firstSound.src);
});

test('onUnload does not interrupt active shared audio', () => {
  const fixture = loadMeditation({ random: () => 0 });
  fixture.page.startMeditation();
  const player = fixture.players[0];

  fixture.page.onUnload();

  assert.equal(fixture.page._breathTimer, null);
  assert.equal(player.stopCalls, 0);
  assert.equal(player.destroyCalls, 0);
  assert.equal(fixture.wx._bgm, player);
});

test('onHide prevents aborted recognition from scheduling an offscreen restart', () => {
  const fixture = loadMeditation();
  fixture.page.onShow();
  assert.equal(fixture.recognitions.length, 1);

  fixture.page.onHide();

  assert.equal(fixture.pendingTimeoutCount(), 0);
});

test('meditation pauses ASR until the session ends', () => {
  const fixture = loadMeditation();
  fixture.page.onShow();
  const recognition = fixture.recognitions[0];

  fixture.page.startMeditation();

  assert.equal(recognition.abortCalls, 1);
  assert.equal(fixture.page.recognition, null);
  assert.equal(fixture.pendingTimeoutCount(), 1);

  fixture.page.setData({ remainingSeconds: 1 });
  fixture.runLatestInterval();

  assert.equal(fixture.page.data.status, 'completed');
  assert.equal(fixture.recognitions.length, 2);
  assert.notEqual(fixture.page.recognition, null);
});

test('long press wakeup enables voice control during meditation', () => {
  const fixture = loadMeditation();
  fixture.page.onShow();
  fixture.page.startMeditation();

  fixture.page.onVoiceWakeup();

  assert.equal(fixture.page._recognitionPausedForMeditation, false);
  assert.equal(fixture.recognitions.length, 2);
  assert.notEqual(fixture.page.recognition, null);
});

test('GlobalHook touch wakeup enables voice control during meditation', () => {
  const fixture = loadMeditation();
  fixture.page.onShow();
  fixture.page.startMeditation();

  fixture.page.onKeyUp({ code: 'GlobalHook' });

  assert.equal(fixture.page._recognitionPausedForMeditation, false);
  assert.equal(fixture.recognitions.length, 2);
  assert.notEqual(fixture.page.recognition, null);
});

test('a synchronous pause error cannot start fallback audio before async setData commits', () => {
  const fixture = loadMeditation({
    audioPlayerErrorOnPause: true,
    deferPausedStatus: true,
    random: () => 0
  });
  fixture.page.startMeditation();

  fixture.page.togglePause();

  assert.equal(fixture.page.data.status, 'running');
  assert.equal(fixture.sounds.length, 0);
});

test('an initial play error falls back before async running setData commits', () => {
  const fixture = loadMeditation({
    audioPlayerErrorOnInitialPlay: true,
    deferRunningStatus: true,
    random: () => 0
  });

  fixture.page.startMeditation();

  assert.equal(fixture.page.data.status, 'idle');
  assert.equal(fixture.sounds.length, 1);
  assert.equal(fixture.sounds[0].src, '../../assets/morning_temple.wav');
  assert.equal(fixture.sounds[0].volume, 0.15);
});

test('a new meditation session randomizes its track while reusing wx._bgm', () => {
  const first = loadMeditation({ random: () => 0 });
  first.page.startMeditation();
  const sharedPlayer = first.wx._bgm;

  const second = loadMeditation({ random: () => 0.5 }, first.wx);
  second.page.startMeditation();

  assert.equal(second.players.length, 0);
  assert.equal(second.wx._bgm, sharedPlayer);
  assert.equal(second.wx._bgm.src, '../../assets/ocean_mindfulness.wav');
});

test('a new session calculates replay count from its own selected duration', () => {
  const first = loadMeditation({ random: () => 0 });
  first.page.data.durationMinutes = 5;
  first.page.startMeditation();

  const second = loadMeditation({ random: () => 0 }, first.wx);
  second.page.data.durationMinutes = 1;
  second.page.startMeditation();

  assert.equal(second.wx._bgmMaxPlays, 20);
  assert.equal(second.wx._bgmPlayCount, 1);
});

test('a stale page timer cannot stop a newer page session BGM', () => {
  const first = loadMeditation({ random: () => 0 });
  first.page.startMeditation();
  const sharedPlayer = first.wx._bgm;

  const second = loadMeditation({ random: () => 0.5 }, first.wx);
  second.page.startMeditation();
  first.page.data.remainingSeconds = 1;
  first.runLatestInterval();

  assert.equal(first.wx._bgm, sharedPlayer);
  assert.equal(sharedPlayer.destroyCalls, 0);
  assert.equal(second.page.data.status, 'running');
});

test('a stale page AudioPlayer error callback cannot replace the newer session BGM', () => {
  const first = loadMeditation({ random: () => 0 });
  first.page.startMeditation();
  const sharedPlayer = first.wx._bgm;
  const staleErrorHandler = sharedPlayer.errorHandler;

  const second = loadMeditation({ random: () => 0.5 }, first.wx);
  second.page.startMeditation();
  staleErrorHandler(new Error('stale page error'));

  assert.equal(second.wx._bgm, sharedPlayer);
  assert.equal(second.wx._bgmOwner, second.page);
  assert.equal(second.wx._bgmTrack.path, '../../assets/ocean_mindfulness.wav');
  assert.equal(second.sounds.length, 0);
});

test('the current page AudioPlayer error falls back using the current track after reuse', () => {
  const first = loadMeditation({ random: () => 0 });
  first.page.startMeditation();
  const sharedPlayer = first.wx._bgm;

  const second = loadMeditation({ random: () => 0.5 }, first.wx);
  second.page.startMeditation();
  sharedPlayer.errorHandler(new Error('current page error'));

  assert.equal(second.wx._bgmMode, 'sound');
  assert.equal(second.wx._bgmOwner, second.page);
  assert.equal(second.wx._bgmTrack.path, '../../assets/ocean_mindfulness.wav');
  assert.equal(second.sounds.length, 1);
  assert.equal(second.sounds[0].src, '../../assets/ocean_mindfulness.wav');
});
