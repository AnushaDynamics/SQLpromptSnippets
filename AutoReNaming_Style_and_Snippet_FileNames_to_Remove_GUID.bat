echo off
cd "C:\GitHub\SQLpromptSnippets"
sqlcmd -S %ComputerName% -E -i "ReNaming_Snippet_FileNames_to_Remove_GUID.sql"
sqlcmd -S %ComputerName% -E -i "ReNaming_Style_FileNames_to_Remove_GUID.sql"