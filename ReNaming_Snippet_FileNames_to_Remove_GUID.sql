/* =============================================================================================================================================================
-- Database		: USE master
-- Script		: Trimming(ReName) Snippet FileNames to Remove GUID.sql
-- Description	: This Script Rename the ".json" Files in the Snippets Folder which are being AutoRenamed by SQLprompt.
--				  So, To Rename the ".json" Files to Default File Names by Removing the PostFixed GUID in the SnippetName.
-- Usage		: Change the @Folder_Path where ".json" files are stored.
============================================================================================================================================================= */
USE master;
GO

--
DECLARE @Folder_Path NVARCHAR(4000) = N'C:\GitHub\SQLpromptSnippets\Snippets';
/**************************************************************************************************************************************************************/
/* ===== ** DO NOT CHANGE CODE BELOW FROM HERE ** =========================================================================================================== */
/**************************************************************************************************************************************************************/
SET NOCOUNT ON;
SET XACT_ABORT ON;

--
/* ===== ** Deleting the "FileList.txt" in the FolderPath "@Folder_Path" If Exists ** ======================================================================= */
DECLARE @DEL_FileList NVARCHAR(4000);
SET @DEL_FileList = N'del /S "' + @Folder_Path + N'\FileList.txt"';
--PRINT @DEL_FileList;
EXEC sys.xp_cmdshell @command = @DEL_FileList;

--
/* ===== ** Creating the New "FileList.txt" in the FolderPath "@Folder_Path" ** ============================================================================= */
DECLARE @MK_FileList NVARCHAR(4000);
SET @MK_FileList = N'for /F "tokens=*" %a in (''dir "' + @Folder_Path + N'\" /s /b'') do echo %~fa >>"' + @Folder_Path + N'\FileList.txt"';
--PRINT @MK_FileList;
EXEC sys.xp_cmdshell @command = @MK_FileList;

--
/* ===== ** Creating "#Temp_SnippetList" Table for Raw Data of "FileList.txt" ** ============================================================================ */
IF OBJECT_ID('tempdb..#Temp_SnippetList', 'U') IS NOT NULL
	DROP TABLE #Temp_SnippetList;

CREATE TABLE #Temp_SnippetList
(
	SnippetName VARCHAR(4000) NOT NULL
) ON [PRIMARY];

/* ===== ** Inserting "FileList.txt" Data into "#Temp_SnippetList" Table ** ================================================================================= */
DECLARE @SnippetListImportString NVARCHAR(4000);
SET @SnippetListImportString = N'BULK INSERT #Temp_SnippetList FROM ''' + @Folder_Path + N'\FileList.txt'' WITH (FIELDTERMINATOR  = '','', FIRSTROW = 1)';
--PRINT @SnippetListImportString;
EXEC sys.sp_executesql @command = @SnippetListImportString;

SELECT SnippetName FROM #Temp_SnippetList;

/* ===== ** Creating the Table "#Final_SnippetList" for Renaming the Files Accordingly ** =================================================================== */
IF OBJECT_ID('tempdb..#Final_SnippetList', 'U') IS NOT NULL
	DROP TABLE #Final_SnippetList;

;WITH _CTE AS 
(
	SELECT SnippetName AS "Old_SnippetName",
		REPLACE(SUBSTRING(SnippetName, 0, CHARINDEX('-', SnippetName, 0)) + '.json', 'C:\GitHub\SQLpromptSnippets\Snippets\', '') AS "New_SnippetName"
	FROM #Temp_SnippetList
)
SELECT ROW_NUMBER() OVER (ORDER BY CTE.New_SnippetName) AS "Id",
	   LTRIM(RTRIM(CTE.Old_SnippetName)) AS "Old_SnippetName",
	   LTRIM(RTRIM(CTE.New_SnippetName)) AS "New_SnippetName"
INTO #Final_SnippetList
FROM _CTE AS CTE;

SELECT FFL.Id, FFL.Old_SnippetName, FFL.New_SnippetName
FROM #Final_SnippetList AS FFL;

/**************************************************************************************************************************************************************/
/* ===== ** Renaming the Files Only if NewSnippetName != ".json" ** ========================================================================================= */
IF EXISTS (SELECT * FROM #Final_SnippetList WHERE New_SnippetName <> '.json')
BEGIN
	BEGIN TRANSACTION;
	--
	PRINT '/*Files ReNaming Process Started*/';
	PRINT '--';
	--
	DECLARE @i INT, @n INT;
	SELECT @i = MIN(Id), @n  = MAX(Id)
	FROM #Final_SnippetList;
	--
	DECLARE @OldSnippetName VARCHAR(512), @NewSnippetName VARCHAR(512);
	DECLARE @DeleteSnippetIfExistsCMD NVARCHAR(4000);
	DECLARE @ReNameSnippetCMD NVARCHAR(4000);
	--
	WHILE @i <= @n
	BEGIN
		IF EXISTS (SELECT * FROM #Final_SnippetList WHERE Id = @i AND New_SnippetName <> '.json')
		BEGIN
			SELECT @OldSnippetName = Old_SnippetName, @NewSnippetName = New_SnippetName
			FROM #Final_SnippetList
			WHERE Id = @i AND New_SnippetName <> '.json';
			--
			SET @DeleteSnippetIfExistsCMD = NULL;
			SET @DeleteSnippetIfExistsCMD = N'del /S "' + @Folder_Path + N'\' + @NewSnippetName + N'"';
			PRINT @DeleteSnippetIfExistsCMD;
			EXEC sys.xp_cmdshell @command = @DeleteSnippetIfExistsCMD;
			--
			SET @ReNameSnippetCMD = NULL;
			SET @ReNameSnippetCMD = N'rename "' + @OldSnippetName + N'" "' + @NewSnippetName + N'"';
			PRINT @ReNameSnippetCMD;
			EXEC sys.xp_cmdshell @command = @ReNameSnippetCMD;
			--
			PRINT 'Changed => ' + @ReNameSnippetCMD;
			PRINT '--';		    
		END
		--
		SET @i = @i + 1;
	END;
	--
	PRINT '/*Files ReNaming Process Completed*/';
	--
	COMMIT TRANSACTION;
END;
ELSE 
BEGIN
	RAISERROR('Aborting Renaming Files as SnippetName would be Truncated to ".json".', 18, 1) WITH NOWAIT;
	EXEC sys.xp_cmdshell @command = 'pause';
END;
--
/* ===== ** Deleting the Flie "FileList.txt" Again which is Created for this Process ** ===================================================================== */
EXEC sys.xp_cmdshell @command = @DEL_FileList;