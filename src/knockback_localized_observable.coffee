###
  knockback_localized_observable.js
  (c) 2011, 2012 Kevin Malakoff.
  Knockback.LocalizedObservable is freely distributable under the MIT license.
  See the following for full license details:
    https://github.com/kmalakoff/knockback/blob/master/LICENSE
###

####################################################
# Note: If you are deriving a class, you need to return the underlying observable rather than your instance since Knockout is expecting observable functions:
#   For example:
#     constructor: ->
#       super
#       return kb.utils.wrappedObservable(@)
#
# You can either provide a read or a read and write function in the options or on the class itself.
# Options (all optional)
#   * default - the value automatically returned when there is no value present. If there is no default, it will return ''
#   * read: (value, observable) - called to get the value and each time the locale changes
#   * write: (localized_string, value, observable) ->  - called to set the value (optional)
#   * onChange: (localized_string, value, observable) -> called when the value changes
####################################################

class kb.LocalizedObservable
  @extend = Backbone.Model.extend # from Backbone non-Coffeescript inheritance (use "kb.RefCountable_RCBase.extend({})" in Javascript instead of "class MyClass extends kb.RefCountable")

  constructor: (@value_holder, @options={}, @view_model={}) ->
    throw 'LocalizedObservable: options.read is missing' if not (@options.read or @read)
    throw 'LocalizedObservable: options.read and read class function exist. You need to choose one.' if @options.read and @read
    throw 'LocalizedObservable: options.write and write class function exist. You need to choose one.' if @options.write and @write
    throw 'LocalizedObservable: kb.locale_manager is not defined' if not kb.locale_manager

    # bind callbacks
    @__kb or= {}
    @__kb._onLocaleChange = _.bind(@_onLocaleChange, @)

    # internal state
    value = ko.utils.unwrapObservable(@value_holder) if @value_holder
    kb.utils.wrappedByKey(@, 'vo', ko.observable(if not value then null else @read.call(this, value, null)))
    throw 'LocalizedObservable: options.write is not a function for read_write model attribute' if @write and (typeof(@write) isnt 'function')
    observable = kb.utils.wrappedObservable(@, ko.dependentObservable({
      read: _.bind(@_onGetValue, @)
      write: if @write then _.bind(@_onSetValue, @) else (-> throw 'kb.LocalizedObservable: value is read only')
      owner: @view_model
    }))

    # publish public interface on the observable and return instead of this
    observable.destroy = _.bind(@destroy, @)
    observable.observedValue = _.bind(@observedValue, @)
    observable.resetToCurrent = _.bind(@resetToCurrent, @)

    # start
    kb.locale_manager.bind('change', @__kb._onLocaleChange)

    # wrap ourselves with a default value
    if @options.hasOwnProperty('default')
      observable = ko.defaultWrapper(observable, @options.default)

    return observable

  destroy: ->
    kb.locale_manager.unbind('change', @__kb._onLocaleChange)
    @options = null; @view_model = null
    kb.utils.wrappedDestroy(@)

  resetToCurrent: ->
    value_observable = kb.utils.wrappedByKey(@, 'vo')
    value_observable(null) # force KO to think a change occurred
    observable = kb.utils.wrappedObservable(this)
    current_value = if (@value_holder and observable) then @read.call(this, ko.utils.unwrapObservable(@value_holder)) else null
    @_onSetValue(current_value)

  # dual purpose set/get
  observedValue: (value) ->
    return @value_holder if arguments.length == 0
    @value_holder = value; @_onLocaleChange()
    @

  ####################################################
  # Internal
  ####################################################
  _onGetValue: ->
    ko.utils.unwrapObservable(@value_holder) if @value_holder 
    value_observable = kb.utils.wrappedByKey(@, 'vo'); value_observable() # create a depdenency
    read = if @read then @read else @options.read
    return read.call(this, ko.utils.unwrapObservable(@value_holder))

  _onSetValue: (value) ->
    write = if @write then @write else @options.write
    write.call(this, value, ko.utils.unwrapObservable(@value_holder))
    value_observable = kb.utils.wrappedByKey(@, 'vo')
    value_observable(value)
    @options.onChange(value) if @options.onChange

  _onLocaleChange: ->
    read = if @read then @read else @options.read
    value = read.call(this, ko.utils.unwrapObservable(@value_holder))
    value_observable = kb.utils.wrappedByKey(@, 'vo')
    value_observable(value)
    @options.onChange(value) if @options.onChange

# factory function
kb.localizedObservable = (value, options, view_model) -> return new kb.LocalizedObservable(value, options, view_model)
