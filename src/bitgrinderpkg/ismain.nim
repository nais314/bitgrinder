
import tables
import math
import strformat, strutils
import times, os

proc echoCountTable(
        BS:seq[SomeUnsignedInt]|seq[SomeOrdinal],
        olvl1:int= -1,
        olvl2:int= -1,
        name:string="")=
  echo "\n......................................."
  echo &"[{name}]: ", BS.len," bytes"

  var cT = toCountTable(BS)
  var
    max:int
    avg:int
    lvl1 = olvl1.int
    lvl2 = olvl2.int
    numLvl1,numLvl2,numLvl3:int
  var b:int

  #[ if olvl1 == -1:
    for a in values(cT):
      if a.int > max: max = a.int
    lvl1 = max div 3
    lvl2 = max - (max div 3) ]#
  if olvl1 == -1:
    lvl1 = int.high
    for a in values(cT):
      if a.int > max: max = a.int
      if lvl1 > a.int: lvl1 = a.int #* min
    lvl1 = lvl1 + ((max - lvl1) div 3)
    lvl2 = max - ((max - lvl1) div 2)

  echo "levels: ", lvl1, " / ", lvl2, " / ", max

  for a in keys(cT):
    #stdout.write fmt"{a:>3d}:{cT[a]:>3d}, "
    if cT[a] <= lvl1:
      stdout.write "\e[32m",fmt"{a:>3d}:{cT[a]:>3d} ", "\e[0m|"
      #stdout.write "\e[34m",fmt"{a:>3d}:","\e[32m",fmt"{cT[a]:>3d} ", "\e[0m|"
      numLvl1 += 1
    elif cT[a] <= lvl2:
      stdout.write "\e[37m",fmt"{a:>3d}:{cT[a]:>3d} ", "\e[0m|"
      #stdout.write "\e[34m",fmt"{a:>3d}:","\e[37m",fmt"{cT[a]:>3d} ", "\e[0m|"
      numLvl2 += 1
    else:
      stdout.write "\e[33m",fmt"{a:>3d}:{cT[a]:>3d} ", "\e[0m|"
      #stdout.write "\e[34m",fmt"{a:>3d}:","\e[33m",fmt"{cT[a]:>3d} ", "\e[0m|"
      numLvl3 += 1
    b += 1 # narrow column for display
    if b == 5:
      b = 0
      echo ""

    #[ if cT[a] > max: max = cT[a]]#
    avg += cT[a]

  echo "\n MAX: ", max
  echo " AVG: ", avg / cT.len, ""
  echo "num lvl1: ", numLvl1, " lvl2: ",numLvl2, " lvl3: ",numLvl3
  echo "__________________________________________"

var
  #val:ByteSeq
  #val = "Árvíz".toByteSeq
  #val = toByteSeq("ÁrvízmxKeySwapBitsA(mxKeyXor(mxKeyRotEnc(mxKeySwapMinors3(kk))))mxKeySwapBitsA(mxKeyXor(mxKeyRotEnc(mxKeySwapMinors3(kk))))Árvíz")
  #[ val = toByteSeq("Contrary to popular belief, LoREM Ipsum is not simply random text. It has roots in a piece of classical Latin literature from 45 BC, making it over 2000 years old.Sections 1.10.32 and 1.10.33 from \"de Finibus Bonorum et Malorum\" by Cicero are also reproduced in their exact original form, accompanied") ]#
  val = toByteSeq('z'.repeat(256)) # 122 :)
  #val = toByteSeq('z'.repeat(810)) # 4096 * 256
  #val:ByteSeq= @[77.uint8,121.uint8,64.uint8]
  #[ val:ByteSeq= @[11.uint8,22.uint8,33.uint8,44.uint8,
    55.uint8,66.uint8,77.uint8,88.uint8,
    99.uint8,00.uint8,10.uint8,20.uint8] ]#
  #[ val = toByteSeq("""

  What is LoREM Ipsum?

  LoREM Ipsum is simply dummy text of the printing and typesetting industry. LoREM Ipsum has been the industry's standard dummy text ever since the 1500s, when an unknown printer took a galley of type and scrambled it to make a type specimen book. It has survived not only five centuries, but also the leap into electronic typesetting, REMaining essentially unchanged. It was popularised in the 1960s with the release of Letraset sheets containing LoREM Ipsum passages, and more recently with desktop publishing software like Aldus PageMaker including versions of LoREM Ipsum.
  Why do we use it?

  It is a long established fact that a reader will be distracted by the readable content of a page when looking at its layout. The point of using LoREM Ipsum is that it has a more-or-less normal distribution of letters, as opposed to using 'Content here, content here', making it look like readable English. Many desktop publishing packages and web page editors now use LoREM Ipsum as their default model text, and a search for 'loREM ipsum' will uncover many web sites still in their infancy. Various versions have evolved over the years, sometimes by accident, sometimes on purpose (injected humour and the like).

  Where does it come from?

  Contrary to popular belief, LoREM Ipsum is not simply random text. It has roots in a piece of classical Latin literature from 45 BC, making it over 2000 years old. Richard McClintock, a Latin professor at Hampden-Sydney College in Virginia, looked up one of the more obscure Latin words, consectetur, from a LoREM Ipsum passage, and going through the cites of the word in classical literature, discovered the undoubtable source. LoREM Ipsum comes from sections 1.10.32 and 1.10.33 of "de Finibus Bonorum et Malorum" (The ExtREMes of Good and Evil) by Cicero, written in 45 BC. This book is a treatise on the theory of ethics, very popular during the Renaissance. The first line of LoREM Ipsum, "LoREM ipsum dolor sit amet..", comes from a line in section 1.10.32.

  The standard chunk of LoREM Ipsum used since the 1500s is reproduced below for those interested. Sections 1.10.32 and 1.10.33 from "de Finibus Bonorum et Malorum" by Cicero are also reproduced in their exact original form, accompanied by English versions from the 1914 translation by H. Rackham.

""") ]#
  #[ val = toByteSeq("""fBColFHV4Fd7pyMcJq8Y
Z26MSBgICJTMBzy51rqa2our7BA6Fb3KhAjMFUzUuBSm0fQ7gks14gjpboXVZTDU0TFMYvQSrOCKVXH0joZX6KBg5QnbTkZQCKIGst7wcV1qFlKXv5VeGcg99UsRyTLXrV1R8YIoSp9USgCGaLVrhDkO6F2PRMpgqMrMdvXc7tYjfyBGHQAAz3RUmsYDCbDiQ0umpnQV8yYHCRl4YWb7uex1jx8vPJ2x2VAYse3LyX4rg0NzvXwwf2UwgRFXcK0zKSodE12fIlnqk6Wq8EXApmQwrNDtbfw2Qcan7QwX6dXs7cT78ntihaC55PPdNwWsPO3OY4OOuRV6jQQMm1UoLP1X8WTfi7qEd24TfcNR3dnTh3kXt3Q1LnRHP8fc5CqxwzgmbRs7wXduElea4fZTF8pq8uRL4JOGU6PCkAb5weqt3fJu02MKBpLNG8ndK0KoWZjotFngThiWFXYXaZH5CrcpZscny1afMGA4zgR6kHzIRqADFmN3vXWenPvBdrWdR5ELno1TQsOb6lBv01jJFHLUGzZwTHQC6ApugjTD0nzL5n2s0MX5kXSgztBt92p4rFT4wG0VQRFToDjccLDhnjS9cbSecg9Qrfc8MkPk5cFwY9wDXU9AWu9Vfr2LxkiTNA4RPUTMCcxkqaCSRYPR9cmHGCRoRLBpgGqGgOnvefG0N5vZozEkALPpxxoVyK3CuhYtrEaera4Dh8kzjPNR9cqK0SwGIJJnBLekdXS6sJK8iOk6bBBks55vZwpWxZ1IBxnrq4GliGTU
YWW2Oh2SP4hfJtawiZ4iG3ogyPjYayvxMAs2yd3tJJa54pTlsEdwr1yRYY7ErOaZZAzRZkt1nDKw0BcqeVOVSQ7xpdj1D5gqv3pp8W8qSAkP4PQLCA6OeO4Kct5UEOqVsOGaEYPcov4nRDqmUxOkBI6JBnldNbCKczmzJhCfTvwY3NUgLJci9f0MFBbb1IxJ9cok3DOIAf1avODQYWN7MtoQYn6C4q
""") ]#
  plaintextlist = [
    #"1", "12", "123",
    'z'.repeat(1024),
    """fBColFHV4Fd7pyMcJq8YZ26MSBgICJTMBzy51rqa2our7BA6Fb3KhAjMFUzUuBSm0fQ7gks14gjpboXVZTDU0TFMYvQSrOCKVXH0joZX6KBg5QnbTkZQCKIGst7wcV1qFlKXv5VeGcg99UsRyTLXrV1R8YIoSp9USgCGaLVrhDkO6F2PRMpgqMrMdvXc7tYjfyBGHQAAz3RUmsYDCbDiQ0umpnQV8yYHCRl4YWb7uex1jx8vPJ2x2VAYse3LyX4rg0NzvXwwf2UwgRFXcK0zKSodE122fIlnqk6Wq8EXApmQwrNDtbfw2Qcan7QwX6dXs7cT78ntihaC55PPdNwWsPO3OY4OOuRV6jQQMm1UoLP1X8WTfi7qEd24TfcNR3dnTh3kXt3Q1LnRHP8fc5CqxwzgmbRs7wXduElea4fZTF8pq8uRL4JOGU6PCkAb5weqt3fJu02MKBpLNG8ndK0KoWZjotFngThiWFXYXaZH5CrcpZscny1afMGA4zgR6kHzIRqADFmN3vXWenPvBdrWdR5ELno1TQsOb6lBv01jJFHLUGzZwTHQC6ApugjTD0nzL5n2s0MX5kXSgztBt92p4rFT4wG0VQRFToDjccLDhnjS9cbSec3g9Qrfc8MkPk5cFwY9wDXU9AWu9Vfr2LxkiTNA4RPUTMCcxkqaCSRYPR9cmHGCRoRLBpgGqGgOnvefG0N5vZozEkALPpxxoVyK3CuhYtrEaera4Dh8kzjPNR9cqK0SwGIJJnBLekdXS6sJK8iOk6bBBks55vZwpWxZ1IBxnrq4GliGTUYWW2Oh2SP4hfJtawiZ4iG3ogyPjYayvxMAs2yd3tJJa54pTlsEdwr1yRYY7ErOaZZAzRZkt1nDKw0BcqeVOVSQ7xpdj1D5gqv3pp8W8qSAkP4PQLCA6OeO4Kct5UEOqVsOGaEYPcov4nRDqmUxOkBI6JBnldNbCKczmzJhCfTvwY3NUgLJci9f0MFBbb1IxJ9cok3DOIAf1avODQYWN7MtoQYn6C4q
""",
    #[ """is not simply random text. It has roots in a piece of classical Latin literature from 45 BC, making it over 2000 years old. Richard McClintock, a Latin professor at Hampden-Sydney College in Virginia, looked up one of the more obscure Latin words, consectetur, from a LoREM Ipsum passage, and going through the cites of the word in classical literature, discovered the undoubtable source. LoREM Ipsum comes from sections 1.10.32 and 1.10.33 of "de Finibus Bonorum et Malorum" (The ExtREMes of Good and Evil) by Cicero, written in 45 BC. This book is a treatise on the theory of ethics, very popular during the Renaissance. The first line of LoREM Ipsum, "LoREM ipsum dolor sit amet..", comes from a line in section 1.10.32.

  The standard chunk of LoREM Ipsum used since the 1500s is reproduced below for those interested. Sections 1.10.32 and 1.10.33 from "de Finibus Bonorum et Malorum" by Cicero are also reproduced in their exact original form, accompanied by English versions from the 1914 translation by H. Rackham.
""", ]#
"""Lorem ipsum dolor sit amet, consectetur adipiscing elit. Vivamus condimentum sagittis lacus, laoreet luctus ligula laoreet ut. Vestibulum ullamcorper accumsan velit vel vehicula. Proin tempor lacus arcu. Nunc at elit condimentum, semper nisi et, condimentum mi. In venenatis blandit nibh at sollicitudin. Vestibulum dapibus mauris at orci maximus pellentesque. Nullam id elementum ipsum. Suspendisse cursus lobortis viverra. Proin et erat at mauris tincidunt porttitor vitae ac dui.

Donec vulputate lorem tortor, nec fermentum nibh bibendum vel. Lorem ipsum dolor sit amet, consectetur adipiscing elit. Praesent dictum luctus massa, non euismod lacus. Pellentesque condimentum dolor est, ut dapibus lectus luctus ac. Ut sagittis commodo arcu. Integer nisi nulla, facilisis sit amet nulla quis, eleifend suscipit purus. Class aptent taciti sociosqu ad litora torquent per conubia nostra, per inceptos himenaeos. Aliquam euismod ultrices lorem, sit amet imperdiet est tincidunt vel. Phasellus dictum justo sit amet ligula varius aliquet auctor et metus. Fusce vitae tortor et nisi pulvinar vestibulum eget in risus. Donec ante ex, placerat a lorem eget, ultricies bibendum purus. Nam sit amet neque non ante laoreet rutrum. Nullam aliquet commodo urna, sed ullamcorper odio feugiat id. Mauris nisi sapien, porttitor in condimentum nec, venenatis eu urna. Pellentesque feugiat diam est, at rhoncus orci porttitor non.

Nulla luctus sem sit amet nisi consequat, id ornare ipsum dignissim. Sed elementum elit nibh, eu condimentum orci viverra quis. Aenean suscipit vitae felis non suscipit. Suspendisse pharetra turpis non eros semper dictum. Etiam tincidunt venenatis venenatis. Praesent eget gravida lorem, ut congue diam. Etiam facilisis elit at porttitor egestas. Praesent consequat, velit non vulputate convallis, ligula diam sagittis urna, in venenatis nisi justo ut mauris. Vestibulum posuere sollicitudin mi, et vulputate nisl fringilla non. Nulla ornare pretium velit a euismod. Nunc sagittis venenatis vestibulum. Nunc sodales libero a est ornare ultricies. Sed sed leo sed orci pellentesque ultrices. Mauris sollicitudin, sem quis placerat ornare, velit arcu convallis ligula, pretium finibus nisl sapien vel sem. Vivamus sit amet tortor id lorem consequat hendrerit. Nullam at dui risus.

Vestibulum ante ipsum primis in faucibus orci luctus et ultrices posuere cubilia Curae; Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed feugiat semper velit consequat facilisis. Etiam facilisis justo non iaculis dictum. Fusce turpis neque, pharetra ut odio eu, hendrerit rhoncus lacus. Nunc orci felis, imperdiet vel interdum quis, porta eu ipsum. Pellentesque dictum sem lacinia, auctor dui in, malesuada nunc. Maecenas sit amet mollis eros. Proin fringilla viverra ligula, sollicitudin viverra ante sollicitudin congue. Donec mollis felis eu libero malesuada, et lacinia risus interdum.

Etiam vitae accumsan augue. Ut urna orci, malesuada ut nisi a, condimentum gravida magna. Nulla bibendum ex in vulputate sagittis. Nulla facilisi. Nullam faucibus et metus ac consequat. Quisque tempor eros velit, id mattis nibh aliquet a. Aenean tempor elit ut finibus auctor. Sed at imperdiet mauris. Vestibulum pharetra non lacus sed pulvinar. Sed pellentesque magna a eros volutpat ullamcorper. In hac habitasse platea dictumst. Donec ipsum mi, feugiat in eros sed, varius lacinia turpis. Donec vulputate tincidunt dui ac laoreet. Sed in eros dui. Pellentesque placerat tristique ligula eu finibus. Proin nec faucibus felis, eu commodo ipsum.

Integer eu hendrerit diam, sed consectetur nunc. Aliquam a sem vitae leo fermentum faucibus quis at sem. Etiam blandit, quam quis fermentum varius, ante urna ultricies lectus, vel pellentesque ligula arcu nec elit. Donec placerat ante in enim scelerisque pretium. Donec et rhoncus erat. Aenean tempor nisi vitae augue tincidunt luctus. Nam condimentum dictum ante, et laoreet neque pellentesque id. Curabitur consectetur cursus neque aliquam porta. Ut interdum nunc nec nibh vestibulum, in sagittis metus facilisis. Pellentesque feugiat condimentum metus. Etiam venenatis quam at ante rhoncus vestibulum. Maecenas suscipit congue pellentesque. Vestibulum suscipit scelerisque fermentum. Nulla iaculis risus ac vulputate porttitor.

Mauris nec metus vel dolor blandit faucibus et vel magna. Ut tincidunt ipsum non nunc dapibus, sed blandit mi condimentum. Quisque pharetra interdum quam nec feugiat. Sed pellentesque nulla et turpis blandit interdum. Curabitur at metus vitae augue elementum viverra. Sed mattis lorem non enim fermentum finibus. Sed at dui in magna dignissim accumsan. Proin tincidunt ultricies cursus. Maecenas tincidunt magna at urna faucibus lacinia.

Quisque venenatis justo sit amet tortor condimentum, nec tincidunt tellus viverra. Morbi risus ipsum, consequat convallis malesuada non, fermentum non velit. Nulla facilisis orci eget ligula mattis fermentum. Aliquam vel velit ultricies, sollicitudin nibh eu, congue velit. Donec nulla lorem, euismod id cursus at, sollicitudin et arcu. Proin vitae tincidunt ipsum. Vivamus elementum eleifend justo, placerat interdum nulla rutrum id.

Phasellus fringilla luctus magna, a finibus justo dapibus a. Nam risus felis, rhoncus eget diam sit amet, congue facilisis nibh. Interdum et malesuada fames ac ante ipsum primis in faucibus. Praesent consequat euismod diam, eget volutpat magna convallis at. Mauris placerat pellentesque imperdiet. Nulla porta scelerisque enim, et scelerisque neque bibendum in. Proin eget turpis nisi. Suspendisse ut est a erat egestas eleifend at euismod arcu. Donec aliquet, nisi sed faucibus condimentum, nisi metus dictum eros, nec dignissim justo odio id nulla. Pellentesque habitant morbi tristique senectus et netus et malesuada fames ac turpis egestas. Maecenas sollicitudin, justo id elementum eleifend, justo neque aliquet nibh, finibus malesuada metus erat eget neque. Suspendisse nec auctor orci. Aenean et vestibulum nulla. Nullam hendrerit augue tristique, commodo metus id, sodales lorem. Etiam feugiat dui est, vitae auctor risus convallis non.

Maecenas turpis enim, consectetur eget lectus eu, hendrerit posuere lacus. Praesent efficitur, felis eget dapibus consectetur, nisi massa dignissim enim, nec semper dolor est eu urna. Nullam ut sodales lorem. Aliquam dapibus faucibus diam. Vestibulum vel magna et dolor gravida imperdiet ut sit amet sem. Lorem ipsum dolor sit amet, consectetur adipiscing elit. Curabitur elementum metus tincidunt nulla euismod ultricies. Duis elementum nec neque in porttitor. Nulla sagittis lorem elit, et consectetur ante laoreet eu. Maecenas nulla tellus, scelerisque ac erat sed, fermentum dapibus metus. Donec tincidunt fermentum molestie.

Sed consequat mi at maximus faucibus. Pellentesque aliquet tincidunt sapien vel auctor. Pellentesque habitant morbi tristique senectus et netus et malesuada fames ac turpis egestas. Praesent accumsan nunc eget leo aliquam, facilisis hendrerit turpis egestas. Morbi in ultricies mauris, a eleifend turpis. Quisque fringilla massa iaculis risus ultrices, sit amet tincidunt dui varius. Quisque maximus porta tristique. Proin tincidunt, turpis ut tempor pretium, lectus ipsum ullamcorper leo, ac tincidunt felis dui non leo. Aenean porta augue ligula, non consequat ipsum aliquet et. Suspendisse ut suscipit ex. Pellentesque vitae lacinia arcu. Curabitur eget tincidunt nulla, non bibendum metus. Nullam mi ipsum, eleifend vitae tortor pulvinar, facilisis sollicitudin ipsum.

Vestibulum molestie risus lorem, at feugiat lorem congue sed. Phasellus ullamcorper laoreet enim, nec aliquam turpis scelerisque et. Etiam dictum metus in elit aliquam dapibus. Vivamus vel lectus velit. Nam sed purus luctus, commodo dui quis, malesuada dui. Nulla porttitor aliquet elit sit amet viverra. Proin tempor nulla urna, non aliquet metus maximus quis. Aliquam ac lectus nec mi aliquam sagittis. Quisque venenatis quam eget nisl tempor, egestas rutrum eros eleifend. Nullam venenatis commodo velit, non tempor mauris fermentum ut. In a metus quis erat cursus sagittis. Donec congue nisl in viverra egestas.

Vestibulum facilisis ligula magna, eu ornare lectus varius et. Mauris facilisis faucibus quam, quis mollis eros convallis non. Interdum et malesuada fames ac ante ipsum primis in faucibus. Praesent sit amet rutrum erat. Suspendisse potenti. Donec lorem mi, sagittis a fringilla sit amet, sagittis bibendum mauris. In in diam et lorem rutrum eleifend a et felis. Sed ac magna quis enim faucibus dictum. Suspendisse blandit enim eu ex laoreet gravida.

Suspendisse sed semper felis. Etiam mattis magna mi, suscipit ullamcorper tellus euismod sed. Aenean congue scelerisque ligula id sodales. Class aptent taciti sociosqu ad litora torquent per conubia nostra, per inceptos himenaeos. Nunc sem lectus, gravida ac dui non, pharetra posuere leo. Maecenas lacus libero, facilisis et elit vitae, commodo facilisis sem. Vivamus id nisl nulla. Integer at maximus dui. Ut a tincidunt lorem. Vivamus vitae ligula vel lacus cursus condimentum. Phasellus quis mauris lobortis, finibus lorem in, vulputate ex. Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed faucibus aliquam metus, quis varius elit porttitor id. Vivamus dignissim sollicitudin scelerisque. Morbi tincidunt, dolor quis vehicula consequat, dui diam condimentum nunc, vitae scelerisque odio libero nec ligula. Vestibulum ante ipsum primis in faucibus orci luctus et ultrices posuere cubilia Curae;
"""
  ]

let passwordlist = [
  "passw0rd",
  "TmL%JhpH*ib0",
  "zvG8^gnj3@ZW@f8t",
  "CSRYPR9cmHGCRoRL",
  "Richard McClintock",
  "Lacus cubilia urna eget eleifend",
  "UmsYDCbDiQ0umpnQV8yYHCRl4YWb7",
  "Finibus Bonorum et Malorum\" by Cicero", #8

  "123456",
  "password", #10
  "12345678",
  "qwerty",
  "123456789",
  "12345",
  "1234",
  "111111",
  "1234567",
  "dragon",
  "123123",
  "baseball", #20
  "abc123",
  "football",
  "monkey",
  "letmein",
  "696969",
  "shadow",
  "master",
  "666666",
  "qwertyuiop",
  "123321", #30
  "mustang",
  "1234567890",
  "michael",
  "654321",
  "pussy",
  "superman",
  "1qaz2wsx",
  "7777777",
  "fuckyou",
  "121212", #40
  "000000",
  "qazwsx",
  "123qwe",
  "killer",
  "trustno1",
  "jordan",
  "jennifer",
  "zxcvbnm",
  "asdfgh",
  "hunter", #50
  "buster",
  "soccer",
  "harley",
  "batman",
  "andrew",
  "tigger",
  "sunshine",
  "iloveyou",
  "fuckme",
  "2000",
  "charlie",
  "robert",
  "thomas",
  "hockey",
  "ranger",
  "daniel",
  "starwars",
  "klaster",
  "112233",
  "george",
  "asshole",
  "computer",
  "michelle",
  "jessica",
  "pepper",
  "1111",
  "zxcvbn",
  "555555",
  "11111111",
  "131313",
  "freedom",
  "777777",
  "pass",
  "fuck",
  "maggie",
  "159753",
  "aaaaaa",
  "ginger",
  "princess",
  "joshua",
  "cheese",
  "amanda",
  "summer",
  "love",
  "ashley",
  "6969",
  "nicole",
  "chelsea",
  "biteme",
  "matthew",
  "access",
  "yankees",
  "987654321",
  "dallas",
  "austin",
  "thunder",
  "taylor",
  "matrix",
  "william"
]

#[ var
  valStr:string
  val:ByteSeq
for i in 1..300:
  valStr &= chr(rand(255))
val = valStr.toByteSeq ]#









#*******************************************************
echo "\n**********************************************"

echo "[key regeneration test]"
var theKey = passToKey("passw0rd")
echo "1st try\n",theKey
echo "can be regenerated? ***",(theKey == passToKey("passw0rd")),"***"

#val = 'z'.repeat(200).toByteSeq

echo "\n [encode - decode test]"
var t0 = epochTime()
var valOrigi = val
encode(val, 
        theKey,"passw0rd",
        150)
echo "Encoding Elapsed Time: ", epochTime() - t0


let enc = val


t0 = epochTime()
decode(val, 
        theKey,"passw0rd",
        150)
echo "Decoding Elapsed Time: ", epochTime() - t0


var oke:bool=true
for i in 0..val.high:
  if valOrigi[i] != val[i]: oke = false
  if i mod 16 == 0: stdout.write valOrigi[i], " == ", val[i], "| "
echo ""

#echo "*****************"
echo "\n **** success ", oke," ****"
#echo "*****************"


echo "\nORIGINAL"
for i in 0..valOrigi.high:
  stdout.write fmt"{valOrigi[i]:>3d} "
  if i > 0 and ((i+1) mod 10) == 0: echo ""
  if i > 0 and i mod 64 == 0: break
echo ""

echo "\nENCODED"
for i in 0..enc.high:
  stdout.write fmt"{enc[i]:>3d} "
  if i > 0 and ((i+1) mod 10) == 0: echo ""
  if i > 0 and i mod 64 == 0: break
echo ""

echo "\nDECODED"
for i in 0..val.high:
  if val[i] != valOrigi[i]:
    stdout.write "\e[1;33m"
  stdout.write fmt"{val[i]:>3d} ","\e[0m"
  if i > 0 and ((i+1) mod 10) == 0: echo ""
  #if i > 0 and i mod 64 == 0: break
echo "\n"


for i in 0..val.high:
  stdout.write "\e[48;2;" & $valOrigi[i] & ";" & $valOrigi[i] & ";" & $valOrigi[i] & "m", "  " , "\e[0m"
  if (i+1) mod 24 == 0: echo ""
  if i > 0 and i mod 128 == 0: break
echo "\n"

for i in 0..enc.high:
  stdout.write "\e[48;2;" & $enc[i] & ";" & $enc[i] & ";" & $enc[i] & "m", "  " , "\e[0m"
  if (i+1) mod 24 == 0: echo ""
  if i > 0 and i mod 128 == 0: break
echo ""


if not oke : quit("\e[33;1m**** PROGRAM ERROR ****\e[0m")

#[ proc getPosition(max,len:int, key:uint8):int=
  var flo = max / len
  result = (key.float / flo).round().int ]#


echo "\n[get eytra byte inclusion pos]"
echo "val.len: ",val.len
#[ var extraBPos: array[0..3,int]
for k in 0..3:
  extraBPos[k] = getPosition(255,val.len,theKey[k])
extraBPos.sort()
echo extraBPos ]#
var extraBPos = getExtraPositions(val.len,theKey)
echo extraBPos

echo "\n**********************************************"
var encX = enc
for i in countdown(extraBPos.high,0):
  encX.insert(0.uint8, extraBPos[i])
  encX.insert(0.uint8, extraBPos[i])
  encX.insert(0.uint8, extraBPos[i])

for i in 0..extraBPos.high:
  encX.delete(extraBPos[i])
  encX.delete(extraBPos[i])
  encX.delete(extraBPos[i])

echo "extrabytes extracted: ", encX == enc

sleep(500)
val = valOrigi
#*-----------------------------------
#[
for p in plaintextlist:
  val = p.toByteSeq
  enc = encode(val)
  dec = decode(enc)

  echo "********\n* ", val == dec ," *\n********"



]#




when passToKeyTest_2:
  var
    countt = 0
    sumCountt = 0
    maxCountt = 0
    was: ByteSeq
    tbl:ByteSeq

  for pass in passwordlist[0..30]:
    tbl.add(passToKey(pass))

  for c in 0 .. tbl.high:
    if not (tbl[c] in was):
      countt = 0
      was.add(tbl[c])
      for cc in c..tbl.high:
        if c == cc: continue
        if tbl[c] == tbl[cc]:
          countt += 1
          sumCountt += 1
      if countt > maxCountt:
        maxCountt = countt

  echo maxCountt
  echo sumCountt




when passToKeyTest:
  block passToKeyTest:

    var tbl:ByteSeq
    var dupc:int

    for pass in passwordlist[0..50]:
      KeyLen = 16
      var key = passToKey(pass)
      for ch in key:
        dupc = 0
        for di in 0 .. key.high:
          if key[di] == ch:
            dupc += 1
        if dupc > 1: stdout.write "\e[1;33m"
        stdout.write fmt"{ch:>3}, "
        stdout.write "\e[0m"
        tbl.add(ch)
      stdout.write "\n"

    echoCountTable(tbl)

    var
      maxCountt = 0
      was: ByteSeq
      countt:int

    for c in 0 .. tbl.high:
      if not (tbl[c] in was):
        was.add(tbl[c])
        countt = 0
        for cc in c .. tbl.high:
          if c == cc: continue
          if tbl[c] == tbl[cc]:
            countt += 1
            if countt > maxCountt:
              maxCountt = countt
        #echo countt
    echo "maxCountt - ", maxCountt







when passToKeyTestB:
  block passToKeyTestB:

    var tbl:ByteSeq
    var dupc:int

    for passss in passwordlist[0..50]:
      var pass = passss
      KeyLen = 16
      var key = passToKey(pass)
      KeyLen = 16
      var pch = pass[0].uint8
      flipBit(pch,0)
      pass[0] = pch.chr()
      key.add(passToKey(pass))

      echoKey(key)
      echo ""



when passToKeyTestC:
  block passToKeyTestB:

    var tbl:ByteSeq
    var dupc:int

    var keyr:ByteSeq
    var csb:uint8

    for passss in passwordlist[0..50]:
      var pass = passss
      KeyLen = 16
      var key1 = passToKey(pass)

      for i in 0..key1.high:
        key1[i] = key1[i] + (reverseBits(countSetBits(key1[i]).uint8))
        key1[i] = key1[i] + (key1[i].reverseBits())

      for i in 0..key1.high:
        csb += countSetBits(key1[i]).uint8
      key1.add(csb)

      key1 = key1.mxKeyAddRR()


      csb = 0
      KeyLen = 16
      var pch = pass[0].uint8
      flipBit(pch,0)
      pass[0] = pch.chr()
      var key2 = passToKey(pass)

      for i in 0..key2.high:
        key2[i] = key2[i] + (reverseBits(countSetBits(key2[i]).uint8))
        key2[i] = key2[i] + (key2[i].reverseBits())

      for i in 0..key2.high:
        csb += countSetBits(key2[i]).uint8
      key2.add(csb)

      key2 = key2.mxKeyAddRR()


      key1.add(key2)



      echoKey(key1)
      echo ""
      key1 = @[]






import tables
when keyexpand_freq_an1:
  block:
    # key exapnder frequency analysis ---------------
    echo "\n k_e_f_a -----------------------"

    var
      numOdd:int
      exkh:int

    var tbl: ByteSeq
    var passw = passwordList[rand(99)]
    var oKey = passToKey(passw) #passToKey("passw0rd")
    var oKeyTable = getKeyTable(oKey,exkh)

    for i in 0 .. (KeyTableRows-1):
      for o in 0.. oKeyTable[i].high:
        if testBit(oKeyTable[i][o],0):
          numOdd += 1
        tbl.add(oKeyTable[i][o])

    echo "num of odd: ", numOdd, "  ", numOdd / (KeyTableRows * 16) * 100, "%"

    echoCountTable(tbl,-1,-1,"kefa: '" & passw & "' keytable")

    echo "\n end k_e_f_a -----------------------"




when keyexpand_freq_an2:
  block:
    # key exapnder frequency analysis ---------------
    echo "\n k_e_odd_a ~~~~~~~~~~~~~~~~~~~~~~~~~"
    var
      numOdd:int
      avgOdd:float
    var
      tbl: ByteSeq
      exkh:int

    for p in passwordList[0..10]:
      var oKey = passToKey(p)
      exkh = 0
      var oKeyTable = getKeyTable(oKey,exkh)
      numOdd = 0
      for i in 0 .. (KeyTableRows-1):
        for o in 0.. oKeyTable[i].high:
          if testBit(oKeyTable[i][o],0):
            numOdd += 1
          tbl.add(oKeyTable[i][o])
      #echo "num of odd: ", numOdd, "  ", numOdd / (KeyTableRows * KeyLen) * 100, "%"
      avgOdd += (numOdd / (KeyTableRows * KeyLen)) * 100

    echoCountTable(tbl,-1,-1,"kefa: passlist")
    echo "avg: ", avgOdd / passwordlist.len.float, "%"

    echo "\n end k_e_odd_a _____________________"



#[
import tables
block passwords1:
  echo "passToKey(password)"
  echo passToKey("password")
  echo "1111"
  echo passToKey("1111")
  echo "12345"
  echo passToKey("12345")
  echo "321qwe"
  echo passToKey("321qwe")
  echo "mxKeyRotEnc(mxKeySwapMinors2(mxKeyXorB((oldKey))))"
  echo passToKey("mxKeyRotEnc(mxKeySwapMinors2(mxKeyXorB((oldKey))))")

  for i in 0..9:
    var z = sample(passwordlist)
    echo z
    echo passToKey(z)


  proc passToKey2(pass:string): ByteSeq = #!PASSTOKEY
    const debug = 0b0
    expandkeyHelper = 0 #!!!!
    result = newSeq[uint8](16) #@[0.uint8,0.uint8,0.uint8,0.uint8,0.uint8,0.uint8,0.uint8,0.uint8,0.uint8,0.uint8,0.uint8,0.uint8,0.uint8,0.uint8,0.uint8, 0.uint8]
    if pass.len == 16:
      result = pass.toByteSeq()

    elif pass.len < 16:
      var c = 0
      for i in 0..(KeyLen - 1):
        result[i] = (pass[c].uint8 + i.uint8) xor pass[c].uint8
        c += 1
        if c > pass.high: c = 0

    elif pass.len > 16:
      var c = 0
      var x = 0.uint8
      for i in 0..pass.high:
        result[c] = (pass[c].uint8 + x.uint8 + i.uint8) xor result[c].uint8
        c += 1
        if c > (KeyLen - 1):
          c = 0
          x += 65


    var tres = result
    var passsalt2: uint8
    for c in 0..result.high:
      var p2x = result
      p2x.delete(c)
      for cc in 0..p2x.high:
        passsalt2 = ((passsalt2 + cc.uint8) xor p2x[cc])
      result[c] = passsalt2
    result = mxZipKeys(tres,result)



    #echo result
    result = mxKeySwapBitsRound(result)
    when debug >= 0b1: echo "K ",result
    #result = result.changeDuplicates()
    #when debug >= 0b1: echo "K ",result

    result = mxKeySwapMinors3(result)
    when debug >= 0b1: echo "K ",result

    result = mxKeyRotEnc(result)
    when debug >= 0b1: echo "K ",result

    tres = mxKeySwapMinors3(result)
    result = mxZipKeys(tres,result)
    #result = mxKeySwapMinors3(result)
    when debug >= 0b1: echo "K ",result

    result = mxKeySwapBitsEE2(result)
    when debug >= 0b1: echo "K ",result

    tres = mxKeySwapBitsRound(result)
    result = mxZipKeys(tres,result)
    #result = mxKeySwapBitsRound(result)
    when debug >= 0b1: echo "K ",result

    result = result.changeDuplicates()
    when debug >= 0b1: echo "K ",result


  var pseq:ByteSeq
  for z in passwordlist:
    echo z
    var a = passToKey2(z)
    echo a
    pseq.add(a)

  var cT = pseq.toCountTable
  var b:int
  var max:int
  var avg:int
  for a in keys(cT):
    #stdout.write fmt"{a:>3d}:{cT[a]:>3d}, "
    if cT[a] < 5:
      stdout.write "\e[32m",fmt"{a:>3d}:{cT[a]:>3d}, ", "\e[0m"
    elif cT[a] < 15:
      stdout.write "\e[37m",fmt"{a:>3d}:{cT[a]:>3d}, ", "\e[0m"
    else:
      stdout.write "\e[33m",fmt"{a:>3d}:{cT[a]:>3d}, ", "\e[0m"
    b += 1
    if b == 8:
      b = 0
      echo ""

    if cT[a] > max: max = cT[a]
    avg += cT[a]

  echo "\n\n MAX: ", max
  echo " AVG: ", avg / cT.len, "\n\n"
]#





# EXPANDER TEST - default for checking changes ------------

when keyexpandvisualizer1:
  echo "\n keyvisualizer repeat checker ---------"
  var oKey = passToKey("passw0rd")
  var tbl: ByteSeq
  var exkH:int
  tbl.add(oKey)
  for i in 0..32:#(KeyLen-2):
    drawKey(oKey)
    oKey = expandKey(oKey,exkH)
    tbl.add(oKey)
  echo ""

  exkH = 0
  oKey = passToKey("passw0rd")
  for i in 0..32:#(KeyLen-2):
    echoKey(oKey)
    oKey = expandKey(oKey,exkH)
  echo ""

  echoCountTable(tbl,-1,-1,"passw0rd keyexpandvisualizer1")

  echo "\n end keyvisualizer -------------"




when keyexpandvisualizer2:
  echo "  keyvisualizer #2 -------------"
  var tbl: ByteSeq
  var exkH:int
  for pass in passwordlist[0..50]:
    var oKey = passToKey(pass)
    tbl.add(oKey)
    for i in 0..(KeyTableRows-1):
      #drawKey(oKey)
      echoKey(oKey)
      oKey = expandKey(oKey,exkH)
      tbl.add(oKey)
    echo ""
  echoCountTable(tbl,-1,-1,"pwlist keyexpandvisualizer2")
  echo " end keyvisualizer -------------"





when keyvisualizer3:
  echo "\n keyvisualizer: algo checker ---------"
  var
    key = passToKey("passw0rd")#passToKey("passw0rd")
    oldKey = key

  for i in 0..(KeyLen - 1):
    drawKey(oldKey)
    oldKey = (mxKeySwapBitsEE2(mxKeySwapBitsRound(mxKeyRotEnc(mxKeySwapMinors3(oldKey)))))
  echo ""

  oldKey = key
  for i in 0..(KeyLen - 1):
    drawKey(oldKey)
    oldKey = mxKeySwapBitsC(mxKeyAlg1(mxKeyRotEnc(mxKeyAlg1(oldKey))))
  echo ""

  oldKey = key
  for i in 0..(KeyLen - 1):
    drawKey(oldKey)
    oldKey = (mxKeySwapBitsEE2(mxKeyAlg1(oldKey)))
  echo ""

  oldKey = key
  for i in 0..(KeyLen - 1):
    drawKey(oldKey)
    oldKey = mxKeySwapBitsE(mxKeyAlg1(mxKeyRotateLeftBits(mxKeyNot(oldKey))))
  echo ""

  oldKey = key
  for i in 0..(KeyLen - 1):
    drawKey(oldKey)
    oldKey = (mxKeyAlg1(mxKeySwapBitsRound(oldKey)))
  echo ""

  oldKey = key
  for i in 0..(KeyLen - 1):
    drawKey(oldKey)
    oldKey = mxKeySwapBitsRound(mxKeyAlg1(mxKeyRotEnc(oldKey)))
  echo ""

  echo "\n........................."
  echo ".........................\n"

  oldKey = key
  for i in 0..(KeyLen - 1):
    drawKey(oldKey)
    oldKey = mxKeySwapBitsEE2(mxKeyXor(mxKeyRotEnc(mxKeySwapMinors3(oldKey))))
  echo ""

  oldKey = key
  for i in 0..(KeyLen - 1):
    drawKey(oldKey)
    oldKey = mxKeyAlg2(mxKeyRotEnc(mxKeyRotateLeftBits(oldKey)))
  echo ""

  oldKey = key
  for i in 0..(KeyLen - 1):
    drawKey(oldKey)
    oldKey = mxKeyAlg2(mxKeySwapBitsEE2(oldKey))
  echo ""

  oldKey = key
  for i in 0..(KeyLen - 1):
    drawKey(oldKey)
    oldKey = mxKeyAlg2(mxKeyRotateLeftBits(mxKeyNot(oldKey)))
  echo ""

  oldKey = key
  for i in 0..(KeyLen - 1):
    drawKey(oldKey)
    oldKey = mxKeyAlg2(mxKeySwapBitsRound(oldKey))
  echo ""

  oldKey = key
  for i in 0..(KeyLen - 1):
    drawKey(oldKey)
    oldKey = mxKeyAlg2(mxKeyRotEnc(oldKey))
  echo ""

  echo "\n keyvisualizer: algo checker  echoKey"
  oldKey = key

  for i in 0..(KeyLen - 1):
    echoKey(oldKey)
    oldKey = (mxKeySwapBitsEE2(mxKeySwapBitsRound(mxKeyRotEnc(mxKeySwapMinors3(oldKey)))))
  echo ""

  oldKey = key
  for i in 0..(KeyLen - 1):
    echoKey(oldKey)
    oldKey = mxKeySwapBitsC(mxKeyAlg1(mxKeyRotEnc(mxKeyAlg1(oldKey))))
  echo ""

  oldKey = key
  for i in 0..(KeyLen - 1):
    echoKey(oldKey)
    oldKey = (mxKeySwapBitsEE2(mxKeyAlg1(oldKey)))
  echo ""

  oldKey = key
  for i in 0..(KeyLen - 1):
    echoKey(oldKey)
    oldKey = mxKeySwapBitsE(mxKeyAlg1(mxKeyRotateLeftBits(mxKeyNot(oldKey))))
  echo ""

  oldKey = key
  for i in 0..(KeyLen - 1):
    echoKey(oldKey)
    oldKey = (mxKeyAlg1(mxKeySwapBitsRound(oldKey)))
  echo ""

  oldKey = key
  for i in 0..(KeyLen - 1):
    echoKey(oldKey)
    oldKey = mxKeySwapBitsRound(mxKeyAlg1(mxKeyRotEnc(oldKey)))
  echo ""

  echo "\n........................."
  echo ".........................\n"

  oldKey = key
  for i in 0..(KeyLen - 1):
    echoKey(oldKey)
    oldKey = mxKeySwapBitsEE2(mxKeyXor(mxKeyRotEnc(mxKeySwapMinors3(oldKey))))
  echo ""

  oldKey = key
  for i in 0..(KeyLen - 1):
    echoKey(oldKey)
    oldKey = mxKeyAlg2(mxKeyRotEnc(mxKeyRotateLeftBits(oldKey)))
  echo ""

  oldKey = key
  for i in 0..(KeyLen - 1):
    echoKey(oldKey)
    oldKey = mxKeyAlg2(mxKeySwapBitsEE2(oldKey))
  echo ""

  oldKey = key
  for i in 0..(KeyLen - 1):
    echoKey(oldKey)
    oldKey = mxKeyAlg2(mxKeyRotateLeftBits(mxKeyNot(oldKey)))
  echo ""

  oldKey = key
  for i in 0..(KeyLen - 1):
    echoKey(oldKey)
    oldKey = mxKeyAlg2(mxKeySwapBitsRound(oldKey))
  echo ""

  oldKey = key
  for i in 0..(KeyLen - 1):
    echoKey(oldKey)
    oldKey = mxKeyAlg2(mxKeyRotEnc(oldKey))
  echo ""


#[
for pss in passwordlist:
  oKey = passToKey(pss)
  for i in 0..15:
    drawKey(oKey)
    oKey = expandKey(oKey)
  echo ""
]#



when keyvisualizer4:
  echo "  keyvisualizer #4 -------------"
  var tbl: ByteSeq
  for pass in passwordlist[0..5]:

    block:
      var oKey = passToKey(pass)
      tbl.add(oKey)
      for i in 0..(KeyTableRows-1):
        #drawKey(oKey)
        echoKey(oKey)
        oKey = mxKeyAlg1(mxKeyAlg1(changeDuplicates(oKey)))
        tbl.add(oKey)
      echo ""
      echoCountTable(tbl,-1,-1,"_mxKeyAlg1_mxKeyAlg1_changeDuplicates")
      tbl = @[]
      echo "-------------"
    block:
      var oKey = passToKey(pass)
      tbl.add(oKey)
      for i in 0..(KeyTableRows-1):
        #drawKey(oKey)
        echoKey(oKey)
        oKey = mxKeyAlg1(mxKeyAlg1(mxKeyAlg2(oKey)))
        tbl.add(oKey)
      echo ""
      echoCountTable(tbl,-1,-1,"_mxKeyAlg1_mxKeyAlg1_mxKeyAlg2")
      tbl = @[]
      echo "-------------"

    block: # 3
      var oKey = passToKey(pass)
      tbl.add(oKey)
      for i in 0..(KeyTableRows-1):
        #drawKey(oKey)
        echoKey(oKey)
        oKey = mxKeyAlg1(changeDuplicatesC2(changeDuplicatesC2(oKey)))
        tbl.add(oKey)
      echo ""
      echoCountTable(tbl,-1,-1,"_mxKeyAlg1_changeDuplicatesC2_changeDuplicatesC2")
      tbl = @[]
      echo "-------------"
    block:
      var oKey = passToKey(pass)
      tbl.add(oKey)
      for i in 0..(KeyTableRows-1):
        #drawKey(oKey)
        echoKey(oKey)
        oKey = mxKeyRotEnc(changeDuplicates(changeDuplicatesC2(oKey)))
        tbl.add(oKey)
      echo ""
      echoCountTable(tbl,-1,-1,"mxKeyRotEnc(changeDuplicates(changeDuplicatesC2")
      tbl = @[]
      echo "-------------"

    block: #5
      var oKey = passToKey(pass)
      tbl.add(oKey)
      for i in 0..(KeyTableRows-1):
        #drawKey(oKey)
        echoKey(oKey)
        oKey = changeDuplicates(mxKeyAlg1(mxKeyRotEnc(oKey)))
        tbl.add(oKey)
      echo ""
      echoCountTable(tbl,-1,-1,"_changeDuplicates_mxKeyAlg1_mxKeyRotEnc")
      tbl = @[]
      echo "-------------"
    #[ block:
      var oKey = passToKey(pass)
      tbl.add(oKey)
      for i in 0..(KeyTableRows-1):
        #drawKey(oKey)
        echoKey(oKey)
        oKey = ######(oKey)
        tbl.add(oKey)
      echo ""
      echoCountTable(tbl,-1,-1,"pwlist keyexpandvisualizer2")
      tbl = @[]
      echo "-------------"

    block: #7
      var oKey = passToKey(pass)
      tbl.add(oKey)
      for i in 0..(KeyTableRows-1):
        #drawKey(oKey)
        echoKey(oKey)
        oKey = ######(oKey)
        tbl.add(oKey)
      echo ""
      echoCountTable(tbl,-1,-1,"pwlist keyexpandvisualizer2")
      tbl = @[]
      echo "-------------"
    block:
      var oKey = passToKey(pass)
      tbl.add(oKey)
      for i in 0..(KeyTableRows-1):
        #drawKey(oKey)
        echoKey(oKey)
        oKey = ######(oKey)
        tbl.add(oKey)
      echo ""
      echoCountTable(tbl,-1,-1,"pwlist keyexpandvisualizer2")
      tbl = @[]
      echo "-------------"

    block: #9
      var oKey = passToKey(pass)
      tbl.add(oKey)
      for i in 0..(KeyTableRows-1):
        #drawKey(oKey)
        echoKey(oKey)
        oKey = ######(oKey)
        tbl.add(oKey)
      echo ""
      echoCountTable(tbl,-1,-1,"pwlist keyexpandvisualizer2")
      tbl = @[]
      echo "-------------"
    block:
      var oKey = passToKey(pass)
      tbl.add(oKey)
      for i in 0..(KeyTableRows-1):
        #drawKey(oKey)
        echoKey(oKey)
        oKey = ######(oKey)
        tbl.add(oKey)
      echo ""
      echoCountTable(tbl,-1,-1,"pwlist keyexpandvisualizer2")
      tbl = @[]
      echo "-------------"    ]#

  echo " end keyvisualizer -------------"






#[ echo "\ndrawKeyTable(oKey)"
drawKeyTable(oKey)
echo "VERTICAL:"
drawKeyTableGr(getVerticalPlane(oKey))
echo "ZIP:"
drawKeyTableGr( mxZipPlanes(getKeyTable(oKey),getVerticalPlane(oKey)) )
]#
#[ echo "CRAWL"
drawKeyTableGr(crawlPlane(oKey))
#echo crawlPlane(oKey)
for k in crawlPlane(oKey):
  echo k ]#

#[ echo "\nCRAWL2"
drawKeyTableGr(getKeyTable(crawlPlane(oKey)))
#echo crawlPlane(oKey)
for k in getKeyTable(crawlPlane(oKey)):
  echo k ]#


#[ echo "expand okey"
var kxxx: ByteSeq = oKey
for i in 0..128:
  #drawKey(kxxx)
  kxxx = expandKey(kxxx)
  echo kxxx
]#


when extratables_fa:
  block crawlpane3: #notgood but computes extra bytes
    var
      oKey, e1Key: ByteSeq # = passToKey("passw0rd")
      expandkeyHelper:int
      #e1Key,e2Key:ByteSeq
      s1s,s2s,s3s,s4s,s5s,s6s,s7s,s8s:ByteSeq # SUM
      #S,Sx:ByteSeq # SUM ARRAY
      S0b:ByteSeq
      #P:ByteSeq # SUM ARRAY
      H:ByteSeq # SUM ARRAY
    var
      buf,s1,s2,s3,s4,s5,s6, s7,s8: uint8
    for pass in passwordlist[0..50]:
      oKey = passToKey(pass)

      for ex in 0..15:
        s1 = 0
        s2 = 0
        s3 = 0
        s4 = 0
        s5 = 0
        s6 = 0

        s7 = 0
        s8 = 0

        buf = 0
        for by in 0..15:
          if ((oKey[by] and 0b1111)) >= 11.uint8:
            #stdout.write "| "
            if by < 8:
              s1 = (s1 shl 1) or 1
            else:
              s2 = (s2 shl 1) or 1
            buf += 1
          else:
            #stdout.write ". "
            if by < 8:
              s1 = (s1 shl 1)
            else:
              s2 = (s2 shl 1)

          if ((oKey[by] shr 4)) >= 11.uint8:
            #stdout.write "| "
            if by < 8:
              s3 = (s3 shl 1) or 1
            else:
              s4 = (s4 shl 1) or 1
            buf += 1
          else:
            #stdout.write ". "
            if by < 8:
              s3 = (s3 shl 1)
            else:
              s4 = (s4 shl 1)

          if ((oKey[by] shr 1) and 0b1111) >= 11.uint8:
            #stdout.write "| "
            if by < 8:
              s5 = (s5 shl 1) or 1
            else:
              s6 = (s6 shl 1) or 1
            buf += 1
          else:
            #stdout.write ". "
            if by < 8:
              s5 = (s5 shl 1)
            else:
              s6 = (s6 shl 1)
        #echo s1,",\t ",s2, ",\t ",buf
        s1 = (s1 + oKey[5])
        s2 = (s2 + oKey[5])
        s3 = (s3 + oKey[5])
        s4 = (s4 + oKey[5])
        s5 = (s5 + oKey[5])
        s6 = (s6 + oKey[5])
        s7 = (s1 xor (s5 + s3)) xor oKey[5]
        s8 = (s2 xor (s6 + s4)) xor oKey[5]
        echo fmt"{buf:>2d}| {s1:>3d}, {s2:>3d}, {s3:>3d}, {s4:>3d},  {s5:>3d}, {s6:>3d}, {s7:>3d}, {s8:>3d} " #,s1 xor oKey[15]

        H.add(buf)

        s1s.add(s1)
        s2s.add(s2)
        s3s.add(s3)
        s4s.add(s4)
        s5s.add(s5)
        s6s.add(s6)
        s7s.add(s7)
        s8s.add(s8)
        #S.add(s1 xor oKey[1])
        #R.add(s2 xor oKey[1])

        S0b.add(((oKey[0] ) and 0b11)+1)
        if e1Key.len < 256:
          e1Key.add([s1,s2,s3,s4,s5,s6,s7,s8])
        #e2Key.add(s2)
        oKey = expandKey(oKey, expandkeyHelper)

      #drawKeyTable e1Key
      echo ""
      #drawKeyTable e2Key
      #e1Key = @[]
      #e2Key = @[]

    echoCountTable(s1s,-1,-1,"s1")
    echoCountTable(s2s,-1,-1,"s2")
    echoCountTable(s3s,-1,-1,"s3")
    echoCountTable(s4s,-1,-1,"s4")
    echoCountTable(s5s,-1,-1,"s5")
    echoCountTable(s6s,-1,-1,"s6")
    echoCountTable(s7s,-1,-1,"s7")
    echoCountTable(s8s,-1,-1,"s8")
    echoCountTable(S0b,-1,-1,"0b11+1")
    echoCountTable(e1Key,-1,-1,"e1Key")
    #echoCountTable(P,-1,-1,"P EXTRABYTES POS")
    #echoCountTable(H,-1,-1,"num Hi")

    #drawKeyTable e1Key


    echo "e1Key.high ",e1Key.high
    var chunkSizeS:seq[uint16]
    for ik in 0..e1Key.high - 3:
      var chunkSize: uint16

      #[ for i in 0..3:
        chunkSize += e1Key[i+ik].uint16
      #stdout.write "[chunkSize+=] ", chunkSize
      chunkSizeS.add(chunkSize) ]#

      chunkSize = e1Key[ik].uint16
      chunkSize = chunkSize shl 2
      chunkSize += (e1Key[ik+1] and 0b11).uint16
      #echo "\t[chunkSize 10bit] ", chunkSize
      chunkSizeS.add(chunkSize)

    chunkSizeS.sort()
    echoCountTable(chunkSizeS)



when extratables_proc:#............................
  var cTbl, obiiTbl : ByteSeq
  var eKeyTbl: KeyTable
  for pass in passwordlist[0..10]:
    #var oKey = passToKey(pass)
    t0 = epochTime()
    eKeyTbl = makeExtraTables(pass)
    echo pass," Elapsed Time: ", epochTime() - t0
    for k in eKeyTbl:
      cTbl.add(k)
      echoKey k

      for obii in k:
        obiiTbl.add(obii and 0b11)
    echo "|"

  echoCountTable(cTbl)
  echoCountTable(obiiTbl)








when avg_diffusion_test:
  block:
    var cTbl: seq[int]
    var eKeyTbl: KeyTable
    for pass in passwordlist:# [0..10]:

      var pBs = pass.toByteSeq()
      var adiff:int
      for i in 0..pBs.high-1:
        if pBs[i] > pBs[i+1]:
          adiff += (pBs[i] - pBs[i+1]).int
        else:
          adiff += (pBs[i+1] - pBs[i]).int
      echo pass, " ",adiff div pass.len
      cTbl.add(adiff div pass.len)

    echoCountTable(cTbl,-1,-1,"avg passw diffusion test")

when avg_diffusion_test:
  block:
    var cTbl: seq[int]
    var eKeyTbl: KeyTable
    for pass in passwordlist:# [0..10]:

      var pBs = pass.passToKey()
      var adiff:int
      for i in 0..pBs.high-1:
        if pBs[i] > pBs[i+1]:
          adiff += (pBs[i] - pBs[i+1]).int
        else:
          adiff += (pBs[i+1] - pBs[i]).int
      echo pass, " ",adiff div pass.len
      cTbl.add(adiff div pass.len)

    echoCountTable(cTbl,-1,-1,"avg passtokey diffusion test")


#[
# 0bxx test for functions
var oKey = passToKey("passw0rd")
var
  counter:array[0..3,int]
  buf: uint8
for i in 0..15:
  for b in countup(0,6,2):
    buf = ((oKey[i] shr b) and 0b11)
    counter[buf] += 1
echo counter

for p in passwordlist:
  oKey = passToKey(p)
  echo oKey
  #[ counter = [0,0,0,0]
  for i in 0..15:
    for b in countup(0,6,2):
      buf = ((oKey[i] shr b) and 0b11)
      counter[buf] += 1
  echo p, "\t\t", counter ]#
]#



#[
import tables
block byteinc_analysis:
  var
    oKey: ByteSeq # = passToKey("passw0rd")
    R:ByteSeq # SUM
    S:ByteSeq # SUM ARRAY
  var
    counter:array[0..15,int]
    buf: uint8
  for pass in passwordlist:
    oKey = passToKey(pass)
    for ex in 0..15:
      counter = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0]
      for i in 0..15:
        buf = ((oKey[i] and 0b1111) )
        counter[buf] += 1
        R.add(buf)
      oKey = expandKey(oKey)
    echo counter
    S.add(0)
    for v in counter:
      #S[S.high] += v.uint8
      #if v == 0: S[S.high] += 1
      if v >= 2: S[S.high] += 1

  echoCountTable(R,75,100)
  echoCountTable(S,75,100)

]#

#[
import tables
block byteinc_analysis:
  var
    oKey: ByteSeq # = passToKey("passw0rd")
    R:ByteSeq # SUM
    S:ByteSeq # SUM ARRAY
    P:ByteSeq # SUM ARRAY
    inserted:bool=false
    insertNum:int
  var
    counter:array[0..15,int]
    buf,s1,s2: uint8
  for pass in passwordlist:
    oKey = passToKey(pass)
    counter = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0]
    s1 = 0
    s2 = 0
    inserted = false
    for ex in 0..15:
      buf = ((oKey[ex] and 0b1111))
      #echo buf
      #R.add(buf)
      #counter[buf] += 1 #freq

      if buf >= 11.uint8:
        stdout.write "| "
        if ex < 8:
          s1 = (s1 shl 1) or 1
        else:
          s2 = (s2 shl 1) or 1
        P.add(ex.uint8)
        if not inserted:
          insertNum = ex
          inserted = true
      else:
        stdout.write ". "
        if ex < 8:
          s1 = (s1 shl 1)
        else:
          s2 = (s2 shl 1)
      #if buf > 8.uint8: counter[ex] += 1
      #[ for i in 0..15:
        counter = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0]
        buf = ((oKey[i] and 0b1111) )
        counter[buf] += 1
        R.add(buf) ]#

      #oKey = expandKey(oKey)
      #[ if (testBit(ex,0)):
        oKey = mxKeySwapMinors(expandKey(oKey) )
      else:
        oKey = expandKey(oKey) ]#

      #echo counter
    echo s1,",\t ",s2, ",\t ",insertNum + 1
    S.add(s1)
    R.add(s2)
    #[ for v in counter:
      if v == 0:
        stdout.write "\e[0m",v,", "
      elif v <= 2:
        stdout.write "\e[33m",v,", "
      else:
        stdout.write "\e[35m",v,", "
    echo "\e[0m"

    S.add(0)
    #[ for v in counter:
      #S[S.high] += v.uint8
      if v == 0: S[S.high] += 1
      #if v > 0: S[S.high] += 1 ]#
    for v in 0..counter.high-1:
      if counter[v] < counter[v+1]: S[S.high] += 1
    echo S[S.high]
    S[S.high] -= 1
    echo ""
]#
  echoCountTable(R,2,4)
  echoCountTable(S,2,4)
  echoCountTable(P,20,40)

]#



#[
import tables
block bitfreq_analysis:
  var
    oKey: ByteSeq # = passToKey("passw0rd")
    R:ByteSeq
  var
    counter:array[0..7,int]
    buf: uint8
  for pass in passwordlist:
    oKey = passToKey(pass)
    for ex in 0..15:
      for by in 0..oKey.high:
        for i in countdown(7,0):
          if testBit(oKey[by],i): counter[i] += 1
          R.add(i.uint8)
      oKey = expandKey(oKey)
    echo counter

  var cT = toCountTable(R)
  var max:int
  var avg:int
  var b:int
  for a in keys(cT):
    #stdout.write fmt"{a:>3d}:{cT[a]:>3d}, "
    if cT[a] < 75:
      stdout.write "\e[32m",fmt"{a:>3d}:{cT[a]:>3d}, ", "\e[0m"
    elif cT[a] < 100:
      stdout.write "\e[37m",fmt"{a:>3d}:{cT[a]:>3d}, ", "\e[0m"
    else:
      stdout.write "\e[33m",fmt"{a:>3d}:{cT[a]:>3d}, ", "\e[0m"
    b += 1
    if b == 8:
      b = 0
      echo ""

    if cT[a] > max: max = cT[a]
    avg += cT[a]

  echo "\n\n MAX: ", max
  echo " AVG: ", avg / cT.len, "\n\n"
]#


# KEY ATTACK -------------------------------------
#[ block ATTACK:
echo "\n[KEYATTACK]\n"
var p = passToKey("2222abcd")
var enc = encode(val,p)
var dec = decode(enc,p)
var res: ByteSeq

echo "********************************************"
echo " decoding with right key - succes is: ", val == dec
echo "********************************************"

var numSucc, numFail,  maxSumFail,sumFail: int
var printed = false
var oke:bool=true
for i in 0..p.high:
  for b in 0..7:
    var p2 = p
    #echo toBin(p[i].int, 16)
    flipBit(p2[i],b)
    #echo toBin(p[i].int, 16)
    dec = decode(enc,p2)
    #echo dec[dec.high]

    sumFail = 0
    oke = true

    for i in 0..dec.high:
      #if dec[i] != val[i]: oke = false
      if dec[i] == val[i]:
        oke = false
        sumFail += 1

    if not oke:
      numFail += 1
      if sumFail > maxSumFail:
        maxSumFail = sumFail
        res = dec
    if oke: numSucc += 1

if maxSumFail > 0:
  echo "\nDECODED & FAILURE\n"
  for i in 0..res.high:
    if res[i] == val[i]:
      stdout.write "\e[33m",fmt"{res[i]:3d} ","\e[0m"
    else:
      stdout.write fmt"{res[i]:3d} "
    if i mod 16 == 0: echo ""
  echo ""
  printed = true

echo "Success: ", numSucc, " - ", numSucc / (p.len * 8) * 100, "%"
echo "\e[33m","FAIL   : ", numFail, " - ", numFail / (p.len * 8) * 100, "%  maxDecoded: ",maxSumFail," ", (maxSumFail / val.len) * 100,"%","\e[0m"
echo "----------------------------------------------------"
]#

#[
block KEYATTACK_DUO:
  echo "\n[KEYATTACK DUO]\n"
  var passw = "2222abcd"
  var theKey = passToKey(passw)

  echo "\n [encode - decode test]"
  var t0 = epochTime()
  var valOrigi = val
  encode(val, 
          theKey,"passw0rd",
          150)
  echo "Encoding Elapsed Time: ", epochTime() - t0


  let enc = val


  t0 = epochTime()
  decode(val, 
          theKey,"passw0rd",
          150)
  echo "Decoding Elapsed Time: ", epochTime() - t0


  var oke:bool=true
  if valOrigi.len == val.len:
    for i in 0..val.high:
      if valOrigi[i] != val[i]: oke = false
  else:
    oke = false

  echo "********************************************"
  echo " decoding with right key - succes is: ", oke
  echo "********************************************"




  var totalFail: int
  var passFail:string
  let listSize = 30
  for pass in passwordlist[0..listSize-1]:
    var res: ByteSeq
    var avgFail, bitOfFail:int
    var numSucc, numFail,  maxSumFail,sumFail: int
    oke = true
    theKey = pass.passToKey
    val = valOrigi
    encode(val, 
        theKey,pass,
        150)
    #for i in 0..theKey.high:
    for i in 0..pass.high:
      for b in 0..7:
        #var p2 = theKey
        var p2 = pass
        var p3:uint8 = p2[i].uint8
        flipBit(p3,b)
        p2[i] = p3.char
        #flipBit(p2[i],7-b) #?EXP
        decode(val, 
              #p2.toString.passToKey, p2.toString,
              p2.passToKey, p2,
              150)

        sumFail = 0
        oke = true

        for i in 0..valOrigi.high-1:
          if valOrigi[i] == val[i] and valOrigi[i+1] == val[i+1]:
            oke = false
            sumFail += 1
            numFail += 1

        for i in 0..valOrigi.high-2:
          if valOrigi[i] == val[i] and
            valOrigi[i+1] == val[i+1] and
            valOrigi[i+2] == val[i+2]:
                echo (val[i..i+2].toString)
                quit(" -= TRIX_FAILURE =- ")

        if not oke:
          if sumFail > maxSumFail:
            maxSumFail = sumFail
            passFail = pass
            bitOfFail = (i * 8) + (b + 1)
        if oke: numSucc += 1

        avgFail += sumFail

    #[ if maxSumFail > 0:
      echo "\nDECODED & FAILURE\n"
      for i in 0..res.high:
        if res[i] == val[i]:
          stdout.write "\e[33m",fmt"{res[i]:3d} ","\e[0m"
        else:
          stdout.write fmt"{res[i]:3d} "
        if i mod 16 == 0: echo ""
      echo "" ]#

    if maxSumFail > 0:
      echo "\e[33m"
    else:
      echo "\e[36m"
    echo "Success: ", numSucc, " - ", numSucc / (pass.len * 8) * 100, "%"
    echo "Total fails   : ", numFail, " - ", numFail / (pass.len * 8) * 100, "%  \nMax Decoded: ",maxSumFail," ", (maxSumFail / val.len) * 100,"%","\e[0m"

    if maxSumFail > 0:
      echo "Average Fail: ", avgFail / (pass.len * 8)
      echo "val to p.len ratio: ", val.len / pass.len, " / failures: ", (val.len / pass.len) * (avgFail / (pass.len * 8))
      echo "no. of bit causing failure: ", bitOfFail, "  ", bitOfFail div 8 + 1, "  ", bitOfFail mod 8
      echo pass
      echo theKey
      totalFail += 1

  echo "\n============================="
  echo "total failures: ", totalFail, " (", fmt"{totalFail / listSize * 100:3.2f}", "%)"
  echo "passFail: ",passFail
  echo "----------------------------------------------------------"








block RAINBOWATTACK_DUO:
  echo "\n[RAINBOW]\n"
  var passw = "1234567"
  var theKey = passToKey(passw)

  echo "\n [encode - decode test]"
  var t0 = epochTime()
  var valOrigi = val
  encode(val, 
          theKey,passw,
          150)
  echo "Encoding Elapsed Time: ", epochTime() - t0


  let enc = val


  t0 = epochTime()
  decode(val, 
          theKey,passw,
          150)
  echo "Decoding Elapsed Time: ", epochTime() - t0


  var oke:bool=true
  if valOrigi.len == val.len:
    for i in 0..val.high:
      if valOrigi[i] != val[i]: oke = false
  else:
    oke = false

  echo "********************************************"
  echo " decoding with right key - succes is: ", oke
  echo "********************************************"


  encode(val, 
        theKey,passw,
        150)

  var totalFail: int
  var passFail:string
  var pE: ByteSeq
  let listSize = passwordlist.len

  for pass in passwordlist[0..listSize-1]:
    if pass == passw: continue
    var res: ByteSeq
    var avgFail, bitOfFail:int
    var numSucc, numFail,  maxSumFail,sumFail: int
    oke = true
    theKey = pass.passToKey

    val = enc
    decode(val, 
          theKey, pass,
          150)

    sumFail = 0
    oke = true

    if val == valOrigi:
      echo "\n\e[31m<<<<<< -= DECODED =- >>>>>>\e[0m"
      oke = false
      sumFail += val.len
      numFail += val.len
    else:
      for i in 0..valOrigi.high-1:
        if valOrigi[i] == val[i] and valOrigi[i+1] == val[i+1]:
          oke = false
          sumFail += 1
          numFail += 1
        #[ elif dec[i] == val[i]:
          numFail += 1 ]#
      for i in 0..valOrigi.high-2:
        if valOrigi[i] == val[i] and
            valOrigi[i+1] == val[i+1] and
            valOrigi[i+2] == val[i+2]:
              #quit(" -= TRIX_FAILURE =- ")
              echo "\n\e[31m -= TRIX_FAILURE =- \e[0m"
              sleep(500)

    if not oke:
      #numFail += 1
      if sumFail > maxSumFail:
        maxSumFail = sumFail
        #res = dec
        #pE = pass
        passFail = pass
    if oke: numSucc += 1

    avgFail += sumFail



    if maxSumFail > 0:
      echo "\e[33m","FAIL: ",pass,"\e[0m"
      totalFail += 1
    else:
      echo "\e[36m","Success\e[0m"


  echo "\n============================="
  echo "total failures: ", totalFail, " (", fmt"{totalFail / listSize * 100:3.2f}", "%)"
  echo "passFail: ",passFail
  echo pE
  echo "------------------------------------------------------------------"

]#







#[
block PASALT2:

  var passsalt2: uint8
  var p3ct: ByteSeq
  var p3x = passToKey("111111111111111111111111111111111111111111111111111")
  #var p3x = toByteSeq("111111111111111111111111111111111111111111111111111")
  var p2xi = 2.uint8
  for c in 0..p3x.high:
    var p2x = p3x
    p2x.delete(c)
    for cc in 0..p2x.high:
      passsalt2 = ((passsalt2 + cc.uint8) xor p2x[cc])
    #echo "\n>>> ", passsalt2
    p3ct.add(passsalt2)

  passsalt2 = 0
  var cT = p3ct.toCountTable
  var b:int
  for a in keys(cT):
    stdout.write fmt"{a:>3d}:{cT[a]:>2d},  "
    b += 1
    if b == 5:
      b = 0
      echo ""

    passsalt2 = passsalt2 xor a.uint8
  echo "\n>>> ", passsalt2
]#

#[
block PASALT3:

var passsalt2: uint8
var p3ct: ByteSeq
var p3x = passToKey("111111111111111111111111111111111111111111111111111")
#var p3x = toByteSeq("111111111111111111111111111111111111111111111111111")
var p2xi = 2.uint8
for c in 0..p3x.high:
  var p2x = p3x
  p2x.delete(c)
  for cc in 0..p2x.high:
    passsalt2 = ((passsalt2 + cc.uint8) + p2x[cc])
  echo "\n>>> ", passsalt2
  p3ct.add(passsalt2)

passsalt2 = 0
var cT = p3ct.toCountTable
var b:int
for a in keys(cT):
  stdout.write fmt"{a:>3d}:{cT[a]:>2d},  "
  b += 1
  if b == 5:
    b = 0
    echo ""

  #passsalt2 = passsalt2 xor a.uint8
#echo "\n>>> ", passsalt2

]#



#[

block bitciph:
var
  a = toByteSeq("1111")
  k1 = passToKey("1111")
  b: uint8

echo a
for i in 0..a.high:
  if testBit(k1[i],7):
    a[i] = bitnot(a[i].int).uint8
  if testBit(k1[i],6):
    a[i] = reverseBits(a[i]).uint8
  if testBit(k1[i],5):
    a[i] = rotateRightBits(a[i],3).uint8
  if testBit(k1[i],4):
    flipBit(a[i],0)
    flipBit(a[i],3)
    flipBit(a[i],6)
  if testBit(k1[i],3):
    flipBit(a[i],1)
    flipBit(a[i],4)
    flipBit(a[i],5)
  if testBit(k1[i],2):
    flipBit(a[i],2)
    flipBit(a[i],7)
  if testBit(k1[i],1):
    a[i] = swapBitsA(a[i])
  if testBit(k1[i],0):
    a[i] = swapBitsC(a[i])
echo a


for i in 0..a.high:
  if testBit(k1[i],0):
    a[i] = swapBitsC(a[i])
  if testBit(k1[i],1):
    a[i] = swapBitsA(a[i])
  if testBit(k1[i],2):
    flipBit(a[i],2)
    flipBit(a[i],7)
  if testBit(k1[i],3):
    flipBit(a[i],1)
    flipBit(a[i],4)
    flipBit(a[i],5)
  if testBit(k1[i],4):
    flipBit(a[i],0)
    flipBit(a[i],3)
    flipBit(a[i],6)
  if testBit(k1[i],5):
    a[i] = rotateLeftBits(a[i],3).uint8
  if testBit(k1[i],6):
    a[i] = reverseBits(a[i]).uint8
  if testBit(k1[i],7):
    a[i] = bitnot(a[i].int).uint8

echo a

]#



#[   block algotest:
  var z: uint8 = 0b01111000
  echo z

  z.flipBit(0)
  echo z
  z.flipBit(4)
  echo z

  echo z xor 0b00010001 ]#



#*        ###    ######## ########
#*       ## ##      ##       ##
#*      ##   ##     ##       ##
#*     ##     ##    ##       ##
#*     #########    ##       ##
#*     ##     ##    ##       ##
#*     ##     ##    ##       ##



when KEYATTACK_COMP1:
  block KEYATTACK_COMP1:
    echo "\n[KEYATTACK_COMP1]______________________________\n"


    KeyLen = 16
    var passw = "passw0rd"
    var theKey = passToKey(passw)

    echo "\n [encode - decode test]"
    var t0 = epochTime()
    var valOrigi = val
    encode(val, 
            theKey,passw,
            150)
    echo "Encoding Elapsed Time: ", epochTime() - t0



    #[ var oke:bool=true
    for i in 0..val.high:
      if valOrigi[i] != val[i]: oke = false
      if i mod 16 == 0: stdout.write valOrigi[i], " == ", val[i],"| "
    stdout.write "\n"
    echo "********************************************"
    echo " decoding with right key - succes is: ", oke
    echo "********************************************"
    sleep(200) ]#
    #let enc = val


    t0 = epochTime()
    decode(val, 
            theKey,passw,
            150)
    echo "Decoding Elapsed Time: ", epochTime() - t0


    var oke:bool=true
    for i in 0..val.high:
      if valOrigi[i] != val[i]: oke = false
      if i mod 16 == 0: stdout.write valOrigi[i], " == ", val[i],"| "
    stdout.write "\n"
    echo "********************************************"
    echo " decoding with right key - succes is: ", oke
    echo "********************************************"
    sleep(200)



    let listSize = 30 # passwordlist.high #def:30
    var plaintextlen:int
    for pT in 0..plaintextlist.high:
      plaintextlen += plaintextlist[pT].len

    var failPos = newSeq[tuple[pchar,pbit,vpos:int]](3)
    var totalFail: int
    var passFail, passByteFail:string

    var bitOfFail:int
    var numSucc, totalFails,  maxSumFail,sumFail: int

    var hardFailures:int

    var totalByteFails, totalBytes, byteFails, maxByteFails:int

    let mode = 0

    for pass in passwordlist[0..listSize]:
      oke = true
      KeyLen = 16
      theKey = pass.passToKey
      byteFails = 0

      #[ var passBS = pass.toByteSeq()
      var avgDiff:int
      for i in 0..passBS.high-1:
        if passBS[i] > passBS[i+1]:
          avgDiff += (passBS[i] - passBS[i+1]).int
        else:
          avgDiff += (passBS[i+1] - passBS[i]).int
      avgDiff = avgDiff div passBS.len ]#

      echo "\e[33m",pass, " - Len: ", pass.len,#[ " - diff: ",avgDiff, ]# "\e[0m"
      echo "\e[33m",theKey, "\e[0m"

      for testval in plaintextlist:

        failPos = @[]


        valOrigi = testval.toByteSeq
        val = valOrigi

        encode(val, 
            theKey,pass,
            150)

        sumFail = 0
        for iP in 0..pass.high:
          var mode3break = false
          for iB in 0..7:

            var p2 = pass

            if mode == 3: # total wrong pass
              if mode3break: break
              var p4 = pass.toByteSeq
              for p4I in 0..p4.high:# - (p4.high - 2):
                p4[p4I] = bitnot(p4[p4I])
              p2 = p4.toString
              mode3break = true
            else:
              var p3:uint8 = p2[iP].uint8 #* mode 0

              flipBit(p3,iB) # mode 0 & 2
              if mode == 2: # flip 2 bits
                if iB == 0:
                  flipBit(p3,5)
                else:
                  flipBit(p3,0)

              p2[iP] = p3.char

            KeyLen = 16
            decode(val, 
                  p2.passToKey, p2,
                  150)

            for iV in 0..valOrigi.high:
              totalBytes += 1
              if valOrigi[iV] == val[iV]:
                totalByteFails += 1
                byteFails += 1
              if byteFails > maxByteFails:
                maxByteFails = byteFails
                passByteFail = pass
            #var newline1: bool = false
            for iV in 0..valOrigi.high-1:
              if valOrigi[iV] == val[iV] and valOrigi[iV+1] == val[iV+1]:
                failPos.add((pchar:iP,pbit:iB,vpos:iV))

                stdout.write val[iV].chr, val[iV+1].chr
                #[ if not newline1:
                  stdout.write val[iV].chr, val[iV+1].chr
                else:
                  stdout.write val[iV+1].chr ]#
                #newline1 = true
                stdout.write " - ",iP,",",iB,",",iV," \t",toBin(pass[iP].BiggestInt,8)," ",toBin(p2[iP].BiggestInt,8),"\n"

                sumFail += 2
                totalFails += 2

                if sumFail > maxSumFail:
                  maxSumFail = sumFail
                  passFail = pass
                  bitOfFail = (iP * 8) + (iB + 1)
            #if newline1: stdout.write " - ",iP,"\n"

            var newline2: bool = false
            for iV in 0..valOrigi.high-2:
              if valOrigi[iV] == val[iV] and
                valOrigi[iV+1] == val[iV+1] and
                valOrigi[iV+2] == val[iV+2]:
                    if not newline2:
                      stdout.write val[iV..iV+2].toString, " - ",iP,",",iB,"  ",toBin(p2[iP].BiggestInt,8), "\e[1;31m -= TRIPLE_FAILURE =- \e[0m\n"
                      #quit(" -= TRIX_FAILURE =- ")
                      newline2 = true
                    else:
                      stdout.write val[iV+2].chr
            if newline2: stdout.write "\n"

            #if oke: numSucc += 1


        if failPos.len > 0:
          for fpI in 0..failPos.high:
            for fpIb in 0..failPos.high:
              if fpI == fpIb: continue
              if failPos[fpI] == failPos[fpIb]:
                echo "\e[1;31m",fmt"FAIL: {pass} {failPos[fpI]}\e[0m"
                oke = false
                hardFailures += 1
        if not oke:
          discard
        else:
          echo "\e[1;32mSUCCESS\e[0m  byteFails: ",
            byteFails, "/", (val.len * pass.len * 8), " ",
            formatFloat(((byteFails / (val.len * pass.len * 8)) * 100),ffDefault,2),"%"


    echo "\n============================="
    #[ var plaintextlen:int
    for pT in 0..plaintextlist.high:
      plaintextlen += plaintextlist[pT].len ]#
    plaintextlen = plaintextlen * (listSize + 1)

    var totPtRat = totalFails / plaintextlen * 100
    if hardFailures > 0:
      stdout.write "\e[1;31m"
    else:
      stdout.write "\e[1;32m"
    echo "HARD FAILURE: ",hardFailures ,"\e[0m"

    echo "max identicals found: \e[1;33m",maxSumFail," : ", passFail,"\e[0m"

    echo "total identicals found: \e[1;36m",totalFails,"\e[0m in ",plaintextlen," \e[1;33m", fmt"{totPtRat:3.2f}%", " \e[0m"

    echo "byte fails: ",totalByteFails, "/",totalBytes," ", "\e[1;33m",formatFloat(((totalByteFails / totalBytes) * 100),ffDefault,4), "%\e[0m"
    echo "max byte fails: \e[1;35m",maxByteFails, " : ", passByteFail,"\e[0m"

    echo "----------------------------------------------------------"







when keyvisualizer4:
  var password = "passw0rd"
  var tbl: seq[uint8]
  for i in 0..password.high:
    for bi in 0..7:
      var p2 = password.toByteSeq()
      flipBit(p2[i],bi)

      var x = passToKey(p2.toString())
      echo x

      tbl.add(x)
  echoCountTable(tbl)






when keygenprocgen:
  var newKey:ByteSeq


  let
    procs =[
      mxKeyAlg2,
      mxKeyAlg1,
      mxKeyNot,
      mxKeyReverse,
      mxKeyReverseBits,
      mxKeyRotEnc,
      mxKeyRotateLeftBits,
      mxKeySwapBitsA,
      mxKeySwapBitsE,
      mxKeySwapBitsC, # 10
      mxKeySwapBitsEE2,
      mxKeySwapBitsRound,
      mxKeySwapMinors,
      mxKeySwapMinors2,
      mxKeySwapMinors3,
      mxKeyXor,
      mxKeyXorB,
      mxKeyXorR,
      mxKeyXorRR,
      mxKeyAddRR,
      changeDuplicates,
      changeDuplicatesC,
      changeDuplicatesC2, # 20
      changeDuplicatesB,
      mxKeySwapBitsB,
      mxKeySwapBitsD,
      mxKeySwapBitsF,
      mxKeySwapBitsG,
      mxKeyByBitEnc
    ]
    procnames =[
      "mxKeyAlg2",
      "mxKeyAlg1",
      "mxKeyNot",
      "mxKeyReverse",
      "mxKeyReverseBits",
      "mxKeyRotEnc",
      "mxKeyRotateLeftBits",
      "mxKeySwapBitsA",
      "mxKeySwapBitsE",
      "mxKeySwapBitsC",
      "mxKeySwapBitsEE2",
      "mxKeySwapBitsRound",
      "mxKeySwapMinors",
      "mxKeySwapMinors2",
      "mxKeySwapMinors3",
      "mxKeyXor",
      "mxKeyXorB",
      "mxKeyXorR",
      "mxKeyXorRR",
      "mxKeyAddRR",
      "changeDuplicates",
      "changeDuplicatesC",
      "changeDuplicatesC2",
      "changeDuplicatesB",
      "mxKeySwapBitsB",
      "mxKeySwapBitsD",
      "mxKeySwapBitsF",
      "mxKeySwapBitsG",
      "mxKeyByBitEnc"
    ]
  const procnum = 2

  var
    pr: array[0..procnum-1,tuple[step: bool, current: int]]
    prstring = ""
    keyTable: ByteSeq
    theTable: KeyTable
    was: ByteSeq
    countt,maxCountt,sumCountt: int
    minMaxCount: int = 65535
    minMaxStr: string
    avg,avg2:int
    rf:File
    minprocnum = 0 #!
    limit,limitt = 0
  rf = open("keygenprocgen-Cm3-" & $procnum & ".csv",fmWrite)
  #for pass in passwordlist[0..40]:
  avg = 9
  block:
    block gen:
      #theKey = passToKey(pass)
      randomize()
      minMaxCount = 65535
      avg = 0 #(10 * 16 * 16 ) div 2
      for pn in 0..procnum-1:
        pr[pn].step = false
        pr[pn].current = 0
      for pass in passwordlist[0..50]:
          theTable.add( passToKey(pass) )

      while true:
        prstring = ""
        #newKey = theKey
        #keyTable = @[]

        for pn in 0..procnum-1:
          prstring = procnames[pr[pn].current] & "(" & prstring & ")"
        stdout.write prstring

        maxCountt = 0
        sumCountt = 0
        for tti in 0.. theTable.high:
          newKey = theTable[tti]
          was = @[]
          keyTable = @[]
          for ti in 0..15: #!15
            for pn in 0..procnum-1:
              newKey = procs[pr[pn].current](newKey)
            keyTable.add(newKey)
          for c in 0 .. keyTable.high:
            if not (keyTable[c] in was):
              was.add(keyTable[c])
              countt = 0
              for cc in c .. keyTable.high:
                if c == cc: continue
                if keyTable[c] == keyTable[cc]:
                  countt += 1
                  sumCountt += 1
                  if countt > maxCountt:
                    maxCountt = countt

        for pn in minprocnum .. procnum-1:
          if pr[pn].step or pn == procnum - 1:# last always
            pr[pn].current += 1
            if pr[pn].current > procs.high:
              if pn == minprocnum: break gen #!
              pr[pn].current = 0
              if pn != 0:
                pr[pn-1].step = true
            if pn < procnum - 1:
              pr[pn].step = false

        if minprocnum > 0:
          for pn in 0..minprocnum:
            pr[pn].current = rand(procs.high)

        #[ for pn in 0..procnum-1:
          pr[pn].current = rand(procs.high)

        limit += 1
        if limit > 1_000_000: break ]#


            #echo countt
        echo " - ", maxCountt, " ", sumCountt
        if sumCountt <= avg2: avg2 = sumCountt
        if maxCountt <= avg: avg = maxCountt

        if maxCountt <= avg or avg == 0 or sumCountt <= avg2: #15:
          rf.writeLine(#[ pass, ",", ]# prstring & "," & $maxCountt & "," & $sumCountt)
          rf.flushFile()
          #avg = maxCountt
          #avg = avg div 2

        #[ if minMaxCount > maxCountt:
          minMaxCount = maxCountt
          minMaxStr = prstring

    echo ":::", minMaxStr, " - ", minMaxCount ]#
  rf.close()
















when keyexpprocgen:
  var newKey:ByteSeq





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


#[
  proc kexproc7(a:ByteSeq):ByteSeq= #*
    result = changeDuplicates(changeDuplicatesC2(a))

  proc kexproc8(a:ByteSeq):ByteSeq=
    result = changeDuplicatesC2(mxKeyAlg2(a))

  proc kexproc9(a:ByteSeq):ByteSeq=
    result = changeDuplicatesC2(changeDuplicatesC2(a))


  proc kexproc10(a:ByteSeq):ByteSeq=
    result = mxKeyAlg2(changeDuplicatesC2(a))

  proc kexproc11(a:ByteSeq):ByteSeq=
    result = mxKeyAlg2(changeDuplicates(a))


  proc kexproc12(a:ByteSeq):ByteSeq=
    result = mxKeySwapMinors3(mxKeyAlg1(a))
  proc kexproc13(a:ByteSeq):ByteSeq=
    result = mxKeySwapMinors3(mxKeyAlg2(a))
  proc kexproc14(a:ByteSeq):ByteSeq=
    result = changeDuplicatesC2(mxKeySwapMinors3(a))

  proc kexproc01(a:ByteSeq):ByteSeq=
    result = changeDuplicates(changeDuplicatesC2(a))
  proc kexproc02(a:ByteSeq):ByteSeq=
    result = changeDuplicatesC2(changeDuplicatesB(a))
  proc kexproc03(a:ByteSeq):ByteSeq=
    result = mxKeySwapBitsF(changeDuplicates(a)) ]#

#[
  proc kexprocIII1(a:ByteSeq):ByteSeq=
    result = mxKeyAlg2(changeDuplicates(mxKeyAlg1(a)))
  proc kexprocIII2(a:ByteSeq):ByteSeq=
    result = mxKeyAlg1(mxKeyAlg1(changeDuplicates(a)))
  proc kexprocIII3(a:ByteSeq):ByteSeq=
    result = mxKeyAlg2(mxKeyAlg1(mxKeyAlg2(a)))
  proc kexprocIII4(a:ByteSeq):ByteSeq=
    result = mxKeyAlg1(changeDuplicatesC2(changeDuplicatesC2(a)))


  proc kexprocIII5(a:ByteSeq):ByteSeq=
    result = mxKeyAlg1(mxKeySwapBitsF(changeDuplicatesC2(a)))
  proc kexprocIII6(a:ByteSeq):ByteSeq=
    result = mxKeyRotEnc(changeDuplicates(changeDuplicatesC2(a)))
  proc kexprocIII7(a:ByteSeq):ByteSeq=
    result = changeDuplicates(mxKeyAlg1(mxKeyRotEnc(a)))
  proc kexprocIII8(a:ByteSeq):ByteSeq=
    result = mxKeyAlg2(mxKeyAlg1(changeDuplicates(a)))


  proc kexprocIII9(a:ByteSeq):ByteSeq=
    result = mxKeyAlg2(changeDuplicates(mxKeyAlg2(a)))
  proc kexprocIII10(a:ByteSeq):ByteSeq=
    result = mxKeyRotEnc(changeDuplicatesC2(mxKeyAlg1(a)))
  proc kexprocIII11(a:ByteSeq):ByteSeq=
    result = mxKeySwapMinors3(changeDuplicates(changeDuplicates(a)))
  proc kexprocIII12(a:ByteSeq):ByteSeq=
    result = changeDuplicates(mxKeyRotEnc(mxKeyAlg1(a)))



  proc kexprocIII13(a:ByteSeq):ByteSeq=
    result = mxKeyAlg2(mxKeyAlg2(changeDuplicates(a)))
  proc kexprocIII14(a:ByteSeq):ByteSeq=
    result = mxKeyAlg2(changeDuplicates(changeDuplicatesC2(a)))
  proc kexprocIII15(a:ByteSeq):ByteSeq=
    result = mxKeyAlg1(mxKeyAlg1(changeDuplicatesC2(a)))
  proc kexprocIII16(a:ByteSeq):ByteSeq=
    result = mxKeyAlg1(mxKeyAlg1(mxKeyAlg2(a)))



  proc kexprocIII17(a:ByteSeq):ByteSeq=
    result = mxKeyAlg2(changeDuplicates(changeDuplicatesC2(a)))
  proc kexprocIII18(a:ByteSeq):ByteSeq=
    result = mxKeyRotEnc(changeDuplicates(mxKeyAlg2(a)))
  proc kexprocIII19(a:ByteSeq):ByteSeq=
    result = mxKeyRotateLeftBits(changeDuplicates(mxKeyAlg2(a)))
  proc kexprocIII20(a:ByteSeq):ByteSeq=
    result = mxKeyRotateLeftBits(mxKeyAlg1(changeDuplicatesC2(a)))
]#
#[
  proc kexprocIII1(a:ByteSeq):ByteSeq=
        result = mxKeyXor(changeDuplicatesB(mxKeyReverseBits(a)))

  proc kexprocIII2(a:ByteSeq):ByteSeq=
        result = mxKeyXor(mxKeySwapBitsG(changeDuplicatesC(a)))
        #result = mxKeySwapBitsG(mxKeyXor(changeDuplicatesC(a)))

  proc kexprocIII3(a:ByteSeq):ByteSeq=
        result = mxKeyNot(mxKeyRotateLeftBits(mxKeySwapBitsE(a)))
        #result = mxKeyNot(mxKeySwapBitsE(mxKeyRotateLeftBits(a)))
        #result = mxKeyRotateLeftBits(mxKeySwapBitsE(mxKeyNot(a)))
        #result = mxKeyRotateLeftBits(mxKeyNot(mxKeySwapBitsE(a)))

  proc kexprocIII4(a:ByteSeq):ByteSeq=
        result = mxKeySwapBitsA(mxKeyXoRR(mxKeyNot(a)))

  proc kexprocIII5(a:ByteSeq):ByteSeq=
        result = mxKeySwapBitsA(changeDuplicatesB(changeDuplicatesC2(a)))

  proc kexprocIII6(a:ByteSeq):ByteSeq=
        result = mxKeySwapMinors2(changeDuplicates(changeDuplicatesC(a)))

  proc kexprocIII7(a:ByteSeq):ByteSeq=
        result = mxKeyXor(changeDuplicatesC2(changeDuplicatesC(a)))

  proc kexprocIII8(a:ByteSeq):ByteSeq=
        result = mxKeyAddRR(mxKeyXorRR(mxKeySwapBitsG(a)))

  proc kexprocIII9(a:ByteSeq):ByteSeq=
        result = changeDuplicatesC(changeDuplicates(mxKeySwapBitsF(a)))

  proc kexprocIII10(a:ByteSeq):ByteSeq= #*138 end
        result = mxKeySwapBitsD(mxKeyXorR(mxKeySwapMinors2(a)))

  proc kexprocIII11(a:ByteSeq):ByteSeq=
    result = mxKeyAlg2(mxKeyAlg2(changeDuplicates(a)))

  proc kexprocIII12(a:ByteSeq):ByteSeq=
    result = mxKeyAlg1(mxKeyNot(mxKeySwapMinors(a)))
    #result = mxKeyAlg1(mxKeySwapMinors(mxKeyNot(a)))

  proc kexprocIII13(a:ByteSeq):ByteSeq=
    result = mxKeyAlg1(mxKeyAddRR(mxKeyAddRR(a)))

  proc kexprocIII14(a:ByteSeq):ByteSeq=
    result = mxKeyNot(mxKeyRotateLeftBits(mxKeySwapBitsF(a)))

  proc kexprocIII15(a:ByteSeq):ByteSeq=
    result = mxKeyNot(mxKeySwapMinors3(changeDuplicatesB(a)))

  proc kexprocIII16(a:ByteSeq):ByteSeq=
    result = mxKeyNot(mxKeyXorR(changeDuplicatesB(a)))

  proc kexprocIII17(a:ByteSeq):ByteSeq=
    result = mxKeyReverse(changeDuplicates(changeDuplicatesC2(a)))

  proc kexprocIII18(a:ByteSeq):ByteSeq=
    result = mxKeyReverse(changeDuplicates(changeDuplicatesC2(a)))

  proc kexprocIII19(a:ByteSeq):ByteSeq=
    result = mxKeyReverse(mxKeySwapBitsF(changeDuplicates(a)))

  proc kexprocIII20(a:ByteSeq):ByteSeq=
    result = mxKeyReverseBits(mxKeyAddRR(changeDuplicatesB(a)))

  proc kexprocIII21(a:ByteSeq):ByteSeq=
    result = mxKeyReverseBits(changeDuplicatesB(mxKeyXorR(a)))

  proc kexprocIII22(a:ByteSeq):ByteSeq=
    result = mxKeyRotEnc(changeDuplicates(changeDuplicatesC(a)))
  proc kexprocIII23(a:ByteSeq):ByteSeq=
    result = mxKeyRotateLeftBits(mxKeyNot(mxKeySwapBitsF(a)))
  proc kexprocIII24(a:ByteSeq):ByteSeq=
    result = mxKeyRotateLeftBits(changeDuplicatesC2(mxKeySwapMinors(a)))
  proc kexprocIII25(a:ByteSeq):ByteSeq=
    result = mxKeyRotateLeftBits(mxKeySwapBitsF(mxKeyNot(a)))
  proc kexprocIII26(a:ByteSeq):ByteSeq=
    result = mxKeySwapBitsRound(changeDuplicates(mxKeyAlg1(a)))
  proc kexprocIII27(a:ByteSeq):ByteSeq=
    result = mxKeySwapMinors(mxKeySwapMinors3(changeDuplicatesC(a)))
  proc kexprocIII28(a:ByteSeq):ByteSeq=
    result = mxKeySwapMinors(mxKeyAddRR(changeDuplicatesC(a)))
  proc kexprocIII29(a:ByteSeq):ByteSeq=
    result = mxKeySwapMinors3(mxKeyAlg1(mxKeySwapBitsF(a)))
  proc kexprocIII30(a:ByteSeq):ByteSeq=
    result = mxKeySwapMinors3(mxKeyNot(changeDuplicatesB(a)))
  proc kexprocIII31(a:ByteSeq):ByteSeq=
    result = mxKeySwapMinors3(mxKeySwapBitsE(mxKeyRotateLeftBits(a)))
  proc kexprocIII32(a:ByteSeq):ByteSeq=
    result = mxKeyXor(changeDuplicatesC2(mxKeySwapBitsA(a)))
  proc kexprocIII33(a:ByteSeq):ByteSeq=
    result = mxKeyXorB(mxKeyAddRR(changeDuplicatesC2(a)))
  proc kexprocIII34(a:ByteSeq):ByteSeq=
    result = mxKeyXorR(mxKeySwapBitsEE2(mxKeyAlg1(a)))
  proc kexprocIII35(a:ByteSeq):ByteSeq=
    result = mxKeyAddRR(changeDuplicatesB(changeDuplicatesC(a)))
  proc kexprocIII36(a:ByteSeq):ByteSeq=
    result = changeDuplicates(mxKeyReverse(changeDuplicatesC2(a)))

  proc kexprocIII37(a:ByteSeq):ByteSeq=
    result = changeDuplicates(mxKeySwapMinors3(mxKeyRotateLeftBits(a)))
  proc kexprocIII38(a:ByteSeq):ByteSeq=
    result = changeDuplicates(changeDuplicatesC2(mxKeyReverse(a)))
  proc kexprocIII39(a:ByteSeq):ByteSeq=
    result = changeDuplicatesC(mxKeyAlg1(mxKeySwapMinors2(a)))
  proc kexprocIII40(a:ByteSeq):ByteSeq=
    result = changeDuplicatesC(mxKeyAddRR(changeDuplicatesB(a)))
  proc kexprocIII41(a:ByteSeq):ByteSeq=
    result = changeDuplicatesC2(mxKeyReverse(changeDuplicatesB(a)))
  proc kexprocIII42(a:ByteSeq):ByteSeq=
    result = changeDuplicatesC2(mxKeySwapBitsE(mxKeyXorB(a)))
  proc kexprocIII43(a:ByteSeq):ByteSeq=
    result = changeDuplicatesC2(mxKeyAddRR(mxKeySwapBitsD(a)))
  proc kexprocIII44(a:ByteSeq):ByteSeq=
    result = changeDuplicatesC2(changeDuplicatesC(mxKeySwapBitsD(a)))
  proc kexprocIII45(a:ByteSeq):ByteSeq=
    result = changeDuplicatesC2(changeDuplicatesB(mxKeyReverse(a)))
  proc kexprocIII46(a:ByteSeq):ByteSeq=
    result = changeDuplicatesC2(changeDuplicatesB(changeDuplicatesB(a)))
  proc kexprocIII47(a:ByteSeq):ByteSeq=
    result = changeDuplicatesC2(mxKeySwapBitsD(mxKeyReverseBits(a)))
  proc kexprocIII48(a:ByteSeq):ByteSeq=
    result = changeDuplicatesB(mxKeySwapMinors3(mxKeySwapBitsA(a)))
  proc kexprocIII49(a:ByteSeq):ByteSeq=
    result = changeDuplicatesB(mxKeyAddRR(mxKeySwapBitsC(a)))

  proc kexprocIII50(a:ByteSeq):ByteSeq=
    result = changeDuplicatesB(changeDuplicatesC2(changeDuplicatesB(a)))
  proc kexprocIII51(a:ByteSeq):ByteSeq=
    result = mxKeySwapBitsD(mxKeySwapBitsG(mxKeySwapBitsF(a)))
  proc kexprocIII52(a:ByteSeq):ByteSeq=
    result = mxKeySwapBitsF(mxKeyReverse(changeDuplicates(a)))
  proc kexprocIII53(a:ByteSeq):ByteSeq=
    result = mxKeySwapBitsF(mxKeySwapBitsRound(changeDuplicates(a)))
  proc kexprocIII54(a:ByteSeq):ByteSeq=
    result = mxKeySwapBitsF(changeDuplicates(mxKeyReverse(a)))
  proc kexprocIII55(a:ByteSeq):ByteSeq=
    result = mxKeySwapBitsG(mxKeySwapBitsB(mxKeySwapBitsE(a)))
]#




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


#[     proc kexprocIV08(a:ByteSeq):ByteSeq=
    result = mxKeySwapBitsA(mxKeySwapBitsB(mxKeySwapBitsD(mxKeyNot(a))))

  proc kexprocIV09(a:ByteSeq):ByteSeq=
    result = mxKeySwapMinors(mxKeyNot(mxKeyRotateLeftBits(mxKeySwapBitsF(a))))

  proc kexprocIV10(a:ByteSeq):ByteSeq=
    result = mxKeySwapMinors(mxKeyRotateLeftBits(mxKeyNot(mxKeySwapBitsF(a))))

  proc kexprocIV11(a:ByteSeq):ByteSeq=
    result = mxKeySwapMinors(mxKeyRotateLeftBits(mxKeySwapBitsF(mxKeyNot(a))))
]#

  proc DUMMY(a:ByteSeq):ByteSeq=
    result = a

  let
    procs =[
      kexprocIV0,
      kexprocIV01,
      kexprocIV02,
      kexprocIV03,
      kexprocIV04,
      kexprocIV05,
      kexprocIV06,
      kexprocIV07,
      #kexprocIV08,
      #kexprocIV09,
      #kexprocIV10,
      #kexprocIV11,
      kexproc1,
      kexproc2,
      kexproc3,
      kexproc4,
      kexproc5,
      kexproc6,
      #kexproc7,
      #kexproc8,
      #kexproc9,
      #kexproc10,
      #kexproc11,
      #kexproc12,
      #kexproc13,
      #kexproc14,

      kexprocIII1,
      kexprocIII2,
      kexprocIII3,
      kexprocIII4,
      kexprocIII5,
      kexprocIII6,
      #kexprocIII7,
      #kexprocIII8,
      #kexprocIII9,
      #kexprocIII10,
      #kexprocIII11,
      #kexprocIII12,
      #kexprocIII13,
      #kexprocIII14,
      #kexprocIII15,
      #kexprocIII16,
      #kexprocIII17,
      #kexprocIII18,
      #kexprocIII19,
      #kexprocIII20,
      #kexprocIII21,
      #kexprocIII22,
      #kexprocIII23,
      #kexprocIII24,
      #kexprocIII25,
      #kexprocIII26,
      #kexprocIII27,
      #kexprocIII28,
      #kexprocIII29,

      #kexprocIII30,
      #kexprocIII31,
      #kexprocIII32,
      #kexprocIII33,
      #kexprocIII34,
      #kexprocIII35,
      #kexprocIII36,
      #kexprocIII37,
      #kexprocIII38,
      #kexprocIII39,
      #kexprocIII40,
      #kexprocIII41,
      #kexprocIII42,
      #kexprocIII43,
      #kexprocIII44,
      #kexprocIII45,
      #kexprocIII46,
      #kexprocIII47,
      #kexprocIII48,
      #kexprocIII49,
      #kexprocIII50,
      #kexprocIII51,
      #kexprocIII52,
      #kexprocIII53,
      #kexprocIII54,
      #kexprocIII55,

      #kexproc01,
      #kexproc02,
      #kexproc03,

      #DUMMY,
      DUMMY,
      DUMMY
      #changeDuplicatesC2,
      #changeDuplicates,
      #mxKeySwapBitsF,
      #mxKeyAlg2,
      #mxKeyAlg1,
      #mxKeyRotEnc



    ]
    procnames =[
      "kexprocIV0",
      "kexprocIV01",
      "kexprocIV02",
      "kexprocIV03",
      "kexprocIV04",
      "kexprocIV05",
      "kexprocIV06",
      "kexprocIV07",
      #"kexprocIV08",
      #"kexprocIV09",
      #"kexprocIV10",
      #"kexprocIV11",
      "kexproc1",
      "kexproc2",
      "kexproc3",
      "kexproc4",
      "kexproc5",
      "kexproc6",
      #"kexproc7",
      #"kexproc8",
      #"kexproc9",
      #"kexproc10",
      #"kexproc11",
      #"kexproc12",
      #"kexproc13",
      #"kexproc14",

      "kexprocIII1",
      "kexprocIII2",
      "kexprocIII3",
      "kexprocIII4",
      "kexprocIII5",
      "kexprocIII6",
      #"kexprocIII7",
      #"kexprocIII8",
      #"kexprocIII9",
      #"kexprocIII10",
      #"kexprocIII11",
      #"kexprocIII12",
      #"kexprocIII13",
      #"kexprocIII14",
      #"kexprocIII15",
      #"kexprocIII16",
      #"kexprocIII17",
      #"kexprocIII18",
      #"kexprocIII19",
      #"kexprocIII20",

      #"kexprocIII21",
      #"kexprocIII22",
      #"kexprocIII23",
      #"kexprocIII24",
      #"kexprocIII25",
      #"kexprocIII26",
      #"kexprocIII27",
      #"kexprocIII28",
      #"kexprocIII29",

      #"kexprocIII30",
      #"kexprocIII31",
      #"kexprocIII32",
      #"kexprocIII33",
      #"kexprocIII34",
      #"kexprocIII35",
      #"kexprocIII36",
      #"kexprocIII37",
      #"kexprocIII38",
      #"kexprocIII39",
      #"kexprocIII40",
      #"kexprocIII41",
      #"kexprocIII42",
      #"kexprocIII43",
      #"kexprocIII44",
      #"kexprocIII45",
      #"kexprocIII46",
      #"kexprocIII47",
      #"kexprocIII48",
      #"kexprocIII49",
      #"kexprocIII50",
      #"kexprocIII51",
      #"kexprocIII52",
      #"kexprocIII53",
      #"kexprocIII54",
      #"kexprocIII55",

      #"kexproc01",
      #"kexproc02",
      #"kexproc03",

      #"DUMMY",
      "DUMMY",
      "DUMMY",

      #"changeDuplicatesC2",
      #"changeDuplicates",
      #"mxKeySwapBitsF",
      #"mxKeyAlg2",
      #"mxKeyAlg1",
      #"mxKeyRotEnc"




    ]
  const procnum = 6

  var
    pr: array[0..procnum-1,tuple[step: bool, current: int]]
    prstring = ""
    keyTable: ByteSeq
    was: ByteSeq
    countt,maxCountt,sumCountt,succCount,maxSuccCount: int
    minMaxCount: int = 65535
    minMaxStr: string
    rf:File
  rf = open("keyexpgen-SUM-MAX-SUCC_E30R-" & $procnum & ".csv",fmWrite)
  randomize()
  for pi in 0..30: # 28
    block gen:
      theKey = passToKey(passwordlist[pi])
      minMaxCount = 65535
      var t1 = 0
      for pn in 0..procnum-1:
        pr[pn].step = false
        pr[pn].current = t1
        t1 += 1

      var avg = 0
      while true:
        prstring = ""
        newKey = theKey
        keyTable = @[]

        var same = false
        block cahce:
          for pn in 0..procnum-1:
            for pn2 in 0..procnum-1:
              if pn == pn2: continue
              if pr[pn].current == pr[pn2].current:
                same = true
                break cahce


        if not same:
          prstring = "oldKey"
          for pn in 0..procnum-1:
            #prstring = prstring & "(" & procnames[pr[pn].current]
            prstring = procnames[pr[pn].current] & "(" & prstring & ")"


          for ti in 0..15:
            #if testBit(newKey[0],0):
            #  newKey = mxKeyReverse(newKey)
            for pn in 0..procnum-1:
              newKey = procs[pr[pn].current](newKey)

            for inn in 0..newKey.high:
              if newKey[inn].countSetBits < 2:
                newKey[inn] = newKey[inn] xor 0b01010101
            newKey = mxKeyAddRR(newKey) #*
            newKey = newKey.changeDuplicatesC() #**

            keyTable.add(newKey)



        var minpn = 1

        #[ if procnum > 4:
          minpn = procnum-4
        for pn in minpn..procnum-1:
          if pr[pn].step or pn == procnum - 1:# last always
            pr[pn].current += 1
            if pr[pn].current > procs.high:
              if pn == minpn+1: break gen #!
              pr[pn].current = 0
              if pn != minpn:
                pr[pn-1].step = true
            if pn < procnum - 1:
              pr[pn].step = false
        for pn in 0..minpn:
          pr[pn].current = rand(procs.high) ]#

        for pn in 0..procnum-1:
          pr[pn].current = rand(procs.high)


        if not same:
          was = @[]
          sumCountt = 0
          maxCountt = 0
          succCount = 0
          for c in 0 .. keyTable.high:
            if not (keyTable[c] in was):
              was.add(keyTable[c])
              countt = 0
              for cc in 0 .. keyTable.high:
                if c == cc: continue
                if keyTable[c] == keyTable[cc]:
                  countt += 1
                  sumCountt += 1
                  if countt > maxCountt:
                    maxCountt = countt
              if countt == 0:
                succCount += 1
              #echo countt

          if avg > 0:
            if succCount >= avg:
              echo "AVG ", avg#[ (avg + succCount) div 2 ]#," - maxC:", maxCountt, " sumC:",sumCountt, " SUCC:",succCount, " | "
              avg = succCount
              #avg = avg div 2
              echoKey(keyTable)
            else:
              echo avg, ", ", prstring
          else:
            echo " - ", succCount
            avg = succCount


          if succCount >= avg and avg != 0 : #125: #15
            echo avg, ", ",prstring
            rf.writeLine(passwordlist[pi], ",", prstring & "," & $sumCountt & "," & $maxCountt & "," & $succCount)
            rf.flushFile()
            #echoKey(keyTable)

          if minMaxCount > maxCountt:
            minMaxCount = maxCountt
            minMaxStr = prstring
        #else: echo " *NOT*" #newline

    echo ":::", minMaxStr, " - ", minMaxCount
  rf.close()



















when keyexpprocgenC:
  var newKey:ByteSeq





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



  proc DUMMY(a:ByteSeq):ByteSeq=
    result = a

  let
    procs =[
      kexprocIV0,
      kexprocIV01,
      kexprocIV02,
      kexprocIV03,
      kexprocIV04,
      kexprocIV05,
      kexprocIV06,
      kexprocIV07,

      kexproc1,
      kexproc2,
      kexproc3,
      kexproc4,
      kexproc5,
      kexproc6,


      kexprocIII1,
      kexprocIII2,
      kexprocIII3,
      kexprocIII4,
      kexprocIII5,
      kexprocIII6,


      #kexproc01,
      #kexproc02,
      #kexproc03,

      #DUMMY,
      #DUMMY,
      #DUMMY
      #changeDuplicatesC2,
      #changeDuplicates,
      #mxKeySwapBitsF,
      #mxKeyAlg2,
      #mxKeyAlg1,
      #mxKeyRotEnc



    ]
    procnames =[
      "kexprocIV0",
      "kexprocIV01",
      "kexprocIV02",
      "kexprocIV03",
      "kexprocIV04",
      "kexprocIV05",
      "kexprocIV06",
      "kexprocIV07",

      "kexproc1",
      "kexproc2",
      "kexproc3",
      "kexproc4",
      "kexproc5",
      "kexproc6",


      "kexprocIII1",
      "kexprocIII2",
      "kexprocIII3",
      "kexprocIII4",
      "kexprocIII5",
      "kexprocIII6",


      #"kexproc01",
      #"kexproc02",
      #"kexproc03",

      #"DUMMY",
      #"DUMMY",
      #"DUMMY",

      #"changeDuplicatesC2",
      #"changeDuplicates",
      #"mxKeySwapBitsF",
      #"mxKeyAlg2",
      #"mxKeyAlg1",
      #"mxKeyRotEnc"




    ]
  const procnum = 16

  var
    pr: array[0..procnum-1,tuple[step: bool, current: int]]
    prstring = ""
    keyTable: ByteSeq
    passTable:KeyTable
    was: ByteSeq
    countt,maxCountt,sumCountt,succCount,maxSuccCount: int
    minMaxCount: int = 65535
    minMaxStr: string
    rf:File
    limit = 0
  rf = open("keyexpgenC-SUM-MAX-SUCC_F30R-" & $procnum & ".csv",fmWrite)
  randomize()

  block:
    block gen:
      #theKey = passToKey(passwordlist[pi])
      minMaxCount = 65535
      var t1 = 0
      for pn in 0..procnum-1:
          pr[pn].current = rand(procs.high)

      var avg = 0
      var roundCount = 0

      for pi in 0..30:
        passTable.add(passToKey(passwordlist[pi]))

      while true:#limit <= 50_000_000:
        limit += 1
        if limit == 100_000:
          #randomize()
          limit = 0
          roundCount += 1
          echo "\n ** 1_000_000 ** ", roundCount
        #prstring = ""
        #newKey = theKey
        #keyTable = @[]

        var same = false
        block cahce:
          if procnum > procs.len:
            same = false
          else:
            for pn in 0..procnum-1:
              for pn2 in 0..procnum-1:
                if pn == pn2: continue
                if pr[pn].current == pr[pn2].current:
                  same = true
                  break cahce


        if not same:
          #prstring = "oldKey"
          prstring = ""
          for pn in 0..procnum-1:
            #prstring = prstring & "(" & procnames[pr[pn].current]
            prstring = prstring & "#[+]#" & procnames[pr[pn].current] & "(oldKey)"

          sumCountt = 0
          maxCountt = 0
          succCount = 0

          for pi in 0..30: # 28
            keyTable = @[]
            newKey = passTable[pi]
            #for ti in 0..1:
            block:
              #if testBit(newKey[0],0):
              #  newKey = mxKeyReverse(newKey)
              for pn in 0..procnum-1:
                newKey = procs[pr[pn].current](newKey)

                for inn in 0..newKey.high: #???
                  if newKey[inn].countSetBits < 2:
                    newKey[inn] = newKey[inn] xor 0b01010101
                newKey = mxKeyAddRR(newKey) #*
                newKey = newKey.changeDuplicatesC() #**

                keyTable.add(newKey)


              was = @[]
              for c in 0 .. keyTable.high:
                if not (keyTable[c] in was):
                  was.add(keyTable[c])
                  countt = 0
                  for cc in 0 .. keyTable.high:
                    if c == cc: continue
                    if keyTable[c] == keyTable[cc]:
                      countt += 1
                      sumCountt += 1
                      if countt > maxCountt:
                        maxCountt = countt
                  if countt == 0:
                    succCount += 1
                  #echo countt


          if avg > 0:
            if succCount >= avg:
              echo "AVG ", avg#[ (avg + succCount) div 2 ]#," - maxC:", maxCountt, " sumC:",sumCountt, " SUCC:",succCount, " | "
              avg = succCount
              #avg = avg div 2
              echoKey(keyTable)
            else:
              #echo avg,", ", succCount,", ", sumCountt,", ", maxCountt,", ", prstring, "\n--------\n"
              stdout.write "[", avg, ",", succCount, "],"
          else:
            echo " - ", succCount
            avg = succCount


          if succCount >= avg and avg != 0 #[ and avg > 80 ]#: #125: #15
            echo avg, ", ",prstring
            rf.writeLine(prstring & "," & $sumCountt & "," & $maxCountt & "," & $succCount)
            rf.flushFile()
            #echoKey(keyTable)

          if minMaxCount > maxCountt:
            minMaxCount = maxCountt
            minMaxStr = prstring


        #[ var minpn = 1

        if procnum > 4:
          minpn = procnum-4
        for pn in minpn..procnum-1:
          if pr[pn].step or pn == procnum - 1:# last always
            pr[pn].current += 1
            if pr[pn].current > procs.high:
              if pn == minpn+1: break gen #!
              pr[pn].current = 0
              if pn != minpn:
                pr[pn-1].step = true
            if pn < procnum - 1:
              pr[pn].step = false
        for pn in 0..minpn:
          pr[pn].current = rand(procs.high) ]#

        for pn in 0..procnum-1:
          pr[pn].current = rand(procs.high)


    echo ":::", minMaxStr, " - ", minMaxCount
  rf.close()



















when pass2keyprocgenRAND_C:
  let
    procs =[
      #p2kproc1,
      #p2kproc2,
      p2kproc3,

      mxKeyAddRR,
      mxKeyXorRR,
      mxKeyNot,
      changeDuplicatesC2,
      changeDuplicates,
      changeDuplicatesB,
      mxKeyAlg2,
      mxKeyAlg1,
      mxKeyRotEnc,
      mxKeyReverse,
      mxKeyReverseBits,
      mxKeySwapBitsRound,
      mxKeyRotEnc2,
      mxKeySwapMinors3,
      mxKeySwapBitsEE2,
      mxKeySwapBitsA,
      mxKeySwapBitsB,
      mxKeySwapBitsC,
      mxKeySwapBitsD,
      mxKeySwapBitsE,
      mxKeySwapBitsF,
      mxKeySwapBitsG,
      mxKeyByBitEnc,
      mxKeyXor,
      mxKeyXorB,
      mxKeyRotateLeftBits,
      changeDuplicatesC

    ]
    procnames =[
      #"p2kproc1",
      #"p2kproc2",
      "p2kproc3",

      "mxKeyAddRR",
      "mxKeyXorRR",
      "mxKeyNot",
      "changeDuplicatesC2",
      "changeDuplicates",
      "changeDuplicatesB",
      "mxKeyAlg2",
      "mxKeyAlg1",
      "mxKeyRotEnc",
      "mxKeyReverse",
      "mxKeyReverseBits",
      "mxKeySwapBitsRound",
      "mxKeyRotEnc2",
      "mxKeySwapMinors3",
      "mxKeySwapBitsEE2",
      "mxKeySwapBitsA",
      "mxKeySwapBitsB",
      "mxKeySwapBitsC",
      "mxKeySwapBitsD",
      "mxKeySwapBitsE",
      "mxKeySwapBitsF",
      "mxKeySwapBitsG",
      "mxKeyByBitEnc",
      "mxKeyXor",
      "mxKeyXorB",
      "mxKeyRotateLeftBits",
      "changeDuplicatesC"

    ]
  const procnum = 16 #16
  const debug = 0b0
  var
    pr: array[0..procnum-1,tuple[step: bool, current: int]]
    prstring = ""
    keyTable: KeyTable
    keyTableF: KeyTable
    was: ByteSeq
    countt,maxCountt, sumCountt: int
    minMaxCount: int = 65535
    minMaxStr: string
    rf:File
  rf = open("pass2key_procgen-C-RANDxx-SUM-" & $procnum & ".csv",fmWrite)


  for pi in 0..30: # 28 ------------------------

    var pass = passwordlist[pi].toByteSeq()

    block:
      var
        b1:uint8
        was:ByteSeq
      for i in 0..pass.high:
        b1 += 1
        if b1 == 0: b1 = 1
        if pass[i] in was:
          pass[i] += b1

        pass[i] += b1
        pass[i] = pass[i] + (pass.len mod 255).uint8


    if pass.len < KeyLen:
      var rI:int
      var c = 0
      var d:uint8 = 0
      for i in pass.high .. (KeyLen - 2):
        pass.add(bitnot(pass[c]) + d)
        c += 1
        if c > pass.high:
          c = 0
          d += 33

    pass = mxKeyXorRR(pass)

    keyTable.add(pass) #--------------------------------------------------


  for pi in 0..30: # 28 ------------------------

    var pass = passwordlist[pi].toByteSeq()
    flipBit(pass[0],0)

    block:
      var
        b1:uint8
        was:ByteSeq
      for i in 0..pass.high:
        b1 += 1
        if b1 == 0: b1 = 1
        if pass[i] in was:
          pass[i] += b1

        pass[i] += b1
        pass[i] = pass[i] + (pass.len mod 255).uint8


    if pass.len < KeyLen:
      var rI:int
      var c = 0
      var d:uint8 = 0
      for i in pass.high .. (KeyLen - 2):
        pass.add(bitnot(pass[c]) + d)
        c += 1
        if c > pass.high:
          c = 0
          d += 33

    pass = mxKeyXorRR(pass)

    keyTableF.add(pass) #--------------------------------------------------








  block:
    block gen:
      #!.............................
      randomize()
      var limit = 0
      var avg = 0
      var avg2 = 0
      minMaxCount = 65535
      var t1:int
      for pn in 0..procnum-1:
        pr[pn].step = false
        pr[pn].current = t1
        t1 += 1
      #!----------------------------------------------
      var t0 = epochTime()
      const limitt = 50_000_000
      echo "BEGIN"
      stdout.write "\e[s"
      while limit < limitt:#procs.high * procs.high * procs.high:# * procs.high:#1_000_000:#
        limit += 1
        #*************
        #stdout.write "\e[H"
        stdout.write "\e[u"
        stdout.write fmt"[{limit:>10d}:{limitt:>10d}]"

        prstring = "p2kproc3(p2kproc2(p2kproc1"
        #newKey = theKey
        var keyTable2 = keyTable
        var keyTable3 = keyTableF

        #[ for kti in 0..keyTable2.high:
          keyTable2[kti] = p2kproc1(keyTable2[kti])
          keyTable2[kti] = p2kproc2(keyTable2[kti])
          keyTable2[kti] = p2kproc3(keyTable2[kti])

          keyTable3[kti] = p2kproc1(keyTable3[kti])
          keyTable3[kti] = p2kproc2(keyTable3[kti])
          keyTable3[kti] = p2kproc3(keyTable3[kti]) ]#

        prstring = "result"
        for pn in 0..procnum-1:
          #prstring = prstring & "(" & procnames[pr[pn].current]
          prstring = procnames[pr[pn].current] & "(" & prstring & ")"

          for kti in 0..keyTable2.high:
            keyTable2[kti] = procs[pr[pn].current](keyTable2[kti])
            keyTable3[kti] = procs[pr[pn].current](keyTable3[kti])

        for pn in 0..procnum-1:#procnum-4:
          pr[pn].current = rand(procs.high)

        #............................................


        sumCountt = 0
        for kti in 0 .. keyTable2.high:
          countt = 0
          for c in 0 .. keyTable2[kti].high:
            if keyTable2[kti][c] == keyTable3[kti][c]:
              countt += 1
              sumCountt += 1

        if sumCountt > 0: continue
        #............................................



        var inkeyCountt = 0
        for newKey in keyTable2:
          for c in 0 .. newKey.high:
            for cc in 0 .. newKey.high:
              if c == cc: continue
              if newKey[c] == newKey[cc]:
                inkeyCountt += 1

        #echo " | ik ", inkeyCountt
        if inkeyCountt > 0: continue
        #............................................

        sumCountt = 0
        maxCountt = 0
        var tbl: ByteSeq
        for newKey in keyTable2:
          tbl.add(newKey)

        was = @[]
        for c in 0 .. tbl.high:
          if not (tbl[c] in was):
            countt = 0
            was.add(tbl[c])
            for cc in 0..tbl.high:
              if c == cc: continue
              if tbl[c] == tbl[cc]:
                countt += 1
                sumCountt += 1
            if countt > maxCountt:
              maxCountt = countt
        #echo " m:", maxCountt, " s:",sumCountt

        if sumCountt <= avg or avg == 0 or sumCountt == 0:
          #rf.writeLine(prstring & "," & $maxCountt)
          avg = sumCountt
        if maxCountt <= avg2 or avg2 == 0 or maxCountt == 0:
          #rf.writeLine(prstring & "," & $maxCountt)
          avg2 = maxCountt


        if sumCountt < 308 and inkeyCountt == 0 and
          (sumCountt <= avg or maxCountt <= avg2):
          rf.writeLine(prstring & "," & $tbl.len & "," & $maxCountt & "," & $sumCountt)
          rf.flushFile()
          #avg2 = maxCountt
          #avg = sumCountt
          echo "\n", sumCountt, " - ", prstring
    #............................................

  rf.close()
  echo "Elapsed Time: ", epochTime() - t0


























when pass2keyprocgenRAND_B:
  let
    procs =[
      #p2kproc1,
      #p2kproc2,
      p2kproc3,

      mxKeyAddRR,
      mxKeyXorRR,
      mxKeyNot,
      changeDuplicatesC2,
      changeDuplicates,
      changeDuplicatesB,
      mxKeyAlg2,
      mxKeyAlg1,
      mxKeyRotEnc,
      mxKeyReverse,
      mxKeyReverseBits,
      mxKeySwapBitsRound,
      mxKeyRotEnc2,
      mxKeySwapMinors3,
      mxKeySwapBitsEE2,
      mxKeySwapBitsA,
      mxKeySwapBitsB,
      mxKeySwapBitsC,
      mxKeySwapBitsD,
      mxKeySwapBitsE,
      mxKeySwapBitsF,
      mxKeySwapBitsG,
      mxKeyByBitEnc,
      mxKeyXor,
      mxKeyXorB,
      mxKeyRotateLeftBits,
      changeDuplicatesC

    ]
    procnames =[
      #"p2kproc1",
      #"p2kproc2",
      "p2kproc3",

      "mxKeyAddRR",
      "mxKeyXorRR",
      "mxKeyNot",
      "changeDuplicatesC2",
      "changeDuplicates",
      "changeDuplicatesB",
      "mxKeyAlg2",
      "mxKeyAlg1",
      "mxKeyRotEnc",
      "mxKeyReverse",
      "mxKeyReverseBits",
      "mxKeySwapBitsRound",
      "mxKeyRotEnc2",
      "mxKeySwapMinors3",
      "mxKeySwapBitsEE2",
      "mxKeySwapBitsA",
      "mxKeySwapBitsB",
      "mxKeySwapBitsC",
      "mxKeySwapBitsD",
      "mxKeySwapBitsE",
      "mxKeySwapBitsF",
      "mxKeySwapBitsG",
      "mxKeyByBitEnc",
      "mxKeyXor",
      "mxKeyXorB",
      "mxKeyRotateLeftBits",
      "changeDuplicatesC"

    ]
  const procnum = 16 #16
  const debug = 0b0
  var
    pr: array[0..procnum-1,tuple[step: bool, current: int]]
    prstring = ""
    keyTable: KeyTable
    was: ByteSeq
    countt,maxCountt, sumCountt: int
    minMaxCount: int = 65535
    minMaxStr: string
    rf:File
  rf = open("pass2key_procgen-B-RANDxx-MAX-SUM-" & $procnum & ".csv",fmWrite)


  for pi in 0..30: # 28 ------------------------

    var pass = passwordlist[pi].toByteSeq()


    block:
      var
        b1:uint8
        was:ByteSeq
      for i in 0..pass.high:
        b1 += 1
        if b1 == 0: b1 = 1
        if pass[i] in was:
          pass[i] += b1

        pass[i] += b1
        pass[i] = pass[i] + (pass.len mod 255).uint8


    if pass.len < KeyLen:
      var rI:int
      var c = 0
      var d:uint8 = 0
      for i in pass.high .. (KeyLen - 2):
        pass.add(bitnot(pass[c]) + d)
        c += 1
        if c > pass.high:
          c = 0
          d += 33

    pass = mxKeyXorRR(pass)

    keyTable.add(pass) #--------------------------------------------------

  block:
    block gen:
      #!.............................
      randomize()
      var limit = 0
      var avg = 0
      var avg2 = 0
      minMaxCount = 65535
      var t1:int
      for pn in 0..procnum-1:
        pr[pn].step = false
        pr[pn].current = t1
        t1 += 1
      #!----------------------------------------------
      var t0 = epochTime()
      const limitt = 10_000_000
      echo "BEGIN"
      stdout.write "\e[s"
      while limit < limitt:#procs.high * procs.high * procs.high:# * procs.high:#1_000_000:#
        limit += 1
        #*************
        #stdout.write "\e[H"
        stdout.write "\e[u"
        stdout.write fmt"[{limit:>10d}:{limitt:>10d}]"

        prstring = "p2kproc3(p2kproc2(p2kproc1"
        #newKey = theKey
        var keyTable2 = keyTable

        for kti in 0..keyTable2.high:
          keyTable2[kti] = p2kproc1(keyTable2[kti])
          keyTable2[kti] = p2kproc2(keyTable2[kti])
          keyTable2[kti] = p2kproc3(keyTable2[kti])

        prstring = "result"
        for pn in 0..procnum-1:
          #prstring = prstring & "(" & procnames[pr[pn].current]
          prstring = procnames[pr[pn].current] & "(" & prstring & ")"

          for kti in 0..keyTable2.high:
            keyTable2[kti] = procs[pr[pn].current](keyTable2[kti])

          #[ if pr[pn].step or pn == procnum - 1:# last always
            pr[pn].current += 1
            if pr[pn].current > procs.high:
              #if pn == procnum - 4: break gen #!
              pr[pn].current = 0
              if pn != 0:
                pr[pn-1].step = true
            if pn < procnum - 1:
              pr[pn].step = false ]#

        #stdout.write prstring

        for pn in 0..procnum-1:#procnum-4:
          pr[pn].current = rand(procs.high)

        #............................................
        var inkeyCountt = 0
        for newKey in keyTable2:
          for c in 0 .. newKey.high:
            for cc in 0 .. newKey.high:
              if c == cc: continue
              if newKey[c] == newKey[cc]:
                inkeyCountt += 1

        #echo " | ik ", inkeyCountt
        if inkeyCountt > 0: continue

        sumCountt = 0
        maxCountt = 0
        var tbl: ByteSeq
        for newKey in keyTable2:
          tbl.add(newKey)

        was = @[]
        for c in 0 .. tbl.high:
          if not (tbl[c] in was):
            countt = 0
            was.add(tbl[c])
            for cc in 0..tbl.high:
              if c == cc: continue
              if tbl[c] == tbl[cc]:
                countt += 1
                sumCountt += 1
            if countt > maxCountt:
              maxCountt = countt
        #echo " m:", maxCountt, " s:",sumCountt

        if sumCountt <= avg or avg == 0 or sumCountt == 0:
          #rf.writeLine(prstring & "," & $maxCountt)
          avg = sumCountt
        if maxCountt <= avg2 or avg2 == 0 or maxCountt == 0:
          #rf.writeLine(prstring & "," & $maxCountt)
          avg2 = maxCountt


        if sumCountt < 308 and inkeyCountt == 0 and
          (sumCountt <= avg or maxCountt <= avg2):
          rf.writeLine(prstring & "," & $tbl.len & "," & $maxCountt & "," & $sumCountt)
          rf.flushFile()
          #avg2 = maxCountt
          #avg = sumCountt
          echo "\n", sumCountt, " - ", prstring
    #............................................

  rf.close()
  echo "Elapsed Time: ", epochTime() - t0








when pass2keyprocSelect:
  block:
    var tbl:ByteSeq
    for i in 0..passwordlist.high:
      tbl.add( countSetBits( passwordlist[i][0].uint8).uint8 )

    echoCountTable(tbl)

  block:
    var tbl:ByteSeq
    for i in 0..passwordlist.high:
      var x =  passwordlist[i][0].uint8 or reverseBits( passwordlist[i][1].uint8) xor  passwordlist[i][2].uint8 + bitnot( passwordlist[i][3].uint8)
      tbl.add( countSetBits( x.uint8).uint8 )

    echoCountTable(tbl)

  block:
    var tbl:ByteSeq
    for i in 0..passwordlist.high:
      var x =  passwordlist[i][0].uint8 or reverseBits( passwordlist[i][1].uint8) or passwordlist[i][2].uint8 or bitnot( passwordlist[i][3].uint8)
      tbl.add( countSetBits( x.uint8).uint8 )

    echoCountTable(tbl)



  block:
    var tbl:ByteSeq
    for i in 0..passwordlist.high:
      var x =  passwordlist[i][0].uint8 + reverseBits( passwordlist[i][1].uint8) + passwordlist[i][2].uint8 + bitnot( passwordlist[i][3].uint8)
      tbl.add( x mod 7 )

    echoCountTable(tbl)


  block:
    var tbl:ByteSeq
    var x:uint8
    for i in 0..passwordlist.high:
      for c in 0..passwordlist[i].high:
        x +=  passwordlist[i][c].uint8 + reverseBits( passwordlist[i][c].uint8) + bitnot( passwordlist[i][c].uint8)
      tbl.add( x mod 7 )

    echoCountTable(tbl)



  block:
    var tbl:ByteSeq
    var x:uint8
    for i in 0..passwordlist.high:
      for c in 0..passwordlist[i].high:
        x += passwordlist[i][c].uint8
      tbl.add( x mod 7 )

    echoCountTable(tbl)


  block:
    var tbl:ByteSeq
    var x:uint8
    for i in 0..passwordlist.high:
      for c in 0..passwordlist[i].high:
        x += passwordlist[i][c].uint8
      tbl.add( x mod 10 )

    echoCountTable(tbl)
















#[

time openssl enc -aes-256-cbc -pass pass:12345 -in test10M -out test10M.aes -pbkdf2

openssl rand -base64 24

openssl enc -blowfish -pbkdf2 -pass pass:passw0rd -in SampleTextFile_10kb.txt -out SampleTextFile_10kb.blowfish

]#