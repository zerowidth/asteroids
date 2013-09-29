window.physics = ->
  window.stats = Utils.drawStats()
  window.ctx = Sketch.create
    element: document.getElementById "physics"
    # retina: true
  window.grid = new Grid 100, "#056"
  controls = new KeyboardControls

  # dot = new Particle [100, ctx.height - 100]
  window.rect = new Rectangle 200, 100, [100, 50], 0, "#F00"
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
  constructor: (sizeX, sizeY, position, angle, @color) ->
    @position = position
    @orientation = Rotation.fromAngle angle
    @offsets = [[ sizeX/2,  sizeY/2],
               [-sizeX/2,  sizeY/2],
               [-sizeX/2, -sizeY/2],
               [ sizeX/2, -sizeY/2]]

  points: () ->
    (Vec.transform offset, @position, @orientation for offset in @offsets)

  update: (dt, keyboard) ->
    dx = dy = rot = 0

    if keyboard.shift
      rot = 1 if keyboard.left
      rot = -1 if keyboard.right
    else
      dx = -1 if keyboard.left
      dx = 1 if keyboard.right

    dy = 1 if keyboard.up
    dy = -1 if keyboard.down

    if dx isnt 0 or dy isnt 0
      @position = Vec.add @position, Vec.scale [dx, dy], 200*dt
    if rot isnt 0
      @orientation = Rotation.addAngle @orientation, Math.PI*dt*rot

  draw: (ctx) ->
    points = @points()
    ctx.save()

    ctx.beginPath()
    ctx.moveTo points[0]...
    for point in points[1..]
      ctx.lineTo point...

    ctx.globalAlpha = 0.5
    ctx.fillStyle = @color
    ctx.fill()

    ctx.globalAlpha = 1
    ctx.strokeStyle = @color
    ctx.stroke()

    ctx.restore()

window.Rotation =
  fromAngle: (angle) -> [Math.cos(angle), Math.sin(angle)]
  add: ([a,b],[c,d]) -> [a*c - b*d, a*d + c*b]
  addAngle: (rotation, angle) -> @add rotation, @fromAngle(angle)
  toAngle: (rotation) -> Math.acos rotation[0]
  fromDeg: (deg) -> deg * 2 * Math.PI / 360
  toDeg: (rad) -> rad * 360 / (2 * Math.PI)

