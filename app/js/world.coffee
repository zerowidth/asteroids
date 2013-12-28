window.World = class World
  constructor: (@display, opts={}) ->
    @speedFactor    = opts.speedFactor or 1
    @paused         = opts.paused or false
    @pauseEveryStep = opts.pauseEveryStep or false
    @pauseOnContact = opts.pauseOnContact or false

    @bodies = []
    @particles = []
    @slow = false

    @camera1 = @camera2 = @cameraDelta = [0, 0]

  keydown: (e) =>
    if e.keyCode is 16 # shift
      @slow = true

  keyup: (e) =>
    if e.keyCode is 16 # shift
      @slow = false
    if e.keyCode is 80 # p
      @paused = !@paused

  mousedown: (mouse) =>
  mouseup: (mouse) =>
  click: (mouse) =>

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

  track: (target) ->
    if target
      @tracking = target
      @camera1 = @camera2 = @tracking.position
    else
      if @tracking
        @tracking = {position: @tracking.position}
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
      body.update dt
      body.integrate dt
      @quadtree.insert body, body.aabb()

    for particle in @particles
      particle.integrate dt

    @postIntegrate()

    @contacts = @narrowPhaseCollisions @broadPhaseCollisions()
    @particleContacts = @generateParticleContacts()

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
        continue if body is @tracking
        body.position = Vec.add body.position, delta
      for particle in @particles
        continue if body is @tracking
        particle.position = Vec.add particle.position, delta
      @tracking.position = Vec.add @tracking.position, delta
      @camera1 = Vec.add @camera1, delta
      @camera2 = Vec.add @camera2, delta
      @cameraDelta = delta

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
      bodiesByType = _.groupBy @bodies, 'renderWith'
      byColor = _.groupBy(bodiesByType.polygon or [], 'color')

      _.each byColor, (bodies, color) =>
        polygons = (body.vertices() for body in bodies)
        centers = (body.position for body in bodies)
        lineColor = bodies[0].lineColor
        @display.drawPolygons polygons, color, lineColor

      for body in bodiesByType.custom or []
        body.draw @display

      for particle in @particles
        particle.draw @display

      if @tracking and @debugSettings.drawCamera
        @display.drawCircle @camera1, 3, "#0FF"
        @display.drawCircle @camera2, 3, "#0AF"

    body.drawDebug(@display, @debugSettings) for body in @bodies

window.WrappedWorld = class WrappedWorld extends World

  constructor: (@display, @sizeX, @sizeY, @scale, opts={}) ->
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

  constructor: (args...) ->
    super args...
    @createStarfield()
    @reset()

  keydown: (e) ->
    super e
    return if @paused or @ship.dead

    switch e.keyCode
      when 16 # shift
        @ship.controls.targeting = true
      when 37 # left
        @ship.controls.left = true
      when 39 # right
        @ship.controls.right = true
      when 38 # up
        @ship.controls.thrust = true
      when 32, 40 # space, down
        v = Vec.scale @ship.orientation, 5
        @fireMissile @ship.tip(), Vec.add(@ship.velocity, v), 3
      when 73 # i
        @ship.toggleInvincibility()
      when 81 # q
        @explodeShip()
      when 88 # x
        v = Vec.scale @ship.orientation, 5
        @fireMissile @ship.tip(), Vec.add(@ship.velocity, v), 5, true
      when 90 # z
        for angle in [-Math.PI/8, -Math.PI/16, 0, Math.PI/16, Math.PI/8]
          v = Rotation.add @ship.orientation, Rotation.fromAngle angle
          v = Vec.scale v, 5
          @fireMissile @ship.tip(), Vec.add(@ship.velocity, v), 3

  keyup: (e) ->
    super e
    return if @paused or @ship.dead
    switch e.keyCode
      when 16 # shift
        @ship.controls.targeting = false
      when 37 # left
        @ship.controls.left = false
      when 39 # right
        @ship.controls.right = false
      when 38 # up
        @ship.controls.thrust = false


  update: (dt) ->
    super dt
    return if @paused
    @updateStarfield @cameraDelta if Vec.magnitudeSquared(@cameraDelta) > 0
    @updateDamage()

    return if @ship.dead
    if @ship.invincible and Utils.random() < 0.1
      @explosionAt @ship.position, size: 1, count: 1, color: @ship.lineColor

  draw: =>
    for stars in @starfield
      @display.drawCircle point, size, color for [point, size, color] in stars
    super()
    @drawDamage()

  collisions: (contacts) ->
    for contact in contacts
      if contact.from.ship or contact.to.ship
        continue if contact.from.dead or contact.to.dead

        maxSepV = if @ship.invincible then -3 else -1.5

        if contact.originalSepV > maxSepV
          color = if contact.from.ship
            contact.to.lineColor
          else
            contact.from.lineColor
          @explosionAt contact.position, color: color, count: 5, size: 1
          unless @ship.invincible
            @damageFlash contact.originalSepV / maxSepV
        else
          @explodeShip() unless @ship.invincible
          if contact.from.ship
            @explodeAsteroid contact.to, contact.position
          else
            @explodeAsteroid contact.from, contact.position

  particleCollisions: (contacts) ->
    for contact in contacts
      body     = contact.body
      particle = contact.particle

      continue if body.ship or contact.body.deleted
      contact.particle.alive = false

      if contact.particle.spawnMore
        num = Utils.randomInt(10, 25)
        for i in [0..num]
          direction = Rotation.fromAngle Utils.random() * Math.PI * 2
          velocity = Vec.scale direction, 2.5 + Utils.random() * 2.5
          @fireMissile contact.particle.position, velocity, 3

      @explodeAsteroid contact.body, particle.position
      contact.body.deleted = true

  explodeAsteroid: (body, point) ->
    body.dead = true
    @removeBody body
    @explosionAt point
    added = @addShards point, body.shatter point
    for shard in added
      if Geometry.pointInsidePolygon point, shard.vertices()
        @removeBody shard
        shards = shard.shatter point, body
        added = added.concat @addShards point, shards

  explodeShip: ->
    return if @ship.dead

    @explosionAt @ship.position
    @damageFlash 1
    for vertex in @ship.vertices()
      @explosionAt vertex
    for shard in @ship.shards @ship.position
      @bodyExplosion @ship.position, [0, 0], shard, @ship.color

    @ship.dead = true
    @track null
    @removeBody @ship

    setTimeout @restoreShip, 3000

  restoreShip: =>
    @ship.dead = false
    @ship.orientation = Rotation.fromAngle Math.PI/2
    @ship.position = @center()
    @ship.velocity = [0, 0]
    @ship.angularVelocity = 0
    @ship.controls = new ShipControls

    @explosionAt @ship.position, color: "#8CF", count: 100

    @addBody @ship
    @track @ship

  addShards: (position, shards) ->
    added = []
    for shard in shards
      if shard.area > @ship.area
        @addBody shard
        added.push shard
      else
        @bodyExplosion shard.position, shard.velocity, shard.vertices(), shard.color
    added

  explosionAt: (position, opts = {}) ->
    color = opts.color # null as default is fine
    count = opts.count or 50
    size = opts.size or 2

    num = Utils.randomInt(count / 2, count)
    for i in [0..num]
      direction = Rotation.fromAngle Utils.random() * Math.PI * 2
      speed = Utils.random() * 2
      green = Utils.randomInt(0, 255)
      c = color or "rgba(255,#{green},32,1)"

      @addParticle new Particle
        lifespan: Utils.random()
        size: size
        position: position
        velocity: Vec.scale direction, speed
        color: c
        fade: true

  bodyExplosion: (position, velocity, vertices, color) ->
    for point in vertices
      inward = Vec.normalize Vec.sub position, point
      v = Vec.add velocity, Vec.scale inward, Utils.random()

      @addParticle new Particle
        lifespan: 1 + Utils.random()
        size: 2
        position: position
        velocity: v
        color: color
        fade: true

  fireMissile: (position, velocity, size, spawnMore = false) ->
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

  createStarfield: ->
    colors = ["#FDD", "#DFD", "#DDF"]
    @starfield = for i in [0..3]
      count = @sizeX * @scale * @sizeY * @scale / 10000
      for i in [0..count]
        x = Utils.random() * @sizeX
        y = Utils.random() * @sizeY
        size = if Utils.random() < 0.1 then 2 else 1
        n = Utils.randomInt(0,10)
        color = if n > 2 then "#FFF" else colors[n]
        [[x, y], size, color]

  updateStarfield: (delta) ->
    n = (@starfield.length + 1) * 0.1
    for stars, i in @starfield
      delta = Vec.scale delta, n - 0.1 * i
      for star in stars
        star[0] = @constrainPosition Vec.add star[0], delta

  damageFlash: (@damage) ->

  updateDamage: ->
    @damage = @damage - 0.01
    @damage = 0 if @damage < 0.01

  drawDamage: ->
    if @damage > 0
      alpha = Math.floor(@damage / 1.5 * 100) / 100
      green = Math.floor (1 - @damage) * 255
      color = "rgba(255,#{green},32,#{alpha})"
      @display.fillBounds color, alpha

  # Reset this world, generating new asteroids, etc.
  reset: ->
    @removeAllBodies()
    @removeAllParticles()
    @generateAsteroids()
    @createShip()

  generateAsteroids: ->
    avgSize = sizeDelta = 3
    deltaVelocity = 3
    deltaTheta = Math.PI

    searchRadius = avgSize - sizeDelta / 2.5
    for pos, i in Utils.distributeRandomPoints [0, 0], [@sizeX, @sizeY], searchRadius, [@center()]
      continue if i is 0
      size = avgSize + Utils.random(sizeDelta) - sizeDelta/2

      density = Utils.randomInt(0,4)
      lineColor = Math.floor(192 - density * 32)
      color = Math.floor(96 - density * 16)

      @addBody new Asteroid size,
        position: pos
        velocity: [
          Utils.random(deltaVelocity) - deltaVelocity / 2,
          Utils.random(deltaVelocity) - deltaVelocity / 2
        ]
        angularVelocity: Utils.random(deltaTheta) - deltaTheta / 2
        density: 10 + 5 * density
        color: "rgba(#{color},#{color},#{color},1)"
        lineColor: "rgba(#{lineColor},#{lineColor},#{lineColor},1)"

  createShip: ->
    @ship = new Ship 0.3,
      position: @center()
      angle: Math.PI/2
      density: 5
      thrust: 6
      turn: 5

    # make the ship more resistant to spinning (helps with bounces)
    @ship.inverseMoment = @ship.inverseMoment / 4

    @addBody @ship
    @track @ship
