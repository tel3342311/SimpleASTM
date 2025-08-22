#!/usr/bin/env python3
import socket
import threading

def handle_client(client_socket, addr):
    print(f"🔗 Client connected: {addr}")
    
    try:
        while True:
            data = client_socket.recv(1024)
            if not data:
                break
                
            # Display received data
            hex_data = ' '.join(f'{b:02X}' for b in data)
            print(f"📥 Received: {hex_data}")
            
            # Decode and display ASTM content
            try:
                message = data.decode('ascii', errors='ignore')
                display = message.replace('\x02', '<STX>').replace('\x03', '<ETX>').replace('\x17', '<ETB>').replace('\x05', '<ENQ>').replace('\x04', '<EOT>').replace('\r', '<CR>').replace('\n', '<LF>')
                print(f"📄 Content: {display}")
                
                # Parse ASTM records
                if '|' in message and len(message) > 2:
                    record_type = message[message.find('\x02')+2:message.find('\x02')+3] if '\x02' in message else ''
                    if record_type in 'HPORLC':
                        record_names = {'H': 'Header', 'P': 'Patient', 'O': 'Order', 'R': 'Result', 'L': 'Terminator', 'C': 'Comment'}
                        print(f"📋 ASTM {record_names.get(record_type, 'Unknown')} Record")
                
            except:
                pass
            
            # Send ACK for frames, ignore for control chars
            if b'\x02' in data:  # STX found - this is a frame
                client_socket.send(b'\x06')  # ACK
                print("📤 Sent: ACK")
            elif b'\x05' in data:  # ENQ
                client_socket.send(b'\x06')  # ACK
                print("📤 Sent: ACK (for ENQ)")
            
            print("-" * 40)
                
    except Exception as e:
        print(f"❌ Error: {e}")
    finally:
        client_socket.close()
        print(f"🔌 Client {addr} disconnected")

def start_server():
    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server.bind(('localhost', 3000))
    server.listen(5)
    
    print("🏥 ASTM Test Server Started")
    print("📍 Listening on localhost:3000")
    print("📋 Ready to receive ASTM messages")
    print("=" * 40)
    
    try:
        while True:
            client, addr = server.accept()
            threading.Thread(target=handle_client, args=(client, addr), daemon=True).start()
    except KeyboardInterrupt:
        print("\n🔌 Server stopped")
    finally:
        server.close()

if __name__ == "__main__":
    start_server()
