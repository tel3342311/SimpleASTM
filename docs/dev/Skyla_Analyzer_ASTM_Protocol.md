# Skyla Clinical Chemistry Analyzer – ASTM Communication Protocol

版本：2023/03/03  
來源：Skyla Data Manager 文件  

---

## 1. Introduction

### 1.1 Document Purpose
- 描述 **Skyla Solution** 如何透過 ASTM 協定傳輸資料至電腦 (Host)。  
- 支援 Ethernet (TCP) 與 RS-232。  
- 文件目的：指導如何建立資料傳輸。  

### 1.2 ASTM Standards
- **E1394-97**: 資料格式。  
- **E1381-95**: 低階傳輸協定。  

---

## 2. Communication

### 2.1 Low-Level Protocol

#### 2.1.1 Serial Port Configurations
- **Baud Rate**: 預設 115200 (可選 57600, 38400, 19200, 9600, 4800)  
- **Parity**: None  
- **Data bits**: 8  

#### 2.1.2 Frame Structure
- **Intermediate Frame**  
```
<STX> FN Text <ETB> C1 C2 <CR><LF>
```
- **End Frame**  
```
<STX> FN Text <ETX> C1 C2 <CR><LF>
```
- **Control Characters**  
  - ENQ: 0x05  
  - ACK: 0x06  
  - NAK: 0x15  
  - EOT: 0x04  
  - STX: 0x02  
  - ETB: 0x17  
  - ETX: 0x03  
  - CR: 0x0D  
  - LF: 0x0A  

#### 2.1.3 Special Conditions
- **Contention**: 雙方同時 ENQ，Solution 優先，重試 10s，最多 2 次。  
- **Busy**: Host 回 NAK，Solution 10s 後重試，最多 2 次。  
- **Receiver Interrupts**: Host 回 EOT，Solution 視為 ACK。  

#### 2.1.4 Transmission Directions
- 雙向，Solution 或 Host 皆可發起。  
- 範例流程：  
```
ENQ → ACK → Frames → EOT
```

#### 2.1.5 Escape Delimiters
- `|` = Field delimiter  
- `^` = Component delimiter  
- `\` = Repeat delimiter  
- `&` = Escape delimiter  

---

### 2.2 High-Level Protocol

包含三類訊息：  
- Analytic Result Messages  
- Connection Status Messages  
- Work List Messages  

---

#### 2.2.1 Analytic Result Messages

##### Header Record (H)
- Sender Info、SW Version、Process ID、ASTM Version、Timestamp

##### Patient Record (P)
- Patient ID、Name、Age、Gender、Species、Weight、Hospital

##### Order Record (O)
- Test Panel、Action Code (N/Q)、Sample Type、PR Code、Report Type

##### Result Record (R)
- Marker/Test ID、Value、Unit、Ref Range、Flags (L/H/</>/N/A)

##### Comment Record (C)
- 特定測試解讀（例：cCOR）

##### Terminator Record (L)
- 結束訊息 (N = Normal Termination)  

**範例：正常分析結果**
```
H|\^&|||Skyla Solution^4.2.0.0|||||P|1|20220308092241
P|1||BBB||金城武||^5^Year|M|||||||OwnerName|Canine||16^Kg||||||||||||||||
O|1|000030||^^^LiverPanel|A|20220308092241|||||N||||||||||||||
R|1|^^^ALB|3.0|g/dL|2.3-4.0|N||||F||20220308092241
R|2|^^^ALT|35|U/L|10-100|N||||F||20220308092241
L|1|N
```

**範例：異常分析結果**
```
R|3|^^^ALB|1.8|g/dL|2.3-4.0|L||||F||20220308092241
```

**範例：單一檢測**
```
O|1|000031||^^^GLU|A|20220308092241|||||N||||||||||||||
R|1|^^^GLU|145|mg/dL|74-143|H||||F||20220308092241
```

**範例：cCOR 註解**
```
C|1|I|^cCOR (Canine Corrected Cortisol): 2.3 μg/dL (Normal)|
```

---

#### 2.2.2 Connection Status Messages
- 組成：Header + Comment + Terminator  
- Solution → Host：Connect / Disconnect  
- Host → Solution：Disconnect  

**範例**
```
C|1|I|SN^Connect|G
```

---

#### 2.2.3 Work List Messages

##### Item Order Message
- Host 新增 (N) 或刪除 (C) 檢測項目。  

##### Item Status Message
- Solution 回覆 Queue/Analyzing/Error/Cancel/Full。  

**範例：新增**
```
O|1|000040||^^^LiverPanel|N|20220308092241|||||N||||||||||||||
```

**範例：刪除**
```
O|1|000040||^^^LiverPanel|C|20220308092241|||||N||||||||||||||
```

**範例：狀態回覆**
```
C|1|I|SN^Queued|G
```

---

#### 2.2.4 Reconnection
- 斷線後重新連線，Solution 需回傳 Work List 狀態更新。  

---

## 3. Appendix

### Appendix A: ASCII Table (IBM 850)
（略，請參考原始文件）

### Appendix B: Marker Naming
- ALB = Albumin  
- ALT = Alanine Aminotransferase  
- GLU = Glucose  
- ...（完整列表見原始文件）  

### Appendix C: Single Assay Item List
- Liver Panel → ALB, ALT, AST, ALP, TBIL, DBIL, TP, GLOB, A/G  
- Kidney Panel → BUN, CREA, UA, PHOS, CA  
- ...（完整列表見原始文件）  

---
