window.Display = class Display
  # ctx    - the canvas context
  # scale  - pixels per unit (world)
  constructor: (@ctx, @scale) ->

  transform: (points...) ->
    dx = @ctx.width/2
    dy = @ctx.height/2
    ([x * @scale + dx, -y * @scale + dy ] for [x, y] in points)

  drawPolygon: (vertices, color) ->
    vertices = @transform vertices...

    @ctx.save()
    @ctx.beginPath()

    @ctx.moveTo vertices[0]...
    for point in vertices[1..]
      @ctx.lineTo point...
    @ctx.lineTo vertices[0]...

    @ctx.globalAlpha = 0.5
    @ctx.fillStyle = color
    @ctx.fill()

    @ctx.globalAlpha = 1
    @ctx.strokeStyle = color
    @ctx.stroke()

    @ctx.restore()

  drawCircle: (center, radius, color) ->
    @ctx.save()

    center = @transform(center)[0]

    @ctx.fillStyle = color

    @ctx.beginPath()
    @ctx.arc center[0], center[1], radius, 0, Math.PI * 2
    @ctx.fill()

    @ctx.restore()

  drawLine: (from, to, width, color, alpha=1) ->
    @ctx.save()

    from = @transform(from)[0]
    to = @transform(to)[0]

    @ctx.strokeStyle = color
    @ctx.lineWidth = width

    @ctx.globalAlpha = alpha if alpha < 1

    @ctx.beginPath()
    @ctx.moveTo from...
    @ctx.lineTo to...
    @ctx.stroke()

    @ctx.restore()

window.WrappedDisplay = class WrappedDisplay extends Display
  # ctx    - the canvas context
  # center - [x, y] (world) center of display
  # sizeX  - size of display (world, not pixels)
  # sizeY  - size of display (world, not pixels)
  # scale  - pixels per meter
  constructor: (@ctx, @center, @sizeX, @sizeY, @scale) ->
    @offset = [0, 0]

  # Internal: perform drawing operations with given x/y offsets (by quadrant)
  #
  # x, y - -1, 0, 1 offset multipliers
  # fn   - a function to call with the given offset
  withOffset: (x, y, fn) ->
    @offset = [x * @sizeX * @scale, y * @sizeY * @scale]
    # @offset = [x * @sizeX, y * @sizeY]
    fn.call this
    @offset = [0, 0]

  transform: (points...) ->
    dx = @ctx.width/2
    dy = @ctx.height/2
    for [x, y] in points
      [
        (x - @center[0]) * @scale + dx + @offset[0],
        (-y + @center[1]) * @scale + dy + @offset[1]
      ]

  drawPolygon: (vertices, color) ->
    super vertices, color

    if _.some(vertices, (v) => v[0] < 0)
      @withOffset  1,  0, -> super vertices, color
    if _.some(vertices, (v) => v[0] > @sizeX)
      @withOffset -1,  0, -> super vertices, color
    if _.some(vertices, (v) => v[1] < 0)
      @withOffset  0, -1, -> super vertices, color
    if _.some(vertices, (v) => v[1] > @sizeY)
      @withOffset  0,  1, -> super vertices, color

  drawCircle: (center, radius, color) ->
    super center, radius, color

  drawLine: (from, to, width, color, alpha=1) ->
    super from, to, width, color, alpha

  # Public: draw the bounds of this display for debugging
  drawBounds: (color="#FFF", alpha=0.2) ->
    @ctx.save()

    points = @transform [ [0,0], [@sizeX, 0], [@sizeX, @sizeY], [0, @sizeY], [0,0] ]...

    @ctx.globalAlpha = alpha if alpha < 1
    @ctx.lineWidth = 1
    @ctx.strokeStyle = color
    @ctx.beginPath()
    @ctx.moveTo points[0]...
    @ctx.lineTo points[i]... for i in [1..4]
    @ctx.stroke()
    @ctx.restore()
