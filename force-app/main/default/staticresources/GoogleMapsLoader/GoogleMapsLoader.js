// googleMapsLoader.js

window.initializeGoogleMaps = function(apiKey, callback) {
    if (typeof google !== 'undefined' && google.maps) {
        callback(); // Already loaded
        return;
    }

    const script = document.createElement('script');
    script.src = `https://maps.googleapis.com/maps/api/js?key=${AIzaSyBIIkkOKYTv0I3je4DyuDFdPsEFguh}`;
    script.defer = true;
    script.async = true;

    script.onload = () => {
        callback();
    };

    script.onerror = () => {
        console.error('Google Maps API failed to load.');
    };

    document.body.appendChild(script);
};
