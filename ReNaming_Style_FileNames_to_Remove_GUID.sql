/* =============================================================================================================================================================
-- Database		: USE master
-- Script		: Trimming(ReName) Style FileNames to Remove GUID.sql
-- Description	: This Script Rename the ".json" Files in the Styles Folder which are being AutoRenamed by SQLprompt.
--				  So, To Rename the ".json" Files to Default File Names by Removing the PostFixed GUID in the StyleName.
-- Usage		: Change the @Folder_Path where ".json" files are stored.
============================================================================================================================================================= */
USE master;
GO

--
DECLARE @Folder_Path NVARCHAR(4000) = N'C:\GitHub\SQLpromptSnippets\Styles';
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
/* ===== ** Creating "#Temp_StyleList" Table for Raw Data of "FileList.txt" ** ============================================================================ */
IF OBJECT_ID('tempdb..#Temp_StyleList', 'U') IS NOT NULL
	DROP TABLE #Temp_StyleList;

CREATE TABLE #Temp_StyleList
(
	StyleName VARCHAR(4000) NOT NULL
) ON [PRIMARY];

/* ===== ** Inserting "FileList.txt" Data into "#Temp_StyleList" Table ** ================================================================================= */
DECLARE @StyleListImportString NVARCHAR(4000);
SET @StyleListImportString = N'BULK INSERT #Temp_StyleList FROM ''' + @Folder_Path + N'\FileList.txt'' WITH (FIELDTERMINATOR  = '','', FIRSTROW = 1)';
--PRINT @StyleListImportString;
EXEC sys.sp_executesql @command = @StyleListImportString;

SELECT StyleName FROM #Temp_StyleList;

/* ===== ** Creating the Table "#Final_StyleList" for Renaming the Files Accordingly ** =================================================================== */
IF OBJECT_ID('tempdb..#Final_StyleList', 'U') IS NOT NULL
	DROP TABLE #Final_StyleList;

;WITH _CTE AS 
(
	SELECT StyleName AS "Old_StyleName",
		REPLACE(SUBSTRING(StyleName, 0, CHARINDEX('-', StyleName, 0)) + '.json', 'C:\GitHub\SQLpromptSnippets\Styles\', '') AS "New_StyleName"
	FROM #Temp_StyleList
)
SELECT ROW_NUMBER() OVER (ORDER BY CTE.New_StyleName) AS "Id",
	   LTRIM(RTRIM(CTE.Old_StyleName)) AS "Old_StyleName",
	   LTRIM(RTRIM(CTE.New_StyleName)) AS "New_StyleName"
INTO #Final_StyleList
FROM _CTE AS CTE;

SELECT FFL.Id, FFL.Old_StyleName, FFL.New_StyleName
FROM #Final_StyleList AS FFL;

/**************************************************************************************************************************************************************/
/* ===== ** Renaming the Files Only if NewStyleName != ".json" ** ========================================================================================= */
IF EXISTS (SELECT * FROM #Final_StyleList WHERE New_StyleName <> '.json')
BEGIN
	BEGIN TRANSACTION;
	--
	PRINT '/*Files ReNaming Process Started*/';
	PRINT '--';
	--
	DECLARE @i INT, @n INT;
	SELECT @i = MIN(Id), @n  = MAX(Id)
	FROM #Final_StyleList;
	--
	DECLARE @OldStyleName VARCHAR(512), @NewStyleName VARCHAR(512);
	DECLARE @DeleteStyleIfExistsCMD NVARCHAR(4000);
	DECLARE @ReNameStyleCMD NVARCHAR(4000);
	--
	WHILE @i <= @n
	BEGIN
		IF EXISTS (SELECT * FROM #Final_StyleList WHERE Id = @i AND New_StyleName <> '.json')
		BEGIN
			SELECT @OldStyleName = Old_StyleName, @NewStyleName = New_StyleName
			FROM #Final_StyleList
			WHERE Id = @i AND New_StyleName <> '.json';
			--
			SET @DeleteStyleIfExistsCMD = NULL;
			SET @DeleteStyleIfExistsCMD = N'del /S "' + @Folder_Path + N'\' + @NewStyleName + N'"';
			PRINT @DeleteStyleIfExistsCMD;
			EXEC sys.xp_cmdshell @command = @DeleteStyleIfExistsCMD;
			--
			SET @ReNameStyleCMD = NULL;
			SET @ReNameStyleCMD = N'rename "' + @OldStyleName + N'" "' + @NewStyleName + N'"';
			PRINT @ReNameStyleCMD;
			EXEC sys.xp_cmdshell @command = @ReNameStyleCMD;
			--
			PRINT 'Changed => ' + @ReNameStyleCMD;
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
	RAISERROR('Aborting Renaming Files as StyleName would be Truncated to ".json".', 18, 1) WITH NOWAIT;
	EXEC sys.xp_cmdshell @command = 'pause';
END;
--
/* ===== ** Deleting the Flie "FileList.txt" Again which is Created for this Process ** ===================================================================== */
EXEC sys.xp_cmdshell @command = @DEL_FileList;