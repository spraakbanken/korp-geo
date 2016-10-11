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

              id = name.replace(/-/g , "")
              markers[id] =
                icon : icon
                lat : lat
                lng : lng
                names: locs

        deferred.resolve markers
      deferred.promise
  ]
  .directive  'sbMap', ['$compile', '$timeout', '$rootScope', ($compile, $timeout, $rootScope) ->
    link = (scope, element, attrs) ->
      scope.useClustering = if angular.isDefined(scope.useClustering) then scope.useClustering else true
        
      scope.showMap = false
      
      scope.hoverTemplate = """<div class="hover-info">
                                <div ng-if="showLabel" class="swatch" style="background-color: {{color}}"></div><div ng-if="showLabel" style="display: inline; font-weight: bold; font-size: 15px">{{label}}</div>
                                <div><span>{{ 'map_name' | loc }}: </span> <span>{{point.name}}</span></div>
                                <div><span>{{ 'map_abs_occurrences' | loc }}: </span> <span>{{point.abs}}</span></div>
                                <div><span>{{ 'map_rel_occurrences' | loc }}: </span> <span>{{point.rel | number:2}}</span></div>
                             </div>"""
      
      map = angular.element (element.find ".map-container")
      scope.map = L.map(map[0], {minZoom: 1, maxZoom: 13}).setView [51.505, -0.09], 13
      scope.selectedMarkers = []

      stamenWaterColor = L.tileLayer.provider "Stamen.Watercolor"
      openStreetMap = L.tileLayer.provider "OpenStreetMap"

      createCircleMarker = (color, diameter) ->
          return L.divIcon 
              html: '<div class="geokorp-marker" style="border-radius:' + diameter + 'px;height:' + diameter + 'px;background-color:' + color + '"></div>'
              iconSize: new L.Point diameter, diameter

      createMarkerIcon = (color, relSize) ->
        # TODO use scope.maxRel, but scope.maxRel is not set when markers are created
        # diameter = ((relSize / scope.maxRel) * 45) + 5
        return createCircleMarker color, 10

      # use the previously calculated "scope.maxRel" to decide the sizes of the bars
      # in the cluster icon that is returned (between 5px and 50px)
      createClusterIcon = (clusterGroups, restColor) ->
          allGroups = _.keys clusterGroups
          visibleGroups = allGroups.sort((group1, group2) ->
              return clusterGroups[group1].order - clusterGroups[group2].order)

          if allGroups.length > 4
              visibleGroups = visibleGroups.splice(0,3)
              visibleGroups.push restColor

          (cluster) ->
              sizes = {}
              for group in visibleGroups
                  sizes[group] = 0
              for child in cluster.getAllChildMarkers()
                  color = child.markerData.color
                  if color not of sizes
                      color = restColor
                  rel = child.markerData.point.rel
                  sizes[color] = sizes[color] + rel

              if allGroups.length == 1
                  color = _.keys(sizes)[0]
                  groupSize = sizes[color]
                  diameter = ((groupSize / scope.maxRel) * 45) + 5
                  return createCircleMarker color, diameter
              else
                  elements = ""
                  for color in _.keys sizes
                      groupSize = sizes[color]
                      divWidth = ((groupSize / scope.maxRel) * 45) + 5
                      elements = elements  + '<div class="cluster-geokorp-marker" style="height:' + divWidth + 'px;background-color:' + color + '"></div>'

                  return L.divIcon { html: '<div class="cluster-geokorp-marker-group">' + elements + '</div>', iconSize: new L.Point(40, 50) }

      # check if the cluster with split into several clusters / markers
      # on zooom
      # TODO: does not work in some cases
      shouldZooomToBounds = (cluster) ->
          childClusters = cluster._childClusters.slice()
          map = cluster._group._map
          boundsZoom = map.getBoundsZoom cluster._bounds          
          zoom = cluster._zoom + 1

          while childClusters.length > 0 && boundsZoom > zoom
              zoom = zoom + 1
              newClusters = []
              for childCluster in childClusters
                 newClusters = newClusters.concat childCluster._childClusters

              childClusters = newClusters

          return childClusters.length > 1

      # check all current clusters and sum up the sizes of its childen
      # this is the max relative value of any cluster and can be used to 
      # calculate marker sizes
      # TODO this needs to use the "rest" group when doing calcuations!!
      updateMarkerSizes = () ->
          bounds = scope.map.getBounds()
          scope.maxRel = 0
          if scope.useClustering and scope.markerCluster
              scope.map.eachLayer (layer) ->
                  if layer.getChildCount
                      sumRels = {}
                      for child in layer.getAllChildMarkers()
                          color = child.markerData.color
                          if not sumRels[color]
                              sumRels[color] = 0
                          sumRels[color] = sumRels[color] + child.markerData.point.rel
                      for sumRel in _.values sumRels
                          if sumRel > scope.maxRel
                              scope.maxRel = sumRel
                  else if layer.markerData
                      rel = layer.markerData.point.rel
                      if rel > scope.maxRel
                          scope.maxRel = rel
              scope.markerCluster.refreshClusters()
              # TODO when scope.maxRel is set, we should redraw all non-cluster markers using this

      # create normal layer (and all listeners) to be used when clustering is not enabled
      createFeatureLayer = () ->
          featureLayer = L.featureGroup()
          featureLayer.on 'click', (e) ->
              scope.selectedMarkers = [e.layer.markerData]
              mouseOver scope.selectedMarkers

          featureLayer.on 'mouseover', (e) ->
              mouseOver [e.layer.markerData]

          featureLayer.on 'mouseout', (e) ->
              if scope.selectedMarkers.length > 0
                  mouseOver scope.selectedMarkers
              else
                  mouseOut()
          return featureLayer

      # create marker cluster layer and all listeners
      createMarkerCluster = (clusterGroups, restColor) ->
          markerCluster = L.markerClusterGroup
              spiderfyOnMaxZoom: false
              showCoverageOnHover: false
              maxClusterRadius: 40
              zoomToBoundsOnClick: false
              iconCreateFunction: createClusterIcon clusterGroups, restColor

          markerCluster.on 'clustermouseover', (e) ->
              mouseOver _.map e.layer.getAllChildMarkers(), (layer) -> layer.markerData

          markerCluster.on 'clustermouseout', (e) ->
              if scope.selectedMarkers.length > 0
                  mouseOver scope.selectedMarkers
              else
                  mouseOut()

          markerCluster.on 'clusterclick', (e) ->
              scope.selectedMarkers = _.map e.layer.getAllChildMarkers(), (layer) -> layer.markerData
              mouseOver scope.selectedMarkers
              if shouldZooomToBounds e.layer
                  e.layer.zoomToBounds()

          markerCluster.on 'click', (e) ->
              scope.selectedMarkers = [e.layer.markerData]
              mouseOver scope.selectedMarkers

          markerCluster.on 'mouseover', (e) ->
              mouseOver [e.layer.markerData]

          markerCluster.on 'mouseout', (e) ->
              if scope.selectedMarkers.length > 0
                  mouseOver scope.selectedMarkers
              else
                  mouseOut()

          markerCluster.on 'animationend', (e) ->
              updateMarkerSizes()

          return markerCluster

      # takes a list of markers and displays clickable (callback determined by directive user) info boxes
      mouseOver = (markerData) ->
          $timeout (() ->
              scope.$apply () ->
                  content = []

                  if scope.useClustering
                      sortedMarkerData = markerData.sort (markerData1, markerData2) ->
                          return markerData2.point.rel - markerData1.point.rel
                      selectedMarkers = markerData
                  else
                      selectedMarkers = for name in _.keys markerData[0].names
                          color: markerData[0].color
                          searchCqp: markerData[0].searchCqp
                          point:
                              name: name
                              abs: markerData[0].names[name].abs_occurrences
                              rel: markerData[0].names[name].rel_occurrences

                  for marker in selectedMarkers
                        msgScope =  $rootScope.$new true
                        msgScope.showLabel = scope.useClustering
                        msgScope.point = marker.point
                        msgScope.label = marker.label
                        msgScope.color = marker.color
                        compiled = $compile scope.hoverTemplate
                        markerDiv = compiled msgScope
                        do(marker) ->
                            markerDiv.bind 'click', () ->
                                scope.markerCallback marker
                        content.push markerDiv
                  hoverInfoElem  = angular.element (element.find ".hover-info-container")
                  hoverInfoElem.empty()
                  hoverInfoElem.append content
                  hoverInfoElem[0].scrollTop = 0
                  hoverInfoElem.css('opacity', '1')), 0

      mouseOut = () ->
          hoverInfoElem  = angular.element (element.find ".hover-info-container")
          hoverInfoElem.css('opacity','0')

      scope.showHoverInfo = false
      scope.map.on 'click', (e) ->
          scope.selectedMarkers = []
          mouseOut()

      scope.$watchCollection "selectedGroups", (selectedGroups) ->
          markers = scope.markers
          
          if scope.markerCluster
              scope.map.removeLayer scope.markerCluster
          else if scope.featureLayer
              scope.map.removeLayer scope.featureLayer

          if scope.useClustering
              clusterGroups = {}
              for group in selectedGroups
                  groupData = markers[group]
                  clusterGroups[groupData.color] =
                      order: groupData.order
              scope.markerCluster = createMarkerCluster clusterGroups, scope.restColor
              scope.map.addLayer scope.markerCluster
          else
              scope.featureLayer = createFeatureLayer()
              scope.map.addLayer scope.featureLayer

          for markerGroupId in selectedGroups
              markerGroup = markers[markerGroupId]
              color = markerGroup.color
              scope.maxRel = 0
              for marker_id in _.keys markerGroup.markers
                  markerData = markerGroup.markers[marker_id]
                  markerData.color = color
                  marker = L.marker [markerData.lat, markerData.lng], {icon: createMarkerIcon color, markerData.point.rel}
                  marker.markerData = markerData

                  if scope.useClustering
                      scope.markerCluster.addLayer marker
                  else
                      scope.featureLayer.addLayer marker

          updateMarkerSizes()

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
        baseLayer: '=sbBaseLayer'
        markerCallback: '=sbMarkerCallback'
        selectedGroups: '=sbSelectedGroups'
        useClustering: '=?sbUseClustering'
        restColor: '=?sbRestColor' # free color to use for grouping etc
      },
      link: link,
      templateUrl: 'template/sb_map.html'
    }
  ]
