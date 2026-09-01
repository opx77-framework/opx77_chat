/* opx77_chat -- the page.
 *
 * It owns the input, the history and the completion list; Lua owns the transport. The only
 * outbound verbs are `chat:ready`, `chat:submit`, `chat:close` and a diagnostic channel.
 */
(function () {
  "use strict";

  // CEF console output does not reach the client log, and the WebUI bridge swallows every
  // exception thrown inside an `Open77.on` handler.
  var reportCount = 0;
  var reporting = false;

  function describe(value) {
    try {
      if (value instanceof Error) return (value.name || "Error") + ": " + value.message;
      if (value === null || value === undefined) return String(value);
      if (typeof value === "object") return Object.prototype.toString.call(value);
      return String(value);
    } catch (ignored) { return "<undescribable>"; }
  }

  function report(text) {
    if (reporting || reportCount >= 20) return;
    reporting = true;
    reportCount += 1;
    try {
      window.Open77.emit("chat:diag", { text: String(text).slice(0, 400) });
    } catch (ignored) { /* nowhere left to complain to */ }
    reporting = false;
  }

  window.addEventListener("error", function (event) {
    report("uncaught " + (event.message || "?") + " at line " + (event.lineno || 0));
  });

  // An empty Lua table arrives as `{}`, not `[]`, and `value || []` would keep it.
  function list(value) { return Array.isArray(value) ? value : []; }
  function text(value) { return value === null || value === undefined ? "" : String(value); }

  var elements = {
    chat: document.getElementById("chat"),
    log: document.getElementById("log"),
    suggestions: document.getElementById("suggestions"),
    entry: document.getElementById("entry"),
    input: document.getElementById("input")
  };

  var settings = { history: 60, fadeMs: 12000, maxLength: 240 };
  var fadeTimer = null;

  /* --------------------------------------------------------------- history */

  var sent = [];      // what the player typed, newest last
  var sentAt = -1;    // where Up/Down currently is in it

  function applyConfig(payload) {
    payload = payload || {};
    elements.chat.className = "chat " +
      (text(payload.anchor) === "top-left" ? "anchor-top-left" : "");
    var width = Number(payload.width);
    if (isFinite(width) && width > 0) {
      elements.chat.style.setProperty("--chat-width", Math.round(width) + "px");
    }
    var history = Number(payload.history);
    if (isFinite(history) && history > 0) settings.history = Math.round(history);
    var fade = Number(payload.fadeMs);
    if (isFinite(fade) && fade >= 0) settings.fadeMs = Math.round(fade);
    var maxLength = Number(payload.maxLength);
    if (isFinite(maxLength) && maxLength > 0) {
      settings.maxLength = Math.round(maxLength);
      elements.input.setAttribute("maxlength", String(settings.maxLength));
    }
  }

  /* ---------------------------------------------------------------- lines */

  function colour(value) {
    if (!Array.isArray(value) || value.length < 3) return null;
    var parts = [];
    for (var i = 0; i < 3; i += 1) {
      var channel = Number(value[i]);
      if (!isFinite(channel)) return null;
      parts.push(Math.max(0, Math.min(255, Math.round(channel))));
    }
    return "rgb(" + parts.join(",") + ")";
  }

  function addMessage(payload) {
    payload = payload || {};
    var line = document.createElement("li");
    line.className = "line " + (text(payload.type) || "chat");

    var author = text(payload.author);
    if (author !== "") {
      var tag = document.createElement("span");
      tag.className = "author";
      // textContent, never innerHTML: an author is a display name a player chose
      tag.textContent = author;
      var tint = colour(payload.color);
      if (tint !== null) tag.style.color = tint;
      line.appendChild(tag);
    }

    var body = document.createElement("span");
    body.textContent = text(payload.text);
    line.appendChild(body);

    if (!document.body.classList.contains("open")) line.classList.add("faded");
    elements.log.appendChild(line);

    while (elements.log.children.length > settings.history) {
      elements.log.removeChild(elements.log.firstChild);
    }
    show();
  }

  /* Every line visible for FADE_MS, then hidden again while the box is closed. The log is
     history, not furniture. */
  function show() {
    var lines = elements.log.children;
    for (var i = 0; i < lines.length; i += 1) lines[i].classList.remove("faded");
    if (fadeTimer !== null) { window.clearTimeout(fadeTimer); fadeTimer = null; }
    if (settings.fadeMs <= 0) return;
    fadeTimer = window.setTimeout(function () {
      if (document.body.classList.contains("open")) return;
      var current = elements.log.children;
      for (var j = 0; j < current.length; j += 1) current[j].classList.add("faded");
    }, settings.fadeMs);
  }

  /* ---------------------------------------------------------- suggestions */

  var suggestions = {};   // "/name" -> { command, help, parameters }
  var matches = [];
  var picked = 0;

  function addSuggestion(entry) {
    if (!entry || typeof entry !== "object") return;
    var name = text(entry.command);
    if (name === "") return;
    if (name.charAt(0) !== "/") name = "/" + name;
    suggestions[name] = {
      command: name,
      help: text(entry.help),
      parameters: list(entry.parameters)
    };
  }

  function renderSuggestions() {
    var typed = elements.input.value;
    matches = [];
    picked = 0;

    if (typed.charAt(0) === "/" && typed.indexOf(" ") === -1) {
      var needle = typed.toLowerCase();
      var names = Object.keys(suggestions).sort();
      for (var i = 0; i < names.length && matches.length < 8; i += 1) {
        if (names[i].toLowerCase().indexOf(needle) === 0) matches.push(suggestions[names[i]]);
      }
    }

    while (elements.suggestions.firstChild) {
      elements.suggestions.removeChild(elements.suggestions.firstChild);
    }
    elements.suggestions.hidden = matches.length === 0;

    for (var j = 0; j < matches.length; j += 1) {
      var row = document.createElement("li");
      row.className = "suggestion" + (j === picked ? " on" : "");
      var name = document.createElement("span");
      name.className = "name";
      name.textContent = matches[j].command;
      row.appendChild(name);

      var hint = matches[j].help;
      var parameters = matches[j].parameters;
      for (var k = 0; k < parameters.length; k += 1) {
        var parameter = parameters[k] || {};
        hint = hint + " [" + text(parameter.name) + "]";
      }
      if (hint !== "") {
        var help = document.createElement("span");
        help.className = "help";
        help.textContent = hint;
        row.appendChild(help);
      }
      elements.suggestions.appendChild(row);
    }
  }

  function movePick(delta) {
    if (matches.length === 0) return false;
    picked = (picked + delta + matches.length) % matches.length;
    var rows = elements.suggestions.children;
    for (var i = 0; i < rows.length; i += 1) {
      rows[i].className = "suggestion" + (i === picked ? " on" : "");
    }
    return true;
  }

  /* ---------------------------------------------------------------- input */

  function open() {
    document.body.classList.add("open");
    elements.entry.hidden = false;
    elements.input.value = "";
    sentAt = -1;
    renderSuggestions();
    show();
    // after the element exists and is visible, or the focus lands nowhere
    window.setTimeout(function () { try { elements.input.focus(); } catch (ignored) {} }, 0);
  }

  function close() {
    document.body.classList.remove("open");
    elements.entry.hidden = true;
    elements.suggestions.hidden = true;
    elements.input.value = "";
    try { elements.input.blur(); } catch (ignored) {}
    show();
  }

  elements.input.addEventListener("input", function () {
    try { renderSuggestions(); } catch (error) { report("suggest: " + describe(error)); }
  });

  elements.input.addEventListener("keydown", function (event) {
    try {
      if (event.key === "Escape") {
        event.preventDefault();
        close();
        window.Open77.emit("chat:close", {});
        return;
      }
      if (event.key === "Enter") {
        event.preventDefault();
        var value = elements.input.value;
        if (value !== "") {
          sent.push(value);
          if (sent.length > 40) sent.shift();
        }
        close();
        window.Open77.emit("chat:submit", { text: value });
        return;
      }
      if (event.key === "Tab") {
        event.preventDefault();
        if (matches.length > 0) {
          elements.input.value = matches[picked].command + " ";
          renderSuggestions();
        }
        return;
      }
      if (event.key === "ArrowUp" || event.key === "ArrowDown") {
        var delta = event.key === "ArrowUp" ? -1 : 1;
        // the suggestion list wins while it is up; history otherwise
        if (movePick(delta)) { event.preventDefault(); return; }
        if (sent.length === 0) return;
        event.preventDefault();
        if (sentAt === -1) sentAt = sent.length;
        sentAt = Math.max(0, Math.min(sent.length, sentAt + delta));
        elements.input.value = sentAt >= sent.length ? "" : sent[sentAt];
        renderSuggestions();
      }
    } catch (error) { report("key: " + describe(error)); }
  });

  /* ----------------------------------------------------------- from Lua */

  Open77.on("chat:config", function (payload) {
    try { applyConfig(payload); } catch (error) { report("config: " + describe(error)); }
  });
  Open77.on("chat:open", function () {
    try { open(); } catch (error) { report("open: " + describe(error)); }
  });
  Open77.on("chat:close", function () {
    try { close(); } catch (error) { report("close: " + describe(error)); }
  });
  Open77.on("chat:addMessage", function (payload) {
    try { addMessage(payload); } catch (error) { report("message: " + describe(error)); }
  });
  Open77.on("chat:addSuggestion", function (payload) {
    try { addSuggestion(payload); renderSuggestions(); }
    catch (error) { report("suggestion: " + describe(error)); }
  });
  Open77.on("chat:addSuggestions", function (payload) {
    try {
      var incoming = list(payload && payload.suggestions);
      for (var i = 0; i < incoming.length; i += 1) addSuggestion(incoming[i]);
      renderSuggestions();
    } catch (error) { report("suggestions: " + describe(error)); }
  });
  Open77.on("chat:removeSuggestion", function (payload) {
    try {
      var name = text(payload && payload.command);
      if (name.charAt(0) !== "/") name = "/" + name;
      delete suggestions[name];
      renderSuggestions();
    } catch (error) { report("remove: " + describe(error)); }
  });
  Open77.on("chat:clearSuggestions", function () {
    try { suggestions = {}; renderSuggestions(); }
    catch (error) { report("clearSuggestions: " + describe(error)); }
  });
  Open77.on("chat:clear", function () {
    try {
      while (elements.log.firstChild) elements.log.removeChild(elements.log.firstChild);
    } catch (error) { report("clear: " + describe(error)); }
  });
  Open77.on("chat:state", function (payload) {
    try { if (payload && payload.enabled === false) close(); }
    catch (error) { report("state: " + describe(error)); }
  });

  // `chat:ready` MUST be emitted whatever happened above: Lua drops every message until the
  // page has reported ready, so a throw before this costs the box every line it is ever sent.
  try { Open77.ready(); } catch (error) { report("ready: " + describe(error)); }
  Open77.emit("chat:ready", {});
})();
