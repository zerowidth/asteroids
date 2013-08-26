stats = new Stats()
stats.setMode(0) # 0: fps, 1: ms
stats.domElement.style.position = 'absolute'
stats.domElement.style.right = '0px'
stats.domElement.style.top = '0px'
document.body.appendChild( stats.domElement )

QUARTER_PI = Math.PI / 4

class Ship
  constructor: (@x, @y, @theta=0) ->
    @size = 50

  update: (controls) =>
    if controls.right
      @theta += PI/30
    else if controls.left
      @theta -= PI/30

    @thrust = controls.up

    @normalize()

  normalize: =>
    @theta -= TWO_PI while @theta > TWO_PI
    @theta += TWO_PI while @theta < TWO_PI

  draw: (ctx) =>
    s3 = @size / 3

    ctx.save()
    ctx.translate @x, @y
    ctx.rotate @theta

    if @thrust
      ctx.beginPath()
      ctx.moveTo 0, s3/2
      ctx.lineTo 0, -s3/2
      ctx.lineTo -@size, 0

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

    # ctx.fillStyle = "#000"
    # ctx.fillRect(0, 0, 1, 1)
    ctx.restore()

ctx = Sketch.create element: document.getElementById('boids')
ship = new Ship(ctx.width/2, ctx.height/2)

controls =
  thrust: false
  left: false
  right: false

ctx.update = ->
  ship.update controls

ctx.draw = ->
  ship.draw(ctx)
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
