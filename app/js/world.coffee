window.World = class World
  constructor: (@display, opts={}) ->
    @speedFactor    = opts.speedFactor or 1
    @paused         = opts.paused or false
    @pauseEveryStep = opts.pauseEveryStep or false
    @pauseOnContact = opts.pauseOnContact or false

    @keyboard = new KeyboardControls

    # @stats = Utils.drawStats()

    @bodies = []
    @particles = []
    @slow = false

  keydown: (e) =>
    @keyboard.keydown e
    @slow = @keyboard.shift

  keyup: (e) =>
    @keyboard.keyup e
    @slow = @keyboard.shift
    if e.keyCode is 80 # p
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

    @quadtree = new QuadTree [0, 0], [@sizeX, @sizeY]

    for body in @bodies
      body.prepare()
      body.resetDebug()
      body.integrate dt, @keyboard
      @quadtree.insert body, body.aabb()

    for particle in @particles
      particle.integrate dt

    @postIntegrate()

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

    @particleContacts = @generateParticleContacts()

    # post-process collisions:
    @particleCollisions @particleContacts
    @collisions @contacts

    @paused = true if @pauseOnContact and
      (@contacts.length > 0 or @particleContacts.length > 0)
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

    @cleanup()

  # Internal: hook for post-integration updates
  postIntegrate: ->

  # Internal: hook for processing contacts after position/velocity has been
  # resolved.
  #
  # contacts - an Array of Contact objects
  collisions: (contacts) ->

  # Internal: hook for processing polygon/body collisions, if present
  #
  # contacts - an Array of ParticleContact objects
  particleCollisions: (contacts) ->

  # Internal: generate particle->body contacts
  generateParticleContacts: ->
    contacts = []
    for particle in @particles
      continue unless particle.collides
      for body in @quadtree.atPoint particle.position
        if Geometry.pointInsidePolygon particle.position, body.vertices()
          contacts.push new ParticleContact particle, body
    contacts

  # Internal: hook for cleanup after everything has been updated
  cleanup: ->
    @particles = (p for p in @particles when p.alive)

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
      for particle in @particles
        particle.draw @display

      bodiesByType = _.groupBy @bodies, 'renderWith'
      byColor = _.groupBy(bodiesByType.polygon or [], 'color')

      _.each byColor, (bodies, color) =>
        polygons = (body.vertices() for body in bodies)
        centers = (body.position for body in bodies)
        @display.drawPolygons polygons, color

      for body in bodiesByType.custom or []
        body.draw @display

      if @tracking and @debugSettings.drawCamera
        @display.drawCircle @camera1, 3, "#0FF"
        @display.drawCircle @camera2, 3, "#0AF"

    body.drawDebug(@display, @debugSettings) for body in @bodies

    # @stats.update()

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
      @quadtree.walk (node) =>
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
          bottomLeft = Vec.add [x, y], boundingBox[0]
          topRight   = Vec.add [x, y], boundingBox[1]
          for candidate in @quadtree.intersecting [bottomLeft, topRight]
            continue if candidate is body
            if Utils.aabbOverlap boundingBox, candidate.aabb(), [x, y]
              pairs.push [body, candidate, x, y]
    pairs

  narrowPhaseCollisions: (pairs) ->
    contacts = []
    for [a, b, offsetX, offsetY] in pairs
      contacts.push contact for contact in a.contactPoints b, [offsetX, offsetY]
    contacts

  # Internal: generate particle->body contacts, but with wrapping
  # TODO this needs to involve the quadtree.
  # generateParticleContacts: ->

  constrain: (body) ->
    body.position = @constrainPosition body.position
    body

  constrainPosition: ([x,y]) ->
    x += @sizeX while x <= 0
    y += @sizeY while y <= 0
    [x % @sizeX, y % @sizeY]


window.AsteroidWorld = class AsteroidWorld extends WrappedWorld

  keydown: (e) ->
    super e
    if e.keyCode is 32 or e.keyCode is 40 # space or down
      v = Vec.scale @ship.orientation, 5
      @fireMissile @ship.tip(), Vec.add @ship.velocity, v
    if e.keyCode is 88 # x
      v = Vec.scale @ship.orientation, 3
      @fireMissile @ship.tip(), Vec.add(@ship.velocity, v), 5, true

  collisions: (contacts) ->
    bumped = []
    for contact in contacts
      if contact.from.ship
        bumped.push contact.to
      if contact.to.ship
        bumped.push contact.from

    for asteroid in _.uniq bumped
      asteroid.toggleColor asteroid.originalColor

  particleCollisions: (contacts) ->
    for contact in contacts
      body     = contact.body
      particle = contact.particle

      continue if body.ship
      contact.particle.alive = false
      continue if contact.body.deleted

      if contact.particle.spawnMore
        num = Utils.randomInt(10, 25)
        for i in [0..num]
          direction = Rotation.fromAngle Utils.random() * Math.PI * 2
          velocity = Vec.scale direction, 2.5 + Utils.random() * 2.5
          @fireMissile contact.particle.position, velocity

      @explosionAt particle.position
      @removeBody contact.body
      contact.body.deleted = true
      added = @addShards particle.position, body.shatter particle.position
      for shard in added
        if Geometry.pointInsidePolygon particle.position, shard.vertices()
          @removeBody shard
          shards = shard.shatter particle.position, body
          added = added.concat @addShards particle.position, shards

  addShards: (position, shards) ->
    added = []
    for shard in shards
      if shard.area > @ship.area
        @addBody shard
        added.push shard
      else
        for point in shard.vertices()
          inward = Vec.normalize Vec.sub shard.position, point
          velocity = Vec.add shard.velocity, Vec.scale inward, Utils.random()

          @addParticle new Particle
            lifespan: 1 + Utils.random()
            size: 2
            position: shard.position
            velocity: velocity
            color: shard.color
            fade: true
    added

  explosionAt: (position) ->
    num = Utils.randomInt(25, 50)
    for i in [0..num]
      direction = Rotation.fromAngle Utils.random() * Math.PI * 2
      speed = Utils.random() * 2
      green = Utils.randomInt(0, 255)
      color = "rgba(255,#{green},32,1)"

      @addParticle new Particle
        lifespan: 0.5 + Utils.random() * 0.5
        size: 2
        position: position
        velocity: Vec.scale direction, speed
        damping: 0.05
        color: color
        fade: true

  fireMissile: (position, velocity, size = 2, spawnMore = false) ->
    missile = new Particle
      lifespan: 1
      position: position
      velocity: velocity
      size: size
      color: "#4FA"
      fade: true
      collides: true
    missile.spawnMore = spawnMore
    @addParticle missile
