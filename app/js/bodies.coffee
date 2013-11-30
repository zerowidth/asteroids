window.Rectangle = class Rectangle extends PolygonalBody
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
    @cachedVertices ?=
      (Vec.transform offset, @position, @orientation for offset in @offsets)

  # the regular polygonal version works, but this is easier:
  calculateInverseMoment: (b, h) ->
    if @inverseMass is 0
      0
    else
      (1/@inverseMass)*(b*b + h*h)/12
