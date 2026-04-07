import React, { useEffect, useRef, useState } from 'react';
import { Html5QrcodeScanner } from 'html5-qrcode';
import { X, Camera, Keyboard } from 'lucide-react';
import { useExternalScanner } from '../hooks/useExternalScanner';

interface BarcodeScannerProps {
  onScanSuccess: (decodedText: string) => void;
  onScanError?: (errorMessage: string) => void;
  onClose: () => void;
}

const BarcodeScanner: React.FC<BarcodeScannerProps> = ({ onScanSuccess, onScanError, onClose }) => {
  const scannerRef = useRef<Html5QrcodeScanner | null>(null);
  const [mode, setMode] = useState<'camera' | 'external'>('camera');

  // Listen for external hardware scanner
  useExternalScanner((code) => {
    onScanSuccess(code);
    onClose();
  });

  useEffect(() => {
    if (mode === 'camera') {
      // Configuration for the scanner
      const config = {
        fps: 10,
        qrbox: { width: 250, height: 250 },
        aspectRatio: 1.0,
        showTorchButtonIfSupported: true,
        showZoomSliderIfSupported: true,
        defaultZoomValueIfSupported: 2,
      };

      // Initialize scanner
      const scanner = new Html5QrcodeScanner("reader", config, /* verbose= */ false);
      scannerRef.current = scanner;

      const onSuccess = (decodedText: string) => {
        // Clear scanner on success to stop camera
        if (scannerRef.current) {
          scannerRef.current.clear().then(() => {
            onScanSuccess(decodedText);
            onClose();
          }).catch((err) => {
            console.error("Failed to clear scanner", err);
            onScanSuccess(decodedText);
            onClose();
          });
        }
      };

      const onError = (errorMessage: string) => {
        if (onScanError) {
          onScanError(errorMessage);
        }
      };

      scanner.render(onSuccess, onError);
    } else {
      // If switching to external mode, clear the camera scanner if it exists
      if (scannerRef.current) {
        scannerRef.current.clear().catch(err => {
          console.error("Error clearing scanner when switching modes", err);
        });
        scannerRef.current = null;
      }
    }

    // Cleanup on unmount or mode change
    return () => {
      if (scannerRef.current) {
        scannerRef.current.clear().catch(err => {
          console.error("Error clearing scanner on cleanup", err);
        });
        scannerRef.current = null;
      }
    };
  }, [mode, onScanSuccess, onScanError, onClose]);

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/80 p-4">
      <div className="relative w-full max-w-lg bg-white rounded-3xl overflow-hidden shadow-2xl">
        <div className="p-4 border-b flex justify-between items-center bg-gray-50">
          <div className="flex gap-4">
            <button 
              onClick={() => setMode('camera')}
              className={`flex items-center gap-2 px-3 py-1.5 rounded-xl font-bold transition-all ${
                mode === 'camera' ? 'bg-primary-600 text-white' : 'text-gray-500 hover:bg-gray-100'
              }`}
            >
              <Camera size={18} />
              Camera
            </button>
            <button 
              onClick={() => setMode('external')}
              className={`flex items-center gap-2 px-3 py-1.5 rounded-xl font-bold transition-all ${
                mode === 'external' ? 'bg-primary-600 text-white' : 'text-gray-500 hover:bg-gray-100'
              }`}
            >
              <Keyboard size={18} />
              Hardware Scanner
            </button>
          </div>
          <button 
            onClick={() => {
              if (scannerRef.current) {
                scannerRef.current.clear().then(onClose).catch(onClose);
              } else {
                onClose();
              }
            }}
            className="p-2 hover:bg-gray-200 rounded-full transition-colors"
          >
            <X className="w-6 h-6 text-gray-600" />
          </button>
        </div>
        
        <div className="p-6">
          {mode === 'camera' ? (
            <>
              <div id="reader" className="overflow-hidden rounded-2xl border-2 border-dashed border-gray-300"></div>
              <p className="mt-4 text-center text-sm font-bold text-gray-500">
                Center the barcode or QR code in the box to scan
              </p>
            </>
          ) : (
            <div className="py-12 flex flex-col items-center justify-center text-center">
              <div className="w-20 h-20 bg-primary-50 text-primary-600 rounded-full flex items-center justify-center mb-6 animate-pulse">
                <Keyboard size={40} />
              </div>
              <h4 className="text-xl font-black text-gray-900 mb-2">Hardware Scanner Ready</h4>
              <p className="text-gray-500 font-medium max-w-xs mx-auto">
                Please use your external barcode scanner now. The data will be captured automatically.
              </p>
              <div className="mt-8 px-4 py-2 bg-gray-100 rounded-full text-xs font-bold text-gray-400 uppercase tracking-widest">
                Waiting for input...
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  );
};

export default BarcodeScanner;
