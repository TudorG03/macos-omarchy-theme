.pragma library

// Trigger word -> { trigger, name, domain, url }. Ordered by how often people use them.
var table = {}
var list = []

// Without a "!", these alone may take the top spot: every other word is too likely to be a normal search.
var EVERYDAY = {
  yt: 1, rd: 1, r: 1, g: 1, gh: 1, w: 1, wiki: 1, so: 1, ddg: 1, gi: 1, gm: 1, maps: 1, gt: 1, tr: 1, amzn: 1, imdb: 1, npm: 1, mdn: 1, aur: 1, arch: 1,
  tw: 1, x: 1, fb: 1, ig: 1, li: 1, hn: 1, spotify: 1, sp: 1, netflix: 1, twitch: 1, ebay: 1, pypi: 1, crates: 1, wa: 1, ud: 1, gcal: 1, gmail: 1, drive: 1
}

function load(text) {
  var nextTable = {}
  var nextList = []
  text.split("\n").forEach(function(line) {
    var parts = line.split("\t")
    if (parts.length < 4) return
    var bang = { trigger: parts[0], name: parts[1], domain: parts[2], url: parts[3] }
    nextTable[parts[0]] = bang
    nextList.push(bang)
  })
  table = nextTable
  list = nextList
}

function lookup(trigger) {
  return table.hasOwnProperty(trigger) ? table[trigger] : null
}

// Returns { bang, terms, explicit } for "!yt cats", "cats !yt" or a bare "yt cats".
function parse(text) {
  var value = String(text).trim()
  var match = value.match(/^!(\S+)(?:\s+(.*))?$/)
  if (match) {
    var leading = lookup(match[1].toLowerCase())
    return leading ? { bang: leading, terms: match[2] || "", explicit: true } : null
  }
  match = value.match(/^(.*\S)\s+!(\S+)$/)
  if (match) {
    var trailing = lookup(match[2].toLowerCase())
    return trailing ? { bang: trailing, terms: match[1], explicit: true } : null
  }
  match = value.match(/^(\S+)\s+(.*\S)$/)
  if (match) {
    var bare = lookup(match[1].toLowerCase())
    return bare ? { bang: bare, terms: match[2], explicit: false, everyday: EVERYDAY.hasOwnProperty(bare.trigger) } : null
  }
  return null
}

function urlFor(bang, terms) {
  if (terms === "") return homeOf(bang)
  // Sites vary in what they accept, but every one of them takes a percent-encoded query.
  return bang.url.split("{{{s}}}").join(encodeURIComponent(terms))
}

function homeOf(bang) {
  return bang.domain !== "" ? "https://" + bang.domain : bang.url.split("{{{s}}}").join("")
}

// Bangs for a half-typed "!you": exact trigger, then trigger prefix, then name, each most-used first.
function complete(fragment, limit) {
  var needle = String(fragment).toLowerCase()
  var exact = []
  var prefix = []
  var named = []
  for (var i = 0; i < list.length; i++) {
    var bang = list[i]
    if (bang.trigger === needle) exact.push(bang)
    else if (bang.trigger.indexOf(needle) === 0) prefix.push(bang)
    else if (needle.length >= 2 && bang.name.toLowerCase().indexOf(needle) === 0) named.push(bang)
  }
  return exact.concat(named.slice(0, 3), prefix, named.slice(3)).slice(0, limit)
}
