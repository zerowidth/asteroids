window.Display = class Display
  # ctx    - the canvas context
  # center - [x, y] center of display
  # scale  - pixels per meter
  constructor: (@ctx, @center, @scale) ->

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

  drawLine: (from, to, width, color) ->
    @ctx.save()

    from = @transform(from)[0]
    to = @transform(to)[0]

    @ctx.strokeStyle = color
    @ctx.lineWidth = width

    @ctx.beginPath()
    @ctx.moveTo from...
    @ctx.lineTo to...
    @ctx.stroke()

    @ctx.restore()
