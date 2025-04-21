#!bash

cd build 

# 2>&1 redirects stderr into stdout
ninja 2>&1 | ../error_highlighter.py \
&& ./swiftEngine.exe
