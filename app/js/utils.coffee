window.ShipControls = class ShipControls
  thrust: false
  left: false
  right: false
  targeting: false

window.FireControls = class FireControls
  timeouts:
    default: 0.15
    bfg: 0.5

  fireMain: false
  fireBFG: false
  fireSpread: false

  constructor: ->
    @timers = {}

  update: (dt) ->
    @timers[key] = value - dt for key, value of @timers when value > 0

  fire: (weapon) ->
    if not @timers[weapon]? or @timers[weapon] <= 0
      before = @timers[weapon] or 0 # account for time already served
      @timers[weapon] = (@timeouts[weapon] or @timeouts["default"]) + before
      true
    else
      false

# Mouse/touch controls for mobile:
# top third: fire
# left/right halves of middle third: left/right
# bottom third: thrust
window.TouchControls = class TouchControls
  constructor: (@width, @height, @scale) ->
    @regions =
      top: false
      left: false
      right: false
      bottom: false

  touchStart: (touch) ->
    @set @mapRegion(touch), true

  touchEnd: (touch) ->
    if touch
      @set @mapRegion(touch), false
    else
      @set key, false for key of @regions

  set: (key, value) ->
    @regions[key] = value

  mapRegion: (touch) ->
    x = touch.ox / @scale
    y = @height - touch.oy / @scale
    if y > 2 * @height / 3
      "top"
    else if y > @height / 3
      if x < @width / 2
        "left"
      else
        "right"
    else
      "bottom"

window.Utils = Utils =
  drawStats: ->
    stats = new Stats()
    stats.setMode(0) # 0: fps, 1: ms
    stats.domElement.style.position = 'absolute'
    stats.domElement.style.left = '0px'
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

  # Return sequential pairs in a sequence: [1, 2, 3] --> [1,2], [2,3], [3,1]
  sequentialPairs: (items) ->
    return [] if items.length < 2
    pairs = []
    for i in [0..(items.length-2)]
      pairs.push [items[i], items[i+1]]
    pairs.push [items[items.length-1], items[0]]
    pairs

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
    min = Infinity
    max = -Infinity

    for point in points
      value = Vec.dotProduct point, axis
      min = value if value < min
      max = value if value > max
    [min, max]

  aabbOverlap: (aAABB, bAABB, offset=[0,0]) ->
    [[ax1, ay1], [ax2, ay2]] = aAABB
    [[bx1, by1], [bx2, by2]] = bAABB
    [xOffset, yOffset] = offset
    ax1 += xOffset
    ax2 += xOffset
    ay1 += yOffset
    ay2 += yOffset

    @intervalOverlap([ax1, ax2], [bx1, bx2]) > 0 and
      @intervalOverlap([ay1, ay2], [by1, by2]) > 0

  # if > 0, intervals overlap.
  intervalOverlap: ([aMin, aMax], [bMin, bMax]) ->
    start = if aMin < bMin then bMin else aMin
    end   = if aMax > bMax then bMax else aMax
    end - start

  m_w: Math.floor(Math.random() * 10000000) # 123456789
  m_z: 987654321

  srand: (seed) ->
    @m_w = seed
    @m_z = 987654321

  # PRNG from stackoverflow, adapted from wikipedia O_o
  random: (max = 1) ->
    mask = 0xffffffff
    @m_z = (36969 * (@m_z & 65535) + (@m_z >> 16)) & mask
    @m_w = (18000 * (@m_w & 65535) + (@m_w >> 16)) & mask
    result = ((@m_z << 16) + @m_w) & mask
    result /= 4294967296
    max * (result + 0.5)

  # To enable unseeded randomness again:
  # random: Math.random

  randomInt: (min, max) ->
    min + Math.floor(@random() * (max - min))

  # Use Mitchell's best-candidate method for distributing points randomly:
  distributeRandomPoints: ([xmin, ymin], [xmax, ymax], radius, list = null) ->
    # keep generated points away from the edges
    xmin += radius/2
    xmax -= radius/2
    ymin += radius/2
    ymax -= radius/2

    # a guess as to how many to try and generate: grid of size r, so:
    n = Math.ceil (xmax - xmin) * (ymax - ymin) / (radius * radius)

    k = 5 # how many candidates to examine

    list ?= [@randomPoint(xmin, xmax, ymin, ymax)]

    for iteration in [0...n]
      candidates = for _ in [0...k]
        @randomPoint xmin, xmax, ymin, ymax

      farthestDistance = 0
      farthest = null

      # Find the candidate from a list of potential candidates with the largest
      # minimum distance from all existing points.
      for candidate, ci in candidates
        minDistance = Infinity

        for existing in list
          distance = Vec.magnitude(Vec.sub existing, candidate)
          if distance < minDistance
            minDistance = distance

        if minDistance > 2 * radius and minDistance > farthestDistance
          farthestDistance = minDistance
          farthest = candidate

      list.push farthest if farthest

    list

  randomPoint: (xmin, xmax, ymin, ymax) ->
    x = xmin + Utils.random(xmax - xmin)
    y = ymin + Utils.random(ymax - ymin)
    [x, y]


  debugLine: (display, from, to, color, dotSize = 3) ->
    display.drawLine from, to, 2, color
    display.drawCircle from, dotSize, color
    display.drawCircle to, dotSize, color

  debugAABB: (display, aabb, color, alpha=0.5) ->
    [[x1, y1], [x2, y2]] = aabb
    display.drawLine [x1, y1], [x2, y1], 1, color, alpha
    display.drawLine [x2, y1], [x2, y2], 1, color, alpha
    display.drawLine [x2, y2], [x1, y2], 1, color, alpha
    display.drawLine [x1, y2], [x1, y1], 1, color, alpha

  debugContact: (display, contact, color="#0F0") ->
    display.drawCircle contact.position, 3, color
    endpoint = Vec.add contact.position, Vec.scale contact.normal, contact.depth
    display.drawLine contact.position, endpoint, 1, color

window.Rotation = Rotation =
  fromAngle: (angle) -> [Math.cos(angle), Math.sin(angle)]
  add: ([a,b],[c,d]) -> [a*c - b*d, a*d + c*b]
  addAngle: (rotation, angle) -> @add rotation, @fromAngle(angle)
  toAngle: (rotation) -> Math.acos rotation[0]
  fromDeg: (deg) -> deg * 2 * Math.PI / 360
  toDeg: (rad) -> rad * 360 / (2 * Math.PI)

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
