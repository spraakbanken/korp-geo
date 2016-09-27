'use strict'
c = console

angular.module 'sbMap', [
  'sbMapTemplate'
  ]
  .factory 'places', ['$q', '$http', ($q, $http) ->

    class Places

      constructor: () ->
        @places = null

      getLocationData: () ->
        def = $q.defer()

        if not @places
          $http.get('components/geokorp/dist/data/places.json')
            .success((data) =>
              @places = data: data
              def.resolve @places
            )
            .error(() =>
              def.reject()
              c.log "failed to get place data for sb map"
            )
        else
          def.resolve @places

        return def.promise

    return new Places()
  ]
  .factory 'nameMapper', ['$q','$http', ($q, $http) ->

    class NameMapper

      constructor: () ->
        @mapper = null

      getNameMapper: () ->
        def = $q.defer()

        if not @mapper
          $http.get('components/geokorp/dist/data/name_mapping.json')
            .success((data) ->
              def.resolve(data: data)
            )
            .error(() ->
              c.log "failed to get name mapper for sb map"
              def.reject()
            )
        else
          def.resolve @mapper
        return  def.promise

    return new NameMapper()
  ]
  .factory 'markers', ['$rootScope', '$q', '$http', 'places', 'nameMapper', ($rootScope, $q, $http, places, nameMapper) ->
    icon =
      type: 'div',
      iconSize: [5, 5],
      html: '<span class="dot"></span>',
      popupAnchor:  [0, 0]

    return (nameData) ->
      deferred = $q.defer()
      $q.all([places.getLocationData(), nameMapper.getNameMapper()]).then ([placeResponse, nameMapperResponse]) ->
        names = _.keys nameData
        usedNames = []
        markers = {}

        mappedLocations = {}
        for name in names
          mappedName = null
          nameLow = name.toLowerCase()
          if nameMapperResponse.data.hasOwnProperty nameLow
            mappedName = nameMapperResponse.data[nameLow]
          else if placeResponse.data.hasOwnProperty nameLow
            mappedName = nameLow
          if mappedName
            locs = mappedLocations[mappedName]
            if not locs
              locs = {}
            locs[name] = nameData[name]
            mappedLocations[mappedName] = locs

        for own name, locs of mappedLocations
            do(name, locs) ->
              [lat, lng] = placeResponse.data[name]
              s = $rootScope.$new(true)
              s.names = locs

              id = name.replace(/-/g , "")
              markers[id] =
                icon : icon
                lat : lat
                lng : lng

              markers[id].getMessageScope = () -> s

        deferred.resolve markers
      deferred.promise
  ]
  .directive  'sbMap', ['$compile', '$timeout', '$rootScope', ($compile, $timeout, $rootScope) ->
    link = (scope, element, attrs) ->

      scope.showMap = false
      scope.map = L.map("mapid", {minZoom: 1, maxZoom: 16}).setView [51.505, -0.09], 13

      stamenWaterColor = L.tileLayer.provider "Stamen.Watercolor"
      openStreetMap = L.tileLayer.provider "OpenStreetMap"

      icon = (color) -> L.icon
          iconUrl: "http://api.tiles.mapbox.com/v3/marker/pin-m+" + color + ".png",
        #   shadowUrl: 'leaf-shadow.png',
          iconSize:     [38, 95],
        #   shadowSize:   [50, 64],
        #   iconAnchor:   [22, 94],
        #   shadowAnchor: [4, 62],
        #   popupAnchor:  [-3, -76]

      createClusterIcon = (cluster) -> 
          return L.divIcon({ html: '<div><span>' + cluster.getChildCount() + '</span></div>', className: 'marker-cluster marker-cluster-' + "small", iconSize: new L.Point(40, 40) });

      scope.markerCluster = L.markerClusterGroup
          showOnSelector: false
          spiderfyOnMaxZoom: true
          showCoverageOnHover: false
          maxClusterRadius: 40
          iconCreateFunction: createClusterIcon

      scope.markerCluster.on 'clustermouseover', (e) ->
          mouseOver (_.map e.layer.getAllChildMarkers(), (layer) -> layer.markerData).slice 0, 5

      scope.markerCluster.on 'clustermouseout', (e) ->
          mouseOut()

      scope.markerCluster.on 'mouseover', (e) ->
          mouseOver [e.layer.markerData]

      scope.markerCluster.on 'mouseout', (e) ->
          mouseOut()

      mouseOver = (markerData) ->
          $timeout (() ->
              scope.$apply () ->
                  content = []
                  for marker in markerData
                        msgScope =  $rootScope.$new true
                        msgScope.point = marker.point
                        msgScope.label = marker.label
                        compiled = $compile scope.hoverTemplate
                        content.push compiled msgScope
                  angular.element('#hover-info').empty()
                  angular.element('#hover-info').append content
                  angular.element('.hover-info').css('opacity', '1')), 0

      mouseOut = () ->
          angular.element('.hover-info').css('opacity','0')

      scope.map.addLayer scope.markerCluster

      scope.$watch("markers", (markers) ->
          scope.markerCluster.clearLayers()

          for marker_id in _.keys markers
              markerData = markers[marker_id]
              marker = L.marker [markerData.lat, markerData.lng], {icon: icon markerData.color}
              marker.markerData = markerData
              scope.markerCluster.addLayer marker

              element = angular.element '<a class="link">' + markerData.point.name + '</a>'
              do(markerData) ->
                  element.bind("click", () ->
                      scope.markerCallback markerData
                  )

              marker.bindPopup element[0]
      )

      if scope.baseLayer == "Stamen Watercolor"
          stamenWaterColor.addTo scope.map
      else
          openStreetMap.addTo scope.map

      baseLayers = 
          "Stamen Watercolor": stamenWaterColor
          "OpenStreetMap": openStreetMap

      L.control.layers(baseLayers, null, {position: "bottomleft"}).addTo scope.map

      scope.map.setView [scope.center.lat, scope.center.lng], scope.center.zoom

      scope.showMap = true

    return {
      restrict: 'E',
      scope: {
        markers: '=sbMarkers'
        center: '=sbCenter'
        hoverTemplate: '=sbHoverTemplate'
        baseLayer: '=sbBaseLayer'
        markerCallback: '=sbMarkerCallback'
      },
      link: link,
      templateUrl: 'template/sb_map.html'
    }
  ]
