.pragma library

var FUNCTIONS = {
  sqrt: Math.sqrt, abs: Math.abs, round: Math.round, floor: Math.floor, ceil: Math.ceil,
  sin: Math.sin, cos: Math.cos, tan: Math.tan, ln: Math.log, log: Math.log10, exp: Math.exp
}
var CONSTANTS = { pi: Math.PI, e: Math.E }

// Recursive descent, so typed text is never evaluated as code.
function evaluate(text) {
  var input = String(text).toLowerCase().replace(/[\s,]+/g, "").replace(/×/g, "*").replace(/÷/g, "/")
  var ofMatch = input.match(/^([0-9.]+)%of(.+)$/)
  if (ofMatch) input = "(" + ofMatch[1] + "/100)*(" + ofMatch[2] + ")"
  if (!/^[0-9a-z.+\-*/%^()]+$/.test(input)) return null
  // A bare number or word is not a sum.
  if (!/[+\-*/%^(]/.test(input.slice(1))) return null

  var at = 0

  function expression() {
    var value = term()
    while (input[at] === "+" || input[at] === "-") {
      var op = input[at++]
      var right = term()
      value = op === "+" ? value + right : value - right
    }
    return value
  }

  function term() {
    var value = power()
    while (input[at] === "*" || input[at] === "/" || input[at] === "%") {
      var op = input[at++]
      var right = power()
      value = op === "*" ? value * right : op === "/" ? value / right : value % right
    }
    return value
  }

  function power() {
    var base = unary()
    if (input[at] !== "^") return base
    at++
    return Math.pow(base, power())
  }

  function unary() {
    if (input[at] === "-") {
      at++
      return -unary()
    }
    return atom()
  }

  function atom() {
    if (input[at] === "(") {
      at++
      var value = expression()
      if (input[at++] !== ")") throw new Error("unbalanced")
      return value
    }
    var word = input.slice(at).match(/^[a-z]+/)
    if (word) {
      at += word[0].length
      if (CONSTANTS.hasOwnProperty(word[0])) return CONSTANTS[word[0]]
      if (FUNCTIONS.hasOwnProperty(word[0]) && input[at] === "(") return FUNCTIONS[word[0]](atom())
      throw new Error("unknown word")
    }
    var match = input.slice(at).match(/^\d*\.?\d+|^\d+\./)
    if (!match) throw new Error("number expected")
    at += match[0].length
    return Number(match[0])
  }

  try {
    var result = expression()
    if (at !== input.length || !isFinite(result)) return null
    return Number(result.toPrecision(12))
  } catch (error) {
    return null
  }
}
