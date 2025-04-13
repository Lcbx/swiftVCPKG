#!bash

cd build 

ninja | ../error_highlighter.py \
&& ./swiftEngine.exe >/dev/null
