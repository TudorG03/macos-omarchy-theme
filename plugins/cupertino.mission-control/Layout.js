.pragma library

// Packs windows into rows at the largest scale that fits, keeping their order and aspect ratios.
function arrange(sizes, areaWidth, areaHeight, gap, maxScale) {
  if (sizes.length === 0) return []

  var best = null
  for (var rowCount = 1; rowCount <= sizes.length; rowCount++) {
    var rows = split(sizes, rowCount)
    var widest = 0
    var totalHeight = gap * (rows.length - 1)
    rows.forEach(function(row) {
      var width = gap * (row.length - 1)
      var height = 0
      row.forEach(function(index) {
        width += sizes[index].width
        height = Math.max(height, sizes[index].height)
      })
      widest = Math.max(widest, width)
      totalHeight += height
    })

    // Gaps stay a fixed size, so only the windows themselves shrink.
    var horizontal = areaWidth / widest
    var vertical = areaHeight / totalHeight
    var scale = Math.min(maxScale, horizontal, vertical)
    if (!best || scale > best.scale + 0.001) best = { scale: scale, rows: rows }
  }

  var rects = new Array(sizes.length)
  var rowHeights = best.rows.map(function(row) {
    return Math.max.apply(null, row.map(function(index) { return sizes[index].height * best.scale }))
  })
  var usedHeight = rowHeights.reduce(function(sum, height) { return sum + height }, 0) + gap * (best.rows.length - 1)
  var y = (areaHeight - usedHeight) / 2

  best.rows.forEach(function(row, rowIndex) {
    var usedWidth = row.reduce(function(sum, index) { return sum + sizes[index].width * best.scale }, 0) + gap * (row.length - 1)
    var x = (areaWidth - usedWidth) / 2
    row.forEach(function(index) {
      var width = sizes[index].width * best.scale
      var height = sizes[index].height * best.scale
      rects[index] = { x: x, y: y + (rowHeights[rowIndex] - height) / 2, width: width, height: height }
      x += width + gap
    })
    y += rowHeights[rowIndex] + gap
  })
  return rects
}

function split(sizes, rowCount) {
  var total = sizes.reduce(function(sum, size) { return sum + size.width }, 0)
  var target = total / rowCount
  var rows = [[]]
  var width = 0
  sizes.forEach(function(size, index) {
    var remainingRows = rowCount - rows.length
    if (rows[rows.length - 1].length > 0 && remainingRows > 0 && width + size.width / 2 > target) {
      rows.push([])
      width = 0
    }
    rows[rows.length - 1].push(index)
    width += size.width
  })
  return rows
}
