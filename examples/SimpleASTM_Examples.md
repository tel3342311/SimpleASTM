# SimpleASTM Simulator Examples

This document provides practical examples of using the SimpleASTM simulator to test ASTM E1381/E1394 protocol implementations.

## Getting Started

1. Launch the SimpleASTM app
2. Navigate to the "Simulator" tab
3. Configure connection settings (default: localhost:3000)
4. Click "Connect" to establish TCP connection
5. Send test messages using the interface

## Example ASTM Messages

### 1. Normal Liver Panel Results

**Patient Information:**
- Name: 金城武 (Jin Chengwu)
- ID: BBB
- Age: 5 years
- Gender: Male
- Species: Canine
- Weight: 16 kg

**Generated ASTM Message:**
```
H|\^&|||Skyla Solution^4.2.0.0|||||P|1|20220308092241
P|1||BBB||金城武||^5^Year|M|||||||OwnerName|Canine||16^Kg||||||||||||||||
O|1|000030||^^^LiverPanel|A|20220308092241|||||N||||||||||||||
R|1|^^^ALB|3.0|g/dL|2.3-4.0|N||||F||20220308092241
R|2|^^^ALT|35|U/L|10-100|N||||F||20220308092241
L|1|N
```

### 2. Abnormal Results with Flags

**Low Albumin and High ALT:**
```
H|\^&|||Skyla Solution^4.2.0.0|||||P|1|20220308092241
P|1||CCC||Test Patient||^3^Year|F|||||||Owner|Canine||12^Kg||||||||||||||||
O|1|000031||^^^LiverPanel|A|20220308092241|||||N||||||||||||||
R|1|^^^ALB|1.8|g/dL|2.3-4.0|L||||F||20220308092241
R|2|^^^ALT|150|U/L|10-100|H||||F||20220308092241
L|1|N
```

### 3. Single Glucose Test

**High Glucose Result:**
```
H|\^&|||Skyla Solution^4.2.0.0|||||P|1|20220308092241
P|1||DDD||Single Test||^7^Year|M|||||||SingleOwner|Canine||20^Kg||||||||||||||||
O|1|000032||^^^GLU|A|20220308092241|||||N||||||||||||||
R|1|^^^GLU|145|mg/dL|74-143|H||||F||20220308092241
L|1|N
```

### 4. Work List Messages

**Add to Work List:**
```
H|\^&|||Skyla Solution^4.2.0.0|||||P|1|20220308092241
O|1|WL001||^^^LiverPanel|N|20220308092241|||||N||||||||||||||
L|1|N
```

**Cancel from Work List:**
```
H|\^&|||Skyla Solution^4.2.0.0|||||P|1|20220308092241
O|1|WL001||^^^LiverPanel|C|20220308092241|||||N||||||||||||||
L|1|N
```

### 5. Connection Status Messages

**Connect Message:**
```
H|\^&|||Skyla Solution^4.2.0.0|||||P|1|20220308092241
C|1|I|SN^Connect|G
L|1|N
```

**Disconnect Message:**
```
H|\^&|||Skyla Solution^4.2.0.0|||||P|1|20220308092241
C|1|I|SN^Disconnect|G
L|1|N
```

## Testing Scenarios

### Scenario 1: Basic Connection Test

1. Start a TCP server on localhost:3000
2. Open SimpleASTM simulator
3. Click "Connect"
4. Verify connection status shows "Connected"
5. Send a "Normal Liver Panel" message
6. Check server receives proper ASTM frames

### Scenario 2: Protocol Compliance Test

1. Connect to ASTM-compliant server
2. Send ENQ control character
3. Wait for ACK response
4. Send framed message with proper checksums
5. Verify EOT transmission completion
6. Monitor logs for protocol compliance

### Scenario 3: Error Handling Test

1. Connect to server
2. Disconnect server while transmitting
3. Verify client handles connection errors
4. Reconnect and verify recovery
5. Check error logs for proper error reporting

### Scenario 4: Load Testing

1. Use "Test Data" tab
2. Configure custom patient information
3. Select "Send 20 Messages" for bulk testing
4. Monitor transmission status
5. Verify all messages sent successfully

## Message Frame Structure

Each ASTM message is transmitted as frames with this structure:

```
<STX> FN Text <ETB/ETX> C1 C2 <CR><LF>
```

Where:
- `<STX>` = Start of Text (0x02)
- `FN` = Frame Number (0-7, cycling)
- `Text` = ASTM record content
- `<ETB>` = End of Transmission Block (0x17) for intermediate frames
- `<ETX>` = End of Text (0x03) for final frame
- `C1 C2` = Checksum bytes (hexadecimal)
- `<CR><LF>` = Carriage Return + Line Feed (0x0D 0x0A)

## Test Panels Available

### Liver Panel Tests
- **ALB** (Albumin): 2.3-4.0 g/dL
- **ALT** (Alanine Aminotransferase): 10-100 U/L
- **AST** (Aspartate Aminotransferase): 15-66 U/L
- **ALP** (Alkaline Phosphatase): 23-212 U/L
- **TBIL** (Total Bilirubin): 0.1-0.3 mg/dL

### Kidney Panel Tests
- **BUN** (Blood Urea Nitrogen): 7-27 mg/dL
- **CREA** (Creatinine): 0.5-1.8 mg/dL
- **UA** (Uric Acid): 0-1 mg/dL
- **PHOS** (Phosphorus): 2.5-6.8 mg/dL

## Result Flags

- **N** = Normal (within reference range)
- **L** = Low (below reference range)
- **H** = High (above reference range)
- **<** = Critical Low (significantly below range)
- **>** = Critical High (significantly above range)
- **A** = Abnormal (non-numeric abnormality)

## Troubleshooting

### Connection Issues
1. Verify server is running on specified port
2. Check firewall settings
3. Ensure correct host address and port
4. Try connecting to different port (1200 for ASTM standard)

### Message Transmission Issues
1. Check connection status before sending
2. Monitor logs for error messages
3. Verify server supports ASTM protocol
4. Test with simple messages first

### Protocol Compliance Issues
1. Enable detailed logging
2. Check frame structure and checksums
3. Verify control character handling
4. Test with ASTM-compliant server

## Advanced Usage

### Custom Message Creation
1. Use "Test Data" tab
2. Configure patient information
3. Select test panel
4. Generate custom results
5. Preview before sending

### Log Analysis
1. Use "Logs" tab for detailed analysis
2. Filter by level (Error, Warning, Info, Debug)
3. Filter by category (Connection, Protocol, Message)
4. Export logs for external analysis

### Real-time Monitoring
1. Use "Monitor" tab during testing
2. Watch connection health indicators
3. Monitor message statistics
4. Analyze protocol compliance metrics

## Integration Examples

### Example TCP Server (Python)
```python
import socket
import threading

def handle_client(client_socket):
    try:
        while True:
            data = client_socket.recv(1024)
            if not data:
                break
            print(f"Received: {data.decode('ascii', errors='ignore')}")
            # Send ACK response
            client_socket.send(b'\x06')  # ACK
    except Exception as e:
        print(f"Error: {e}")
    finally:
        client_socket.close()

server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
server.bind(('localhost', 3000))
server.listen(5)

while True:
    client, addr = server.accept()
    threading.Thread(target=handle_client, args=(client,)).start()
```

This example creates a basic TCP server that receives ASTM messages and responds with ACK characters.