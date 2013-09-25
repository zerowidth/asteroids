window.KeyboardControls = class KeyboardControls
  up: false
  down: false
  left: false
  right: false
  keyup: (e) =>
    @shift = e.shiftKey
    switch e.keyCode
      when 37 # left
        @left = false
      when 39 # right
        @right = false
      when 38 # up
        @up = false
      when 40 # down
        @down = false

  keydown: (e) =>
    @shift = e.shiftKey
    switch e.keyCode
      when 37 # left
        @left = true
      when 39 # right
        @right = true
      when 38 # up
        @up = true
      when 40 # down
        @down = true

window.Utils = Utils =
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

  # if > 0, intervals overlap.
  intervalOverlap: ([aMin, aMax], [bMin, bMax]) ->
    start = if aMin < bMin then bMin else aMin
    end   = if aMax > bMax then bMax else aMax
    end - start

window.Grid = class Grid
  constructor: (@size, @color) ->
  draw: (ctx) =>
    ctx.strokeStyle = @color

    count = ctx.width/@size
    offset = Math.floor(count/2) * @size
    for n in [0..count]
      x = n * @size - offset
      ctx.beginPath()
      ctx.moveTo x, -ctx.height/2
      ctx.lineTo x, ctx.height/2
      ctx.stroke()

    count = ctx.height/@size
    offset = Math.floor(count/2) * @size
    for n in [0..count]
      y = n * @size - offset
      ctx.beginPath()
      ctx.moveTo -ctx.width/2, y
      ctx.lineTo  ctx.width/2, y
      ctx.stroke()

    ctx.beginPath()
    ctx.arc 0, 0, 5, 0, Math.PI * 2
    ctx.stroke()
    ctx.fill()
