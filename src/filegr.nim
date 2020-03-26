
#[

]#

#[
    used Key values:
      salt_rand = getRand(theKey[8])
      (theKey[theKey.high]):
      (theKey[theKey.high - 1]):
      (theKey[theKey.high - 2]):
      (theKey[theKey.high - 3]):

    used extraTable values:
      outFile.write((salt_rand  xor extraTable[extraTable.high][0]).char)
      for iswap in 0..(extraTable[0][0]).int:
      extraTable[iswap mod KeyTableRows]

    Key and keyTable (word) usage is ambigous.
    keyfile stores keyTable - but they look like ordinary keys...
]#
#_________________________________________________

import bitgrinder
## extend bitgrinderpkg/afterburner with your procs
## so your encryption will be unique!
## but don't forget to save it before pull...
include bitgrinderpkg/afterburner #! <-------- include


#_________________________________________________

import cpuinfo # thread num calculator
import locks
import parseopt
import os
import random
import base64 # key load/save
import strformat, strutils # testBenchmark
import parsecfg # for keyfiles
import streams # for encrypted keys

#_________________________________________________






# SOME UTILITIES:

import times, strutils
template testBenchmark(benchmarkName: string, repeat: int = 1, code: untyped) =
  ## used to run tests more time, for averaging
  block:
    var
      t0, elapsed, tFirst: float
    for i in 1..repeat:
      t0 = epochTime()
      code
      elapsed += epochTime() - t0
      if i == 1: tFirst = elapsed
    elapsed = elapsed / repeat
    let elapsedStr = elapsed.formatFloat(format = ffDecimal, precision = 3)
    echo "CPU Time [", benchmarkName, "] ", elapsedStr, "s"
    echo "First Time [", benchmarkName, "] ", tFirst.formatFloat(format = ffDecimal, precision = 3), "s"


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

    echo days,"d ",hours,":",mins,":",elapsed.formatFloat(format = ffDecimal, precision = 3)
    #echo fmt"CPU Time {days:>4d}d {hours:>2d}:{mins:>2d}:{elapsed:f}"

#*-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-

template benchmark(benchmarkName: string, code: untyped) =
  ## used for verbose outputs
  ## https://forum.nim-lang.org/t/5579#34696
  var
    t0, elapsed: float

  t0 = epochTime()

  code

  elapsed += epochTime() - t0

  if verbosity >= 1:
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
#TODO ?
proc toSafeFileName*(s:string):string=
  result = s
  for c in countdown(s.high,0):
    if s[c] in " ;:?*!§$%&/{}<>=`´|\\\'\"#~": #,()
      result[c] = '_'

    if s[c] in {0x00.chr .. 0x1F.chr}:
      result.delete(c,c)

    if s[c] == 0x7F.chr:
      result.delete(c,c)

#_________________________________________________






## program options________
type
  OperationMode = enum
    opNone,
    opEncodeArgument,
    opEncode,
    opDecode,
    opKey

  AppOptionsObj = object
    ## these variables are needed
    ## in app argument postprocess
    xkeyFileName:string
    xpassword:string
    saveXkey:bool
    saveXkeyFileName:string
    outputFileName:string
    abSeq:seq[int] # run these afterburner procs on buffer



var
  optObj: AppOptionsObj
  optCount:int # if no opts, show help
  tmpStr:string # ephemeral volatile storage
  tmpInt:int # ephemeral volatile storage

  verbosity:int = 0
  operationMode:OperationMode
  arguments: seq[string]
  testAfterEncoding:bool = false

## basic encoding variables______
var
  salt_rand:uint8 # = getRand
  password: string #= "passw0rd"
  theKey: ByteSeq # used to store the key generated from password
                  # or to store the keyTable from keyfile
  keyExpandMode: bitgrinder.KeyExpandMode = kemAuto # passed to encode & makeNewKeyTables
  #keyTableLenRequest:int = 0 # if keyfile specifies num of rows a keytable has
  # extra keytables are used in post-encoding - aka hardening, or afterburner
  extraTable:KeyTable # the original extra-keytable
  chunkExtraTable:KeyTable # used for chunksize calculations
  exV, exH, exKHelper:int # chunkExtraTable cursors

## extended encoding variables_______
var
  # for getChunkSize():
  MaxInputBufferSize = 1024*1024*32 # var, for FUTURE
  MaxChunkSize = 1024 * 8 #max len of a piece of buffer to encode
  ChunkMultiplier = 0 # depends on threadcount and filesize
  numChunks:Natural # count chunks used - good for debugging
  chunkExtraTableExpandHelper:int #STATIC FUNCTION-VARIABLE
  #..............................


  maxThreadCount = countProcessors() - (countProcessors() div 4)

  threadBank = newSeq[Thread[int]](maxThreadCount)
  threadLock = newSeq[Lock](maxThreadCount)
  finishedThreadsCount: int

  inFile, outFile: File
  inFileLock: Lock
  inFileSize: BiggestInt

  numRead: Natural
  writeLock: Lock

  theBuffer = newSeq[uint8](MaxInputBufferSize)
  bufferLock: Lock
  bufferPos:int

## afterburner related

#_________________________________________________




# dont let touch the buffer yet
initLock(bufferLock) #!----------------------

#[
proc dummy(chunk:seq[uint8]):seq[uint8]=
  ## DEBUG
  #[ result = chunk
  os.sleep(100) ]#
  result = chunk
  for i in 0..result.high - 1:
    result[i] = result[i] xor result[i+1]

proc dummy2(inb:var seq[uint8],st,en:int,ke:ByteSeq,pa:string,sa:uint8)=
  ## DEBUG
  var enc = inb[st..en]
  for i in st..en:
    inb[i] = enc[i-st]

 ]#

proc getChunkSize():Natural=
  ## filegrinder encodes files in pseudo-random-length chunks
  ## this proc generates length values from extra keytables

  #result = MaxChunkSize # DEBUG
  numChunks += 1 # DEBUG

  result += chunkExtraTable[exV][exH]
  result += chunkExtraTable[exV][exH+1]
  result += chunkExtraTable[exV][exH+2] #  0.077s 0.057s
  result = result xor chunkExtraTable[exV][exH+3].int # 2.984s  0.088s
  result += salt_rand

  #result = result * 1024 # CPU Time [threaded] 1.830s  0.077s
  result = result * ChunkMultiplier # CPU Time [threaded] 2.411s 0.068s

  if result > MaxChunkSize:
    result = result div 2

  #echo "getChunkSize ", result

  exH += 4
  if exH > chunkExtraTable[0].high:
    exH = 0
    exV += 1
    if exV > chunkExtraTable.high:
      exV = 0
      for ok in 0..chunkExtraTable.high:
        chunkExtraTable[ok][0..chunkExtraTable[0].high] = expandKey(chunkExtraTable[ok],chunkExtraTableExpandHelper)[0..chunkExtraTable[0].high]

#-----------------------------------------------------












#-----------------------------------------------------
#[
##      ##         ######## ##    ##  ######
##  ##  ##         ##       ###   ## ##    ##
##  ##  ##         ##       ####  ## ##
##  ##  ## ####### ######   ## ## ## ##
##  ##  ##         ##       ##  #### ##
##  ##  ##         ##       ##   ### ##    ##
 ###  ###          ######## ##    ##  ######
 ]#
proc encodeWorker(thId:int) {.thread.} =
  const debug = 0b0
  var
    bufferStart, bufferEnd: Natural
    chunkSize:Natural
    extraPositions:seq[int]
    isLastChunk:bool


  os.sleep(0)
  when debug >= 0b11: echo "Thread: ", thId
  {.gcsafe.}:
    while true: #! thread == loop, if break, thread exits
      when debug >= 0b11: echo thId, ": acquire threadLock"
      acquire threadLock[thId] # thread stopping - "wait for start signal"
      acquire bufferLock # only 1 thread reads from to buffer


      if bufferPos == numRead: #?... may never reach this...
        # already finished
        atomicInc finishedThreadsCount
        release bufferLock
        sleep(0)
        when debug >= 0b11: echo "Thread Finished - bufferPos == numRead ",thId

        if finishedThreadsCount == maxThreadCount:
          release(writeLock)

        break #...


      else:  #*...............................................

        bufferStart = bufferPos # start at current buffer cursor position

        chunkSize = getChunkSize()
        when debug >= 0b1: echo chunkSize

        # get bufferEnd
        # and if last chunk of input, then finish and release writeLock
        if bufferPos + chunkSize < numRead - 1: #! not the last chunk
          bufferPos += chunkSize # no need for +1 !
          bufferEnd = bufferPos - 1
          release bufferLock # let others use the buffer - from bufferPos
          sleep(0)
          isLastChunk = false

        else: #! this is the last chunk........................
          bufferPos = numRead
          bufferEnd = numRead - 1
          release bufferLock
          sleep(0)
          chunkSize = bufferEnd - bufferStart
          isLastChunk = true


        #....................................................
        # to pass a chunk, it must be copied :( - enc
        var enc = theBuffer[bufferStart..bufferEnd]
        encode(enc,theKey,password,salt_rand) #!ENC
        #....................................................

        #!chunk-afterburner
        extraPositions = getExtraPositions(
          chunkSize - 1,
          extraTable[ (extraTable[15][0] mod KeyTableRows.uint8) ]
          )
        #echo "extraPositions: ", chunkSize,extraPositions
        swapBytes(enc, extraPositions[0],enc.high)
        swapBytes(enc, extraPositions[1],0)
        swapBytes(enc, extraPositions[2], extraPositions[3])
        swapBytes(enc, extraPositions[4], extraPositions[5])
        #....................................................

        theBuffer[bufferStart..bufferEnd] = enc

        for di in 0..enc.high: enc[di] = 0 #! clean ram
        #....................................................

        when debug >= 0b1111:
                    echo thId,"==ENC==: ",
                      theBuffer[bufferStart..bufferStart+4],") ",
                      theBuffer[bufferEnd-4..bufferEnd],") ",
                      bufferStart,", ",bufferEnd, "\n"

        #....................................................
        if not isLastChunk:
          sleep(0)
          release threadLock[thId]
          sleep(0)

        else:
          #.................................................
          # if last chunk, wait for others, release writelock
          atomicInc finishedThreadsCount

          when debug >= 0b11:
                    echo "finishedThreadsCount ",finishedThreadsCount
                    echo "Thread Finished, End of Buffer ",thId, " bufferEnd: ", bufferEnd

          while finishedThreadsCount < maxThreadCount:
            sleep(1)

          release(writeLock) #!

          break #! EXIT THREAD!
          #! thread remains locked

        #....................................................
        #....................................................

#____________________________________________________









#---------------------------------------------------------
#[

##      ##         ########  ########  ######
##  ##  ##         ##     ## ##       ##    ##
##  ##  ##         ##     ## ##       ##
##  ##  ## ####### ##     ## ######   ##
##  ##  ##         ##     ## ##       ##
##  ##  ##         ##     ## ##       ##    ##
 ###  ###          ########  ########  ######

 ]#
proc decodeWorker(thId:int) {.thread.} =
  const debug = 0b0
  var
    bufferStart, bufferEnd: Natural
    chunkSize:Natural
    extraPositions:seq[int]
    isLastChunk:bool


  os.sleep(0)
  when debug >= 0b11: echo "Thread: ", thId
  {.gcsafe.}:
    while true: #! thread == loop, if break, thread exits
      when debug >= 0b11: echo thId, ": acquire threadLock"
      acquire threadLock[thId]
      acquire bufferLock


      if bufferPos == numRead: #?... may never reach this...
        atomicInc finishedThreadsCount
        release bufferLock
        when debug >= 0b11: echo "@@ Thread Finished ",thId

        if finishedThreadsCount == maxThreadCount:
          release(writeLock)

        break

      else:  #.................................

        bufferStart = bufferPos

        chunkSize = getChunkSize()


        if bufferPos + chunkSize < numRead - 1 :
          bufferPos += chunkSize
          bufferEnd = bufferPos - 1
          release bufferLock
          sleep(0)
        else:
          bufferPos = numRead
          bufferEnd = bufferPos - 1
          release bufferLock
          sleep(0)
          chunkSize = bufferEnd - bufferStart

        when debug >= 0b1111:
                  echo thId,"=DEC IF: ",
                    theBuffer[bufferStart..bufferStart+4],") ",
                    theBuffer[bufferEnd-4..bufferEnd],") ",
                    bufferStart,", ",bufferEnd, " CS: ",chunkSize, "\n"


        #....................................................

        var enc = theBuffer[bufferStart..bufferEnd]

        #....................................................
        extraPositions = getExtraPositions(
          chunkSize - 1,
          extraTable[ (extraTable[15][0] mod KeyTableRows.uint8) ]
          )
        #echo "DEC extraPositions: ", chunkSize,extraPositions
        swapBytes(enc, extraPositions[4], extraPositions[5])
        swapBytes(enc, extraPositions[2], extraPositions[3])
        swapBytes(enc, extraPositions[1],0)
        swapBytes(enc, extraPositions[0],enc.high)
        #....................................................

        decode(enc,theKey,password,salt_rand)

        theBuffer[bufferStart..bufferEnd] = enc
        when debug >= 0b1: echo "-----> ecn: ", enc.toString


        for di in 0..enc.high: enc[di] = 0 #! clear ram

        #....................................................


        when debug >= 0b1111:
                        echo thId," DEC IF: ",
                          theBuffer[bufferStart..bufferStart+4],") ",
                          theBuffer[bufferEnd-4..bufferEnd],") ",
                          bufferStart,", ",bufferEnd, "\n"

        #....................................................
        if not isLastChunk:
          release threadLock[thId]
        else:
          # if last chunk, wait for others, release writelock
          atomicInc finishedThreadsCount

          when debug >= 0b1: echo "Thread Finished, End of Buffer ",thId, " bufferEnd: ", bufferEnd

          while finishedThreadsCount < maxThreadCount:
            sleep(1)
          release(writeLock)
          break
          #! thread remains locked

        #....................................................
        #....................................................
#____________________________________________________




#[

########         ######## ##    ##  ######
##               ##       ###   ## ##    ##
##               ##       ####  ## ##
######   ####### ######   ## ## ## ##
##               ##       ##  #### ##
##               ##       ##   ### ##    ##
##               ######## ##    ##  ######

]#

proc encodeFile(inFileName,
                outFileName: string
                )=
  const debug = 0b0

  when debug >= 0b1:
    echo "\n-------------- encodeFile - Processing ----------------"
  # Reset GLOBAL variables used by Threads
  finishedThreadsCount = 0
  numRead = 0
  bufferPos = 0
  theBuffer.setLen(0)
  chunkExtraTableExpandHelper = 0
  exV = 0
  exH = 0
  numChunks = 0
  #...............................
  when debug >= 0b1:
              echo "pF:[getFreeMem]  ", getFreeMem()
              echo "pF:[getTotalMem] ", getTotalMem()
              echo "pF:[countProcessors] ", countProcessors()
              echo "pF:[maxThreadCount] ", maxThreadCount
              echo "pF:[inFileName] ", inFileName
              echo "pF:[outFileName] ", outFileName


  var
    numWrote: int # debug

  # File open .................................

  initLock(inFileLock)
  try:
    inFile = open(inFileName, fmRead)
  except:
    quit "\nERROR: inFile - cannot open"

  #...........................

  inFileSize = getFileSize(inFileName)
  when debug >= 0b1: echo "pF:[inFileSize] ",inFileSize

  ChunkMultiplier = (inFileSize.int div maxThreadCount div 4096) + 2
  when debug >= 0b1: echo "ChunkMultiplier ", ChunkMultiplier

  #............................

  try:
    outFile = open(outFileName, fmWrite)
  except:
    quit "\nERROR: outFile - cannot open"


  # Init Extra KeyTables ...............................
  extraTable = makeExtraTables(theKey)
  chunkExtraTable = extraTable

  when debug >= 0b1:
          echo "F-ENC.extraTable:      ",extraTable[0][0..4]
          echo "F-ENC.chunkExtraTable: ",chunkExtraTable[0][0..4]
          echo "F-ENC.KEY: ",theKey
          echo "F-ENC.PW:  ",password
          echo "F-ENC.keyExpandMode:  ",keyExpandMode
          echo "F-ENC.keyExpandProc:  ",bitgrinder.KeyExpandProc


  # Init Threads .......................................
  #TODO threads needed? A/B

  when debug >= 0b1: echo "creating Threads"
  #threadBank = newSeq[Thread[int]](maxThreadCount)

  for iT in 0..maxThreadCount-1:
    discard tryAcquire(threadLock[iT]) # may already acquired
    when debug >= 0b1: echo "Createing Encode Threads ", iT
    createThread(threadBank[iT],
                 encodeWorker, iT)
    os.sleep(1)
  when debug >= 0b1: echo "Threads ready"


  #________________________________________

  while not endOfFile(inFile):
    #......
    salt_rand = getRand(theKey[8])
    when debug >= 0b1: echo "SALT_RAND: ",salt_rand

    # Reset buffer..........
    #theBuffer = @[]
    theBuffer = newSeq[uint8](MaxInputBufferSize)

    numRead = inFile.readBytes(theBuffer,0,MaxInputBufferSize)
    when debug >= 0b11: echo "numRead ", numRead

    theBuffer.setLen(numRead) #! its a must for output file

    when debug >= 0b1: echo "/# numRead: ", numRead
    when debug >= 0b1: echo "*** theBuffer: ", theBuffer[0]

    # enable threads .....................
    acquire(writeLock)
    release(bufferLock)
    for iL in 0 .. (maxThreadCount - 1) :
      release(threadLock[iL])
    sleep(0)

    # last thread will release writelock........
    withLock writeLock: #!~~--~~--~~--~~--~~--~~--~~--
      when debug >= 0b1: echo "writing out file"
      if verbosity >= 1 or debug >= 0b1: echo "- number of chunks: ",numChunks

      if verbosity >= 1: echo "- Writing out file"

      outFile.write((salt_rand  xor extraTable[extraTable.high][0]).char) #*NEW


      #!AFTERBURNER_______________________________________

      var extraPositions:seq[int]



      #!SWAP.........................

      if verbosity > 1 or debug >= 0b1: echo "- swapping ",(extraTable[0][0])," times"

      for iswap in 0..(extraTable[0][0]).int:
        var newExtraKey = extraTable[iswap mod KeyTableRows]
        for ni in 0..iswap:
          newExtraKey = mxKeyAlg1(newExtraKey)

        extraPositions = getExtraPositions(numRead - 1,newExtraKey)

        swapBytes(theBuffer, extraPositions[0],(numRead-1))
        swapBytes(theBuffer, extraPositions[1],0)
        swapBytes(theBuffer, extraPositions[2], extraPositions[3])
        swapBytes(theBuffer, extraPositions[4], extraPositions[5])
        swapBytes(theBuffer, extraPositions[6], extraPositions[7])
        when debug >= 0b11: echo extraPositions

      #!EXTRABYTES...................
      # from this point, numRead is not == theBuffer.len !!!

      extraPositions = getExtraPositions(numRead - 1,extraTable[0])

      for ik in 0.uint8 .. (theKey[theKey.high]):
        theBuffer.add(rand(255).uint8)
      for ik in 0.uint8 .. (theKey[theKey.high - 1]):
        theBuffer.insert(rand(255).uint8,extraPositions[0])
      for ik in 0.uint8 .. (theKey[theKey.high - 2]):
        theBuffer.insert(rand(255).uint8,extraPositions[3])
      for ik in 0.uint8 .. (theKey[theKey.high - 3]):
        theBuffer.insert(rand(255).uint8,0)

      when debug >= 0b11:
        stdout.write (theKey[theKey.high]), ", "
        stdout.write (theKey[theKey.high - 1]), ", "
        stdout.write (theKey[theKey.high - 2]), ", "
        echo (theKey[theKey.high - 3])


      #*...............................................

      block:
        for abi in optObj.abSeq:
          afterBurnerProcs[abi](theBuffer, true)

      #*END AFTERBURNER_______________________________________

      numWrote = outFile.writeBytes(theBuffer,0, theBuffer.len)
      when debug >= 0b1: echo "*** outBuffer: ", theBuffer[0]
      when debug >= 0b1: echo "/# numWrote: ", numRead, " ", theBuffer.len


  close(inFile)
  close(outFile)
  inFileLock.deinitLock() #?
  #os.sleep(5)
  #end processFile_________________________





#[

########         ########  ########  ######
##               ##     ## ##       ##    ##
##               ##     ## ##       ##
######   ####### ##     ## ######   ##
##               ##     ## ##       ##
##               ##     ## ##       ##    ##
##               ########  ########  ######

 ]#


proc decodeFile(inFileName: string,
                outFileName: string
                  )=
  const debug = 0b0

  when debug >= 0b1:
    echo "\n------------------------------ Processing"

  when debug >= 0b1:
    echo "pF:[getFreeMem]  ", getFreeMem()
    echo "pF:[getTotalMem] ", getTotalMem()
    echo "pF:[countProcessors] ", countProcessors()
    echo "pF:[maxThreadCount] ", maxThreadCount
    echo "pF:[inFileName] ", inFileName
    echo "pF:[outFileName] ", outFileName

  # Reset GLOBAL variables.........
  finishedThreadsCount = 0
  numRead = 0
  bufferPos = 0
  theBuffer.setLen(0)
  chunkExtraTableExpandHelper = 0
  exV = 0
  exH = 0
  numChunks = 0

  # ...............................
  var
    numWrote: int # debug


  # File open .................................

  initLock(inFileLock)
  try:
    inFile = open(inFileName, fmRead)
  except:
    quit "\nERROR: inFile - cannot open"
  #..........

  inFileSize = getFileSize(inFileName)
  when debug >= 0b1: echo "pF:[inFileSize] ",inFileSize
  #..........

  ChunkMultiplier = (inFileSize.int div maxThreadCount div 4096) + 2
  when debug >= 0b1: echo "ChunkMultiplier ", ChunkMultiplier

  #..........
  try:
    outFile = open(outFileName, fmWrite)
  except:
    quit "\nERROR: outFile - cannot open"


  # Init Extra KeyTables .........................
  when debug >= 0b11: echo ".extraTable:      ",extraTable[0][0..4]

  #extraTable.setLen(0)
  extraTable = makeExtraTables(theKey)
  chunkExtraTable = extraTable
  when debug >= 0b11:
    echo "DEC .extraTable:      ",extraTable[0][0..4]
    echo "DEC .chunkExtraTable: ",chunkExtraTable[0][0..4]
    echo "DEC .KEY: ",theKey
    echo "DEC .PW:  ",password

  # Init Threads ............................
  #TODO threads needed? A/B

  when debug >= 0b11: echo "creating Threads"
  #threadBank = newSeq[Thread[int]](maxThreadCount)
  for iT in 0..maxThreadCount-1:
    discard tryAcquire(threadLock[iT])
    when debug >= 0b1: echo "Createing Decode Threads"
    createThread(threadBank[iT],
                 decodeWorker, iT)
  os.sleep(1)


  #* reset extra keytable - must for decoding -
  #extraTable = makeExtraTables(theKey) #!


  #* Read file to theBuffer .......................
  while not endOfFile(inFile):
    #salt_rand = inFile.readChar.uint8 xor theKey[0] #***
    salt_rand = inFile.readChar.uint8 xor extraTable[extraTable.high][0] #***
    when debug >= 0b1: echo "SALT_RAND: ",salt_rand

    # Reset buffer..........
    #theBuffer = @[]
    theBuffer = newSeq[uint8](MaxInputBufferSize)

    numRead = inFile.readBytes(theBuffer,0,MaxInputBufferSize)
    when debug >= 0b1: echo "DEC numRead = ", numRead

    theBuffer.setLen(numRead) #! must set for extrabytes delete!!!


    #!AFTERBURNER_______________________________________

    block:
      for abi in countdown(optObj.abSeq.high,0):
        afterBurnerProcs[optObj.abSeq[abi]](theBuffer, false)

    #*...............................................


    var extraPositions:seq[int]


    #!EXTRABYTES...................
    # numRead is used to get THE ORIGINAL file size
    when debug >= 0b1: echo "DEC extrabytes"
    numRead -= (theKey[theKey.high - 3])
    numRead -= (theKey[theKey.high - 2])
    numRead -= (theKey[theKey.high - 1])
    numRead -= (theKey[theKey.high])
    numRead -= 4
    when debug >= 0b1: echo "DEC numRead #2 = ", numRead

    #*-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_


    #[ when debug >= 0b1:
      #echo "DEC getExtraPositions"
      var t0 = epochTime() ]#
    extraPositions = getExtraPositions(numRead - 1,extraTable[0])


    when debug >= 0b1: echo "1/5"
    for ik in 0.uint8 .. (theKey[theKey.high - 3]):
      theBuffer.delete(0)
    when debug >= 0b1: echo "2/5"
    for ik in 0.uint8 .. (theKey[theKey.high - 2]):
      theBuffer.delete(extraPositions[3])
    when debug >= 0b1: echo "3/5"
    for ik in 0.uint8 .. (theKey[theKey.high - 1]):
      theBuffer.delete(extraPositions[0])
    when debug >= 0b1: echo "4/5"
    for ik in 0.uint8 .. (theKey[theKey.high]):
      theBuffer.delete(theBuffer.high)

    # at this point assert: numRead == theBuffer.len

    when debug >= 0b1:
      stdout.write (theKey[theKey.high]), ", "
      stdout.write (theKey[theKey.high - 1]), ", "
      stdout.write (theKey[theKey.high - 2]), ", "
      echo (theKey[theKey.high - 3])



    #*...............................................

    #theBuffer.setLen(numRead)

    when debug >= 0b1: echo "/# numRead 3: ", numRead


    #!SWAP.........................
    when debug >= 0b1: echo "- swapping ",(extraTable[0][0])," times"
    for iswap in countdown((extraTable[0][0]).int,0):
      var newExtraKey = extraTable[iswap mod KeyTableRows]
      for ni in 0..iswap:
        newExtraKey = mxKeyAlg1(newExtraKey)

      extraPositions = getExtraPositions(numRead - 1,newExtraKey)

      swapBytes(theBuffer, extraPositions[6], extraPositions[7])
      swapBytes(theBuffer, extraPositions[4], extraPositions[5])
      swapBytes(theBuffer, extraPositions[2], extraPositions[3])
      swapBytes(theBuffer, extraPositions[1],0)
      swapBytes(theBuffer, extraPositions[0],(numRead-1))

    #*END AFTERBURNER_______________________________________



    when debug >= 0b1: echo "*** theBuffer: ", theBuffer[0]

    # enable threads
    acquire(writeLock)  # last Thread will release it
    release(bufferLock) # can Start Threads
    # Start Threads
    for iL in 0 .. (maxThreadCount - 1):
      release(threadLock[iL])
    sleep(0)


    # last thread will release writelock........
    withLock writeLock: #!~~--~~--~~--~~--~~--~~--~~--
      #when debug >= 0b1: echo "writing out file"
      when debug >= 0b1: echo "number of chunks: ",numChunks

      if debug >= 0b1 or verbosity >= 1: echo "- Writing out file"

      numWrote = outFile.writeBytes(theBuffer,0, theBuffer.len)
      when debug >= 0b1: echo "*** outBuffer: ", theBuffer[0]

  #[ when debug >= 0b1:
      echo "DEC benchmark: seconds: ", epochTime() - t0 ]#
  close(inFile)
  close(outFile)
  inFileLock.deinitLock()
  #os.sleep(5)
  #end processFile_________________________



















#[

      ########   ######          ######## ##    ##  ######
      ##     ## ##    ##         ##       ###   ## ##    ##
      ##     ## ##               ##       ####  ## ##
      ########   ######  ####### ######   ## ## ## ##
      ##     ##       ##         ##       ##  #### ##
      ##     ## ##    ##         ##       ##   ### ##    ##
      ########   ######          ######## ##    ##  ######

]#

proc encodeByteSeq(inP: var ByteSeq,
                   outP: var ByteSeq
                )=
  const debug = 0b0

  when debug >= 0b1:
    echo "\n----Processing------------------[encodeByteSeq]"
  # Reset GLOBAL variables
  finishedThreadsCount = 0
  numRead = 0
  bufferPos = 0
  theBuffer.setLen(0)
  chunkExtraTableExpandHelper = 0
  exV = 0
  exH = 0
  numChunks = 0
  #...............................
  when debug >= 0b1:
    echo "pF:[getFreeMem]  ", getFreeMem()
    echo "pF:[getTotalMem] ", getTotalMem()
    echo "pF:[countProcessors] ", countProcessors()
    echo "pF:[maxThreadCount] ", maxThreadCount



  var
    numWrote: int # debug

  # File open .................................

  initLock(inFileLock)
  if inP.len == 0:
    quit("no input data provided!")
  #...........................

  inFileSize = inP.len
  when debug >= 0b1: echo "pF:[inFileSize] ",inFileSize

  ChunkMultiplier = (inFileSize.int div maxThreadCount div 4096) + 2
  when debug >= 0b1: echo "ChunkMultiplier ", ChunkMultiplier

  #............................



  # Init Extra KeyTables ...............................
  extraTable = makeExtraTables(theKey)
  chunkExtraTable = extraTable

  when debug >= 0b1:
    echo "F-ENC.extraTable:      ",extraTable[0][0..4]
    echo "F-ENC.chunkExtraTable: ",chunkExtraTable[0][0..4]
    echo "F-ENC.KEY: ",theKey
    echo "F-ENC.PW:  ",password
    echo "F-ENC.keyExpandMode:  ",keyExpandMode
    echo "F-ENC.keyExpandProc:  ",bitgrinder.KeyExpandProc


  # Init Threads .......................................
  #TODO threads needed? A/B

  when debug >= 0b1: echo "creating Threads"
  #threadBank = newSeq[Thread[int]](maxThreadCount)

  for iT in 0..maxThreadCount-1:
    discard tryAcquire(threadLock[iT])
    when debug >= 0b1: echo "Createing Encode Threads ", iT
    createThread(threadBank[iT],
                    encodeWorker, iT)
    os.sleep(1)
  when debug >= 0b1: echo "Threads ready"


  #________________________________________
  var inPCursor = 0
  while inPCursor < inP.high:
    #......
    salt_rand = inP[inPCursor] xor extraTable[extraTable.high][0] #***

    when debug >= 0b1: echo "SALT_RAND: ",salt_rand

    # Reset buffer..........
    #theBuffer = @[]
    theBuffer = newSeq[uint8](MaxInputBufferSize)


    if inPCursor + (MaxInputBufferSize - 1) <= inP.high:
      theBuffer = inP[inPCursor .. (MaxInputBufferSize - 1)]
      numRead = MaxInputBufferSize
      inPCursor += MaxInputBufferSize
      if inPCursor == 0: inPCursor -= 1
    else:
      theBuffer = inP[inPCursor .. inP.high]
      numRead = (inP.high - inPCursor) + 1 # TODO TEST!!!
      inPCursor = inP.high


    theBuffer.setLen(numRead) #*

    when debug >= 0b1: echo "E numRead: ", numRead
    when debug >= 0b1: echo "*** theBuffer: ", theBuffer[0]

    # enable threads .....................
    acquire(writeLock)
    release(bufferLock)
    for iL in 0 .. (maxThreadCount - 1) :
      release(threadLock[iL])
    sleep(0)

    # last thread will release writelock........
    withLock writeLock: #!~~--~~--~~--~~--~~--~~--~~--
      when debug >= 0b1: echo "writing out buffer"
      when debug >= 0b1: echo "number of chunks: ",numChunks

      if verbosity >= 1: echo "- Writing out buffer"

      #* reset extra keytable - must for decoding -
      #extraTable = makeExtraTables(theKey)

      #outFile.write((salt_rand  xor theKey[0]).char) #***
      outP.add((salt_rand xor extraTable[extraTable.high][0])) #!write salt_rand


      #!AFTERBURNER_______________________________________

      var extraPositions:seq[int]


      #!SWAP.........................
      when debug >= 0b1: echo "- swapping ",(extraTable[0][0])," times"

      for iswap in 0..(extraTable[0][0]).int:
        var newExtraKey = extraTable[iswap mod KeyTableRows]
        for ni in 0..iswap:
          newExtraKey = mxKeyAlg1(newExtraKey)

        extraPositions = getExtraPositions(numRead - 1,newExtraKey)

        swapBytes(theBuffer, extraPositions[0],(numRead-1))
        swapBytes(theBuffer, extraPositions[1],0)
        swapBytes(theBuffer, extraPositions[2], extraPositions[3])
        swapBytes(theBuffer, extraPositions[4], extraPositions[5])
        swapBytes(theBuffer, extraPositions[6], extraPositions[7])

      #!EXTRABYTES...................
      when debug >= 0b1:
        var t0 = epochTime()

      extraPositions = getExtraPositions(numRead - 1,extraTable[0])

      for ik in 0.uint8 .. (theKey[theKey.high]):
        theBuffer.add(rand(255).uint8)
      for ik in 0.uint8 .. (theKey[theKey.high - 1]):
        theBuffer.insert(rand(255).uint8,extraPositions[0])
      for ik in 0.uint8 .. (theKey[theKey.high - 2]):
        theBuffer.insert(rand(255).uint8,extraPositions[3])
      for ik in 0.uint8 .. (theKey[theKey.high - 3]):
        theBuffer.insert(rand(255).uint8,0)

      when debug >= 0b11:
        stdout.write (theKey[theKey.high]), ", "
        stdout.write (theKey[theKey.high - 1]), ", "
        stdout.write (theKey[theKey.high - 2]), ", "
        echo (theKey[theKey.high - 3])

      when debug >= 0b1:
        echo "extrabytes elapsed: ", epochTime() - t0

      #*...............................................

      block:
        for abi in optObj.abSeq:
          afterBurnerProcs[abi](theBuffer, true)

      #*END AFTERBURNER_______________________________________

      outP.add(theBuffer)

      when debug >= 0b1: echo "*** outBuffer: ", theBuffer[0]
      when debug >= 0b1: echo "/# numWrote: ", theBuffer.len



  inFileLock.deinitLock() #?
  #os.sleep(5)
  #end processFile_________________________











#[
      ########   ######          ########  ########  ######
      ##     ## ##    ##         ##     ## ##       ##    ##
      ##     ## ##               ##     ## ##       ##
      ########   ######  ####### ##     ## ######   ##
      ##     ##       ##         ##     ## ##       ##
      ##     ## ##    ##         ##     ## ##       ##    ##
      ########   ######          ########  ########  ######
 ]#
proc decodeByteSeq*(inP: var ByteSeq,
                    outP: var ByteSeq
                   )=
  const debug = 0b0

  when debug >= 0b1:
    echo "\n----Processing------------------[decodeByteSeq]"

  when debug >= 0b1:
    echo "pF:[getFreeMem]  ", getFreeMem()
    echo "pF:[getTotalMem] ", getTotalMem()
    echo "pF:[countProcessors] ", countProcessors()
    echo "pF:[maxThreadCount] ", maxThreadCount

  # Reset GLOBAL variables.........
  finishedThreadsCount = 0
  numRead = 0
  bufferPos = 0
  theBuffer.setLen(0)
  chunkExtraTableExpandHelper = 0
  exV = 0
  exH = 0
  numChunks = 0

  # ...............................
  var
    numWrote: int # debug


  # File open .................................

  initLock(inFileLock)
  if inP.len == 0:
    quit("no input data provided!")

  #..........

  inFileSize = inP.len
  when debug >= 0b1: echo "pF:[inFileSize] ",inFileSize
  #..........

  ChunkMultiplier = (inFileSize.int div maxThreadCount div 4096) + 2
  when debug >= 0b1: echo "ChunkMultiplier ", ChunkMultiplier

  #..........


  # Init Extra KeyTables ...............................
  extraTable = makeExtraTables(theKey)
  chunkExtraTable = extraTable
  when debug >= 0b11: echo ".extraTable:      ",extraTable[0][0..4]

  #extraTable.setLen(0)
  extraTable = makeExtraTables(theKey)
  chunkExtraTable = extraTable

  when debug >= 0b1:
    echo "F-DEC.extraTable:      ",extraTable[0][0..4]
    echo "F-DEC.chunkExtraTable: ",chunkExtraTable[0][0..4]
    echo "F-DEC.KEY: ",theKey
    echo "F-DEC.PW:  ",password
    echo "F-DEC.keyExpandMode:  ",keyExpandMode
    echo "F-DEC.keyExpandProc:  ",bitgrinder.KeyExpandProc

  # Init Threads ............................
  #TODO threads needed? A/B

  when debug >= 0b11: echo "creating Threads"
  #threadBank = newSeq[Thread[int]](maxThreadCount)
  for iT in 0..maxThreadCount-1:
    discard tryAcquire(threadLock[iT])
    when debug >= 0b1: echo "Createing Decode Threads"
    createThread(threadBank[iT],
                 decodeWorker, iT)
    os.sleep(1)
  when debug >= 0b1: echo "Threads ready"


  #* reset extra keytable - must for decoding -
  #extraTable = makeExtraTables(theKey) #!



  #* read to theBuffer .......................
  var inPCursor = 0 # !its the same as numread in fileEncode
  while inPCursor < inP.high:
    salt_rand = inP[inPCursor] xor extraTable[extraTable.high][0] #***
    inPCursor += 1
    when debug >= 0b1: echo "SALT_RAND: ",salt_rand

    # Reset buffer..........
    theBuffer = newSeq[uint8](MaxInputBufferSize)


    if inPCursor + (MaxInputBufferSize - 1) <= inP.high:
      theBuffer = inP[inPCursor .. (MaxInputBufferSize - 1)]
      numRead = MaxInputBufferSize
      inPCursor += MaxInputBufferSize
      if inPCursor == 0: inPCursor -= 1
    else:
      theBuffer = inP[inPCursor .. inP.high]
      numRead = (inP.high - inPCursor) + 1 # TODO TEST!!!
      inPCursor = inP.high


    theBuffer.setLen(numRead) #*


    #!AFTERBURNER_______________________________________

    block:
      for abi in countdown(optObj.abSeq.high,0):
        afterBurnerProcs[optObj.abSeq[abi]](theBuffer, false)

    #*...............................................


    var extraPositions:seq[int]
    when debug >= 0b1: echo "inFileSize ", inFileSize


    #!EXTRABYTES...................
    when debug >= 0b1: echo "DEC extrabytes"
    numRead -= (theKey[theKey.high - 3])
    numRead -= (theKey[theKey.high - 2])
    numRead -= (theKey[theKey.high - 1])
    numRead -= (theKey[theKey.high])
    numRead -= 4
    when debug >= 0b1: echo "DEC numRead #2 = ", numRead

    #*-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_


    when debug >= 0b1:
      #echo "DEC getExtraPositions"
      var t0 = epochTime()
    extraPositions = getExtraPositions(numRead - 1,extraTable[0])


    when debug >= 0b1: echo "1/5"
    for ik in 0.uint8 .. (theKey[theKey.high - 3]):
      theBuffer.delete(0)
    when debug >= 0b1: echo "2/5"
    for ik in 0.uint8 .. (theKey[theKey.high - 2]):
      theBuffer.delete(extraPositions[3])
    when debug >= 0b1: echo "3/5"
    for ik in 0.uint8 .. (theKey[theKey.high - 1]):
      theBuffer.delete(extraPositions[0])
    when debug >= 0b1: echo "4/5"
    for ik in 0.uint8 .. (theKey[theKey.high]):
      theBuffer.delete(theBuffer.high)

    when debug >= 0b1:
      stdout.write (theKey[theKey.high]), ", "
      stdout.write (theKey[theKey.high - 1]), ", "
      stdout.write (theKey[theKey.high - 2]), ", "
      echo (theKey[theKey.high - 3])

    when debug >= 0b1:
     echo "5/5 DEC extrabytes ", epochTime() - t0
    #numRead = theBuffer.len
    #echo "theBuffer.len: ", theBuffer.len
    #*...............................................

    theBuffer.setLen(numRead)

    when debug >= 0b1: echo "/# numRead 3: ", numRead


    #!SWAP.........................
    when debug >= 0b1: echo "- swapping ",(extraTable[0][0])," times"
    for iswap in countdown((extraTable[0][0]).int,0):
      var newExtraKey = extraTable[iswap mod KeyTableRows]
      for ni in 0..iswap:
        newExtraKey = mxKeyAlg1(newExtraKey)

      extraPositions = getExtraPositions(numRead - 1,newExtraKey)

      swapBytes(theBuffer, extraPositions[6], extraPositions[7])
      swapBytes(theBuffer, extraPositions[4], extraPositions[5])
      swapBytes(theBuffer, extraPositions[2], extraPositions[3])
      swapBytes(theBuffer, extraPositions[1],0)
      swapBytes(theBuffer, extraPositions[0],(numRead-1))


    #*END AFTERBURNER_______________________________________

    when debug >= 0b1: echo "*** theBuffer: ", theBuffer[0]

    # enable threads
    acquire(writeLock)  # last Thread will release it
    release(bufferLock) # can Start Threads
    # Start Threads
    for iL in 0 .. (maxThreadCount - 1):
      release(threadLock[iL])
    sleep(0)


    # last thread will release writelock........
    withLock writeLock: #!~~--~~--~~--~~--~~--~~--~~--
      when debug >= 0b1: echo "writing out buffer"
      when debug >= 0b1: echo "number of chunks: ",numChunks

      if verbosity >= 1: echo "~ Writing out buffer"

      outP.add(theBuffer)

      when debug >= 0b1: echo "*** outBuffer: ", theBuffer[0]

  inFileLock.deinitLock()
  #os.sleep(5)
  #end processFile_________________________







#[
  _____  _______  ______ _______ _______      _____   _____  _______
 |_____] |_____| |_____/ |______ |______ ___ |     | |_____]    |
 |       |     | |    \_ ______| |______     |_____| |          |

]#
import times
when isMainModule:
  const debug = 0b0

  proc echoHelp()=
    echo """
Examples:
  |
  | Encoding file(s):
  |   filegr --enc --pass:YourPassWord FileName.ext
  |   filegr -e -p:YourPassWord FileName.ext
  |   filegr -e -p:YourPassWord FileName.ext -o:OutPutFileName.ext
  |   -e, --enc, --encode
  |   -p:<string>, --pass:<string>, --password:<string>
  |
  | Encoding argument(s):
  |   filegr -e -arg Your_Argument_(string)_Here
  |   filegr -e -a Your_Argument_1 Your_Argument_2 ...
  |   filegr -e -arg Your_Argument_(string) -o:OutPutFileName.ext
  | --------------------------------------------------
  |
  | Encoding .xbgk Key file to .exbgk:
  |   filegr -e -p:YourPassWord FileName.xbgk
  | Using .exbgk:
  |   filegr -e -xp:YourPassWord --xkey:THE.exbgk FileName.ext
  |   filegr -d -xp:YourPassWord --xkey:THE.exbgk FileName.ext.enc
  | Saving arguments to .xbgk file:
  |   filegr -e -p:yourpass --sx FileName.ext
  |   filegr -e -p:yourpass --sx:keyFileName FileName.ext
  |___________________________________________________

  |Decoding file(s):
  |  filegr --dec --pass:YourPassWord FileName.ext
  |  filegr -d -p:YourPassWord FileName.ext
  |  -d, --dec, --decode
  |___________________________________________________

Otions:
  | -e, --enc, --encode
  | -d, --dec, --decode
  | -a, --arg
  |   # encode the Arguments as input data
  |   # (else Arguments are file names)

  | -p:<string>, --pass:<string>, --password:<string>
  | -t, --test
  |   # test encoding (decode and compare)

  | -o:<string>, --of:<string>, --outputfile:<string>
  |   # (optional) output file name

  | --pf:<string>, --passwordfile:<string>
  |   # read base64 encoded password from file


  | --pb, --preburn, --pre
  |   # int: pre-expand key n times
  | --abs, afterburners
  |   # abs:0  abs:0,1,2  abs:0,1,0,2
  |   # post process functions - MAKE YOUR OWN .)

  | --kem, --keyexpandmode, --kxm
  |   # <char>: a/r/c/b
  |   # a: auto = repeat or block
  |   # r: repeat keytable
  |   # c: continous = generate new row from last row
  |   # b: block: new keytable from all the rows
  | --kxp, --exp, --kp, --kep, --expproc, --keyexpandproc
  |   # <uint8> [0..4]
  | --ktr, --keytablerows, --tr
  |   # <uint>

  | --sx, --savekey, --xs, --sk
  |   # save options to .xbgk keyfile
  |   # optional: <filename> --sx:fileName
  | --xp, --xpass, --xpassword
  |   # use with xs to create encrypted key, .exbgk file

  | --xkey
  |   # load .xbgk file with numerous options
  |   # (key,password,preburn,expander-proc,
  |   #  expander-mode,keytable-rows)
  |   # . . . . . . . . . . . . . . . . . . . . . . . .
  | -k --key
  |   # load key(table) from .bgk file
  |
  | --newkey
  |   # create "new.xbgk" key-template file
  |
  | --krn
  |   # convert an ascii file of numbers (0-255)
  |   # .bgkrn to .bkg key (base64 encoded)


  | -v:<0-2>, --verbosity:<0-2>
  |   # 0-2 : more output
  | -v, --verbose
  |   # equals to -v:2
  | -q
  |   # quiet - opposite of verbose - no output, v:0

Notes:
  | if keyTable is provided through key,
  |  the remainder: key(Table) mod KeyTableRows
  |  must be zero 0 !
  |  and key(Table) div KeyTableRows >= 16 is required!
  | if --ktr used with --key and --password,
  |  that can cause such problems

  | .exbgk file overrides --kxp option, if set.
"""


  var p = initOptParser()
  while true:
    p.next()
    case p.kind
      #________________________
      of cmdEnd: break
      #________________________
      of cmdShortOption, cmdLongOption:#!------------------
        optCount += 1 #!

        # normailze input case
        p.key = toLowerAscii(p.key)
        p.val = toLowerAscii(p.val)

        when debug >= 0b1:
          if p.val == "":
            echo "Option: ", p.key
          else:
            echo "Option and value: ", p.key, ", ", p.val

        #...................................................


        case p.key: #!---------------------------------------
        #of "g","gpio":
        #  discard
        of "h","help": echoHelp()
        #------------------------------------------------
        of "v","verbosity":
          if p.val == "":
            verbosity = 2
          else:
              try:
                verbosity = p.val.parseInt()
                if verbosity > 2: verbosity = 2
              except: discard

        of "q","quiet":
          verbosity = 0

        of "verbose":
          verbosity = 2

        #------------------------------------------------

        of "e","enc","encode":
          operationMode = opEncode

        of "t","test":
          testAfterEncoding = true

        of "d","dec","decode":
          operationMode = opDecode

        of "a","arg":
          operationMode = opEncodeArgument

        #------------------------------------------------

        of "o","of","outputfilename":
          if p.val != "":
            optObj.outputFileName = p.val
            #optObj.outputFileName = optObj.outputFileName.toSafeFileName()


        #------------------------------------------------

        of "p","pass","password":
          when debug >= 0b11: echo p.val

          if verbosity >= 1:
            if password.len > 0: echo "- changing password from key"

          if p.val.len < 4:
            quit("ERROR: PASSWORD TOO SMALL")

          password = p.val


        of "pb", "preburn", "pre": # int :)
          if p.val != "":
            try:
              tmpInt = p.val.parseInt()
              if tmpInt > 0:
                bitgrinder.PreBurn = tmpInt
              if verbosity > 0 and bitgrinder.PreBurn > 0:
                echo "- Key-Preburn: " & $bitgrinder.PreBurn
              else:
                echo "- Key-Preburn: auto"
            except: discard


        of "kxm", "keyexpandmode", "kem":
          case p.val:
            of "r","repeat":
              keyExpandMode = kemRepeat
              if verbosity > 0: echo "- Key-Expand Mode: repeat"
            of "b", "block":
              keyExpandMode = kemBlock
              if verbosity > 0: echo "- Key-Expand Mode: block"
            of "c", "continous":
              keyExpandMode = kemContinuos
              if verbosity > 0: echo "- Key-Expand Mode: continous"
            else:
              keyExpandMode = kemAuto
              if verbosity > 0: echo "WARNING: key expand proc not defined, usin auto"


        of "kxp", "keyexpandproc","kep","kp", "expproc", "exp":
          if p.val != "":
            try:
              tmpInt = p.val.parseInt()
              if tmpInt >= 0 and tmpInt <= 4:
                bitgrinder.KeyExpandProc = tmpInt.uint8
              else:
                bitgrinder.KeyExpandProc = 0

              if verbosity > 0 and bitgrinder.KeyExpandProc == 0.uint8:
                echo "- Key-Key-Expand Proc: auto"
              else:
                echo "- Key-Expand Proc: " & $bitgrinder.KeyExpandProc
            except: discard


        of "ktr", "keytablerows", "tr":
          if p.val != "":
            try:
              tmpInt = p.val.parseInt()
              if tmpInt > bitgrinder.MinKeyTableRows:
                bitgrinder.KeyTableRows = tmpInt
              if verbosity > 0: echo "- KeyTableRows: ", bitgrinder.KeyTableRows
            except: discard


        of "abs", "afterburners":
          if p.val != "":
            if p.val.find(",") >= 0:
              var abs = split(p.val,",")
              for ab in abs:
                try:
                  tmpInt = ab.parseInt
                  if tmpInt >= 0 and tmpInt <= afterBurnerProcs.high:
                    optObj.abSeq.add(tmpInt)
                except:
                  quit("ERROR: malformed afterburner option!")
            else:
              try:
                tmpInt = p.val.parseInt
                if tmpInt >= 0 and tmpInt <= afterBurnerProcs.high:
                  optObj.abSeq.add(tmpInt)
              except:
                quit("ERROR: malformed afterburner option!")

        #------------------------------------------------


        of "xp","xpass","xpassword":
          if p.val.len < 4:
            quit("ERROR: KEY's PASSWORD TOO SMALL")
          optObj.xpassword = p.val


        of "sx","savekey", "xs", "sk":
          optObj.saveXkey = true
          if p.val != "": optObj.saveXkeyFileName = p.val

        #------------------------------------------------




        of "xkey", "xbgk", "exbgk":# --xkey:<string>.bgkx
          optObj.xkeyFileName = p.val
          echo optObj.xkeyFileName
        #------------------------------------------------




        of "key","k":# --key:<fileName>  -------
          ## .bgk key: a seq[uint8] len >= 256
          when debug >= 0b11: echo "of -k --key"

          var
            bgkFile: File
            b64:string
          
          if verbosity > 0: echo "- looking for keyfile"

          try:
                # pre check:..................
            if not existsFile(p.val):
              if verbosity > 0: echo "- searching for keyfile"
              if existsFile(getConfigDir() & "bitgrinder" & os.DirSep & p.val):
                 bgkFile = open(getConfigDir() & "bitgrinder" & os.DirSep & p.val)
              elif existsFile(getHomeDir() & "bitgrinder" & os.DirSep & p.val):
                 bgkFile = open(getHomeDir() & "bitgrinder" & os.DirSep & p.val)
              else:
                quit("ERROR: key file not found")
            else:    
              bgkFile = open(p.val,fmRead)

            b64 = $readAll(bgkFile)
            b64.stripLineEnd()
            theKey = base64.decode(b64).toByteSeq

            if theKey.len < 256: # ASSERTION
              quit("ERROR: KEY TOO SMALL : " & $theKey.len)

            if password.len == 0:
              password = b64[0..15]
              bitgrinder.KeyLen = 16

          except:
            echo getCurrentExceptionMsg()



        of "pf","passwordfile":# --pf:<fileName>  -------
          ## .bgk key: a seq[uint8] len >= 256
          when debug >= 0b11: echo "of --pf --passwordfile"

          var
            pwFile: File
            b64:string

          try:
            pwFile = open(p.val,fmRead)

            b64 = $readAll(pwFile)
            b64.stripLineEnd()
            password = base64.decode(b64)
            if password.len < 4: # ASSERTION
              quit("ERROR: PASSWORD TOO SMALL : " & $theKey.len)


          except:
            echo getCurrentExceptionMsg()


        #------------------------------------------------



        of "newkey":
          ## make a "skeleton-key"
          operationMode = opKey
          var xbgk:File
          try:
            if p.val == "":
              xbgk = open("new.xbgk", fmWrite)
            else:
              xbgk = open(p.val, fmWrite)
            xbgk.writeLine("#key = \"copy HERE the result of: openssl rand -base64 256\"")
            xbgk.writeLine("#password = \"type your password HERE\"")
            xbgk.writeLine("#preburn = 42 # integer 0 - 255: expand the key N times before start")
            xbgk.writeLine("#expproc = 0 # integer 0 - 4 : currently 5 different modes supported")
            xbgk.writeLine("#expmode = \"repeat/block/continous or r/b/c\" ")
            xbgk.writeLine("#keytablerows = 16 # min 16! ")

            xbgk.writeLine("#..................................................")
            xbgk.writeLine("# Encoding .xbgk Key file to .exbgk:")
            xbgk.writeLine("#  filegr -e -p:YourPassWord FileName.xbgk")
            xbgk.writeLine("# Using .exbgk:")
            xbgk.writeLine("#  filegr -e -p:YourPassWord --xkey:THE.exbgk FileName.ext")
            xbgk.writeLine("#  filegr -d -p:YourPassWord --xkey:THE.exbgk FileName.ext.enc")
          except:
            echo getCurrentExceptionMsg()
            quit("ERROR: creating new keyfile")
        #------------------------------------------------




        of "krn":# -------  krn:test.bgkrn  -------
          ## random numbers in .txt file format
          ## eg. from random.org saved as file
          ## separator: new line
          operationMode = opKey
          when debug >= 0b11:
            echo "of --krn:<string>.bgkrn"
            echo "generate .bgk from .bgkrn file"
          var
            krnf: File
            line:string
            b64:string
          try:
            krnf = open(p.val,fmRead)
          except:
            echo getCurrentExceptionMsg()

          while krnf.readLine(line):
            #echo line
            theKey.add(parseInt(line.strip()).uint8)
            #discard
          krnf.close()

        # ___________________________________________



      of cmdArgument:#!-----------------------------------
        when debug >= 0b1: echo "Argument: ", p.key

        arguments.add(p.key)
      #!__________________________________________________








  #*********************
  if optCount == 0:
    echoHelp()
    quit()
  #*********************








#!_ __ ___ __ _ __ ___ __  _  __  ___  _______   _________ __ _
#!_ __ ___ __ _ __ ___ __  _  __  ___  _______   _________ __ _
#!                    _
#!    _ __   ___  ___| |_ _ __  _ __ ___   ___ ___  ___ ___
#!   | '_ \ / _ \/ __| __| '_ \| '__/ _ \ / __/ _ \/ __/ __|
#!   | |_) | (_) \__ \ |_| |_) | | | (_) | (_|  __/\__ \__ \
#!   | .__/ \___/|___/\__| .__/|_|  \___/ \___\___||___/___/
#!   |_|                 |_|
#!        config
#!_ __ ___ __ _ __ ___ __  _  __  ___  _______   _________ __ _
#!_ __ ___ __ _ __ ___ __  _  __  ___  _______   _________ __ _


  if password.len == 0 and theKey.len == 0 and optObj.xkeyFileName.len == 0 and
    (operationMode == opEncode or operationMode == opDecode):
      echo getConfigDir() & "bitgrinder" & os.DirSep & "bitgrinder.exbgk"
      if existsFile(getConfigDir() & "bitgrinder" & os.DirSep & "bitgrinder.exbgk"):
        optObj.xkeyFileName = getConfigDir() & "bitgrinder" & os.DirSep & "bitgrinder.exbgk"
      elif existsFile(getConfigDir() & "bitgrinder" & os.DirSep & "bitgrinder.xbgk"):
        optObj.xkeyFileName = getConfigDir() & "bitgrinder" & os.DirSep & "bitgrinder.xbgk"
  # post proces arguments................................

#*          _  __                       _  __
#*    __  _| |/ /___ _   _     _____  _| |/ /___ _   _
#*    \ \/ / ' // _ \ | | |   / _ \ \/ / ' // _ \ | | |
#*     >  <| . \  __/ |_| |  |  __/>  <| . \  __/ |_| |
#*    /_/\_\_|\_\___|\__, |   \___/_/\_\_|\_\___|\__, |
#*                   |___/                       |___/

  if optObj.xkeyFileName.len > 0:
    ## .xbgk eXtendedKey: ini file containing
    ## options for en/decryption
    when debug >= 0b1: echo "using --xkey"
    when debug >= 0b11: echo "getConfigDir ", getConfigDir() & "bitgrinder" & os.DirSep
    when debug >= 0b11: echo "getHomeDir ", getHomeDir()


    var
      b64:string

    # pre check:..................
    if not existsFile(optObj.xkeyFileName):
      if existsFile(getConfigDir() & "bitgrinder" & os.DirSep & optObj.xkeyFileName):
        optObj.xkeyFileName = getConfigDir() & "bitgrinder" & os.DirSep & optObj.xkeyFileName
      elif existsFile(getHomeDir() & "bitgrinder" & os.DirSep & optObj.xkeyFileName):
        optObj.xkeyFileName = getHomeDir() & "bitgrinder" & os.DirSep & optObj.xkeyFileName
      else:
        quit(".xbgk .exbgk key file not found")
    #..........................


    var dict:Config #* <===============================

    #[      if
            _______ _     _ _     _ _______ __   __
            |______  \___/  |____/  |______   \_/
            |______ _/   \_ |    \_ |______    |
    ]#

    if optObj.xkeyFileName[optObj.xkeyFileName.len - 5 .. optObj.xkeyFileName.len - 1] == "exbgk" or
      optObj.xkeyFileName[optObj.xkeyFileName.len - 8 .. optObj.xkeyFileName.len - 1] == "xbgk.enc":
        var
          exbgkF: File
          exbgBS:ByteSeq
          xbgBS:ByteSeq

        if verbosity >= 1 or debug >= 0b1:
          echo "~ Decoding encrypted key"

        if optObj.xpassword.len == 0:
          quit("ERROR: password not set! - Decoding Encrypted Key")

        #load keyfile
        try:
          exbgkF = open(optObj.xkeyFileName,fmRead)
          exbgBS = readAll(exbgkF).toByteSeq
          exbgkF.close()
        except:
          echo getCurrentExceptionMsg()

        #...........................
        #! encoding threads are using global variables
        #! following sections will override!
        password = optObj.xpassword
        theKey = passToKey(password)

        bitgrinder.KeyExpandProc = 0
        for c in password:
          bitgrinder.KeyExpandProc += c.uint8
        bitgrinder.KeyExpandProc = bitgrinder.KeyExpandProc mod 5
        #...........................
        decodeByteSeq(exbgBS, xbgBS)
        when debug >= 0b11: echo xbgBS.toString
        #...........................

        dict = loadConfig(xbgBS.toString.newStringStream) #!
        when debug >= 0b11: echo xbgBS.toString
        #...........................
        # Cleaning...
        for di in 0 .. exbgBS.high: exbgBS[di] = 0
        for di in 0 .. xbgBS.high: xbgBS[di] = 0
        GC_unref(exbgBS)
        GC_unref(xbgBS)

        # reset needed to work!!!
        theKey = @[]
        password = ""
        #...........................
    else: # simple .xbgk file
      dict = loadConfig(optObj.xkeyFileName) #!
      when debug >= 0b11: echo "file"


    #*:.......................................
    #*: keyfile decrypted
    #*: config loaded,
    #*: continue processing


    try: #. . . . . . . . . . . . . . .
      tmpInt = dict.getSectionValue("","keytablerows").parseInt
      if tmpInt > MinKeyTableRows:
        #keyTableLenRequest = tmpInt
        bitgrinder.KeyTableRows = tmpInt
      #else:
      #  keyTableLenRequest = MinKeyTableRows
    except:
      discard
      #keyTableLenRequest = MinKeyTableRows #!!!

    try: #. . . . . . . . . . . . . . .
      b64 = dict.getSectionValue("","key")
      b64.stripLineEnd()
      if b64 != "":
        theKey = base64.decode(b64).toByteSeq
        if theKey.len mod bitgrinder.KeyTableRows != 0:
          quit("ERROR: key length cannot be divided by KeyTableRows !")
        else:
          bitgrinder.KeyLen = theKey.len div bitgrinder.KeyTableRows
          if bitgrinder.KeyLen == 0:
            quit("ERROR: key length is zero !")
        if verbosity > 0:
            echo "- got the key"
      else:
        echo "- no valid key found"
    except:
      quit("ERROR: key cannot be read! " & getCurrentExceptionMsg())

    #. . . . . . . . . . . . . . .
    if not (password.len >= 4): # -p may override this
      try:
        password = dict.getSectionValue("","password")
        when debug >= 0b11: echo password
        if password.len == 0 and theKey.len > 0:
          if verbosity > 0:
            echo "Generating password from key"

          if b64.len >= 16:
            password = b64[0..15]
          else:
            password = b64
        elif password.len == 0:
          quit("ERROR: key or password needed!")

      except:
        if theKey.len == 0:
          quit("ERROR: password cannot be read!")



    try: #. . . . . . . . . . . . . . .
      if bitgrinder.PreBurn == 0: # option may override keyfile
        tmpInt = dict.getSectionValue("","preburn").parseInt()
        bitgrinder.PreBurn = tmpInt
    except: discard

    try: #. . . . . . . . . . . . . . .
      tmpInt = dict.getSectionValue("","expproc").parseInt()
      bitgrinder.KeyExpandProc = tmpInt.uint8
      when debug >= 0b11: echo bitgrinder.KeyExpandProc
    except: discard

    try: #. . . . . . . . . . . . . . .
      tmpStr = dict.getSectionValue("","expmode")
      case tmpStr:
      of "r","repeat":
        keyExpandMode = kemRepeat
      of "b", "block":
        keyExpandMode = kemBlock
      of "c", "continous":
        keyExpandMode = kemContinuos
      else:
        keyExpandMode = kemAuto

    except:
      quit("ERROR: key expand MODE unclear [valid: 'r' / 'b' / 'c']")

  #___________________________________________


  #*_END PARSEOPT__________________________________




  #[

        ########  ##     ## ##    ##    ##
        ##     ## ##     ## ###   ##     ##
        ##     ## ##     ## ####  ##      ##
        ########  ##     ## ## ## ##       ##
        ##   ##   ##     ## ##  ####      ##
        ##    ##  ##     ## ##   ###     ##
        ##     ##  #######  ##    ##    ##

  ]#


  ## pre run checks
  if (operationMode == opEncode or
      operationMode == opDecode or
      operationMode == opEncodeArgument):

    ## KeyExpandProc MUST be calculated!
    ## file chunking and extratables are
    ## relaying on keyexpand proc, and
    ## keyExpandProc is calculated from the password
    when debug >= 0b1: echo "- CHECK password: ", password

    if bitgrinder.KeyExpandProc == 128:
      if password.len > 0:
        bitgrinder.KeyExpandProc = 0
        if verbosity >= 1: echo "- CALCULATING KeyExpandProc"

        for c in password:
          bitgrinder.KeyExpandProc += c.uint8

        bitgrinder.KeyExpandProc = bitgrinder.KeyExpandProc mod 5

      else:
        quit("ERROR CALCULATING KeyExpandProc: password not set!")

    if verbosity > 0: echo "- Key Expand Prroc #: ", bitgrinder.KeyExpandProc
    #..................................

    if theKey.len == 0:
      if verbosity > 0: echo "- CALCULATING THE KEY"
      theKey = passToKey(password)
    elif theKey.len mod bitgrinder.KeyTableRows != 0:
      quit("ERROR: key length cannot be divided by KeyTableRows !")
    elif theKey.len div bitgrinder.KeyTableRows < 16:
      quit("ERROR: key-row length < 16 ! \n" &
      "(Key length / KeyTableRows < 16)" )

    #..................................




  #*                           _
  #*     ___  __ ___   _____  | | _____ _   _
  #*    / __|/ _` \ \ / / _ \ | |/ / _ \ | | |
  #*    \__ \ (_| |\ V /  __/ |   <  __/ |_| |
  #*    |___/\__,_| \_/ \___| |_|\_\___|\__, |
  #*                                    |___/
  #*

  if optObj.saveXkey and optObj.saveXkeyFileName == "":
    ## save the key in filename.xbgk file
    ## filename is the first filename if more given
    optObj.saveXkeyFileName = (arguments[0][0 .. arguments[0].rfind(".")-1] & ".xbgk").toLowerAscii()
  elif optObj.saveXkey and optObj.saveXkeyFileName != "":
    ## fileName provided as option
    if optObj.saveXkeyFileName.rfind(".xbgk") == -1 and
       optObj.saveXkeyFileName.rfind(".exbgk") == -1:
        optObj.saveXkeyFileName = optObj.saveXkeyFileName & ".xbgk"
  # fileName set, lets write data
  if optObj.saveXkey:
    when debug >= 0b1: echo optObj.saveXkeyFileName
    var
      outKeyFile: File

    try:
      outKeyFile = open(optObj.saveXkeyFileName,fmWrite)

      if theKey.len >= 256:
        outKeyFile.writeLine("key = \"" & base64.encode(theKey) & "\"")
      outKeyFile.writeLine("password = \"" & password & "\"")
      outKeyFile.writeLine("preburn = " & $bitgrinder.PreBurn)
      outKeyFile.writeLine("expproc = " & $bitgrinder.KeyExpandProc & "")
      case keyExpandMode:
        of kemAuto: outKeyFile.writeLine("expmode = \"a\"")
        of kemRepeat: outKeyFile.writeLine("expmode = \"r\"")
        of kemBlock: outKeyFile.writeLine("expmode = \"b\"")
        of kemContinuos: outKeyFile.writeLine("expmode = \"c\"")
      outKeyFile.writeLine("keytablerows = " & $bitgrinder.KeyTableRows)
      #..................
      outKeyFile.close() #!
    except:
      echo getCurrentExceptionMsg()
      quit("ERROR: creating output key file")


    #**** if key encryption is requested - xpass option set:
    if optObj.xpassword != "":
      # filegr executable must be in path.
      # if not, manual encoding is needed
      if os.execShellCmd("filegr -q -e -p:" & optObj.xpassword & " " & optObj.saveXkeyFileName) == 0:
          outKeyFile = open(optObj.saveXkeyFileName,fmReadWrite)
          outKeyFile.write('z'.repeat(getFileSize(optObj.saveXkeyFileName)))
          outKeyFile.close()
          try:
            os.removeFile(optObj.saveXkeyFileName)
          except:
            echo "ERROR: unencrypted keyfile cannot be removed: ", optObj.saveXkeyFileName
      else:
        echo "\nERROR filegr executable cannot be found - not in PATH!\nPlease encode it manually eg: filegr -e -p:password " & optObj.saveXkeyFileName







  #__________________________________________________________

  if verbosity > 0: echo "- operation mode :", $operationMode
  case operationMode:
  of opNone:
    discard

  of opKey:
    discard
    #.............................................



  of opEncodeArgument:
    if arguments.len == 0:
      quit("ERROR: no arguments to encode (?)")
    if password.len == 0 and theKey.len == 0:
      quit("ERROR: password or key needed!")

    for ai in 0..arguments.high:
      block:
        var
          outFileName: string
          cTime = now()
          fileCount = ai
          outBS:ByteSeq
          inBS:ByteSeq


        if optObj.outputFileName.len > 0:
          outFileName = "(" & $ai & ")" & optObj.outputFileName
        else:
          outFileName = &"bgrenc_{cTime.year}-{cTime.hour}-{cTime.minute}-{cTime.second}_"
          while true:
            if not fileExists(outFileName & $fileCount & ".enc"): break
            fileCount += 1
          outFileName = outFileName & $fileCount & ".enc"

        if verbosity >= 1: echo "- Encoding to \"",outFileName,"\""
        benchmark "Encoding":
          inBS = arguments[ai].toByteSeq
          encodeByteSeq(inBS, outBS)
          outFile = open(outFileName, fmWrite)
          discard outFile.writeBytes(outBS, 0, outBS.len)
          outFile.close()
        if verbosity > 0: echo "- numChunks :", numChunks


        #.......................
        if testAfterEncoding:
          if verbosity >= 1: echo "- Testing \"",outFileName,"\""
          benchmark "Decoding":
            inBS = @[]
            decodeByteSeq(outBS, inBS)

          if not (inBS == arguments[ai].toByteSeq):
            #echo inBS.toString
            #echo arguments[ai]
            quit("!!! Testing decoding failed !!!")
          if verbosity >= 1: echo "- Decode test succesfull :)"
          #.......................


        if verbosity >= 1: echo "- Cleanup..."
        # cleanup mess:
        for di in 0..inBS.high: inBS[di] = 0
        for di in 0..arguments[ai].high: arguments[ai][di] = ' '
        for di in 0..outBS.high: outBS[di] = 0

        #.......................

    #.............................................




  of opEncode:
    var outFileName:string
    if arguments.len == 0:
      quit("ERROR: no arguments (files) to encode (?)")
    if password.len == 0 and theKey.len == 0:
      quit("ERROR: password or key needed!")

    for file in arguments:#* <---------------- LOOP
      if fileExists(file):
        # if output file exists - add number before filename
        if optObj.outputFileName.len > 0:
          if arguments.len > 1:
            var fileCount:int
            if existsFile(optObj.outputFileName):
              while true:
                if not fileExists("(" & $fileCount & ")" & optObj.outputFileName): break
                fileCount += 1
              outFileName = "(" & $fileCount & ")" & optObj.outputFileName
            else:
              outFileName = optObj.outputFileName
          else:
            outFileName = optObj.outputFileName

        else: # if no filename given as option <-----
            if file.find(".xbgk") != -1: # if keyfile nedded to encode
              outFileName = file[0 .. file.find(".xbgk")-1] & ".exbgk"
            else:
              outFileName = file & ".enc" # normal file to encode .enc extension

        if verbosity >= 1: echo "- Encoding '",file,"' to '",outFileName,"'"

        benchmark "Encoding":
          encodeFile(file, outFileName)
        #if verbosity > 0: echo "- numChunks :", numChunks


        #.........................................
        #...........testAfterEncoding.............
        if testAfterEncoding:
          if verbosity >= 1: echo "- Testing \"",outFileName,"\""
          benchmark "Decoding": decodeFile(outFileName, file & ".dec")
          var
            testFileA = open(file, fmRead)
            testFileB = open(file & ".dec", fmRead)
            testBufferA = newSeq[uint8](1024*1024)
            testBufferB = newSeq[uint8](1024*1024)

          if getFileSize(file) != getFileSize(file & ".dec"):
            echo "!!! Testing encoding failed !!! filesizes are different"
          else:
            while not endOfFile(testFileA):
              discard testFileA.readBytes(testBufferA,0,(1024*1024))
              discard testFileB.readBytes(testBufferB,0,(1024*1024))

              if testBufferA != testBufferB:
                testFileA.close()
                testFileB.close()
                echo("!!! Testing decoding failed !!!")
                break
            if verbosity >= 1: echo "- Decode test succesfull :)"

          #.....................................
          if verbosity >= 1: echo "- Cleanup..."
          # cleanup mess:
          testFileB = open(file & ".dec", fmReadWriteExisting)
          testBufferB.newSeq((1024*1024))

          while numRead < getFileSize(file & ".dec"):
            if getFileSize(file & ".dec") - numRead > 1024*1024:
              numRead += testFileB.writeBytes(testBufferB,0,(1024*1024))
            else:
              numRead += testFileB.writeBytes(testBufferB,0,(getFileSize(file & ".dec") - numRead))
          removeFile(file & ".dec")
          #.................

      else:
        if verbosity >= 1: echo "! ERROR: \"",file,"\" not found!"


    #.............................................



  of opDecode:
    if arguments.len == 0:
      quit("ERROR: no arguments (files) to decode (?)")
    if password.len == 0 and theKey.len == 0:
      quit("ERROR: password or key needed!")

    for file in arguments:
      if fileExists(file):
        if verbosity >= 1: echo "- Decoding \"",file,"\""
        benchmark "Decoding":
          var decFileName:string
          if file.find(".enc") != -1:
            decFileName = file[0 .. (file.find(".enc") - 1)]
          if fileExists(decFileName):
            decFileName = decFileName & ".dec"
          if verbosity > 0: echo "- Decoding to ", decFileName

          decodeFile(file, decFileName)
        #.................
      else:
        if verbosity >= 1: echo "! ERROR: \"",file,"\" not found!"
    #.............................................
  #_______________________________________________

  when debug >= 0b1:
    echo "password length: ", password.len, " ", password
    echo "KeyExpand Proc num: ", bitgrinder.KeyExpandProc
    echo "keyTable PreBurn: ",bitgrinder.PreBurn
    echo "KeyTableRows: ", bitgrinder.KeyTableRows

  #_______________________________________________




  #! CLEANUP-----------------------------------
  when false:
    for bi in 0..theKey.high: theKey[bi] = 0
    for bi in 0..extraTable.high:
      for bbi in 0..extraTable[bi].high: extraTable[bi][bbi] = 0
    for bi in 0..chunkExtraTable.high:
      for bbi in 0..chunkExtraTable[bi].high: chunkExtraTable[bi][bbi] = 0
    for bi in 0..theKey.high: theKey[bi] = 0
    for bi in 0..password.high: password[bi] = '\"'
    for bi in 0..theBuffer.high: theBuffer[bi] = 0
    numChunks = 0
    operationMode = opNone
    exV = 0
    exH = 0
    salt_rand = 0
    ChunkMultiplier = 0
    MaxChunkSize = 0
    MaxInputBufferSize = 0













#[ 
######## ########  ######  ########  ######  
   ##    ##       ##    ##    ##    ##    ## 
   ##    ##       ##          ##    ##       
   ##    ######    ######     ##     ######  
   ##    ##             ##    ##          ## 
   ##    ##       ##    ##    ##    ##    ## 
   ##    ########  ######     ##     ######  

 ]#



  when false:
    echo toSafeFileName("Program Files (x86)")
    echo toSafeFileName(0x00.chr & " whitespace \e")










  when false: ###############################################
    echo "\n======= TESTING ======================"
    password = "passw0rd"

    testBenchmark "threaded",1:
      if bitgrinder.KeyExpandProc == 128: bitgrinder.KeyExpandProc = 0
      echo "\n###############################"
      echo "password length: ", password.len, " ", password
      echo "KeyExpand Proc num: ", bitgrinder.KeyExpandProc
      echo "keyTable PreBurn: ",bitgrinder.PreBurn
      echo "KeyTableRows: ", bitgrinder.KeyTableRows

      if theKey.len == 0:
        theKey = passToKey(password)
        when debug >= 0b0: echo "Generating Key"
      encodeFile("/home/user/Downloads/test1M",
                  "/home/user/Downloads/test1M.out")


    testBenchmark "threaded",1:
      echo "\n################################"
      echo "password length: ", password.len, " ", password
      echo "KeyExpand Proc num: ", bitgrinder.KeyExpandProc
      echo "keyTable PreBurn: ",bitgrinder.PreBurn
      echo "KeyTableRows: ", bitgrinder.KeyTableRows

      if theKey.len == 0:
        theKey = passToKey(password)
        when debug >= 0b0: echo "Generating Key"
      decodeFile("/home/user/Downloads/test1M.out",
                  "/home/user/Downloads/test1M.dec")

    echo "\n# Comparing files, return code: ", execShellCmd("cmp /home/user/Downloads/test1M /home/user/Downloads/test1M.dec")

    echo "\nFINISHED................................\n\n"








  when false: #=========================================================
  # CHANGE PATHS BEFORE RUNNING IT:
    import bitops
    echo "ATTACK"


    testBenchmark "threaded",1:
      password = "passw0rd"
      if theKey.len == 0:
        theKey = passToKey(password)
      
      bitgrinder.KeyExpandProc = 0
      for c in password:
        bitgrinder.KeyExpandProc += c.uint8
      bitgrinder.KeyExpandProc = bitgrinder.KeyExpandProc mod 5
      
      extraTable = makeExtraTables(theKey)
      encodeFile("/home/user/Downloads/SampleTextFile_10kb.txt",
                  "/home/user/Downloads/SampleTextFile_10kb.txt.out")



    var numFail, totalFail: int
    var prevPos:int

    var origiFile = open("/home/user/Downloads/SampleTextFile_10kb.txt",
                        fmRead)
    var origiBuffer = newSeq[uint8](getFileSize("/home/user/Downloads/SampleTextFile_10kb.txt"))
    var origiRead = origiFile.readBytes(
      origiBuffer,
      0,getFileSize("/home/user/Downloads/SampleTextFile_10kb.txt")
      )

    for iP in 0..0: # password.high:
      for iB in 0..0:
        echo "."
        numFail = 0
        password = "passw1rd"
        theKey = passToKey(password)

        extraTable = makeExtraTables(theKey)
        decodeFile("/home/user/Downloads/SampleTextFile_10kb.txt.out",
                    "/home/user/Downloads/SampleTextFile_10kb.txt.deca")

        var testFile = open("/home/user/Downloads/SampleTextFile_10kb.txt.deca",
                            fmRead)
        var testBuffer = newSeq[uint8](getFileSize("/home/user/Downloads/SampleTextFile_10kb.txt.deca"))
        var testRead = testFile.readBytes(
          testBuffer,
          0,getFileSize("/home/user/Downloads/SampleTextFile_10kb.txt.deca")
          )


        if testBuffer.len != origiBuffer.len: echo("filesize error: " & $testBuffer.len & "/" & $origiBuffer.len)

        var maxL = 0
        if testBuffer.len < origiBuffer.len:
          maxL = testBuffer.high
        else:
          maxL = origiBuffer.high

        for di in 0..maxL:
          if origiBuffer[di] == testBuffer[di]:
            numFail += 1
            totalFail += 1
            if prevPos + 1 == di:
              stdout.write "\e[1;33m"
            if di < maxL:
              if origiBuffer[di+1] == testBuffer[di+1]:
                stdout.write "\e[1;33m"
            stdout.write di,",\e[0m" #origiBuffer[di]
            prevPos = di

            testBuffer[di] = 'X'.uint8
          else:
            testBuffer[di] = '.'.uint8

        echo "\n NumFail: ",numFail

        var testOutFile = open("/home/user/Downloads/SampleTextFile_10kb.txt.deca" & $iP & $iB,
          fmWrite)
        discard testOutFile.writeBytes(testBuffer,0,testBuffer.len)
        close(testOutFile)

    echo "TOTAL FAILS: ",totalFail, "/",origiBuffer.len, "  ", formatFloat((totalFail / origiBuffer.len) * 100,ffDefault,3), "%"

    echo "\nFINISHED................................"



#[ new key algos
  135,250,719,895,1308,1386,1938,2181,2923,2962,3492,4830,4951,5133,5162,5345,5910,5912,6060,6481,7072,7365,8307,8691,9054,9212,9217,9251,
  password: 28
  TOTAL FAILS: 28/9510  0.294%
 ]#

#[ 123,228,488,559,604,676,1195,1286,1292,1305,1680,2135,2656,3194,3310,3541,3745,3762,3967,4096,4449,4638,4718,4747,5977,6513,6589,7240,7982,8457,8632,9085,9095,
password: 33
TOTAL FAILS: 33/9510  0.347% ]#

#[   blowfish tester
  298,400,609,839,1222,1626,2083,2143,2671,2700,2721,2916,3079,3089,3125,3359,3361,3573,4218,4294,4343,4581,4815,5072,5572,5895,6160,6389,6449,7102,7188,7368,8031,8041,8805,8914,8951,9132,9140,
  TOTAL FAILS: 79/9510  0.831% ]#





#[
  echo "aes tester"

  origiRead = origiFile.readBytes(
    origiBuffer,
    0,getFileSize("/home/user/Downloads/SampleTextFile_10kb.txt")
    )

  var testBuffer = newSeq[uint8](getFileSize("/home/user/Downloads/SampleTextFile_10kb.aes.dec"))

  var testFile = open("/home/user/Downloads/SampleTextFile_10kb.aes.dec",
                    fmRead)
  var testRead = testFile.readBytes(
        testBuffer,
        0,getFileSize("/home/user/Downloads/SampleTextFile_10kb.aes.dec")
        )

  for di in 0..testBuffer.high:
    if origiBuffer[di] == testBuffer[di]:
      numFail += 1
      totalFail += 1
      if prevPos + 1 == di:
        stdout.write "\e[1;33m"
      if di < origiBuffer.high  and
        origiBuffer[di+1] == testBuffer[di+1]:
          stdout.write "\e[1;33m"
      stdout.write di,",\e[0m" #origiBuffer[di]
      prevPos = di

      testBuffer[di] = 'X'.uint8
    else:
      testBuffer[di] = '.'.uint8


  var testOutFile = open("/home/user/Downloads/SampleTextFile_10kb.aes.deca",
    fmWrite)
  discard testOutFile.writeBytes(testBuffer,0,testBuffer.len)
  close(testOutFile)

  echo "\nTOTAL FAILS: ",totalFail, "/",origiBuffer.len, "  ", formatFloat((totalFail / origiBuffer.len) * 100,ffDefault,3), "%"

  echo "\nFINISHED................................"
#[ aes tester
95,495,655,1910,1915,1974,2093,2263,2276,2689,2986,3111,3287,4091,4247,4662,4957,6748,6835,6966,7180,7210,7409,7552,7788,7846,8156,8215,8405,9306,9338,9494,
TOTAL FAILS: 63/9510  0.662% ]#

 ]#


#[
  echo "blowfish tester"

  origiRead = origiFile.readBytes(
    origiBuffer,
    0,getFileSize(
      "/home/user/Downloads/SampleTextFile_10kb.txt")
    )

  var testBuffer = newSeq[uint8](getFileSize(
    "/home/user/Downloads/SampleTextFile_10kb.blowfish.dec"))

  var testFile = open("/home/user/Downloads/SampleTextFile_10kb.blowfish.dec",
                    fmRead)
  var testRead = testFile.readBytes(
        testBuffer,
        0,getFileSize("/home/user/Downloads/SampleTextFile_10kb.blowfish.dec")
        )

  for di in 0..testBuffer.high:
    if origiBuffer[di] == testBuffer[di]:
      numFail += 1
      totalFail += 1
      if prevPos + 1 == di:
        stdout.write "\e[1;33m"
      if di < origiBuffer.high  and
        origiBuffer[di+1] == testBuffer[di+1]:
          stdout.write "\e[1;33m"
      stdout.write di,",\e[0m" #origiBuffer[di]
      prevPos = di

      testBuffer[di] = 'X'.uint8
    else:
      testBuffer[di] = '.'.uint8


  var testOutFile = open("/home/user/Downloads/SampleTextFile_10kb.blowfish.deca",
    fmWrite)
  discard testOutFile.writeBytes(testBuffer,0,testBuffer.len)
  close(testOutFile)

  echo "\nTOTAL FAILS: ",totalFail, "/",origiBuffer.len, "  ",  formatFloat((totalFail / origiBuffer.len) * 100,ffDefault,3),  "%"

  echo "\nFINISHED................................"

 #[ blowfish tester
8,449,1053,1947,2446,2457,2545,2568,2687,2965,3277,3423,3841,3849,3947,4258,4358,4403,4672,4784,4950,4973,5201,5600,5853,5984,6268,7143,7648,8102,8296,8710,8735,9239,
TOTAL FAILS: 80/9510  0.841% ]#
  ]#



  #echo salt_rands
#[
  testBenchmark "single threaded",1:
    if theKey.len == 0:
      theKey = passToKey(password)
    extraTable = makeExtraTables(theKey)

    inFile = open("/home/user/Downloads/test1M", fmRead)
    numRead = inFile.readBytes(theBuffer,0,getFileSize(inFile))
    inFile.close()
    encode(theBuffer,0,theBuffer.high,theKey,password,128)
    outFile = open("/home/user/Downloads/test1M.out2", fmWrite)
    echo outFile.writeBytes(theBuffer,0,numRead)
    outFile.close()

  testBenchmark "single threaded",1:
    if theKey.len == 0:
      theKey = passToKey(password)
    extraTable = makeExtraTables(theKey)

    inFile = open("/home/user/Downloads/test1M.out2", fmRead)
    numRead = inFile.readBytes(theBuffer,0,getFileSize(inFile))
    inFile.close()
    decode(theBuffer,0,theBuffer.high,theKey,password,128)
    outFile = open("/home/user/Downloads/test1M.dec2", fmWrite)
    echo outFile.writeBytes(theBuffer,0,numRead)
    outFile.close()

  echo "\nFINISHED-------------------------------"
 ]#
