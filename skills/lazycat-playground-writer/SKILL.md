---
name: lazycat-playground-writer
description: Use when writing or publishing an article (攻略) to the LazyCat Playground (lazycat.cloud/playground), taking app screenshots via a shared browser, uploading screenshots into the ByteMD CodeMirror editor, masking sensitive fields like device IDs and API keys in screenshots, or asking a logged-in user to complete login/cover/category steps. Covers the paste-to-upload trick, workflow URL, publish-finished confirmation, and ServerChan sendkey channel pitfalls.
---

# 懒猫攻略平台写作与发布

为 lazycat.cloud/playground 攻略平台写一篇应用攻略：调研源码、共享浏览器截图、脱敏、图片自动上传、填表发布。整条链路只依赖共享浏览器和登录用户的少量配合。

## 工作流

1. **调研**：读应用源码（README、docs、git log、handler/scheduler 代码），梳理开发动机和功能演进顺序。动机按用户口述为准，技术细节以代码为准。
2. **截图**：共享浏览器打开应用真实地址。需要登录时，让用户在共享浏览器里登录（AskUserQuestion 确认进度，不要替用户输密码）。逐屏截图：首页、任务列表、各配置页、关键对话框。截图前先脱敏。
3. **脱敏**：截图前用 `eval` 改 DOM 文本再截图，比截图后修图可靠。已知敏感位：设备 ID（`.device-id`，保留前 4 位其余换成 `•`）、SendKey（input 改成 `SCT****`）、ntfy token、用户邮箱。
4. **上传图片**：见下「图片自动上传」，核心是本地起 HTTP 服务 + ClipboardEvent 粘贴，平台自动传 COS 并把 markdown 图片链接插回编辑器。
5. **写文章**：文章结构按信息依赖排序：开发动机 → 核心功能（每个功能先给场景再讲操作）→ 原理（深入浅出，不贴源码）→ 边界与坑。功能清单式说明书是失败模式，每个功能必须先有「为什么需要它」的场景。
6. **填表发布**：`https://lazycat.cloud/playground/workshop` 填标题和正文，封面和分类让用户手动完成（cover 有独立上传组件，eval 不可靠）。用户点发布，确认 URL 变成 `playground/publish-finished?type=图文` 即成功。

## 图片自动上传（关键技巧）

攻略平台编辑器是 ByteMD（内核 CodeMirror）。用户直接粘贴图片会自动上传到腾讯云 COS，并在光标处插入 `![](COS地址)`。浏览器自动化没有系统剪贴板，但可以在页面里合成 paste 事件：

1. 本地起 HTTP 服务供页面 fetch 图片（eval 里 `fetch('http://127.0.0.1:PORT/x.jpg')`）：

```python
import http.server, functools
class H(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header('Access-Control-Allow-Origin','*')
        self.send_header('Cache-Control','no-store')
        super().end_headers()
    def log_message(self,*a): pass
http.server.ThreadingHTTPServer(('127.0.0.1', 8791),
    functools.partial(H, directory='/tmp/shots')).serve_forever()
```

用 exec 的 runInBackground 启动（不要用 nohup &）。

2. 页面注入上传函数（截图先压缩成 jpg，单张 base64 控制在 60KB 内）：

```js
window.__cm = document.querySelector('.CodeMirror').CodeMirror;
window.__pasteOne = async (name) => {
  const r = await fetch('http://127.0.0.1:8791/' + name);
  const b = await r.blob();
  const f = new File([b], name, {type: b.type});
  const dt = new DataTransfer(); dt.items.add(f);
  const target = document.querySelector('.CodeMirror textarea');
  target.focus();
  target.dispatchEvent(new ClipboardEvent('paste',
    {clipboardData: dt, bubbles: true, cancelable: true}));
  await new Promise(res => setTimeout(res, 2600));
  return [...window.__cm.getValue().matchAll(
    /!\[([^\]]+)\]\((https:[^)\s]+)/g)].map(m => ({name: m[1], url: m[2]}));
};
```

3. 逐张粘贴：每次先 `window.__cm.setValue('')` 清空，拿到 COS URL 后清空再传下一张，收集进 `window.__urls` 映射。上传触发 `applyWrite?name=` + COS `PUT`，监听 XHR 可确认。
4. 全部传完后 setValue 完整 markdown（图片链接用收集到的 COS URL），标题直接 `input.value = ...` + dispatchEvent。

## 失败模式与回退

| 症状 | 原因 | 处理 |
|---|---|---|
| navigate 后 eval 仍返回旧页面 URL | 浏览器层导航与页面执行不同步，常见于从应用站跳回平台 | 改用 `reload`；确认 `Page.getNavigationHistory`；仍失败让用户关掉标签页再 navigate 重建 |
| 截图报 "A previous Browser capture is still pending" | 上一次截图超时挂起 | `wait ms 2000~5000` 后重试，不要连续快速截图 |
| 粘贴后编辑器为空 | 平台编辑器 paste 监听在 CodeMirror 的事件链上，事件没触发 | 确认 `target.focus()` 在 dispatch 前；确认 dispatch 返回值；仍失败改用截图里可见的拖拽上传入口让用户手动传 |
| OCR / image.read 不可用 | 本机 modality provider 未配置 | 靠 snapshot + eval 读 DOM 文本，这是常态，不要反复重试 OCR |
| 全页截图 fullPage 报不支持 | 桌面 webview 限制 | 用 scroll + 多次 viewport 截图拼接 |
| eval 中中文被截断或转义出错 | 长文本直接写进 eval 表达式 | 把 markdown 存本地文件放 HTTP 目录，eval fetch 回来再 setValue |

## 不要做

- 不要把 SendKey、token、完整设备 ID 写进文章或截图
- 不要替用户输入任何密码或验证码；登录只让用户在共享浏览器完成
- 不要在文章里贴源码；原理用自然语言讲（比如 RTC 闹钟写后回读比对再关机）
- 不要在登录页面上传截图：先确认已进入应用主界面
- 不要用绝对时间「今天/刚刚」描述应用行为，写清楚功能语义

## 已知平台事实

- workshop 编辑器：ByteMD，markdown 正文上限 50000 字符，标题 50 字
- 发布成功标志：URL `playground/publish-finished?type=图文`，显示「攻略发布成功，等待管理员审核」
- 图片上传后落到 `lzc-playground-1301583638.cos.ap-chengdu.myqcloud.com/guidelines/<uid>/`
- 分类下拉项：影音娱乐、AI 算力舱、数字办公、学习阅读、便捷生活、创意设计、网络应用、玩机攻略、开发工具
- Server酱 SendKey 双渠道坑：`sc3.ft07.com/sendkey` 走 Server酱 App 推送，`sct.ftqq.com/sendkey` 走微信推送，填错不报错只是收不到
