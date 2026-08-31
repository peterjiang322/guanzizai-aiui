<script def>
{
  "navigationBarTitleText": "🎵 白噪音",
  "description": "白噪音音景 — 6 种自然禅境，滑动选择"
}
</script>

<script setup>
import wx from 'wx';

var AUDIO_PATH_MAP = {
  "morning-temple": "../../assets/morning_temple.wav",
  "morning_temple.wav": "../../assets/morning_temple.wav",
  "temple_bell": "../../assets/morning_temple.wav",
  "morning_birds": "../../assets/morning_temple.wav",
  "bamboo_wind": "../../assets/morning_temple.wav",
  "rain-zen": "../../assets/rain_zen.wav",
  "rain_zen.wav": "../../assets/rain_zen.wav",
  "rain_gentle": "../../assets/rain_zen.wav",
  "water_drops": "../../assets/rain_zen.wav",
  "stream-forest": "../../assets/stream_forest.wav",
  "stream_forest.wav": "../../assets/stream_forest.wav",
  "stream": "../../assets/stream_forest.wav",
  "occasional_bird": "../../assets/stream_forest.wav",
  "ocean-mindfulness": "../../assets/ocean_mindfulness.wav",
  "ocean_mindfulness.wav": "../../assets/ocean_mindfulness.wav",
  "ocean_waves": "../../assets/ocean_mindfulness.wav",
  "night-temple": "../../assets/night_temple.wav",
  "night_temple.wav": "../../assets/night_temple.wav",
  "temple_drum": "../../assets/night_temple.wav",
  "singing_bowl": "../../assets/night_temple.wav",
  "night_cicada": "../../assets/night_temple.wav",
  "incense-chamber": "../../assets/incense_chamber.wav",
  "incense_chamber.wav": "../../assets/incense_chamber.wav",
  "muyu_slow": "../../assets/incense_chamber.wav",
  "silence": "../../assets/incense_chamber.wav"
};

// 各音频文件实际时长(ms)，用于 setInterval 精准循环
// 仅 Sound 降级方案使用；AudioPlayer 用原生 loop=true 无需定时器
var AUDIO_LOOP_MS = {
  "morning_temple.wav": 3000,
  "rain_zen.wav": 3000,
  "stream_forest.wav": 7000,
  "ocean_mindfulness.wav": 4000,
  "night_temple.wav": 10000,
  "incense_chamber.wav": 3000
};

function loopMsForFile(file) {
  if (!file) return 3000;
  var f = file.replace(/^.*\//, "");
  return AUDIO_LOOP_MS[f] || AUDIO_LOOP_MS[file] || 3000;
}

export default {
  data: {
    page: "list",
    scenes: [],
    selectedIdx: 0,
    scene: { icon: "", name: "", description: "" },
   loading: true,
   statusText: "请选择场景",
    isPlaying: false,
    isPaused: false,
    playStatusText: "⏹ 已停止",
    playIcon: "⏹"
  },

  audioPlayer: null,
  audioMode: "",
  audioLoopTimer: null,
  currentAudioScene: null,

  onLoad: function() {
    var self = this;
   self.speak("请选择禅境音景");
   self.loadScenes();
 },

  onUnload: function() {
    this.stopAudio();
  },

  loadScenes: function() {
    var self = this;
    var app = getApp();
    wx.request({
      url: app.globalData.baseUrl + "/api/soundscapes/list",
      method: "GET",
      responseType: "text",
      dataType: "json",
      success: function(res) {
        var list = (res.data && res.data.scenes) || [];
        for (var i = 0; i < list.length; i++) {
          if (!list[i].file && list[i].tracks && list[i].tracks.length > 0) {
            list[i].file = list[i].tracks[0].sound;
          }
        }
        self.setData({ scenes: list, loading: false });
        if (list.length === 0) {
          self.setData({ statusText: "暂无场景数据" });
        }
      },
      fail: function() {
        self.setData({
          scenes: [
            { id: "morning-temple", name: "晨钟", icon: "🔔", description: "清晨禅寺，钟声悠远，鸟儿轻啼", tags: ["清晨","禅寺"], file: "morning_temple.wav" },
            { id: "rain-zen", name: "雨声禅定", icon: "🌧️", description: "雨打芭蕉，水滴石阶，远山隐隐", tags: ["雨天","冥想"], file: "rain_zen.wav" },
            { id: "stream-forest", name: "溪林", icon: "🌿", description: "山涧流水，竹林风过，偶有鸟鸣", tags: ["溪流","自然"], file: "stream_forest.wav" },
            { id: "ocean-mindfulness", name: "潮音", icon: "🌊", description: "潮起潮落，如观世音耳根圆通", tags: ["海浪","禅修"], file: "ocean_mindfulness.wav" },
            { id: "night-temple", name: "暮鼓", icon: "🌙", description: "夜幕降临，暮鼓声声，磬音悠长", tags: ["夜晚","安眠"], file: "night_temple.wav" },
            { id: "incense-chamber", name: "香室", icon: "🪷", description: "室内焚香，木鱼轻敲，沉静安宁", tags: ["室内","修行"], file: "incense_chamber.wav" }
          ],
          loading: false
        });
      }
    });
  },

  clearAudioLoop: function() {
    if (this.audioLoopTimer) {
      clearInterval(this.audioLoopTimer);
      this.audioLoopTimer = null;
    }
  },

  destroyAudioPlayer: function() {
    var player = this.audioPlayer;
    if (!player) return;

    try { player.stop(); } catch (e) {}
    try { player.destroy(); } catch (e) {}
    this.audioPlayer = null;
    this.audioMode = "";
  },

  stopAudio: function() {
    this.clearAudioLoop();
    this.destroyAudioPlayer();
    this.setData({ isPlaying: false, isPaused: false, playStatusText: "⏹ 已停止", playIcon: "⏹" });
  },

  pauseAudio: function() {
    this.clearAudioLoop();
    if (this.audioPlayer) {
      if (this.audioMode === "audioPlayer" && typeof this.audioPlayer.pause === "function") {
        try { this.audioPlayer.pause(); } catch (e) {}
      } else {
        try { this.audioPlayer.stop(); } catch (e2) {}
      }
    }
    this.setData({ isPaused: true, playStatusText: "🔇 已暂停", playIcon: "▶" });
  },

  resumeAudio: function() {
    if (this.audioPlayer && this.audioMode === "audioPlayer") {
      try { this.audioPlayer.play(); } catch (e) {}
      this.setData({ isPaused: false, playStatusText: "🔊 播放中", playIcon: "⏸" });
      return;
    }

    if (this.currentAudioScene) {
      this.playScene(this.currentAudioScene);
    }
  },

  getAudioPath: function(scene) {
    if (!scene || !scene.file) return "";
    return AUDIO_PATH_MAP[scene.file] || AUDIO_PATH_MAP[scene.id] || ("../../assets/" + scene.file);
  },

  handleAudioError: function(message) {
    this.clearAudioLoop();
    this.destroyAudioPlayer();
    this.setData({
      statusText: message || "播放失败",
      isPlaying: false,
      isPaused: false,
      playStatusText: "⏹ 已停止",
      playIcon: "⏹"
    });
  },

  startSoundPlayback: function(scene, path) {
    var self = this;
    if (typeof Sound === "undefined") {
      self.handleAudioError("当前运行时不支持音频播放");
      return false;
    }

    var sound = new Sound(path);
    sound.volume = 0.5;
    sound.play();

    self.audioPlayer = sound;
    self.audioMode = "sound";
    var loopMs = loopMsForFile(scene.file);
    self.audioLoopTimer = setInterval(function() {
      if (!self.audioPlayer || self.audioMode !== "sound" || !self.data.isPlaying || self.data.isPaused) {
        return;
      }
      try {
        self.audioPlayer.play();
      } catch (e) {
        self.handleAudioError("循环播放失败");
      }
    }, loopMs);

    self.setData({
      isPlaying: true,
      isPaused: false,
      playStatusText: "🔊 播放中",
      playIcon: "⏸",
      statusText: "正在播放 " + scene.name
    });
    return true;
  },

  startAudioPlayerPlayback: function(scene, path) {
    var self = this;
    if (typeof AudioPlayer === "undefined") {
      return false;
    }

    var player = new AudioPlayer();
    player.src = path;
    player.loop = true;
    player.volume = 0.5;

    if (typeof player.onError === "function") {
      player.onError(function(error) {
        var msg = (error && error.message) ? error.message : String(error || "Unknown");
        console.log("AudioPlayer error: " + msg);
        self.destroyAudioPlayer();
        try {
          self.startSoundPlayback(scene, path);
        } catch (fallbackError) {
          self.handleAudioError("播放失败");
        }
      });
    }

    // loop=true 在 Craft 生效但真机可能不生效，onEnded 做兜底
    if (typeof player.onEnded === "function") {
      player.onEnded(function() {
        if (self.audioPlayer === player && self.data.isPlaying && !self.data.isPaused) {
          try { player.play(); } catch (e) {}
        }
      });
    }

    self.audioPlayer = player;
    self.audioMode = "audioPlayer";
    try {
      player.play();
    } catch (playError) {
      self.destroyAudioPlayer();
      return self.startSoundPlayback(scene, path);
    }
    // loop=true 原生循环，不启动 setInterval
    self.setData({
      isPlaying: true,
      isPaused: false,
      playStatusText: "🔊 播放中",
      playIcon: "⏸",
      statusText: "正在播放 " + scene.name
    });
    return true;
  },

  playScene: function(scene) {
    var self = this;
    self.stopAudio();

    if (!scene || !scene.file) {
      self.setData({ statusText: "该场景暂无音频" });
      return;
    }

    var path = self.getAudioPath(scene);
    self.currentAudioScene = scene;

    try {
      if (self.startAudioPlayerPlayback(scene, path)) {
        return;
      }
      if (self.startSoundPlayback(scene, path)) {
        return;
      }
    } catch (e) {
      self.handleAudioError("加载音频失败");
    }
  },

  speak: function(text) {
    try {
      var u = new SpeechSynthesisUtterance(text);
      u.lang = "zh-CN";
      u.rate = 1.0;
      speechSynthesis.speak(u);
   } catch (e) {
     try { wx.speech.playTTS(text); } catch (e2) {}
   }
 },

  selectScene: function(idx) {
    var scene = this.data.scenes[idx];
    if (!scene) return;
    this.setData({
      page: "detail",
      scene: scene,
      statusText: "已选择" + scene.name
    });
    try { wx.pageScrollTo({ scrollTop: 0 }); } catch(e) {}
    this.speak("已选择" + scene.name);
    this.playScene(scene);
  },

  handleSceneTap: function(e) {
    var idx = parseInt(e.currentTarget.dataset.idx, 10);
    if (!isNaN(idx)) { this.selectScene(idx); }
  },

  handleBack: function() {
    this.stopAudio();
    this.setData({
      page: "list",
      scene: { icon: "", name: "", description: "" },
      selectedIdx: 0,
      statusText: "请选择场景"
    });
    try { wx.pageScrollTo({ scrollTop: 0 }); } catch(e) {}
  },

  handlePauseResume: function() {
    if (this.data.isPaused) {
      this.resumeAudio();
    } else {
      this.pauseAudio();
    }
  },

  handleStop: function() {
    this.stopAudio();
    this.speak("已停止");
  },

  onKeyUp: function(event) {
    var code = event.code;
    if (this.data.page === "list") {
      if (code === "ArrowUp" || code === "ArrowLeft") {
        var next = this.data.selectedIdx + 1;
        if (next < this.data.scenes.length) { this.setData({ selectedIdx: next }); }
      }
      else if (code === "ArrowDown" || code === "ArrowRight") {
        var prev = this.data.selectedIdx - 1;
        if (prev >= 0) { this.setData({ selectedIdx: prev }); }
      }
      else if (code === "Enter") {
        this.selectScene(this.data.selectedIdx);
      }
      else if (code === "Backspace") {
        wx.navigateBack();
      }
    } else {
      if (code === "Backspace" || code === "Escape") {
        this.handleBack();
      }
      else if (code === "Enter") {
        this.handlePauseResume();
      }
    }
  }
};
</script>

<page>
  <view class="page-wrapper">
   <view class="container list-container" ink:if="{{page === 'list'}}" key="list-panel">
      <view class="voice-bar">
        <text class="voice-icon">🎵</text>
        <text class="voice-text">{{ statusText }}</text>
      </view>
      <text class="title">🎵 禅境音景</text>
      <view class="loading-text" ink:if="{{loading}}"><text>加载中...</text></view>
      <card ink:for="{{scenes}}" ink:key="id">
        <view class="scene-card {{index === selectedIdx ? 'scene-card-active' : ''}}" data-idx="{{index}}" bindtap="handleSceneTap">
          <text class="card-icon">{{ item.icon }}</text>
          <view class="card-info">
            <text class="card-name">{{ item.name }}</text>
            <text class="card-desc">{{ item.description }}</text>
          </view>
          <text class="card-check">{{ index === selectedIdx ? '✓' : '▶' }}</text>
        </view>
      </card>
    </view>

   <view class="container detail-container" ink:if="{{page === 'detail'}}" key="detail-panel">
      <view class="voice-bar">
        <text class="voice-icon">🎵</text>
        <text class="voice-text">{{ statusText }}</text>
      </view>
      <text class="title">{{ scene.name }}</text>
      <text class="big-icon">{{ scene.icon }}</text>
      <text class="desc-text">{{ scene.description }}</text>
      <view class="play-ring-wrap" ink:if="{{isPlaying}}" bindtap="handlePauseResume">
        <text class="play-ring-icon">{{ playIcon }}</text>
      </view>
    </view>
  </view>
</page>

<style>
.page-wrapper { width: 407px; min-height: 288px; background-color: #000; }
.container { display: flex; flex-direction: column; width: 407px; padding: 14px; background-color: #000; min-height: 288px; }
.list-container { gap: 12px; }
.detail-container { gap: 40px; }
.voice-bar { display: flex; flex-direction: row; align-items: center; gap: 6px; width: 100%; padding: 6px 10px; background-color: rgba(64,255,94,0.04); border: 1px solid rgba(64,255,94,0.08); border-radius: 10px; }
.voice-icon { font-size: 12px; font-weight: 700; color: #40FF5E; }
.voice-text { font-size: 11px; color: rgba(64,255,94,0.6); flex: 1; }
.title { font-size: 16px; font-weight: 700; color: #40FF5E; }
.loading-text { font-size: 12px; color: rgba(64,255,94,0.6); }
.scene-card { display: flex; flex-direction: row; align-items: center; gap: 2px; padding: 5px 14px; border-radius: 10px; border: 1px solid rgba(64,255,94,0.08); background: rgba(64,255,94,0.02); }
.scene-card-active { border-color: #40FF5E; background: rgba(64,255,94,0.08); }
.card-icon { font-size: 26px; flex-shrink: 0; }
.card-info { display: flex; flex-direction: column; gap: 2px; flex: 1; }
.card-name { font-size: 15px; font-weight: 700; color: #40FF5E; }
.card-desc { font-size: 11px; color: rgba(64,255,94,0.5); }
.card-check { font-size: 14px; color: #40FF5E; font-weight: 700; flex-shrink: 0; }
.big-icon { font-size: 36px; text-align: center; }
.desc-text { font-size: 13px; color: rgba(64,255,94,0.6); text-align: center; line-height: 1.5; }
.play-ring-wrap { display: flex; align-items: center; justify-content: center; padding: 4px; margin-top: 8px; }
.play-ring-icon { font-size: 32px; color: #40FF5E; }
</style>
