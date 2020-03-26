var
  afterBurnerProcs*:seq[proc(buffer: var seq[uint8], encoding:bool)]

proc swapBytesA*(x:var seq[uint8], encoding:bool)=
  if x.len >= 8:
    var b:seq[uint8]
    for i in countup(0,x.high - 7,8):
      b = x[i..i+7]
      
      x[i] = b[6]
      x[i+1] = b[5]
      x[i+2] = b[3]
      x[i+3] = b[2]
      x[i+4] = b[7]
      x[i+5] = b[1]
      x[i+6] = b[0]
      x[i+7] = b[4]


proc swapBytesBX*(x:var seq[uint8], encoding:bool)=
  if x.len >= 8:
    var b:seq[uint8]
    for i in countup(0,x.high - 7,8):
      b = x[i..i+7]
      
      x[i]   = b[7]
      x[i+1] = b[4]
      x[i+2] = b[6]
      x[i+3] = b[5]
      x[i+4] = b[1]
      x[i+5] = b[3]
      x[i+6] = b[2]
      x[i+7] = b[0]


proc swapBytesC*(x:var seq[uint8], encoding:bool)=
  if x.len >= 8:
    var b:seq[uint8]
    for i in countup(0,x.high - 7,8):
      b = x[i..i+7]

      x[i]   = b[4]
      x[i+1] = b[2]
      x[i+2] = b[1]
      x[i+3] = b[7]
      x[i+4] = b[0]
      x[i+5] = b[6]
      x[i+6] = b[5]
      x[i+7] = b[3]
    

## extend bitgrinderpkg/afterburner with your procs
## so your encryption will be unique!
## but don't forget to save it before pull...

#! init procs!
afterBurnerProcs.add(swapBytesA)
afterBurnerProcs.add(swapBytesBX)
afterBurnerProcs.add(swapBytesC)
