class KeyboardControls
  thrust: false
  left: false
  right: false
  keyup: (e) =>
    switch e.keyCode
      when 37 # left
        @left = false
      when 39 # right
        @right = false
      when 38 # up
        @up = false
  keydown: (e) =>
    switch e.keyCode
      when 37 # left
        @left = true
      when 39 # right
        @right = true
      when 38 # up
        @up = true

Utils =
  drawStats: () ->
    stats = new Stats()
    stats.setMode(0) # 0: fps, 1: ms
    stats.domElement.style.position = 'absolute'
    stats.domElement.style.right = '0px'
    stats.domElement.style.top = '0px'
    document.body.appendChild( stats.domElement )
    stats

  drawWrapped: (ctx, [xEdge,yEdge], drawFn) ->
    drawFn()

    if xEdge isnt 0
      ctx.translate xEdge * ctx.width, 0
      drawFn()
      ctx.translate -xEdge * ctx.width, 0

    if yEdge isnt 0
      ctx.translate 0, yEdge * ctx.height
      drawFn()
      ctx.translate 0, -yEdge * ctx.height

  axisAlignedBoundingBox: (points) ->
    maxX = @maxOnAxis points, 0
    maxY = @maxOnAxis points, 1
    minX = @minOnAxis points, 0
    minY = @minOnAxis points, 1
    [minX, maxX, minY, maxY]

  maxOnAxis: (points, axisIndex) ->
    Math.max (p[axisIndex] for p in points)...

  minOnAxis: (points, axisIndex) ->
    Math.min (p[axisIndex] for p in points)...

  pairs: (items) ->
    _.zip items, items[1..].concat([items[0]])

  # test from:
  # http://compgeom.cs.uiuc.edu/~jeffe/teaching/373/notes/x05-convexhull.pdf
  # http://compgeom.cs.uiuc.edu/~jeffe/teaching/373/notes/x06-sweepline.pdf
  # a, b, c, d are points describing two line segments.
  linesIntersect: ([a,b], [c,d]) ->
    @counterClockwise(a, c, d) != @counterClockwise(b, c, d) &&
      @counterClockwise(a, b, c) != @counterClockwise(a, b, d)

  # Check if the vectors from a->b and a->c are counterclockwise, that is, the
  # magnitude of their cross product is >= 0. A magnitude of 0 indicates the
  # vectors are collinear. Since this is used for hit testing, this means a
  # check on a polygon boundary is a hit.
  counterClockwise: ( a, b, c ) ->
    from = Vec.sub(b,a)
    to = Vec.sub(c,a)
    mag = @crossProductMagnitude( from, to ) > 0

  crossProductMagnitude: ( [x1, y1], [x2, y2] ) -> x1 * y2 - y1 * x2

  # project each point on to the given axis, returns a min/max interval
  projectionInterval: (points, axis) ->
    values = (Vec.dotProduct point, axis for point in points)
    [Math.min(values...), Math.max(values...)]

  intervalsOverlap: ([aMin, aMax], [bMin, bMax]) ->
    return aMin <= bMax and bMin <= aMax

class Grid
  constructor: (@size, @color) ->
  draw: (ctx) =>
    ctx.strokeStyle = @color

    for x in [1..(ctx.width / @size)]
      ctx.beginPath()
      ctx.moveTo x * @size, 0
      ctx.lineTo x * @size, ctx.height
      ctx.stroke()

    for y in [1..(ctx.height / @size)]
      ctx.beginPath()
      ctx.moveTo 0, y * @size
      ctx.lineTo ctx.width, y * @size
      ctx.stroke()


window.KeyboardControls = KeyboardControls
window.Utils = Utils
window.Grid = Grid
