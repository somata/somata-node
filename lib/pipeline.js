// Generated by CoffeeScript 1.7.1
(function() {
  var SomataPipeline, hashpipe,
    __hasProp = {}.hasOwnProperty,
    __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; },
    __slice = [].slice;

  hashpipe = require('hashpipe');

  SomataPipeline = (function(_super) {
    __extends(SomataPipeline, _super);

    function SomataPipeline() {
      return SomataPipeline.__super__.constructor.apply(this, arguments);
    }

    return SomataPipeline;

  })(hashpipe.Pipeline);

  SomataPipeline.prototype.get = function(t, k) {
    var found, method, service, service_method;
    found = SomataPipeline.__super__.get.apply(this, arguments);
    if ((found == null) && t === 'fns') {
      if (service_method = k.match(/([\w:]+)\.([\w\.]*)/)) {
        service = service_method[1];
        method = service_method[2] || service;
        found = (function(_this) {
          return function(inp, args, ctx, cb) {
            var _ref;
            return (_ref = _this.client).remote.apply(_ref, [service, method].concat(__slice.call(args), [cb]));
          };
        })(this);
      }
    }
    return found;
  };

  module.exports = SomataPipeline;

}).call(this);