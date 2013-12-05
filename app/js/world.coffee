window.World = class World
  constructor: (element, opts={}) ->
    @scale          = opts.scale or 50
    @speedFactor    = opts.speedFactor or 1
    @paused         = opts.paused or false
    @pauseEveryStep = opts.pauseEveryStep or false
    @pauseOnContact = opts.pauseOnContact or false

    @ctx = Sketch.create
      element: document.getElementById element
      retina: true
    @stats = Utils.drawStats()
    @display = new Display @ctx, @scale

    @bodies = []
    @slow = false

    _.extend @ctx,
      update: @update
      draw: @draw
      keydown: (e) =>
        switch e.keyCode
          when 16 # shift
            @slow = true
      keyup: (e) =>
        switch e.keyCode
          when 32 # space
            @paused = !@paused
          when 16 # shift
            @slow = false

  debugSettings:
    drawMinAxis: false
    drawAABB: false
    drawSAT: false
    drawContacts: false

  addBody: (body) ->
    @bodies.push body

  removeBody: (body) ->
    @bodies = _.without(@bodies, body)

  removeAllBodies: ->
    @bodies = []

  update: =>
    return if @paused

    dt = @ctx.dt / 1000 * @speedFactor
    dt = dt / 5 if @slow

    for body in @bodies
      body.resetDebug()
      body.integrate dt

    @postIntegrate()

    @contacts = @narrowPhaseCollisions @broadPhaseCollisions()

    if @contacts.length > 0
      for n in [1..@contacts.length*2] # loop contacts * 2 times
        worst = null
        for contact in @contacts
          if not worst or contact.depth > worst.depth
            worst = contact
        break if worst.depth <= 0
        @resolveInterpenetration worst

      for n in [1..@contacts.length*2]
        worst = null
        worstSepV = null
        for contact in @contacts
          sepV = contact.separatingVelocity()
          if not worst or sepV < worstSepV
            worst     = contact
            worstSepV = sepV

        break if worstSepV > 0
        @resolveVelocity worst, dt

      @paused = true if @pauseOnContact

    @paused = true if @pauseEveryStep

  resolveInterpenetration: (contact) ->
    contact.resolveInterpenetration()

  resolveVelocity: (contact, dt) ->
    contact.resolveVelocity dt

  # Internal: hook for post-integration updates
  postIntegrate: ->

  # Naive version: returns all unique pairs of bodies with overlapping AABB's.
  # TODO: use AABB to build quadtree?
  broadPhaseCollisions: ->
    return [] if @bodies.length < 2
    pairs = []
    for i in [0..(@bodies.length-2)]
      for j in [(i+1)..(@bodies.length-1)]
        a = @bodies[i]
        b = @bodies[j]
        if Utils.aabbOverlap a.aabb(), b.aabb()
          pairs.push [a, b]
    pairs

  narrowPhaseCollisions: (pairs) ->
    contacts = []
    for [a, b] in pairs
      contacts = contacts.concat(b.contactPoints a)
    contacts

  draw: =>
    for body in @bodies
      body.draw @display
      body.drawDebug @display, @debugSettings
    @stats.update()

window.WrappedWorld = class WrappedWorld extends World

  constructor: (element, @sizeX, @sizeY, opts={}) ->
    super element, opts
    @display = new WrappedDisplay @ctx, [@sizeX/2, @sizeY/2], @sizeX, @sizeY, @scale

  addBody: (body) ->
    super @constrainBody body

  postIntegrate: ->
    for body in @bodies
      @constrainBody body

  draw: =>
    super()
    @display.drawBounds()

  constrainBody: (body) ->
    body.position = @constrainPosition body.position
    body

  constrainPosition: ([x,y]) ->
    x += @sizeX while x <= 0
    y += @sizeY while y <= 0
    [x % @sizeX, y % @sizeY]

