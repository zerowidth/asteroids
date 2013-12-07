window.World = class World
  constructor: (element, opts={}) ->
    @scale          = opts.scale or 50
    @speedFactor    = opts.speedFactor or 1
    @paused         = opts.paused or false
    @pauseEveryStep = opts.pauseEveryStep or false
    @pauseOnContact = opts.pauseOnContact or false

    @keyboard = new KeyboardControls

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
        @keyboard.keydown e
        @slow = @keyboard.shift
      keyup: (e) =>
        @keyboard.keyup e
        @slow = @keyboard.shift
        switch e.keyCode
          when 32 # space
            @paused = !@paused

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

  track: (@tracking) ->

  center: -> [@sizeX/2, @sizeY/2]

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

    # move = [0, 0]
    # if @keyboard.left
    #   move[0] = -1
    # else if @keyboard.right
    #   move[0] = 1

    # if @keyboard.up
    #   move[1] = 1
    # else if @keyboard.down
    #   move[1] = -1

    # delta = Vec.invert Vec.scale move, dt * 5
    if @tracking
      delta = Vec.sub @center(), @tracking.position
      for body in @bodies
        body.position = Vec.add body.position, delta

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
    @display = new WrappedDisplay @ctx, @center(), @sizeX, @sizeY, @scale

  addBody: (body) ->
    super @constrainBody body

  postIntegrate: ->
    for body in @bodies
      @constrainBody body

  draw: =>
    super()
    @display.drawBounds()

  # Returns an array of arrays containing:
  # [ body A, body B, offset x, offset y ]
  # where the offset applies to body A for the sake of contact generation.
  broadPhaseCollisions: ->
    return [] if @bodies.length < 2
    pairs = []
    for i in [0..(@bodies.length-2)]
      for j in [(i+1)..(@bodies.length-1)]
        a = @bodies[i]
        b = @bodies[j]

        # Compare each pair of bodies: if their AABBs overlap each other either
        # directly or over a wrapped edge, check for contact.

        xOffsets = [0]
        yOffsets = [0]
        aBox = a.aabb()
        bBox = b.aabb()

        xOffsets.push  @sizeX if aBox[0][0] < 0      or bBox[1][0] > @sizeX
        xOffsets.push -@sizeX if aBox[1][0] > @sizeX or bBox[0][0] < 0
        yOffsets.push -@sizeY if aBox[1][1] > @sizeY or bBox[0][1] < 0
        yOffsets.push  @sizeY if aBox[0][1] < 0      or bBox[1][1] > @sizeY

        for x in xOffsets
          for y in yOffsets
            if Utils.aabbOverlap a.aabb(), b.aabb(), [x, y]
              pairs.push [a, b, x, y]
    pairs

  narrowPhaseCollisions: (pairs) ->
    contacts = []
    for [a, b, offsetX, offsetY] in pairs
      a.position = Vec.add a.position, [offsetX, offsetY]
      for contact in a.contactPoints b
        contact.offset = [offsetX, offsetY]
        contacts.push contact
      a.position = Vec.sub a.position, [offsetX, offsetY]
    contacts

  resolveInterpenetration: (contact) ->
    contact.from.position = Vec.add contact.from.position, contact.offset
    contact.resolveInterpenetration()
    contact.from.position = Vec.sub contact.from.position, contact.offset

  resolveVelocity: (contact, dt) ->
    contact.from.position = Vec.add contact.from.position, contact.offset
    contact.resolveVelocity dt
    contact.from.position = Vec.sub contact.from.position, contact.offset

  constrainBody: (body) ->
    body.position = @constrainPosition body.position
    body

  constrainPosition: ([x,y]) ->
    x += @sizeX while x <= 0
    y += @sizeY while y <= 0
    [x % @sizeX, y % @sizeY]

