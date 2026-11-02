.pragma library

var ZONES = {
  "new york": "America/New_York", nyc: "America/New_York", boston: "America/New_York", miami: "America/New_York", toronto: "America/Toronto",
  chicago: "America/Chicago", houston: "America/Chicago", dallas: "America/Chicago", denver: "America/Denver",
  "los angeles": "America/Los_Angeles", la: "America/Los_Angeles", "san francisco": "America/Los_Angeles", sf: "America/Los_Angeles", seattle: "America/Los_Angeles", cupertino: "America/Los_Angeles", vancouver: "America/Vancouver",
  "mexico city": "America/Mexico_City", "sao paulo": "America/Sao_Paulo", "buenos aires": "America/Argentina/Buenos_Aires",
  london: "Europe/London", dublin: "Europe/Dublin", lisbon: "Europe/Lisbon", paris: "Europe/Paris", madrid: "Europe/Madrid", barcelona: "Europe/Madrid", rome: "Europe/Rome", milan: "Europe/Rome",
  berlin: "Europe/Berlin", munich: "Europe/Berlin", amsterdam: "Europe/Amsterdam", brussels: "Europe/Brussels", zurich: "Europe/Zurich", vienna: "Europe/Vienna", prague: "Europe/Prague", warsaw: "Europe/Warsaw", budapest: "Europe/Budapest", stockholm: "Europe/Stockholm", oslo: "Europe/Oslo", copenhagen: "Europe/Copenhagen", helsinki: "Europe/Helsinki",
  bucharest: "Europe/Bucharest", sofia: "Europe/Sofia", athens: "Europe/Athens", kyiv: "Europe/Kyiv", chisinau: "Europe/Chisinau", istanbul: "Europe/Istanbul", moscow: "Europe/Moscow",
  dubai: "Asia/Dubai", "tel aviv": "Asia/Jerusalem", jerusalem: "Asia/Jerusalem", riyadh: "Asia/Riyadh", cairo: "Africa/Cairo", johannesburg: "Africa/Johannesburg", lagos: "Africa/Lagos", nairobi: "Africa/Nairobi",
  mumbai: "Asia/Kolkata", delhi: "Asia/Kolkata", bangalore: "Asia/Kolkata", india: "Asia/Kolkata", bangkok: "Asia/Bangkok", singapore: "Asia/Singapore", "hong kong": "Asia/Hong_Kong", shanghai: "Asia/Shanghai", beijing: "Asia/Shanghai", china: "Asia/Shanghai", seoul: "Asia/Seoul", tokyo: "Asia/Tokyo", japan: "Asia/Tokyo",
  sydney: "Australia/Sydney", melbourne: "Australia/Melbourne", perth: "Australia/Perth", auckland: "Pacific/Auckland", honolulu: "Pacific/Honolulu", utc: "UTC", gmt: "UTC"
}

function title(city) {
  if (city === "utc" || city === "gmt" || city === "nyc" || city === "la" || city === "sf") return city.toUpperCase()
  return city.split(" ").map(function(word) { return word.charAt(0).toUpperCase() + word.slice(1) }).join(" ")
}

// Returns { city, zone } for "time in tokyo", "tokyo time" or "time tokyo".
function lookup(text) {
  var match = String(text).trim().toLowerCase().match(/^(?:what\s+)?(?:time\s+(?:is\s+it\s+)?(?:in\s+)?(.+)|(.+)\s+time)$/)
  if (!match) return null
  var city = (match[1] || match[2]).trim()
  return ZONES.hasOwnProperty(city) ? { city: title(city), zone: ZONES[city] } : null
}
