import math

DEPTH = 512
MAX_VAL = 1023
VAL_PER_LINE = 11

vals = []
for i in range(DEPTH):
    vals.append(round(((math.sin(2 * math.pi * i / DEPTH - math.pi/2) + 1) / 2) * MAX_VAL))

with open("sin_wave_table.sv", "w") as f:
    f.write('// Include with `include "sin_wave_table.sv"\n')
    f.write(f"const logic [9:0] wave_table [0:{DEPTH-1}] = '{{\n")
    for row in range(0, DEPTH, VAL_PER_LINE):
        chunk = ", ".join(f"10'd{v}" for v in vals[row:row+VAL_PER_LINE])
        f.write(chunk + (",\n" if row + VAL_PER_LINE < DEPTH else "\n"))
    f.write("};\n")
