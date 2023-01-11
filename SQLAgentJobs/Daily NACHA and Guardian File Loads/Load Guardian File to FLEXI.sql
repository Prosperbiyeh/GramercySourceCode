USE Sandbox
GO


SET NOCOUNT ON
DECLARE @iFileExists INT

EXEC master..xp_fileexist 'E:\GuardianImport\GuardianBillingStatement.csv', 
 @iFileExists OUTPUT

--select @iFileExists

if @iFileExists <> 0

	begin

	truncate table [dbo].[GuardianRawExcelImport]


	BULK INSERT [dbo].[GuardianRawExcelImport]
	FROM 'E:\GuardianImport\GuardianBillingStatement.csv'
	WITH (FORMAT = 'CSV'
		  , DATAFILETYPE = 'char'
		  , FIRSTROW=6
		  , FIELDTERMINATOR=','
		  , ROWTERMINATOR = '0x0a');

	exec master..xp_cmdshell 'E:\GuardianImport\ArchiveGuardianBillingStatement.bat'

	insert into [dbo].[GuardianJournalEntries]
	select *
	from [dbo].[v_GuardianJournalEntries]

	exec master..xp_cmdshell 'sqlcmd -s, -W -Q "set nocount on; select a.[Company Code], a.[GL Effective Date], a.[Journal Code], a.[Journal Desc], a.[GL Account], a.Amount, a.[Line Description], a.XREF1, a.XREF2, a.XREF3, a.[Journal ID - Batch #] from [Sandbox].[dbo].[v_GuardianJournalEntries] a" | findstr /v /c:"-" /b > "E:\GuardianImport\FlexiExport\FlexiGuardianBS.csv"'
	exec master..xp_cmdshell 'ren E:\GuardianImport\FlexiExport\"FlexiGuardianBS.csv" "FlexiGuardianBS-%date:~10,4%%date:~4,2%%date:~7,2%.csv"'
	exec master..xp_cmdshell 'E:\GuardianImport\FlexiExport\SFTPtoFlexiPROD.bat'

end