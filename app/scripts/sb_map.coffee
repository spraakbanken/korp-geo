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
      map = angular.element (element.find ".map-container")
      scope.map = L.map(map[0], {minZoom: 1, maxZoom: 16}).setView [51.505, -0.09], 13

      stamenWaterColor = L.tileLayer.provider "Stamen.Watercolor"
      openStreetMap = L.tileLayer.provider "OpenStreetMap"

      createMarkerIcon = (color) -> 
        return L.divIcon { html: '<div class="geokorp-marker" style="background-color:' + color + '"></div>', iconSize: new L.Point(10,10) }

      shadeColor = (color, percent) ->
          f = parseInt(color.slice(1),16)
          t = if percent < 0 then 0 else 255 
          p = if percent < 0 then percent*-1 else percent 
          R = f>>16
          G = f>>8&0x00FF
          B = f&0x0000FF
          return "#"+(0x1000000+(Math.round((t-R)*p)+R)*0x10000+(Math.round((t-G)*p)+G)*0x100+(Math.round((t-B)*p)+B)).toString(16).slice(1)

      createClusterIcon = (cluster) ->
          elements = {}
          for child in cluster.getAllChildMarkers()
              color = child.markerData.color
              if not elements[color]
                  elements[color] = []
              elements[color].push '<div class="geokorp-marker" style="display: table-cell;background-color:' + color + '"></div>'

          res = []
          for elements in _.values elements
              res.push '<div style="display: table-row">' + elements.join(" ") + '</div>'
          return L.divIcon { html: '<div style="display: table">' + res.join(" ") + '</div>', iconSize: new L.Point(50, 50) }

      createMarkerCluster = () ->
          markerCluster = L.markerClusterGroup
              showOnSelector: false
              spiderfyOnMaxZoom: false
              showCoverageOnHover: false
              maxClusterRadius: 40
              zoomToBoundsOnClick: false
              iconCreateFunction: createClusterIcon

          markerCluster.on 'clustermouseover', (e) ->
              mouseOver (_.map e.layer.getAllChildMarkers(), (layer) -> layer.markerData).slice 0, 4

          markerCluster.on 'clustermouseout', (e) ->
              mouseOut()

          markerCluster.on 'mouseover', (e) ->
              mouseOver [e.layer.markerData]

          markerCluster.on 'mouseout', (e) ->
              mouseOut()

          markerCluster.on 'clusterclick', (e) ->
              allData = _.map e.layer.getAllChildMarkers(), (layer) -> layer.markerData
              elements = _.map allData, (markerData) -> 
                  queryLink = angular.element '<a class="link" style="display: block">' + markerData.point.name + '</a>'
                  queryLink.bind "click", () ->
                      scope.markerCallback markerData
                  return queryLink
              popupMarkup = angular.element '<div></div>'
              popupMarkup.append elements

              popup = L.popup()
                    .setLatLng e.latlng
                    .setContent popupMarkup[0]
                    .openOn scope.map
              
          return markerCluster

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
                  hoverInfoElem  = angular.element (element.find ".hover-info-container")
                  hoverInfoElem.empty()
                  hoverInfoElem.append content
                  angular.element('.hover-info').css('opacity', '1')), 0

      mouseOut = () ->
          angular.element('.hover-info').css('opacity','0')

      scope.markerCluster = createMarkerCluster()
      scope.map.addLayer scope.markerCluster

      scope.$watchCollection("selectedGroups", (selectedGroups) ->
          markers = scope.markers
          
          scope.markerCluster.eachLayer (layer) ->
              scope.markerCluster.removeLayer layer

          for markerGroupId in selectedGroups
              markerGroup = markers[markerGroupId]
              color = markerGroup.color

              for marker_id in _.keys markerGroup.markers
                  markerData = markerGroup.markers[marker_id]
                  markerData.color = color
                  marker = L.marker [markerData.lat, markerData.lng], {icon: createMarkerIcon color}
                  marker.markerData = markerData
                  scope.markerCluster.addLayer marker

                  popupLink = angular.element '<a class="link">' + markerData.point.name + '</a>'
                  do(markerData) ->
                      popupLink.bind("click", () ->
                          scope.markerCallback markerData
                      )

                  marker.bindPopup popupLink[0]
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
        selectedGroups: '=sbSelectedGroups'
      },
      link: link,
      templateUrl: 'template/sb_map.html'
    }
  ]
