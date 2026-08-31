<script def>
{
  "navigationBarTitleText": "",
  "navigationStyle": "custom",
  "description": "佛经藏经阁 — 心经、金刚经、大悲咒等，语音控制翻页"
}
</script>

<script setup>
import wx from 'wx';

export default {
  data: {
    scriptures: [],
    showingDetail: false,
    scriptureName: "",
    sections: [],
    sectionIdx: 0,
    verseText: "",
    verseTitle: "",
    vernacular: "",
    totalSections: 1,
    selectedIdx: 0,
    scrollTarget: "card-0",
    statusText: "上下滑动选择经文，单击进入",
    lastBackspaceTime: 0,
    verseKey: 0,
    listening: false
  },

  recognition: null,
  _lastNavTs: 0,
  _verseTop: 0,
  _verseH: 0,
  _verseClient: 0,

  onLoad: function() {
    var self = this;
    self.loadScriptureList();
    self.speak("请说出你想诵读的经文名称");
    // onShow 会在页面进入前台时启动语音识别
  },

  onShow: function() {
    // 从其他页面进入时，清理旧实例 + 重新初始化语音识别
    try {
      if (this.recognition) { this.recognition.abort(); }
    } catch (e) {}
    this.recognition = null;
    this.initRecognition();
  },

  onHide: function() {
    try {
      if (this.recognition) { this.recognition.abort(); }
    } catch (e) {}
    this.recognition = null;
    this.setData({ listening: false });
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
          setTimeout(function() { self.startRecognition(); }, 1000);
          return;
        }
        setTimeout(function() { self.startRecognition(); }, 2000);
      };

      self.recognition.onerror = function(event) {
        self.setData({ listening: false, statusText: "语音出错: " + (event.error || "未知") });
        setTimeout(function() { self.startRecognition(); }, 2000);
      };

      self.recognition.onend = function() {
        self.setData({ listening: false });
        setTimeout(function() { self.startRecognition(); }, 1500);
      };

      self.recognition.onnomatch = function() {
        self.setData({ listening: false });
        setTimeout(function() { self.startRecognition(); }, 1500);
      };

      self.startRecognition();
    } catch (e) {
      self.setData({ statusText: "语音不可用: " + (e.message || e) });
      self.recognition = null;
    }
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
        setTimeout(function() { self.startRecognition(); }, 500);
      } else {
        setTimeout(function() { self.startRecognition(); }, 2000);
      }
    }
  },

  // 停止语音识别
  stopRecognition: function() {
    try {
      if (this.recognition) { this.recognition.abort(); }
    } catch (e) {}
    this.setData({ listening: false });
  },

  // ===== 语音命令路由 =====
  handleVoiceCommand: function(text) {
    var self = this;
    var t = text.replace(/\s/g, "");

    if (self.data.showingDetail) {
      // 阅读视图中的语音命令
      if (t.indexOf("上一品") > -1 || t.indexOf("上一页") > -1 || t.indexOf("上一") > -1 || t.indexOf("前") > -1) {
        self.handlePrev();
      }
      else if (t.indexOf("下一品") > -1 || t.indexOf("下一页") > -1 || t.indexOf("下一") > -1 || t.indexOf("后") > -1 || t.indexOf("继续") > -1) {
        self.handleNext();
      }
      else if (t.indexOf("返回") > -1 || t.indexOf("退回") > -1 || t.indexOf("退出") > -1) {
        self.handleBack();
        self.speak("返回经文列表");
      }
      else {
        self.setData({ statusText: "未识别: " + t });
      }
    } else {
      // 列表视图中的语音命令 —— 根据经文名称匹配
      var scriptures = self.data.scriptures;
      var aliases = {
        "金刚经": "diamond-sutra",
        "心经": "heart-sutra",
        "无量寿经": "infinite-life-sutra",
        "华严经": "huayan-selections",
        "法华经": "lotus-sutra",
        "药师经": "medicine-buddha-sutra",
        "楞严经": "shurangama-sutra"
      };
      for (var alias in aliases) {
        if (t.indexOf(alias) > -1) {
          var aliasId = aliases[alias];
          for (var k = 0; k < scriptures.length; k++) {
            if (scriptures[k].id === aliasId) {
              self.setData({ statusText: "进入" + scriptures[k].name });
              self.loadScripture(scriptures[k]);
              return;
            }
          }
        }
      }
      for (var i = 0; i < scriptures.length; i++) {
        var name = scriptures[i].name || "";
        // 取经文名称的关键字进行匹配
        var keywords = name.replace(/[《》\s]/g, "");
        if (t.indexOf(keywords) > -1 || t.indexOf(name) > -1) {
          self.setData({ statusText: "进入" + name });
          self.loadScripture(scriptures[i]);
          return;
        }
      }
      // 万能匹配：如果用户说出包含经文名字中前两个字的内容
      for (var j = 0; j < scriptures.length; j++) {
        var sname = scriptures[j].name || "";
        var short = sname.replace(/[《》\s]/g, "").substring(0, 2);
        if (short && t.indexOf(short) > -1) {
          self.setData({ statusText: "进入" + sname });
          self.loadScripture(scriptures[j]);
          return;
        }
      }
      if (t.indexOf("返回") > -1 || t.indexOf("退出") > -1) {
        self.stopRecognition();
        wx.navigateBack();
      }
      else {
        self.setData({ statusText: "未识别: " + t });
        self.speak("请说出经文名称");
      }
    }
  },

  // ===== 语音播报 (TTS) =====
  speak: function(text) {
    try {
      var u = new SpeechSynthesisUtterance(text);
      u.lang = "zh-CN";
      u.rate = 1.0;
      speechSynthesis.speak(u);
    } catch (e) {
      try {
        wx.speech.playTTS(text);
      } catch (e2) {}
    }
  },

  // ===== 语音唤醒 (灵珠平台/眼镜) =====
  onVoiceWakeup: function(event) {
    if (!this.recognition) {
      this.initRecognition();
    }
    this.startRecognition();
  },

  // ===== 加载经文列表 =====
  loadScriptureList: function() {
    var self = this;
    var app = getApp();
    wx.request({
      url: app.globalData.baseUrl + "/api/scripture/list",
      method: "GET",
      responseType: "text",
      dataType: "json",
      success: function(res) {
        var list = (res.data && res.data.scriptures) || [];
        self.setData({ scriptures: list });
        if (list.length === 0) {
          self.setData({ statusText: "未找到经文数据" });
        }
      },
      fail: function() {
        self.setData({ statusText: "经文加载失败" });
      }
    });
  },

  // ===== 双击镜腿返回 =====
  handleBackspace: function() {
    var now = Date.now ? Date.now() : new Date().getTime();
    var last = this.data.lastBackspaceTime;
    this.setData({ lastBackspaceTime: now });
    if (now - last < 500 && last > 0) {
      this.setData({ lastBackspaceTime: 0 });
      if (this.data.showingDetail) {
        this.handleBack();
      } else {
        wx.navigateBack();
      }
    }
  },

  // ===== 加载经文 =====
 loadScripture: function(item) {
   var self = this;
   var id = item.id;
   var name = item.name || "";
   var app = getApp();
    self._verseTop = 0; self._verseH = 0;
   self.setData({ statusText: "加载" + name + "..." });
    wx.request({
      url: app.globalData.baseUrl + '/api/scripture/' + id,
      method: 'GET',
      responseType: "text",
      dataType: "json",
      success: function(res) {
        var data = res.data || {};
        var secs = data.sections || [];
        var text = "", title = "", v = "";
        if (secs.length > 0) {
          title = secs[0].title || "";
          if (secs[0].verses && secs[0].verses.length > 0) {
            text = secs[0].verses[0].text_original || "";
            v = secs[0].verses[0].text_vernacular || "";
          }
        }
        self.setData({
          showingDetail: true,
          scriptureName: data.name || "",
          sections: secs, sectionIdx: 0,
          verseText: text, verseTitle: title,
         vernacular: v, totalSections: secs.length,
         verseKey: (self.data.verseKey || 0) + 1,
          verseScrollTop: 0,
         statusText: (data.name || "") + " · 上下滑动翻品"
        });
      },
      fail: function() {
        self.setData({ statusText: "加载失败" });
      }
    });
  },

  handleTap: function(e) {
    var id = e.currentTarget.dataset.id;
    var scriptures = this.data.scriptures;
    for (var i = 0; i < scriptures.length; i++) {
      if (scriptures[i].id === id) { this.loadScripture(scriptures[i]); break; }
   }
 },

  // ===== 经文滚动跟踪 =====
  onVerseScroll: function(event) {
    var d = event.detail || {};
    this._verseTop = d.scrollTop || 0;
    this._verseH = d.scrollHeight || 0;
    this._verseClient = d.clientHeight || 0;
  },

  // ===== 键盘/触摸 =====
  onKeyUp: function(event) {
  var code = event.code;
  if (this.data.showingDetail) {
      // 节流：眼镜滑动手势可能一次连发多次方向键
      if (code === "ArrowUp" || code === "ArrowDown" || code === "Enter") {
        var now = Date.now ? Date.now() : new Date().getTime();
        if (now - (this._lastNavTs || 0) < 220) { return; }
        this._lastNavTs = now;
      }
      if (code === "ArrowUp") {
        // 前滑/向下：已在底部 → 翻下一品；否则向下滚动内容
        if (this._verseH > 0 && this._verseTop + this._verseClient >= this._verseH - 5) {
          this.handleNext();
        } else {
          var down = (this._verseTop || 0) + 120;
          this.setData({ verseScrollTop: down });
          this._verseTop = down;
        }
      }
      else if (code === "ArrowDown") {
        // 后滑/向上：已在顶部 → 翻上一品；否则向上滚动内容
        if ((this._verseTop || 0) <= 5) {
          this.handlePrev();
        } else {
          var up = (this._verseTop || 0) - 120;
          if (up < 0) { up = 0; }
          this.setData({ verseScrollTop: up });
          this._verseTop = up;
        }
      }
      else if (code === "Enter") {
        this.handleNext();
      }
      else if (code === "Backspace") {
        this.handleBackspace();
      }
    }
   else {
      // 节流：眼镜滑动手势可能一次连发多次方向键，导致跳过相邻项
      if (code === "ArrowUp" || code === "ArrowLeft" || code === "ArrowDown" || code === "ArrowRight") {
        var now = Date.now ? Date.now() : new Date().getTime();
        if (now - (this._lastNavTs || 0) < 220) { return; }
        this._lastNavTs = now;
      }
    if (code === "ArrowUp" || code === "ArrowLeft") {
        var next = this.data.selectedIdx + 1;
        if (next >= this.data.scriptures.length) { next = 0; }
        this.setData({ selectedIdx: next, scrollTarget: "card-" + next, statusText: "已选中 · 单击进入" });
      }
      else if (code === "ArrowDown" || code === "ArrowRight") {
        var prev = this.data.selectedIdx - 1;
        if (prev < 0) { prev = this.data.scriptures.length - 1; }
        this.setData({ selectedIdx: prev, scrollTarget: "card-" + prev, statusText: "已选中 · 单击进入" });
      }
      else if (code === "Enter") {
        var sel = this.data.scriptures[this.data.selectedIdx];
        if (sel) { this.loadScripture(sel); }
      }
      else if (code === "Backspace") {
        this.handleBackspace();
      }
    }
  },

 handlePrev: function() {
   var idx = this.data.sectionIdx - 1;
   if (idx < 0) return;
   var sec = this.data.sections[idx];
   if (!sec) return;
   var key = this.data.verseKey + 1;
    this._verseTop = 0; this._verseH = 0;
   this.setData({
     sectionIdx: idx,
     verseKey: key,
      verseTitle: sec.title || "",
      verseText: (sec.verses && sec.verses[0] && sec.verses[0].text_original) || "",
      vernacular: (sec.verses && sec.verses[0] && sec.verses[0].text_vernacular) || "",
      verseScrollTop: 0
   });
 },

 handleNext: function() {
   var idx = this.data.sectionIdx + 1;
   if (idx >= this.data.totalSections) { idx = 0; }
   var sec = this.data.sections[idx];
   if (!sec) return;
   var key = this.data.verseKey + 1;
    this._verseTop = 0; this._verseH = 0;
   this.setData({
     sectionIdx: idx,
     verseKey: key,
      verseTitle: sec.title || "",
      verseText: (sec.verses && sec.verses[0] && sec.verses[0].text_original) || "",
      vernacular: (sec.verses && sec.verses[0] && sec.verses[0].text_vernacular) || "",
      verseScrollTop: 0
   });
 },

 handleBack: function() {
   this.setData({
     showingDetail: false, scriptureName: "",
     sections: [], sectionIdx: 0,
     verseText: "", verseTitle: "", vernacular: "",
  totalSections: 1, selectedIdx: 0,
      scrollTarget: "card-0",
     statusText: "上下滑动选择经文，单击进入",
      statusText: "上下滑动选择经文，单击进入"
   });
 }
};
</script>

<page>
  <view class="container" style="min-height: 270px;">
    <!-- 语音状态栏 -->
    <view class="voice-bar {{listening ? 'active' : ''}}">
      <text class="voice-icon">{{ listening ? '🎙' : '📖' }}</text>
      <text class="voice-text">{{ statusText }}</text>
    </view>

    <!-- 列表视图 -->
    <view class="list-panel" ink:if="{{!showingDetail}}" key="list-panel">
      <text class="title">📖 佛经藏经阁</text>
      <view class="scripture-grid">
      <view ink:for="{{scriptures}}" ink:key="id" class="card-wrap {{index === selectedIdx ? 'card-wrap-selected' : ''}}">
        <card data-id="{{item.id}}" bindtap="handleTap" class="scripture-card-shell">
          <view class="card">
            <text class="card-name">{{ item.name }}</text>
            <text class="card-meta">{{ item.verse_count }}品</text>
          </view>
        </card>
      </view>
      </view>
    </view>

    <!-- 阅读视图 -->
    <view class="detail-panel" ink:if="{{showingDetail}}">
     <text class="reading-title">{{ scriptureName }}</text>
      <scroll-view scroll-y="true" scroll-top="{{verseScrollTop}}" bindscroll="onVerseScroll" class="verse-box" key="{{verseKey}}">
        <text class="subtitle">{{ verseTitle }}</text>
        <text class="verse">{{ verseText }}</text>
        <text class="baihua">{{ vernacular }}</text>
      </scroll-view>
      <view class="row">
        <card bindtap="handlePrev"><view class="nav-btn"><text>上一品</text></view></card>
        <text class="pnum">{{ sectionIdx + 1 }} / {{ totalSections }}</text>
        <card bindtap="handleNext"><view class="nav-btn"><text>下一品</text></view></card>
      </view>
    </view>
  </view>
</page>

<style>
.container { display: flex; flex-direction: column; width: 407px; background-color: #000; padding: 12px; gap: 10px; }
.read-container { display: flex; flex-direction: column; width: 407px; min-height: 270px; background-color: #000; padding: 12px; gap: 10px; }
.list-panel { display: flex; flex-direction: column; gap: 8px; }
.detail-panel { display: flex; flex-direction: column; gap: 10px; }

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

.title { font-size: 16px; font-weight: 700; color: #40FF5E; }
.reading-title { font-size: 16px; font-weight: 700; color: #40FF5E; }
.card-wrap { display: flex; flex-direction: column; align-items: center; justify-content: center; width: 131px; box-sizing: border-box; padding: 8px 6px; gap: 4px; border-radius: 10px; min-height: 56px; border: 1px solid rgba(64,255,94,0.5); }
.card-wrap-selected { background-color: rgba(64,255,94,0.2); border-color: transparent; }
.scripture-card-shell { width: 100%; box-sizing: border-box; border-width: 0; background-color: transparent; }
.scripture-grid { display: grid; width: 405px; grid-template-columns: 131px 131px 131px; gap: 6px; }
.card { display: flex; flex-direction: column; align-items: center; gap: 3px; width: 100%; box-sizing: border-box; }
.card-name { width: 100%; font-size: 12px; font-weight: 700; color: #40FF5E; text-align: center; }
.card-meta { font-size: 10px; color: rgba(64,255,94,0.5); text-align: center; }
.verse-box { padding: 10px; background: rgba(64,255,94,0.06); border-radius: 10px; height: 178px; }
.subtitle { font-size: 18px; font-weight: 700; color: #40FF5E; margin-bottom: 6px; }
.verse { font-size: 18px; color: #40FF5E; line-height: 1.8; }
.baihua { font-size: 16px; color: rgba(64,255,94,0.5); line-height: 1.5; margin-top: 6px; }
.row { display: flex; flex-direction: row; justify-content: space-between; align-items: center; margin-top: 6px; }
.nav-btn { padding: 6px 12px; }
.nav-btn text { font-size: 12px; color: #40FF5E; }
.pnum { font-size: 11px; color: rgba(64,255,94,0.4); }
</style>
