class Ship
  SHIP_MASS: 10
  SHIP_SIZE: 25
  MAX_THRUST: 2000
  THRUST_STEP: 0.2

  constructor: (x, y, @theta= Vec.HALF_PI * 3) ->
    @position = [x, y]
    @velocity = [0, 0]
    @thrust = false
    @thrustLevel = 0

  update: (dt, controls) =>
    if controls.right
      @theta += PI/30
    else if controls.left
      @theta -= PI/30

    if @thrust = controls.up
      acceleration = Vec.polarToVector(@theta, @MAX_THRUST / @SHIP_MASS)
      @velocity = Vec.add @velocity, Vec.mul(acceleration, dt)

    @position = Vec.add @position, Vec.mul(@velocity, dt)

    if @thrust and @thrustLevel < 1
      @thrustLevel += @THRUST_STEP
    else if not @thrust and @thrustLevel > 0
      @thrustLevel -= @THRUST_STEP * 2
      @thrustLevel = 0 if @thrustLevel < 0

    @normalize ctx

  normalize: (ctx) =>
    @theta = Vec.normalizeAngle @theta

    # wrap window edges
    while @position[0] < 0
      @position[0] += ctx.width
    while @position[0] > ctx.width
      @position[0] -= ctx.width

    while @position[1] < 1
      @position[1] += ctx.height
    while @position[1] > ctx.height
      @position[1] -= ctx.height

  draw: (ctx) =>
    s3 = @SHIP_SIZE / 3

    ctx.save()
    ctx.translate @position...
    ctx.rotate @theta

    if @thrustLevel > 0
      ctx.beginPath()
      ctx.moveTo 0, s3/2
      ctx.lineTo 0, -s3/2
      ctx.lineTo -@SHIP_SIZE * @thrustLevel, 0

      ctx.fillStyle = "FB0"
      ctx.fill()

    ctx.beginPath()
    ctx.moveTo 2 * s3, 0
    ctx.lineTo -s3, -s3
    ctx.quadraticCurveTo 0, 0, -s3, s3
    # equivalent lines:
    # ctx.lineTo -s3/2, 0
    # ctx.lineTo -s3, s3
    ctx.lineTo 2 * s3, 0

    ctx.fillStyle = "#CCC"
    ctx.fill()
    ctx.lineWidth = 0.5
    ctx.stroke()

    ctx.restore()

  # Public: calculcate if the ship is near any edges.
  #
  # Returns [x, y], where 1 for left/top, -1 for right/bottom, 0 for neither.
  nearEdges: (ctx) =>
    # assume total size of ship and effects is SHIP_SIZE * 2
    xEdge = 0
    yEdge = 0

    [x, y] = @position
    xEdge = 1 if x < @SHIP_SIZE * 2
    xEdge = -1 if x > ctx.width - @SHIP_SIZE * 2

    yEdge = 1 if y < @SHIP_SIZE * 2
    yEdge = -1 if y > ctx.height - @SHIP_SIZE * 2

    [xEdge, yEdge]


window.Ship = Ship
