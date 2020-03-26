# bitgrinder
## (file) encryption tool and cipher
## written in Nim

**bitgrinder** _cipher_ uses simple functions - like xor, addition, swapping - to encode
a sequence (array) of bytes(!).  
currently it is 16 byte operations. (almost like 16 rounds?)  
no multiple rounds are used - but, the key expansion proc may *preburn* the key N times,  
and the *afterburners* may postprocess the result as needed.  
  
bitgrinder is tested as:
ciphertext encrypted with "passw0rd", then 1 bit is flipped, and if the result is unreadable, its marked as success.  
(i tested the 2 commonly known ciphers too, and bg's results are good.)

  
bitgrinder is long, but it is really simple.  
there is no hard math behind the scenes.  
(there is some hard(?) logic at decoding, where the calculation of the last key is needed...)  
(it is the opposit of TEA - wich i really like, its so beautyful...)
bg encodes the password and the key many times, many ways, to make sure, only the right key gets good result.

**bg needs at least a 4 character password to work.**
it uses a minimum 256 bytes long key - derived from password, or supplied in a key file.  
**key files can be encrypted too...**  
**it uses a random salt to change the encoded result every time. - it must be supplied as argument!**  
because xor and addition functions may be accidentali decoded via brute force, the encoder swaps some bytes,
depending on the key.  
so bitgrinder contains a pass-to-key generator, an encoder, and a lot of mixing functions.  
  
  
**filegr** is a **multi-threaded** file encrypton _tool_, built with bitgrinder.  
it adds extra layers of security:  
- chunk up larger byte-sequences like files - depending on the key
- swap bytes - depending on key
- options to change encoder options: preburn, keyexpand mode, keyexpand process, afterburners, keytable rows num
- store encryption options as keys, encrypted-keys
- save used options to key file

changing options may lead to fast or slow encoding/decoding - the slower, the safer...  
eg: using a 4096 byte key and a long password from a password file (both generated with openssl or on random.org),  
setting keytablerows to 64, preburn to 256 - and the encoding time rises 10X :)  
except afterburners, all options will be auto choosed, based on the password, if not explicitly given.  
the options are multiplying the work needed for succesfull crack.  
  
**you may write your own afterburners, to make the tool unique!**

the source is full of commented-out sections, and testresults can be find in /tests:  
the original version was hand-crafted, later, after many boring tests, i wrote automated test, and the current key-expansion procs are selected from millions of rounds, statistically.  
at the end of bitgrinder.nim, test functions can be enabled - they are moved to ismain.nim.  
it was fun to write bg, and i hope, others will also find it intresting, to hack around - that is why the source is not bleached-out ;) it is a living code.  
  
## FILEGR

'''
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
'''
