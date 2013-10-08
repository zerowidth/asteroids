window.physics = ->

  window.world = new World "physics"

  window.rect = new Rectangle 2, 2,
    position: [0, 0]
    inverseMass: 1/4
    color: "#F00"

  window.rect2 = new Rectangle 1, 1,
    position: [0, 5]
    inverseMass: 1/1
    velocity: [0, -1]
    color: "#00F"

  world.addObject rect
  world.addObject rect2

class World
  constructor: (element) ->
    @ctx = Sketch.create
      element: document.getElementById element
      retina: true
    @stats = Utils.drawStats()
    @display = new Display @ctx, [0, 0], 50

    @objects = []
    @paused = true

    _.extend @ctx,
      update: @update
      draw: @draw
      keyup: (e) =>
        if e.keyCode is 32 # space
          @paused = !@paused

  addObject: (object) ->
    @objects.push object

  removeObject: (object) ->
    @objects = _without(@objects, object)

  update: =>
    return if @paused

    dt = @ctx.dt / 1000

    for object in @objects
      object.reset()
      object.resetDebug()
      object.integrate dt for object in @objects

    @contacts = @narrowPhaseCollisions @broadPhaseCollisions()

    if @contacts.length > 0
      for c, i in @contacts
        console.log "contact #{i}", c.normal, c.depth, c.from.velocity

      for n in [1..@contacts.length*2] # loop contacts * 2 times
        worst = null
        for contact in @contacts
          if not worst or contact.separatingVelocity() < worst.separatingVelocity()
            worst = contact
        break if worst.separatingVelocity() >= 0
        worst.resolve(dt)

      @paused = true

  # Naive version: returns all unique pairs of objects, nothing more. TODO: use
  # (memoized?) AABBs to build quadtree, then iterate and compare bounding boxes
  # for overlap.
  broadPhaseCollisions: ->
    pairs = []
    for i in [0..(@objects.length-2)]
      for j in [(i+1)..(@objects.length-1)]
        pairs.push [@objects[i], @objects[j]]
    pairs

  narrowPhaseCollisions: (pairs) ->
    contacts = []
    for [a, b] in pairs
      contacts = contacts.concat(b.contactPoints a)
    contacts

  draw: =>
    for object in @objects
      object.draw @display
      object.drawDebug @display
    @stats.update()

class Display
  # ctx    - the canvas context
  # center - [x, y] center of display
  # scale  - pixels per meter
  constructor: (@ctx, @center, @scale) ->

  transform: (points...) ->
    dx = @ctx.width/2
    dy = @ctx.height/2
    ([x * @scale + dx, -y * @scale + dy ] for [x, y] in points)

  drawPolygon: (vertices, color) ->
    vertices = @transform vertices...

    @ctx.save()
    @ctx.beginPath()

    @ctx.moveTo vertices[0]...
    for point in vertices[1..]
      @ctx.lineTo point...
    @ctx.lineTo vertices[0]...

    @ctx.globalAlpha = 0.5
    @ctx.fillStyle = color
    @ctx.fill()

    @ctx.globalAlpha = 1
    @ctx.strokeStyle = color
    @ctx.stroke()

    @ctx.restore()

  drawCircle: (center, radius, color) ->
    @ctx.save()

    center = @transform(center)[0]

    @ctx.fillStyle = color

    @ctx.beginPath()
    @ctx.arc center[0], center[1], radius, 0, Math.PI * 2
    @ctx.fill()

    @ctx.restore()

  drawLine: (from, to, width, color) ->
    @ctx.save()

    from = @transform(from)[0]
    to = @transform(to)[0]

    @ctx.strokeStyle = color
    @ctx.lineWidth = width

    @ctx.beginPath()
    @ctx.moveTo from...
    @ctx.lineTo to...
    @ctx.stroke()

    @ctx.restore()

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
  position: [0, 0]
  rotation: [1, 0] # Rotation.fromAngle(0)

  velocity: [0, 0]
  angularVelocity: 0
  inverseMass: 0 # required value
  inverseMoment: 0 # calculated value

  # acceleration: [0, -100] # gravity
  acceleration: [0, 0]
  angularAccel: 0
  damping: 0.9999 # minimal
  angularDamping: 0.9999

  vertices: -> []

  color: "#CCC"
  debug: {}

  reset: -> # reset caches, forces, etc.

  integrate: (dt) ->
    return if dt <= 0

    if @inverseMass > 0
      @position = Vec.add @position, Vec.scale @velocity, dt
      @position = Vec.add @position, Vec.scale @acceleration, dt * dt / 2

      # TODO add forces here from whatever external forces are present (force
      # generators + force generator registry?)

      @velocity = Vec.scale @velocity, Math.pow(@damping, dt)
      @velocity = Vec.add @velocity, Vec.scale @acceleration, dt

    if @inverseMoment > 0
      @orientation = Rotation.addAngle @orientation, @angularVelocity * dt
      @orientation = Rotation.addAngle @orientation, @angularAccel * dt * dt / 2

      @angularVelocity = Math.pow(@angularDamping, dt) * @angularVelocity
      @angularVelocity += @angularAccel * dt

  draw: (display) ->
    display.drawPolygon @vertices(), @color

  resetDebug: -> @debug = {}

  drawDebug: (display) ->
    # if ref = @debug.reference
    #   Utils.debugLine display, ref.from, ref.to, "#F66"
    # if inc = @debug.incident
    #   Utils.debugLine display, inc.from, inc.to, "#66F"
    # if clipped = @debug.clipped
    #   Utils.debugLine display, clipped[0], clipped[1], "#FF0"
    if contacts = @debug.contacts
      for contact in contacts
        Utils.debugContact display, contact, "#0F0"

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
    contactNormal = Vec.invert minAxis # so it's B->A
    contacts = []

    # Calculate depth for each clipped point and return only those which are
    # nonzero (that is, aren't on the other side of the reference edge)
    for point in clipped
      depth = Vec.dotProduct(refNorm, point) - maxDepth
      if depth >= 0
        contacts.push new Contact(this, other, point, contactNormal, depth, 0.3)

    # For simplicity sake, only return the "deepest" contact point. Eventually
    # the physics engine will need to track more than one contact per pair of
    # objects and update related contacts as each one is resolved.
    if contacts[1] && contacts[1].depth > contacts[0].depth
      contacts = [contacts[1]]
    else
      contacts = [contacts[0]]

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
    vertices = @vertices()

    # Find deepest vertex in the polygon along separation axis
    deepestIndex = null
    maxProjection = -Infinity
    for vertex, i in vertices
      projection = Vec.dotProduct minAxis, vertex
      if projection > maxProjection
        maxProjection = projection
        deepestIndex = i

    # Find edge which is most perpendicular to separation axis
    deepest    = vertices[ deepestIndex ]
    prevVertex = vertices[ (deepestIndex - 1 + vertices.length) % vertices.length ]
    nextVertex = vertices[ (deepestIndex + 1 + vertices.length) % vertices.length ]

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
    Utils.projectionInterval @vertices(), axis

  perpendicularAxes: ->
    for pair in Utils.pairs @vertices()
      Vec.perpendicular Vec.sub pair[1], pair[0]

  perpendicularAxesFacing: (other) ->
    dir = Vec.sub other.position, @position
    (axis for axis in @perpendicularAxes() when Vec.dotProduct(axis, dir) > 0)

  calculatePhysicalProperties: (opts) ->
    @inverseMass = opts.inverseMass or @inverseMass

    vertices = @vertices()

    ix   = 0
    iy   = 0
    area = 0
    cx   = 0
    cy   = 0

    for [[x0,y0], [x1,y1]] in Utils.pairs vertices
      a     = (x0*y1 - x1*y0) # unsigned area of triangle
      area += a
      ix   += (y0*y0 + y0*y1 + y1*y1) * a
      iy   += (x0*x0 + x0*x1 + x1*x1) * a
      cx   += (x0 + x1) * a
      cy   += (y0 + y1) * a

    ix   = ix / 12
    iy   = iy / 12
    area = Math.abs(area) / 2
    cx   = cx / (6 * area)
    cy   = cy / (6 * area)

    # parallel axis theorem to recenter moment around centroid
    ix = ix - area * cx * cx
    iy = iy - area * cy * cy

    momentOfArea = ix + iy

    if momentOfArea > 0 and @inverseMass > 0
      mass           = 1 / @inverseMass
      moment         = (mass / area) * momentOfArea
      @inverseMoment = opts.inverseMoment or 1/moment

    # TODO reset centroid with new values

class Rectangle extends Polygon
  constructor: (sizeX, sizeY, opts = {}) ->
    @position = opts.position or @position
    @offsets = [[ sizeX/2,  sizeY/2],
               [-sizeX/2,  sizeY/2],
               [-sizeX/2, -sizeY/2],
               [ sizeX/2, -sizeY/2]]

    @orientation = Rotation.fromAngle(opts.angle or 0)
    @color = opts.color or "#888"

    @velocity = opts.velocity or @velocity
    @angularVelocity = opts.angularVelocity or @angularVelocity

    @calculatePhysicalProperties opts

  reset: ->
    # TODO only reset if position/velocity/orientation have changed
    @cachedVertices = null

  vertices: ->
    @cachedVertices ?= (Vec.transform offset, @position, @orientation for offset in @offsets)

  calculateInverseMoment: (b, h) ->
    if @inverseMass is 0
      0
    else
      (1/@inverseMass)*(b*b + h*h)/12

class Contact
  restitution: 0.5 # fairly bouncy

  constructor: (@from, @to, @position, @normal, @depth, restitution=null) ->
    @restitution = restitution if restitution?

  # Calculated fresh each time, as the position and velocity may have changed
  # during a previous contact resolution iteration
  separatingVelocity: ->
    relativeV = @from.velocity
    if @to
      relativeV = Vec.sub relativeV, @to.velocity
    Vec.dotProduct relativeV, @normal

  resolve: (dt) ->
    @resolveVelocity dt
    @resolveInterpenetration dt

  resolveVelocity: (dt) ->
    sepV = @separatingVelocity()
    return if sepV >= 0 # separating or stationary

    newSepV = -sepV * @restitution

    # check velocity buildup due to acceleration only
    acceleratedV = if @from.inverseMass > 0 then @from.acceleration else 0
    if @to and @to.inverseMass > 0
      acceleratedV = Vec.sub acceleratedV, @to.acceleration
    acceleratedSepV = Vec.dotProduct acceleratedV, Vec.scale @normal, dt
    newSepV += @restitution * acceleratedSepV if acceleratedSepV < 0
    newSepV = 0 if newSepV < 0

    deltaV = newSepV - sepV

    # apply change in velocity in proportion to inverse mass
    totalInvMass = @totalInvMass()
    return if totalInvMass <= 0 # nobody's goin' nowhere

    impulse = deltaV / totalInvMass
    impulsePerMass = Vec.scale @normal, impulse

    # apply impulses
    @from.velocity = Vec.add @from.velocity, Vec.scale impulsePerMass, @from.inverseMass
    if @to
      @to.velocity = Vec.sub @to.velocity, Vec.scale impulsePerMass, @to.inverseMass

  resolveInterpenetration: ->
    return if @depth <= 0

    totalInvMass = @totalInvMass()
    return if totalInvMass <= 0 # nobody's goin' nowhere

    movePerIMass = Vec.scale @normal, (@depth / totalInvMass)

    @from.position = Vec.add @from.position, Vec.scale movePerIMass, @from.inverseMass
    if @to
      @to.position = Vec.sub @to.position, Vec.scale movePerIMass, @to.inverseMass

  totalInvMass: ->
    total = @from.inverseMass
    total += @to.inverseMass if @to
    total

window.Rotation =
  fromAngle: (angle) -> [Math.cos(angle), Math.sin(angle)]
  add: ([a,b],[c,d]) -> [a*c - b*d, a*d + c*b]
  addAngle: (rotation, angle) -> @add rotation, @fromAngle(angle)
  toAngle: (rotation) -> Math.acos rotation[0]
  fromDeg: (deg) -> deg * 2 * Math.PI / 360
  toDeg: (rad) -> rad * 360 / (2 * Math.PI)
