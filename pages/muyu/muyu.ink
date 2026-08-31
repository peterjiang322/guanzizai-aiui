<script def>
{
  "navigationBarTitleText": "🪵 敲木鱼",
  "description": "敲木鱼积功德 — 每点一下功德+1"
}
</script>

<script setup>
import wx from 'wx';

export default {
  data: {
    count: 0,
    plusOpacity: 0,
    muyuEmoji: "📿",
    muyuSize: "250px",
    muyuSrc: "/assets/muyu1.png"
  },

  plusTimer: null,

  onLoad: function() {
    var today = new Date().toDateString();
    var lastDate = "";
    try { lastDate = wx.getStorageSync('muyu_date') || ""; } catch(e) {}
    if (lastDate !== today) {
      try { wx.setStorageSync('muyu_count', 0); } catch(e) {}
      try { wx.setStorageSync('muyu_date', today); } catch(e) {}
    }
    var saved = 0;
    try { saved = parseInt(wx.getStorageSync('muyu_count')) || 0; } catch(e) {}
    this.setData({ count: saved });
  },

  onUnload: function() {
    if (this.plusTimer) { clearTimeout(this.plusTimer); }
  },

  handleTap: function() {
    var self = this;
    var next = self.data.count + 1;
    self.setData({ count: next, plusOpacity: 1, muyuSize: "220px", muyuSrc: "/assets/muyu2.png" });
    setTimeout(function() {
      self.setData({ muyuSize: "250px", muyuSrc: "/assets/muyu1.png" });
    }, 120);

    try {
      if (typeof Sound !== "undefined") {
        var s = new Sound("../../assets/muyu_tap.wav");
        s.volume = 0.5;
        s.play();
      }
    } catch(e) {}

    try { wx.setStorageSync('muyu_count', next); } catch(e) {}
    try { wx.setStorageSync('muyu_date', new Date().toDateString()); } catch(e) {}

    if (self.plusTimer) { clearTimeout(self.plusTimer); }
    self.plusTimer = setTimeout(function() {
      self.setData({ plusOpacity: 0 });
    }, 600);
  },

  handleReset: function() {
    this.setData({ count: 0, plusOpacity: 0 });
    try { wx.setStorageSync('muyu_count', 0); } catch(e) {}
  },

  onKeyUp: function(event) {
    if (event.code === "Enter") {
      this.handleTap();
    } else if (event.code === "Backspace") {
      wx.navigateBack();
    }
  }
};
</script>

<page>
  <view class="container">
    <text class="title">🥁 敲木鱼</text>


    <text class="plus-text" style="opacity: {{plusOpacity}};">功德+1</text>

    <view class="card-left" bindtap="handleTap">
        <view class="muyu-img-wrap" style="width: {{muyuSize}};">
          <image src="{{muyuSrc}}" class="muyu-img" mode="widthFix"></image>
        </view>
    </view>

    <view class="counter-row">
      <text class="label">功德</text>
      <text class="count">{{ count }}</text>
    </view>
  </view>
</page>

<style>
.container { display: flex; flex-direction: column; align-items: center; width: 407px; min-height: 288px; background-color: #000; padding: 16px; gap: 8px; }
.title { font-size: 18px; font-weight: 700; color: #40FF5E; }
.card-left { display: flex; align-items: center; justify-content: center; padding: 12px; }
.muyu-img-wrap { position: relative; }
.muyu-img { width: 100%; display: block; }
.plus-text { font-size: 22px; font-weight: 700; color: #40FF5E; margin: 8px 0 -4px 0; }
.counter-row { display: flex; flex-direction: row; align-items: baseline; gap: 8px; }
.label { font-size: 28px; font-weight: 700; color: #40FF5E; }
.count { font-size: 28px; font-weight: 700; color: #40FF5E; }
</style>
