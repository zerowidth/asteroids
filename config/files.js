/* Exports an object that defines
 *  all of the paths & globs that the project
 *  is concerned with.
 *
 * The "configure" task will require this file and
 *  then re-initialize the grunt config such that
 *  directives like <config:files.js.app> will work
 *  regardless of the point you're at in the build
 *  lifecycle.
 *
 * To see the default definitions for all of Lineman's file paths and globs, look at:
 * https://github.com/testdouble/lineman/blob/master/config/files.coffee
 */

module.exports = require(process.env['LINEMAN_MAIN']).config.extend('files', {
  coffee: {
    app: [
      "app/js/vector.coffee",
      "app/js/utils.coffee",
      "app/js/ship.coffee",
      "app/js/intersections.coffee",
      "app/js/particles.coffee",
      "app/js/physics.coffee"
    ]
  }
});
