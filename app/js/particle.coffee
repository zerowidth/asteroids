window.Particle = class Particle
  alive: true
  lifespan: 1

  position: [0, 0]
  velocity: [0, 0]
  damping: 0

  size: 1
  color: "#888"
  fade: false

  constructor: (opts = {}) ->
    @lifespan = opts.lifespan if opts.lifespan
    @position = opts.position if opts.position
    @velocity = opts.velocity if opts.velocity
    @damping  = opts.damping if opts.damping
    @size     = opts.size if opts.size
    @color    = opts.color if opts.color
    @fade     = opts.fade
    @collides = opts.collides

    @life = 0

  integrate: (dt) ->
    return if dt <= 0
    @position = Vec.add @position, Vec.scale @velocity, dt

    if @damping > 0
      @velocity = Vec.scale @velocity, (1 - @damping)

    @life += dt

    @alive = @life <= @lifespan

  draw: (display) ->
    threeFourths = @lifespan * 3 / 4
    alpha = 1
    if @fade and @life > threeFourths
      # quadratic falloff from 0.75 to 1.0 of lifespan
      width = @lifespan / 4
      x = (@life - threeFourths) / width
      alpha = (1 - x * x)
    display.drawCircle @position, @size, @color, alpha
