import React, { useEffect, useMemo, useRef, useState } from 'react';
import { useParams } from 'react-router-dom';

type LocationUpdate = {
  lat: number;
  lon: number;
  ts?: string;
};

const OrderTracking: React.FC = () => {
  const { id } = useParams();
  const [loc, setLoc] = useState<LocationUpdate | null>(null);
  const [status, setStatus] = useState<'connecting' | 'connected' | 'error'>('connecting');
  const wsRef = useRef<WebSocket | null>(null);

  useEffect(() => {
    const apiBase = import.meta.env.VITE_API_BASE as string | undefined;
    let url: string;
    if (apiBase && apiBase.length > 0) {
      try {
        const httpOrigin = new URL(apiBase).origin; // e.g. https://host
        const wsOrigin = httpOrigin.replace(/^https:/, 'wss:').replace(/^http:/, 'ws:');
        url = `${wsOrigin}/ws/orders/${id}/location`;
      } catch {
        const proto = window.location.protocol === 'https:' ? 'wss' : 'ws';
        url = `${proto}://${window.location.host}/ws/orders/${id}/location`;
      }
    } else {
      const proto = window.location.protocol === 'https:' ? 'wss' : 'ws';
      url = `${proto}://${window.location.host}/ws/orders/${id}/location`;
    }
    try {
      const ws = new WebSocket(url);
      wsRef.current = ws;
      ws.onopen = () => setStatus('connected');
      ws.onmessage = (ev) => {
        try {
          const data = JSON.parse(ev.data);
          if (typeof data.lat === 'number' && typeof data.lon === 'number') {
            setLoc({ lat: data.lat, lon: data.lon, ts: data.ts });
          }
        } catch {
          // ignore malformed messages
        }
      };
      ws.onerror = () => setStatus('error');
      ws.onclose = () => {
        // try to reconnect after short delay
        setStatus('error');
      };
    } catch {
      setStatus('error');
    }
    return () => {
      wsRef.current?.close();
    };
  }, [id]);

  const bbox = useMemo(() => {
    if (!loc) return null;
    const dLat = 0.02;
    const dLon = 0.02;
    const minLon = loc.lon - dLon;
    const minLat = loc.lat - dLat;
    const maxLon = loc.lon + dLon;
    const maxLat = loc.lat + dLat;
    return `${minLon}%2C${minLat}%2C${maxLon}%2C${maxLat}`;
  }, [loc]);

  const osmEmbedSrc = useMemo(() => {
    if (!loc || !bbox) return null;
    return `https://www.openstreetmap.org/export/embed.html?bbox=${bbox}&layer=mapnik&marker=${loc.lat}%2C${loc.lon}`;
  }, [loc, bbox]);

  const osmLink = useMemo(() => {
    if (!loc) return null;
    return `https://www.openstreetmap.org/?mlat=${loc.lat}&mlon=${loc.lon}#map=15/${loc.lat}/${loc.lon}`;
  }, [loc]);

  return (
    <div className="container mx-auto">
      <div className="bg-white rounded-xl shadow-sm border border-gray-100 p-6 mb-6">
        <h1 className="text-xl font-bold">Order #{id} Live Tracking</h1>
        <p className="text-gray-500 text-sm mt-1">
          {status === 'connecting' && 'Connecting to live location...'}
          {status === 'connected' && 'Receiving live updates.'}
          {status === 'error' && 'Live updates unavailable. Retrying or check backend WebSocket.'}
        </p>
      </div>
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <div className="lg:col-span-2 bg-white rounded-xl shadow-sm border border-gray-100 overflow-hidden">
          {osmEmbedSrc ? (
            <iframe
              title="OpenStreetMap"
              className="w-full h-[480px] border-0"
              src={osmEmbedSrc}
            />
          ) : (
            <div className="p-6 text-gray-600">
              {status === 'connected'
                ? 'Waiting for live location...'
                : 'Map not available'}
            </div>
          )}
        </div>
        <div className="bg-white rounded-xl shadow-sm border border-gray-100 p-6">
          <h2 className="font-semibold mb-3">Current Location</h2>
          {loc ? (
            <div className="space-y-2 text-sm text-gray-700">
              <div>Latitude: {loc.lat.toFixed(6)}</div>
              <div>Longitude: {loc.lon.toFixed(6)}</div>
              {loc.ts && <div>Updated: {new Date(loc.ts).toLocaleString()}</div>}
              {osmLink && (
                <a
                  href={osmLink}
                  target="_blank"
                  rel="noreferrer"
                  className="inline-block mt-3 text-primary-600 hover:text-primary-800 font-medium"
                >
                  Open in OpenStreetMap
                </a>
              )}
            </div>
          ) : (
            <div className="text-gray-500">No coordinates received yet.</div>
          )}
        </div>
      </div>
    </div>
  );
};

export default OrderTracking;
