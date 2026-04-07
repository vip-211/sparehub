import { useEffect, useRef } from 'react';

/**
 * Hook to listen for external barcode scanner input (HID keyboard mode).
 * Scanners send characters rapidly followed by 'Enter'.
 * @param onScan Callback function called when a full code is scanned.
 */
export const useExternalScanner = (onScan: (code: string) => void) => {
  const buffer = useRef<string>('');
  const lastKeyTime = useRef<number>(0);
  const SCAN_THRESHOLD = 50; // Milliseconds between keypresses for a scanner
  const MIN_LENGTH = 3;      // Minimum characters for a barcode

  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      // Avoid interference when the user is typing in a text field
      const target = e.target as HTMLElement;
      const isInput = target.tagName === 'INPUT' || target.tagName === 'TEXTAREA' || target.isContentEditable;
      
      const currentTime = Date.now();
      const diff = currentTime - lastKeyTime.current;
      
      // If the time between keys is too long, it's human typing. Reset.
      if (diff > SCAN_THRESHOLD) {
        buffer.current = '';
      }
      
      lastKeyTime.current = currentTime;

      // Check if it's the 'Enter' key, which signifies the end of a scan
      if (e.key === 'Enter') {
        if (buffer.current.length >= MIN_LENGTH) {
          onScan(buffer.current);
          buffer.current = '';
          // Prevent the Enter key from submitting a form if a scan occurred
          if (!isInput) e.preventDefault();
        }
        return;
      }

      // Add alphanumeric characters to the buffer
      if (e.key.length === 1) {
        buffer.current += e.key;
      }
    };

    window.addEventListener('keydown', handleKeyDown);
    return () => {
      window.removeEventListener('keydown', handleKeyDown);
    };
  }, [onScan]);
};
