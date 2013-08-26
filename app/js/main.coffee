stats = new Stats()
stats.setMode(0) # 0: fps, 1: ms
stats.domElement.style.position = 'absolute'
stats.domElement.style.right = '0px'
stats.domElement.style.top = '0px'
document.body.appendChild( stats.domElement )

QUARTER_PI = Math.PI / 4

class Boid
  constructor: (@x, @y, @theta=0) ->
    @size = 100

  update: =>
    @theta += PI/60
    @normalize()

  normalize: =>
    @theta -= TWO_PI while @theta > TWO_PI
    @theta += TWO_PI while @theta < TWO_PI

  draw: (ctx) =>
    ctx.save()
    ctx.translate @x, @y
    ctx.rotate @theta

    ctx.fillStyle = "#CCC"

    s3 = @size / 3
    ctx.beginPath()
    ctx.moveTo 2 * s3, 0
    ctx.lineTo -s3, s3
    ctx.quadraticCurveTo 0, 0, -s3, -s3
    ctx.lineTo 2 * s3, 0
    ctx.fill()
    ctx.stroke()

    # ctx.fillStyle = "#000"
    # ctx.fillRect(0, 0, 1, 1)
    ctx.restore()

ctx = Sketch.create element: document.getElementById('boids')
boid = new Boid(ctx.width/2, ctx.height/2)

ctx.draw = ->
  boid.update()
  boid.draw(ctx)
  stats.update()
