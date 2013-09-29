window.physics = ->
  window.stats = Utils.drawStats()
  window.ctx = Sketch.create
    element: document.getElementById "physics"
    # retina: true
  window.grid = new Grid 100, "#056"
  controls = new KeyboardControls

  # dot = new Particle [100, ctx.height - 100]
  window.rect = new Rectangle 200, 100, [120, 80], 0, "#F00"
  rect2 = new Rectangle 200, 100, [0, 0], 0, "#00F"

  _.extend ctx,
    update: ->
      rect.reset()
      rect.update ctx.dt / 1000, controls
    draw: ->
      grid.draw ctx
      rect.draw ctx
      rect2.draw ctx
      rect.drawDebug ctx
      stats.update()
    clear: ->
      ctx.clearRect -ctx.width/2, -ctx.height/2, ctx.width, ctx.height
    keyup: (e) ->
      if e.keyCode is 32 # space
        rect.resetDebug()
        rect.contactPoints(rect2)
      controls.keyup e
    keydown: controls.keydown

  # | a c e |    |  1  0  0 |
  # | b d f | => |  0 -1  0 |
  # | 0 0 1 |    |  0  0  1 |
  ctx.setTransform 1, 0, 0, -1, 0, 0 # flip y axis so it goes up (and z goes out)
  ctx.translate ctx.width/2, -ctx.height/2 # center the origin

class Edge
  constructor: (@vertex, @from, @to) ->
    @vec = Vec.sub @to, @from
  dot: (other) ->
    Vec.dotProduct @vec, other
  normalize: ->
    @vec = Vec.normalize @vec
  invert: ->
    @vec = Vec.invert @vec

class Polygon
  debug: {}
  resetDebug: -> @debug = {}
  drawDebug: (ctx) ->
    if ref = @debug.reference
      Utils.debugLine ctx, ref.from, ref.to, "#0F0"
    if inc = @debug.incident
      Utils.debugLine ctx, inc.from, inc.to, "#FF0"
    if clipped = @debug.clipped
      Utils.debugLine ctx, clipped[0], clipped[1], "#0FF"
    if trimmed = @debug.trimmed
      Utils.debugPoints ctx, "#000", trimmed...

  # Calculate contact points against another polygon.
  # from http://www.codezealot.org/archives/394 &c
  contactPoints: (other) ->
    minAxis = @minimumSeparationAxis other
    console.log "found minimum separation axis of #{minAxis}"
    return [] unless minAxis

    e1 = @bestEdge minAxis
    e2 = other.bestEdge Vec.invert minAxis # A->B always

    # Now, clip the edges. Do a series of line/plane clips to get the contact
    # manifold. Identify the reference edge and incident edge. Reference is most
    # perpendicular to contact axis, and will be used to clip the incident edge
    # vertices to generate the manifold.

    if e1.dot(minAxis) <= e2.dot(minAxis)
      reference = e1
      incident  = e2
      flipped   = false
    else
      reference = e2
      incident  = e1
      flipped   = true

    @debug.reference = reference
    @debug.incident = incident

    console.log "reference: #{reference.vertex} #{reference.from} -> #{reference.to} (vec #{reference.vec})"
    console.log "incident: #{incident.vertex} #{incident.from} -> #{incident.to} (vec #{incident.vec})"
    console.log "flipped", flipped

    reference.normalize()

    offset1 = reference.dot reference.from
    # clip the incident edge by the first vertex of the reference edge
    first = @clip incident.from, incident.to, reference, offset1
    return [] if first.length < 2 # if we don't have 2 points left, then fail
    console.log "first", first[0], first[1]
    @debug.first = first

    # clip what's left of the incident edge by second vertex of reference edge
    # clipping in opposite direction, so flip direction and offset
    o2 = reference.dot reference.to
    reference.invert()
    clipped = @clip first[0], first[1], reference, -o2
    return [] if clipped.length < 2
    reference.invert() # put it back (FIXME: stop using objects here)

    console.log "clipped", clipped[0], clipped[1]
    @debug.clipped = clipped

    # get the reference edge normal
    refNorm = Vec.perpendicular reference.vec

    # if incident/reference were flipped, then flip the normal to clip properly
    refNorm = Vec.invert refNorm if flipped

    # get the largest depth
    max = Vec.dotProduct refNorm, reference.vertex

    # make sure the final points are not past this maximum
    if Vec.dotProduct(refNorm, clipped[0]) - max < 0
      clipped[0] = null
    if Vec.dotProduct(refNorm, clipped[1]) - max < 0
      clipped[1] = null

    trimmed = (entry for entry in clipped when entry)

    console.log "trimmed", trimmed[0], trimmed[1]
    @debug.trimmed = trimmed

    trimmed

  # clip the line segment from v1 to v2 if they are beyond offset along normal
  clip: (v1, v2, normal, offset) ->
    console.log "clipping #{v1} -> #{v2} against #{normal.vec} with #{offset}"
    points = []
    d1 = normal.dot(v1) - offset
    d2 = normal.dot(v2) - offset
    console.log "d1 #{d1}, d2 #{d2}"
    points.push v1 if d1 >= 0
    points.push v2 if d2 >= 0

    # check if they are on opposing sides of the offset
    if d1 * d2 < 0
      # different sides, figure out which one we're clipping, and clip it
      e = Vec.sub v2, v1
      u = d1 / (d1 - d2)
      e = Vec.scale e, u
      e = Vec.add e, v1
      points.push e

    points

  # Calculate the best edge (closest perpendicular edge given a separation axis)
  bestEdge: (minAxis) ->
    points = @points()

    # Find farthest vertex in the polygon along separation axis
    closestIndex = null
    maxProjection = -Infinity
    for vertex, i in points
      projection = Vec.dotProduct minAxis, vertex
      if projection > maxProjection
        maxProjection = projection
        closestIndex = i

    # Find edge which is most perpendicular to separation axis
    closest    = points[closestIndex]
    prevVertex = points[ (closestIndex - 1 + points.length) % points.length ]
    nextVertex = points[ (closestIndex + 1 + points.length) % points.length ]

    left = Vec.sub closest, prevVertex
    right = Vec.sub closest, nextVertex
    if Vec.dotProduct(right, minAxis) <= Vec.dotProduct(left, minAxis)
      new Edge closest, closest, nextVertex # right edge is better
    else
      new Edge closest, prevVertex, closest # left edge is better

  # Use Separating Axis Theorem to find minimum separation axis
  # from http://www.codezealot.org/archives/55 &c.
  minimumSeparationAxis: (other) ->
    minAxis    = null
    minOverlap = Infinity

    for axis in @perpendicularAxes()
      us = @projectionInterval axis
      them = other.projectionInterval axis
      overlap = Utils.intervalOverlap us, them
      return false unless overlap > 0
      if overlap < minOverlap
        minOverlap = overlap
        minAxis = axis

    for axis in other.perpendicularAxes()
      us = @projectionInterval axis
      them = other.projectionInterval axis
      overlap = Utils.intervalOverlap us, them
      return false unless overlap > 0
      if overlap < minOverlap
        minOverlap = overlap
        minAxis = Vec.invert axis # separation axis is always A->B

    minAxis

  projectionInterval: (axis) ->
    Utils.projectionInterval @points(), axis

  perpendicularAxes: ->
    for pair in Utils.pairs @points()
      Vec.perpendicular Vec.sub pair[1], pair[0]

class Rectangle extends Polygon
  constructor: (sizeX, sizeY, position, angle, @color) ->
    @position = position
    @orientation = Rotation.fromAngle angle
    @offsets = [[ sizeX/2,  sizeY/2],
               [-sizeX/2,  sizeY/2],
               [-sizeX/2, -sizeY/2],
               [ sizeX/2, -sizeY/2]]
  reset: ->
    # TODO only reset if position/velocity/orientation have changed
    @cachedPoints = null

  points: () ->
    @cachedPoints ?= (Vec.transform offset, @position, @orientation for offset in @offsets)

  update: (dt, keyboard) ->
    dx = dy = rot = 0

    if keyboard.shift
      rot = 1 if keyboard.left
      rot = -1 if keyboard.right
    else
      dx = -1 if keyboard.left
      dx = 1 if keyboard.right

    dy = 1 if keyboard.up
    dy = -1 if keyboard.down

    if dx isnt 0 or dy isnt 0
      @position = Vec.add @position, Vec.scale [dx, dy], 200*dt
    if rot isnt 0
      @orientation = Rotation.addAngle @orientation, Math.PI*dt*rot

  draw: (ctx) ->
    points = @points()
    ctx.save()

    ctx.beginPath()
    ctx.moveTo points[0]...
    for point in points[1..]
      ctx.lineTo point...

    ctx.globalAlpha = 0.5
    ctx.fillStyle = @color
    ctx.fill()

    ctx.globalAlpha = 1
    ctx.strokeStyle = @color
    ctx.stroke()

    ctx.restore()

window.Rotation =
  fromAngle: (angle) -> [Math.cos(angle), Math.sin(angle)]
  add: ([a,b],[c,d]) -> [a*c - b*d, a*d + c*b]
  addAngle: (rotation, angle) -> @add rotation, @fromAngle(angle)
  toAngle: (rotation) -> Math.acos rotation[0]
  fromDeg: (deg) -> deg * 2 * Math.PI / 360
  toDeg: (rad) -> rad * 360 / (2 * Math.PI)

