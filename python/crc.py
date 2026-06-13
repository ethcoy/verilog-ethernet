data = 0x52
data_len = 8

plynml = 0x15B
crc_len = 8

plynml_len = crc_len + 1

plynml = plynml << (data_len - 1)

rslt = data << crc_len

for i in range(data_len):
    if (rslt & 2**(data_len + crc_len - 1)):
        rslt = rslt ^ plynml
    rslt = rslt << 1

print(f'{crc_len}-bit CRC = {hex(rslt >> 8)}')   

# Result equals data << CRC-X length
# rslt = data << crc_len

# Position equals CRC-X length + data length - 1
# pstn = data_len + crc_len - 1

# XOR position equals data length + CRC-X length - polynomial length
# xor_pstn = plynml << (data_len - 1)

# Repeat for data length times
# for i in range(data_len):
#     print(f'Result before: {bin(rslt)}')
#     print(f'XOR:           {bin(xor_pstn)}')      
#     if (rslt & (2**pstn)):
#         rslt = rslt ^ xor_pstn
#     print(f'Result after:  {bin(rslt)}\n')
#     xor_pstn >>= 1
#     pstn -= 1
    
# print(f'{crc_len}-bit CRC = {hex(rslt)}')   