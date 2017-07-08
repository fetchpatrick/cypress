_ = require("lodash")
$ = require("jquery")
Promise = require("bluebird")

$Log = require("../../../cypress/log")
$utils = require("../../../cypress/utils")

findScrollableParent = ($el, win) ->
  $parent = $el.parent()

  ## if we're at the body, we just want to pass in
  ## window into jQuery scrollTo
  if $parent.is("body,html") or $utils.hasDocument($parent)
    return win

  return $parent if $Cypress.Dom.elIsScrollable($parent)

  findScrollableParent($parent, win)

isNaNOrInfinity = (item) ->
  num = Number.parseFloat(item)

  return _.isNaN(num) or !_.isFinite(num)

create = (Cypress, Commands) ->
  Commands.addAll({ prevSubject: "dom" }, {
    scrollIntoView: (subject, options = {}) ->
      if !_.isObject(options)
        $utils.throwErrByPath("scrollIntoView.invalid_argument", {args: { arg: options }})

      ## ensure the subject is not window itself
      ## cause how are you gonna scroll the window into view...
      if subject is @state("window")
        $utils.throwErrByPath("scrollIntoView.subject_is_window")

      ## throw if we're trying to scroll to multiple elements
      if subject.length > 1
        $utils.throwErrByPath("scrollIntoView.multiple_elements", {args: { num: subject.length }})

      _.defaults options,
        $el: subject
        $parent: @state("window")
        log: true
        duration: 0
        easing: "swing"
        axis: "xy"

      ## figure out the options which actually change the behavior of clicks
      deltaOptions = $utils.filterOutOptions(options)

      ## here we want to figure out what has to actually
      ## be scrolled to get to this element, cause we need
      ## to scrollTo passing in that element.
      options.$parent = findScrollableParent(options.$el, @privateState("window"))

      if options.$parent is @privateState("window")
        parentIsWin = true
        ## jQuery scrollTo looks for the prop contentWindow
        ## otherwise it'll use the wrong window to scroll :(
        options.$parent.contentWindow = options.$parent

      ## if we cannot parse an integer out of duration
      ## which could be 500 or "500", then it's NaN...throw
      if isNaNOrInfinity(options.duration)
        $utils.throwErrByPath("scrollIntoView.invalid_duration", {args: { duration: options.duration }})

      if !(options.easing is "swing" or options.easing is "linear")
        $utils.throwErrByPath("scrollIntoView.invalid_easing", {args: { easing: options.easing }})

      if options.log
        deltaOptions = $utils.filterOutOptions(options, {duration: 0, easing: 'swing', offset: {left: 0, top: 0}})

        log = {
          $el: options.$el
          message: deltaOptions
          consoleProps: ->
            obj = {
              ## merge into consoleProps without mutating it
              "Applied To": $utils.getDomElements(options.$el)
              "Scrolled Element": $utils.getDomElements(options.$el)
            }

            return obj
        }

        options._log = $Log.command(log)

      if not parentIsWin
        ## scroll the parent into view first
        ## before attemp
        options.$parent[0].scrollIntoView()

      return new Promise (resolve, reject) =>
        ## scroll our axes
        $(options.$parent).scrollTo(options.$el, {
          axis:     options.axis
          easing:   options.easing
          duration: options.duration
          offset:   options.offset
          done: (animation, jumpedToEnd) ->
            resolve(options.$el)
          fail: (animation, jumpedToEnd) ->
            ## its Promise object is rejected
            try
              $utils.throwErrByPath("scrollTo.animation_failed")
            catch err
              reject(err)
          always: ->
            if parentIsWin
              delete options.$parent.contentWindow
        })
  })

  Commands.addAll({ prevSubject: "optional" }, {
    scrollTo: (subject, xOrPosition, yOrOptions, options = {}) ->
      ## check for undefined or null values
      if not xOrPosition?
        $utils.throwErrByPath "scrollTo.invalid_target", {args: { x }}

      switch
        when _.isObject(yOrOptions)
          options = yOrOptions
        else
          y = yOrOptions

      position = null

      ## we may be '50%' or 'bottomCenter'
      if _.isString(xOrPosition)
        ## if there's a number in our string, then
        ## don't check for positions and just set x
        ## this will check for NaN, etc - we need to explicitly
        ## include '0%' as a use case
        if (Number.parseFloat(xOrPosition) or Number.parseFloat(xOrPosition) is 0)
          x = xOrPosition
        else
          position = xOrPosition
          ## make sure it's one of the valid position strings
          @ensureValidPosition(position)
      else
        x = xOrPosition

      switch position
        when 'topLeft'
          x = 0       # y = 0
        when 'top'
          x = '50%'   # y = 0
        when 'topRight'
          x = '100%'  # y = 0
        when 'left'
          x = 0
          y = '50%'
        when 'center'
          x = '50%'
          y = '50%'
        when 'right'
          x = '100%'
          y = '50%'
        when 'bottomLeft'
          x = 0
          y = '100%'
        when 'bottom'
          x = '50%'
          y = '100%'
        when 'bottomRight'
          x = '100%'
          y = '100%'

      y ?= 0
      x ?= 0

      if subject
        ## if they passed something here, need to ensure it's DOM
        @ensureDom(subject)
        $container = subject
      else
        isWin = true
        ## if we don't have a subject, then we are a parent command
        ## assume they want to scroll the entire window.
        $container = @privateState("window")

        ## jQuery scrollTo looks for the prop contentWindow
        ## otherwise it'll use the wrong window to scroll :(
        $container.contentWindow = $container

      ## throw if we're trying to scroll multiple containers
      if $container.length > 1
        $utils.throwErrByPath("scrollTo.multiple_containers", {args: { num: $container.length }})

      _.defaults options,
        $el: $container
        log: true
        duration: 0
        easing: "swing"
        axis: "xy"
        x: x
        y: y

      ## if we cannot parse an integer out of duration
      ## which could be 500 or "500", then it's NaN...throw
      if isNaNOrInfinity(options.duration)
        $utils.throwErrByPath("scrollTo.invalid_duration", {args: { duration: options.duration }})

      if !(options.easing is "swing" or options.easing is "linear")
        $utils.throwErrByPath("scrollTo.invalid_easing", {args: { easing: options.easing }})

      ## if we cannot parse an integer out of y or x
      ## which could be 50 or "50px" or "50%" then
      ## it's NaN/Infinity...throw
      if isNaNOrInfinity(options.y) or isNaNOrInfinity(options.x)
        $utils.throwErrByPath("scrollTo.invalid_target", {args: { x, y }})

      if options.log
        deltaOptions = $utils.filterOutOptions(options, {duration: 0, easing: 'swing'})

        log = {
          message: deltaOptions
          consoleProps: ->
            obj = {
              ## merge into consoleProps without mutating it
              "Scrolled Element": $utils.getDomElements(options.$el)
            }

            return obj
        }

        if !isWin then log.$el = options.$el

        options._log = $Log.command(log)

      ensureScrollability = =>
        try
          ## make sure our container can even be scrolled
          @ensureScrollability($container, "scrollTo")
        catch err
          options.error = err
          @_retry(ensureScrollability, options)

      Promise
      .try(ensureScrollability)
      .then =>
        return new Promise (resolve, reject) =>
          ## scroll our axis'
          $(options.$el).scrollTo({left: x, top: y}, {
            axis:     options.axis
            easing:   options.easing
            duration: options.duration
            done: (animation, jumpedToEnd) ->
              resolve(options.$el)
            fail: (animation, jumpedToEnd) ->
              ## its Promise object is rejected
              try
                $utils.throwErrByPath("scrollTo.animation_failed")
              catch err
                reject(err)
          })

          if isWin
            delete options.$el.contentWindow
  })

module.exports = {
  create
}
