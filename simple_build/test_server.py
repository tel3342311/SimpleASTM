#!/usr/bin/env python3
"""
Simple ASTM Test Server
Receives ASTM messages and responds with appropriate control characters
"""

import socket
import threading
import time

class ASTMTestServer:
    def __init__(self, host='localhost', port=3000):
        self.host = host
        self.port = port
        self.server_socket = None
        self.running = False
        
    def start(self):
        """Start the ASTM test server"""
        print(f"🏥 Starting ASTM Test Server on {self.host}:{self.port}")
        print("📋 Ready to receive ASTM E1381/E1394 messages")
        print("=" * 50)
        
        self.server_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.server_socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        
        try:
            self.server_socket.bind((self.host, self.port))
            self.server_socket.listen(5)
            self.running = True
            
            print(f"✅ Server listening on {self.host}:{self.port}")
            print("⌨️  Press Ctrl+C to stop")
            print("-" * 50)
            
            while self.running:
                try:
                    client_socket, address = self.server_socket.accept()
                    print(f"🔗 New connection from {address}")
                    
                    # Handle client in separate thread
                    client_thread = threading.Thread(
                        target=self.handle_client,
                        args=(client_socket, address)
                    )
                    client_thread.daemon = True
                    client_thread.start()
                    
                except socket.error as e:
                    if self.running:
                        print(f"❌ Socket error: {e}")
                    break
                    
        except KeyboardInterrupt:
            print("\n🔌 Shutting down server...")
        except Exception as e:
            print(f"❌ Server error: {e}")
        finally:
            self.stop()
    
    def handle_client(self, client_socket, address):
        """Handle individual client connections"""
        try:
            while True:
                data = client_socket.recv(1024)
                if not data:
                    break
                
                # Process received data
                message = data.decode('ascii', errors='ignore')
                self.process_message(message, client_socket, address)
                
        except Exception as e:
            print(f"❌ Client handler error: {e}")
        finally:
            print(f"🔌 Client {address} disconnected")
            client_socket.close()
    
    def process_message(self, message, client_socket, address):
        """Process ASTM messages and send appropriate responses"""
        # Replace control characters with readable names for display
        display_message = (message
                          .replace('\x02', '<STX>')
                          .replace('\x03', '<ETX>')
                          .replace('\x17', '<ETB>')
                          .replace('\x05', '<ENQ>')
                          .replace('\x04', '<EOT>')
                          .replace('\x06', '<ACK>')
                          .replace('\x15', '<NAK>')
                          .replace('\r', '<CR>')
                          .replace('\n', '<LF>'))
        
        print(f"📥 From {address}: {display_message}")
        
        # Process different message types
        if '\x05' in message:  # ENQ
            print("   📝 Received ENQ (Enquiry) - Sending ACK")
            client_socket.send(b'\x06')  # Send ACK
            
        elif '\x04' in message:  # EOT
            print("   📝 Received EOT (End of Transmission) - Communication complete")
            
        elif '\x02' in message:  # STX (Frame start)
            print("   📝 Received ASTM frame - Sending ACK")
            client_socket.send(b'\x06')  # Send ACK
            
            # Parse ASTM record type
            if '|' in message:
                parts = message.split('|')
                if len(parts) > 0:
                    record_type = parts[0][-1] if parts[0] else ''
                    
                    if record_type == 'H':
                        print("      🏥 Header Record - System information")
                    elif record_type == 'P':
                        print("      👤 Patient Record - Demographics")
                    elif record_type == 'O':
                        print("      📋 Order Record - Test panel request")
                    elif record_type == 'R':
                        print("      🧪 Result Record - Lab test results")
                    elif record_type == 'C':
                        print("      💬 Comment Record - Additional info")
                    elif record_type == 'L':
                        print("      🔚 Terminator Record - End of message")
        
        print()  # Empty line for readability
    
    def stop(self):
        """Stop the server"""
        self.running = False
        if self.server_socket:
            self.server_socket.close()

if __name__ == "__main__":
    server = ASTMTestServer()
    try:
        server.start()
    except KeyboardInterrupt:
        print("\n👋 Server stopped by user")
    except Exception as e:
        print(f"💥 Unexpected error: {e}")