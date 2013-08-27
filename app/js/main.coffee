stats = new Stats()
stats.setMode(0) # 0: fps, 1: ms
stats.domElement.style.position = 'absolute'
stats.domElement.style.right = '0px'
stats.domElement.style.top = '0px'
document.body.appendChild( stats.domElement )

QUARTER_PI = Math.PI / 4

SHIP_MASS = 10
SHIP_SIZE = 50
MAX_THRUST = 2000

Vec =
  add: ([x1, y1], [x2, y2]) ->
    [x1 + x2, y1 + y2]
  sub: ([x1, y1], [x2, y2]) ->
    [x1 - x2, y1 - y2]
  mul: ([x, y], c) ->
    [x * c, y * c]
  polarToVector: (theta, length) ->
    [ cos(theta) * length, sin(theta) * length ]

class Ship
  constructor: (x, y, @theta= HALF_PI * 3) ->
    @position = [x, y]
    @velocity = [0, 0]

  update: (dt, controls) =>
    if controls.right
      @theta += PI/30
    else if controls.left
      @theta -= PI/30

    if @thrust = controls.up
      acceleration = Vec.polarToVector(@theta, MAX_THRUST / SHIP_MASS)
      @velocity = Vec.add @velocity, Vec.mul(acceleration, dt)

    @position = Vec.add @position, Vec.mul(@velocity, dt)

    @normalize(ctx)

  normalize: (ctx) =>
    while @theta > TWO_PI
      @theta -= TWO_PI
    while @theta < -TWO_PI
      @theta += TWO_PI

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
    s3 = SHIP_SIZE / 3

    ctx.save()
    ctx.translate @position...
    ctx.rotate @theta

    if @thrust
      ctx.beginPath()
      ctx.moveTo 0, s3/2
      ctx.lineTo 0, -s3/2
      ctx.lineTo -SHIP_SIZE, 0

      ctx.fillStyle = "FB0"
      ctx.fill()

    ctx.beginPath()
    ctx.moveTo 2 * s3, 0
    ctx.lineTo -s3, s3
    ctx.quadraticCurveTo 0, 0, -s3, -s3
    ctx.lineTo 2 * s3, 0

    ctx.fillStyle = "#CCC"
    ctx.fill()
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
    xEdge = 1 if x < SHIP_SIZE * 2
    xEdge = -1 if x > ctx.width - SHIP_SIZE * 2

    yEdge = 1 if y < SHIP_SIZE * 2
    yEdge = -1 if y > ctx.height - SHIP_SIZE * 2

    [xEdge, yEdge]

window.ctx = Sketch.create element: document.getElementById('asteroids')
window.ship = new Ship(ctx.width/2, ctx.height/2)

controls =
  thrust: false
  left: false
  right: false

drawWrapped = ([xEdge,yEdge], drawFn) ->
  drawFn()

  if xEdge isnt 0
    ctx.translate xEdge * ctx.width, 0
    drawFn()
    ctx.translate -xEdge * ctx.width, 0

  if yEdge isnt 0
    ctx.translate 0, yEdge * ctx.height
    drawFn()
    ctx.translate 0, -yEdge * ctx.height

ctx.update = ->
  ship.update ctx.dt / 1000, controls

ctx.draw = ->
  drawWrapped ship.nearEdges(ctx), -> ship.draw(ctx)
  stats.update()

ctx.keyup = (e) ->
  switch e.keyCode
    when 37 # left
      controls.left = false
    when 39 # right
      controls.right = false
    when 38 # up
      controls.up = false

ctx.keydown = (e) ->
  switch e.keyCode
    when 37 # left
      controls.left = true
    when 39 # right
      controls.right = true
    when 38 # up
      controls.up = true
