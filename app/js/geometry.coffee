window.Geometry = Geometry =
  transform: (vertices, offset) ->
    (Vec.add vertex, offset for vertex in vertices)

  contactPoints: (polygonA, polygonB, offset = [0, 0]) ->
    minAxis = @minimumSeparationAxis polygonA, polygonB, offset
    return [] unless minAxis

    e1 = @bestEdge @transform(polygonA.vertices(), offset), minAxis
    e2 = @bestEdge polygonB.vertices(), Vec.invert minAxis # A->B always

    # Now, clip the edges. The reference edge is most perpendicular to contact
    # axis, and will be used to clip the incident edge vertices to generate the
    # contact points.
    if Math.abs(e1.dot(minAxis)) <= Math.abs(e2.dot(minAxis))
      reference = e1
      incident  = e2
    else
      reference = e2
      incident  = e1

    polygonA.debug.reference = reference
    polygonA.debug.incident = incident

    reference.normalize()

    offset1 = reference.dot reference.from
    # clip the incident edge by the first vertex of the reference edge
    first = @clip incident.from, incident.to, reference, offset1
    return [] if first.length < 2 # if we don't have 2 points left, then fail
    polygonA.debug.first = first

    # clip what's left of the incident edge by second vertex of reference edge
    # clipping in opposite direction, so flip direction and offset
    o2 = reference.dot reference.to
    reference.invert()
    clipped = @clip first[0], first[1], reference, -o2
    return [] if clipped.length < 2
    reference.invert() # put it back (FIXME: stop using objects here)

    polygonA.debug.clipped = clipped

    # get the reference edge normal
    refNorm = Vec.perpendicularNormal reference.vec

    # find the largest depth
    maxDepth = Vec.dotProduct refNorm, reference.deepest
    contactNormal = Vec.invert minAxis # so it's B->A
    contacts = []

    # Calculate depth for each clipped point and return only those which are
    # nonzero (that is, aren't on the other side of the reference edge)
    for point in clipped
      depth = Vec.dotProduct(refNorm, point) - maxDepth
      if depth >= 0
        contacts.push new Contact(polygonA, polygonB, point, contactNormal, depth, offset)

    if contacts[1]
      contacts[0].related = contacts[1]
      contacts[1].related = contacts[0]

    polygonA.debug.contacts = contacts

    contacts

  # clip the line segment from v1 to v2 if they are beyond offset along normal
  clip: (v1, v2, normal, offset) ->
    points = []
    d1 = normal.dot(v1) - offset
    d2 = normal.dot(v2) - offset
    points.push v1 if d1 >= 0
    points.push v2 if d2 >= 0

    # check if they are on opposing sides of the offset
    if d1 * d2 < 0
      # different sides, figure out which one we're clipping, and clip it
      e = Vec.sub v2, v1
      u = d1 / (d1 - d2)
      e = Vec.scale e, u
      e = Vec.add e, v1
      points.push e

    points

  # Calculate the best edge (deepest perpendicular edge given a separation axis)
  bestEdge: (vertices, minAxis) ->
    # Find deepest vertex in the polygon along separation axis
    deepestIndex = null
    maxProjection = -Infinity
    for vertex, i in vertices
      projection = Vec.dotProduct minAxis, vertex
      if projection > maxProjection
        maxProjection = projection
        deepestIndex = i

    # Find edge which is most perpendicular to separation axis
    deepest    = vertices[ deepestIndex ]
    prevVertex = vertices[ (deepestIndex - 1 + vertices.length) % vertices.length ]
    nextVertex = vertices[ (deepestIndex + 1 + vertices.length) % vertices.length ]

    # vectors pointing at the deepest vertex
    left  = Vec.sub deepest, prevVertex
    right = Vec.sub deepest, nextVertex

    if Vec.dotProduct(right, minAxis) <= Vec.dotProduct(left, minAxis)
      new Edge deepest, deepest, nextVertex # right edge is better
    else
      new Edge deepest, prevVertex, deepest # left edge is better

  # Use Separating Axis Theorem to find minimum separation axis
  # from http://www.codezealot.org/archives/55 &c.
  minimumSeparationAxis: (polygonA, polygonB, offset) ->
    minAxis    = null
    minOverlap = Infinity

    for axis in @perpendicularAxes @transform polygonA.vertices(), offset
      us      = @projectionInterval @transform(polygonA.vertices(), offset), axis
      them    = @projectionInterval polygonB.vertices(), axis
      overlap = Utils.intervalOverlap us, them
      return false unless overlap > 0
      if overlap < minOverlap
        minOverlap = overlap
        minAxis = axis

    for axis in @perpendicularAxes polygonB.vertices()
      us      = @projectionInterval @transform(polygonA.vertices(), offset), axis
      them    = @projectionInterval polygonB.vertices(), axis
      overlap = Utils.intervalOverlap us, them
      return false unless overlap > 0
      if overlap < minOverlap
        minOverlap = overlap
        minAxis = axis

    dir = Vec.sub polygonB.position, Vec.add(polygonA.position, offset)
    if Vec.dotProduct(dir, minAxis) < 0
      minAxis = Vec.invert minAxis # separation axis is always A->B

    polygonA.debug.minAxis =
      from: Vec.add offset, polygonA.position,
      to:   Vec.add offset, Vec.add polygonA.position, minAxis
    minAxis

  projectionInterval: (vertices, axis) ->
    Utils.projectionInterval vertices, axis

  perpendicularAxes: (vertices) ->
    for pair in Utils.sequentialPairs vertices
      Vec.perpendicularNormal Vec.sub pair[1], pair[0]

class Edge
  constructor: (@deepest, @from, @to) ->
    @vec = Vec.sub @to, @from
  dot: (other) ->
    Vec.dotProduct @vec, other
  normalize: ->
    @vec = Vec.normalize @vec
  invert: ->
    @vec = Vec.invert @vec

