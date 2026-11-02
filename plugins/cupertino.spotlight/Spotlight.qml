import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons as Commons
import "Bangs.js" as Bangs
import "Calculator.js" as Calculator
import "Cities.js" as Cities
import "Converter.js" as Converter
import "Glob.js" as Glob

Item {
  id: root

  property var shell: null
  property var manifest: null

  property bool opened: false
  property string query: ""
  property int selectedIndex: 0
  property var fileResults: []
  property var contentResults: []
  property var recentFiles: []
  property var clipboardEntries: []
  property var usage: ({})
  property var answer: null
  property var rates: ({})
  property var fileInfo: ({})
  property bool bangsLoaded: false

  readonly property string home: Quickshell.env("HOME")
  readonly property int cardWidth: 900
  readonly property int previewWidth: 320
  readonly property int rowHeight: 40
  readonly property int headerHeight: 24
  readonly property int minListHeight: 350
  readonly property int maxListHeight: 500
  readonly property int searchHeight: 58
  readonly property int hintHeight: 30

  // Pure lookups that only mean something once you start typing them.
  readonly property var settings: [
    { title: "Wi-Fi", keys: "network internet wireless", icon: "network-wireless", command: ["omarchy-shell", "shell", "toggle", "omarchy.network", "{}"] },
    { title: "Bluetooth", keys: "devices headphones", icon: "bluetooth", command: ["omarchy-shell", "shell", "toggle", "omarchy.bluetooth", "{}"] },
    { title: "Sound", keys: "audio volume speakers microphone", icon: "audio-volume-high", command: ["omarchy-shell", "shell", "toggle", "omarchy.audio", "{}"] },
    { title: "Displays", keys: "monitor resolution brightness screen", icon: "video-display", command: ["omarchy-shell", "shell", "toggle", "omarchy.monitor", "{}"] },
    { title: "Wallpaper", keys: "background desktop", icon: "preferences-desktop-wallpaper", command: ["omarchy-menu", "toggle", "background"] },
    { title: "Appearance", keys: "theme dark light", icon: "preferences-desktop-theme", command: ["omarchy-menu", "toggle", "theme"] },
    { title: "Keyboard Shortcuts", keys: "keybindings hotkeys", icon: "preferences-desktop-keyboard-shortcuts", command: ["omarchy-menu-keybindings"] },
    { title: "Battery & Power", keys: "energy power profile", icon: "preferences-system-power", command: ["omarchy-shell", "shell", "toggle", "omarchy.power", "{}"] },
    { title: "System Settings", keys: "preferences setup configuration", icon: "preferences-system", command: ["omarchy-menu", "toggle", "setup"] },
    { title: "Advanced Settings", keys: "omarchy menu", icon: "preferences-system", command: ["omarchy-menu", "toggle", "root"] }
  ]

  readonly property var quickActions: [
    { title: "Mission Control", keys: "windows expose overview desktops spaces", icon: "mission-control", command: ["omarchy-shell", "shell", "toggle", "cupertino.mission-control", "{}"] },
    { title: "Launchpad", keys: "apps applications", icon: "launchpad", command: ["omarchy-shell", "shell", "toggle", "cupertino.launchpad", "{}"] },
    { title: "Toggle Do Not Disturb", keys: "dnd focus silence notifications", icon: "notifications-disabled", command: ["omarchy-shell", "notifications", "toggleDnd"] },
    { title: "Toggle Night Shift", keys: "nightlight warm blue", icon: "weather-clear-night", command: ["omarchy", "toggle", "nightlight"] },
    { title: "Take Screenshot", keys: "capture screen", icon: "applets-screenshooter", command: ["omarchy", "capture", "screenshot"] },
    { title: "Clipboard History", keys: "paste copied", icon: "edit-paste", command: ["omarchy-shell", "shell", "toggle", "omarchy.clipboard", "{}"] },
    { title: "Emoji & Symbols", keys: "emojis smileys", icon: "face-smile", command: ["omarchy-shell", "shell", "toggle", "omarchy.emojis", "{}"] },
    { title: "Open Trash", keys: "bin deleted", icon: "user-trash", command: ["xdg-open", "trash:///"] }
  ]

  // Machine-state changes: they need four typed letters so a stray Enter can't restart anything.
  readonly property var systemActions: [
    { title: "Lock Screen", icon: "system-lock-screen", command: ["omarchy", "system", "lock"] },
    { title: "Log Out", icon: "system-log-out", command: ["omarchy", "system", "logout"] },
    { title: "Restart", icon: "system-reboot", command: ["omarchy", "system", "reboot"] },
    { title: "Shut Down", icon: "system-shutdown", command: ["omarchy", "system", "shutdown"] }
  ]

  function open(payloadJson) {
    query = ""
    selectedIndex = 0
    fileResults = []
    contentResults = []
    answer = null
    opened = true
    usageFile.reload()
    clipboardFile.reload()
    recentFinder.running = true
    bangFile.path = home + "/.config/omarchy/plugins/cupertino.spotlight/bangs.tsv"
    Qt.callLater(function() { searchInput.forceActiveFocus() })
  }

  function close() {
    opened = false
  }

  function dismiss() {
    opened = false
    if (shell && typeof shell.hide === "function") shell.hide((manifest && manifest.id) || "cupertino.spotlight")
  }

  function iconFor(name, fallback) {
    var chosen = fallback || "application-x-executable"
    if (name && name.indexOf("/") === 0) return "file://" + name
    return Quickshell.iconPath(name ? name : chosen, chosen)
  }

  // Best match first: exact word start, initials ("vsc" for Visual Studio Code), substring, keywords, loose order.
  function score(needle, name, extra) {
    var haystack = name.toLowerCase()
    if (haystack === needle) return 120
    if (haystack.indexOf(needle) === 0) return 100
    var words = haystack.split(/[\s\-_.]+/).filter(function(word) { return word !== "" })
    if (words.some(function(word) { return word.indexOf(needle) === 0 })) return 85
    if (needle.length >= 2 && words.map(function(word) { return word.charAt(0) }).join("").indexOf(needle) === 0) return 80
    if (haystack.indexOf(needle) >= 0) return 60
    if (extra && extra.toLowerCase().indexOf(needle) >= 0) return 40
    if (needle.length >= 3) {
      var at = 0
      for (var i = 0; i < haystack.length && at < needle.length; i++) {
        if (haystack[i] === needle[at]) at++
      }
      if (at === needle.length) return 20
    }
    return 0
  }

  function usageBoost(id) {
    var entry = usage[id]
    return entry ? Math.min(30, entry.count * 3) : 0
  }

  function appRow(entry, section, rank) {
    return {
      kind: "app",
      section: section,
      rank: rank,
      title: entry.name,
      detail: "Application",
      icon: iconFor(entry.icon),
      id: entry.id,
      preview: { heading: entry.name, subtitle: entry.genericName || "Application", body: entry.comment || "" }
    }
  }

  function appRows(needle) {
    return DesktopEntries.applications.values
      .filter(function(entry) { return !entry.noDisplay })
      .map(function(entry) {
        var extra = [entry.genericName, entry.comment, entry.id].concat(entry.keywords || []).join(" ")
        var base = score(needle, entry.name, extra)
        return { entry: entry, rank: base > 0 ? base + usageBoost(entry.id) : 0 }
      })
      .filter(function(item) { return item.rank > 0 })
      .sort(function(a, b) { return b.rank - a.rank || a.entry.name.localeCompare(b.entry.name) })
      .slice(0, 5)
      .map(function(item) { return appRow(item.entry, "Applications", item.rank) })
  }

  // Hyprland ignores foreign-toplevel activation across workspaces, so ask it to focus by address.
  function focusWindow(toplevel) {
    var hyprlandToplevels = Hyprland.toplevels.values
    for (var i = 0; i < hyprlandToplevels.length; i++) {
      if (hyprlandToplevels[i].wayland === toplevel) {
        var address = "address:0x" + hyprlandToplevels[i].address
        // Minimized windows wait on a hidden workspace; bring them back first.
        var workspace = hyprlandToplevels[i].workspace
        if (workspace && workspace.name === "special:minimized") {
          var current = Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1
          Hyprland.dispatch("hl.dsp.window.move({ workspace = \"" + current + "\", follow = false, window = \"" + address + "\" })")
        }
        Hyprland.dispatch("hl.dsp.focus({ window = \"" + address + "\" })")
        return
      }
    }
    toplevel.activate()
  }

  function workspaceOf(toplevel) {
    var hyprlandToplevels = Hyprland.toplevels.values
    for (var i = 0; i < hyprlandToplevels.length; i++) {
      if (hyprlandToplevels[i].wayland === toplevel) return hyprlandToplevels[i].workspace
    }
    return null
  }

  function windowRows(needle) {
    return ToplevelManager.toplevels.values
      .filter(function(toplevel) {
        return ((toplevel.title || "") + " " + (toplevel.appId || "")).toLowerCase().indexOf(needle) >= 0
      })
      .slice(0, 4)
      .map(function(toplevel) {
        var appId = toplevel.appId || ""
        var entry = DesktopEntries.heuristicLookup(appId === "org.omarchy.agent" ? "com.mitchellh.ghostty" : appId)
        var workspace = workspaceOf(toplevel)
        var where = !workspace ? "" : workspace.name === "special:minimized" ? "Minimized" : workspace.id > 0 ? "Desktop " + workspace.id : "Scratchpad"
        return {
          kind: "window",
          section: "Windows",
          rank: 50,
          title: toplevel.title || appId,
          detail: where,
          icon: iconFor(entry ? entry.icon : ""),
          toplevel: toplevel,
          preview: { heading: toplevel.title || appId, subtitle: entry ? entry.name : appId, meta: where ? [["Location", where]] : [] }
        }
      })
  }

  function actionRows(list, needle, section) {
    return list
      .map(function(action) { return { action: action, rank: score(needle, action.title, action.keys) } })
      .filter(function(item) { return item.rank > 0 })
      .sort(function(a, b) { return b.rank - a.rank })
      .slice(0, 4)
      .map(function(item) {
        return {
          kind: "command",
          section: section,
          rank: item.rank,
          title: item.action.title,
          detail: section === "System Settings" ? "System Settings" : "Action",
          icon: iconFor(item.action.icon, "preferences-system"),
          command: item.action.command,
          preview: { heading: item.action.title, subtitle: section }
        }
      })
  }

  function systemRows(needle) {
    if (needle.length < 4) return []
    return systemActions
      .filter(function(action) { return action.title.toLowerCase().indexOf(needle) === 0 })
      .map(function(action) {
        return {
          kind: "command",
          section: "System",
          rank: 0,
          title: action.title,
          detail: "System",
          icon: iconFor(action.icon, "system-run"),
          command: action.command,
          preview: { heading: action.title, subtitle: "System" }
        }
      })
  }

  function answerRows(text) {
    var rows = []
    var calcIcon = iconFor("accessories-calculator")

    var value = Calculator.evaluate(text)
    if (value !== null) {
      var shown = value.toLocaleString(Qt.locale("en_US"), "f", 10).replace(/\.?0+$/, "")
      rows.push({
        kind: "copy", section: "Calculator", title: shown, detail: text, icon: calcIcon, value: String(value),
        preview: { big: shown, subtitle: text }
      })
    }

    var converted = Converter.convert(text)
    if (converted) {
      rows.push({
        kind: "copy", section: "Conversion", title: converted.text, detail: converted.expression, icon: calcIcon, value: converted.value,
        preview: { big: converted.text, subtitle: converted.expression }
      })
    }

    var money = Converter.currency(text)
    if (money) {
      var table = rates[money.from]
      var amount = table && table.rates[money.to] !== undefined ? money.amount * table.rates[money.to] : null
      var moneyText = amount === null ? "Fetching rates\u2026" : Number(amount.toFixed(2)).toLocaleString(Qt.locale("en_US"), "f", 2) + " " + money.to
      rows.push({
        kind: amount === null ? "none" : "copy", section: "Currency", title: moneyText,
        detail: money.amount + " " + money.from, icon: calcIcon, value: amount === null ? "" : amount.toFixed(2),
        preview: { big: moneyText, subtitle: money.amount + " " + money.from, meta: table ? [["Rates from", table.date]] : [] }
      })
    }

    var city = Cities.lookup(text)
    if (city) {
      var clock = answer && answer.type === "time" && answer.key === text ? answer : null
      rows.push({
        kind: clock ? "copy" : "none", section: "World Clock", title: clock ? clock.time : "\u2026", detail: city.city,
        icon: iconFor("preferences-system-time", "x-office-calendar"), value: clock ? clock.time : "",
        preview: { big: clock ? clock.time : "", subtitle: city.city, meta: clock ? [["Date", clock.date], ["Offset", clock.offset]] : [] }
      })
    }

    var word = text.match(/^(?:define|dict|definition of|meaning of)\s+([a-zA-Z'-]+)$/i)
    if (word) {
      var definition = answer && answer.type === "define" && answer.key === text ? answer : null
      rows.push({
        kind: definition && definition.ok ? "copy" : "none", section: "Dictionary", title: word[1],
        detail: definition ? (definition.ok ? definition.phonetic : "No definition found") : "Looking up\u2026",
        icon: iconFor("accessories-dictionary", "accessories-text-editor"), value: definition && definition.ok ? definition.body : "",
        preview: { heading: word[1], subtitle: definition ? definition.phonetic : "", body: definition ? definition.body : "" }
      })
    }

    var weather = text.match(/^weather(?:\s+(?:in\s+)?(.+))?$/i)
    if (weather) {
      var report = answer && answer.type === "weather" && answer.key === text ? answer : null
      rows.push({
        kind: "command", section: "Weather", title: report && report.ok ? report.temperature + " " + report.condition : (report ? "Weather unavailable" : "Checking\u2026"),
        detail: weather[1] || (report && report.area) || "Here", icon: iconFor("weather-few-clouds", "weather-clear"),
        command: ["omarchy-shell", "shell", "toggle", "omarchy.weather", "{}"],
        preview: report && report.ok
          ? { big: report.temperature, subtitle: report.condition + " \u00b7 " + report.area, meta: [["Feels like", report.feels], ["Humidity", report.humidity], ["Wind", report.wind]] }
          : { heading: "Weather", subtitle: weather[1] || "" }
      })
    }

    return rows
  }

  function clipboardRows(text) {
    var match = text.match(/^(?:clip|clipboard)(?:\s+(.*))?$/i)
    if (!match) return []
    var needle = (match[1] || "").toLowerCase()
    return clipboardEntries
      .filter(function(entry) { return entry.type === "text" && entry.text.toLowerCase().indexOf(needle) >= 0 })
      .slice(0, 8)
      .map(function(entry) {
        return {
          kind: "copy", section: "Clipboard", title: entry.text.replace(/\s+/g, " ").slice(0, 120), detail: entry.text.length + " characters",
          icon: iconFor("edit-paste"), value: entry.text,
          preview: { heading: "Clipboard", body: entry.text.slice(0, 3000) }
        }
      })
  }

  function fileKind(path, isDirectory) {
    if (isDirectory) return { section: "Folders", icon: "folder", label: "Folder" }
    var extension = path.split("/").pop().split(".").pop().toLowerCase()
    if (/^(png|jpe?g|gif|webp|svg|bmp|heic|avif)$/.test(extension)) return { section: "Images", icon: "image-x-generic", label: "Image" }
    if (/^(mp4|mkv|mov|webm|avi)$/.test(extension)) return { section: "Movies", icon: "video-x-generic", label: "Movie" }
    if (/^(mp3|flac|wav|ogg|m4a|opus)$/.test(extension)) return { section: "Music", icon: "audio-x-generic", label: "Audio" }
    if (extension === "pdf") return { section: "PDF Documents", icon: "application-pdf", label: "PDF Document" }
    if (/^(docx?|odt|rtf|pptx?|odp|xlsx?|ods|csv|md|txt|tex)$/.test(extension)) return { section: "Documents", icon: "x-office-document", label: "Document" }
    if (/^(js|ts|tsx|jsx|py|c|h|cpp|hpp|rs|go|java|qml|lua|sh|html|css|json|toml|ya?ml|kt|rb)$/.test(extension)) return { section: "Developer", icon: "text-x-script", label: "Source Code" }
    if (/^(zip|tar|gz|xz|7z|rar|zst)$/.test(extension)) return { section: "Archives", icon: "package-x-generic", label: "Archive" }
    return { section: "Documents", icon: "text-x-generic", label: "File" }
  }

  function fileRow(path, section) {
    var isDirectory = path.charAt(path.length - 1) === "/"
    var clean = isDirectory ? path.slice(0, -1) : path
    var kind = fileKind(clean, isDirectory)
    var where = clean.slice(0, clean.lastIndexOf("/")).replace(home, "~")
    var name = clean.split("/").pop()
    return {
      kind: "file",
      section: section || kind.section,
      title: name,
      detail: where,
      icon: iconFor(kind.icon, "text-x-generic"),
      path: clean,
      isDirectory: isDirectory,
      preview: { heading: name, subtitle: kind.label, meta: [["Where", where]] }
    }
  }

  // "kind:pdf report" narrows the file search, as Spotlight does.
  readonly property var parsedQuery: {
    var text = query.trim()
    var match = text.match(/^(?:(.*\S)\s+)?kind:(\w+)(?:\s+(.*))?$/i)
    if (!match) return { text: text, kind: "" }
    return { text: [match[1], match[3]].filter(function(part) { return !!part }).join(" "), kind: match[2].toLowerCase() }
  }

  readonly property var kindExtensions: ({
    pdf: ["pdf"],
    image: ["png", "jpg", "jpeg", "gif", "webp", "svg", "heic"], images: ["png", "jpg", "jpeg", "gif", "webp", "svg", "heic"],
    movie: ["mp4", "mkv", "mov", "webm"], video: ["mp4", "mkv", "mov", "webm"],
    music: ["mp3", "flac", "wav", "ogg", "m4a"], audio: ["mp3", "flac", "wav", "ogg", "m4a"],
    document: ["pdf", "doc", "docx", "odt", "rtf", "txt", "md", "tex"], doc: ["pdf", "doc", "docx", "odt", "rtf", "txt", "md", "tex"],
    code: ["js", "ts", "py", "c", "cpp", "rs", "go", "java", "qml", "lua", "sh"],
    archive: ["zip", "tar", "gz", "xz", "7z", "rar"]
  })

  // A filename pattern, unless it's really a sum like 2*3.
  readonly property var globQuery: Calculator.evaluate(query.trim()) === null ? Glob.parse(query.trim(), home) : null

  readonly property var bangQuery: bangsLoaded && !globQuery ? Bangs.parse(query.trim()) : null

  // "!you" while it's still being typed.
  readonly property string bangFragment: {
    var match = query.match(/^!(\S+)$/)
    return match ? match[1] : ""
  }

  function bangRow(bang, terms, section) {
    return {
      kind: "web",
      section: section,
      title: terms !== "" ? terms : bang.name,
      detail: "!" + bang.trigger + " \u00b7 " + bang.name,
      icon: iconFor("web-browser"),
      url: Bangs.urlFor(bang, terms),
      trigger: bang.trigger,
      preview: {
        heading: bang.name,
        subtitle: "!" + bang.trigger,
        body: "Your search is only sent if you open this result.",
        meta: [["Site", bang.domain]]
      }
    }
  }

  readonly property var rows: {
    var text = query.trim()
    var result = []

    if (globQuery) return fileResults

    // Typing "!" lists the most used bangs; more letters narrow it down.
    if (text === "!" && bangsLoaded) {
      return Bangs.list.slice(0, 12).map(function(bang) { return bangRow(bang, "", "Bangs") })
    }
    if (bangFragment !== "" && bangsLoaded) {
      var matches = Bangs.complete(bangFragment, 12).map(function(bang) { return bangRow(bang, "", "Bangs") })
      if (matches.length > 0) return matches
    }

    // "!yt cats" says exactly what it wants, so nothing else competes with it.
    if (bangQuery && bangQuery.explicit) {
      return [bangRow(bangQuery.bang, bangQuery.terms, "Search " + bangQuery.bang.name)]
    }

    if (text === "") {
      var used = DesktopEntries.applications.values
        .filter(function(entry) { return !entry.noDisplay && usage[entry.id] })
        .sort(function(a, b) { return usage[b.id].last - usage[a.id].last })
        .slice(0, 4)
        .map(function(entry) { return appRow(entry, "Recent Applications", 0) })
      return used.concat(recentFiles.slice(0, 5).map(function(path) { return fileRow(path, "Recent Documents") }))
    }

    var needle = text.toLowerCase()
    var answers = answerRows(text)
    var fileOnly = parsedQuery.kind !== ""
    var apps = fileOnly ? [] : appRows(needle)
    var windows = fileOnly ? [] : windowRows(needle)
    var settingRows = fileOnly ? [] : actionRows(settings, needle, "System Settings")
    var actions = fileOnly ? [] : actionRows(quickActions, needle, "Actions")

    // The strongest app, setting or action leads as the Top Hit. Files arrive later, so they can't jump the queue.
    var candidates = apps.concat(settingRows, actions)
    var top = null
    candidates.forEach(function(row) { if (row.rank >= 60 && (!top || row.rank > top.rank)) top = row })

    function without(list) {
      return list.filter(function(row) { return row !== top })
    }

    // A bare "yt cats" leads only for everyday bangs. Answers still beat it, so "time in tokyo" stays a clock.
    var bangLeads = bangQuery && bangQuery.everyday && answers.length === 0
    if (bangLeads) {
      result.push(bangRow(bangQuery.bang, bangQuery.terms, "Search " + bangQuery.bang.name))
    } else if (top) {
      var hit = Object.assign({}, top)
      hit.section = "Top Hit"
      result.push(hit)
    }

    if (bangLeads) top = null

    result = result.concat(
      answers,
      clipboardRows(text),
      without(apps),
      windows,
      without(settingRows),
      without(actions),
      fileOnly ? [] : systemRows(needle),
      fileResults,
      contentResults
    )

    if (bangQuery && !bangLeads && !fileOnly && answers.length === 0) {
      result.push(bangRow(bangQuery.bang, bangQuery.terms, "Search " + bangQuery.bang.name))
    }

    if (!fileOnly) {
      result.push({
        kind: "web", section: "Search the Web", title: text, detail: "Google", icon: iconFor("web-browser"),
        url: "https://www.google.com/search?q=" + encodeURIComponent(text),
        preview: { heading: "Search the Web", subtitle: "\u201c" + text + "\u201d", body: "Your search is only sent if you open this result." }
      })
    }
    return result
  }

  readonly property var selectedRow: rows[selectedIndex] || null

  readonly property int sectionCount: {
    var seen = 0
    var last = null
    rows.forEach(function(row) {
      if (row.section !== last) seen++
      last = row.section
    })
    return seen
  }

  onRowsChanged: {
    if (selectedIndex >= rows.length) selectedIndex = Math.max(0, rows.length - 1)
  }

  onSelectedRowChanged: {
    previewDelay.stop()
    if (selectedRow && selectedRow.kind === "file" && !fileInfo[selectedRow.path]) previewDelay.restart()
  }

  onQueryChanged: {
    selectedIndex = 0
    fileResults = []
    contentResults = []
    answer = null
    fileDebounce.stop()
    contentDebounce.stop()
    lookupDebounce.stop()
    var text = query.trim()
    // Bangs are aimed at a website, so they don't search your files too.
    if (text.charAt(0) === "!" || /\s!\S+$/.test(text)) return
    if (globQuery || parsedQuery.text.length >= 2 || parsedQuery.kind !== "") fileDebounce.restart()
    if (!globQuery && parsedQuery.text.length >= 3) contentDebounce.restart()
    if (text !== "" && !globQuery) lookupDebounce.restart()
  }

  // Remembers what you launch from here, on this machine only, to rank it higher next time.
  function recordUse(id) {
    var next = {}
    for (var key in usage) next[key] = usage[key]
    next[id] = { count: (next[id] ? next[id].count : 0) + 1, last: Date.now() }
    usage = next
    usageFile.setText(JSON.stringify(next))
  }

  function run(row) {
    if (!row || row.kind === "none") return
    dismiss()
    if (row.kind === "app") {
      recordUse(row.id)
      Quickshell.execDetached(["uwsm-app", "--", "gtk-launch", row.id + ".desktop"])
    } else if (row.kind === "window") {
      pendingWindow = row.toplevel
      focusDelay.restart()
    } else if (row.kind === "command") {
      Quickshell.execDetached(row.command)
    } else if (row.kind === "file") {
      Quickshell.execDetached(["xdg-open", row.path])
    } else if (row.kind === "web") {
      Quickshell.execDetached(["xdg-open", row.url])
    } else if (row.kind === "copy") {
      Quickshell.execDetached(["wl-copy", "--", row.value])
    }
  }

  function reveal(row) {
    if (!row || row.kind !== "file") return
    dismiss()
    Quickshell.execDetached(["uwsm-app", "--", "nautilus", "--select", row.path])
  }

  function copyOf(row) {
    if (!row) return ""
    if (row.kind === "file") return row.path
    if (row.kind === "copy") return row.value
    if (row.kind === "web") return row.url
    return row.title
  }

  function move(delta) {
    if (rows.length === 0) return
    selectedIndex = (selectedIndex + delta + rows.length) % rows.length
    resultList.positionViewAtIndex(selectedIndex, ListView.Contain)
  }

  // Tab jumps between sections.
  function jumpSection(direction) {
    if (rows.length === 0) return
    var section = rows[selectedIndex].section
    var index = selectedIndex
    for (var step = 0; step < rows.length; step++) {
      index = (index + direction + rows.length) % rows.length
      if (rows[index].section !== section) break
    }
    if (direction < 0) {
      while (rows[(index - 1 + rows.length) % rows.length].section === rows[index].section && index > 0) index--
    }
    selectedIndex = index
    resultList.positionViewAtIndex(selectedIndex, ListView.Contain)
  }

  // Focus has to wait for this overlay to give up the keyboard, or Hyprland hands it straight back.
  property var pendingWindow: null
  Timer {
    id: focusDelay
    interval: 80
    onTriggered: root.focusWindow(root.pendingWindow)
  }

  FileView {
    id: usageFile
    path: root.home + "/.local/state/omarchy/spotlight-usage.json"
    atomicWrites: true
    printErrors: false
    onLoaded: {
      try {
        root.usage = JSON.parse(text()) || {}
      } catch (error) {
        root.usage = {}
      }
    }
  }

  // Loaded the first time Spotlight opens, then kept for the rest of the session.
  FileView {
    id: bangFile
    printErrors: true
    onLoaded: {
      Bangs.load(text())
      root.bangsLoaded = true
    }
  }

  FileView {
    id: clipboardFile
    path: root.home + "/.local/state/omarchy/clipboard-history.json"
    printErrors: false
    onLoaded: {
      try {
        root.clipboardEntries = JSON.parse(text()) || []
      } catch (error) {
        root.clipboardEntries = []
      }
    }
  }

  // Newest first, and only files that still exist.
  Process {
    id: recentFinder
    command: ["sh", "-c",
      "f=\"$HOME/.local/share/recently-used.xbel\"; [ -f \"$f\" ] || exit 0; " +
      "sed -n 's/.*href=\"file:\\/\\/\\([^\"]*\\)\".*modified=\"\\([^\"]*\\)\".*/\\2 \\1/p' \"$f\" | sort -r | cut -d' ' -f2- | head -20"]
    stdout: StdioCollector {
      onStreamFinished: recentChecker.check(text.split("\n").filter(function(line) { return line !== "" }).map(function(path) {
        try {
          return decodeURIComponent(path)
        } catch (error) {
          return path
        }
      }))
    }
  }

  Process {
    id: recentChecker
    function check(paths) {
      if (paths.length === 0) {
        root.recentFiles = []
        return
      }
      command = ["sh", "-c", "for f in \"$@\"; do if [ -d \"$f\" ]; then printf '%s/\\n' \"$f\"; elif [ -e \"$f\" ]; then printf '%s\\n' \"$f\"; fi; done", "--"].concat(paths)
      running = true
    }
    stdout: StdioCollector {
      onStreamFinished: root.recentFiles = text.split("\n").filter(function(line) { return line !== "" })
    }
  }

  Timer {
    id: fileDebounce
    interval: 170
    onTriggered: {
      if (fileSearch.running) {
        fileSearch.restartAfterExit = true
        fileSearch.running = false
      } else {
        fileSearch.start()
      }
    }
  }

  Process {
    id: fileSearch
    property string searched: ""
    property bool restartAfterExit: false

    function start() {
      searched = root.query.trim()
      var glob = root.globQuery
      if (glob) {
        var globArgs = ["timeout", "3", "fd", "--ignore-case", "--glob", "--absolute-path", "--no-ignore-vcs", "--max-depth", "10",
          "--max-results", "60", "--exclude", "node_modules", "--base-directory", glob.base]
        if (glob.fullPath) globArgs.push("--full-path")
        if (glob.hidden) globArgs.push("--hidden")
        globArgs.push("--", glob.pattern)
        command = globArgs
        running = true
        return
      }
      var args = ["timeout", "2", "fd", "--ignore-case", "--fixed-strings", "--absolute-path", "--max-depth", "7",
        "--max-results", "8", "--exclude", "node_modules", "--base-directory", root.home]
      var extensions = root.kindExtensions[root.parsedQuery.kind]
      if (extensions) extensions.forEach(function(extension) { args.push("--extension", extension) })
      if (root.parsedQuery.kind === "folder") args.push("--type", "directory")
      args.push("--", root.parsedQuery.text)
      command = args
      running = true
    }

    stdout: StdioCollector {
      onStreamFinished: {
        if (fileSearch.searched !== root.query.trim()) return
        var paths = text.split("\n").filter(function(line) { return line !== "" })
        if (root.globQuery && paths.length === 0) {
          root.fileResults = [{
            kind: "none", section: "Files", title: "No files match " + fileSearch.searched, detail: "", icon: root.iconFor("edit-find", "system-search"),
            preview: { heading: "No Matches", subtitle: fileSearch.searched, body: "Hidden folders are skipped unless you name one, as in ~/.config/**/*.toml" }
          }]
          return
        }
        if (root.globQuery) {
          var heading = paths.length === 60 ? "First 60 Matching " : paths.length + (paths.length === 1 ? " File Matching " : " Files Matching ")
          root.fileResults = paths.sort().map(function(path) { return root.fileRow(path, heading + fileSearch.searched) })
          return
        }
        // Keep rows in the same section together.
        var seen = []
        var grouped = {}
        paths.forEach(function(path) {
          var row = root.fileRow(path)
          if (!grouped[row.section]) {
            grouped[row.section] = []
            seen.push(row.section)
          }
          grouped[row.section].push(row)
        })
        root.fileResults = seen.reduce(function(all, section) { return all.concat(grouped[section]) }, [])
      }
    }

    onExited: {
      if (!restartAfterExit) return
      restartAfterExit = false
      if (root.globQuery || root.parsedQuery.text.length >= 2 || root.parsedQuery.kind !== "") start()
    }
  }

  Timer {
    id: contentDebounce
    interval: 420
    onTriggered: {
      if (contentSearch.running) {
        contentSearch.restartAfterExit = true
        contentSearch.running = false
      } else {
        contentSearch.start()
      }
    }
  }

  // Finds documents by what's inside them. It stops after two seconds so it can't load the machine.
  Process {
    id: contentSearch
    property string searched: ""
    property bool restartAfterExit: false

    function start() {
      searched = root.query.trim()
      command = ["timeout", "2", "nice", "rg", "--files-with-matches", "--fixed-strings", "--ignore-case", "--threads", "4",
        "--max-filesize", "1M", "--max-depth", "6", "--glob", "!node_modules", "--", root.parsedQuery.text, root.home]
      running = true
    }

    stdout: StdioCollector {
      onStreamFinished: {
        if (contentSearch.searched !== root.query.trim()) return
        var named = root.fileResults.map(function(row) { return row.path })
        root.contentResults = text.split("\n")
          .filter(function(line) { return line !== "" && named.indexOf(line) < 0 })
          .slice(0, 6)
          .map(function(path) { return root.fileRow(path, "Documents Containing \u201c" + contentSearch.searched + "\u201d") })
      }
    }

    onExited: {
      if (!restartAfterExit) return
      restartAfterExit = false
      if (root.parsedQuery.text.length >= 3) start()
    }
  }

  // Lookups that need the network run only for text clearly asking for them, never for ordinary searches.
  Timer {
    id: lookupDebounce
    interval: 260
    onTriggered: {
      var text = root.query.trim()
      var money = Converter.currency(text)
      if (money) {
        if (!root.rates[money.from]) lookup.fetch("rates", money.from, ["curl", "-sf", "-m", "6", "https://api.frankfurter.dev/v1/latest?base=" + money.from])
        return
      }
      var city = Cities.lookup(text)
      if (city) {
        lookup.fetch("time", text, ["env", "TZ=" + city.zone, "date", "+%H:%M|%A, %B %-d|UTC%:z"])
        return
      }
      var word = text.match(/^(?:define|dict|definition of|meaning of)\s+([a-zA-Z'-]+)$/i)
      if (word) {
        lookup.fetch("define", text, ["curl", "-s", "-m", "6", "https://api.dictionaryapi.dev/api/v2/entries/en/" + encodeURIComponent(word[1])])
        return
      }
      var weather = text.match(/^weather(?:\s+(?:in\s+)?(.+))?$/i)
      if (weather) lookup.fetch("weather", text, ["curl", "-sf", "-m", "8", "https://wttr.in/" + encodeURIComponent(weather[1] || "") + "?format=j1"])
    }
  }

  Process {
    id: lookup
    property string type: ""
    property string key: ""

    function fetch(nextType, nextKey, nextCommand) {
      running = false
      type = nextType
      key = nextKey
      command = nextCommand
      running = true
    }

    stdout: StdioCollector {
      onStreamFinished: {
        var parsed = null
        try {
          if (lookup.type === "time") {
            var parts = text.trim().split("|")
            root.answer = { type: "time", key: lookup.key, time: parts[0], date: parts[1], offset: parts[2] }
            return
          }
          parsed = JSON.parse(text)
        } catch (error) {
          parsed = null
        }

        if (lookup.type === "rates") {
          if (parsed && parsed.rates) {
            var next = {}
            for (var base in root.rates) next[base] = root.rates[base]
            next[lookup.key] = parsed
            root.rates = next
          }
        } else if (lookup.type === "define") {
          var ok = Array.isArray(parsed) && parsed.length > 0
          var lines = []
          if (ok) {
            parsed[0].meanings.slice(0, 3).forEach(function(meaning) {
              lines.push(meaning.partOfSpeech)
              meaning.definitions.slice(0, 2).forEach(function(item, index) { lines.push((index + 1) + ". " + item.definition) })
              lines.push("")
            })
          }
          root.answer = { type: "define", key: lookup.key, ok: ok, phonetic: ok ? (parsed[0].phonetic || "") : "No definition found", body: lines.join("\n").trim() }
        } else if (lookup.type === "weather") {
          var current = parsed && parsed.current_condition ? parsed.current_condition[0] : null
          if (current) {
            var area = parsed.nearest_area && parsed.nearest_area[0] ? parsed.nearest_area[0].areaName[0].value : ""
            root.answer = {
              type: "weather", key: lookup.key, ok: true, area: area, temperature: current.temp_C + "\u00b0C",
              condition: current.weatherDesc[0].value, feels: current.FeelsLikeC + "\u00b0C", humidity: current.humidity + "%", wind: current.windspeedKmph + " km/h"
            }
          } else {
            root.answer = { type: "weather", key: lookup.key, ok: false }
          }
        }
      }
    }
  }

  Timer {
    id: previewDelay
    interval: 90
    onTriggered: {
      if (!root.selectedRow || root.selectedRow.kind !== "file") return
      previewProbe.running = false
      previewProbe.path = root.selectedRow.path
      previewProbe.command = ["sh", "-c",
        "stat -c '%s|%Y' -- \"$1\"; m=$(file -b --mime-type -- \"$1\"); echo \"$m\"; " +
        "case \"$m\" in text/*|application/json|application/xml|application/javascript) head -c 2500 -- \"$1\";; " +
        "application/pdf) pdftotext -l 1 -- \"$1\" - 2>/dev/null | head -c 2500;; esac", "--", previewProbe.path]
      previewProbe.running = true
    }
  }

  Process {
    id: previewProbe
    property string path: ""
    stdout: StdioCollector {
      onStreamFinished: {
        var first = text.indexOf("\n")
        var second = text.indexOf("\n", first + 1)
        if (first < 0 || second < 0) return
        var stat = text.slice(0, first).split("|")
        var next = {}
        for (var key in root.fileInfo) next[key] = root.fileInfo[key]
        next[previewProbe.path] = {
          size: Number(stat[0]),
          modified: new Date(Number(stat[1]) * 1000),
          mime: text.slice(first + 1, second),
          text: text.slice(second + 1)
        }
        root.fileInfo = next
      }
    }
  }

  function sizeText(bytes) {
    if (bytes < 1000) return bytes + " bytes"
    if (bytes < 1e6) return (bytes / 1000).toFixed(0) + " KB"
    if (bytes < 1e9) return (bytes / 1e6).toFixed(1) + " MB"
    return (bytes / 1e9).toFixed(1) + " GB"
  }

  readonly property var selectedInfo: selectedRow && selectedRow.kind === "file" ? (fileInfo[selectedRow.path] || null) : null
  readonly property var previewMeta: {
    if (!selectedRow || !selectedRow.preview) return []
    var meta = (selectedRow.preview.meta || []).slice()
    if (selectedInfo) {
      if (!selectedRow.isDirectory) meta.unshift(["Size", sizeText(selectedInfo.size)])
      meta.push(["Modified", Qt.formatDateTime(selectedInfo.modified, "MMM d, yyyy, HH:mm")])
    }
    return meta
  }

  readonly property string hintText: {
    var row = selectedRow
    if (!row) return ""
    if (row.kind === "file") return "\u23ce Open      Ctrl+\u23ce Show in Finder      Ctrl+C Copy Path      \u21e5 Next Section"
    if (row.kind === "copy") return "\u23ce Copy      \u21e5 Next Section"
    if (row.kind === "app") return "\u23ce Open      Ctrl+C Copy Name      \u21e5 Next Section"
    if (row.kind === "window") return "\u23ce Switch to Window      \u21e5 Next Section"
    if (row.trigger && (bangFragment !== "" || query.trim() === "!")) return "\u23ce Open Site      \u21e5 Search This Site"
    if (row.kind === "web") return "\u23ce Search      Ctrl+C Copy Link      \u21e5 Next Section"
    if (row.kind === "none") return "\u21e5 Next Section"
    return "\u23ce Open      \u21e5 Next Section"
  }

  PanelWindow {
    id: panel
    visible: root.opened
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "omarchy-spotlight"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore

    MouseArea {
      anchors.fill: parent
      onClicked: root.dismiss()
    }

    Rectangle {
      id: card
      readonly property bool expanded: root.rows.length > 0
      anchors.horizontalCenter: parent.horizontalCenter
      y: Math.round(parent.height * 0.14)
      width: Math.min(root.cardWidth, parent.width - 32)
      height: root.searchHeight + (expanded ? resultList.height + root.hintHeight + 14 : 0)
      radius: 16
      color: Qt.rgba(Commons.Color.background.r, Commons.Color.background.g, Commons.Color.background.b, 0.72)
      border.color: Qt.rgba(1, 1, 1, 0.2)
      border.width: 1

      // Swallow clicks on the card so they don't dismiss Spotlight.
      MouseArea { anchors.fill: parent }

      Text {
        id: glass
        x: 18
        width: 26
        height: root.searchHeight
        verticalAlignment: Text.AlignVCenter
        text: "\uf002"
        color: Commons.Color.foreground
        opacity: 0.65
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 20
      }

      TextInput {
        id: searchInput
        anchors.left: glass.right
        anchors.leftMargin: 8
        anchors.right: parent.right
        anchors.rightMargin: 18
        height: root.searchHeight
        verticalAlignment: TextInput.AlignVCenter
        color: Commons.Color.foreground
        selectionColor: "#0a84ff"
        selectedTextColor: "#ffffff"
        font.family: "Adwaita Sans"
        font.pixelSize: 24
        font.weight: Font.Light
        clip: true
        focus: true
        text: root.query
        onTextEdited: root.query = text

        Text {
          anchors.fill: parent
          verticalAlignment: Text.AlignVCenter
          visible: searchInput.text === ""
          text: "Spotlight Search"
          color: Commons.Color.foreground
          opacity: 0.45
          font: searchInput.font
        }

        Keys.onPressed: function(event) {
          var ctrl = event.modifiers & Qt.ControlModifier
          if (event.key === Qt.Key_Escape) {
            if (root.query !== "") root.query = ""
            else root.dismiss()
          } else if (event.key === Qt.Key_Down || (ctrl && event.key === Qt.Key_N)) {
            root.move(1)
          } else if (event.key === Qt.Key_Up || (ctrl && event.key === Qt.Key_P)) {
            root.move(-1)
          } else if (event.key === Qt.Key_Tab && root.selectedRow && root.selectedRow.trigger && root.bangFragment !== "") {
            root.query = "!" + root.selectedRow.trigger + " "
          } else if (event.key === Qt.Key_Tab && root.selectedRow && root.selectedRow.trigger && root.query.trim() === "!") {
            root.query = "!" + root.selectedRow.trigger + " "
          } else if (event.key === Qt.Key_Tab) {
            root.jumpSection(1)
          } else if (event.key === Qt.Key_Backtab) {
            root.jumpSection(-1)
          } else if (ctrl && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)) {
            root.reveal(root.selectedRow)
          } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.run(root.selectedRow)
          } else if (ctrl && event.key === Qt.Key_C && searchInput.selectedText === "" && root.selectedRow) {
            Quickshell.execDetached(["wl-copy", "--", root.copyOf(root.selectedRow)])
            root.dismiss()
          } else {
            return
          }
          event.accepted = true
        }
      }

      Rectangle {
        visible: card.expanded
        y: root.searchHeight
        x: 1
        width: parent.width - 2
        height: 1
        color: Qt.rgba(1, 1, 1, 0.14)
      }

      ListView {
        id: resultList
        visible: card.expanded
        x: 8
        y: root.searchHeight + 6
        width: parent.width - root.previewWidth - 16
        // Tall enough for the preview pane even with a single result.
        height: Math.max(root.minListHeight, Math.min(root.maxListHeight, root.rows.length * root.rowHeight + root.sectionCount * root.headerHeight))
        clip: true
        model: root.rows
        boundsBehavior: Flickable.StopAtBounds
        currentIndex: root.selectedIndex
        highlightFollowsCurrentItem: false

        delegate: Item {
          required property var modelData
          required property int index
          readonly property bool selected: index === root.selectedIndex
          readonly property bool startsSection: index === 0 || root.rows[index - 1].section !== modelData.section

          width: resultList.width
          height: root.rowHeight + (startsSection ? root.headerHeight : 0)

          Text {
            visible: parent.startsSection
            x: 10
            y: 6
            width: parent.width - 20
            textFormat: Text.PlainText
            text: parent.modelData.section
            elide: Text.ElideRight
            color: Commons.Color.foreground
            opacity: 0.55
            font.family: "Adwaita Sans"
            font.pixelSize: 12
            font.weight: Font.DemiBold
          }

          Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: root.rowHeight
            radius: 8
            color: parent.selected ? "#0058d0" : "transparent"
          }

          Image {
            id: rowIcon
            x: 10
            y: parent.height - root.rowHeight + (root.rowHeight - height) / 2
            width: 26
            height: 26
            source: parent.modelData.icon
            sourceSize: Qt.size(64, 64)
            fillMode: Image.PreserveAspectFit
            smooth: true
            mipmap: true
          }

          Text {
            id: rowDetail
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: rowIcon.verticalCenter
            width: Math.min(implicitWidth, parent.width * 0.38)
            textFormat: Text.PlainText
            text: parent.modelData.detail
            elide: Text.ElideMiddle
            color: parent.selected ? "#ffffff" : Commons.Color.foreground
            opacity: parent.selected ? 0.85 : 0.55
            font.family: "Adwaita Sans"
            font.pixelSize: 12
          }

          Text {
            anchors.left: rowIcon.right
            anchors.leftMargin: 10
            anchors.right: rowDetail.left
            anchors.rightMargin: 12
            anchors.verticalCenter: rowIcon.verticalCenter
            textFormat: Text.PlainText
            text: parent.modelData.title
            elide: Text.ElideRight
            color: parent.selected ? "#ffffff" : Commons.Color.foreground
            font.family: "Adwaita Sans"
            font.pixelSize: 15
          }

          MouseArea {
            anchors.bottom: parent.bottom
            width: parent.width
            height: root.rowHeight
            hoverEnabled: true
            onEntered: root.selectedIndex = parent.index
            onClicked: root.run(parent.modelData)
          }
        }
      }

      Rectangle {
        visible: card.expanded
        x: resultList.x + resultList.width
        y: root.searchHeight + 1
        width: 1
        height: resultList.height + 11
        color: Qt.rgba(1, 1, 1, 0.14)
      }

      Item {
        id: previewPane
        visible: card.expanded
        readonly property var info: root.selectedRow && root.selectedRow.preview ? root.selectedRow.preview : ({})
        readonly property bool isImage: root.selectedRow !== null && root.selectedRow.kind === "file" && /\.(png|jpe?g|gif|webp|bmp)$/i.test(root.selectedRow.path)
        readonly property string fileText: root.selectedInfo ? root.selectedInfo.text.trim() : ""
        x: resultList.x + resultList.width + 1
        y: root.searchHeight + 1
        width: root.previewWidth - 8
        height: resultList.height + 11
        clip: true

        Column {
          x: 16
          y: 14
          width: parent.width - 32
          spacing: 8

          // Only ever a local file, so loading it off the main thread is safe.
          Image {
            visible: previewPane.isImage
            width: parent.width
            height: visible ? 170 : 0
            source: previewPane.isImage ? "file://" + root.selectedRow.path : ""
            sourceSize: Qt.size(560, 340)
            fillMode: Image.PreserveAspectFit
            asynchronous: true
          }

          Image {
            visible: !previewPane.isImage && !previewPane.info.big && root.selectedRow !== null
            anchors.horizontalCenter: parent.horizontalCenter
            width: visible ? 76 : 0
            height: width
            source: root.selectedRow ? root.selectedRow.icon : ""
            sourceSize: Qt.size(128, 128)
            fillMode: Image.PreserveAspectFit
            smooth: true
            mipmap: true
          }

          Text {
            visible: !!previewPane.info.big
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            textFormat: Text.PlainText
            topPadding: 30
            text: previewPane.info.big || ""
            color: Commons.Color.foreground
            font.family: "Adwaita Sans"
            font.pixelSize: 34
            font.weight: Font.Light
          }

          Text {
            visible: text !== ""
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            maximumLineCount: 3
            elide: Text.ElideRight
            textFormat: Text.PlainText
            text: previewPane.info.heading || ""
            color: Commons.Color.foreground
            font.family: "Adwaita Sans"
            font.pixelSize: 15
            font.weight: Font.DemiBold
          }

          Text {
            visible: text !== ""
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight
            textFormat: Text.PlainText
            text: previewPane.info.subtitle || ""
            color: Commons.Color.foreground
            opacity: 0.6
            font.family: "Adwaita Sans"
            font.pixelSize: 12
          }

          Text {
            visible: text !== ""
            width: parent.width
            wrapMode: Text.Wrap
            textFormat: Text.PlainText
            text: previewPane.info.body || previewPane.fileText
            color: Commons.Color.foreground
            opacity: 0.8
            font.family: previewPane.fileText !== "" && !previewPane.info.body ? "JetBrainsMono Nerd Font" : "Adwaita Sans"
            font.pixelSize: previewPane.fileText !== "" && !previewPane.info.body ? 10 : 12
            maximumLineCount: previewPane.fileText !== "" && !previewPane.info.body ? 10 : 14
            elide: Text.ElideRight
          }

          Repeater {
            model: root.previewMeta
            Item {
              required property var modelData
              width: previewPane.width - 32
              height: Math.max(metaValue.implicitHeight, 16)
              Text {
                id: metaKey
                width: 72
                textFormat: Text.PlainText
                text: parent.modelData[0]
                horizontalAlignment: Text.AlignRight
                color: Commons.Color.foreground
                opacity: 0.55
                font.family: "Adwaita Sans"
                font.pixelSize: 11
              }
              Text {
                id: metaValue
                anchors.left: metaKey.right
                anchors.leftMargin: 8
                anchors.right: parent.right
                textFormat: Text.PlainText
                text: parent.modelData[1]
                wrapMode: Text.WrapAnywhere
                maximumLineCount: 3
                elide: Text.ElideMiddle
                color: Commons.Color.foreground
                font.family: "Adwaita Sans"
                font.pixelSize: 11
              }
            }
          }
        }
      }

      Rectangle {
        visible: card.expanded
        y: card.height - root.hintHeight
        x: 1
        width: parent.width - 2
        height: 1
        color: Qt.rgba(1, 1, 1, 0.14)
      }

      Text {
        visible: card.expanded
        y: card.height - root.hintHeight
        x: 16
        height: root.hintHeight
        verticalAlignment: Text.AlignVCenter
        textFormat: Text.PlainText
        text: root.hintText
        color: Commons.Color.foreground
        opacity: 0.6
        font.family: "Adwaita Sans"
        font.pixelSize: 11
      }
    }
  }
}
