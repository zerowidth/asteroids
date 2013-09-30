window.physics = ->
  window.stats = Utils.drawStats()
  window.ctx = Sketch.create
    element: document.getElementById "physics"
    # retina: true
  window.grid = new Grid 100, "#056"
  controls = new KeyboardControls

  # dot = new Particle [100, ctx.height - 100]
  window.rect = new Rectangle 200, 200, [100, 80], 0.3, "#F00"
  rect2 = new Rectangle 120, 100, [0, 0], 0, "#00F"

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
  constructor: (@deepest, @from, @to) ->
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
      Utils.debugLine ctx, ref.from, ref.to, "#F66"
    if inc = @debug.incident
      Utils.debugLine ctx, inc.from, inc.to, "#66F"
    if clipped = @debug.clipped
      Utils.debugLine ctx, clipped[0], clipped[1], "#FF0"
    if contacts = @debug.contacts
      for contact in contacts
        Utils.debugContact ctx, contact, "#0F0"

  # Calculate contact points against another polygon.
  # from http://www.codezealot.org/archives/394 &c
  contactPoints: (other) ->
    minAxis = @minimumSeparationAxis other
    return [] unless minAxis

    e1 = @bestEdge minAxis
    e2 = other.bestEdge Vec.invert minAxis # A->B always

    # Now, clip the edges. The reference edge is most perpendicular to contact
    # axis, and will be used to clip the incident edge vertices to generate the
    # contact points.
    if Math.abs(e1.dot(minAxis)) <= Math.abs(e2.dot(minAxis))
      reference = e1
      incident  = e2
    else
      reference = e2
      incident  = e1

    @debug.reference = reference
    @debug.incident = incident

    reference.normalize()

    offset1 = reference.dot reference.from
    # clip the incident edge by the first vertex of the reference edge
    first = @clip incident.from, incident.to, reference, offset1
    return [] if first.length < 2 # if we don't have 2 points left, then fail
    @debug.first = first

    # clip what's left of the incident edge by second vertex of reference edge
    # clipping in opposite direction, so flip direction and offset
    o2 = reference.dot reference.to
    reference.invert()
    clipped = @clip first[0], first[1], reference, -o2
    return [] if clipped.length < 2
    reference.invert() # put it back (FIXME: stop using objects here)

    @debug.clipped = clipped

    # get the reference edge normal
    refNorm = Vec.perpendicular reference.vec

    # find the largest depth
    maxDepth = Vec.dotProduct refNorm, reference.deepest
    contacts = []

    # Calculate depth for each clipped point and return only those which are
    # nonzero (that is, aren't on the other side of the reference edge)
    for point in clipped
      depth = Vec.dotProduct(refNorm, point) - maxDepth
      if depth >= 0
        contacts.push new Contact(point, minAxis, depth)

    @debug.contacts = contacts

    contacts

  # clip the line segment from v1 to v2 if they are beyond offset along normal
  clip: (v1, v2, normal, offset) ->
    points = []
    d1 = normal.dot(v1) - offset
    d2 = normal.dot(v2) - offset
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

  # Calculate the best edge (deepest perpendicular edge given a separation axis)
  bestEdge: (minAxis) ->
    points = @points()

    # Find deepest vertex in the polygon along separation axis
    deepestIndex = null
    maxProjection = -Infinity
    for vertex, i in points
      projection = Vec.dotProduct minAxis, vertex
      if projection > maxProjection
        maxProjection = projection
        deepestIndex = i

    # Find edge which is most perpendicular to separation axis
    deepest    = points[ deepestIndex ]
    prevVertex = points[ (deepestIndex - 1 + points.length) % points.length ]
    nextVertex = points[ (deepestIndex + 1 + points.length) % points.length ]

    # vectors pointing at the deepest vertex
    left  = Vec.sub deepest, prevVertex
    right = Vec.sub deepest, nextVertex

    if Vec.dotProduct(right, minAxis) <= Vec.dotProduct(left, minAxis)
      new Edge deepest, deepest, nextVertex # right edge is better
    else
      new Edge deepest, prevVertex, deepest # left edge is better

  # Use Separating Axis Theorem to find minimum separation axis
  # from http://www.codezealot.org/archives/55 &c.
  minimumSeparationAxis: (other) ->
    minAxis    = null
    minOverlap = Infinity

    for axis in @perpendicularAxesFacing(other)
      us = @projectionInterval axis
      them = other.projectionInterval axis
      overlap = Utils.intervalOverlap us, them
      return false unless overlap > 0
      if overlap < minOverlap
        minOverlap = overlap
        minAxis = axis

    for axis in other.perpendicularAxesFacing(this)
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

  perpendicularAxesFacing: (other) ->
    dir = Vec.sub other.position, @position
    (axis for axis in @perpendicularAxes() when Vec.dotProduct(axis, dir) > 0)

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
    ctx.lineTo points[0]...

    ctx.globalAlpha = 0.5
    ctx.fillStyle = @color
    ctx.fill()

    ctx.globalAlpha = 1
    ctx.strokeStyle = @color
    ctx.stroke()

    ctx.restore()

class Contact
  constructor: (@position, @normal, @depth) ->

window.Rotation =
  fromAngle: (angle) -> [Math.cos(angle), Math.sin(angle)]
  add: ([a,b],[c,d]) -> [a*c - b*d, a*d + c*b]
  addAngle: (rotation, angle) -> @add rotation, @fromAngle(angle)
  toAngle: (rotation) -> Math.acos rotation[0]
  fromDeg: (deg) -> deg * 2 * Math.PI / 360
  toDeg: (rad) -> rad * 360 / (2 * Math.PI)

