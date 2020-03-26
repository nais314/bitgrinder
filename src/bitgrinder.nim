import times

#*-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-

template benchmark(benchmarkName: string, code: untyped) =
  ## used for verbose outputs
  ## https://forum.nim-lang.org/t/5579#34696
  var
    t0, elapsed: float

  t0 = epochTime()

  code
    
  elapsed += epochTime() - t0
  
  var days,hours,mins,secs:int
  if elapsed >= 24*60*60:
    days = (elapsed / (24*60*60)).int
    elapsed = elapsed - (days * (24*60*60)).float
  
  if elapsed >= 60*60:
    hours = (elapsed / (60*60)).int
    elapsed = elapsed - (hours * 60 * 60).float
  
  if elapsed >= 60:
    mins = (elapsed / 60).int
    elapsed = elapsed - (mins * 60).float
  
  echo "CPU Time [", benchmarkName, "] ", days,"d ",hours,":",mins,":",elapsed.formatFloat(format = ffDecimal, precision = 3), "\n"

#*-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-

proc swapBytes*(x: var seq[uint8], a,b:int)=
  var temp = x[b]
  x[b] = x[a]
  x[a] = temp

#*-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-

import bitops
import random
import strutils, strformat
import algorithm


type
  ByteSeq* = seq[uint8]
  KeyTable* = seq[ByteSeq] #array[0..KeyTableRows-1,ByteSeq]
  KeyExpandMode* = enum
    ## kemContinuos generates new Keytable from last key
    ## kemBlock generates Keytable from previous Keytable,
    ## each key is expanded to new key
    kemAuto, # not forced - kemRepeat is default, or kemBlock if a key is present
    kemRepeat, # reuse keytable
    kemContinuos, # expand(oldKey)
    kemBlock # for keyTable: expandkey(keyTable[i])


const
  MinKeyLen* = 16 #TODO
  MinKeyTableRows* = 16 #512 bits #TODO
var
  KeyLen* = 16 # len of 1 key
  KeyTableRows* = 16 # num keys in keytable, 16*16bytes == 2048bits 256bytes
  
  KeyExpandProc*: uint8 = 128 # wich expand method to use
  PreBurn* = 0

#_________________________________________________________

## important base/utility functions

proc toByteSeq*(x:string): ByteSeq =
  for c in x:
    result.add(c.uint8)
    
proc toString*(x:ByteSeq): string =
  for c in x:
    result.add(c.chr)



proc getRand*(key:uint8):uint8=
  randomize()
  let a: int = (key and 0b11).int
  for i in 0..a:
    result = rand(255).uint8


proc passToKey*(pass:string): ByteSeq # FWD declaration

#_________________________________________________________



# DEV test funcs................................
#[ proc getAKey*(byteLen:int=16): ByteSeq =
  ## for testing only
  randomize()
  var num: uint8
  for i in 1..byteLen:
    num = sample([rand(255),rand(255),rand(255)]).uint8
    result.add(num)
    #echo num
  result = result.changeDuplicates()
 ]#

#[ proc getAKeyFromStr(str:string):ByteSeq=
  #TODO
  let dStr = base64.decode(str)
  for i in 0..dStr.high:
    result.add(dStr[i].uint8) ]#

#[ proc getTestKey(): ByteSeq =
  ## for testing only
  for i in 1..16:
    result.add( (16 * i - 1).uint8 ) ]#

#_________________________________________________________



proc changeDuplicates*(a:ByteSeq):ByteSeq= #!CHANGEDUPLICATES
  ## used @ key expansion
  result = a

  var passsalt2: uint8
  for c in 0..result.high:
    var p2x = result
    p2x.delete(c)
    for cc in 0..p2x.high:
      passsalt2 = ((passsalt2 + cc.uint8 * 15) xor p2x[cc])
    result[c] = passsalt2

proc changeDuplicatesB*(a:ByteSeq):ByteSeq= #!CHANGEDUPLICATES
  ## can be used on max len 256 Byteseqs
  result = a
  var oke = false
  var rounds = 0
  while not oke and rounds < 16:
    oke = true
    rounds += 1
    for i in 0..result.high:
      var b = 1.uint8
      for c in 0..result.high:
        if c == i: continue
        if result[c] == result[i]:
          result[c] += b
          b += 1
          oke = false
          result[c] = bitnot(result[c]) + c.uint8


proc changeDuplicatesC*(a:ByteSeq):ByteSeq= #!CHANGEDUPLICATES
  ## can be used on max len 256 Byteseqs
  result = a
  var oke = false
  var rounds = 0
  while not oke and rounds < 16:
    oke = true
    rounds += 1
    for i in 0..result.high:
      var b = 1.uint8
      for c in 0..result.high:
        if c == i: continue
        if result[c] == result[i]:
          oke = false
          if c < result.high:
            result[c] = (result[c] + result[c+1])
          else:
            result[c] = (result[c] + result[0])

proc changeDuplicatesC2*(a:ByteSeq):ByteSeq= #!CHANGEDUPLICATES
  result = a
  for c in 0..result.high:
    if c < result.high:
      result[c] = (result[c] + result[c+1])
    else:
      result[c] = (result[c] + result[0])

proc changeDuplicates*(keyTable: var KeyTable)= #!CHANGEDUPLICATES
  var oke = false
  var rounds = 0
  while not oke and rounds < 2:
    oke = true
    rounds += 1
    var b = 1.uint8
    for keyi in 0..keyTable.high:
      for ci in 0..keyTable[0].high:
        for r in 0..keyTable.high:
          for c in 0..keyTable[0].high:
            if c == ci and r == keyi: continue
            if keyTable[keyi][ci] == keyTable[r][c]:
              oke = false
              keyTable[r][c] += b
              b += 1

              if keyTable[r][c] == 0: keyTable[r][c] = b

              if c < keyTable[0].high:
                #keyTable[r][c] = keyTable[r][c] + keyTable[r][c+1]
                keyTable[r][c] = ((keyTable[r][c] * (keyTable[r][c+1] and 0b11)) )
              else:
                #keyTable[r][c] = keyTable[r][c] + keyTable[r][0]
                keyTable[r][c] = (keyTable[r][c] * (keyTable[r][0] and 0b11))



#_________________________________________________________





proc swapBitsA*(a:uint8):uint8= # SELF REVERSIBLE
  ## Shuff: 1-5,2-3,4-7
  result = 0
  if testBit(a,4): #7
    result += 1
  result = result shl 1
  if testBit(a,0): #6
    result += 1
  result = result shl 1
  if testBit(a,1): #5
    result += 1
  result = result shl 1
  if testBit(a,7): #4
    result += 1
  result = result shl 1
  if testBit(a,2): #3
    result += 1
  result = result shl 1
  if testBit(a,3): #2
    result += 1
  result = result shl 1
  if testBit(a,5): #1
    result += 1
  result = result shl 1
  if testBit(a,6): #0
    result += 1

proc swapBitsBx*(a:uint8):uint8= # SELF REVERSIBLE
  ## Shuff: 7-3,6-0,5-2,4-1
  result = 0
  if testBit(a,3): #7
    result += 1
  result = result shl 1
  if testBit(a,0): #6
    result += 1
  result = result shl 1
  if testBit(a,2): #5
    result += 1
  result = result shl 1
  if testBit(a,1): #4
    result += 1
  result = result shl 1
  if testBit(a,7): #3
    result += 1
  result = result shl 1
  if testBit(a,5): #2
    result += 1
  result = result shl 1
  if testBit(a,4): #1
    result += 1
  result = result shl 1
  if testBit(a,6): #0
    result += 1

proc swapBitsB*(a:uint8):uint8= # SELF REVERSIBLE
  ## Shuff: 7-3,6-0,5-2,4-1
  result = 0
  if testBit(a,0): #7
    result += 1
  result = result shl 1
  if testBit(a,2): #6
    result += 1
  result = result shl 1
  if testBit(a,5): #5
    result += 1
  result = result shl 1
  if testBit(a,1): #4
    result += 1
  result = result shl 1
  if testBit(a,3): #3
    result += 1
  result = result shl 1
  if testBit(a,6): #2
    result += 1
  result = result shl 1
  if testBit(a,4): #1
    result += 1
  result = result shl 1
  if testBit(a,7): #0
    result += 1

proc swapBitsC*(a:uint8):uint8= # SELF REVERSIBLE
  ## Shuff:
  result = 0
  if testBit(a,3): #7
    result += 1
  result = result shl 1
  if testBit(a,5): #6
    result += 1
  result = result shl 1
  if testBit(a,6): #5
    result += 1
  result = result shl 1
  if testBit(a,0): #4
    result += 1
  result = result shl 1
  if testBit(a,7): #3
    result += 1
  result = result shl 1
  if testBit(a,1): #2
    result += 1
  result = result shl 1
  if testBit(a,2): #1
    result += 1
  result = result shl 1
  if testBit(a,4): #0
    result += 1

proc swapBitsD*(a:uint8):uint8= #! not self reversible
  ## Shuff:
  result = 0
  if testBit(a,1): #7
    result += 1
  result = result shl 1
  if testBit(a,2): #6
    result += 1
  result = result shl 1
  if testBit(a,3): #5
    result += 1
  result = result shl 1
  if testBit(a,5): #4
    result += 1
  result = result shl 1
  if testBit(a,4): #3
    result += 1
  result = result shl 1
  if testBit(a,0): #2
    result += 1
  result = result shl 1
  if testBit(a,7): #1
    result += 1
  result = result shl 1
  if testBit(a,6): #0
    result += 1

proc swapBitsD2*(a:uint8):uint8= #! not self reversible
  ## Shuff:
  result = 0
  if testBit(a,1): #7
    result += 1
  result = result shl 1
  if testBit(a,0): #6
    result += 1
  result = result shl 1
  if testBit(a,4): #5
    result += 1
  result = result shl 1
  if testBit(a,3): #4
    result += 1
  result = result shl 1
  if testBit(a,5): #3
    result += 1
  result = result shl 1
  if testBit(a,6): #2
    result += 1
  result = result shl 1
  if testBit(a,7): #1
    result += 1
  result = result shl 1
  if testBit(a,2): #0
    result += 1


proc swapBitsE*(a:uint8):uint8= #! not self reversible
  ## Shuff
  result = 0
  if testBit(a,2): #7
    result += 1
  result = result shl 1
  if testBit(a,4): #6
    result += 1
  result = result shl 1
  if testBit(a,7): #5
    result += 1
  result = result shl 1
  if testBit(a,1): #4
    result += 1
  result = result shl 1
  if testBit(a,0): #3
    result += 1
  result = result shl 1
  if testBit(a,6): #2
    result += 1
  result = result shl 1
  if testBit(a,3): #1
    result += 1
  result = result shl 1
  if testBit(a,5): #0
    result += 1

proc swapBitsE2*(a:uint8):uint8= #! not self reversible
  ## Shuff
  result = 0
  if testBit(a,5): #7
    result += 1
  result = result shl 1
  if testBit(a,2): #6
    result += 1
  result = result shl 1
  if testBit(a,0): #5
    result += 1
  result = result shl 1
  if testBit(a,6): #4
    result += 1
  result = result shl 1
  if testBit(a,1): #3
    result += 1
  result = result shl 1
  if testBit(a,7): #2
    result += 1
  result = result shl 1
  if testBit(a,4): #1
    result += 1
  result = result shl 1
  if testBit(a,3): #0
    result += 1


proc swapBitsF*(a:uint8):uint8= #! not self reversible
  ## Shuff
  result = 0
  if testBit(a,3): #7
    result += 1
  result = result shl 1
  if testBit(a,7): #6
    result += 1
  result = result shl 1
  if testBit(a,6): #5
    result += 1
  result = result shl 1
  if testBit(a,2): #4
    result += 1
  result = result shl 1
  if testBit(a,1): #3
    result += 1
  result = result shl 1
  if testBit(a,5): #2
    result += 1
  result = result shl 1
  if testBit(a,0): #1
    result += 1
  result = result shl 1
  if testBit(a,4): #0
    result += 1

proc swapBitsF2*(a:uint8):uint8= #! not self reversible
  ## Shuff
  result = 0
  if testBit(a,6): #7
    result += 1
  result = result shl 1
  if testBit(a,5): #6
    result += 1
  result = result shl 1
  if testBit(a,2): #5
    result += 1
  result = result shl 1
  if testBit(a,0): #4
    result += 1
  result = result shl 1
  if testBit(a,7): #3
    result += 1
  result = result shl 1
  if testBit(a,4): #2
    result += 1
  result = result shl 1
  if testBit(a,3): #1
    result += 1
  result = result shl 1
  if testBit(a,1): #0
    result += 1


proc swapBitsG*(a:uint8):uint8= #! not self reversible
  ## Shuff
  result = 0
  if testBit(a,5): #7
    result += 1
  result = result shl 1
  if testBit(a,3): #6
    result += 1
  result = result shl 1
  if testBit(a,4): #5
    result += 1
  result = result shl 1
  if testBit(a,7): #4
    result += 1
  result = result shl 1
  if testBit(a,6): #3
    result += 1
  result = result shl 1
  if testBit(a,0): #2
    result += 1
  result = result shl 1
  if testBit(a,2): #1
    result += 1
  result = result shl 1
  if testBit(a,1): #0
    result += 1

proc swapBitsG2*(a:uint8):uint8= #! not self reversible
  ## Shuff
  result = 0
  if testBit(a,4): #7
    result += 1
  result = result shl 1
  if testBit(a,3): #6
    result += 1
  result = result shl 1
  if testBit(a,7): #5
    result += 1
  result = result shl 1
  if testBit(a,5): #4
    result += 1
  result = result shl 1
  if testBit(a,6): #3
    result += 1
  result = result shl 1
  if testBit(a,1): #2
    result += 1
  result = result shl 1
  if testBit(a,0): #1
    result += 1
  result = result shl 1
  if testBit(a,2): #0
    result += 1


#[
proc swapBit*(a:uint8,x,y:int):uint8= #unused
  var r = a
  let
    x1= testBit(a.int,x)
    y1= testBit(a.int,y)
  if x1:
    setBit(r,y)
  else:
    clearBit(r,y)
  if y1:
    setBit(r,x)
  else:
    clearBit(r,x)
  return r
 ]#


proc byBitEnc*(v:uint8,k:uint8):uint8=
  result = v
  if testBit(k,7):
    result = bitnot(result).uint8
  else:
    #[ flipBit(result,0)
    flipBit(result,2) ]#
    result = result xor 0b01000101

  if testBit(k,6):
    result = reverseBits(result).uint8
  else:
      #[ flipBit(result,1)
      flipBit(result,7) ]#
      result = result xor 0b10010010

  if testBit(k,5):
    result = rotateLeftBits(result,3).uint8
  else:
      #[ flipBit(result,3)
      flipBit(result,4) ]#
      result = result xor 0b00111000

  if testBit(k,4):
    #[ flipBit(result,0)
    flipBit(result,3)
    flipBit(result,6) ]#
    result = result xor 0b01001001
  else:
      #[ flipBit(result,5)
      flipBit(result,6) ]#
      result = result xor 0b01101000

  if testBit(k,3):
    #[ flipBit(result,1)
    flipBit(result,4)
    flipBit(result,5) ]#
    result = result xor 0b00110010
  else:
      #result = swapBitsB(result)
      result = result xor 0b01010100

  if testBit(k,2):
    #[ flipBit(result,2)
    flipBit(result,7) ]#
    result = result xor 0b10000100
  else:
      result = swapBitsE(result)

  if testBit(k,1):
    #result = swapBitsA(result)
    result = result xor 0b00010110
  else:
      #[ flipBit(result,0)
      flipBit(result,4)
      flipBit(result,2) ]#
      result = result xor 0b00010101

  if testBit(k,0):
    result = result xor 0b00111000
  else:
      result = rotateLeftBits(result,5).uint8


proc byBitDec*(v:uint8,k:uint8):uint8=
  result = v
  if testBit(k,0):
    result = result xor 0b00111000
  else:
      result = rotateRightBits(result,5).uint8

  if testBit(k,1):
    #result = swapBitsA(result)
    result = result xor 0b00010110
  else:
      #[ flipBit(result,0)
      flipBit(result,4)
      flipBit(result,2) ]#
      result = result xor 0b00010101

  if testBit(k,2):
    #[ flipBit(result,2)
    flipBit(result,7) ]#
    result = result xor 0b10000100
  else:
      result = swapBitsE2(result)

  if testBit(k,3):
    #[ flipBit(result,1)
    flipBit(result,4)
    flipBit(result,5) ]#
    result = result xor 0b00110010
  else:
      #result = swapBitsB(result)
      result = result xor 0b01010100

  if testBit(k,4):
    #[ flipBit(result,0)
    flipBit(result,3)
    flipBit(result,6) ]#
    result = result xor 0b01001001
  else:
      #[ flipBit(result,5)
      flipBit(result,6) ]#
      result = result xor 0b01101000

  if testBit(k,5):
    result = rotateRightBits(result,3).uint8
  else:
      #[ flipBit(result,3)
      flipBit(result,4) ]#
      result = result xor 0b00111000

  if testBit(k,6):
    result = reverseBits(result).uint8
  else:
      #[ flipBit(result,1)
      flipBit(result,7) ]#
      result = result xor 0b10010010

  if testBit(k,7):
    result = bitnot(result).uint8
  else:
      #[ flipBit(result,0)
      flipBit(result,2) ]#
      result = result xor 0b01000101


#-----------------------------------------



#[ proc mxKeyRot5*(a:ByteSeq):ByteSeq= #unused
  result = a
  var b: uint8
  for i in 1..5:
    b = result.pop()
    result.insert(b,0) ]#

#[ proc mxKeyRotEnc12*(a:ByteSeq):ByteSeq= #unused
  for i in 0..a.high-1:
    if a[i] < a[i+1]:
      result.add(a[i] - 12)
    else:
      result.add(a[i] + 12)
  result.add (a[a.high] + a[0] - 12) ]#


proc mxKeyRotEnc*(a:ByteSeq):ByteSeq=
  for i in 0..a.high-1:
    if a[i] < a[i+1]:
      result.add(a[i] + a[i+1] + 65)
    else:
      result.add(a[i] - a[i+1] - 65)
  result.add (a[a.high] + a[0] + 65)



#-----------------------------------------


#[ proc mxKeyShuffle*(a:ByteSeq):ByteSeq= # Ahhh...
  result = a
  let half:int = a.len div 2
  var
    buf:uint8
    b:int
  randomize(65535)
  for i in 0..a.high:
    if i < half: # if first half
      b = a.high - i
      b = rand(b)
      buf = result[i+b]
      result[i+b] = result[i]
      result[i] = buf
    else:
      b = rand(i)
      buf = result[i-b]
      result[i-b] = result[i]
      result[i] = buf ]#


#-----------------------------------------
proc mxZipKeys*(a,b:ByteSeq):ByteSeq=
  for i in 0..a.high:
    if testBit(i,0):
      result.add(a[i])
    else:
      result.add(b[i])


proc mxKeyReverse*(a:ByteSeq):ByteSeq=
  result = a
  for i in 0..result.high:
    var x = result[i]
    result[i] = result[result.high - i]
    result[result.high - i] = x

#-----------------------------------------


proc swapMinors*(a:uint8):uint8=
  result = a shl 4 + a shr 4


proc mxKeySwapMinors*(a:ByteSeq):ByteSeq= #unused
  result = a
  for i in 0..a.high:
    result[i] = swapMinors(a[i])

proc mxKeySwapMinors2*(a:ByteSeq):ByteSeq= #unused
  result = a
  for i in 0..a.high-1:
    result[i] =  a[i] shl 4 or a[i+1] shr 4
  result[a.high] =  a[a.high] shl 4 or a[0] shr 4


proc mxKeySwapMinors3*(a:ByteSeq):ByteSeq=
  result = a
  var x,y:uint8

  for i in countup(0,a.high-2, 2):
    #echo (x and 0b00111100), " + ", (y and 0b11000011)
    x = result[i].rotateLeftBits(2)
    y = result[i+1].rotateRightBits(2)
    result[i] = ((x and 0b11111000) + (y and 0b00000111)).bitnot
    result[i+1] = ((y and 0b11111000) + (x and 0b00000111)).bitnot
    x = result[i+1]
    y = result[i+2]
    result[i+2] = (y and 0b11111000) + (x and 0b00000111)
    result[i+1] = (x and 0b11111000) + (y and 0b00000111)

  y = result[a.high]
  x = result[0]
  result[a.high] = ((x and 0b11111000) + (y and 0b00000111)).bitnot
  result[0] = ((y and 0b11111000) + (x and 0b00000111)).bitnot


proc mxKeysSwapMinors*(a,b:ByteSeq):ByteSeq= #unused
  for i in 0..a.high:
    result.add(a[i] shl 4 + b[i] shr 4)

#-----------------------------------------


proc mxKeySwapBitsA*(a:ByteSeq):ByteSeq=
  result = a
  for i in 0..a.high:
    result[i] = swapBitsA(a[i])

proc mxKeySwapBitsE*(a:ByteSeq):ByteSeq=
  result = a
  for i in 0..a.high:
    result[i] = swapBitsE(a[i])

proc mxKeySwapBitsC*(a:ByteSeq):ByteSeq=
  result = a
  for i in 0..a.high:
    result[i] = swapBitsC(a[i])

proc mxKeySwapBitsF*(a:ByteSeq):ByteSeq=
  result = a
  for i in 0..a.high:
    result[i] = swapBitsF(a[i])

proc mxKeySwapBitsRound*(a:ByteSeq):ByteSeq=
  result = a
  var
    c = 0
  for i in 0..a.high:
    #if testBit(a[(KeyLen - 1) - i].int, 0):
    if testBit(a[i].int, 0):
      case c:
      of 0: result[i] = swapBitsF(a[i])
      of 1: result[i] = rotateRightBits(a[i],3)#swapBitsG(a[i])
      of 2: result[i] = swapBitsE(a[i])
      of 3: result[i] = swapBitsG2(a[i]) #
      of 4: result[i] = swapBitsG(a[i])#bitnot(a[i]) - a[i]
      #of 5: result[i] = swapBitsC(a[i])
      of 6: result[i] = swapBitsF(a[i])
      else: result[i] = swapBitsD(a[i])
    else:
      case c:
      of 0: result[i] = swapBitsE(a[i])
      of 1: result[i] = rotateLeftBits(a[i],3) # swapBitsG(a[i])
      of 2: result[i] = swapBitsF(a[i])
      #of 3: result[i] = swapBitsD(a[i]) #
      of 4: result[i] = swapBitsG2(a[i]) #*
      #of 5: result[i] = reverseBits(a[i])
      of 6: result[i] = swapBitsD2(a[i])#a[i] + (26.uint8 * (a[i] and 0b11.uint8))#a[i]
      else: result[i] = swapBitsE(a[i])
    c += 1
    if c == 8:
      c = 0
  #echo "S ", result




proc mxKeySwapBitsEE2*(a:ByteSeq):ByteSeq= #TODO ?
  result = a
  for i in 0..a.high:
    if testBit(a[i].int, 0):
      result[i] = swapBitsE(a[i])
    else:
      result[i] = bitnot swapBitsE(a[i])


proc mxKeyReverseBits*(a:ByteSeq):ByteSeq= #unused
  result = a
  for i in 0..a.high:
    result[i] = reverseBits(a[i])


proc mxKeyRotateLeftBits*(a:ByteSeq):ByteSeq=
  result = a
  for i in 0..a.high:
    result[i] = rotateLeftBits(a[i],3)

#-----------------------------------------



#*****************************************

proc mxKeyXor*(a:ByteSeq):ByteSeq=
  result = a
  for i in 0..a.high-1:
    if result[i] != result[i+1]:
      result[i] = result[i] xor result[i+1]
    else:
      result[i] = result[i] + result[i+1]
  result[a.high] = result[a.high] xor a[0]

proc mxKeyXorB*(a:ByteSeq):ByteSeq=
  result = a
  for i in countup(0,a.high-1,2):
    if result[i] != result[i+1]:
      result[i] = result[i] xor result[i+1]
    else:
      result[i] = result[i] + result[i+1]
  result[a.high] = result[a.high] xor result[0]

proc mxKeysXor*(a,b:ByteSeq):ByteSeq=
  result = a
  for i in 0..a.high:
    if a[i] != b[i]:
      result[i] = a[i] xor b[i]
    else:
      result[i] = a[i] + b[i]

proc mxKeyNot*(a:ByteSeq):ByteSeq=
  result = a
  for i in 0..a.high:
    result[i] = result[i].bitnot

#*-----------------------------------------------



proc mxKeyAlg1Fun*(a:ByteSeq):ByteSeq=
  result = a
  var passsalt2: uint8

  for c in 0..result.high:
    var p2x = result
    p2x.delete(c)
    for cc in 0..p2x.high:
      passsalt2 = ((passsalt2 + cc.uint8) xor p2x[cc])
    #echo "\n>>> ", passsalt2
    result[c] = passsalt2
    #p3ct.add(passsalt2)

proc mxKeyAlg2Fun*(a:ByteSeq):ByteSeq=
  result = a
  var passsalt2: uint8

  for c in 0..result.high:
    #!EXPALG1
    var p2x = a # hmmm....
    p2x.delete(c)
    for cc in 0..p2x.high:
      passsalt2 = ((passsalt2 + cc.uint8) + p2x[cc].uint8)
    #echo "\n>>> ", passsalt2
    result[c] = passsalt2

proc mxKeyAlg1*(a:ByteSeq):ByteSeq=
  result = a
  var cI,cII,cS:int
  cI = 0
  cS = 16 #16
  cII = cS - 1
  while true:
    if cII > result.high: cII = result.high
    var pchunk = result[cI..cII]
    pchunk = pchunk.mxKeyAlg1Fun()
    result[cI..cII] = pchunk
    cI = cII + 1
    cII += cS
    if cI > result.high: break

proc mxKeyAlg2*(a:ByteSeq):ByteSeq=
  result = a
  var cI,cII,cS:int
  cI = 0
  cS = 16 #16
  cII = cS - 1
  while true:
    if cII > result.high: cII = result.high
    var pchunk = result[cI..cII]
    pchunk = pchunk.mxKeyAlg2Fun()
    result[cI..cII] = pchunk
    cI = cII + 1
    cII += cS
    if cI > result.high: break
#***************************************************

proc mxKeyXorR*(a:ByteSeq):ByteSeq=
  result = a
  for i in countdown(a.high,1):
    if result[i] != result[i-1]:
      result[i] = result[i] xor result[i-1]
    else:
      result[i] = result[i] + result[i-1]
  result[0] = result[a.high] xor a[0]

proc mxKeyXorRR*(a:ByteSeq):ByteSeq=
  result = a
  for i in countdown(a.high,1):
    if result[i] != result[i-1]:
      result[i] = result[i] xor result[i-1]
    else:
      result[i] = result[i] + result[i-1]
  result[0] = result[a.high] xor a[0]
  for i in 0..a.high-1:
    if result[i] != result[i+1]:
      result[i] = result[i] xor result[i+1]
    else:
      result[i] = result[i] + result[i+1]
  result[a.high] = result[a.high] xor a[0]


proc mxKeyAddRR*(a:ByteSeq):ByteSeq=
  result = a
  for i in countdown(a.high,1):
    result[i] = result[i] + result[i-1]
  result[0] = result[a.high] + a[0]

  for i in 0..a.high-1:
    result[i] = result[i] + result[i+1]
  result[a.high] = result[a.high] + a[0]


proc mxKeySwapBitsB*(a:ByteSeq):ByteSeq=
  result = a
  for i in 0..a.high:
    result[i] = swapBitsB(a[i])

proc mxKeySwapBitsD*(a:ByteSeq):ByteSeq=
  result = a
  for i in 0..a.high:
    result[i] = swapBitsD(a[i])


proc mxKeySwapBitsG*(a:ByteSeq):ByteSeq=
  result = a
  for i in 0..a.high:
    result[i] = swapBitsG(a[i])

proc mxKeyByBitEnc*(a:ByteSeq):ByteSeq=
  result = a
  for i in 0..a.high:
    result[i] = byBitEnc(a[i],a[i])

proc mxKeyRotEnc2*(a:ByteSeq):ByteSeq=
  for i in 0..a.high-1:
    if a[i] > a[i+1]:
      result.add((a[i] + a[i+1]) xor a[i+1])
    else:
      result.add((a[i] - a[i+1]) xor a[i+1])
  result.add ((a[a.high] + a[0]) xor a[0])

#_____________________________________________________







#[

########  #######  ##    ## ######## ##    ##
   ##    ##     ## ##   ##  ##        ##  ##
   ##    ##     ## ##  ##   ##         ####
   ##    ##     ## #####    ######      ##
   ##    ##     ## ##  ##   ##          ##
   ##    ##     ## ##   ##  ##          ##
   ##     #######  ##    ## ########    ##

 ]#


proc p2kproc3(a:ByteSeq):ByteSeq=
  var tres = mxKeySwapMinors3(a)
  result = mxZipKeys(tres,a)

proc p2kproc2(a:ByteSeq):ByteSeq=
  result = a
  var passsalt2: uint8
  for c in 0..result.high:
    var p2x = result
    p2x.delete(c)
    for cc in 0..p2x.high:
      passsalt2 = ((passsalt2 + cc.uint8) xor p2x[cc])
    result[c] = passsalt2

proc p2kproc1(a:ByteSeq):ByteSeq=
  result = a
  var rI:int
  for i in 0..result.high:
    result[i] = rotateRightBits(result[i], rI)
    rI += 1
    if rI >= 8:
        rI = 0



proc passToKey*(pass:string): ByteSeq = #!PASSTOKEY NEW

  result = pass.toByteSeq()

  #[ let procSelector = (pass[0].uint8 +
                      pass[1].uint8 +
                      pass[2].uint8 +
                      pass[3].uint8 ) mod 7 ]#
  var procSelector : uint8
  for c in 0..result.high:
    procSelector += result[c].uint8
  procSelector = procSelector mod 10 #7


  block:
    var
      b1:uint8
      was:ByteSeq
    for i in 0..result.high:
      b1 += 1
      if b1 == 0: b1 = 1
      if result[i] in was:
        result[i] += b1

      result[i] += b1
      result[i] = result[i] + (result.len mod 255).uint8


  if result.len < KeyLen:
    var c = 0
    var d:uint8 = 0
    for i in result.high .. (KeyLen - 2):
      result.add(bitnot(result[c]) + d)
      c += 1
      if c > result.high:
        c = 0
        d += 33
  else:
    KeyLen = result.len

  result = mxKeyXorRR(result) #???

  #............ TODO
  #[ result = p2kproc1(result)
  result = p2kproc2(result)
  result = p2kproc3(result) ]#




  case procSelector:
  of 8: result = changeDuplicatesB(mxKeySwapBitsC(mxKeySwapBitsB(mxKeySwapBitsG(mxKeyXorRR(mxKeySwapBitsC(mxKeySwapBitsRound(mxKeyAlg1(mxKeyReverseBits(mxKeySwapBitsG(mxKeySwapBitsF(mxKeyRotEnc(mxKeySwapBitsRound(p2kproc3(mxKeyRotEnc2(mxKeyAlg1(result))))))))))))))))

  of 3: result = mxKeySwapBitsD(mxKeySwapBitsG(changeDuplicatesB(mxKeySwapBitsE(changeDuplicates(mxKeySwapBitsA(mxKeyRotEnc(mxKeyReverseBits(mxKeySwapBitsF(mxKeySwapBitsE(mxKeyReverse(mxKeySwapBitsD(mxKeyXor(mxKeyReverseBits(changeDuplicatesC2(mxKeySwapMinors3(result))))))))))))))))

  of 7: result = changeDuplicatesC(changeDuplicates(changeDuplicatesC2(mxKeyReverse(mxKeySwapBitsRound(mxKeySwapBitsG(changeDuplicatesC2(mxKeyAlg1(mxKeySwapMinors3(mxKeyAlg2(changeDuplicatesB(changeDuplicates(mxKeySwapMinors3(mxKeyByBitEnc(mxKeySwapBitsEE2(changeDuplicatesC(result))))))))))))))))

  of 5: result = changeDuplicatesB(changeDuplicates(mxKeyReverse(mxKeySwapBitsE(mxKeySwapBitsEE2(mxKeySwapBitsD(mxKeyAlg1(mxKeySwapBitsF(mxKeySwapBitsEE2(changeDuplicates(mxKeySwapBitsRound(mxKeySwapBitsB(mxKeyAlg1(mxKeySwapBitsG(p2kproc3(p2kproc3(result))))))))))))))))

  of 4: result = changeDuplicatesC(mxKeySwapBitsG(changeDuplicatesC(mxKeySwapBitsE(mxKeyReverseBits(mxKeyAddRR(mxKeyByBitEnc(p2kproc3(changeDuplicates(mxKeyReverseBits(mxKeyRotateLeftBits(mxKeySwapBitsA(changeDuplicatesC2(mxKeyXorRR(changeDuplicatesB(mxKeySwapBitsB(result))))))))))))))))

  of 9: result = mxKeyReverse(mxKeySwapBitsF(mxKeyRotateLeftBits(changeDuplicatesC(p2kproc3(mxKeyAlg1(mxKeyRotEnc2(changeDuplicates(mxKeySwapBitsRound(mxKeyXorRR(mxKeySwapBitsRound(mxKeyXorRR(mxKeySwapBitsA(mxKeySwapBitsE(mxKeyNot(mxKeyNot(result))))))))))))))))

  of 6: result = changeDuplicatesC(mxKeyNot(p2kproc3(mxKeyAlg2(mxKeySwapBitsB(mxKeyXorRR(mxKeySwapBitsRound(mxKeyByBitEnc(mxKeyRotEnc(mxKeySwapBitsE(p2kproc3(mxKeyRotEnc(mxKeySwapBitsE(mxKeyAlg1(mxKeyAlg1(mxKeyByBitEnc(result))))))))))))))))

  of 1: result = changeDuplicatesB(changeDuplicatesC2(changeDuplicatesC2(mxKeySwapMinors3(mxKeySwapBitsG(mxKeySwapBitsRound(mxKeyReverseBits(mxKeyAddRR(mxKeyRotEnc2(changeDuplicatesC(mxKeySwapMinors3(changeDuplicates(mxKeySwapBitsB(mxKeySwapBitsF(mxKeyRotEnc2(mxKeySwapBitsF(result))))))))))))))))

  of 0: result = mxKeySwapBitsE(mxKeySwapBitsG(changeDuplicatesC(mxKeyReverseBits(mxKeyXor(changeDuplicatesC(mxKeyRotEnc(changeDuplicatesB(mxKeyXor(mxKeySwapBitsEE2(mxKeySwapBitsE(changeDuplicatesC(mxKeySwapBitsE(mxKeyReverseBits(mxKeyXorRR(changeDuplicates(result))))))))))))))))

  else: result = mxKeyNot(mxKeySwapBitsE(changeDuplicatesC(mxKeyAlg2(changeDuplicatesC(mxKeySwapBitsRound(mxKeyXorB(mxKeyNot(changeDuplicatesC(mxKeyAlg2(mxKeyAlg2(p2kproc3(changeDuplicates(changeDuplicatesC2(mxKeySwapBitsF(mxKeySwapBitsEE2(result))))))))))))))))









#[ 
  case procSelector:
  of 0: result = changeDuplicatesB(mxKeyReverse(mxKeyAddRR(mxKeySwapBitsF(mxKeySwapBitsB(mxKeyXorRR(p2kproc3(mxKeyXorRR(changeDuplicatesC(mxKeyXorB(mxKeyAddRR(mxKeyByBitEnc(mxKeyXor(mxKeySwapBitsG(mxKeyRotateLeftBits(mxKeyRotEnc2(result))))))))))))))))

  of 1: result = mxKeySwapBitsA(changeDuplicatesB(mxKeyAlg2(mxKeyReverseBits(mxKeyRotateLeftBits(mxKeyReverse(p2kproc3(mxKeyAlg1(mxKeySwapBitsB(mxKeySwapBitsF(mxKeySwapBitsRound(mxKeyReverseBits(mxKeyNot(mxKeyXorB(p2kproc3(mxKeyReverseBits(result))))))))))))))))

  of 2: result = changeDuplicatesC(mxKeyXor(mxKeyReverseBits(mxKeyReverseBits(mxKeySwapBitsE(mxKeyRotEnc(mxKeySwapBitsF(mxKeySwapBitsRound(mxKeyAddRR(mxKeySwapBitsE(changeDuplicatesC2(mxKeySwapBitsF(mxKeySwapBitsG(mxKeyXorRR(changeDuplicates(changeDuplicatesC(result))))))))))))))))

  of 3: result = mxKeySwapBitsB(changeDuplicatesC(mxKeySwapBitsA(mxKeySwapBitsD(mxKeyNot(mxKeyXor(mxKeyAlg2(p2kproc3(mxKeyByBitEnc(mxKeySwapBitsRound(mxKeySwapBitsF(mxKeyXor(mxKeyAlg1(mxKeyAlg1(mxKeyRotEnc2(changeDuplicatesB(result))))))))))))))))

  of 4: result = mxKeySwapBitsB(changeDuplicatesB(changeDuplicates(mxKeyRotEnc2(mxKeyXorB(mxKeyNot(mxKeyReverse(mxKeyRotateLeftBits(mxKeyXorB(mxKeySwapBitsE(mxKeySwapBitsRound(p2kproc3(changeDuplicatesC2(mxKeyRotateLeftBits(changeDuplicates(mxKeyAddRR(result))))))))))))))))

  of 5: result = changeDuplicatesC(mxKeySwapMinors3(mxKeySwapBitsB(changeDuplicatesB(mxKeySwapBitsD(mxKeyAlg1(mxKeySwapBitsG(mxKeyXor(mxKeySwapBitsD(mxKeySwapBitsC(mxKeySwapBitsRound(mxKeySwapMinors3(mxKeyByBitEnc(mxKeySwapBitsE(mxKeyReverse(mxKeySwapBitsA(result))))))))))))))))

  else: result = changeDuplicatesC(mxKeySwapBitsA(mxKeySwapBitsE(changeDuplicates(changeDuplicates(mxKeySwapMinors3(mxKeySwapBitsEE2(mxKeySwapBitsA(changeDuplicatesC2(mxKeySwapMinors3(mxKeySwapBitsB(mxKeyNot(mxKeyAlg2(mxKeyByBitEnc(mxKeySwapBitsRound(changeDuplicatesC(result))))))))))))))))
 ]#

  #[result = changeDuplicatesB(
    changeDuplicatesC(mxKeyRotateLeftBits(
    mxKeyNot(mxKeyAddRR(mxKeyAddRR(mxKeySwapBitsF(
    p2kproc3(mxKeyRotEnc(changeDuplicates(
    changeDuplicatesB(mxKeyReverse(mxKeyAlg2(
    mxKeySwapBitsRound(mxKeySwapMinors3(
    mxKeyAddRR(p2kproc3(p2kproc2(p2kproc1(result)))))))))))))))))))
]#

  #result = p2kproc1(p2kproc2(p2kproc3(mxKeyReverse(mxKeyAddRR(mxKeyReverseBits(changeDuplicatesC2(changeDuplicatesC2(mxKeySwapBitsE(mxKeyXorRR(mxKeyRotEnc(mxKeyReverseBits(mxKeyAddRR(mxKeyRotEnc(mxKeyAddRR(mxKeyRotateLeftBits(mxKeyAddRR(changeDuplicatesB(mxKeyReverseBits(result)))))))))))))))))))


  #result = p2kproc1(p2kproc2(p2kproc3(mxKeySwapBitsE(mxKeyXorRR(changeDuplicatesC2(mxKeyAlg2(mxKeyAddRR(mxKeyAddRR(mxKeySwapBitsG(mxKeySwapBitsF(mxKeyXorRR(mxKeySwapBitsF(mxKeyRotEnc(mxKeyByBitEnc(mxKeyXorRR(changeDuplicatesC2(mxKeyAddRR(changeDuplicatesB(result)))))))))))))))))))


  #result = p2kproc1(p2kproc2(p2kproc3(changeDuplicatesC2(mxKeySwapBitsEE2(mxKeyAddRR(mxKeySwapBitsE(mxKeyReverseBits(mxKeyAlg2(mxKeyRotEnc(mxKeyAlg2(mxKeySwapMinors3(mxKeyNot(mxKeyReverseBits(mxKeyReverse(mxKeyRotEnc2(mxKeyAlg2(mxKeySwapBitsG(changeDuplicatesB(result)))))))))))))))))))

#[
proc passToKey*(pass:string): ByteSeq = #!PASSTOKEY
  const debug = 0b0
  #expandkeyHelper = 0 #!!!!
  #result = newSeq[uint8](KeyLen)
  var tres = result

  result = pass.toByteSeq()
  #result = result.mxKeyReverse()
  #result = result.changeDuplicatesB()
  var avgDiff:int
  for i in 0..result.high-1:
    if result[i] > result[i+1]:
      avgDiff += (result[i] - result[i+1]).int
    else:
      avgDiff += (result[i+1] - result[i]).int
  avgDiff = avgDiff div result.len
  when debug >= 0b11: echo pass, " ",avgDiff
  let avgDiffLevel = 100


  if pass.len > KeyLen: #*=-~~~~~~~~~~~~~~~~~~~~~~~~~
    #result = pass.toByteSeq()
    KeyLen = result.len

    var rI:int=2
    for i in 0..result.high:

      if testBit(result[i],7):
        result[i] = rotateRightBits(result[i], rI)
        result[i] += i.uint8
      else:
        result[i] = rotateLeftBits(result[i], rI)
      rI += 1
      if testBit(result[i],7): rI -= 1
      if rI >= 8: #5 #7
        if testBit(result[i],0):
          rI = 2 #1 #5
        else:
          rI = 1


    #result = result.changeDuplicatesC2()
    #result = result.mxKeyXorB()
    #result = mxKeyShuffle(result)
    var cI,cII,cS:int
    cI = 0
    cS = 16 #16
    cII = cS - 1
    while true:
      var pchunk = result[cI..cII]
      pchunk = pchunk.changeDuplicatesC2()
      result[cI..cII] = pchunk
      cI = cII + 1
      cII += cS
      if cII > result.high: cII = result.high
      if cI > result.high: break

    #result = result.changeDuplicatesC2()

    cI = 0
    cS = 11
    cII = cS - 1
    while true:
      var pchunk = result[cI..cII]
      pchunk = pchunk.mxKeyXor()
      result[cI..cII] = pchunk
      cI = cII + 1
      cII += cS
      if cII > result.high: cII = result.high
      if cI > result.high: break



    cI = 0
    cS = 16
    cII = cS - 1
    while true:
      var pchunk = result[cI..cII]
      pchunk = pchunk.mxKeyAlg1Fun()
      pchunk = pchunk.mxKeyAlg2Fun()
      result[cI..cII] = pchunk
      cI = cII + 1
      cII += cS
      if cII > result.high: cII = result.high
      if cI > result.high: break




    result = result.mxKeyReverseBits() #*

    #result = mxZipKeys(tres,result)


    #echo result
    #result = result.changeDuplicates()
    #when debug >= 0b1: echo "K ",result
    tres = result[0..(result.high div 2)]
    tres = tres.changeDuplicates()
    result[0..(result.high div 2)] = tres


    result = mxKeySwapBitsRound(result)
    when debug >= 0b1: echo "K ",result

    #result = mxKeySwapMinors3(result)
    #when debug >= 0b1: echo "K ",result

    result = result.mxKeyNot() #?New


    cI = 0
    cS = 16
    cII = cS - 1
    while true:
      var pchunk = result[cI..cII]
      pchunk = pchunk.mxKeyRotEnc()
      result[cI..cII] = pchunk
      cI = cII + 1
      cII += cS
      if cII > result.high: cII = result.high
      if cI > result.high: break
    #result = mxKeyRotEnc(result)
    #when debug >= 0b1: echo "K ",result

    #tres = mxKeySwapMinors3(result) #*
    #result = mxZipKeys(tres,result) #*

    #result = mxKeyReverse(result) # no effect

    #result = mxKeySwapMinors3(result)
    #when debug >= 0b1: echo "K ",result
    #[ cI = 0
    cS = 16
    cII = cS - 1
    while true:
      var pchunk = result[cI..cII]
      pchunk = pchunk.mxKeySwapMinors3()
      #pchunk = pchunk.mxKeyAlg2()
      result[cI..cII] = pchunk
      cI = cII + 1
      cII += cS
      if cII > result.high: cII = result.high
      if cI > result.high: break ]#


    result = mxKeySwapBitsEE2(result)
    when debug >= 0b1: echo "K ",result


    tres = mxKeySwapMinors3(result) #*
    result = mxZipKeys(tres,result) #*


    result = mxKeyReverse(result) # no effect

    result = result.mxKeyNot() #?New


    result = mxKeySwapBitsRound(result)
    when debug >= 0b1: echo "K ",result

    cI = 0
    cS = 16
    cII = cS - 1
    while true:
      var pchunk = result[cI..cII]
      pchunk = pchunk.mxKeySwapMinors3()
      #pchunk = pchunk.mxKeyAlg2()
      result[cI..cII] = pchunk
      cI = cII + 1
      cII += cS
      if cII > result.high: cII = result.high
      if cI > result.high: break


    result = result.changeDuplicatesB() #*

    #[ for cR in 0..result.high:
      for cP in 0..pass.high:
        byBitEnc(result[cR], pass[cP].uint8)
        result[cR] = result[cR] xor pass[cP].uint8 ]#

    #[ var d:uint8 = 0
    for i in 0..5:
      result.add(bitnot(result[i]) + d)
      d += 3
    KeyLen += 6 ]#



  #*-------------------------------------------------

  else: #*=-~~~~~~~~~~~~~~~~~~~~~~~~~

    if pass.len == KeyLen:
      discard
      #result = pass.toByteSeq()
      #result = result.changeDuplicates()
      #[ var d:uint8 = 0
      for i in 0..5:
        result.add(bitnot(result[i]) + d)
        d += 3
      KeyLen += 6  ]#

    elif pass.len < KeyLen:

      #result = pass.toByteSeq()

      #result = result.changeDuplicates()
      var rI:int

      var c = 0
      var d:uint8 = 0
      for i in result.high .. (KeyLen - 2):

        result.add(bitnot(result[c]) + d)

        c += 1
        if c > pass.high:
          c = 0
          d += 33

        #[ result.add((pass[c].uint8 + i.uint8) xor pass[c].uint8)

        for b in 0 .. result.high:
          d += result[b]
        result[result.high] += d ]#


        #[ result.add(
          ((result[result.high] shl 4) +
          (result[result.high - 1] shr 4 )) * c +
          (result[result.high - 2]) ) ]#

        #[ result.add(
          swapBitsE(result[result.high]) +
          swapBitsD(result[result.high - 1]) -
          swapBitsF(result[result.high - 2])
        ) ]#

        #[ result.add(bitnot result[c])
        byBitEnc(
          result[result.high],
          result[result.high div 2] + c.uint8
          ) ]#

        #result.add(((pass[c].uint8 + i.uint8) xor pass[c].uint8).reverseBits)
        #[ result.add(
          (pass[c].uint8.rotateRightBits( i.uint8 div 3)) xor
          pass[c].uint8.rotateLeftBits( i.uint8 div 3)
          ) ]#

        #[ for b in 0 .. result.high:
          d += result[b]
        result.add(d) ]#

        #if i mod 2 == 0: result[result.high] = reverseBits(result[result.high])


        #[ result[result.high] = rotateRightBits(result[result.high], rI)
        rI += 1
        if rI == 8: rI = 0 ]#

    var rI:int
    for i in 0..result.high:
      result[i] = rotateRightBits(result[i], rI)
      rI += 1
      if rI >= 8:
          rI = 0

    #[ var rI:int
    for i in 0..result.high:
      if i mod 2 == 0:
        result[i] = rotateRightBits(result[i], rI)
      else:
        result[i] = rotateLeftBits(result[i], rI)
      rI += 1
      if rI >= 8:
          rI = 0  ]#

    #result = result.changeDuplicatesC2()
    #result = result.changeDuplicatesC()

    #result = mxKeyShuffle(result)
    #when debug >= 0b1: echo "K ",result

    var passsalt2: uint8
    for c in 0..result.high:
      var p2x = result
      p2x.delete(c)
      for cc in 0..p2x.high:
        passsalt2 = ((passsalt2 + cc.uint8) xor p2x[cc])
      result[c] = passsalt2

    result = result.mxKeyNot() #?New

    result = mxKeyAlg1(result)
    result = result.mxKeyNot() #?New

    result = mxKeyAlg2(result)


    #tres = result
    result = result.mxKeyReverseBits()
    #result = mxZipKeys(tres,result)


    #echo result
    #result = result.changeDuplicates()
    #when debug >= 0b1: echo "K ",result

    result = mxKeySwapBitsRound(result)
    when debug >= 0b1: echo "K ",result

    #result = mxKeySwapMinors3(result)
    #when debug >= 0b1: echo "K ",result

    result = mxKeyRotEnc(result)
    when debug >= 0b1: echo "K ",result

    tres = mxKeySwapMinors3(result)
    result = mxZipKeys(tres,result)

    #result = mxKeyReverse(result) # no effect

    result = mxKeySwapMinors3(result)
    when debug >= 0b1: echo "K ",result

    result = mxKeySwapBitsEE2(result)
    when debug >= 0b1: echo "K ",result

    tres = mxKeySwapMinors3(result)
    result = mxZipKeys(tres,result)

    result = mxKeySwapBitsRound(result)
    when debug >= 0b1: echo "K ",result

    result = result.changeDuplicates()
    when debug >= 0b1: echo "K ",result

    #result = result.changeDuplicates()
    #result = mxKeyAlg1(result)
    result = result.changeDuplicatesB() #! NEW

    #[ for cR in 0..result.high:
      for cP in 0..pass.high:
        byBitEnc(result[cR], pass[cP].uint8)
        result[cR] = result[cR] xor pass[cP].uint8 ]#
 ]#
  #-------------------------------------------------
  #-------------------------------------------------
  #-------------------------------------------------
  #-------------------------------------------------
  #-------------------------------------------------










#*       ######## ##     ## ########
#*       ##        ##   ##  ##     ##
#*       ##         ## ##   ##     ##
#*       ######      ###    ########
#*       ##         ## ##   ##
#*       ##        ##   ##  ##
#*       ######## ##     ## ##

#*########################################################
#*########################################################
#*########################################################
#*########################################################
#[ proc expandKeyTEST(oldKey:ByteSeq):ByteSeq= #test only
  result = oldKey ]#

#!!!! var expandkeyHelper = 0
proc expandKey*(oldKey:var ByteSeq, expandkeyHelper: var int):ByteSeq= #!EXPAND
  #result = mxKeySwapBitsE(mxKeyXor(mxKeyRotEnc(mxKeySwapMinors3(oldKey))))
  #result = mxKeySwapBitsEE2(mxKeyXor(mxKeyRotEnc(mxKeySwapMinors3(oldKey))))

  #[ case expandkeyHelper:
  of 0: result = (mxKeySwapBitsEE2(mxKeySwapBitsRound(mxKeyRotEnc(mxKeySwapMinors3(oldKey)))))
  of 1: result = mxKeySwapBitsC(mxKeyAlg1(mxKeyRotEnc(mxKeyAlg1(oldKey))))
  of 2: result = (mxKeySwapBitsEE2(mxKeyAlg1(oldKey)))
  of 3: result = mxKeySwapBitsE(mxKeyAlg1(mxKeyRotateLeftBits(mxKeyNot(oldKey))))
  of 4: result = (mxKeyAlg1(mxKeySwapBitsRound(oldKey)))
  else: result = mxKeySwapBitsRound(mxKeyAlg1(mxKeyRotEnc(oldKey)))

  expandkeyHelper += 1
  if expandkeyHelper == 6: expandkeyHelper = 0 ]#

  #....................
#[   case expandkeyHelper:
  of 0: result = mxKeySwapBitsEE2(mxKeyXor(mxKeyRotEnc(mxKeySwapMinors3(oldKey))))
  of 1: result = mxKeyXor(mxKeyRotEnc(mxKeyRotateLeftBits(oldKey)))
  of 2: result = mxKeyXor(mxKeySwapBitsEE2(oldKey))
  of 3: result = mxKeyXor(mxKeyRotateLeftBits(mxKeyNot(oldKey)))
  of 4: result = mxKeyXor(mxKeySwapBitsRound(oldKey))
  else: result = mxKeyXor(mxKeyRotEnc(oldKey)) ]#

#[
  #....................
  expandkeyHelper += 1
  if expandkeyHelper == 6: expandkeyHelper = 0

  if testBit(oldKey[0],0) :
    case expandkeyHelper:
      of 0: result = (mxKeySwapBitsEE2(mxKeySwapBitsRound(mxKeyRotEnc(mxKeySwapMinors3(oldKey)))))
      of 1: result = mxKeySwapBitsC(mxKeyAlg1(mxKeyRotEnc(mxKeyAlg1(oldKey))))
      of 2: result = (mxKeySwapBitsEE2(mxKeyAlg1(oldKey)))
      of 3: result = mxKeySwapBitsE(mxKeyAlg1(mxKeyRotateLeftBits(mxKeyNot(oldKey))))
      of 4: result = (mxKeyAlg1(mxKeySwapBitsRound(oldKey)))
      else: result = mxKeySwapBitsRound(mxKeyAlg1(mxKeyRotEnc(oldKey)))
  else:
    result = mxKeyReverse(result)
    case expandkeyHelper:
      of 0: result = mxKeySwapBitsEE2(mxKeyXor(mxKeyRotEnc(mxKeySwapMinors3(oldKey))))
      of 1: result = mxKeyAlg2(mxKeyRotEnc(mxKeyRotateLeftBits(oldKey)))
      of 2: result = mxKeyAlg2(mxKeySwapBitsEE2(oldKey))
      of 3: result = mxKeyAlg2(mxKeyRotateLeftBits(mxKeyNot(oldKey)))
      of 4: result = mxKeyAlg2(mxKeySwapBitsRound(oldKey))
      else: result = mxKeyAlg2(mxKeyRotEnc(oldKey))
  #....................

 ]#


  #....................

  proc kexproc1(a:ByteSeq):ByteSeq=
    result = changeDuplicatesB(mxKeyXor(a))

  proc kexproc2(a:ByteSeq):ByteSeq=
    result = changeDuplicatesB(mxKeyXorR(a))

  proc kexproc3(a:ByteSeq):ByteSeq=
    result = changeDuplicatesC(mxKeyAddRR(a))


  proc kexproc4(a:ByteSeq):ByteSeq=
    result = changeDuplicatesC(mxKeyXor(a))

  proc kexproc5(a:ByteSeq):ByteSeq=
    result = changeDuplicatesB(mxKeyAlg2(a))

  proc kexproc6(a:ByteSeq):ByteSeq=
    result = mxKeyAlg2(mxKeySwapMinors2(a))



  proc kexprocIII1(a:ByteSeq):ByteSeq=
    result = mxKeyAddRR(mxKeyAlg2(mxKeyAlg2(a)))

  proc kexprocIII2(a:ByteSeq):ByteSeq=
    result = mxKeyNot(mxKeyAlg2(mxKeyAlg2(a)))

  proc kexprocIII3(a:ByteSeq):ByteSeq=
    result = changeDuplicates(mxKeyAlg1(mxKeyAlg2(a)))

  proc kexprocIII4(a:ByteSeq):ByteSeq=
    result = mxKeyXorB(mxKeyAlg2(mxKeyAlg2(a)))

  proc kexprocIII5(a:ByteSeq):ByteSeq=
    result = mxKeySwapBitsD(mxKeyAlg2(mxKeyAlg2(a)))

  proc kexprocIII6(a:ByteSeq):ByteSeq=
    result = mxKeyXorR(mxKeyAlg1(mxKeyAlg2(a)))



  proc kexprocIV0(a:ByteSeq):ByteSeq=
    result = changeDuplicatesC(mxKeySwapMinors2(mxKeyXor(mxKeySwapMinors2(a))))

  proc kexprocIV01(a:ByteSeq):ByteSeq=
    result = changeDuplicatesB(mxKeySwapBitsA(mxKeyReverseBits(changeDuplicates(a))))

  proc kexprocIV02(a:ByteSeq):ByteSeq=
    result = mxKeyReverseBits(changeDuplicatesC(mxKeyXorR(mxKeyReverseBits(a))))

  proc kexprocIV03(a:ByteSeq):ByteSeq=
    result = mxKeyReverseBits(changeDuplicatesC(mxKeyReverseBits(mxKeyXorR(a))))

  proc kexprocIV04(a:ByteSeq):ByteSeq=
    result = mxKeySwapMinors(changeDuplicatesB(mxKeyXorR(mxKeySwapMinors(a))))

  proc kexprocIV05(a:ByteSeq):ByteSeq=
    result = mxKeySwapMinors(changeDuplicatesB(mxKeySwapMinors(mxKeyXorR(a))))

  proc kexprocIV06(a:ByteSeq):ByteSeq=
    result = mxKeyXorB(mxKeyXorB(changeDuplicatesB(mxKeyXorR(a))))

  proc kexprocIV07(a:ByteSeq):ByteSeq=
    result = changeDuplicatesB(mxKeyAlg2(mxKeyReverse(changeDuplicatesC(a))))



#[
  max identicals found: 86 : UmsYDCbDiQ0umpnQV8yYHCRl4YWb7
  total identicals found: 984 in 357492 0.28%
  byte fails: 115442/29614176 0.3898%
  max byte fails: 13083 : Finibus Bonorum et Malorum" by Cicero
  ----------------------------------------------------------
     ]#
#[
  expandkeyHelper += 1
  if expandkeyHelper == 7: expandkeyHelper = 0

  if testBit(oldKey[0],0) :
    case expandkeyHelper:
      of 0: result = kexprocIV02(oldKey)
      of 1: result = kexproc6(oldKey)
      of 2: result = kexprocIV04(oldKey)
      of 3: result = kexprocIV07(oldKey)
      of 4: result = kexproc2(oldKey)
      of 5: result = kexprocIII3(oldKey)
      of 6: result = kexproc4(oldKey)
      else: result = kexproc5(oldKey)

  else:
    #result = mxKeyReverse(result)
    case expandkeyHelper:
      of 0: result = kexprocIV03(oldKey)
      of 1: result = kexprocIV06(oldKey)
      of 2: result = kexprocIII5(oldKey)
      of 3: result = kexprocIII4(oldKey)
      of 4: result = kexprocIV0(oldKey)
      of 5: result = kexproc1(oldKey)
      of 6: result = kexprocIV01(oldKey)
      else: result = kexprocIII2(oldKey)
 ]#



  if KeyExpandProc == 4:
    #[ #3 max identicals found: 100 : Finibus Bonorum et Malorum" by Cicero
    total identicals found: 874 in 357492 0.24%
    byte fails: 115283/29614176 0.3893%
    max byte fails: 13320 : Finibus Bonorum et Malorum" by Cicero
    ]#
    expandkeyHelper += 1
    if expandkeyHelper == 16: expandkeyHelper = 0

    case expandkeyHelper:
    of  0: result = kexprocIV01(oldKey)
    of  1: result = kexprocIII3(oldKey)
    of  2: result = kexprocIII6(oldKey)
    of  3: result = kexprocIII1(oldKey)
    of  4: result = kexproc1(oldKey)
    of  5: result = kexproc3(oldKey)
    of  6: result = kexprocIII5(oldKey)
    of  7: result = kexproc4(oldKey)
    of  8: result = kexproc2(oldKey)
    of  9: result = kexproc6(oldKey)
    of 10: result = kexprocIV04(oldKey)
    of 11: result = kexprocIV03(oldKey)
    of 12: result = kexprocIII2(oldKey)
    of 13: result = kexprocIV06(oldKey)
    of 14: result = kexprocIV05(oldKey)
    else:  result = kexprocIV07(oldKey)





#[ #6 keyexpgenB-SUM-MAX-SUCC_F30R-16
 max identicals found: 90 : Finibus Bonorum et Malorum" by Cicero
 total identicals found: 894 in 357492 0.25%
 byte fails: 115924/29614176 0.3914%
 max byte fails: 13257 : Finibus Bonorum et Malorum" by Cicero
 ----------------------------------------------------------
 ]#
#[
  expandkeyHelper += 1
  if expandkeyHelper == 16: expandkeyHelper = 0

  case expandkeyHelper:
  of  0: result = kexprocIII1(oldKey)
  of  1: result = kexprocIV04(oldKey)
  of  2: result = kexproc2(oldKey)
  of  3: result = kexproc4(oldKey)
  of  4: result = kexprocIV02(oldKey)
  of  5: result = kexproc1(oldKey)
  of  6: result = kexprocIII2(oldKey)
  of  7: result = kexproc5(oldKey)
  of  8: result = kexprocIV05(oldKey)
  of  9: result = kexprocIII5(oldKey)
  of 10: result = kexprocIII4(oldKey)
  of 11: result = kexprocIII3(oldKey)
  of 12: result = kexproc3(oldKey)
  of 13: result = kexprocIII6(oldKey)
  of 14: result = kexproc6(oldKey)
  else:  result = kexprocIV01(oldKey)
 ]#


  if KeyExpandProc == 2:
    #[ #7 :( keyexpgenB-SUM-MAX-SUCC_F30R-16 - best 4 combined
    max identicals found: 78 : UmsYDCbDiQ0umpnQV8yYHCRl4YWb7
    total identicals found: 844 in 357492 0.24%
    byte fails: 115981/29614176 0.3916%
    max byte fails: 13499 : Finibus Bonorum et Malorum" by Cicero
    ]#
    expandkeyHelper += 1
    if expandkeyHelper == 64: expandkeyHelper = 0

    case expandkeyHelper:
    of   0: result = kexprocIII1(oldKey)
    of   1: result = kexprocIV04(oldKey)
    of   2: result = kexproc2(oldKey)
    of   3: result = kexproc4(oldKey)
    of   4: result = kexprocIV02(oldKey)
    of   5: result = kexproc1(oldKey)
    of   6: result = kexprocIII2(oldKey)
    of   7: result = kexproc5(oldKey)
    of   8: result = kexprocIV05(oldKey)
    of   9: result = kexprocIII5(oldKey)
    of  10: result = kexprocIII4(oldKey)
    of  11: result = kexprocIII3(oldKey)
    of  12: result = kexproc3(oldKey)
    of  13: result = kexprocIII6(oldKey)
    of  14: result = kexproc6(oldKey)
    of  15: result = kexprocIV01(oldKey)

    of  16: result = kexproc6(oldKey)
    of  17: result = kexprocIV02(oldKey)
    of  18: result = kexproc2(oldKey)
    of  19: result = kexprocIV0(oldKey)
    of  20: result = kexprocIV07(oldKey)
    of  21: result = kexprocIV03(oldKey)
    of  22: result = kexproc3(oldKey)
    of  23: result = kexprocIV04(oldKey)
    of  24: result = kexprocIII1(oldKey)
    of  25: result = kexprocIII5(oldKey)
    of  26: result = kexprocIII4(oldKey)
    of  27: result = kexproc5(oldKey)
    of  28: result = kexproc4(oldKey)
    of  29: result = kexprocIII2(oldKey)
    of  30: result = kexprocIII6(oldKey)
    of  31: result = kexproc1(oldKey)

    of  32: result = kexprocIV07(oldKey)
    of  33: result = kexproc2(oldKey)
    of  34: result = kexprocIII4(oldKey)
    of  35: result = kexprocIII3(oldKey)
    of  36: result = kexproc3(oldKey)
    of  37: result = kexproc6(oldKey)
    of  38: result = kexprocIV03(oldKey)
    of  39: result = kexprocIII1(oldKey)
    of  40: result = kexprocIV06(oldKey)
    of  41: result = kexprocIV05(oldKey)
    of  42: result = kexprocIV01(oldKey)
    of  43: result = kexprocIV02(oldKey)
    of  44: result = kexprocIV0(oldKey)
    of  45: result = kexprocIII5(oldKey)
    of  46: result = kexproc1(oldKey)
    of  47: result = kexprocIII6(oldKey)

    of  48: result = kexprocIV02(oldKey)
    of  49: result = kexprocIII5(oldKey)
    of  50: result = kexproc6(oldKey)
    of  51: result = kexprocIV03(oldKey)
    of  52: result = kexproc1(oldKey)
    of  53: result = kexprocIII4(oldKey)
    of  54: result = kexprocIV0(oldKey)
    of  55: result = kexproc3(oldKey)
    of  56: result = kexprocIV07(oldKey)
    of  57: result = kexprocIII1(oldKey)
    of  58: result = kexprocIII6(oldKey)
    of  59: result = kexproc5(oldKey)
    of  60: result = kexprocIV04(oldKey)
    of  61: result = kexprocIII3(oldKey)
    of  62: result = kexproc2(oldKey)
    else:   result = kexprocIV01(oldKey)



  if KeyExpandProc == 3:
    #[
    #2 keyexpgenB-SUM-MAX-SUCC_E30R-8
    max identicals found: 104 : Finibus Bonorum et Malorum" by Cicero
    total identicals found: 846 in 357492 0.24%
    byte fails: 115229/29614176 0.3891%
    max byte fails: 13185 : Finibus Bonorum et Malorum" by Cicero
    ----------------------------------------------------------
    ]#
    expandkeyHelper += 1
    if expandkeyHelper == 8: expandkeyHelper = 0

    case expandkeyHelper:
    of   0: result = kexprocIV06(oldKey)
    of   1: result = kexprocIV0(oldKey)
    of   2: result = kexprocIV02(oldKey)
    of   3: result = kexprocIII4(oldKey)
    of   4: result = kexproc4(oldKey)
    of   5: result = kexprocIII1(oldKey)
    of   6: result = kexprocIV05(oldKey)
    else: result = kexprocIII5(oldKey)




  #[ max identicals found: 94 : Finibus Bonorum et Malorum" by Cicero
  total identicals found: 906 in 357492 0.25% 
  byte fails: 115525/29614176 0.3901%
  max byte fails: 13279 : Finibus Bonorum et Malorum" by Cicero
  ]#
  #[ expandkeyHelper += 1
  if expandkeyHelper == 8: expandkeyHelper = 0
  case expandkeyHelper:
  of 0: result = kexprocIII5(oldKey)
  of 1: result = kexprocIV03(oldKey)
  of 2: result = kexprocIII3(oldKey)
  of 3: result = kexprocIII2(oldKey)
  of 4: result = kexprocIV07(oldKey)
  of 5: result = kexprocIV02(oldKey)
  of 6: result = kexprocIII6(oldKey)
  else: result = kexproc5(oldKey) ]#
 


  if KeyExpandProc == 1:
    #[ max identicals found: 78 : Lacus cubilia urna eget eleifend
    total identicals found: 840 in 357492 0.23% 
    byte fails: 115632/29614176 0.3905%
    max byte fails: 13231 : Finibus Bonorum et Malorum" by Cicero ]#
    expandkeyHelper += 1
    if expandkeyHelper == 16: expandkeyHelper = 0
    case expandkeyHelper:
    of  0: result = kexprocIV07(oldKey)
    of  1: result = kexproc2(oldKey)
    of  2: result = kexprocIV02(oldKey)
    of  3: result = kexproc5(oldKey)
    of  4: result = kexprocIV05(oldKey)
    of  5: result = kexprocIV04(oldKey)
    of  6: result = kexprocIII1(oldKey)
    of  7: result = kexprocIV06(oldKey)
    of  8: result = kexproc6(oldKey)
    of  9: result = kexprocIII5(oldKey)
    of 10: result = kexprocIV0(oldKey)
    of 11: result = kexproc3(oldKey)
    of 12: result = kexproc4(oldKey)
    of 13: result = kexprocIV03(oldKey)
    else:  result = kexprocIII2(oldKey)



  if KeyExpandProc == 0:
    #[ #1 keyexpgenC-SUM-MAX-SUCC_F30R-64
      max identicals found: 88 : Finibus Bonorum et Malorum" by Cicero
      total identicals found: 826 in 357492 0.23%
      byte fails: 114961/29614176 0.3882%
      max byte fails: 13231 : Finibus Bonorum et Malorum" by Cicero
      ----------------------------------------------------------
    ]#
    expandkeyHelper += 1
    if expandkeyHelper == 64: expandkeyHelper = 0

    case expandkeyHelper:
    of   0: result = kexproc4(oldKey)
    of   1: result = kexproc1(oldKey)
    of   2: result = kexprocIV07(oldKey)
    of   3: result = kexprocIV01(oldKey)
    of   4: result = kexprocIV07(oldKey)
    of   5: result = kexprocIV0(oldKey)
    of   6: result = kexproc1(oldKey)
    of   7: result = kexprocIV03(oldKey)
    of   8: result = kexprocIII6(oldKey)
    of   9: result = kexprocIV07(oldKey)
    of  10: result = kexproc5(oldKey)
    of  11: result = kexprocIII5(oldKey)
    of  12: result = kexproc4(oldKey)
    of  13: result = kexproc3(oldKey)
    of  14: result = kexproc2(oldKey)
    of  15: result = kexprocIV0(oldKey)
    of  16: result = kexprocIII2(oldKey)
    of  17: result = kexprocIV0(oldKey)
    of  18: result = kexprocIII6(oldKey)
    of  19: result = kexprocIV03(oldKey)
    of  20: result = kexprocIV05(oldKey)
    of  21: result = kexprocIV04(oldKey)
    of  22: result = kexproc2(oldKey)
    of  23: result = kexprocIV03(oldKey)
    of  24: result = kexproc6(oldKey)
    of  25: result = kexproc4(oldKey)
    of  26: result = kexprocIV02(oldKey)
    of  27: result = kexprocIV0(oldKey)
    of  28: result = kexproc2(oldKey)
    of  29: result = kexprocIV01(oldKey)
    of  30: result = kexprocIII5(oldKey)
    of  31: result = kexprocIII3(oldKey)
    of  32: result = kexprocIV04(oldKey)
    of  33: result = kexprocIV07(oldKey)
    of  34: result = kexproc6(oldKey)
    of  35: result = kexprocIV07(oldKey)
    of  36: result = kexprocIV02(oldKey)
    of  37: result = kexprocIII3(oldKey)
    of  38: result = kexprocIV0(oldKey)
    of  39: result = kexproc5(oldKey)
    of  40: result = kexprocIV04(oldKey)
    of  41: result = kexprocIII6(oldKey)
    of  42: result = kexprocIV0(oldKey)
    of  43: result = kexproc5(oldKey)
    of  44: result = kexprocIV01(oldKey)
    of  45: result = kexprocIII2(oldKey)
    of  46: result = kexprocIV06(oldKey)
    of  47: result = kexprocIV05(oldKey)
    of  48: result = kexprocIV01(oldKey)
    of  49: result = kexprocIV07(oldKey)
    of  50: result = kexprocIII3(oldKey)
    of  51: result = kexprocIII5(oldKey)
    of  52: result = kexproc5(oldKey)
    of  53: result = kexprocIV04(oldKey)
    of  54: result = kexprocIV05(oldKey)
    of  55: result = kexprocIII6(oldKey)
    of  56: result = kexprocIV06(oldKey)
    of  57: result = kexprocIV04(oldKey)
    of  58: result = kexprocIV06(oldKey)
    of  59: result = kexproc3(oldKey)
    of  60: result = kexprocIV0(oldKey)
    of  61: result = kexprocIV02(oldKey)
    of  62: result = kexprocIII2(oldKey)
    else: result =   kexprocIV03(oldKey)





  #[ #7 keyexpgenC-SUM-MAX-SUCC_F30R-64
    max identicals found: 92 : Finibus Bonorum et Malorum" by Cicero
    total identicals found: 922 in 357492 0.26%
    byte fails: 115585/29614176 0.3903%
    max byte fails: 13346 : Finibus Bonorum et Malorum" by Cicero
    ----------------------------------------------------------
   ]#
  #[ expandkeyHelper += 1
  if expandkeyHelper == 64: expandkeyHelper = 0

  case expandkeyHelper:
  of   0: result = kexproc5(oldKey)
  of   1: result = kexprocIII5(oldKey)
  of   2: result = kexprocIII5(oldKey)
  of   3: result = kexprocIV0(oldKey)
  of   4: result = kexprocIV04(oldKey)
  of   5: result = kexprocIII3(oldKey)
  of   6: result = kexprocIV02(oldKey)
  of   7: result = kexproc5(oldKey)
  of   8: result = kexprocIV02(oldKey)
  of   9: result = kexproc4(oldKey)
  of  10: result = kexprocIV01(oldKey)
  of  11: result = kexprocIV04(oldKey)
  of  12: result = kexprocIII4(oldKey)
  of  13: result = kexproc5(oldKey)
  of  14: result = kexprocIII4(oldKey)
  of  15: result = kexprocIV04(oldKey)
  of  16: result = kexprocIV05(oldKey)
  of  17: result = kexprocIII1(oldKey)
  of  18: result = kexproc6(oldKey)
  of  19: result = kexprocIV05(oldKey)
  of  20: result = kexprocIII1(oldKey)
  of  21: result = kexproc3(oldKey)
  of  22: result = kexprocIII4(oldKey)
  of  23: result = kexprocIV02(oldKey)
  of  24: result = kexprocIII4(oldKey)
  of  25: result = kexprocIV02(oldKey)
  of  26: result = kexprocIV03(oldKey)
  of  27: result = kexprocIII2(oldKey)
  of  28: result = kexproc6(oldKey)
  of  29: result = kexprocIV06(oldKey)
  of  30: result = kexprocIV03(oldKey)
  of  31: result = kexproc6(oldKey)
  of  32: result = kexprocIV04(oldKey)
  of  33: result = kexprocIV06(oldKey)
  of  34: result = kexprocIV02(oldKey)
  of  35: result = kexprocIV01(oldKey)
  of  36: result = kexprocIII4(oldKey)
  of  37: result = kexprocIII3(oldKey)
  of  38: result = kexprocIII6(oldKey)
  of  39: result = kexproc3(oldKey)
  of  40: result = kexprocIII4(oldKey)
  of  41: result = kexprocIII6(oldKey)
  of  42: result = kexproc1(oldKey)
  of  43: result = kexprocIV06(oldKey)
  of  44: result = kexproc4(oldKey)
  of  45: result = kexproc3(oldKey)
  of  46: result = kexprocIV04(oldKey)
  of  47: result = kexprocIII3(oldKey)
  of  48: result = kexprocIII1(oldKey)
  of  49: result = kexprocIII5(oldKey)
  of  50: result = kexprocIV0(oldKey)
  of  51: result = kexprocIV04(oldKey)
  of  52: result = kexproc2(oldKey)
  of  53: result = kexproc1(oldKey)
  of  54: result = kexprocIII6(oldKey)
  of  55: result = kexprocIII2(oldKey)
  of  56: result = kexproc1(oldKey)
  of  57: result = kexprocIII2(oldKey)
  of  58: result = kexprocIII5(oldKey)
  of  59: result = kexprocIII4(oldKey)
  of  60: result = kexprocIV07(oldKey)
  of  61: result = kexprocIII6(oldKey)
  of  62: result = kexprocIII3(oldKey)
  else: result =   kexprocIV07(oldKey)

 ]#





  #[ #4 keyexpgenC-SUM-MAX-SUCC_F30R-64
    max identicals found: 96 : Finibus Bonorum et Malorum" by Cicero
    total identicals found: 910 in 357492 0.25%
    byte fails: 115561/29614176 0.3902%
    max byte fails: 13379 : Finibus Bonorum et Malorum" by Cicero
    ----------------------------------------------------------
   ]#
  #[ expandkeyHelper += 1
  if expandkeyHelper == 64: expandkeyHelper = 0

  case expandkeyHelper:
  of   0: result = kexproc5(oldKey)
  of   1: result = kexprocIII1(oldKey)
  of   2: result = kexproc6(oldKey)
  of   3: result = kexprocIV01(oldKey)
  of   4: result = kexprocIV01(oldKey)
  of   5: result = kexproc3(oldKey)
  of   6: result = kexprocIV03(oldKey)
  of   7: result = kexproc6(oldKey)
  of   8: result = kexprocIII2(oldKey)
  of   9: result = kexprocIV07(oldKey)
  of  10: result = kexprocIV03(oldKey)
  of  11: result = kexprocIII5(oldKey)
  of  12: result = kexproc2(oldKey)
  of  13: result = kexprocIII3(oldKey)
  of  14: result = kexproc6(oldKey)
  of  15: result = kexproc6(oldKey)
  of  16: result = kexproc3(oldKey)
  of  17: result = kexproc4(oldKey)
  of  18: result = kexprocIII2(oldKey)
  of  19: result = kexproc1(oldKey)
  of  20: result = kexprocIV03(oldKey)
  of  21: result = kexprocIII4(oldKey)
  of  22: result = kexprocIII6(oldKey)
  of  23: result = kexprocIII5(oldKey)
  of  24: result = kexproc1(oldKey)
  of  25: result = kexprocIII6(oldKey)
  of  26: result = kexprocIV05(oldKey)
  of  27: result = kexprocIV02(oldKey)
  of  28: result = kexprocIV02(oldKey)
  of  29: result = kexprocIII3(oldKey)
  of  30: result = kexprocIV04(oldKey)
  of  31: result = kexprocIII3(oldKey)
  of  32: result = kexprocIV02(oldKey)
  of  33: result = kexprocIV0(oldKey)
  of  34: result = kexprocIII1(oldKey)
  of  35: result = kexprocIII2(oldKey)
  of  36: result = kexprocIII1(oldKey)
  of  37: result = kexproc3(oldKey)
  of  38: result = kexproc3(oldKey)
  of  39: result = kexprocIV07(oldKey)
  of  40: result = kexprocIII6(oldKey)
  of  41: result = kexproc3(oldKey)
  of  42: result = kexprocIII3(oldKey)
  of  43: result = kexprocIII4(oldKey)
  of  44: result = kexproc3(oldKey)
  of  45: result = kexprocIV01(oldKey)
  of  46: result = kexprocIV0(oldKey)
  of  47: result = kexprocIII2(oldKey)
  of  48: result = kexproc1(oldKey)
  of  49: result = kexproc6(oldKey)
  of  50: result = kexprocIV02(oldKey)
  of  51: result = kexprocIV01(oldKey)
  of  52: result = kexprocIV07(oldKey)
  of  53: result = kexproc6(oldKey)
  of  54: result = kexprocIII1(oldKey)
  of  55: result = kexprocIII2(oldKey)
  of  56: result = kexproc1(oldKey)
  of  57: result = kexprocIII2(oldKey)
  of  58: result = kexprocIII2(oldKey)
  of  59: result = kexprocIV02(oldKey)
  of  60: result = kexprocIII2(oldKey)
  of  61: result = kexproc4(oldKey)
  of  62: result = kexprocIV07(oldKey)
  else: result =   kexproc4(oldKey)
 ]#




  result = mxKeyAddRR(result) #*
  result = result.changeDuplicatesC() #**
  #result = result.changeDuplicatesB() #*
  #....................



  #*#######################################################
  #[
  #result = mxKeyReverse(result) #*

  #result = mxKeysXor(oldKey,mxKeyRotEncD(oldKey))
  #result = mxKeySwapBitsRound(result)
  #result = mxKeySwapMinors3(result)

  if oldKey[0] < oldKey[7]:
    result = mxKeyRotEnc(mxKeySwapMinors2(mxKeyXorB((oldKey))))
  else:
    result = mxKeySwapBitsEE2(mxKeyXor(mxKeyRotEnc(mxKeySwapMinors3(oldKey))))


  #result = mxKeyXor(result) #*
  #result = result.changeDuplicatesB() #*

  result = result.changeDuplicatesC() #**

  for i in 0..result.high:
    if result[i].countSetBits < 2:
      result[i] = result[i] xor 0b01010101

  #[ for i in 0..result.high:
    var x = result[i]
    result[i] = result[result.high - i]
    result[result.high - i] = x ]#
 ]#
#*##################################################################
#*##################################################################
#*##################################################################
#*##################################################################











proc drawKey*(key:ByteSeq)=
  for i in 0..key.high:
    #stdout.write "\e[48;5;" & $k[i] & "m", fmt"{k[i]:>3d}" , "\e[0m"
    stdout.write "\e[48;5;" & $key[i] & "m", "  " , "\e[0m"
  echo ""

proc echoKey*(key:ByteSeq)=
  for i in 0..key.high:
    for d in 0..key.high:
      if key[i] == key[d] and i != d:
        stdout.write "\e[1;33m"
    stdout.write fmt"{key[i]:>3d},"
    stdout.write "\e[0m"
    if i mod 16 == 0  and  i > 0:
      echo ""
  echo ""

#[ proc drawKeyTable*(key:ByteSeq)=
  var k = key
  for ek in 0..KeyTableRows-1:
    for i in 0..key.high:
      #stdout.write "\e[48;5;" & $k[i] & "m", fmt"{k[i]:>3d}" , "\e[0m"
      stdout.write "\e[48;5;" & $k[i] & "m", "  " , "\e[0m"
    echo ""
    k = expandKey(k) ]#


proc drawKeyTable*(key:KeyTable)=
  #var k = key
  for ek in 0..KeyTableRows-1:
    for i in 0..(KeyLen - 1):
      #stdout.write "\e[48;5;" & $k[i] & "m", fmt"{k[i]:>3d}" , "\e[0m"
      stdout.write "\e[48;5;" & $key[ek][i] & "m", "  " , "\e[0m"
    echo ""

proc drawKeyTableGr*(key:KeyTable)=
  #var k = key
  for ek in 0..KeyTableRows-1:
    for i in 0..(KeyLen - 1):
      #stdout.write "\e[48;5;" & $k[i] & "m", fmt"{k[i]:>3d}" , "\e[0m"
      stdout.write "\e[48;2;" & $key[ek][i] & ";" & $key[ek][i] & ";" & $key[ek][i] & "m", "  " , "\e[0m"
    echo ""







#******************************************************
#******************************************************
#******************************************************
proc getKeyTable*(k:ByteSeq,expandkeyHelper: var int):KeyTable=
  var key = k
  for i in 0..KeyTableRows-1:
    key = expandKey(key,expandkeyHelper)
    result.add(key) # changed order for continous mode
  #changeDuplicates(result)

proc clearKeyTable*(kT:var KeyTable)= #!implement
  ## zerofill KeyTable
  for k in 0..kT.high:
    for i in 0..kT[k].high:
      kT[k][i] = 0
#******************************************************
#******************************************************
#******************************************************







#[
  #DEPRECATED
  proc getVerticalPlane(a:ByteSeq):KeyTable=
  var key = a
  for i in 0..KeyTableRows-1:
    result[i] = @[]

  for i in 0..KeyTableRows-1:
    for c in countdown((KeyLen - 1),0):
      result[c].add(key[(KeyLen - 1)-c])
    key = expandKey(key) ]#

proc mxZipPlanes*(a,b:KeyTable):KeyTable= #unused
  for i in 0..KeyTableRows-1:
    result.add(mxZipKeys(a[i],b[i]))



# TODO test diversity
proc crawlPlane*(k:ByteSeq):ByteSeq=
  result.add(k[0])
  for i in 1..k.high:
    result.add(result[i-1] + k[i])
#[
proc crawlPlane2*(k:ByteSeq):ByteSeq=
  var aP = getKeyTable(k) #TODO use global
  var x,y:int
  var d:int

  proc moveUp(dY:int):int=
    if dY == 0:
      result = y - 3
    else:
      result = y - dY
    if result < 0: result = KeyTableRows-1 + result #result * -1
    if result > KeyTableRows-1: result = result - KeyTableRows-1
  proc moveDown(dY:int):int=
    if dY == 0:
      result = y + 3
    else:
      result = y + dY
    if result > KeyTableRows-1: result = result - KeyTableRows-1
    if result < 0: result = result * -1
  proc moveLeft(dX:int):int=
    if dX == 0:
      result = x - 3
    else:
      result = x - dX
    if result < 0: result = (KeyLen - 1) + result #result * -1
    if result > (KeyLen - 1): result = result - (KeyLen - 1)
  proc moveRight(dX:int):int=
    if dX == 0:
      result = x + 3
    else:
      result = x + dX
    if result > (KeyLen - 1): result = result - (KeyLen - 1)
    if result < 0: result = result * -1

  var movex:bool=true
  var c = 0
  for cc in countdown((KeyLen - 1),0):
    if movex:
      if aP[c][cc] < 128:
        x = moveRight((aP[c][cc] div 32).int)
      else:
        x = moveLeft((aP[c][cc] div 32).int)
      movex = false
    else:
      if aP[c][cc] < 128:
        y = moveUp((aP[c][cc] div 32).int)
      else:
        y = moveDown((aP[c][cc] div 32).int)
      movex = true
    result.add(aP[y][x])
    c += 1

 ]#

#TODO test, visualize
proc crawlTable*(kT:KeyTable):ByteSeq=
  var
    x:int = Keylen div 2
    y:int = KeyTableRows div 2


  proc moveUp(dY:int):int=
    if dY == 0:
      result = y - 3
    else:
      result = y - dY
    if result < 0: result = KeyTableRows-1 + result #result * -1
    if result > KeyTableRows-1: result = result - KeyTableRows-1
  proc moveDown(dY:int):int=
    if dY == 0:
      result = y + 3
    else:
      result = y + dY
    if result > KeyTableRows-1: result = result - KeyTableRows-1
    if result < 0: result = result * -1
  proc moveLeft(dX:int):int=
    if dX == 0:
      result = x - 3
    else:
      result = x - dX
    if result < 0: result = (KeyLen - 1) + result #result * -1
    if result > (KeyLen - 1): result = result - (KeyLen - 1)
  proc moveRight(dX:int):int=
    if dX == 0:
      result = x + 3
    else:
      result = x + dX
    if result > (KeyLen - 1): result = result - (KeyLen - 1)
    if result < 0: result = result * -1

  var movex:bool=true
  var c = 0
  for cc in countdown((KeyLen - 1),0):
    if movex:
      if kT[c][cc] < 128:
        x = moveRight((kT[c][cc] div 32).int)
      else:
        x = moveLeft((kT[c][cc] div 32).int)
      movex = false
    else:
      if kT[c][cc] < 128:
        y = moveUp((kT[c][cc] div 32).int)
      else:
        y = moveDown((kT[c][cc] div 32).int)
      movex = true
    result.add(kT[y][x])
    c += 1
    if c == KeyTableRows: c = 0



#*###################################################################
#*###################################################################



# NO multi file encode:
# enable / disable threads & set maxTh number
# even if th enabled, do we need th?
proc begin*()=
  discard
  ## generate salt_rand
  ## set keyexpandMode & generate keytable
  ## generate extrabytes pos - for decode
  ## make it reentrant

#*     ##     ##    ###    ##    ## ########
#*     ###   ###   ## ##   ##   ##  ##
#*     #### ####  ##   ##  ##  ##   ##
#*     ## ### ## ##     ## #####    ######
#*     ##     ## ######### ##  ##   ##
#*     ##     ## ##     ## ##   ##  ##
#*     ##     ## ##     ## ##    ## ########

# TODO maybe real changeDuplicates is possible?!!!
proc makeNewKeyTables(keyTable,othKeyTable: var KeyTable,
                      expandkeyHelper: var int,
                      keyExpandMode:KeyExpandMode = kemAuto)=
  const debug = 0b0
  #? keyVariant = 0

  case keyExpandMode:
  of kemRepeat, kemAuto: discard

  of kemContinuos:
    keyTable = getKeyTable(
                  keyTable[KeyTableRows - 1],
                  expandkeyHelper)

    othKeyTable = getKeyTable(
                    crawlTable(keyTable),
                    expandkeyHelper)

  of kemBlock:
    for i in 0 .. (KeyTableRows - 1):
      keyTable[i] = expandKey(keyTable[i],expandkeyHelper)

    othKeyTable = getKeyTable(
                    crawlTable(keyTable),
                    expandkeyHelper)

  when debug >= 0b1 : echo keyTable[0][0]
  #changeDuplicates(keyTable)
  #changeDuplicates(othKeyTable)
#===========================================================




proc makeExtraTables*(oKey: ByteSeq):KeyTable=
  ## #############################################################
  ## DON'T USE WITHOUT SETTING EXPANDPROC!!!------------------- ##
  ##  for c in password:                                        ##
  ##    bitgrinder.KeyExpandProc += c.uint8                     ##
  ##                                                            ##
  ##  bitgrinder.KeyExpandProc = bitgrinder.KeyExpandProc mod 5 ##
  ## #############################################################
  const debug = 0b0
  #echo ">>>>>>>> ",oKey

  var
    s1,s2,s3,s4,s5,s6, s7,s8: uint8
    eKeyHelper: int
    theKey = oKey[0..15]

  #for ex in 0..oKey.high:
  for ex in 0..KeyTableRows-1:
    theKey = expandKey(theKey,eKeyHelper)
    s1 = 0
    s2 = 0
    s3 = 0
    s4 = 0
    s5 = 0
    s6 = 0
    s7 = 0
    s8 = 0

    for by in 0..15: # theKey.high:
      if ((theKey[by] and 0b1111)) >= 11.uint8:
        #stdout.write "| "
        if by < 8:
          s1 = (s1 shl 1) or 1
        else:
          s2 = (s2 shl 1) or 1
      else:
        #stdout.write ". "
        if by < 8:
          s1 = (s1 shl 1)
        else:
          s2 = (s2 shl 1)

      if ((theKey[by] shr 4)) >= 11.uint8:
        #stdout.write "| "
        if by < 8:
          s3 = (s3 shl 1) or 1
        else:
          s4 = (s4 shl 1) or 1
      else:
        #stdout.write ". "
        if by < 8:
          s3 = (s3 shl 1)
        else:
          s4 = (s4 shl 1)

      if ((theKey[by] shr 1) and 0b1111) >= 11.uint8:
        #stdout.write "| "
        if by < 8:
          s5 = (s5 shl 1) or 1
        else:
          s6 = (s6 shl 1) or 1
      else:
        #stdout.write ". "
        if by < 8:
          s5 = (s5 shl 1)
        else:
          s6 = (s6 shl 1)

    s1 = (s1 + theKey[5])
    s2 = (s2 + theKey[5])
    s3 = (s3 + theKey[5])
    s4 = (s4 + theKey[5])
    s5 = (s5 + theKey[5])
    s6 = (s6 + theKey[5])
    s7 = (s1 xor (s5 + s3)) xor theKey[5]
    s8 = (s2 xor (s6 + s4)) xor theKey[5]
    when debug >= 0b11:
      echo fmt"{s1:>3d}, {s2:>3d}, {s3:>3d}, {s4:>3d},  {s5:>3d}, {s6:>3d}, {s7:>3d}, {s8:>3d} "

    #if result.len < KeyLen:
    result.add((@[s1,s2,s3,s4,s5,s6,s7,s8]))


    if ex mod 2 == 0:
      result[result.high] = mxKeySwapBitsRound(result[result.high])
    else:
      result[result.high] = mxKeySwapBitsEE2(result[result.high])

    result[result.high] = mxKeyXor(result[result.high])

    result[result.high] = result[result.high].changeDuplicatesB()


    #changeDuplicates result


proc makeExtraTables*(pass:string):KeyTable=
  var theKey = passToKey(pass)
  result = makeExtraTables(theKey)

#============================================================


proc getPosition*(max,len:SomeInteger, key:uint8):int=
  var flo = max / len
  result = (key.float / flo).int #.round()


proc getExtraPositions*(chunkLen:int,
                        key: ByteSeq,
                        #count:int=7
                        count:range[0..7]=7):seq[int]=
  #var extraBPos: array[0..3,int]
  for k in 0..count:
    result.add getPosition(uint8.high.int, chunkLen, key[k])
  result.sort()
  #echo extraBPos

#============================================================


proc endjob*()=
  discard
  ## add extrabytes
  ## fillzero memory



#*#####################################################################
#*#####################################################################





















#[

######## ##    ##
##       ###   ##
##       ####  ##
######   ## ## ## ######
##       ##  ####
##       ##   ###
######## ##    ##

 ######   #######  ########  ########
##    ## ##     ## ##     ## ##
##       ##     ## ##     ## ##
##       ##     ## ##     ## ######
##       ##     ## ##     ## ##
##    ## ##     ## ##     ## ##
 ######   #######  ########  ########

 ]#


proc encode*(seg: var ByteSeq,
             encKey:ByteSeq,
             passw:string,
             salt_rand: uint8,
             preBurn=PreBurn,
             oKeyExpandMode:KeyExpandMode = kemAuto)= #!ENC
  const debug = 0b0

  #[ expandkeyHelper = 0 #!!!!
  keyVariant = 0 #!!!! ]#

  #let segLen = (seg.high - seg.low) + 1
  when debug >= 0b1: echo "EN: SEG[] ", seg[seg.low .. seg.low + 4]

  var
    keyExpandMode:KeyExpandMode = oKeyExpandMode
    expandkeyHelper:int
    keyTable: KeyTable # the keytable in use
    othKeyTable: KeyTable # second table derived from keyTable
    keyVariant:int = 0
    keyIterator: int = 0
    # made global #keyVariant: int

    salt_keyVariant:uint8 = 0
    salt_keyTable:uint8 = 0
    salt_pass:uint8 = 0

    #bibits:uint8 = 0


  #*-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=

  #.......................
  for c in passw:
    salt_pass += c.uint8
  #.......................

  if KeyExpandProc == 128:
    KeyExpandProc = 0
    KeyExpandProc = salt_pass mod 5
    when debug >= 0b111: echo "ENC KeyExpandProc = ", KeyExpandProc
  else:
    when debug >= 0b111: echo "ENC KeyExpandProc = ", KeyExpandProc
    discard

  #*..............................................

  var passCounter:int

  #*..............................................
  #!.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-
  #!.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-
  if encKey.len == KeyLen:
    when debug >= 0b10: echo "\tENC: key from passw - getting keyTable, othKeyTable ..."
    keyTable = getKeyTable(encKey,expandkeyHelper)
    othKeyTable = getKeyTable(crawlTable(keyTable),
                              expandkeyHelper)
    if keyExpandMode == kemAuto:
      keyExpandMode = kemRepeat
    #keyExpandMode = kemBlock #!DEBUG
    #keyExpandMode = kemContinuos #!DEBUG

  elif encKey.len == KeyTableRows * KeyLen: 
    when debug >= 0b10: echo "\tENC: keyTable from key ",encKey.len,", ", KeyTableRows,", ", KeyLen
    for i in countup(0,encKey.high,KeyLen):
      keyTable.add(encKey[i .. (i + KeyLen - 1)])

    othKeyTable = getKeyTable(crawlTable(keyTable),
                              expandkeyHelper)
    if keyExpandMode == kemAuto:
      keyExpandMode = kemBlock
  
  elif encKey.len >= 256 and (encKey.len mod MinKeyTableRows == 0): #!NEW 
    when debug >= 0b10: echo "\tENC: keyTable from key - password and keytable different source"
    KeyLen = MinKeyLen
    for i in countup(0,encKey.high,KeyLen):
      keyTable.add(encKey[i .. (i + KeyLen - 1)])
    if keyExpandMode == kemAuto:
      keyExpandMode = kemBlock

  else:
    quit("EXCEPTION ENCODING: argument error, KeyTable error " & $encKey.len & "," & $KeyLen)
  #!.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-
  #!.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-

  salt_keyTable = keyTable[0][0]
  for c in 1..keyTable.high:
    if c mod 2 == 0:
      #salt_keyTable = salt_keyTable xor keyTable[c][0]
      salt_keyTable -= keyTable[c][0]
    else:
      salt_keyTable = salt_keyTable xor keyTable[c][0]
      salt_keyTable += keyTable[c][0]
  #*..............................................

  #!PREBURNER............................
  for pbrn in 0..((salt_rand and 0b1111).int + preBurn):
    expandkeyHelper = 0
    makeNewKeyTables( keyTable,
                      othKeyTable,
                      expandkeyHelper,
                      keyExpandMode)

  #*..............................................

  # salt - salt - salt - salt - salt - salt -

  salt_keyVariant = keyTable[keyVariant][0]
  for c in 1..keyTable[keyVariant].high:
    salt_keyVariant = salt_keyVariant xor keyTable[keyVariant][c]
  for c in 0..othKeyTable[keyVariant].high:
    salt_keyVariant = salt_keyVariant xor othKeyTable[keyVariant][c]


  when debug >= 0b1: echo "EN: original KeyTable\n", keyTable[keyVariant], "\n"
  when debug >= 0b1111: echo "\nEN:  PLAINTEXT\n",toString(seg),"\n\n"#, " ", seg.len


  #*------- ENCODE INIT

  #!EXP_BEFORE_1
  #[ var pC = encKey.high div 2
  for i in seg.low..seg.high:
    seg[i] = seg[i] + encKey[pC]
    pC += 1
    if pC > encKey.high: pC = 0  ]#

  #[ var pC = 0
  for i in seg.low..seg.high:
    seg[i] = seg[i] - encKey[pC]
    pC += 1
    if pC > encKey.high: pC = 0 ]#
  #!EXP_BEFORE_0
  ## make bytes dependent on each other
  for i in countup(0,seg.high-1,2):
    seg[i] = rotateRightBits(seg[i], (i mod 7))
    var a = seg[i]
    var b = seg[i+1]
    var c = (a and 0b01010101) or (b and 0b10101010)
    var d = (b and 0b01010101) or (a and 0b10101010)
    seg[i] = c
    seg[i+1] = d

  #*................................................



  #*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#* ENCODE
  #*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#* ENCODE
  #*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#* ENCODE
  #*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#* ENCODE
 
  for i in seg.low..seg.high:
    #!EXP_MILL - for heavily repeating content
    seg[i] = rotateRightBits(seg[i], (i mod 7))

    #!EXP_SALT_K2 - some impact, may revise
    seg[i] = seg[i] xor salt_keyTable

    #....
    seg[i] = byBitEnc(seg[i],passw[passCounter].uint8) #!EXP#BY3 - some impact on triplets
    #.
    var pr = rotateRightBits(
      passw[passCounter].uint8, (passCounter mod 7))
    pr = pr + keyTable[keyVariant][keyIterator]
    ## bad on maxByteFails, good on doublefails 74 vs 112, 115889 vs 115613
    seg[i] = (seg[i] xor pr)
    seg[i] += pr
    #.
    ## min impact
    if passCounter < passw.high:
      seg[i] += passw[passCounter+1].uint8
      #.
    passCounter += 1
    if passCounter > passw.high: passCounter = 0

    #....
    seg[i] = seg[i] xor salt_rand #* min impact - need revise
    #seg[i] = seg[i] + (salt_rand xor salt_keyVariant) # old
    seg[i] = seg[i] + (
      salt_rand xor salt_keyVariant.rotateLeftBits(
        keyTable[keyVariant][keyIterator] mod 7)
      ) #!plausible
    #echo salt_keyVariant
    #....
    seg[i] = byBitEnc(seg[i],keyTable[keyVariant][keyIterator]) #!EXP#BY1 small impact
    #!EXP#1
    #+++++
    ## impact on triplets and dous
    case keyTable[keyVariant][keyIterator] and 0b11:
    of 0b00: seg[i] = swapBitsB(seg[i])
    of 0b01: seg[i] = swapBitsC(seg[i])
    of 0b10: seg[i] = swapBitsD(seg[i])
    else: seg[i] = swapBitsA(seg[i])

    #[ if i < 16 :
      echo keyTable[keyVariant][keyIterator] and 0b11 ]#

    #....
    seg[i] = (seg[i] xor keyTable[keyVariant][keyIterator]) #?EXP6
    #....
    seg[i] = seg[i] + othKeyTable[keyVariant][keyIterator] #?EXP5
    #....
    seg[i] = swapBitsE(seg[i]) #?EXP#2
    #....
    seg[i] = byBitEnc(seg[i],othKeyTable[keyVariant][keyIterator]) #!EXP#BY2 *OK*

    #....
    #! salt based on content *OK*
    if i < seg.high:
      seg[i] = (seg[i] xor (seg[i+1] ))
    else:
      seg[i] = (seg[i] xor (seg[seg.low] ))

    #[ if i > 0: # bad on dous, good on maxbytefails
      seg[i] = (seg[i] + seg[i-1])
    else:
      seg[i] = (seg[i] + seg[seg.high]) ]#

    #....

    seg[i] += salt_pass #!EXP7 *OK*  heavy impact

#[     #!EXP_88
    if keyIterator < keyTable[keyVariant].high:
      seg[i] += keyTable[keyVariant][keyIterator+1] ]#


    #**++**++**++**++**++**++**++**++**++**++**++
    keyIterator += 1
    if keyIterator > (KeyLen - 1) and i < seg.high:
      keyIterator = 0

      keyVariant += 1
      if keyVariant > KeyTableRows-1:
        keyVariant = 0
        expandkeyHelper = 0
        makeNewKeyTables(keyTable,othKeyTable,expandkeyHelper,keyExpandMode)#!NEW
        when debug >= 0b1111: echo keyTable[0]

      salt_keyVariant = keyTable[keyVariant][0]
      for c in 1..keyTable[keyVariant].high:
        salt_keyVariant = salt_keyVariant xor keyTable[keyVariant][c]
      for c in 0..othKeyTable[keyVariant].high:
        salt_keyVariant = salt_keyVariant xor othKeyTable[keyVariant][c]

      when debug >= 0b1111: echo "EN: salt_keyVariant ", salt_keyVariant, "...", keyVariant
    #**++**++**++**++**++**++**++**++**++**++**++
  
  #!EXP_AFTER_0
  when debug >= 0b1: echo "ENC: swapping "
  #expandkeyHelper = 0
  let extraTable = makeExtraTables(mxKeyReverse(encKey))
  let extraPositions = getExtraPositions(
      seg.high,
      extraTable[extraTable.high],
      5)
  when debug >= 0b1110:
    echo "ENC: extraPositions: ",extraPositions
  swapBytes(seg, extraPositions[0],0)
  swapBytes(seg, extraPositions[1],seg.high)
  swapBytes(seg, extraPositions[2],extraPositions[5])
  swapBytes(seg, extraPositions[3],extraPositions[4])


  ## TODO res.add(salt_rand xor salt_key1) #! SALT EMBEDDED------------
  when debug >= 0b1: echo "EN: salt k1 ",salt_key1
  when debug >= 0b1: echo "EN: salt_rand ",$salt_rand
  when debug >= 0b1: echo "EN: salt_keyVariant ", salt_keyVariant
  #echo res.toString



  when debug >= 0b1:
    if keyIterator == 0 and keyVariant == 0:
      keyVariant = KeyLen - 1
    echo "EN: keyVariant ",keyVariant
  when debug >= 0b1:
    if keyIterator == 0: keyIterator = KeyTableRows
    echo "EN: keyIterator ",keyIterator - 1
  when debug >= 0b1: echo "EN: key: ",keyTable[keyVariant]
  when debug >= 0b1: echo "EN: expandkeyHelper ", expandkeyHelper
  when debug >= 0b1:
    if passCounter == 0:
      passCounter = passw.len
    echo "EN: passCounter: ", passCounter - 1
  
  when debug >= 0b11111: echo keyTable


  when debug >= 0b1111:
    echo "\n**********************************************"
    echo "ENCODED\n"
    for i in 0..res.high:
      stdout.write fmt"{res[i]:3d} "
      if i mod 16 == 0: echo ""
    for i in 0..res.high:
      stdout.write "\e[48;2;" & $res[i] & ";" & $res[i] & ";" & $res[i] & "m", "  " , "\e[0m"
      if i mod 16 == 0: echo ""

    echo "\n******************************************"


proc encode*(seg: var ByteSeq,
             passw:string,
             salt_rand: uint8,
             preBurn=PreBurn)= #***ENC
  encode(seg,
          passToKey(passw),
          passw,
          salt_rand,
          preBurn)
#*#####################################################################
#*#####################################################################
















#[

 ########  ########
 ##     ## ##
 ##     ## ##
 ##     ## ######   #####
 ##     ## ##
 ##     ## ##
 ########  ########

  ######   #######  ########  ########
 ##    ## ##     ## ##     ## ##
 ##       ##     ## ##     ## ##
 ##       ##     ## ##     ## ######
 ##       ##     ## ##     ## ##
 ##    ## ##     ## ##     ## ##
  ######   #######  ########  ########

 ]#

proc decode*(seg:var ByteSeq,
            encKey:ByteSeq,
            passw:string,
            salt_rand:uint8,
            preBurn=PreBurn,
            oKeyExpandMode:KeyExpandMode = kemAuto)=
  const debug = 0b0

  when debug >= 0b1:
    var t0 = epochTime()

  when debug >= 0b11:
    echo "DE: SEG[] ", seg[seg.low .. seg.low + 4],
      seg[seg.high-4 .. seg.high],
      encKey, passw, salt_rand, "\n"

  var
    keyExpandMode = oKeyExpandMode
    expandkeyHelper = 0
    keyTable: KeyTable # the keytable in use
    othKeyTable: KeyTable # second table derived from keyTable
    keyVariant:int = 0
    keyIterator:int = 0

    salt_keyVariant:uint8 = 0
    salt_key1:uint8 = 0
    salt_keyTable:uint8 = 0

    salt_pass:uint8 = 0

    keyTableCache:seq[KeyTable]
    keyTableCacheIterator:int = 0
    othTableCache:seq[KeyTable]


  #*-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
  when debug >= 0b1: echo "DE: salt_rand ",$salt_rand

  #.......................
  for c in passw:
    salt_pass += c.uint8
  #.......................

  if KeyExpandProc == 128:
    KeyExpandProc = 0
    KeyExpandProc = salt_pass mod 5
    when debug >= 0b111: echo "DEC KeyExpandProc = ", KeyExpandProc
  else:
    when debug >= 0b111: echo "DEC KeyExpandProc = ", KeyExpandProc
    discard

  #*..............................................
  #*.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-

  # .........................

  salt_key1 = encKey[0]
  for c in countup(0,encKey.high,3): #1..encKey.high:
    salt_key1 = salt_key1 xor encKey[c]
  when debug >= 0b11: echo "DE: salt k1 ",$salt_key1

  # .........................

  #!.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-
  #!# calculate cursor positions
  let segLen = (seg.high - seg.low) + 1
  let lastSegLen = segLen mod (KeyTableRows * KeyLen)

  if segLen mod (KeyTableRows * KeyLen) == 0 and segLen > 0:
    when debug >= 0b1: echo "DE:  segLen == KeyTable"
    keyVariant = KeyTableRows - 1
    keyIterator = KeyLen - 1

  elif segLen > (KeyTableRows * KeyLen):
    when debug >= 0b1: echo "DE:  segLen > KeyTable"

    keyVariant = lastSegLen div KeyLen
    if segLen mod KeyLen == 0: keyVariant -= 1

    keyIterator = (lastSegLen mod KeyLen) - 1
    if keyIterator == -1:
      keyIterator = KeyLen - 1

  elif segLen > KeyLen:
    when debug >= 0b1: echo "DE:  segLen > KeyLen"

    keyVariant = segLen div KeyLen
    if segLen mod KeyLen == 0: keyVariant -= 1

    keyIterator = (segLen mod KeyLen) - 1
    if keyIterator == -1:
      keyIterator = KeyLen - 1

  else:
    when debug >= 0b1: echo "DE:  segLen <= KeyLen"
    keyVariant = 0
    keyIterator = segLen - 1

  #keyVariant -= 1
  when debug >= 0b1: echo "DE: keyVariant ",keyVariant
  when debug >= 0b1: echo "DE: keyIterator ",keyIterator


  #!.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-
  #!.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-

  if encKey.len == KeyLen:
    when debug >= 0b10: echo "\tDEC: key from passw "
    keyTable = getKeyTable(encKey,expandkeyHelper)
    othKeyTable = getKeyTable(crawlTable(keyTable),
                              expandkeyHelper)
    if keyExpandMode == kemAuto:
      keyExpandMode = kemRepeat
    #keyExpandMode = kemBlock #!DEBUG
    #keyExpandMode = kemContinuos #!DEBUG

  elif encKey.len == KeyTableRows * KeyLen:
    when debug >= 0b10: echo "\tDEC:  keyTable from key "
    for i in countup(0,encKey.high,KeyLen):
      keyTable.add(encKey[i .. (i + KeyLen - 1)])

    othKeyTable = getKeyTable(crawlTable(keyTable),
                              expandkeyHelper)
    if keyExpandMode == kemAuto:
      keyExpandMode = kemBlock

  elif encKey.len >= 256 and encKey.len mod 16 == 0: #!NEW 
    when debug >= 0b10: echo "\tENC: keyTable from key - password and keytable different source"
    KeyLen = MinKeyLen
    for i in countup(0,encKey.high,KeyLen):
      keyTable.add(encKey[i .. (i + KeyLen - 1)])
    if keyExpandMode == kemAuto:
      keyExpandMode = kemBlock

  else:
    quit("EXCEPTION DE-CODING: argument error, KeyTable error")

  #!.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-
  #!.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-


  salt_keyTable = keyTable[0][0]
  for c in 1..keyTable.high:
    if c mod 2 == 0:
      salt_keyTable -= keyTable[c][0]
    else:
      salt_keyTable = salt_keyTable xor keyTable[c][0]
      salt_keyTable += keyTable[c][0]
  #*..............................................

  if segLen > (KeyTableRows * KeyLen):
    when debug >= 0b11: echo "DE:  goto keyTable "

    case keyExpandMode:
      of kemRepeat,kemAuto:
        discard
        when debug >= 0b11: echo "DE:  kemRepeat "

      of kemContinuos, kemBlock:
        keyTableCache.add(keyTable)
        othTableCache.add(othKeyTable)

        for i in 1 .. (segLen div (KeyTableRows * KeyLen) ):
          expandkeyHelper = 0
          makeNewKeyTables( keyTable,
                            othKeyTable,
                            expandkeyHelper,
                            keyExpandMode)
          keyTableCache.add(keyTable)
          othTableCache.add(othKeyTable)
          keyTableCacheIterator += 1
          when debug >= 0b1111: echo keyTable[0]

    when debug >= 0b1: echo "DE: keyTableCache.len ", keyTableCache.len
    when debug >= 0b11111: echo "DE: ", keyTableCache[keyTableCache.high]

  #[ else:
    othKeyTable = getKeyTable(crawlTable(keyTable),expandkeyHelper)
    when debug >= 0b11: echo "DE: getKeyTable " ]#

  when debug >= 0b1: echo "DE: salt k1 ", salt_key1
  when debug >= 0b1: echo "DE: expandkeyHelper ", expandkeyHelper

  #!PREBURNER............................
  for pbrn in 0..((salt_rand and 0b1111).int + preBurn):
    expandkeyHelper = 0
    makeNewKeyTables( keyTable,
                      othKeyTable,
                      expandkeyHelper,
                      keyExpandMode)
    keyTableCache.add(keyTable)
    othTableCache.add(othKeyTable)
    keyTableCacheIterator += 1


  #*..................................................

  var passCounter = if segLen mod passw.len == 0: passw.high else: segLen mod passw.len - 1
  when debug >= 0b1: echo "DE: passCounter:",passCounter

  #*..................................................


  salt_keyVariant = keyTable[keyVariant][0]
  for c in 1..keyTable[keyVariant].high:
    salt_keyVariant = salt_keyVariant xor keyTable[keyVariant][c]
  for c in 0..othKeyTable[keyVariant].high:
    salt_keyVariant = salt_keyVariant xor othKeyTable[keyVariant][c]

  when debug >= 0b1: echo "DE: salt_keyVariant ", salt_keyVariant, "...",keyVariant
  #..................................
  when debug >= 0b1:
    echo "DE: key begin: ", keyTable[keyVariant]
  #echo keyTable[keyVariant][keyIterator]

  #*..................................... DECODE #!DEC
  #*..................................... DECODE #!DEC
  #*..................................... DECODE #!DEC
  #*..................................... DECODE #!DEC
  #*..................................... DECODE #!DEC
  #*..................................... DECODE #!DEC
  #*..................................... DECODE #!DEC
  #*..................................... DECODE #!DEC

  #!EXP_AFTER_0

  when debug >= 0b1: echo "DEC: swapping "
  let extraTable = makeExtraTables(mxKeyReverse(encKey))
  let extraPositions = getExtraPositions(
      seg.high,
      extraTable[extraTable.high],
      5)
  when debug >= 0b1110:
    echo "DEC: extraPositions: ",extraPositions
  swapBytes(seg, extraPositions[3],extraPositions[4])
  swapBytes(seg, extraPositions[2],extraPositions[5])
  swapBytes(seg, extraPositions[1],seg.high)
  swapBytes(seg, extraPositions[0],0)

  #....

  for i in countdown(seg.high,seg.low):
    #++++++++++++++++++++++++++++++++++++++

#[     #!EXP_88
    if keyIterator < keyTable[keyVariant].high:
      seg[i] -= keyTable[keyVariant][keyIterator+1] ]#


    seg[i] -= salt_pass #!EXP7 *OK* heavy impact

    #....

    #[ if i > 0: # bad on dous, good on maxbytefails
      seg[i] = (seg[i] - seg[i-1])
    else:
      seg[i] = (seg[i] - seg[seg.high]) ]#

    #! salt based on content *OK*
    if i < seg.high:
      seg[i] = (seg[i] xor (seg[i+1] ))
    else:
      seg[i] = (seg[i] xor (seg[seg.low] ))
    #....

    seg[i] = byBitDec(seg[i],othKeyTable[keyVariant][keyIterator]) #!EXP#BY2
    #....
    seg[i] = swapBitsE2(seg[i]) #?EXP#2
    #....
    seg[i] = seg[i] - othKeyTable[keyVariant][keyIterator] #?EXP5
    #....
    seg[i] = (seg[i] xor keyTable[keyVariant][keyIterator]) #?EXP6
    #....

    case keyTable[keyVariant][keyIterator] and 0b11:
    of 0b00: seg[i] = swapBitsB(seg[i])
    of 0b01: seg[i] = swapBitsC(seg[i])
    of 0b10: seg[i] = swapBitsD2(seg[i])
    else: seg[i] = swapBitsA(seg[i])

    #+++++
    #!EXP#1
    seg[i] = byBitDec(seg[i],keyTable[keyVariant][keyIterator]) #!EXP#BY1
    #....
    #seg[i] = seg[i] - (salt_rand xor salt_keyVariant) #old
    seg[i] = seg[i] - (
      salt_rand xor salt_keyVariant.rotateLeftBits(
        keyTable[keyVariant][keyIterator] mod 7)
      ) #!plausible

    seg[i] = seg[i] xor salt_rand #*

    #....
    var pr = rotateRightBits(
      passw[passCounter].uint8, (passCounter mod 7))
    pr = pr + keyTable[keyVariant][keyIterator] #xor 0b01010101

    if passCounter < passw.high:
      seg[i] -= passw[passCounter+1].uint8
      #.
    seg[i] -= pr
    seg[i] = (seg[i] xor pr)
    #.
    seg[i] = byBitDec(seg[i],passw[passCounter].uint8) #!EXP#BY3
    passCounter -= 1
    if passCounter < 0: passCounter = passw.high


    #!EXP_SALT_K2
    seg[i] = seg[i] xor salt_keyTable

    #!EXP_MILL
    seg[i] = rotateLeftBits(seg[i], (i mod 7))

    #**++**++**++**++**++**++**++**++**++**++**++
    keyIterator -= 1
    if keyIterator < 0 and i > 0:
      keyIterator = (KeyLen - 1)

      keyVariant -= 1

      if keyVariant < 0 :
        if keyExpandMode != kemRepeat:
          keyTableCacheIterator -= 1
          shallowCopy(keyTable, keyTableCache[keyTableCacheIterator])
          shallowCopy(othKeyTable, othTableCache[keyTableCacheIterator])

        keyVariant = KeyTableRows-1

      salt_keyVariant = keyTable[keyVariant][0]
      for c in 1..keyTable[keyVariant].high:
        salt_keyVariant = salt_keyVariant xor keyTable[keyVariant][c]
      for c in 0..othKeyTable[keyVariant].high:
        salt_keyVariant = salt_keyVariant xor othKeyTable[keyVariant][c]


    #**++**++**++**++**++**++**++**++**++**++**++
  #!EXP_BEFORE_0
  for i in countup(0,seg.high-1,2):
    var a = seg[i]
    var b = seg[i+1]
    var c = (a and 0b01010101) or (b and 0b10101010)
    var d = (b and 0b01010101) or (a and 0b10101010)
    seg[i] = c
    seg[i+1] = d
    seg[i] = rotateLeftBits(seg[i], (i mod 7))
  #!EXP_BEFORE_1
  #[ var pC = 0
  for i in seg.low..seg.high:
    seg[i] = seg[i] + encKey[pC]
    pC += 1
    if pC > encKey.high: pC = 0 ]#
#[
  pC = encKey.high div 2
  for i in seg.low..seg.high:
    seg[i] = seg[i] - encKey[pC]
    pC += 1
    if pC > encKey.high: pC = 0  ]#
  #....

  when debug >= 0b11:
    echo "ENDE: SEG[] ", seg[seg.low .. seg.low + 4],
      seg[seg.high-4 .. seg.high], "\n"


  when debug >= 0b1:
    echo "ELAPSED: ", formatFloat(epochTime() - t0,ffDefault,2),"sec"




















when isMainModule:
  const KEYATTACK_COMP1 = true

  const passToKeyTest = false
  const passToKeyTestB = false
  const passToKeyTestC = false


  const extratables_fa = false
  const extratables_proc = false

  const keyexpandvisualizer1 = true # needs ANSI compatible terminal
  const keyexpandvisualizer2 = false #
  const keyvisualizer3 = false #
  const keyvisualizer4 = false #

  const keyexpand_freq_an1 = false
  const keyexpand_freq_an2 = false

  const avg_diffusion_test = false
  #const bitciph = false

  const keygenprocgen = false

  const keyexpprocgen = false 
  const keyexpprocgenC = false # used in final

  const pass2keyprocgenRAND_B = false # less preprocess
  const pass2keyprocgenRAND_C = false # +dupfinder # used in final
  const pass2keyprocSelect = false # select the best from pass2keyprocgenRAND results
  const passToKeyTest_2 = false
  #_____________________________________

  include "bitgrinderpkg/ismain.nim"

  #[ 
    max identicals found: 80 : Lacus cubilia urna eget eleifend
total identicals found: 916 in 357492 0.26% 
byte fails: 115054/29614176 0.3885%
max byte fails: 13205 : Finibus Bonorum et Malorum" by Cicero
   ]#