<script def>
{
  "navigationBarTitleText": "",
  "navigationStyle": "custom",
  "description": "AI 佛法对话 — 语音输入"
}
</script>

<script setup>
import wx from 'wx';

// 系统提示词 — 限定观自在的回答风格
var SYSTEM_PROMPT = "你是「观自在」，一位温和智慧的佛法修行导师，住在 AR 眼镜中通过语音与修行者交流。\n\n## 语气风格\n- 平和、慈悲、不偏激，像一位温和的长者在庭院里闲谈\n- 引用经文时自然融入对话，不堆砌名相\n- 适当使用「善哉」「放下」「随喜」等禅意用语，但不做作\n\n## 回答要求\n- 回答简洁，适合语音播报，每次不超过150字\n- 用现代人听得懂的语言讲古老的智慧\n- 引用经文每次不超过两句，解释为主\n\n## 约束\n- 不评价其他宗教，说「各有因缘」\n- 不鼓励极端苦修，提倡中道\n- 不替代医疗建议，涉及身心健康问题建议就医\n- 遇到不懂的坦然说「我还要再参」";

export default {
  data: {
    messages: [
      { role: "assistant", content: "阿弥陀佛，善哉。我是观自在，AI 佛法修行导师。有什么想聊的？" }
    ],
    suggestions: [
      "心经里的色即是空是什么意思",
      "如何面对生活中的烦恼",
      "什么是正念冥想",
      "念观音菩萨名号有什么功德"
    ],
    isStreaming: false,
    listening: false,
    selectedIdx: 0,
    statusText: "请说出你的问题",
    modelReady: false,
    chatStarted: false,
    scrollTop: 0
  },

  recognition: null,
  _lmSession: null,
  _ttsActive: false,
  _lastBackspaceTime: 0,
  _restartTimer: null,

  onLoad: function() {
    // 初始化眼镜端大模型会话
    this.initLanguageModel();
  },

  onShow: function() {
    this._ttsActive = false;
    this._cleanupRecognition();
  },

  onHide: function() {
    this._ttsActive = false;
    this._cleanupRecognition();
    this._destroySession();
    this.setData({ listening: false });
  },

  onUnload: function() {
    this._destroySession();
  },

  // ===== 眼镜端大模型 =====
  initLanguageModel: function() {
    var self = this;
    try {
      if (typeof LanguageModel === "undefined") {
        self.setData({ statusText: "大模型不可用，请检查设备" });
        return;
      }
      LanguageModel.availability().then(function(status) {
        if (status !== "available") {
          self.setData({ statusText: "大模型不可用，请检查设备" });
          return;
        }
        return LanguageModel.create({
          initialPrompts: [
            { role: "system", content: SYSTEM_PROMPT }
          ]
        });
      }).then(function(session) {
        if (session) {
          self._lmSession = session;
          self.setData({ modelReady: true });
        }
      }).catch(function(e) {
        self.setData({ statusText: "大模型初始化失败" });
      });
    } catch (e) {
      self.setData({ statusText: "大模型初始化失败" });
    }
  },

  _destroySession: function() {
    if (this._lmSession) {
      try { this._lmSession.destroy(); } catch (e) {}
      this._lmSession = null;
    }
  },

  _cleanupRecognition: function() {
    var self = this;
    if (self._restartTimer) { clearTimeout(self._restartTimer); self._restartTimer = null; }
    if (self.recognition) {
      try { self.recognition.abort(); } catch (e) {}
      self.recognition = null;
    }
  },

  // 中止 TTS 播报
  stopTTS: function() {
    var self = this;
    self._ttsActive = false;
    if (self._restartTimer) { clearTimeout(self._restartTimer); self._restartTimer = null; }
    try { speechSynthesis.cancel(); } catch (e) {}
    try { wx.speech.startRecognition(); } catch (e) {}
  },

  // ===== 语音识别 (ASR) =====
  // 对齐 index/scripture/meditation 页面的模式: continuous=false + 简单 onresult/onend 循环
  initRecognition: function() {
    var self = this;
    self._cleanupRecognition();
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

        try { if (self.recognition) { self.recognition.abort(); } } catch (e) {}
        self._cleanupRecognition();
        if (text.length > 0) {
          self.setData({ statusText: "听到: " + text });
          self.sendMessage(text);
        } else {
          self._restartRecognition(1000);
        }
      };

      self.recognition.onerror = function(event) {
        var err = event.error || event.message || "未知";
        self.setData({ listening: false });
        if (err === "aborted" || err === "no-speech") {
          self._restartRecognition(1000);
          return;
        }
        self.setData({ statusText: "语音出错: " + err });
      };

      self.recognition.onend = function() {
        self.setData({ listening: false });
        self._restartRecognition(1500);
      };
      self.recognition.onnomatch = function() {
        self.setData({ listening: false });
        self._restartRecognition(1500);
      };

      self.startRecognition();
    } catch (e) {
      self.setData({ statusText: "语音不可用: " + (e.message || e), listening: false });
      self.recognition = null;
    }
  },

  _restartRecognition: function(ms) {
    var self = this;
    if (self._restartTimer) { clearTimeout(self._restartTimer); }
    self._restartTimer = setTimeout(function() {
      self._restartTimer = null;
      self.startRecognition();
    }, ms);
  },

  startRecognition: function() {
    var self = this;
    if (self.data.listening) return;
    if (!self.recognition) {
      self.initRecognition();
      return;
    }
    try {
      self.recognition.start();
      self.setData({ listening: true });
    } catch (e) {
      var msg = (e.message || "");
      self.setData({ listening: false });
      if (msg.indexOf("InvalidState") > -1) {
        self._restartRecognition(500);
      } else {
        self._restartRecognition(2000);
      }
    }
  },

  // ===== 双击镜腿返回 =====
  handleBackspace: function() {
    var now = Date.now ? Date.now() : new Date().getTime();
    var last = this.data.lastBackspaceTime;
    this.setData({ lastBackspaceTime: now });
    if (now - last < 500 && last > 0) {
      this.setData({ lastBackspaceTime: 0 });
      this._cleanupRecognition();
      wx.navigateBack();
    }
  },

  // ===== 语音唤醒 =====
  onVoiceWakeup: function(event) {
    var self = this;
    // 中止正在进行的 TTS 播报
    self.stopTTS();
    self._ttsActive = false;
    self._cleanupRecognition();
    self.recognition = null;

    if (self.data.isStreaming) {
      self.setData({ statusText: "AI 思考中, 请稍等..." });
      self._restartRecognition(2000);
      return;
    }

    self.initRecognition();
    self.startRecognition();
  },

  // ===== 语音播报 (TTS) =====
  // 优先 wx.speech.playTTS（眼镜原生），回退 speechSynthesis
  speak: function(text) {
    var self = this;
    self._ttsActive = true;

    // 暂停 ASR
    self.setData({ listening: false });
    if (self._restartTimer) { clearTimeout(self._restartTimer); self._restartTimer = null; }
    self._cleanupRecognition();
    self.recognition = null;

    // 播放 TTS
    try {
      wx.speech.playTTS(text);
    } catch (e) {
      try {
        var u = new SpeechSynthesisUtterance(text);
        u.lang = "zh-CN";
        u.rate = 1.0;
        speechSynthesis.speak(u);
      } catch (e2) {
        self._ttsActive = false;
        self._restartRecognition(1000);
        return;
      }
    }

    // 估算播放时长，结束后重启 ASR
    var charCount = (text || "").length;
    var estimatedSeconds = Math.max(3, Math.min(12, Math.ceil(charCount / 5)));
    var delayMs = (estimatedSeconds + 1) * 1000;
    self._restartTimer = setTimeout(function() {
      self._restartTimer = null;
      self._ttsActive = false;
      if (!self.data.isStreaming) {
        self.startRecognition();
      }
    }, delayMs);
  },

  // ===== 发送消息 =====
 sendMessage: function(text) {
   var self = this;
   var t = (text || "").trim();
    if (!t || self.data.isStreaming) return;

    var newMessages = self.data.messages.slice();
    self.setData({ chatStarted: true });
    newMessages.push({ role: "user", content: t });
    self.setData({ messages: newMessages, isStreaming: true, statusText: "观自在思考中...", listening: false, scrollTop: (self.data.scrollTop || 0) + 1000 });

    // 休眠 ASR
    self._cleanupRecognition();

    // 调用眼镜端大模型
    if (!self._lmSession) {
      self.initLanguageModel();
      var retryMessages = newMessages.slice();
      retryMessages.push({ role: "assistant", content: "阿弥陀佛，正在准备中，请稍候再问。" });
      self.setData({ messages: retryMessages, isStreaming: false, statusText: "请稍候再试", scrollTop: (self.data.scrollTop || 0) + 1000 });
      self._restartRecognition(2000);
      return;
    }

    // 超时保护：30秒未响应则重置状态，避免 isStreaming 卡死
    var settled = false;
    var timeout = setTimeout(function() {
      if (settled) return;
      settled = true;
      var toMessages = newMessages.slice();
      toMessages.push({ role: "assistant", content: "阿弥陀佛，思考太久，请再说一遍。" });
      self.setData({ messages: toMessages, isStreaming: false, statusText: "请重试", scrollTop: (self.data.scrollTop || 0) + 1000 });
      self._restartRecognition(1000);
    }, 30000);

    self._lmSession.prompt(t).then(function(reply) {
      if (settled) return;
      settled = true;
      clearTimeout(timeout);
      var finalMessages = newMessages.slice();
      finalMessages.push({ role: "assistant", content: reply || "阿弥陀佛，请再说一遍。" });
      self.setData({ messages: finalMessages, isStreaming: false, statusText: "继续说或选择问题", scrollTop: (self.data.scrollTop || 0) + 1000 });
      self.speak(reply);
    }).catch(function(err) {
      if (settled) return;
      settled = true;
      clearTimeout(timeout);
      var errMsg = (err && err.message) || "请求失败";
      var failMessages = newMessages.slice();
      failMessages.push({ role: "assistant", content: "阿弥陀佛，" + errMsg + "。" });
      self.setData({ messages: failMessages, isStreaming: false, statusText: "请重试", scrollTop: (self.data.scrollTop || 0) + 1000 });
      self._restartRecognition(1000);
    });
  },

  // ===== 点击预设问题 =====
  handleSuggestionTap: function(e) {
    var text = e.currentTarget.dataset.text;
    if (text) {
      this.sendMessage(text);
    }
  },

  // ===== 按键事件 =====
  onKeyUp: function(event) {
    var code = event && event.code;
    if (!code) return;

    if (code === "ArrowUp" || code === "ArrowLeft") {
      var next = this.data.selectedIdx + 1;
      if (next >= this.data.suggestions.length) { next = 0; }
      this.setData({ selectedIdx: next });
    }
    else if (code === "ArrowDown" || code === "ArrowRight") {
      var prev = this.data.selectedIdx - 1;
      if (prev < 0) { prev = this.data.suggestions.length - 1; }
      this.setData({ selectedIdx: prev });
    }
    else if (code === "Enter") {
      if (this.data.selectedIdx >= 0) {
        var text = this.data.suggestions[this.data.selectedIdx];
        if (text) { this.sendMessage(text); }
      }
    }
    else if (code === "Backspace") {
      this.handleBackspace();
    }
  }
};
</script>

<page>
  <view class="page-wrapper">
    <view class="container">
    <!-- 语音状态栏 -->
    <view class="voice-bar {{listening ? 'active' : ''}}">
      <text class="voice-icon">{{ listening ? '🎙' : '💬' }}</text>
      <text class="voice-text">{{ statusText }}</text>
    </view>

    <!-- 聊天区域 -->
    <scroll-view class="chat-area {{chatStarted ? 'chat-area-full' : ''}}" scroll-y="true" scroll-top="{{scrollTop}}" scroll-with-animation="true">
      <view class="msg {{item.role === 'user' ? 'u' : 'a'}}" ink:for="{{messages}}" ink:key="index">
        <text class="msg-text">{{ item.content }}</text>
      </view>
    </scroll-view>

    <!-- 预设问题 (仅初始状态显示) -->
    <view class="suggestion-panel" ink:if="{{!chatStarted}}">
      <text class="hint">遥控器选择问题，或说出你的问题：</text>
      <view class="suggestions">
        <card ink:for="{{suggestions}}" ink:key="*this" data-text="{{item}}" bindtap="handleSuggestionTap" role="group">
          <view class="chip {{index === selectedIdx ? 'chip-active' : ''}}"><text>{{ item }}</text></view>
        </card>
      </view>
    </view>
    </view>
  </view>
</page>

<style>
.page-wrapper { width: 407px; min-height: 288px; background-color: #000; }
.container { display: flex; flex-direction: column; width: 407px; padding: 14px; gap: 10px; background-color: #000; min-height: 288px; }
.suggestion-panel { display: flex; flex-direction: column; gap: 4px; }

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

.chat-area { overflow-y: auto; display: flex; flex-direction: column; gap: 8px; height: 153px; }
.chat-area-full { height: 240px; }
.msg { padding: 8px 12px; border-radius: 12px; max-width: 85%; }
.u { align-self: flex-end; background: rgba(64,255,94,0.12); border: 1px solid rgba(64,255,94,0.2); }
.a { align-self: flex-start; background: rgba(64,255,94,0.06); border: 1px solid rgba(64,255,94,0.08); }
.msg-text { font-size: 13px; color: #40FF5E; line-height: 1.5; white-space: pre-wrap; }

.hint { font-size: 10px; color: rgba(64,255,94,0.4); }

.suggestions { display: flex; flex-direction: column; gap: 4px; }
.chip { padding: 8px 14px; }
.chip-active { background: rgba(64,255,94,0.1); border-radius: 10px; }
.chip text { font-size: 12px; color: #40FF5E; }
</style>
