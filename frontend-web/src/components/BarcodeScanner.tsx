import React, { useEffect, useRef } from 'react';
import { Html5QrcodeScanner, Html5QrcodeScannerState } from 'html5-qrcode';
import { X } from 'lucide-react';

interface BarcodeScannerProps {
  onScanSuccess: (decodedText: string) => void;
  onScanError?: (errorMessage: string) => void;
  onClose: () => void;
}

const BarcodeScanner: React.FC<BarcodeScannerProps> = ({ onScanSuccess, onScanError, onClose }) => {
  const scannerRef = useRef<Html5QrcodeScanner | null>(null);

  useEffect(() => {
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

    // Cleanup on unmount
    return () => {
      if (scannerRef.current) {
        scannerRef.current.clear().catch(err => {
          console.error("Error clearing scanner on unmount", err);
        });
      }
    };
  }, [onScanSuccess, onScanError, onClose]);

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/80 p-4">
      <div className="relative w-full max-w-lg bg-white rounded-3xl overflow-hidden shadow-2xl">
        <div className="p-4 border-b flex justify-between items-center bg-gray-50">
          <h3 className="text-xl font-black text-gray-900">Scan Barcode / QR</h3>
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
        
        <div className="p-4">
          <div id="reader" className="overflow-hidden rounded-2xl border-2 border-dashed border-gray-300"></div>
          <p className="mt-4 text-center text-sm font-bold text-gray-500">
            Center the barcode or QR code in the box to scan
          </p>
        </div>
      </div>
    </div>
  );
};

export default BarcodeScanner;
