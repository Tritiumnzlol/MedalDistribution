:: We will hide our commands
@echo off

:: Set here your path to 7-Zip, including 7z.exe
SET zip="C:\Program Files\7-Zip\7z.exe"

:: This will get the current directory name,
:: Keep in mind that the Plugin ID (not the site ID) must be the same name as the current directory
for %%I in (.) do SET CurrDirName=%%~nxI

:: Check if we have already a .op built
:: If we have one, we need to delete, because 7-Zip will add files on it but not delete older ones
IF EXIST %CurrDirName%.op (
    del %CurrDirName%.op
)

:: Then compress it
%zip% a -mx1 -tzip %CurrDirName%.op info.toml src

echo Done!