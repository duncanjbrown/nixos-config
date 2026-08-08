(() => {
  if (window.__opencodeWidget) return;
  window.__opencodeWidget = true;

  const API = "/opencode";
  const dir = location.pathname.replace(/[^/]*$/, "") || "/";
  const sessionKey = "opencode-widget.session." + dir;
  const contextKey = "opencode-widget.context.";
  const openKey = "opencode-widget.open";

  let sessionID = null;
  let es = null;
  let busy = false;
  let edited = false;
  let opened = false;
  const partEls = new Map();
  const msgEls = new Map();

  const css = document.createElement("style");
  css.textContent = `
.ocw-bubble{position:fixed;right:16px;bottom:16px;z-index:2147483646;width:44px;height:44px;border-radius:50%;border:1px solid #3c3c42;background:#1e1e22;color:#e8e8ea;cursor:pointer;display:flex;align-items:center;justify-content:center;box-shadow:0 2px 10px rgba(0,0,0,.35)}
.ocw-bubble:hover{background:#2a2a30}
.ocw-panel{position:fixed;right:16px;bottom:70px;z-index:2147483647;width:400px;max-width:calc(100vw - 32px);height:560px;max-height:calc(100vh - 100px);display:flex;flex-direction:column;background:#17171a;color:#e6e6e9;border:1px solid #34343a;border-radius:10px;box-shadow:0 8px 30px rgba(0,0,0,.5);font:13px/1.45 system-ui,-apple-system,sans-serif;text-align:left}
.ocw-head{display:flex;align-items:center;gap:8px;padding:10px 12px;border-bottom:1px solid #2c2c31}
.ocw-title{font-weight:600;flex:1;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
.ocw-dot{width:8px;height:8px;border-radius:50%;background:#888;flex:none;display:inline-block}
.ocw-dot.ok{background:#3fb950}
.ocw-dot.busy{background:#f0883e}
.ocw-dot.err{background:#f85149}
.ocw-close{background:none;border:none;color:#999;cursor:pointer;font-size:16px;padding:2px 6px}
.ocw-msgs{flex:1;overflow-y:auto;padding:12px;display:flex;flex-direction:column;gap:10px}
.ocw-msg{max-width:92%;padding:8px 10px;border-radius:8px;white-space:pre-wrap;overflow-wrap:break-word}
.ocw-user{align-self:flex-end;background:#264f78;color:#fff}
.ocw-assistant{align-self:flex-start;background:#232327;border:1px solid #303036;width:92%;display:flex;flex-direction:column;gap:6px}
.ocw-text{white-space:pre-wrap;overflow-wrap:break-word}
.ocw-sys{align-self:center;color:#999;font-size:12px}
.ocw-tool{display:flex;gap:6px;align-items:baseline;color:#a0a0a8;font-size:12px}
.ocw-tool .ocw-dot{width:6px;height:6px}
.ocw-perm{border:1px solid #f0883e;border-radius:8px;padding:8px 10px;background:#2a2118;display:flex;flex-direction:column;gap:8px;width:92%;align-self:flex-start}
.ocw-perm-desc{font-size:12px;overflow-wrap:anywhere}
.ocw-perm-btns{display:flex;gap:6px}
.ocw-perm-btns button{flex:1;padding:4px 6px;border-radius:6px;border:1px solid #444;background:#2d2d33;color:#e6e6e9;cursor:pointer;font-size:12px}
.ocw-perm-btns button:hover{background:#3a3a42}
.ocw-perm.ocw-resolved{opacity:.6}
.ocw-toast{display:flex;gap:8px;align-items:center;padding:8px 12px;border-top:1px solid #2c2c31;background:#1d2a1d;font-size:12px}
.ocw-toast span{flex:1}
.ocw-toast button{padding:3px 10px;border-radius:6px;border:1px solid #444;background:#2d2d33;color:#e6e6e9;cursor:pointer;font-size:12px}
.ocw-input{display:flex;gap:8px;padding:10px 12px;border-top:1px solid #2c2c31}
.ocw-input textarea{flex:1;resize:none;height:40px;max-height:120px;background:#232327;color:#e6e6e9;border:1px solid #34343a;border-radius:8px;padding:8px;font:inherit}
.ocw-input button{padding:0 14px;border-radius:8px;border:none;background:#f5a623;color:#161616;font-weight:600;cursor:pointer}
.ocw-input button:disabled{opacity:.5;cursor:default}
.ocw-panel[hidden],.ocw-toast[hidden]{display:none}
`;

  function make(tag, cls, text) {
    const n = document.createElement(tag);
    if (cls) n.className = cls;
    if (text != null) n.textContent = text;
    return n;
  }

  const root = document.body || document.documentElement;
  root.appendChild(css);

  const bubble = make("button", "ocw-bubble");
  bubble.title = "Chat with opencode";
  bubble.innerHTML = '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 11.5a8.38 8.38 0 0 1-.9 3.8 8.5 8.5 0 0 1-7.6 4.7 8.38 8.38 0 0 1-3.8-.9L3 21l1.9-5.7a8.38 8.38 0 0 1-.9-3.8 8.5 8.5 0 0 1 4.7-7.6 8.38 8.38 0 0 1 3.8-.9h.5a8.48 8.48 0 0 1 8 8v.5z"/></svg>';

  const panel = make("div", "ocw-panel");
  panel.hidden = true;
  const dot = make("span", "ocw-dot");
  const title = make("div", "ocw-title", "opencode · " + dir);
  const closeBtn = make("button", "ocw-close", "×");
  const head = make("div", "ocw-head");
  head.append(dot, title, closeBtn);
  const msgs = make("div", "ocw-msgs");
  const toast = make("div", "ocw-toast");
  toast.hidden = true;
  toast.append(
    make("span", null, "Files changed on disk."),
    (() => {
      const b = make("button", null, "Reload");
      b.onclick = () => location.reload();
      return b;
    })(),
    (() => {
      const b = make("button", null, "Dismiss");
      b.onclick = () => { toast.hidden = true; };
      return b;
    })(),
  );
  const ta = make("textarea");
  ta.placeholder = "Ask opencode about this page…";
  const sendBtn = make("button", null, "Send");
  const inputRow = make("div", "ocw-input");
  inputRow.append(ta, sendBtn);
  panel.append(head, msgs, toast, inputRow);
  root.append(bubble, panel);

  function setStatus(state) {
    dot.className = "ocw-dot" + (state ? " " + state : "");
  }

  function scroll() {
    msgs.scrollTop = msgs.scrollHeight;
  }

  function sysMsg(text) {
    msgs.appendChild(make("div", "ocw-sys", text));
    scroll();
  }

  function updateInput() {
    sendBtn.disabled = busy || !sessionID;
  }

  function assistantMsg(messageID) {
    let m = msgEls.get(messageID);
    if (!m) {
      m = make("div", "ocw-msg ocw-assistant");
      msgs.appendChild(m);
      msgEls.set(messageID, m);
    }
    return m;
  }

  function renderPart(part) {
    if (!part) return;
    if (part.type === "text") {
      let rec = partEls.get(part.id);
      if (!rec) {
        const el = make("div", "ocw-text");
        assistantMsg(part.messageID).appendChild(el);
        rec = { el, kind: "text" };
        partEls.set(part.id, rec);
      }
      rec.el.textContent = part.text;
    } else if (part.type === "tool") {
      let rec = partEls.get(part.id);
      if (!rec) {
        const el = make("div", "ocw-tool");
        el.append(make("span", "ocw-dot"), make("span"));
        assistantMsg(part.messageID).appendChild(el);
        rec = { el, kind: "tool" };
        partEls.set(part.id, rec);
      }
      const st = part.state || {};
      const label = part.tool + (st.title ? ": " + st.title : "") + (st.status === "error" ? " (failed)" : "");
      rec.el.lastChild.textContent = label;
      rec.el.firstChild.className = "ocw-dot " +
        (st.status === "completed" ? "ok" : st.status === "error" ? "err" : "busy");
      if (st.status === "completed" && ["edit", "write", "patch"].includes(part.tool)) edited = true;
    }
    scroll();
  }

  function onDelta(p) {
    if (p.sessionID !== sessionID) return;
    const rec = partEls.get(p.partID);
    if (rec && rec.kind === "text" && p.field === "text") {
      rec.el.textContent += p.delta;
      scroll();
    }
  }

  function onMsgUpdated(p) {
    if (p.sessionID !== sessionID) return;
    const info = p.info || {};
    if (info.role === "assistant" && info.time && info.time.completed) {
      busy = false;
      setStatus("ok");
      updateInput();
      if (edited) toast.hidden = false;
    }
  }

  function onPermission(type, p) {
    if (p.sessionID !== sessionID) return;
    const card = make("div", "ocw-perm");
    const items = type === "permission.v2.asked" ? p.resources : p.patterns;
    const name = type === "permission.v2.asked" ? p.action : p.permission;
    card.appendChild(make("div", "ocw-perm-desc",
      "Permission: " + name + (items && items.length ? " — " + items.join(", ") : "")));
    const btns = make("div", "ocw-perm-btns");
    const mkBtn = (label, response) => {
      const b = make("button", null, label);
      b.onclick = async () => {
        try {
          const r = await fetch(API + "/session/" + sessionID + "/permissions/" + p.id, {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ response }),
          });
          if (!r.ok) throw new Error(await r.text());
          card.classList.add("ocw-resolved");
          btns.remove();
        } catch (e) {
          sysMsg("permission reply failed: " + e.message);
        }
      };
      return b;
    };
    btns.append(mkBtn("Allow once", "once"), mkBtn("Always allow", "always"), mkBtn("Reject", "reject"));
    card.appendChild(btns);
    msgs.appendChild(card);
    scroll();
  }

  function connect() {
    if (es) return;
    es = new EventSource(API + "/event");
    es.onmessage = (e) => {
      let evt;
      try { evt = JSON.parse(e.data); } catch { return; }
      const p = evt.properties || {};
      if (evt.type === "message.part.updated" && p.sessionID === sessionID) renderPart(p.part);
      else if (evt.type === "message.part.delta") onDelta(p);
      else if (evt.type === "message.updated") onMsgUpdated(p);
      else if (evt.type === "permission.asked" || evt.type === "permission.v2.asked") onPermission(evt.type, p);
    };
    es.onopen = () => setStatus(busy ? "busy" : "ok");
    es.onerror = () => setStatus("err");
  }

  async function ensureSession() {
    let id = localStorage.getItem(sessionKey);
    if (id) {
      try {
        const r = await fetch(API + "/session/" + id);
        if (r.ok) return id;
      } catch { /* fall through */ }
      localStorage.removeItem(sessionKey);
    }
    const r = await fetch(API + "/session", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        title: "widget: " + dir,
        permission: [
          { permission: "edit", pattern: "~/projects/*", action: "allow" },
          { permission: "edit", pattern: "/home/duncanbrown/projects/*", action: "allow" },
          { permission: "bash", pattern: "*", action: "ask" },
        ],
      }),
    });
    if (!r.ok) throw new Error(await r.text());
    const s = await r.json();
    id = s.id || (s.session && s.session.id);
    localStorage.setItem(sessionKey, id);
    return id;
  }

  async function send() {
    const text = ta.value.trim();
    if (!text || busy || !sessionID) return;
    ta.value = "";
    busy = true;
    edited = false;
    toast.hidden = true;
    setStatus("busy");
    updateInput();
    msgs.appendChild(make("div", "ocw-msg ocw-user", text));
    scroll();
    let prompt = text;
    if (!localStorage.getItem(contextKey + sessionID)) {
      prompt = "I'm viewing " + location.href + " in my browser. The files for this page live under ~/projects" +
        dir + " (nginx serves ~/projects as the web root, and you can edit those files directly).\n\n" + text;
      localStorage.setItem(contextKey + sessionID, "1");
    }
    try {
      const r = await fetch(API + "/session/" + sessionID + "/prompt_async", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ parts: [{ type: "text", text: prompt }] }),
      });
      if (!r.ok) throw new Error(await r.text());
    } catch (e) {
      busy = false;
      setStatus("err");
      updateInput();
      sysMsg("send failed: " + e.message);
    }
  }

  async function loadHistory() {
    const r = await fetch(API + "/session/" + sessionID + "/message");
    if (!r.ok) return;
    const list = await r.json();
    for (const m of list) {
      const role = m.info && m.info.role;
      if (role === "user") {
        const text = (m.parts || []).filter(p => p.type === "text").map(p => p.text).join("\n");
        if (text.trim()) msgs.appendChild(make("div", "ocw-msg ocw-user", text));
      } else if (role === "assistant") {
        for (const p of m.parts || []) renderPart(p);
      }
    }
    const last = list[list.length - 1];
    if (last && last.info && last.info.role === "assistant" && !(last.info.time && last.info.time.completed)) busy = true;
    scroll();
  }

  async function open(focus) {
    panel.hidden = false;
    localStorage.setItem(openKey, "1");
    if (focus) ta.focus();
    if (opened) return;
    opened = true;
    try {
      sessionID = await ensureSession();
      await loadHistory();
      connect();
      setStatus(busy ? "busy" : "ok");
      updateInput();
    } catch (e) {
      setStatus("err");
      sysMsg("failed to start session: " + e.message);
    }
  }

  function close() {
    panel.hidden = true;
    localStorage.setItem(openKey, "");
  }

  bubble.onclick = () => { panel.hidden ? open(true) : close(); };
  closeBtn.onclick = close;
  sendBtn.onclick = send;
  for (const type of ["keydown", "keyup", "keypress"]) {
    panel.addEventListener(type, (e) => e.stopPropagation());
  }
  ta.addEventListener("keydown", (e) => {
    if (e.key === "Enter" && !e.shiftKey) {
      e.preventDefault();
      send();
    }
  });
  updateInput();
  if (localStorage.getItem(openKey) === "1") open();
})();
