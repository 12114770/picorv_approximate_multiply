import sys
import numpy as np

with open(sys.argv[1]) as file:
  content = file.readlines()[3:-1]

MED = 0.0
MRED = 0.0

num_zeros = 0

# Calculate exact product and calculate MED/MRED out of exact and approximated values
for line in content:
  try:
    line = line.split(" ")
    a = int(line[0])
    b = int(line[1])
    result = int(line[2])
    MED += np.abs(result - a * b)
    if a == 0 or b == 0:
      num_zeros += 1
    else:
      MRED += np.abs(result - a * b)/(a * b)
  except:
    print(line)
#print(f"MED = {MED}")

# Calculate MED
MED /= len(content)
print(f"MED = {MED}")

# Calculate MRED
MRED /= len(content) - num_zeros

# Calculate NMED
NMED = MED / ((2 ** 32) - 1)

print(f"NMED = {NMED}")
print(f"MRED = {MRED}")
