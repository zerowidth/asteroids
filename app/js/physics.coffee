window.Polygon = class Polygon
  position: [0, 0]
  orientation: [1, 0] # Rotation.fromAngle(0)

  velocity: [0, 0]
  angularVelocity: 0
  inverseMass: 0 # required value
  inverseMoment: 0 # calculated value

  # acceleration: [0, -100] # gravity
  acceleration: [0, 0]
  angularAccel: 0
  damping: 0.9999 # minimal
  angularDamping: 0.9999

  # bookkeeping
  lastAcceleration: [0, 0]

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

      # save the acceleration for contact resolution for resting contacts.
      @lastAcceleration = Vec.scale @acceleration, dt

      @velocity = Vec.scale @velocity, Math.pow(@damping, dt)
      @velocity = Vec.add @velocity, @lastAcceleration

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
    refNorm = Vec.perpendicularNormal reference.vec

    # find the largest depth
    maxDepth = Vec.dotProduct refNorm, reference.deepest
    contactNormal = Vec.invert minAxis # so it's B->A
    contacts = []

    # Calculate depth for each clipped point and return only those which are
    # nonzero (that is, aren't on the other side of the reference edge)
    for point in clipped
      depth = Vec.dotProduct(refNorm, point) - maxDepth
      if depth >= 0
        contacts.push new Contact(this, other, point, contactNormal, depth)

    if contacts[1]
      contacts[0].related = contacts[1]
      contacts[1].related = contacts[0]

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
      Vec.perpendicularNormal Vec.sub pair[1], pair[0]

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

    # TODO reset position to centroid using the new values

  relativePositionAt: (point) ->
    Vec.sub point, @position

  angularVelocityAt: (point) ->
    Vec.scale Vec.perpendicular(@relativePositionAt(point)), @angularVelocity

  angularInertiaAt: (position, direction) ->
    qRel = @relativePositionAt position
    torquePerUnitImpulse = Vec.crossProduct qRel, direction
    rotationPerUnitImpulse = torquePerUnitImpulse * @inverseMoment
    velocityPerUnitImpulse = Vec.perpendicular Vec.scale(qRel, rotationPerUnitImpulse)
    Vec.dotProduct velocityPerUnitImpulse, direction

  applyImpulse: (impulse, position) ->
    impulsiveTorque = Vec.crossProduct @relativePositionAt(position), impulse
    @velocity = Vec.add @velocity, Vec.scale impulse, @inverseMass
    @angularVelocity += impulsiveTorque * @inverseMoment

  changePosition: (normal, amount) ->
    linearChange = Vec.scale normal, amount
    @position = Vec.add @position, linearChange
    linearChange

  rotateByImpulse: (position, normal, amount) ->
    impulsiveTorque = Vec.crossProduct @relativePositionAt(position), normal
    impulsePerMove  = @inverseMoment * impulsiveTorque
    rotationChange  = amount * impulsePerMove
    @orientation    = Rotation.addAngle @orientation, rotationChange
    rotationChange

window.Rectangle = class Rectangle extends Polygon
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

    @acceleration = opts.acceleration or @acceleration

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
  restitution: 0.3 # TODO calculate this from objects involved

  constructor: (@from, @to, @position, @normal, @depth, restitution=null) ->
    @restitution = restitution if restitution?

  # Calculated fresh each time, as the position and velocity may have changed
  # during a previous contact resolution iteration
  relativeVelocity: ->
    relativeV = Vec.add @from.velocity, @from.angularVelocityAt(@position)
    if @to
      toV = Vec.add @to.velocity, @to.angularVelocityAt(@position)
      relativeV = Vec.sub relativeV, toV
    relativeV

  separatingVelocity: ->
    Vec.dotProduct @relativeVelocity(), @normal

  resolveVelocity: (dt) ->
    relV = @relativeVelocity()
    sepV = Vec.dotProduct relV, @normal
    tangent = Vec.normalize Vec.sub(relV, Vec.scale(@normal, sepV))

    return if sepV >= 0 # separating or stationary

    # TODO save acceleration per frame and compensate here

    # debug "sepV", sepV

    # calculate distribution of desired deltaV between linear and angular
    # components on both bodies:
    deltaV = @from.inverseMass
    deltaV += @from.angularInertiaAt(@position, @normal)

    # ignore velocity accumulated in the last frame for reducing vibration
    # during resting contacts.
    velocityFromAcceleration = Vec.dotProduct @from.lastAcceleration, @normal

    if @to
      deltaV += @to.inverseMass
      deltaV += @to.angularInertiaAt(@position, @normal)
      velocityFromAcceleration -= Vec.dotProduct @to.lastAcceleration, @normal

    # limit restitution on low-speed collisions (i.e. resting contacts)
    appliedRestitution = Math.abs(sepV) < 0.1 ? 0 : @restitution

    desiredDeltaV = -sepV - @restitution * (sepV - velocityFromAcceleration)
    impulse = desiredDeltaV / deltaV
    reactionImpulse = Vec.scale @normal, impulse

    @from.applyImpulse reactionImpulse, @position
    if @to
      @to.applyImpulse Vec.invert(reactionImpulse), @position

    friction = 0.3 # hardcoded coefficient
    frictionLimit = friction * Vec.magnitude(reactionImpulse)

    deltaV = @from.inverseMass
    deltaV += @from.angularInertiaAt(@position, tangent)
    if @to
      deltaV += @to.inverseMass
      deltaV += @to.angularInertiaAt(@position, tangent)

    vTangent = Vec.dotProduct relV, tangent
    tangentImpulse = -vTangent / deltaV
    limit = friction * impulse
    if tangentImpulse > limit then tangentImpulse = limit
    if tangentImpulse < -limit then tangentImpulse = -limit

    frictionImpulse = Vec.scale tangent, tangentImpulse

    @from.applyImpulse frictionImpulse, @position
    if @to
      @to.applyImpulse Vec.invert(frictionImpulse), @position

  resolveInterpenetration: ->
    return if @depth <= 0

    # Similar to velocity resolution, distribute penetration resolution between
    # linear and angular components proportional to the bodies' inertia.

    totalInertia = @from.inverseMass
    totalInertia += @from.angularInertiaAt(@position, @normal)

    if @to
      totalInertia += @to.inverseMass
      totalInertia += @to.angularInertiaAt(@position, @normal)

    return if totalInertia <= 0 # nobody's goin' nowhere

    # how far per inertia should each body move?
    moveRatio = @depth / totalInertia

    [linearMove, angularMove] = @calculateMove @from, moveRatio
    linearChange   = @from.changePosition @normal, linearMove
    rotationChange = @from.rotateByImpulse @position, @normal, angularMove
    if @related
      @related.updatePenetration linearChange, rotationChange, @from, -1

    if @to
      [linearMove, angularMove] = @calculateMove @to, moveRatio
      linearChange = @to.changePosition @normal, -linearMove
      rotationChange = @to.rotateByImpulse @position, @normal, -angularMove
      if @related
        @related.updatePenetration linearChange, rotationChange, @to, 1

    @depth = 0

  calculateMove: (body, moveRatio) ->
    linearMove  = moveRatio * body.inverseMass
    angularMove = moveRatio * body.angularInertiaAt(@position, @normal)

    # Limit the rotation movement by a factor relative to the size of the body.
    # The relative position of the contact serves as a stand-in for actual size.
    # This prevents a body from being rotated "too far", and instead shifts the
    # burden of angular movement to the linear portion.

    limit = Vec.magnitude(body.relativePositionAt(@position)) * 0.2
    if Math.abs(angularMove) > limit
      total = linearMove + angularMove
      if angularMove >= 0
        angularMove = limit
      else
        angularMove = -limit
      linearMove = total - angularMove

    [linearMove, angularMove]

  updatePenetration: (linearChange, rotationChange, referenceBody, sign) ->
    relativePosition = referenceBody.relativePositionAt(@position)
    rotationDistance = Vec.scale Vec.perpendicular(relativePosition), rotationChange
    deltaPosition = Vec.add linearChange, rotationDistance
    relativeChange = Vec.dotProduct @normal, deltaPosition
    @depth += relativeChange * sign

class Edge
  constructor: (@deepest, @from, @to) ->
    @vec = Vec.sub @to, @from
  dot: (other) ->
    Vec.dotProduct @vec, other
  normalize: ->
    @vec = Vec.normalize @vec
  invert: ->
    @vec = Vec.invert @vec
