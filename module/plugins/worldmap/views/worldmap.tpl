%rebase layout globals(), css=['worldmap/css/worldmap.css'], title='Worldmap', refresh=True

<!-- HTML map container -->
<div class="map_container">
	<div id="map">
		<div class="alert alert-info">
			<a href="#" class="alert-link">Loading map ...</a>
		</div>
	</div>
    <div class="row">
        <div class="col-xs-2">
            <div class="form-group">
                <label class="control-label">Hostgroups:</label>
                <select class="form-control" name="filter" onchange="location = this.options[this.selectedIndex].value">
                    <option>-----</option>
                    <option value="/worldmap">No filter</option>
                    %for name in hostgroups:
                    <option value="/worldmap/{{ name }}">{{ name }}</option>
                    %end
                </select>
            </div>
        </div>
    </div>
</div>

<script>
	var map;
	var infoWindow;
	
	// Images dir
	var imagesDir="/static/worldmap/img/";

	// Default camera position/zoom ...
	var defLat={{params['default_Lat']}};
	var defLng={{params['default_Lng']}};
	var defaultZoom={{params['default_zoom']}};

	// Markers ...
	var allMarkers = [];

    //------------------------------------------------------------------------
    // Create a marker on specified position for specified host/state with IW
    // content
    //------------------------------------------------------------------------
    // point : GPS coordinates
    // name : host name
    // state : host state
    // content : infoWindow content
    //------------------------------------------------------------------------
    var markerCreate = function(name, state, content, position, iconBase) {
        if (!iconBase) {
            iconBase='host';
        }
        var iconUrl = imagesDir + '/' + iconBase;
        if (state) {
            iconUrl += "-" + state;
        }
        iconUrl += ".png";

        var size = new google.maps.Size(32,32);
        var origin = new google.maps.Point(0,0);
        var anchor = new google.maps.Point(16,32);
        var markerImage = new google.maps.MarkerImage(
            iconUrl, size, origin, anchor);

        try {
            var markerOptions = {
                map: map,
                position: position,
                icon: markerImage,
                raiseOnDrag: false,
                draggable: true,
                title: name,
                hoststate: state,
                hostname: name,
                iw_content: content
            };
            var marker = new google.maps.Marker(markerOptions);

            // Register Custom "dragend" Event
            google.maps.event.addListener(marker, 'dragend', function() {
                // Center the map at given point
                map.panTo(marker.getPosition());
            });
        } catch (e) {
            console.error('markerCreate, exception : ' + e.message);
        }

        return marker;
    };

	//------------------------------------------------------------------------
	// Map initialization
	//------------------------------------------------------------------------
	//------------------------------------------------------------------------
	var mapInit = function mapInit() {
        var mapContainer = document.getElementById('map');
        var mapOptions = {
            center: new google.maps.LatLng (defLat, defLng),
            zoom: defaultZoom,
            mapTypeId: google.maps.MapTypeId.ROADMAP
        };
        var map = new google.maps.Map(mapContainer, mapOptions);
        var bounds = new google.maps.LatLngBounds();
        var infoWindow = new google.maps.InfoWindow;

        %for h in hosts:

        try {
            // Creating a marker for all hosts having GPS coordinates ...
            var latitude = {{float(h.customs.get('_LOC_LAT', params['default_Lat']))}};
            var longitude = {{float(h.customs.get('_LOC_LNG', params['default_Lng']))}};
            var gpsLocation = new google.maps.LatLng(latitude, longitude);

            var hostGlobalState = 0;
            var hostState = "{{h.state}}";
            switch(hostState.toUpperCase()) {
                case "UP":
                    hostGlobalState = 0;
                    break;
                case "DOWN":
                    hostGlobalState = 2;
                    break;
                default:
                    hostGlobalState = 1;
                    break;
            }

            var markerInfoWindowContent = [
                '<div class="map-infoView" id="iw-{{h.get_name()}}">',
                '<img class="map-iconHostState map-host-{{h.state}} map-host-{{h.state_type}}" src="{{app.helper.get_icon_state(h)}}" />',
                '<span class="map-hostname"><a href="/host/{{h.get_name()}}">{{h.get_name()}}</a> is {{h.state}}.</span>',
                '<hr/>',
                %if h.services:
                '<ul class="map-servicesList">',
                %for s in h.services:
                    '<li><span class="map-service map-service-{{s.state}} map-service-{{s.state_type}}"></span><a href="/service/{{h.get_name()}}/{{s.get_name()}}">{{s.get_name()}}</a> is {{s.state}}.</li>',
                %end
                '</ul>',
                %end
                '</div>'
            ].join('');
            %if h.services:
                %for s in h.services:
                    var serviceState = "{{s.state}}";
                    switch(serviceState.toUpperCase()) {
                        case "OK":
                            break;
                        case "UNKNOWN":
                        case "PENDING":
                        case "WARNING":
                            if (hostGlobalState < 1) {
                                hostGlobalState = 1;
                            }
                            break;
                        case "CRITICAL":
                            if (hostGlobalState < 2) {
                                hostGlobalState = 2;
                            }
                            break;
                    }
                %end
            %end

            var markerState = "UNKNOWN";
            switch(hostGlobalState) {
                case 0:
                    markerState = "OK";
                    break;
                case 2:
                    markerState = "KO";
                    break;
                default:
                    markerState = "WARNING";
                    break;
            }

            // Create marker and append to markers list ...
            allMarkers.push(markerCreate('{{h.get_name()}}', markerState, markerInfoWindowContent, gpsLocation, 'host'));
            bounds.extend(gpsLocation);
        } catch (e) {
            console.error('markerCreate, exception : ' + e.message);
        }

        %end
        %# End all hosts

        map.fitBounds(bounds);

        var markerClusterOptions = {
            zoomOnClick: true,
            showText: true,
            averageCenter: true,
            gridSize: 10,
            minimumClusterSize: 2,
            maxZoom: 18,
            styles: [
                { height: 50, width: 50, url: imagesDir+"/cluster-OK.png" },
                { height: 60, width: 60, url: imagesDir+"/cluster-WARNING.png" },
                { height: 60, width: 60, url: imagesDir+"/cluster-KO.png" }
            ],
            calculator: function calculator(markers, numStyles) {
                var clusterIndex = 1;
                var i;
                for (i=0; i < markers.length; i++) {
                    var currentMarker = markers[i];
                    switch(currentMarker.hoststate.toUpperCase()) {
                        case "OK":
                            break;
                        case "WARNING":
                            if (clusterIndex < 2) {
                                clusterIndex = 2;
                            }
                            break;
                        case "KO":
                            if (clusterIndex < 3) {
                                clusterIndex = 3;
                            }
                            break;
                    }
                }

                return {
                    text: markers.length,
                    index: clusterIndex
                };
            }
        };
        var markerCluster = new MarkerClusterer(map, allMarkers, markerClusterOptions);

        var omsOptions = {
            markersWontMove: true,
            markersWontHide: true,
            keepSpiderfied: true,
            nearbyDistance: 10,
            circleFootSeparation: 50,
            spiralFootSeparation: 50,
            spiralLengthFactor: 20
        }
        var oms = new OverlappingMarkerSpiderfier(map, omsOptions);
        oms.addListener('click', function(marker) {
            infoWindow.setContent(marker.iw_content);
            infoWindow.open(map, marker);
        });
        oms.addListener('spiderfy', function(markers) {
            infoWindow.close();
        });
        oms.addListener('unspiderfy', function(markers) {
            console.log('unspiderfy ...');
        });

        for (var i = 0; i < allMarkers.length; i++) {
            oms.addMarker(allMarkers[i]);
        }
	};

    var main = function main () {
        var markerWithLabelURI = "/static/worldmap/js/markerwithlabel_packed.js";
        var markerClusterURI = "/static/worldmap/js/markerclusterer_packed.js";
        var omsURI = "/static/worldmap/js/oms.min.js";
        $.when(
            $.getScript(markerClusterURI),
            $.getScript(markerWithLabelURI),
            $.getScript(omsURI),
            $.Deferred(function (deferred) {
                $(deferred.resolve);
            })
        ).done(function (){
            mapInit();
        });
    };

    $(document).ready(function () {
        var mapsApiURI = "http://maps.googleapis.com/maps/api/js?sensor=false&callback=main";
        $.getScript(mapsApiURI);
    });

</script>
