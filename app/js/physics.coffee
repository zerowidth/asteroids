window.physics = ->
  window.stats = Utils.drawStats()
  window.ctx = Sketch.create
    element: document.getElementById "physics"
    # retina: true
  window.grid = new Grid 100, "#056"
  controls = new KeyboardControls

  # dot = new Particle [100, ctx.height - 100]
  rect = new Rectangle 200, 100, [100, 50], 0, "#F00"
  rect2 = new Rectangle 200, 100, [0, -100], 0, "#00F"

  _.extend ctx,
    update: ->
      rect.update ctx.dt / 1000, controls
    draw: ->
      grid.draw ctx
      rect.draw ctx
      rect2.draw ctx
      stats.update()
    clear: ->
      ctx.clearRect -ctx.width/2, -ctx.height/2, ctx.width, ctx.height
    keyup: controls.keyup
    keydown: controls.keydown

  # | a c e |    |  1  0  0 |
  # | b d f | => |  0 -1  0 |
  # | 0 0 1 |    |  0  0  1 |
  ctx.setTransform 1, 0, 0, -1, 0, 0 # flip y axis so it goes up (and z goes out)
  ctx.translate ctx.width/2, -ctx.height/2 # center the origin

class Rectangle
  constructor: (sizeX, sizeY, position, orientationAngle, @color) ->
    @position = position
    @points = [[ sizeX/2,  sizeY/2],
               [-sizeX/2,  sizeY/2],
               [-sizeX/2, -sizeY/2],
               [ sizeX/2, -sizeY/2]]

  update: (dt, keyboard) ->
    if keyboard.left
      dx = -1
    else if keyboard.right
      dx = 1
    else
      dx = 0

    if keyboard.up
      dy = 1
    else if keyboard.down
      dy = -1
    else dy = 0

    @position = Vec.add @position, Vec.scale [dx, dy], 200*dt

  draw: (ctx) ->
    ctx.save()
    ctx.beginPath()

    ctx.translate @position...

    ctx.moveTo @points[@points.length - 1]...

    for point in @points
      ctx.lineTo point...

    ctx.globalAlpha = 0.5
    ctx.fillStyle = @color
    ctx.fill()
    ctx.globalAlpha = 1

    ctx.strokeStyle = @color
    ctx.stroke()
    ctx.restore()
