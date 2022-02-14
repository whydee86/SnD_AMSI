# SnD_AMSI
## Search and Destroy AMSI Remotely  ##
![pngaaa com-5355643](https://user-images.githubusercontent.com/43274863/152907908-bb5a41a5-4e00-4607-8429-b1f51bb40518.png)  
Start new PowerShell without etw and amsi in pure nim
### Compile: ###
````
nimble install winim  
nim c -x -f StartCleanPS.nim
````
### POC ###
![image](https://user-images.githubusercontent.com/43274863/153766141-73f5a8de-49ee-422f-b011-75580cbe0323.png)

### Credits: ###
- https://github.com/byt3bl33d3r/OffensiveNim
- Thank you, Elddy for the idea of patching amsi in that way.
https://github.com/elddy
