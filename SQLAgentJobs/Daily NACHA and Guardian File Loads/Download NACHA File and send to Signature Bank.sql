USE Sandbox




/* Get ACH Nacha file from Flexi SFTP site */


exec master..xp_cmdshell 'E:\FlexiExport\GetACHFileFromFlexiProd.bat'


/* Load [dbo].[ACH_Import] table */




truncate table [dbo].[ACH_Import_FileList]

BULK INSERT [dbo].[ACH_Import_FileList]
FROM 'E:\FlexiExport\Import\ACH\dirfile.lst'
WITH (FIELDTERMINATOR = '","', 
--      ROWTERMINATOR = '",\n"',
		ROWTERMINATOR = '0x0a',
		FIRSTROW = 1);

if @@ROWCOUNT <> 0

begin


	--  Fix right end character padding


	update [dbo].[ACH_Import_FileList]
	set FileName = substring(FileName, 1, len(FileName) - 1)
	where right(FileName, 3) <> 'txt'


	DECLARE @sql As VARCHAR(MAX);
	SET @sql = '';

	DECLARE @FileName	varchar(200);
	DECLARE @Command	varchar(500);

	DECLARE FileCursor CURSOR FAST_FORWARD READ_ONLY
	FOR
	SELECT  a.FileName
	FROM    [dbo].[ACH_Import_FileList] a
	where a.FileName like 'GRC-SIG%'
	  and not exists (select 1
					  from [dbo].[ACH_FileList] aa
					  where aa.FileName = a.FileName)
	order by 1;

	-- To see if there are any files to transmit

	DECLARE @FileCounter	int
	set @FileCounter = 0

	OPEN FileCursor

	 FETCH NEXT FROM FileCursor INTO @FileName

	 WHILE @@FETCH_STATUS = 0
		BEGIN
	--	    PRINT @FileName
			set @sql = ''
			SELECT @sql = @sql + REPLACE(REPLACE(REPLACE('
				BULK INSERT [dbo].[v_ACH_ImportData]
				FROM ''E:\FlexiExport\Import\ACH\Pending\*''
				WITH (FIELDTERMINATOR = '','', ROWTERMINATOR = ''\n'', FIRSTROW = 1 );
				', '*', FileName), CHAR(13), ''), CHAR(10), '')
			FROM    [dbo].[ACH_Import_FileList]
			WHERE   FileName = @FileName;

			--PRINT @sql;
			EXEC(@sql);

			insert into [dbo].[ACH_FileList] values (@FileName, GetDate())

			insert into [dbo].[ACH_FileData]
			select @FileName, ImportData, GetDate(), RecordSeq
			from [dbo].[ACH_ImportData]		

			insert into [dbo].[ACH_FileExport]
			select distinct @FileName, 'Pending', GetDate()
			from [dbo].[ACH_ImportData]	

			set @Command = REPLACE(REPLACE('move E:\FlexiExport\Import\ACH\Pending\' + @FileName + ' E:\FlexiExport\Import\ACH\Loaded\' + @FileName, CHAR(13), ''), CHAR(10), '')

			exec master..xp_cmdshell @Command


	--  Write out Transmittal and NACHA files to Export Directory
        
			declare @ExportFileName	varchar(150)

			set @ExportFileName = (select 'Transmittal_' + substring(FileName, CHARINDEX('ACH', FileName), 11)  + '.GR3.txt'
									from [dbo].[v_ACH_FileTransmittalFormattedData]
									where FileName = @FileName
									  and RowNumber = 1)

			set @Command = 'sqlcmd /h-1 -s, -W -Q "set nocount on; select Text from [Sandbox].[dbo].[v_ACH_FileTransmittalFormattedData] where FileName = ''' + @FileName + ''' order by RowNumber" | findstr /v /c:"-" /b > "E:\SigBankACHExport\' + @ExportFileName + '"'
			--print @Command

			exec master..xp_cmdshell @Command

			set @ExportFileName = (select substring(FileName, CHARINDEX('ACH', FileName), 11)  + '.GR3.txt'
									from [dbo].[v_ACH_FileTransmittalFormattedData]
									where FileName = @FileName
									  and RowNumber = 1)

	-- Save this for now, but for the time being don't order the rows in the NACHA file, 
	-- let the table load and query naturally rely on the file line order							  

	--		set @Command = 'sqlcmd /h-1 -s, -W -Q "set nocount on; select FileData from [Sandbox].[dbo].[ACH_FileData] where FileName = ''' + @FileName + ''' order by left(FileData, 1), case when left(FileData, 1) = ''6'' then substring(FileData, 80, 15) end" | findstr /v /c:"-" /b > "E:\SigBankACHExport\' + @ExportFileName + '"'

			set @Command = 'sqlcmd /h-1 -s, -W -Q "set nocount on; select FileData from [Sandbox].[dbo].[ACH_FileData] where FileName = ''' + @FileName + ''' order by RecordSeq" | findstr /v /c:"-" /b > "E:\SigBankACHExport\' + @ExportFileName + '"'
			--print @Command

			exec master..xp_cmdshell @Command

			truncate table [dbo].[ACH_ImportData]

			set @FileCounter = @FileCounter + 1

			update [dbo].[ACH_FileExport]
			set ExportStatus = 'Loaded'
			where FileName = @FileName

			FETCH NEXT FROM FileCursor INTO @FileName

		END

	 CLOSE FileCursor
	 DEALLOCATE FileCursor



	 if @FileCounter > 0
	 begin

		exec master..xp_cmdshell 'E:\SigBankACHExport\Export_SB_ACH_File.bat'

	 end




end

