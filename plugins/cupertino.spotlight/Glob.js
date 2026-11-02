.pragma library

// Turns "*.pdf", "report*.doc?", "~/Downloads/*.zip" or "src/**/*.py" into what fd needs. Null if it isn't a pattern.
function parse(text, home) {
  var value = String(text).trim()
  var wild = value.indexOf("*") >= 0 || (value.indexOf("?") >= 0 && !/\s/.test(value) && !/\?$/.test(value))
  if (!wild) return null

  var hidden = value.split("/").some(function(part) { return part.charAt(0) === "." && part !== "." && part !== ".." })
  var path = value.indexOf("~/") === 0 ? home + value.slice(1) : value

  if (path.indexOf("/") < 0) return { pattern: path, base: home, fullPath: false, hidden: hidden }

  var cut = path.lastIndexOf("/")
  var folder = path.slice(0, cut)
  var name = path.slice(cut + 1)
  var folderIsPlain = !/[*?]/.test(folder)

  // An absolute folder without wildcards is simply where to look.
  if (path.charAt(0) === "/" && folderIsPlain) return { pattern: name, base: folder === "" ? "/" : folder, fullPath: false, hidden: hidden }
  if (path.charAt(0) === "/") return { pattern: path, base: home, fullPath: true, hidden: hidden }
  // "src/*.py" can sit anywhere under home.
  return { pattern: path.indexOf("**/") === 0 ? path : "**/" + path, base: home, fullPath: true, hidden: hidden }
}
