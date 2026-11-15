pragma Singleton

import QtQuick
import Quickshell

// Weather from open-meteo.com (free, no key) for every city a weather widget asks for.
// Refreshes every 15 minutes while a weather widget exists.
Singleton {
    id: root

    property var data: ({})     // "city|units" -> { place, temp, code, day, wind, humidity, hi, lo, days: [...] } or { error }

    readonly property var wanted: [...new Set(Widgets.items.filter(w => w.type === "weather" && (w.props.city ?? "").trim() !== "").map(w => key(w.props.city, w.props.units)))]
    onWantedChanged: refresh(false)

    Timer {
        interval: 15 * 60 * 1000
        running: root.wanted.length > 0
        repeat: true
        onTriggered: root.refresh(true)
    }

    function key(city, units) {
        return city.trim().toLowerCase() + "|" + (units || "celsius");
    }

    function refresh(force) {
        for (const k of wanted)
            if (force || !data[k] || data[k].error)
                load(k);
    }

    function put(k, v) {
        const d = Object.assign({}, data);
        d[k] = v;
        data = d;
    }

    function get(url, done) {
        const x = new XMLHttpRequest();
        x.onreadystatechange = () => {
            if (x.readyState !== XMLHttpRequest.DONE)
                return;
            let r = null;
            try {
                r = x.status === 200 ? JSON.parse(x.responseText) : null;
            } catch (e) {}
            done(r);
        };
        x.open("GET", url);
        x.send();
    }

    function load(k) {
        const [city, units] = k.split("|");
        put(k, Object.assign({}, data[k] ?? {}, { loading: true }));
        get(`https://geocoding-api.open-meteo.com/v1/search?count=1&language=en&name=${encodeURIComponent(city)}`, g => {
            const p = g?.results?.[0];
            if (!p) {
                put(k, { error: g ? "city not found" : "offline" });
                return;
            }
            get(`https://api.open-meteo.com/v1/forecast?latitude=${p.latitude}&longitude=${p.longitude}`
                + "&current=temperature_2m,weather_code,wind_speed_10m,relative_humidity_2m,is_day"
                + "&daily=weather_code,temperature_2m_max,temperature_2m_min&forecast_days=4&timezone=auto"
                + `&temperature_unit=${units}`, f => {
                if (!f?.current) {
                    put(k, { error: "offline" });
                    return;
                }
                const d = f.daily;
                put(k, {
                    place: p.name,
                    temp: Math.round(f.current.temperature_2m),
                    code: f.current.weather_code,
                    day: f.current.is_day === 1,
                    wind: Math.round(f.current.wind_speed_10m),
                    humidity: f.current.relative_humidity_2m,
                    hi: Math.round(d.temperature_2m_max[0]),
                    lo: Math.round(d.temperature_2m_min[0]),
                    days: d.time.slice(1).map((t, i) => ({
                        name: new Date(t + "T12:00").toLocaleDateString(Qt.locale(), "ddd").toLowerCase(),
                        code: d.weather_code[i + 1],
                        hi: Math.round(d.temperature_2m_max[i + 1]),
                        lo: Math.round(d.temperature_2m_min[i + 1])
                    }))
                });
            });
        });
    }

    // WMO weather codes -> Material Design glyph / words
    function icon(code, day) {
        if (code === 0)
            return day === false ? "󰖔" : "󰖙";
        if (code <= 2)
            return "󰖕";
        if (code === 3)
            return "󰖐";
        if (code <= 48)
            return "󰖑";
        if (code <= 57)
            return "󰖗";
        if (code <= 67)
            return "󰖖";
        if (code <= 77)
            return "󰖘";
        if (code <= 82)
            return "󰖖";
        if (code <= 86)
            return "󰖘";
        return "󰙾";
    }

    function words(code) {
        if (code === 0)
            return "clear";
        if (code <= 2)
            return "partly cloudy";
        if (code === 3)
            return "overcast";
        if (code <= 48)
            return "fog";
        if (code <= 57)
            return "drizzle";
        if (code <= 67)
            return "rain";
        if (code <= 77)
            return "snow";
        if (code <= 82)
            return "showers";
        if (code <= 86)
            return "snow showers";
        return "thunderstorm";
    }
}
