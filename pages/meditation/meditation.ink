<script def>
{
  "navigationBarTitleText": "",
  "navigationStyle": "custom",
  "description": "冥想修行 — 正念呼吸、身体扫描、静坐，语音控制"
}
</script>

<script setup>
import wx from 'wx';

var PRESET_DURATIONS = [1, 5, 10, 20, 30, 60];

var MEDITATION_AUDIO_TRACKS = [
  { file: "morning_temple.wav", path: "../../assets/morning_temple.wav", loopMs: 3000 },
  { file: "rain_zen.wav", path: "../../assets/rain_zen.wav", loopMs: 3000 },
  { file: "stream_forest.wav", path: "../../assets/stream_forest.wav", loopMs: 7000 },
  { file: "ocean_mindfulness.wav", path: "../../assets/ocean_mindfulness.wav", loopMs: 4000 },
  { file: "night_temple.wav", path: "../../assets/night_temple.wav", loopMs: 10000 },
  { file: "incense_chamber.wav", path: "../../assets/incense_chamber.wav", loopMs: 3000 }
];

var TYPE_OPTIONS = [
  {
    key: "breathing", name: "呼吸冥想", icon: "🌬️", desc: "关注一呼一吸",
    guides: [
      "将注意力带到鼻尖。吸气，感受清凉的空气进入身体；呼气，感受温热的气息缓缓离开。不必刻意控制呼吸的深浅快慢，只是觉知它本来的样子。缓缓闭上眼睛。",
      "当念头升起时，不必跟随，也不必抗拒。轻轻地将注意力带回到呼吸上，就像秋风拂过水面，涟漪自来自去。每一次呼吸，都是一次归来的练习。",
      "让呼吸成为你安住的锚点。在这片宁静中，身心渐渐柔软，杂念如浮云散去。你只是坐着，只是呼吸，便已足够。一呼一吸之间，便是当下。"
    ]
  },
  {
    key: "body-scan", name: "身体扫描", icon: "🫀", desc: "从头到脚扫描身体感受",
    guides: [
      "从头顶开始。感受头顶的皮肤，觉察那里细微的触感。慢慢向下，经过额头、眉间，放松眼睑，让面部的每一寸肌肉自然舒展。闭上眼睛。",
      "继续向下，感受颈部、双肩。让肩膀沉下来，卸下承载的重量。手臂、手掌、指尖，觉察每一处温度与脉动。胸腔随呼吸起伏，腹部柔软地放松。",
      "向下到髋部、大腿、小腿，直到双脚的每一个脚趾。整个身体从头到脚，被觉知之光照亮。不评判，不改变，只是感受它此刻本来的状态。"
    ]
  },
  {
    key: "sitting", name: "静坐", icon: "🧘", desc: "静坐观心，万缘放下",
    guides: [
      "脊背挺直而不僵硬，如同松树扎根于山间。双手自然安放，舌抵上颚，面带微笑。让身体稳稳地坐着，如山如石。轻轻闭上眼睛。",
      "不去追逐念头，也不去压抑念头。让一切来来去去，你只是那个看见的人。念头如水中倒影，来无所从，去无所至。你不必做任何事，只是安住于此。",
      "在这份寂静中，心渐渐澄明。没有过去，没有未来，只有此刻的觉照。万缘放下，身心自在。坐在这片空明之中，便是归处。"
    ]
  }
];

export default {
  data: {
    step: "type",

    typeOptions: TYPE_OPTIONS,
    typeIdx: 0,

    durationIdx: 2,
    durationMinutes: 10,

    totalSeconds: 0,
    remainingSeconds: 0,
    timerText: "10:00",
    progress: 100,
    ringOpacity: 1,
    haloStyle: "opacity: 0; width: 168px; height: 168px; left: 9px; top: 9px; border-color: rgba(64,255,94,0.08); background-color: rgba(64,255,94,0.01);",

    status: "idle",
    guideText: "请选择修行方式",
    guideKey: 0,
    statusText: "说出「呼吸」「扫描」「静坐」选方式",

    listening: false
  },

  timer: null,
  recognition: null,
  _guideTimer: null,
  _guideIdx: 0,
  _guideSegments: [],
  audioPlayer: null,
  audioMode: "",
  audioLoopTimer: null,
  currentAudioTrack: null,
  audioPlayCount: 0,
  audioMaxPlays: 0,
  audioSessionTotalSeconds: 0,
  _breathTimer: null,
  _breathPhase: 0,
  _ringBaseOpacity: 1,
  _breathingActive: false,
  _meditationPauseRequested: false,
  _recognitionRestartTimer: null,
  _isPageActive: false,
  _recognitionPausedForMeditation: false,

  onLoad: function() {
    var self = this;
    // onShow 会在页面进入前台时启动语音识别
  },

  onShow: function() {
    this._isPageActive = true;
    this.clearRecognitionRestart();
    if (this.data.status === "running" || this.data.status === "paused") {
      return;
    }
    try {
      if (this.recognition) { this.recognition.abort(); }
    } catch (e) {}
    this.recognition = null;
    this.initRecognition();
  },

  onHide: function() {
    this._isPageActive = false;
    this.clearRecognitionRestart();
    try {
      if (this.recognition) { this.recognition.abort(); }
    } catch (e) {}
    this.recognition = null;
    this.setData({ listening: false });
  },

  onUnload: function() {
    this._isPageActive = false;
    this.clearRecognitionRestart();
    this.stopBreathing(false);
    try {
      if (this.recognition) { this.recognition.abort(); }
    } catch (e) {}
    this.recognition = null;
  },

  // ===== 语音识别 (ASR) =====
  initRecognition: function() {
    var self = this;
    if (self.recognition) {
      try { self.recognition.abort(); } catch (e) {}
      self.recognition = null;
    }
    self.setData({ listening: false });

    try {
      self.recognition = new SpeechRecognition();
      self.recognition.lang = "zh-CN";
      self.recognition.continuous = false;
      self.recognition.interimResults = false;
      self.recognition.maxAlternatives = 1;

      self.recognition.onresult = function(event) {
        self.setData({ listening: false });
        var text = "";
        try {
          var results = event.results;
          if (results && results.length > 0) {
            var first = results[0];
            if (first.length > 0) {
              var alt = first[0];
              text = alt.transcript || alt.text || "";
            } else if (typeof first.transcript === "string") {
              text = first.transcript;
            } else if (typeof first === "string") {
              text = first;
            }
          }
        } catch (e2) {
          try { text = event.results[0][0].transcript || ""; } catch (e3) {}
        }
        text = (text || "").replace(/\s/g, "");

        if (text.length > 0) {
          self.setData({ statusText: "听到: " + text });
          self.handleVoiceCommand(text);
        } else {
          self.scheduleRecognitionRestart(1000);
          return;
        }
        self.scheduleRecognitionRestart(2000);
      };

      self.recognition.onerror = function(event) {
        self.setData({ listening: false, statusText: "语音出错: " + (event.error || "未知") });
        self.scheduleRecognitionRestart(2000);
      };

      self.recognition.onend = function() {
        self.setData({ listening: false });
        self.scheduleRecognitionRestart(1500);
      };

      self.recognition.onnomatch = function() {
        self.setData({ listening: false });
        self.scheduleRecognitionRestart(1500);
      };

      self.startRecognition();
    } catch (e) {
      self.setData({ statusText: "语音不可用: " + (e.message || e) });
      self.recognition = null;
    }
  },

  clearRecognitionRestart: function() {
    if (this._recognitionRestartTimer) {
      clearTimeout(this._recognitionRestartTimer);
      this._recognitionRestartTimer = null;
    }
  },

  scheduleRecognitionRestart: function(ms) {
    var self = this;
    if (!self._isPageActive || self._recognitionPausedForMeditation) { return; }
    self.clearRecognitionRestart();
    self._recognitionRestartTimer = setTimeout(function() {
      self._recognitionRestartTimer = null;
      if (self._isPageActive && !self._recognitionPausedForMeditation) {
        self.startRecognition();
      }
    }, ms);
  },

  startRecognition: function() {
    var self = this;
    if (!self._isPageActive || self._recognitionPausedForMeditation) { return; }
    if (self.data.listening) return;
    if (!self.recognition) {
      self.initRecognition();
      return;
    }
    try {
      self.recognition.start();
      self.setData({ listening: true, statusText: "正在听..." });
    } catch (e) {
      var msg = (e.message || "");
      if (msg.indexOf("InvalidState") > -1) {
        self.setData({ statusText: "等待页面就绪..." });
        self.scheduleRecognitionRestart(500);
      } else {
        self.scheduleRecognitionRestart(2000);
      }
    }
  },

  // ===== 语音唤醒 (长按触摸) =====
  onVoiceWakeup: function(event) {
    this._recognitionPausedForMeditation = false;
    this.initRecognition();
    this.startRecognition();
  },

  pauseRecognitionForMeditation: function() {
    this._recognitionPausedForMeditation = true;
    this.clearRecognitionRestart();
    try {
      if (this.recognition) { this.recognition.abort(); }
    } catch (e) {}
    this.recognition = null;
    this.setData({ listening: false });
  },

  resumeRecognitionAfterMeditation: function() {
    this._recognitionPausedForMeditation = false;
    if (this._isPageActive && this.data.status !== "running" && this.data.status !== "paused") {
      this.initRecognition();
    }
  },

  speak: function(text) {
    try {
      var u = new SpeechSynthesisUtterance(text);
      u.lang = "zh-CN"; u.rate = 1.0;
      speechSynthesis.speak(u);
    } catch (e) {
      try { wx.speech.playTTS(text); } catch (e2) {}
    }
  },

  // ===== 语音命令路由 =====
  handleVoiceCommand: function(text) {
    var self = this;
    var t = text;

    if (self.data.step === "type") {
      if (t.indexOf("呼吸") > -1) {
        self.setType(0); self.confirmType();
      }
      else if (t.indexOf("扫描") > -1 || t.indexOf("身体") > -1) {
        self.setType(1); self.confirmType();
      }
      else if (t.indexOf("静坐") > -1 || t.indexOf("寂静") > -1) {
        self.setType(2); self.confirmType();
      }
      else if (t.indexOf("返回") > -1 || t.indexOf("退出") > -1) {
        wx.navigateBack();
      }
      else {
        self.setData({ statusText: "未识别: " + t });
      }
    }
    else if (self.data.step === "duration") {
      var mins = self.parseDuration(t);
      if (mins > 0) {
        self.setDuration(mins);
        self.confirmDuration();
      }
      else if (t.indexOf("返回") > -1 || t.indexOf("退出") > -1) {
        self.setData({ step: "type", statusText: "请选择修行方式" });
      }
      else {
        self.setData({ statusText: "未识别: " + t });
      }
    }
    else if (self.data.step === "timer") {
      if (t.indexOf("暂停") > -1 || t.indexOf("停") > -1 || t.indexOf("继续") > -1 || t.indexOf("开始") > -1) {
        self.togglePause();
      }
      else if (t.indexOf("结束") > -1 || t.indexOf("停止") > -1) {
        self.resetMeditation();
      }
    }
  },

  // ===== 时长解析 =====
  parseDuration: function(text) {
    var t = (text || "").replace(/\s/g, "");
    if (!t) { return 0; }

    var parseNumber = function(value) {
      if (!value) { return 0; }
      value = value.replace(/个/g, "");
      if (/^\d+$/.test(value)) { return parseInt(value, 10); }

      var digits = {
        "零": 0, "一": 1, "二": 2, "两": 2, "三": 3, "四": 4,
        "五": 5, "六": 6, "七": 7, "八": 8, "九": 9, "十": 10
      };
      if (Object.prototype.hasOwnProperty.call(digits, value)) {
        return digits[value];
      }

      var match = value.match(/^([一二两三四五六七八九])十([一二三四五六七八九])?$/);
      if (match) {
        return digits[match[1]] * 10 + (match[2] ? digits[match[2]] : 0);
      }
      if (value.indexOf("十") === 0) {
        var tail = value.slice(1);
        return 10 + (tail ? (digits[tail] || 0) : 0);
      }
      return 0;
    };

    var hourMinutes = 0;
    var minuteMinutes = 0;
    var numberPattern = "[0-9零一二两三四五六七八九十个]+";
    var hourMatch = t.match(new RegExp("(" + numberPattern + ")小时(?:(" + numberPattern + ")分钟)?"));
    if (hourMatch) {
      hourMinutes = parseNumber(hourMatch[1]) * 60;
      if (hourMatch[2]) { minuteMinutes = parseNumber(hourMatch[2]); }
    } else {
      var explicitMinutes = t.match(new RegExp("(" + numberPattern + ")分钟"));
      if (explicitMinutes) {
        minuteMinutes = parseNumber(explicitMinutes[1]);
      } else {
        var numberMatch = t.match(/\d+/);
        minuteMinutes = numberMatch ? parseNumber(numberMatch[0]) : parseNumber(t);
      }
    }

    var total = hourMinutes + minuteMinutes;
    return total >= 1 && total <= 120 ? total : 0;
  },

  // ===== 环形样式更新 =====
  getBreathFactor: function() {
    var phase = this._breathPhase;
    var wave = phase <= 0.5 ? 1 - (phase * 2) : ((phase - 0.5) * 2);
    return 0.20 + (0.80 * wave);
  },

  getHaloStyle: function(active) {
    var strength = this._ringBaseOpacity * this.getBreathFactor();
    var borderAlpha = 0.08 + (strength * 0.72);
    var fillAlpha = 0.01 + (strength * 0.12);
    var sizeFactor = 0.93 + (this.getBreathFactor() * 0.15);
    var size = 168 * sizeFactor;
    var offset = (194 - size - 8) / 2;
    return "opacity: " + (active ? "1" : "0") + "; width: " + size.toFixed(3) + "px; height: " + size.toFixed(3) + "px; left: " + offset.toFixed(3) + "px; top: " + offset.toFixed(3) + "px; border-color: rgba(64,255,94," + borderAlpha.toFixed(3) + "); background-color: rgba(64,255,94," + fillAlpha.toFixed(3) + ");";
  },

  applyBreathingOpacity: function() {
    var opacity = this._ringBaseOpacity * this.getBreathFactor();
    this.setData({
      ringOpacity: Number(opacity.toFixed(4)),
      haloStyle: this.getHaloStyle(true)
    });
  },

  startBreathing: function(resetPhase) {
    this.stopBreathing(false);
    if (resetPhase) { this._breathPhase = 0; }
    this._breathingActive = true;
    this.applyBreathingOpacity();
    var self = this;
    this._breathTimer = setInterval(function() {
      if (self.data.status !== "running") { return; }
      self._breathPhase += 0.1 / 6;
      if (self._breathPhase >= 1) { self._breathPhase -= 1; }
      self.applyBreathingOpacity();
    }, 100);
  },

  stopBreathing: function(resetVisual) {
    if (this._breathTimer) {
      clearInterval(this._breathTimer);
      this._breathTimer = null;
    }
    this._breathingActive = false;
    if (resetVisual) {
      this._breathPhase = 0;
      this._ringBaseOpacity = 1;
      this.setData({
        ringOpacity: 1,
        haloStyle: this.getHaloStyle(false)
      });
    }
  },

  updateRingStyle: function(pct, elapsedSec) {
    // 亮度按绝对时间渐暗：1分钟降到60%，2分钟降到20%，之后保持
    var elapsed = elapsedSec || 0;
    var opacity;
    if (elapsed >= 120) {
      opacity = 0.2;
    } else if (elapsed >= 60) {
      opacity = 0.6 - ((elapsed - 60) / 60) * 0.4;
    } else {
      opacity = 1.0 - (elapsed / 60) * 0.4;
    }
    this._ringBaseOpacity = opacity;
    this.setData({
      ringOpacity: this._breathingActive ? Number((opacity * this.getBreathFactor()).toFixed(4)) : opacity,
      haloStyle: this._breathingActive ? this.getHaloStyle(true) : this.getHaloStyle(false)
    });
  },

  // ===== Step 1: 修行方式 =====
  setType: function(idx) {
    this.setData({ typeIdx: idx });
  },

  confirmType: function() {
    var type = this.data.typeOptions[this.data.typeIdx];
    this.setData({
      step: "duration",
      statusText: "已选" + type.name + "，说出时长（分钟或小时）"
    });
    this.speak(type.name);
  },

  // ===== Step 2: 时长选择 =====
  setDuration: function(mins) {
    var idx = 0;
    for (var i = 0; i < PRESET_DURATIONS.length; i++) {
      if (mins >= PRESET_DURATIONS[i]) { idx = i; }
    }
    var ts = mins < 10 ? "0" + mins + ":00" : mins + ":00";
    this.setData({ durationMinutes: mins, durationIdx: idx, timerText: ts });
  },

  confirmDuration: function() {
    var mins = this.data.durationMinutes;
    var type = this.data.typeOptions[this.data.typeIdx];
    this.updateRingStyle(100, 0);
    this.setData({ step: "timer" });
    this.speak("开始" + mins + "分钟" + type.name);
    this.startMeditation();
  },

  // ===== 冥想背景音 =====
  selectMeditationTrack: function() {
    var idx = Math.floor(Math.random() * MEDITATION_AUDIO_TRACKS.length);
    if (idx < 0) { idx = 0; }
    if (idx >= MEDITATION_AUDIO_TRACKS.length) { idx = MEDITATION_AUDIO_TRACKS.length - 1; }
    return MEDITATION_AUDIO_TRACKS[idx];
  },

  clearAudioLoop: function() {
    var globalTimer = wx._bgmLoopTimer;
    if (wx._bgmOwner === this && globalTimer) {
      clearInterval(globalTimer);
      wx._bgmLoopTimer = null;
    }
    if (this.audioLoopTimer) {
      clearInterval(this.audioLoopTimer);
      this.audioLoopTimer = null;
    }
  },

  prepareAudioRepeat: function(track, resetCount) {
    if (resetCount || !this.audioMaxPlays) {
      var totalSeconds = this.audioSessionTotalSeconds || (this.data.durationMinutes * 60);
      this.audioMaxPlays = Math.max(1, Math.ceil((totalSeconds * 1000) / track.loopMs));
      this.audioPlayCount = 1;
    }
    wx._bgmMaxPlays = this.audioMaxPlays;
    wx._bgmPlayCount = this.audioPlayCount || 1;
  },

  scheduleAudioLoop: function(track) {
    var self = this;
    if (wx._bgmOwner !== self || wx._bgmTrack !== track || !wx._bgm || !self.audioPlayer) { return; }
    self.clearAudioLoop();
    var timer = setInterval(function() {
      var isCurrent = wx._bgm === self.audioPlayer && wx._bgmOwner === self && wx._bgmTrack === track;
      if (!isCurrent) {
        clearInterval(timer);
        if (self.audioLoopTimer === timer) { self.audioLoopTimer = null; }
        return;
      }
      if (wx._bgmPaused) { return; }
      if (wx._bgmPlayCount >= wx._bgmMaxPlays) {
        self.clearAudioLoop();
        return;
      }
      try {
        self.audioPlayer.play();
        wx._bgmPlayCount += 1;
        self.audioPlayCount = wx._bgmPlayCount;
      } catch (e) {
        var shouldFallback = self.audioMode === "audioPlayer" && !self._meditationPauseRequested;
        if (shouldFallback) {
          self.releaseAudioPlayer();
          self.startSoundPlayback(track);
        } else {
          self.stopMeditationAudio(false);
        }
      }
    }, track.loopMs);
    wx._bgmLoopTimer = timer;
    self.audioLoopTimer = timer;
  },

  releaseAudioPlayer: function() {
    var player = this.audioPlayer || wx._bgm;
    var ownsGlobal = wx._bgm === player && (!wx._bgmOwner || wx._bgmOwner === this);
    if (wx._bgm === player && !ownsGlobal) {
      return false;
    }
    this.audioPlayer = null;
    this.audioMode = "";
    if (wx._bgm === player) {
      wx._bgm = null;
      wx._bgmMode = "";
      wx._bgmTrack = null;
      wx._bgmOwner = null;
      wx._bgmPaused = false;
      if (wx._bgmLoopTimer) {
        clearInterval(wx._bgmLoopTimer);
        wx._bgmLoopTimer = null;
      }
      wx._bgmPlayCount = 0;
      wx._bgmMaxPlays = 0;
    }
    if (!player) { return; }
    try { player.stop(); } catch (e) {}
    try { player.destroy(); } catch (e2) {}
  },

  stopMeditationAudio: function(clearTrack) {
    if (wx._bgm === this.audioPlayer && wx._bgmOwner && wx._bgmOwner !== this) {
      return;
    }
    this.clearAudioLoop();
    this.releaseAudioPlayer();
    if (clearTrack) {
      this.currentAudioTrack = null;
    }
    return true;
  },

  forceReleaseSharedBgm: function() {
    var player = wx._bgm;
    if (wx._bgmLoopTimer) {
      clearInterval(wx._bgmLoopTimer);
      wx._bgmLoopTimer = null;
    }
    wx._bgm = null;
    wx._bgmMode = "";
    wx._bgmTrack = null;
    wx._bgmOwner = null;
    wx._bgmPaused = false;
    wx._bgmPlayCount = 0;
    wx._bgmMaxPlays = 0;
    if (this.audioPlayer === player) {
      this.audioPlayer = null;
      this.audioMode = "";
    }
    if (player) {
      try { player.stop(); } catch (e) {}
      try { player.destroy(); } catch (e2) {}
    }
  },

  startSoundPlayback: function(track) {
    var self = this;
    if (typeof Sound === "undefined") { return false; }

    try {
      var sound = new Sound(track.path);
      sound.volume = 0.15;
      self.audioPlayer = sound;
      self.audioMode = "sound";
      wx._bgm = sound;
      wx._bgmMode = "sound";
      wx._bgmTrack = track;
      wx._bgmOwner = self;
      wx._bgmPaused = false;
      self.prepareAudioRepeat(track, false);
      sound.play();
      if (wx._bgm === sound) { self.scheduleAudioLoop(track); }
      return true;
    } catch (e) {
      self.stopMeditationAudio(false);
      return false;
    }
  },

  startAudioPlayerPlayback: function(track) {
    var self = this;
    if (typeof AudioPlayer === "undefined") { return false; }

    if (wx._bgm) {
      self.audioPlayer = wx._bgm;
      self.audioMode = wx._bgmMode || "audioPlayer";
      wx._bgmOwner = self;
      return true;
    }

    var player;
    try {
      player = new AudioPlayer();
    } catch (e) {
      return false;
    }
    player.src = track.path;
    player.loop = false;
    player.volume = 0.15;

    self.audioPlayer = player;
    self.audioMode = "audioPlayer";
    wx._bgm = player;
    wx._bgmMode = "audioPlayer";
    wx._bgmTrack = track;
    wx._bgmOwner = self;
    wx._bgmPaused = false;
    self.prepareAudioRepeat(track, false);
    self.bindAudioPlayerError(player, track);
    try {
      player.play();
      if (wx._bgm === player) { self.scheduleAudioLoop(track); }
      return true;
    } catch (e) {
      self.releaseAudioPlayer();
      return false;
    }
  },

  bindAudioPlayerError: function(player, track) {
    var self = this;
    if (typeof player.onError !== "function") { return; }
    player.onError(function() {
      if (wx._bgm !== player || wx._bgmOwner !== self || wx._bgmTrack !== track) { return; }
      self.releaseAudioPlayer();
      if (!self._meditationPauseRequested) {
        self.startSoundPlayback(track);
      }
    });
  },

  startMeditationAudio: function(track, replaceTrack) {
    if (track && replaceTrack) { this.prepareAudioRepeat(track, true); }
    if (replaceTrack && wx._bgm) {
      if (wx._bgmMode === "audioPlayer") {
        this.clearAudioLoop();
        this.audioPlayer = wx._bgm;
        this.audioMode = "audioPlayer";
        this.currentAudioTrack = track;
        wx._bgmOwner = this;
        wx._bgmTrack = track;
        wx._bgmPaused = false;
        this.bindAudioPlayerError(wx._bgm, track);
        try {
          wx._bgm.src = track.path;
          wx._bgm.loop = false;
          wx._bgm.volume = 0.15;
          wx._bgm.play();
          this.scheduleAudioLoop(track);
        } catch (e) {
          this.forceReleaseSharedBgm();
          this.startSoundPlayback(track);
        }
        return;
      }
      this.forceReleaseSharedBgm();
    }
    if (wx._bgm) {
      this.audioPlayer = wx._bgm;
      this.audioMode = wx._bgmMode || "audioPlayer";
      this.currentAudioTrack = wx._bgmTrack || track;
      wx._bgmOwner = this;
      return;
    }
    this.stopMeditationAudio(false);
    this.currentAudioTrack = track;
    if (!track) { return; }

    try {
      if (this.startAudioPlayerPlayback(track)) { return; }
      this.startSoundPlayback(track);
    } catch (e) {
      this.stopMeditationAudio(false);
    }
  },

  pauseMeditationAudio: function() {
    this.clearAudioLoop();
    if (wx._bgmOwner === this) { wx._bgmPaused = true; }
    if (!this.audioPlayer) { return; }

    if (this.audioMode === "audioPlayer" && typeof this.audioPlayer.pause === "function") {
      try {
        this.audioPlayer.pause();
      } catch (e) {
        this.releaseAudioPlayer();
      }
      return;
    }

    this.releaseAudioPlayer();
  },

  resumeMeditationAudio: function() {
    if (wx._bgmOwner === this) { wx._bgmPaused = false; }
    if (this.audioPlayer && this.audioMode === "audioPlayer") {
      try {
        this.audioPlayer.play();
        if (wx._bgmOwner === this && wx._bgmTrack) {
          this.scheduleAudioLoop(wx._bgmTrack);
        }
      } catch (e) {
        this.releaseAudioPlayer();
        if (this.currentAudioTrack) {
          this.startSoundPlayback(this.currentAudioTrack);
        }
      }
      return;
    }

    if (this.currentAudioTrack) {
      this.startMeditationAudio(this.currentAudioTrack);
    }
  },

  // ===== Step 3: 计时器 =====
  startMeditation: function() {
    var self = this;
    self.pauseRecognitionForMeditation();
    var total = self.data.durationMinutes * 60;
    var type = self.data.typeOptions[self.data.typeIdx];
    self._guideSegments = type.guides || [];
    self._guideIdx = 0;
    self.audioSessionTotalSeconds = total;
    self._meditationPauseRequested = false;

    self.setData({
      totalSeconds: total,
      remainingSeconds: total,
      status: "running",
      guideText: (self._guideSegments[0] || ""),
      progress: 100,
     statusText: "冥想中，长按触摸后说话"
    });
    self.updateRingStyle(100, 0);
    self.startBreathing(true);
    self.startMeditationAudio(self.selectMeditationTrack(), true);
    self.cycleGuide();
    self.startTimer();
  },

  // 分段滚动：每段50秒滚完，间隔5秒后切下一段，循环
  cycleGuide: function() {
    var self = this;
    var segs = self._guideSegments || [];
    if (segs.length === 0) return;
    var i = self._guideIdx;
    // 切到第 i 段，重置 key 触发动画重新播放
    self.setData({ guideText: segs[i], guideKey: (self.data.guideKey || 0) + 1 });
    self._guideTimer = setTimeout(function() {
      // 50秒滚完，清空进入5秒间隔
      self.setData({ guideText: "" });
      self._guideIdx = (i + 1) % segs.length;
      self._guideTimer = setTimeout(function() {
        self.cycleGuide();
      }, 5000);
    }, 50000);
  },

  stopGuide: function() {
    if (this._guideTimer) { clearTimeout(this._guideTimer); this._guideTimer = null; }
  },

  startTimer: function() {
    var self = this;
    if (self.timer) { clearInterval(self.timer); }
    self.timer = setInterval(function() {
      var remain = self.data.remainingSeconds - 1;
      if (remain <= 0) {
        clearInterval(self.timer);
        self.timer = null;
        self.stopGuide();
        self.stopMeditationAudio(true);
        self._meditationPauseRequested = false;
       self.setData({ remainingSeconds: 0, timerText: "00:00", progress: 0, status: "completed", guideText: "修行圆满，随喜赞叹", statusText: "已完成" });
        self.updateRingStyle(0, self.data.totalSeconds);
        self.stopBreathing(true);
        self.speak("修行圆满，随喜赞叹");
        self.resumeRecognitionAfterMeditation();
        return;
      }
      var mins = Math.floor(remain / 60);
      var secs = remain % 60;
      var ts = (mins < 10 ? "0" : "") + mins + ":" + (secs < 10 ? "0" : "") + secs;
      var pct = Math.round((remain / self.data.totalSeconds) * 100);
     self.setData({ remainingSeconds: remain, timerText: ts, progress: pct });
      self.updateRingStyle(pct, self.data.totalSeconds - remain);
    }, 1000);
  },

  togglePause: function() {
    if (this.data.status === "completed") return;
    if (this.data.status === "running") {
      this._meditationPauseRequested = true;
      if (this.timer) { clearInterval(this.timer); this.timer = null; }
      this.stopBreathing(false);
      this.pauseMeditationAudio();
      this.setData({ status: "paused", statusText: "已暂停" });
    } else if (this.data.status === "paused") {
      this._meditationPauseRequested = false;
      this.setData({ status: "running", statusText: "冥想中，长按触摸后说话" });
      this.resumeMeditationAudio();
      this.startTimer();
      this.startBreathing(false);
    }
  },

  resetMeditation: function() {
    if (this.timer) { clearInterval(this.timer); this.timer = null; }
    this.stopGuide();
    this.stopMeditationAudio(true);
    this.stopBreathing(true);
    this.audioPlayCount = 0;
    this.audioMaxPlays = 0;
    this.audioSessionTotalSeconds = 0;
    this._meditationPauseRequested = false;
    this.setData({
      step: "type", status: "idle",
      typeIdx: 0, durationIdx: 2, durationMinutes: 10,
      timerText: "10:00", totalSeconds: 0, remainingSeconds: 0, progress: 100,
      guideText: "请选择修行方式",
     statusText: "说出「呼吸」「扫描」「静坐」选方式"
    });
    this.updateRingStyle(100, 0);
    this.resumeRecognitionAfterMeditation();
  },

  // ===== 键盘/触摸导航 =====
  onKeyUp: function(event) {
    var code = event.code;
    var self = this;

    if (code === "GlobalHook") {
      self.onVoiceWakeup(event);
      return;
    }

    if (self.data.step === "type") {
      if (code === "ArrowUp") {
        var next = self.data.typeIdx + 1;
        if (next >= TYPE_OPTIONS.length) { next = 0; }
        self.setData({ typeIdx: next });
      }
      else if (code === "ArrowDown") {
        var prev = self.data.typeIdx - 1;
        if (prev < 0) { prev = TYPE_OPTIONS.length - 1; }
        self.setData({ typeIdx: prev });
      }
      else if (code === "Enter") { self.confirmType(); }
      else if (code === "Backspace") { wx.navigateBack(); }
    }
    else if (self.data.step === "duration") {
      if (code === "ArrowUp") {
        var dn = self.data.durationIdx + 1;
        if (dn >= PRESET_DURATIONS.length) { dn = 0; }
        self.setDuration(PRESET_DURATIONS[dn]);
      }
      else if (code === "ArrowDown") {
        var dp = self.data.durationIdx - 1;
        if (dp < 0) { dp = PRESET_DURATIONS.length - 1; }
        self.setDuration(PRESET_DURATIONS[dp]);
      }
      else if (code === "Enter") { self.confirmDuration(); }
      else if (code === "Backspace") {
        self.setData({ step: "type", statusText: "请选择修行方式" });
      }
    }
    else if (self.data.step === "timer") {
      if (code === "Enter") { self.togglePause(); }
      else if (code === "Backspace") { self.resetMeditation(); }
    }
  }
};
</script>

<page>
  <view class="page-wrapper">
    <!-- ===== 面板 1: 修行方式 ===== -->
    <view class="container" ink:if="{{step === 'type'}}" key="type-panel">
      <view class="voice-bar {{listening ? 'active' : ''}}">
        <text class="voice-icon">{{ listening ? '🎙' : '🧘' }}</text>
        <text class="voice-text">{{ statusText }}</text>
      </view>

      <text class="title">🧘 冥想修行</text>
      <text class="section-label">选择修行方式</text>

      <view class="type-list">
        <view ink:for="{{typeOptions}}" ink:key="key" class="type-card-wrap {{index === typeIdx ? 'type-card-wrap-selected' : ''}}">
          <card bindtap="setType" data-idx="{{index}}" class="type-card-shell">
            <view class="type-card">
            <text class="type-icon">{{ item.icon }}</text>
            <text class="type-name">{{ item.name }}</text>
            <text class="type-desc">{{ item.desc }}</text>
            </view>
          </card>
        </view>
      </view>

    </view>

    <!-- ===== 面板 2: 时长选择 ===== -->
    <view class="container" ink:if="{{step === 'duration'}}" key="duration-panel">
      <view class="voice-bar {{listening ? 'active' : ''}}">
        <text class="voice-icon">{{ listening ? '🎙' : '🧘' }}</text>
        <text class="voice-text">{{ statusText }}</text>
      </view>

      <text class="title">{{ typeOptions[typeIdx].icon }} {{ typeOptions[typeIdx].name }}</text>
      <text class="section-label">选择时长</text>

      <view class="duration-picker">
        <text class="arrow-up">▲</text>
        <text class="duration-big">{{ durationMinutes }}</text>
        <text class="duration-unit">分钟</text>
        <text class="arrow-down">▼</text>
      </view>

    </view>

    <!-- ===== 面板 3: 计时器 ===== -->
    <view class="container timer-container" ink:if="{{step === 'timer'}}" key="timer-panel">
      <view class="voice-bar {{listening ? 'active' : ''}}">
        <text class="voice-icon">{{ listening ? '🎙' : '🧘' }}</text>
        <text class="voice-text">{{ statusText }}</text>
      </view>

      <view class="timer-ring-wrap">
        <view class="timer-ring-stage">
          <view class="timer-halo" style="{{haloStyle}}"></view>
          <view class="timer-ring" style="opacity: {{ringOpacity}};">
            <view class="timer-ring-inner">
              <text class="timer-text">{{ timerText }}</text>
              <view class="pause-indicator" bindtap="togglePause">
                <text class="indicator-icon">{{ status === 'running' ? '⏸' : (status === 'paused' ? '▶' : (status === 'completed' ? '🙏' : '')) }}</text>
              </view>
            </view>
          </view>
        </view>
      </view>

      <view class="hint-wrap"><view class="hint-dim" style="opacity: {{ringOpacity}};"><text class="hint-scroll" key="g{{guideKey}}">{{ guideText }}</text></view></view>

    </view>
  </view>
</page>

<style>
/* ===== 页面包裹 ===== */
.page-wrapper { width: 407px; min-height: 288px; background-color: #000; }

/* ===== 容器 ===== */
.container {
  display: flex; flex-direction: column; align-items: center;
  width: 407px; padding: 12px; gap: 15px;
  background-color: #000; min-height: 288px;
}
.timer-container { gap: 15px; }

/* ===== 语音状态栏 ===== */
.voice-bar {
  display: flex; flex-direction: row; align-items: center; gap: 6px;
  width: 100%; padding: 6px 10px;
  background-color: rgba(64,255,94,0.04);
  border: 1px solid rgba(64,255,94,0.08);
  border-radius: 10px;
}
.voice-bar.active {
  background-color: rgba(64,255,94,0.08);
  border-color: rgba(64,255,94,0.3);
}
.voice-icon { font-size: 12px; font-weight: 700; color: #40FF5E; }
.voice-text { font-size: 11px; color: rgba(64,255,94,0.6); flex: 1; }

/* ===== 标题 & 标签 ===== */
.title { font-size: 16px; font-weight: 700; color: #40FF5E; }
.section-label { font-size: 11px; color: rgba(64,255,94,0.5); align-self: center; }

/* ===== 面板 1: 修行方式列表 ===== */
.type-list { display: flex; flex-direction: column; gap: 8px; width: 100%; margin-top: 2px; }
.type-card-wrap { display: flex; flex-direction: row; align-items: center; width: 100%; border: 1px solid rgba(64,255,94,0.08); border-radius: 10px; }
.type-card-wrap-selected { background-color: rgba(64,255,94,0.2); border-color: transparent; }
.type-card-shell { width: 100%; border-width: 0; background-color: transparent; }
.type-card { display: flex; flex-direction: row; align-items: center; gap: 12px; padding: 5px 14px; border-radius: 10px; }
.type-icon { font-size: 26px; flex-shrink: 0; }
.type-info { display: flex; flex-direction: column; gap: 2px; flex: 1; }
.type-name { font-size: 18px; font-weight: 700; color: #40FF5E; }
.type-desc { flex: 1; font-size: 12px; color: rgba(64,255,94,0.5); }

/* ===== 面板 2: 时长选择 ===== */
.duration-picker {
  display: flex; flex-direction: column; align-items: center; justify-content: center;
  width: 150px; height: 150px; border-radius: 50%;
  border: 3px solid #40FF5E; gap: 2px; margin-top: 6px;
}
.arrow-up { font-size: 14px; color: rgba(64,255,94,0.35); }
.arrow-down { font-size: 14px; color: rgba(64,255,94,0.35); }
.duration-big { font-size: 42px; font-weight: 800; color: #40FF5E; line-height: 1; }
.duration-unit { font-size: 13px; color: rgba(64,255,94,0.5); }

/* ===== 面板 3: 计时器 ===== */
.timer-ring-wrap { display: flex; align-items: center; justify-content: center; padding: 4px; margin-top: 10px; }
.timer-ring-stage { position: relative; display: flex; align-items: center; justify-content: center; width: 194px; height: 194px; }
.timer-halo { position: absolute; left: 9px; top: 9px; width: 168px; height: 168px; border: 4px solid #40FF5E; border-radius: 50%; background-color: rgba(64,255,94,0.01); }
.timer-ring {
  position: relative;
  display: flex; align-items: center; justify-content: center;
  width: 152px; height: 152px; border-radius: 50%;
  border: 3px solid transparent;
  background-color: transparent;
}
.timer-ring-inner {
  display: flex; flex-direction: column; align-items: center; justify-content: center;
  width: 138px; height: 138px; border-radius: 50%;
  background: transparent; gap: 30px;
}
.timer-text { font-size: 32px; color: #40FF5E; font-family: monospace; font-weight: 700; }
.pause-indicator { display: flex; align-items: center; justify-content: center; }
.indicator-icon { font-size: 24px; }


/* ===== 底部提示 --- 缓慢滚动 ===== */
.hint-wrap {
  width: 100%; height: 96px; overflow: hidden; margin-top: 4px;
}
.hint-dim { width: 100%; }
.hint-scroll {
  display: block; white-space: normal; text-align: center;
  font-size: 14px; line-height: 1.6; color: rgba(64,255,94,0.4);
  padding: 0 16px;
  animation: hintSlide 50s ease-out;
}
@keyframes hintSlide {
  0%   { transform: translateY(100%); opacity: 0; }
  15%  { transform: translateY(0); opacity: 1; }
  85%  { transform: translateY(0); opacity: 1; }
  100% { transform: translateY(-20%); opacity: 0; }
}
</style>
