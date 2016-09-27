(function() {
  'use strict';
  var c,
    __hasProp = {}.hasOwnProperty;

  c = console;

  angular.module('sbMap', ['sbMapTemplate']).factory('places', [
    '$q', '$http', function($q, $http) {
      var Places;
      Places = (function() {
        function Places() {
          this.places = null;
        }

        Places.prototype.getLocationData = function() {
          var def;
          def = $q.defer();
          if (!this.places) {
            $http.get('components/geokorp/dist/data/places.json').success((function(_this) {
              return function(data) {
                _this.places = {
                  data: data
                };
                return def.resolve(_this.places);
              };
            })(this)).error((function(_this) {
              return function() {
                def.reject();
                return c.log("failed to get place data for sb map");
              };
            })(this));
          } else {
            def.resolve(this.places);
          }
          return def.promise;
        };

        return Places;

      })();
      return new Places();
    }
  ]).factory('nameMapper', [
    '$q', '$http', function($q, $http) {
      var NameMapper;
      NameMapper = (function() {
        function NameMapper() {
          this.mapper = null;
        }

        NameMapper.prototype.getNameMapper = function() {
          var def;
          def = $q.defer();
          if (!this.mapper) {
            $http.get('components/geokorp/dist/data/name_mapping.json').success(function(data) {
              return def.resolve({
                data: data
              });
            }).error(function() {
              c.log("failed to get name mapper for sb map");
              return def.reject();
            });
          } else {
            def.resolve(this.mapper);
          }
          return def.promise;
        };

        return NameMapper;

      })();
      return new NameMapper();
    }
  ]).factory('markers', [
    '$rootScope', '$q', '$http', 'places', 'nameMapper', function($rootScope, $q, $http, places, nameMapper) {
      var icon;
      icon = {
        type: 'div',
        iconSize: [5, 5],
        html: '<span class="dot"></span>',
        popupAnchor: [0, 0]
      };
      return function(nameData) {
        var deferred;
        deferred = $q.defer();
        $q.all([places.getLocationData(), nameMapper.getNameMapper()]).then(function(_arg) {
          var locs, mappedLocations, mappedName, markers, name, nameLow, nameMapperResponse, names, placeResponse, usedNames, _fn, _i, _len;
          placeResponse = _arg[0], nameMapperResponse = _arg[1];
          names = _.keys(nameData);
          usedNames = [];
          markers = {};
          mappedLocations = {};
          for (_i = 0, _len = names.length; _i < _len; _i++) {
            name = names[_i];
            mappedName = null;
            nameLow = name.toLowerCase();
            if (nameMapperResponse.data.hasOwnProperty(nameLow)) {
              mappedName = nameMapperResponse.data[nameLow];
            } else if (placeResponse.data.hasOwnProperty(nameLow)) {
              mappedName = nameLow;
            }
            if (mappedName) {
              locs = mappedLocations[mappedName];
              if (!locs) {
                locs = {};
              }
              locs[name] = nameData[name];
              mappedLocations[mappedName] = locs;
            }
          }
          _fn = function(name, locs) {
            var id, lat, lng, s, _ref;
            _ref = placeResponse.data[name], lat = _ref[0], lng = _ref[1];
            s = $rootScope.$new(true);
            s.names = locs;
            id = name.replace(/-/g, "");
            markers[id] = {
              icon: icon,
              lat: lat,
              lng: lng
            };
            return markers[id].getMessageScope = function() {
              return s;
            };
          };
          for (name in mappedLocations) {
            if (!__hasProp.call(mappedLocations, name)) continue;
            locs = mappedLocations[name];
            _fn(name, locs);
          }
          return deferred.resolve(markers);
        });
        return deferred.promise;
      };
    }
  ]).directive('sbMap', [
    '$compile', '$timeout', '$rootScope', function($compile, $timeout, $rootScope) {
      var link;
      link = function(scope, element, attrs) {
        var baseLayers, createClusterIcon, icon, mouseOut, mouseOver, openStreetMap, stamenWaterColor;
        scope.showMap = false;
        scope.map = L.map("mapid", {
          minZoom: 1,
          maxZoom: 16
        }).setView([51.505, -0.09], 13);
        stamenWaterColor = L.tileLayer.provider("Stamen.Watercolor");
        openStreetMap = L.tileLayer.provider("OpenStreetMap");
        icon = function(color) {
          return L.icon({
            iconUrl: "http://api.tiles.mapbox.com/v3/marker/pin-m+" + color + ".png",
            iconSize: [38, 95]
          });
        };
        createClusterIcon = function(cluster) {
          return L.divIcon({
            html: '<div><span>' + cluster.getChildCount() + '</span></div>',
            className: 'marker-cluster marker-cluster-' + "small",
            iconSize: new L.Point(40, 40)
          });
        };
        scope.markerCluster = L.markerClusterGroup({
          showOnSelector: false,
          spiderfyOnMaxZoom: true,
          showCoverageOnHover: false,
          maxClusterRadius: 40,
          iconCreateFunction: createClusterIcon
        });
        scope.markerCluster.on('clustermouseover', function(e) {
          return mouseOver((_.map(e.layer.getAllChildMarkers(), function(layer) {
            return layer.markerData;
          })).slice(0, 5));
        });
        scope.markerCluster.on('clustermouseout', function(e) {
          return mouseOut();
        });
        scope.markerCluster.on('mouseover', function(e) {
          return mouseOver([e.layer.markerData]);
        });
        scope.markerCluster.on('mouseout', function(e) {
          return mouseOut();
        });
        mouseOver = function(markerData) {
          return $timeout((function() {
            return scope.$apply(function() {
              var compiled, content, marker, msgScope, _i, _len;
              content = [];
              for (_i = 0, _len = markerData.length; _i < _len; _i++) {
                marker = markerData[_i];
                msgScope = $rootScope.$new(true);
                msgScope.point = marker.point;
                msgScope.label = marker.label;
                compiled = $compile(scope.hoverTemplate);
                content.push(compiled(msgScope));
              }
              angular.element('#hover-info').empty();
              angular.element('#hover-info').append(content);
              return angular.element('.hover-info').css('opacity', '1');
            });
          }), 0);
        };
        mouseOut = function() {
          return angular.element('.hover-info').css('opacity', '0');
        };
        scope.map.addLayer(scope.markerCluster);
        scope.$watch("markers", function(markers) {
          var marker, markerData, marker_id, _fn, _i, _len, _ref, _results;
          scope.markerCluster.clearLayers();
          _ref = _.keys(markers);
          _fn = function(markerData) {
            return element.bind("click", function() {
              return scope.markerCallback(markerData);
            });
          };
          _results = [];
          for (_i = 0, _len = _ref.length; _i < _len; _i++) {
            marker_id = _ref[_i];
            markerData = markers[marker_id];
            marker = L.marker([markerData.lat, markerData.lng], {
              icon: icon(markerData.color)
            });
            marker.markerData = markerData;
            scope.markerCluster.addLayer(marker);
            element = angular.element('<a class="link">' + markerData.point.name + '</a>');
            _fn(markerData);
            _results.push(marker.bindPopup(element[0]));
          }
          return _results;
        });
        if (scope.baseLayer === "Stamen Watercolor") {
          stamenWaterColor.addTo(scope.map);
        } else {
          openStreetMap.addTo(scope.map);
        }
        baseLayers = {
          "Stamen Watercolor": stamenWaterColor,
          "OpenStreetMap": openStreetMap
        };
        L.control.layers(baseLayers, null, {
          position: "bottomleft"
        }).addTo(scope.map);
        scope.map.setView([scope.center.lat, scope.center.lng], scope.center.zoom);
        return scope.showMap = true;
      };
      return {
        restrict: 'E',
        scope: {
          markers: '=sbMarkers',
          center: '=sbCenter',
          hoverTemplate: '=sbHoverTemplate',
          baseLayer: '=sbBaseLayer',
          markerCallback: '=sbMarkerCallback'
        },
        link: link,
        templateUrl: 'template/sb_map.html'
      };
    }
  ]);

}).call(this);

//# sourceMappingURL=sb_map.js.map
