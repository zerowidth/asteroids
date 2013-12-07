window.PolygonalBody = class PolygonalBody
  # where it is
  position: [0, 0]
  orientation: [1, 0] # Rotation.fromAngle(0)

  # where it's going
  velocity: [0, 0]
  angularVelocity: 0

  # where it will be going
  # acceleration: [0, -100] # gravity
  acceleration: [0, 0]
  angularAccel: 0

  # how heavy is it?
  inverseMass: 0 # required value if density not provided
  inverseMoment: null # calculated value, explicitly 0 to pin in place
  density: null

  # what's it look like?
  color: "#CCC"

  # simulation parameters
  damping: 0.9999 # minimal
  angularDamping: 0.9999

  # bookkeeping
  lastAcceleration: [0, 0]

  # Public: Initialize a polygonal body.
  #
  # opts - a dictionary of options, which can include:
  #        position        - location of the body
  #        orientation     - [x, iy] rotation of the body, OR:
  #        angle           - angle of orientation
  #        velocity        - [dx, dy] velocity
  #        angularVelocity - dTheta angular velocity
  #        acceleration    - [ddx, ddy] acceleration vector
  #        angularAccel    - angular acceleration scalar
  #        inverseMass     - inverse mass (0 for infinite)
  #        inverseMoment   - inverse moment (0 for infinite)
  #        density         - mass per unit area, instead of mass/moment
  #        color           - "#RRGGBB" color of the body
  #
  # Note that the vertices must be available at the time this constructor is
  # called (e.g. with super) so that the physical properties (area, mass, moment
  # of inertia) can be calculated.
  constructor: (opts = {}) ->
    @position = opts.position if opts.position
    if opts.angle
      @orientation = Rotation.fromAngle(opts.angle)
    else if opts.orientation
      @orientation = opts.orientation

    @velocity        = opts.velocity if opts.velocity
    @angularVelocity = opts.angularVelocity if opts.angularVelocity

    @acceleration    = opts.acceleration if opts.acceleration
    @angularAccel    = opts.angularAccel if opts.angularAccel

    @inverseMass     = opts.inverseMass if opts.inverseMass
    @inverseMoment   = opts.inverseMoment if opts.inverseMoment
    @density         = opts.density if opts.density

    @color           = opts.color if opts.color

    @calculatePhysicalProperties()

  # Public: override this in subclasses to define the vertices of this
  # polygonal body.
  vertices: -> []

  # Public: return an axis-aligned bounding box: [[xmin, ymin], [xmax, ymax]]
  aabb: ->
    vertices = @vertices()
    [x, y] = vertices[0]
    xmin = xmax = x
    ymin = ymax = y

    for [x, y] in vertices
      xmin = x if x < xmin
      xmax = x if x > xmax
      ymin = y if y < ymin
      ymax = y if y > ymax

    @debug.aabb = [[xmin, ymin], [xmax, ymax]]

  integrate: (dt, keyboard) ->
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

  debug: {}
  resetDebug: -> @debug = {}

  drawDebug: (display, settings) ->
    if settings.drawMinAxis and minAxis = @debug.minAxis
      Utils.debugLine display, minAxis.from, minAxis.to, "#F6F"
    if settings.drawAABB and aabb = @debug.aabb
      Utils.debugAABB display, aabb, "#F0F", 0.5
    if settings.drawSAT
      if ref = @debug.reference
        Utils.debugLine display, ref.from, ref.to, "#F66"
      if inc = @debug.incident
        Utils.debugLine display, inc.from, inc.to, "#66F"
      if clipped = @debug.clipped
        Utils.debugLine display, clipped[0], clipped[1], "#FF0"
    if settings.drawContacts and contacts = @debug.contacts
      for contact in contacts
        Utils.debugContact display, contact, "#0F0"

  # Calculate contact points against another polygon.
  # from http://www.codezealot.org/archives/394 &c
  contactPoints: (other) ->
    Geometry.contactPoints this, other

  calculatePhysicalProperties: ->
    vertices = @vertices()

    ix   = 0
    iy   = 0
    area = 0
    cx   = 0
    cy   = 0

    # Surveyor's formula
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

    if @density
      mass = area * @density
      @inverseMass = if mass > 0 then 1/mass else 0

    if momentOfArea > 0 and @inverseMass > 0 and not @inverseMoment
      mass           = 1 / @inverseMass
      moment         = (mass / area) * momentOfArea
      @inverseMoment = 1/moment

    # Store the difference between the calculated centroid and position. This
    # should always be [0, 0] but the value is stored for future correction if
    # it differs.
    @centroidOffset = Vec.sub [cx, cy], @position

  # Internal: Based on the calculated centroid, adjust the position (and point
  # offsets) so they match up.
  recalculateCentroid: ->
    @position = Vec.sub @position, @centroidOffset
    @centroidOffset = [0, 0]

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

