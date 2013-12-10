window.World = class World
  constructor: (@display, opts={}) ->
    @speedFactor    = opts.speedFactor or 1
    @paused         = opts.paused or false
    @pauseEveryStep = opts.pauseEveryStep or false
    @pauseOnContact = opts.pauseOnContact or false

    @keyboard = new KeyboardControls

    @stats = Utils.drawStats()

    @bodies = []
    @particles = []
    @slow = false

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
    drawCamera: false
    drawQuadtree: false

  addBody: (body) -> @bodies.push body
  removeBody: (body) -> @bodies = _.without(@bodies, body)
  removeAllBodies: -> @bodies = []

  addParticle: (particle) -> @particles.push particle
  removeParticle: (particle) -> _.without(@particles, particle)
  removeAllParticles: -> @particles = []

  track: (@tracking) ->
    if @tracking
      @camera1 = @camera2 = @tracking.position
    else
      @camera1 = @camera2 = @center()

  center: -> [@sizeX/2, @sizeY/2]

  # Public: update callback. dt is raw javascript time delta in ms.
  update: (dt) ->
    return if @paused

    dt = dt / 1000 * @speedFactor
    dt = dt / 5 if @slow

    for body in @bodies
      body.prepare()
      body.resetDebug()
      body.integrate dt, @keyboard

    for particle in @particles
      particle.integrate dt

    @particles = (p for p in @particles when p.alive)

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

    if @tracking
      # camera moves 10% toward the target
      distance = Vec.sub @tracking.position, @camera1
      @camera1 = Vec.add @camera1, Vec.scale distance, 0.1

      distance = Vec.sub @camera1, @camera2
      @camera2 = Vec.add @camera2, Vec.scale distance, 0.1

      delta = Vec.sub @center(), @camera2
      for body in @bodies
        body.position = Vec.add body.position, delta
      for particle in @particles
        particle.position = Vec.add particle.position, delta
      @camera1 = Vec.add @camera1, delta
      @camera2 = Vec.add @camera2, delta

  resolveInterpenetration: (contact) ->
    contact.resolveInterpenetration()

  resolveVelocity: (contact, dt) ->
    contact.resolveVelocity dt

  # Internal: hook for post-integration updates
  postIntegrate: ->

  # Naive version: returns all unique pairs of bodies with overlapping AABB's.
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

  draw: ->

    @display.drawClipped =>
      # for particle in @particles
      #   particle.draw @display

      bodiesByType = _.groupBy @bodies, 'renderWith'
      byColor = _.groupBy(bodiesByType.polygon or [], 'color')

      _.each byColor, (bodies, color) =>
        polygons = (body.vertices() for body in bodies)
        centers = (body.position for body in bodies)
        @display.drawPolygons polygons, color
        @display.drawCircles centers, 2, "#444"

      for body in bodiesByType.custom or []
        body.draw @display

      if @tracking and @debugSettings.drawCamera
        @display.drawCircle @camera1, 3, "#0FF"
        @display.drawCircle @camera2, 3, "#0AF"

    @stats.update()

window.WrappedWorld = class WrappedWorld extends World

  constructor: (@display, @sizeX, @sizeY, opts={}) ->
    super @display, opts

  addBody: (body) -> super @constrain body
  addParticle: (particle) -> super @constrain particle

  postIntegrate: ->
    for body in @bodies
      @constrain body
    for particle in @particles
      @constrain particle

  draw: =>
    super()
    @display.drawBounds()

    if @debugSettings.drawQuadtree
      midpoints = []
      @quad.walk (node) =>
        if node.nodes
          midpoints.push [[node.left, node.yMidpoint], [node.right, node.yMidpoint]]
          midpoints.push [[node.xMidpoint, node.bottom], [node.xMidpoint, node.top]]
        true
      for [start, end] in midpoints
        @display.drawLine start, end, 0.5, "#8F8"

  # Returns an array of arrays containing:
  # [ body A, body B, offset x, offset y ]
  # where the offset applies to body A for the sake of contact generation.
  broadPhaseCollisions: ->
    return [] if @bodies.length < 2

    @quad = new QuadTree [0, 0], [@sizeX, @sizeY]
    @quad.insert body, body.aabb() for body in @bodies

    pairs = []
    for body in @bodies
      xOffsets = [0]
      yOffsets = [0]
      boundingBox = body.aabb()

      xOffsets.push  @sizeX if boundingBox[0][0] < 0
      xOffsets.push -@sizeX if boundingBox[1][0] > @sizeX
      yOffsets.push -@sizeY if boundingBox[1][1] > @sizeY
      yOffsets.push  @sizeY if boundingBox[0][1] < 0

      for x in xOffsets
        for y in yOffsets
          offsetBounds = (Vec.add [x,y], corner for corner in boundingBox)
          found = @quad.intersecting offsetBounds
          found = _.uniq found
          for candidate in found
            continue if candidate is body
            if Utils.aabbOverlap boundingBox, candidate.aabb(), [x, y]
              pairs.push [body, candidate, x, y]

    pairs

  narrowPhaseCollisions: (pairs) ->
    contacts = []
    for [a, b, offsetX, offsetY] in pairs
      contacts.push contact for contact in a.contactPoints b, [offsetX, offsetY]
    contacts

  resolveInterpenetration: (contact) ->
    contact.resolveInterpenetration()

  resolveVelocity: (contact, dt) ->
    contact.resolveVelocity dt

  constrain: (body) ->
    body.position = @constrainPosition body.position
    body

  constrainPosition: ([x,y]) ->
    x += @sizeX while x <= 0
    y += @sizeY while y <= 0
    [x % @sizeX, y % @sizeY]

