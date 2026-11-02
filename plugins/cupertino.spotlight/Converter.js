.pragma library

// Every unit is a factor to its category's base unit. Temperature is handled separately.
var CATEGORIES = {
  length: { m: 1, km: 1000, cm: 0.01, mm: 0.001, um: 1e-6, nm: 1e-9, mi: 1609.344, yd: 0.9144, ft: 0.3048, in: 0.0254, nmi: 1852 },
  mass: { kg: 1, g: 0.001, mg: 1e-6, t: 1000, lb: 0.45359237, oz: 0.028349523125, st: 6.35029318 },
  volume: { l: 1, ml: 0.001, cl: 0.01, dl: 0.1, m3: 1000, gal: 3.785411784, qt: 0.946352946, pt: 0.473176473, cup: 0.2365882365, floz: 0.0295735295, tbsp: 0.01478676, tsp: 0.00492892 },
  area: { m2: 1, km2: 1e6, cm2: 1e-4, ft2: 0.09290304, in2: 0.00064516, mi2: 2589988.110336, ha: 10000, acre: 4046.8564224 },
  time: { s: 1, ms: 0.001, min: 60, h: 3600, day: 86400, week: 604800, month: 2629746, year: 31556952 },
  speed: { "m/s": 1, "km/h": 0.277777777778, mph: 0.44704, kn: 0.514444444444 },
  data: { b: 1, kb: 1000, mb: 1e6, gb: 1e9, tb: 1e12, pb: 1e15, kib: 1024, mib: 1048576, gib: 1073741824, tib: 1099511627776 },
  energy: { j: 1, kj: 1000, cal: 4.184, kcal: 4184, wh: 3600, kwh: 3600000 },
  pressure: { pa: 1, kpa: 1000, bar: 100000, psi: 6894.757, atm: 101325 },
  temperature: { c: 1, f: 1, k: 1 }
}

var ALIASES = {
  meter: "m", meters: "m", metre: "m", metres: "m", kilometer: "km", kilometers: "km", kilometre: "km", kilometres: "km",
  centimeter: "cm", centimeters: "cm", centimetre: "cm", centimetres: "cm", millimeter: "mm", millimeters: "mm", mile: "mi", miles: "mi",
  yard: "yd", yards: "yd", foot: "ft", feet: "ft", inch: "in", inches: "in",
  kilo: "kg", kilos: "kg", kilogram: "kg", kilograms: "kg", gram: "g", grams: "g", tonne: "t", tonnes: "t",
  pound: "lb", pounds: "lb", lbs: "lb", ounce: "oz", ounces: "oz", stone: "st",
  liter: "l", liters: "l", litre: "l", litres: "l", milliliter: "ml", milliliters: "ml", gallon: "gal", gallons: "gal", quart: "qt", quarts: "qt", pint: "pt", pints: "pt", cups: "cup",
  sec: "s", secs: "s", second: "s", seconds: "s", mins: "min", minute: "min", minutes: "min", hr: "h", hrs: "h", hour: "h", hours: "h",
  days: "day", weeks: "week", months: "month", years: "year",
  kph: "km/h", kmh: "km/h", mps: "m/s", knot: "kn", knots: "kn",
  byte: "b", bytes: "b", kilobyte: "kb", kilobytes: "kb", megabyte: "mb", megabytes: "mb", gigabyte: "gb", gigabytes: "gb", terabyte: "tb", terabytes: "tb",
  joule: "j", joules: "j", calorie: "cal", calories: "cal",
  acres: "acre", hectare: "ha", hectares: "ha",
  celsius: "c", "°c": "c", fahrenheit: "f", "°f": "f", kelvin: "k"
}

// What a unit converts to when no target is typed, as in "10 km".
var DEFAULT_TARGET = {
  km: "mi", mi: "km", m: "ft", ft: "m", cm: "in", in: "cm", kg: "lb", lb: "kg", g: "oz", oz: "g",
  l: "gal", gal: "l", c: "f", f: "c", gb: "mb", mb: "kb", tb: "gb", kwh: "kj", "km/h": "mph", mph: "km/h", psi: "bar", bar: "psi", ha: "acre", acre: "ha"
}

var CURRENCIES = {
  usd: "USD", dollar: "USD", dollars: "USD", eur: "EUR", euro: "EUR", euros: "EUR", gbp: "GBP", pound_sterling: "GBP", sterling: "GBP",
  ron: "RON", lei: "RON", leu: "RON", jpy: "JPY", yen: "JPY", chf: "CHF", francs: "CHF", cad: "CAD", aud: "AUD", nzd: "NZD",
  sek: "SEK", nok: "NOK", dkk: "DKK", pln: "PLN", czk: "CZK", huf: "HUF", bgn: "BGN", try: "TRY", cny: "CNY", yuan: "CNY",
  inr: "INR", rupees: "INR", brl: "BRL", mxn: "MXN", krw: "KRW", sgd: "SGD", hkd: "HKD", ils: "ILS", thb: "THB", zar: "ZAR"
}

var PATTERN = /^(-?[\d][\d,]*\.?\d*|\.\d+)\s*([a-zA-Z°µ/0-9²³]+)(?:\s+(?:to|in|as|=)\s+([a-zA-Z°µ/0-9²³]+))?$/

function normalize(unit) {
  var value = unit.toLowerCase().replace(/²/g, "2").replace(/³/g, "3").replace(/µ/g, "u")
  return ALIASES.hasOwnProperty(value) ? ALIASES[value] : value
}

function categoryOf(unit) {
  for (var name in CATEGORIES) {
    if (CATEGORIES[name].hasOwnProperty(unit)) return name
  }
  return ""
}

function toCelsius(value, unit) {
  return unit === "c" ? value : unit === "f" ? (value - 32) * 5 / 9 : value - 273.15
}

function fromCelsius(value, unit) {
  return unit === "c" ? value : unit === "f" ? value * 9 / 5 + 32 : value + 273.15
}

function format(value) {
  return Number(value.toPrecision(8)).toLocaleString(Qt.locale("en_US"), "f", 6).replace(/\.?0+$/, "")
}

function plain(value) {
  return String(Number(value.toPrecision(10)))
}

function display(unit) {
  if (unit === "c") return "°C"
  if (unit === "f") return "°F"
  if (unit === "k") return "K"
  var special = { b: "B", kb: "KB", mb: "MB", gb: "GB", tb: "TB", pb: "PB", kib: "KiB", mib: "MiB", gib: "GiB", tib: "TiB", l: "L", ml: "mL", cl: "cL", dl: "dL", j: "J", kj: "kJ", wh: "Wh", kwh: "kWh", pa: "Pa", kpa: "kPa", psi: "psi", m2: "m²", km2: "km²", cm2: "cm²", ft2: "ft²", in2: "in²", mi2: "mi²", m3: "m³", um: "µm" }
  return special.hasOwnProperty(unit) ? special[unit] : unit
}

// Returns { value, text, expression } or null. Currencies are answered by currency().
function convert(text) {
  var match = String(text).trim().match(PATTERN)
  if (!match) return null
  var amount = Number(match[1].replace(/,/g, ""))
  var from = normalize(match[2])
  var category = categoryOf(from)
  if (category === "" || isNaN(amount)) return null
  var to = match[3] ? normalize(match[3]) : DEFAULT_TARGET[from]
  if (!to || categoryOf(to) !== category || to === from) return null

  var result = category === "temperature"
    ? fromCelsius(toCelsius(amount, from), to)
    : amount * CATEGORIES[category][from] / CATEGORIES[category][to]
  return {
    value: plain(result),
    text: format(result) + " " + display(to),
    expression: format(amount) + " " + display(from)
  }
}

// Returns { amount, from, to } when the text asks for a currency conversion.
function currency(text) {
  var match = String(text).trim().match(/^(-?[\d][\d,]*\.?\d*)\s*([a-zA-Z_]+)\s+(?:to|in|as|=)\s+([a-zA-Z_]+)$/)
  if (!match) return null
  var fromKey = match[2].toLowerCase()
  var toKey = match[3].toLowerCase()
  if (!CURRENCIES.hasOwnProperty(fromKey) || !CURRENCIES.hasOwnProperty(toKey)) return null
  var from = CURRENCIES[fromKey]
  var to = CURRENCIES[toKey]
  if (from === to) return null
  return { amount: Number(match[1].replace(/,/g, "")), from: from, to: to }
}
