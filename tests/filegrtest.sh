#!/usr/bin/env bash

openssl rand -base64 256 > test256.key
openssl rand -base64 512 > test512.key
openssl rand -base64 1024 > test1024.key
openssl rand -base64 4096 > test4096.key

echo "_.__._._.__._.._.__._._.__._.._.__._._.__._.._.__._._.__._"
echo "[password]____________"
filegr -e -t -v:2 -p:passw0rd SampleTextFile_100kb.txt
echo "-----------------------------------------"
echo "[password block]____________"
filegr -e -t -v:2 -p:passw0rd --kem:b SampleTextFile_100kb.txt
echo "-----------------------------------------"
echo "[password cont]____________"
filegr -e -t -v:2 -p:passw0rd --kxm:c SampleTextFile_100kb.txt
echo "-----------------------------------------"

echo "[password ktr:256]____________"
filegr -e -t -v:2 -p:passw0rd --ktr:256 SampleTextFile_100kb.txt
echo "-----------------------------------------"



echo "[key]_____________"
filegr -e -t -v:2 -k:test256.key SampleTextFile_100kb.txt
echo "-----------------------------------------"
echo "[key 1024 ktr:32]_____________"
filegr -e -t -v:2 -k:test1024.key --ktr:32 SampleTextFile_100kb.txt
echo "-----------------------------------------"

echo "[key repeat]_____________"
filegr -e -t -v:2 -k:test256.key --kem:r SampleTextFile_100kb.txt
echo "-----------------------------------------"
echo "[pass & key]____________"
filegr -e -t -v:2 -p:passw0rd -k:test256.key SampleTextFile_100kb.txt
echo "-----------------------------------------"
echo "[preburn]___________"
filegr -e -t -v:2 -p:passw0rd --pre:256 SampleTextFile_100kb.txt
echo "-----------------------------------------"


echo "key length 256,512,1024 bytes"
filegr -e -t -v:2 -k:test512.key SampleTextFile_100kb.txt
echo "-----------------------------------------"
filegr -e -t -v:2 -k:test1024.key SampleTextFile_100kb.txt
echo "-----------------------------------------"


echo "[test1.xbgk]___________"
filegr -e -t -v:2 --xkey:test1.xbgk SampleTextFile_100kb.txt
echo "-----------------------------------------"
echo "[test1.exbgk]___________"
filegr -e -t -v:2 --xp:1111 --xkey:test1.xbgk SampleTextFile_100kb.txt
echo "-----------------------------------------"

echo "[test1.xbgk -p:1111]___________"
filegr -e -t -v:2 --xkey:test1.xbgk -p:1111 SampleTextFile_100kb.txt
echo "-----------------------------------------"

echo "[ALL / 1]____________"
filegr -e -t -v:2 -p:passw0rd --pre:128 --kem:b --exp:0 --sx --ktr:128 SampleTextFile_100kb.txt
echo "-----------------------------------------"

echo "[ALL / 1]____________"
filegr -e -t -v:2 -p:passw0rd --pre:128 --kem:b --kxp:0 --sx --xp:1111 --ktr:128 SampleTextFile_100kb.txt
echo "........................................."
filegr -e -t -v:2 -p:passw0rd --pre:128 --kem:b --kxp:0 --sx --ktr:128 SampleTextFile_100kb.txt
echo "........................................."
filegr -d -v:2 --xp:1111 --xkey:sampletextfile_100kb.exbgk SampleTextFile_100kb.txt.enc
echo "-----------------------------------------"

echo "[ALL / 2]____________"
filegr -e -t -v:2 -p:passw0rd --key:test1.key --pre:128 --kem:b --kxp:0 --sx --xp:1111 SampleTextFile_10kb.txt --abs:0
echo "........................................."
filegr -e -t -v:2 -p:passw0rd --key:test1.key --pre:128 --kem:b --kxp:0 --sx SampleTextFile_10kb.txt
echo "........................................."
filegr -d -v:2 --xp:1111 --xkey:sampletextfile_10kb.exbgk SampleTextFile_10kb.txt.enc
echo "-----------------------------------------"

echo "[mixing]___________"
filegr -e -t -v --key:test512.key --ktr:2 SampleTextFile_100kb.txt --of:sample100_mix1.enc
echo "-----------------------------------------"

echo "[slower 2]___________"
filegr -e -v --pre:256 --ktr:32 --key:test4096.key --pf:test256.key SampleTextFile_100kb.txt --of:textMix100kb.enc --sx:slower2.xbgk
echo "-----------------------------------------"
echo "[slower 3]___________"
filegr -e -v --pre:256 --ktr:64 --key:test4096.key --pf:test256.key SampleTextFile_100kb.txt --of:textMix100kb.enc --sx:slower3.xbgk
echo "-----------------------------------------"