<script def>
{
  "navigationBarTitleText": "🪷 观自在",
  "description": "观自在 AI 修行伴侣首页 — 语音命令控制：说诵经/冥想/参禅进入功能"
}
</script>

<script setup>
import wx from 'wx';

var ZEN_QUOTES = [
  { quote: "应无所住而生其心", source: "金刚经" },
  { quote: "色即是空，空即是色", source: "心经" },
  { quote: "一切有为法，如梦幻泡影", source: "金刚经" },
  { quote: "照见五蕴皆空，度一切苦厄", source: "心经" },
  { quote: "菩提本无树，明镜亦非台", source: "六祖坛经" },
  { quote: "本来无一物，何处惹尘埃", source: "六祖坛经" },
  { quote: "放下屠刀，立地成佛", source: "五灯会元" },
  { quote: "一花一世界，一叶一菩提", source: "华严经" },
  { quote: "众生皆具如来智慧德相", source: "华严经" },
  { quote: "善护念", source: "金刚经" },
  { quote: "凡所有相，皆是虚妄", source: "金刚经" },
  { quote: "过去心不可得，现在心不可得，未来心不可得", source: "金刚经" },
  { quote: "无罣碍故，无有恐怖", source: "心经" },
  { quote: "远离颠倒梦想，究竟涅槃", source: "心经" },
  { quote: "心生则种种法生，心灭则种种法灭", source: "大乘起信论" },
  { quote: "一切众生皆具如来智慧德相，但以妄想执着不能证得", source: "华严经" },
  { quote: "知一切法无我，得成于忍", source: "金刚经" },
  { quote: "若以色见我，以音声求我，是人行邪道，不能见如来", source: "金刚经" },
  { quote: "一念迷即凡，一念悟即佛", source: "六祖坛经" },
  { quote: "不是风动，不是幡动，仁者心动", source: "六祖坛经" },
  { quote: "何期自性本自清净，何期自性能生万法", source: "六祖坛经" },
  { quote: "见性成佛", source: "六祖坛经" },
  { quote: "心净则国土净", source: "维摩诘经" },
  { quote: "随其心净则佛土净", source: "维摩诘经" },
  { quote: "深入经藏，智慧如海", source: "普贤行愿品" },
  { quote: "菩提心者，犹如种子，能生一切诸佛法故", source: "华严经" },
  { quote: "不忘初心，方得始终", source: "华严经" },
  { quote: "一切法得成于忍", source: "金刚经" },
  { quote: "若人欲了知，三世一切佛，应观法界性，一切唯心造", source: "华严经" },
];

function calculateCheckinStreak(today, lastDate, savedStreak) {
  var safeStreak = parseInt(savedStreak, 10);
  if (!lastDate || !safeStreak || safeStreak < 1 || !/^\d{4}-\d{2}-\d{2}$/.test(lastDate)) return 1;
  if (lastDate === today) return safeStreak;
  var todayMs = new Date(today + 'T00:00:00').getTime();
  var lastMs = new Date(lastDate + 'T00:00:00').getTime();
  if (!isNaN(todayMs) && !isNaN(lastMs) && todayMs - lastMs === 86400000) return safeStreak + 1;
  return 1;
}

function getLocalDateKey(date) {
  var year = date.getFullYear();
  var month = date.getMonth() + 1;
  var day = date.getDate();
  return year + '-' + (month < 10 ? '0' : '') + month + '-' + (day < 10 ? '0' : '') + day;
}

export default {
  data: {
    greeting: "阿弥陀佛",
    dailyQuote: "应无所住而生其心",
    quoteSource: "金刚经",
    streakDays: 1,
    statusText: "长按触摸后，说「读经文」「敲木鱼」「冥想」「聊佛法」进入",
    listening: false,
    selectedIdx: 0,
  menus: [
     { key: "scripture", name: "📖 读经文", desc: "心经·金刚经·大悲咒", url: "/pages/scripture/scripture" },
    { key: "muyu", name: "🥁 敲木鱼", desc: "积功德·静心", url: "/pages/muyu/muyu" },
    { key: "meditation", name: "🧘 冥想", desc: "正念呼吸·身体扫描", url: "/pages/meditation/meditation" },
    { key: "chat", name: "💬 聊佛法", desc: "解经释义·修行答疑", url: "/pages/chat/chat" },
  ]
  },

  recognition: null,
  _restartTimer: null,
  _lastNavTs: 0,

  updateCheckin: function() {
    var today = getLocalDateKey(new Date());
    var streak = 1;
    try {
      var lastDate = wx.getStorageSync('checkin_last_date') || '';
      var savedStreak = wx.getStorageSync('checkin_streak_days') || 0;
      streak = calculateCheckinStreak(today, lastDate, savedStreak);
      wx.setStorageSync('checkin_last_date', today);
      wx.setStorageSync('checkin_streak_days', streak);
    } catch (e) {
      streak = 1;
    }
    this.setData({ streakDays: streak });
  },

  onLoad: function() {
    var self = this;
    self.updateCheckin();
    var h = new Date().getHours();
    var g = "阿弥陀佛";
    if (h < 6) g = "夜深人静，正宜观心";
    else if (h < 9) g = "晨光初现，善哉一日始";
    else if (h < 12) g = "阿弥陀佛，上午好";
    else if (h < 18) g = "午后时光，不妨歇一歇";
    else g = "暮色渐至，万缘放下";
    self.setData({ greeting: g });

    var today = new Date().toDateString();
    var hash = 0;
    for (var j = 0; j < today.length; j++) { hash = ((hash << 5) - hash) + today.charCodeAt(j); }
    var idx = Math.abs(hash % ZEN_QUOTES.length);
    var rz = ZEN_QUOTES[idx];
    self.setData({ dailyQuote: rz.quote, quoteSource: rz.source });

    // 播报欢迎语；语音识别由 onVoiceWakeup 触发，不在 onLoad/onShow 中启动
    self.speak("阿弥陀佛，请说读经文、敲木鱼、冥想或聊佛法");
  },

  onShow: function() {
    if (this._restartTimer) { clearTimeout(this._restartTimer); this._restartTimer = null; }
    // 返回本页时仅清理旧识别实例，不自动启动监听（等待 onVoiceWakeup 唤醒）
    try {
      if (this.recognition) {
        var r = this.recognition;
        this.recognition = null;
        r.abort();
      }
    } catch (e) {}
    this.setData({
      listening: false,
      statusText: "长按触摸后，说「读经文」「敲木鱼」「冥想」「聊佛法」进入"
    });
  },

  onHide: function() {
    if (this._restartTimer) { clearTimeout(this._restartTimer); this._restartTimer = null; }
    try {
      if (this.recognition) {
        var r = this.recognition;
        this.recognition = null;
        try { r.abort(); } catch (e) {}
      }
    } catch (e) {}
    this.setData({ listening: false });
  },

  // ===== 语音识别 (ASR) =====
  initRecognition: function() {
    var self = this;
    self.setData({ listening: false });

    try {
      var recognition = new SpeechRecognition();
      self.recognition = recognition;
      recognition.lang = "zh-CN";
      recognition.continuous = false;
      recognition.interimResults = false;
      recognition.maxAlternatives = 1;

      recognition.onresult = function(event) {
        if (self.recognition !== recognition) return;
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

        if (!text) {
          self._scheduleRestart(1000);
          return;
        }

        self.setData({ statusText: "听到: " + text });
        self.handleCommand(text);
        self._scheduleRestart(2000);
      };

      recognition.onerror = function(event) {
        if (self.recognition !== recognition) return;
        self.setData({ listening: false, statusText: "语音出错: " + (event.error || "未知") });
        self._scheduleRestart(2000);
      };

      recognition.onend = function() {
        if (self.recognition !== recognition) return;
        self.setData({ listening: false });
        self._scheduleRestart(1500);
      };

      recognition.onnomatch = function() {
        if (self.recognition !== recognition) return;
        self.setData({ listening: false });
        self._scheduleRestart(1500);
      };

      self.startRecognition();
    } catch (e) {
      self.setData({ statusText: "语音不可用: " + (e.message || e) });
      self.recognition = null;
    }
  },

  _scheduleRestart: function(ms) {
    var self = this;
    if (self._restartTimer) { clearTimeout(self._restartTimer); }
    self._restartTimer = setTimeout(function() {
      self._restartTimer = null;
      self.startRecognition();
    }, ms);
  },

  // 启动语音识别
  startRecognition: function() {
    var self = this;
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
        self._scheduleRestart(500);
      } else {
        self._scheduleRestart(2000);
      }
    }
  },

  // ===== 语音命令路由 =====
  handleCommand: function(text) {
    var self = this;
    var t = text.replace(/\s/g, "");

    // 读经文
    if (t.indexOf("读经文") > -1 || t.indexOf("诵经") > -1 || t.indexOf("读经") > -1 || t.indexOf("念经") > -1 || t.indexOf("经文") > -1) {
      self.stopRecognition();
      self.setData({ statusText: "进入读经文" });
      wx.navigateTo({ url: "/pages/scripture/scripture" });
    }
    // 敲木鱼
    else if (t.indexOf("敲木鱼") > -1 || t.indexOf("木鱼") > -1 || t.indexOf("功德") > -1) {
      self.stopRecognition();
      self.setData({ statusText: "进入敲木鱼" });
      wx.navigateTo({ url: "/pages/muyu/muyu" });
    }
    // 冥想 / 修行
    else if (t.indexOf("冥想") > -1 || t.indexOf("打坐") > -1 || t.indexOf("修行") > -1 || t.indexOf("坐禅") > -1) {
      self.stopRecognition();
      self.setData({ statusText: "进入冥想" });
      wx.navigateTo({ url: "/pages/meditation/meditation" });
    }
    // 聊佛法 / 对话
    else if (t.indexOf("聊佛法") > -1 || t.indexOf("参禅") > -1 || t.indexOf("对话") > -1 || t.indexOf("聊天") > -1 || t.indexOf("佛法") > -1) {
      self.stopRecognition();
      self.setData({ statusText: "进入聊佛法" });
      wx.navigateTo({ url: "/pages/chat/chat" });
    }
    // 观自在 / 唤醒
    else if (t.indexOf("观自在") > -1 || t.indexOf("唤醒") > -1) {
      self.speak("我在，请说指令");
    }
    // 无法识别
    else if (t.length > 0) {
      self.setData({ statusText: "未识别: " + t });
      self.speak("请再说一遍");
    }
  },

  // 停止语音识别
  stopRecognition: function() {
    if (this._restartTimer) { clearTimeout(this._restartTimer); this._restartTimer = null; }
    try {
      if (this.recognition) {
        var r = this.recognition;
        this.recognition = null;
        r.abort();
      }
    } catch (e) {}
    this.setData({ listening: false });
  },

  // 导航 (不播报 TTS，避免与导航冲突)
  navigatePage: function(url) {
    var self = this;
    self.stopRecognition();
    self.setData({ statusText: "导航中..." });
    setTimeout(function() {
      wx.navigateTo({ url: url });
    }, 300);
  },

  // ===== 语音播报 (TTS) =====
  speak: function(text) {
    try {
      // 方式一: speechSynthesis
      var u = new SpeechSynthesisUtterance(text);
      u.lang = "zh-CN";
      u.rate = 1.0;
      speechSynthesis.speak(u);
    } catch (e) {
      try {
        // 方式二: wx.speech
        wx.speech.playTTS(text);
      } catch (e2) {}
    }
  },

  // ===== 语音唤醒 (灵珠平台/眼镜) =====
  onVoiceWakeup: function(event) {
    this.initRecognition();
    this.startRecognition();
  },

  // ===== 触控 (备用) =====
  handleMenuTap: function(e) {
    var self = this;
    var url = e.currentTarget.dataset.url;
    if (url) {
      self.stopRecognition();
      wx.navigateTo({ url: url });
    }
  },

  // ===== 按键事件 =====
  onKeyUp: function(event) {
    var code = event.code;
    // 菜单网格：方向键 + Enter 导航
    // 节流：眼镜滑动手势可能一次连发多次方向键，导致跳过相邻项
    if (code === "ArrowUp" || code === "ArrowLeft" || code === "ArrowDown" || code === "ArrowRight") {
      var now = Date.now ? Date.now() : new Date().getTime();
      if (now - (this._lastNavTs || 0) < 220) { return; }
      this._lastNavTs = now;
    }
    if (code === "ArrowUp" || code === "ArrowLeft") {
      // 前滑/向下选择下一项
      var next = this.data.selectedIdx + 1;
      if (next >= this.data.menus.length) { next = 0; }
      this.setData({ selectedIdx: next });
    }
    else if (code === "ArrowDown" || code === "ArrowRight") {
      // 后滑/向上选择上一项
      var prev = this.data.selectedIdx - 1;
      if (prev < 0) { prev = this.data.menus.length - 1; }
      this.setData({ selectedIdx: prev });
    }
    else if (code === "Enter") {
      if (this.data.selectedIdx >= 0) {
        var item = this.data.menus[this.data.selectedIdx];
        if (item && item.url) { this.stopRecognition(); wx.navigateTo({ url: item.url }); }
      } else {
        this.speak("请说");
        this.startRecognition();
      }
    }
  }
};
</script>

<page>
  <view class="container">
    <view class="header">
      <text class="greeting">{{ greeting }}</text>
      <text class="app-name">🪷 观自在</text>
      <text class="streak">🔥 连续 {{ streakDays }} 天</text>
    </view>

    <!-- 语音状态栏 -->
    <view class="voice-bar {{listening ? 'active' : ''}}">
      <text class="voice-icon">{{ listening ? '...' : 'x' }}</text>
      <text class="voice-text">{{ statusText }}</text>
    </view>

    <!-- 每日禅语 -->
    <view class="zen-card">
      <text class="zen-quote">"{{ dailyQuote }}"</text>
      <text class="zen-source">—— {{ quoteSource }}</text>
    </view>

    <!-- 功能菜单 (触控+遥控器) -->
    <view class="menu-grid">
      <view ink:for="{{menus}}" ink:key="key" class="menu-item-wrap {{index === selectedIdx ? 'menu-item-wrap-selected' : ''}}">
        <card data-url="{{item.url}}" bindtap="handleMenuTap" class="menu-card-shell">
          <view class="menu-item">
          <view class="menu-text">
            <text class="menu-name">{{ item.name }}</text>
            <text class="menu-desc">{{ item.desc }}</text>
          </view>
          </view>
        </card>
      </view>
    </view>

    <!-- 底部提示 -->
    <text class="hint">长按触摸后，说「读经文」「敲木鱼」「冥想」「聊佛法」进入</text>
  </view>
</page>

<style>
.container {
  display: flex; flex-direction: column; align-items: center;
  width: 407px; min-height: 288px; background-color: #000;
  padding: 14px; gap: 10px;
}
.header {
  display: flex; flex-direction: row; align-items: center; width: 407px; position: relative;
}
.greeting { font-size: 12px; color: rgba(64,255,94,0.6); flex-shrink: 0; }
.app-name { font-size: 15px; font-weight: 700; color: #40FF5E; position: absolute; left: 50%; transform: translateX(-50%); }
.streak { font-size: 10px; color: rgba(64,255,94,0.7); margin-left: auto; }

.voice-bar {
  display: flex; flex-direction: row; align-items: center; gap: 6px;
  width: 407px; padding: 6px 10px;
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

.zen-card {
  display: flex; flex-direction: column; align-items: center;
  width: 407px; padding: 10px;
  background-color: rgba(64,255,94,0.06);
  border: 2px solid rgba(64,255,94,0.08);
  border-radius: 12px; gap: 4px;
}
.zen-quote { font-size: 14px; color: #40FF5E; text-align: center; line-height: 1.5; }
.zen-source { font-size: 11px; color: rgba(64,255,94,0.6); }
.menu-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 10px; width: 407px; }
.menu-item-wrap {
  display: flex; flex-direction: row; align-items: center;
  min-height: 48px; border: 1px solid rgba(64,255,94,0.5); border-radius: 10px;
}
.menu-item-wrap-selected { background-color: rgba(64,255,94,0.2); border-color: transparent; }
.menu-card-shell { width: 100%; border-width: 0; background-color: transparent; }
.menu-item { display: flex; flex-direction: row; align-items: center; padding: 4px; gap: 10px; min-height: 48px; }
.menu-text { display: flex; flex-direction: column; gap: 2px; }
.menu-name { font-size: 16px; font-weight: 700; color: #40FF5E; }
.menu-desc { font-size: 10px; color: rgba(64,255,94,0.6); }
.hint { font-size: 10px; color: rgba(64,255,94,0.4); text-align: center; }
</style>
