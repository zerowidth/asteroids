window.Contact = class Contact

  restitution: 0.2 # TODO calculate this from objects involved

  constructor: (@from, @to, @position, @normal, @depth, @offset) ->

  # Calculated fresh each time, as the position and velocity may have changed
  # during a previous contact resolution iteration
  relativeVelocity: ->
    relativeV = Vec.add @from.velocity, @from.angularVelocityAt(@position, @offset)
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

    # calculate distribution of desired deltaV between linear and angular
    # components on both bodies:
    deltaV = @from.inverseMass
    deltaV += @from.angularInertiaAt(@position, @normal, @offset)

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

    @from.applyImpulse reactionImpulse, @position, @offset
    if @to
      @to.applyImpulse Vec.invert(reactionImpulse), @position

    friction = 0.4 # hardcoded coefficient
    frictionLimit = friction * Vec.magnitude(reactionImpulse)

    deltaV = @from.inverseMass
    deltaV += @from.angularInertiaAt(@position, tangent, @offset)
    if @to
      deltaV += @to.inverseMass
      deltaV += @to.angularInertiaAt(@position, tangent)

    vTangent = Vec.dotProduct relV, tangent
    tangentImpulse = -vTangent / deltaV
    limit = friction * impulse
    if tangentImpulse > limit then tangentImpulse = limit
    if tangentImpulse < -limit then tangentImpulse = -limit

    frictionImpulse = Vec.scale tangent, tangentImpulse

    @from.applyImpulse frictionImpulse, @position, @offset
    if @to
      @to.applyImpulse Vec.invert(frictionImpulse), @position

  resolveInterpenetration: ->
    return if @depth <= 0

    # Similar to velocity resolution, distribute penetration resolution between
    # linear and angular components proportional to the bodies' inertia.

    totalInertia = @from.inverseMass
    totalInertia += @from.angularInertiaAt(@position, @normal, @offset)

    if @to
      totalInertia += @to.inverseMass
      totalInertia += @to.angularInertiaAt(@position, @normal)

    return if totalInertia <= 0 # nobody's goin' nowhere

    # how far per inertia should each body move?
    moveRatio = @depth / totalInertia

    [linearMove, angularMove] = @calculateMove @from, moveRatio, @offset
    linearChange   = @from.changePosition @normal, linearMove
    rotationChange = @from.rotateByImpulse @position, @normal, angularMove, @offset
    if @related
      @related.updatePenetration linearChange, rotationChange, @from, -1

    if @to
      [linearMove, angularMove] = @calculateMove @to, moveRatio, [0, 0]
      linearChange = @to.changePosition @normal, -linearMove
      rotationChange = @to.rotateByImpulse @position, @normal, -angularMove
      if @related
        @related.updatePenetration linearChange, rotationChange, @to, 1

    @depth = 0

  calculateMove: (body, moveRatio, offset) ->
    linearMove  = moveRatio * body.inverseMass
    angularMove = moveRatio * body.angularInertiaAt(@position, @normal, offset)

    # Limit the rotation movement by a factor relative to the size of the body.
    # The relative position of the contact serves as a stand-in for actual size.
    # This prevents a body from being rotated "too far", and instead shifts the
    # burden of angular movement to the linear portion.

    limit = Vec.magnitude(body.relativePositionAt(@position, offset)) * 0.2
    if Math.abs(angularMove) > limit
      total = linearMove + angularMove
      if angularMove >= 0
        angularMove = limit
      else
        angularMove = -limit
      linearMove = total - angularMove

    [linearMove, angularMove]

  updatePenetration: (linearChange, rotationChange, referenceBody, sign) ->
    relativePosition = referenceBody.relativePositionAt(@position, @offset)
    rotationDistance = Vec.scale Vec.perpendicular(relativePosition), rotationChange
    deltaPosition = Vec.add linearChange, rotationDistance
    relativeChange = Vec.dotProduct @normal, deltaPosition
    @depth += relativeChange * sign

