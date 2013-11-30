window.World = class World
  constructor: (element) ->
    @ctx = Sketch.create
      element: document.getElementById element
      retina: true
    @stats = Utils.drawStats()
    @display = new Display @ctx, [0, 0], 50

    @bodies = []
    @slow = false
    @paused = true

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

  addBody: (body) ->
    @bodies.push body

  removeBody: (body) ->
    @bodies = _without(@bodies, body)

  update: =>
    return if @paused

    dt = @ctx.dt / 1000
    dt = dt / 5 if @slow

    for body in @bodies
      body.reset()
      body.resetDebug()
      body.integrate dt

    @contacts = @narrowPhaseCollisions @broadPhaseCollisions()

    if @contacts.length > 0
      for n in [1..@contacts.length*2] # loop contacts * 2 times
        worst = null
        for contact in @contacts
          if not worst or contact.depth > worst.depth
            worst = contact
        break if worst.depth <= 0
        worst.resolveInterpenetration()

      for n in [1..@contacts.length*2]
        worst = null
        worstSepV = null
        for contact in @contacts
          sepV = contact.separatingVelocity()
          if not worst or sepV < worstSepV
            worst     = contact
            worstSepV = sepV

        break if worstSepV > 0
        worst.resolveVelocity dt

      # @paused = true

  # Naive version: returns all unique pairs of bodies, nothing more. TODO: use
  # (memoized?) AABBs to build quadtree, then iterate and compare bounding boxes
  # for overlap.
  broadPhaseCollisions: ->
    pairs = []
    for i in [0..(@bodies.length-2)]
      for j in [(i+1)..(@bodies.length-1)]
        pairs.push [@bodies[i], @bodies[j]]
    pairs

  narrowPhaseCollisions: (pairs) ->
    contacts = []
    for [a, b] in pairs
      contacts = contacts.concat(b.contactPoints a)
    contacts

  draw: =>
    for body in @bodies
      body.draw @display
      body.drawDebug @display
    @stats.update()


