window.particles = ->
  window.stats = Utils.drawStats()
  window.ctx = Sketch.create
    element: document.getElementById "particles"
    # retina: true
  window.grid = new Grid 100, "#056"

  dot = new Particle [100, ctx.height - 100]

  _.extend ctx,
    draw: ->
      grid.draw ctx
      dot.draw ctx
      stats.update()

  # | a c e |    |  1  0  0 |
  # | b d f | => |  0 -1  0 |
  # | 0 0 1 |    |  0  0  1 |
  ctx.setTransform 1, 0, 0, -1, 0, 0
  ctx.translate 0, -ctx.height

TWO_PI = Math.PI * 2

class Vec2
  constructor: (@x, @y) ->
  addScaledVector: (vec, scale) ->
    @x += vec.x * scale
    @y += vec.y * scale

GRAVITY = new Vec2 0, 10

class Particle
  inverseMass  : 0
  damping      : 0.999
  # position     : new Vec2 0, 0
  # velocity     : new Vec2 0, 0
  # acceleration : new Vec2 0, 0

  constructor: (position=[0,0]) ->
    @position = new Vec2 position...
    @velocity = new Vec2 0, 0
    @acceleration = new Vec2 0, 0

  integrate: (time) ->
    @age += time
    return if @inverseMass <= 0

    # update position
    @position.addScaledVector @velocity, time
    @position.addScaledVector @acceleration, time * time * 0.5

    # update velocity
    @velocity.addScaledVector @acceleration, duration

    # impose drag
    @velocity.scale Math.pow(@damping, time)

  draw: (ctx) ->
    ctx.beginPath()
    ctx.arc @position.x, @position.y, 5, 0, TWO_PI
    ctx.fillStyle = "#F00"
    ctx.fill()

window.Particle = Particle
window.Vec2 = Vec2
