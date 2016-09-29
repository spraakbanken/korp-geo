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
        var baseLayers, createClusterIcon, createMarkerCluster, createMarkerIcon, map, mouseOut, mouseOver, openStreetMap, shadeColor, stamenWaterColor;
        scope.showMap = false;
        map = angular.element(element.find(".map-container"));
        scope.map = L.map(map[0], {
          minZoom: 1,
          maxZoom: 16
        }).setView([51.505, -0.09], 13);
        stamenWaterColor = L.tileLayer.provider("Stamen.Watercolor");
        openStreetMap = L.tileLayer.provider("OpenStreetMap");
        createMarkerIcon = function(color) {
          return L.divIcon({
            html: '<div class="geokorp-marker" style="background-color:' + color + '"></div>',
            iconSize: new L.Point(10, 10)
          });
        };
        shadeColor = function(color, percent) {
          var B, G, R, f, p, t;
          f = parseInt(color.slice(1), 16);
          t = percent < 0 ? 0 : 255;
          p = percent < 0 ? percent * -1 : percent;
          R = f >> 16;
          G = f >> 8 & 0x00FF;
          B = f & 0x0000FF;
          return "#" + (0x1000000 + (Math.round((t - R) * p) + R) * 0x10000 + (Math.round((t - G) * p) + G) * 0x100 + (Math.round((t - B) * p) + B)).toString(16).slice(1);
        };
        createClusterIcon = function(cluster) {
          var child, color, elements, res, _i, _j, _len, _len1, _ref, _ref1;
          elements = {};
          _ref = cluster.getAllChildMarkers();
          for (_i = 0, _len = _ref.length; _i < _len; _i++) {
            child = _ref[_i];
            color = child.markerData.color;
            if (!elements[color]) {
              elements[color] = [];
            }
            elements[color].push('<div class="geokorp-marker" style="display: table-cell;background-color:' + color + '"></div>');
          }
          res = [];
          _ref1 = _.values(elements);
          for (_j = 0, _len1 = _ref1.length; _j < _len1; _j++) {
            elements = _ref1[_j];
            res.push('<div style="display: table-row">' + elements.join(" ") + '</div>');
          }
          return L.divIcon({
            html: '<div style="display: table">' + res.join(" ") + '</div>',
            iconSize: new L.Point(50, 50)
          });
        };
        createMarkerCluster = function() {
          var markerCluster;
          markerCluster = L.markerClusterGroup({
            showOnSelector: false,
            spiderfyOnMaxZoom: false,
            showCoverageOnHover: false,
            maxClusterRadius: 40,
            zoomToBoundsOnClick: false,
            iconCreateFunction: createClusterIcon
          });
          markerCluster.on('clustermouseover', function(e) {
            return mouseOver((_.map(e.layer.getAllChildMarkers(), function(layer) {
              return layer.markerData;
            })).slice(0, 4));
          });
          markerCluster.on('clustermouseout', function(e) {
            return mouseOut();
          });
          markerCluster.on('mouseover', function(e) {
            return mouseOver([e.layer.markerData]);
          });
          markerCluster.on('mouseout', function(e) {
            return mouseOut();
          });
          markerCluster.on('clusterclick', function(e) {
            var allData, elements, popup, popupMarkup;
            allData = _.map(e.layer.getAllChildMarkers(), function(layer) {
              return layer.markerData;
            });
            elements = _.map(allData, function(markerData) {
              var queryLink;
              queryLink = angular.element('<a class="link" style="display: block">' + markerData.point.name + '</a>');
              queryLink.bind("click", function() {
                return scope.markerCallback(markerData);
              });
              return queryLink;
            });
            popupMarkup = angular.element('<div></div>');
            popupMarkup.append(elements);
            return popup = L.popup().setLatLng(e.latlng).setContent(popupMarkup[0]).openOn(scope.map);
          });
          return markerCluster;
        };
        mouseOver = function(markerData) {
          return $timeout((function() {
            return scope.$apply(function() {
              var compiled, content, hoverInfoElem, marker, msgScope, _i, _len;
              content = [];
              for (_i = 0, _len = markerData.length; _i < _len; _i++) {
                marker = markerData[_i];
                msgScope = $rootScope.$new(true);
                msgScope.point = marker.point;
                msgScope.label = marker.label;
                compiled = $compile(scope.hoverTemplate);
                content.push(compiled(msgScope));
              }
              hoverInfoElem = angular.element(element.find(".hover-info-container"));
              hoverInfoElem.empty();
              hoverInfoElem.append(content);
              return angular.element('.hover-info').css('opacity', '1');
            });
          }), 0);
        };
        mouseOut = function() {
          return angular.element('.hover-info').css('opacity', '0');
        };
        scope.markerCluster = createMarkerCluster();
        scope.map.addLayer(scope.markerCluster);
        scope.$watchCollection("selectedGroups", function(selectedGroups) {
          var color, marker, markerData, markerGroup, markerGroupId, marker_id, markers, popupLink, _i, _len, _results;
          markers = scope.markers;
          scope.markerCluster.eachLayer(function(layer) {
            return scope.markerCluster.removeLayer(layer);
          });
          _results = [];
          for (_i = 0, _len = selectedGroups.length; _i < _len; _i++) {
            markerGroupId = selectedGroups[_i];
            markerGroup = markers[markerGroupId];
            color = markerGroup.color;
            _results.push((function() {
              var _fn, _j, _len1, _ref, _results1;
              _ref = _.keys(markerGroup.markers);
              _fn = function(markerData) {
                return popupLink.bind("click", function() {
                  return scope.markerCallback(markerData);
                });
              };
              _results1 = [];
              for (_j = 0, _len1 = _ref.length; _j < _len1; _j++) {
                marker_id = _ref[_j];
                markerData = markerGroup.markers[marker_id];
                markerData.color = color;
                marker = L.marker([markerData.lat, markerData.lng], {
                  icon: createMarkerIcon(color)
                });
                marker.markerData = markerData;
                scope.markerCluster.addLayer(marker);
                popupLink = angular.element('<a class="link">' + markerData.point.name + '</a>');
                _fn(markerData);
                _results1.push(marker.bindPopup(popupLink[0]));
              }
              return _results1;
            })());
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
          markerCallback: '=sbMarkerCallback',
          selectedGroups: '=sbSelectedGroups'
        },
        link: link,
        templateUrl: 'template/sb_map.html'
      };
    }
  ]);

}).call(this);

//# sourceMappingURL=sb_map.js.map
