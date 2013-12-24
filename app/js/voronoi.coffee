window.Voronoi =
  generate: (points, boundingBox) ->
    siteEvents = (new SiteEvent point for point in points)
    getY = (e) -> e.y
    queue = new EventQueue siteEvents
    tree = new Tree

    until queue.empty?()
      event = queue.pop()
      console.log [event.x(), event.y()]

      # * locate existing arc, if any, above the new site.
      # * break the arc by replacing the leaf with a subtree representing the new
      #   arc and its breakpoints
      # * 

      # tree.insert new Edge event.site
      tree.insert new Arc event.site

    console.log tree

    []

class BreakPoint

class Arc
  constructor: (@site) ->

class Tree
  constructor: (root = null) ->
    @root  = root
    @left  = null
    @right = null
  insert: (event) ->
    if @root
      # noop yet
    else
      @root = event

class SiteEvent
  constructor: (@site) ->
  x: -> @site[0]
  y: -> @site[1]

class CircleEvent

class Site
  constructor: (@x, @y) ->

# This should be a heap or something, but eh, good enough.
class EventQueue
  constructor: (@events) ->
    @sort()
  push: (event) ->
    @events.push event
    @sort()
  pop: -> @events.pop()
  empty: -> @events.length == 0
  sort: -> @events = _.sortBy @events, ['y', 'x']
