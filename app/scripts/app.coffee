'use strict'
c = console
###*
 # @ngdoc overview
 # @name leafletApp
 # @description
 # # leafletApp
 #
 # Main module of the application.
###

yearToCity = {}

getSeriesData = (data) ->
    delete data[""]
    # TODO: getTimeInterval should take the corpora of this parent tab instead of the global ones.
    # [first, last] = settings.corpusListing.getTimeInterval()

    parseDate = (granularity, time) ->
        [year,month,day] = [null,0,1]
        switch granularity
            when "y" then year = time
            when "m"
                year = time[0...4]
                month = time[4...6]
            when "d"
                year = time[0...4]
                month = time[4...6]
                day = time[6...8]

        return moment([Number(year), Number(month), Number(day)])

    fillMissingDate = (data) ->
        dateArray = _.pluck data, "x"
        min = _.min dateArray, (mom) -> mom.toDate()
        max = _.max dateArray, (mom) -> mom.toDate()


        duration = switch "y"
            when "y"
                duration = moment.duration year :  1
                diff = "year"
            when "m"
                duration = moment.duration month :  1
                diff = "month"
            when "d"
                duration = moment.duration day :  1
                diff = "day"

        n_diff = moment(max).diff min, diff

        momentMapping = _.object _.map data, (item) ->
            [moment(item.x).unix(), item.y]

        newMoments = []
        for i in [0..n_diff]
            newMoment = moment(min).add(diff, i)
            maybeCurrent = momentMapping[newMoment.unix()]
            if typeof maybeCurrent != 'undefined'
                lastYVal = maybeCurrent
            else
                newMoments.push {x : newMoment, y : lastYVal}
                

        return [].concat data, newMoments

    first = 1611
    last = 2015

    firstVal = parseDate "y", first
    lastVal = parseDate "y", last.toString()

    hasFirstValue = false
    hasLastValue = false
    output = for [x, y] in (_.pairs data)
        mom = (parseDate "y", x)
        if mom.isSame firstVal then hasFirstValue = true
        if mom.isSame lastVal then hasLastValue = true
        {x : mom, y : y}

    unless hasFirstValue
        output.push {x : firstVal, y:0}

    output = fillMissingDate output


    output =  output.sort (a, b) ->
        a.x.unix() - b.x.unix()

    #remove last element
    output.splice(output.length-1, 1)

    for tuple in output
        tuple.x = tuple.x.unix()

    return output


angular
  .module 'leafletApp', [
    'ngAnimate',
    'ngSanitize'
    "leaflet-directive"
  ]
  .controller "MapController", ($scope, leafletData, $http, $q) ->
    s = $scope
    s.loading = true

    placeDef = $http(
        method : "GET"
        url : "data/places.json"
    )
    # placeDef.then (placeResponse) ->
        # names = _.pairs placeResponse.data
        # s.placeData = data

        # for i in [0..100]
        #     [city, [lat, lng]] = data[i]

        #     s.markers[city] = 
        #         icon : icon
        #         lat : lat
        #         lng : lng
        #         message : city



    korpDef = $http(
        method : "GET"
        url : "http://spraakbanken.gu.se/ws/korp?command=count&groupby=word&cqp=%5Bpos+%3D+%22PM%22+%26+_.text_title+%3D+%22Nils+Holgersson.*%22%5D&corpus=LB&incremental=true&defaultwithin=sentence"
    )
    # korpDef.then (response) ->
    #     data = response.data




    $q.all([placeDef, korpDef]).then ([placeResponse, korpResponse]) ->
        c.log "all done"

        names = _.keys korpResponse.data.total.absolute
        usedNames = []
        for name in names
            if name.toLowerCase() of placeResponse.data
                usedNames.push name
                # [lat, lng] = placeResponse.data[name.toLowerCase()]
                # s.markers[name] = 
                #     icon : icon
                #     lat : lat
                #     lng : lng
                #     message : name

        c.log "all names", usedNames.length

        cqpFromName = (name) ->
            return """(word = "#{name}")"""

        cqps = _.map usedNames, cqpFromName
        tokenWrap = (expr) -> "[" + expr + "]"
        cqp = tokenWrap (cqps).join(" | ")

        params = {
            command : "count_time"
            corpus : "LB"
            cqp : cqp
        }
        for expr, i in cqps
            params["subcqp" + i] = tokenWrap expr


        $http(
            method : "GET"
            url : "http://spraakbanken.gu.se/ws/korp"
            params: params
        ).then (response) ->
            c.log "time response", response.data

            combined = response.data.combined
            delete combined[""] # deal with rest data later?

            allData = []
            
            for item in combined
                series = getSeriesData item.relative
                name = item.cqp or "&Sigma;"
                if name.match('"(.*?)"') is null then continue
                city = name.match('"(.*?)"')[1]
                for val in series
                    if val.y
                        year = moment.unix(val.x).year()
                        if not yearToCity[year]? then yearToCity[year] = []
                        [lat, lng] = placeResponse.data[city.toLowerCase()]
                        yearToCity[moment.unix(val.x).year()].push 
                            val: val.y
                            name : city
                            lat: lat
                            lng : lng
                # moment.unix()
                # c.log "series", name, series
            c.log "yearToCity", yearToCity
            s.loading = false






            # c.log "combined", series




    
    s.startTimer = () ->
        setInterval(() ->
            s.$apply () ->
                s.year++
                s.setYear(s.year)
        , 400)

    s.year = 1811
    s.setYear = (year) ->
        s.markers = {}
        c.log "year", year, yearToCity[year]
        for item in yearToCity[year]
            {val, name, lat, lng} = item
            c.log "val, name, lat, lng", val, name, lat, lng
            s.markers[name] = 
                icon : icon
                lat : lat
                lng : lng
                message : name



    s.center = 
        lat: 62.99515845212052
        lng: 16.69921875
        zoom: 4


    icon = 
        type: 'div',
        iconSize: [5, 5],
        html: '<span class="dot"></span>',
        popupAnchor:  [0, 0]

    s.markers = {}
        # m1:
        #     icon : icon
        #     lat: 57.7072326
        #     lng : 11.9670171
        #     message : "Göteborg"
    
    s.show_map = false
    leafletData.getMap().then (map) ->
        # L.GeoIP.centerMapOnPosition(map, 15)
        L.tileLayer.provider('Stamen.Watercolor').addTo(map);
        s.show_map = true
