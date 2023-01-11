declare @YYYYMM		char(6)

set @YYYYMM = convert(char(6), dateadd(d, -1, GetDate()), 112)


insert into [Sandbox].[dbo].[Results]
select '02' [Company Code],
       convert(char(8), dateadd(d, -1, dateadd(m, 1, convert(date, convert(char(6), [TransEffDate], 112) + '01'))), 112) [GL Effective Date],
	   'IMS GWP' [Journal Code],
	   'GWP Memo Reporting Entry' [Journal Desc],
	   '02400010000001000320010' [GL Account],
       round(sum(GWP), 2) [Amount],
	   'GWP Memo Reporting Entry' [Line Description],
	   '' XREF1,
	   '' XREF2,
	   '' XREF3,
	   '' [Journal ID - Batch #]
from [Sandbox].[dbo].[PremiumByYYYYMMFuture]
where YYYYMM = convert(char(6), [TransEffDate], 112)
  and YYYYMM = @YYYYMM
group by convert(char(6), [TransEffDate], 112)
union all
select '10' [Company Code],
       convert(char(8), dateadd(d, -1, dateadd(m, 1, convert(date, convert(char(6), [TransEffDate], 112) + '01'))), 112) [GL Effective Date],
	   'IMS GWP' [Journal Code],
	   'GWP Memo Reporting Entry' [Journal Desc],
	   '10400010000001000320010' [GL Account],
       round(sum(GWP), 2) [Amount],
	   'GWP Memo Reporting Entry' [Line Description],
	   '' XREF1,
	   '' XREF2,
	   '' XREF3,
	   '' [Journal ID - Batch #]
from [Sandbox].[dbo].[PremiumByYYYYMMFuture]
where YYYYMM = convert(char(6), [TransEffDate], 112)
  and YYYYMM = @YYYYMM
group by convert(char(6), [TransEffDate], 112)

/*
select *
from [Sandbox].[dbo].[Results]
*/

exec master..xp_cmdshell 'sqlcmd -s, -W -Q "set nocount on; select [Company Code], [GL Effective Date], [Journal Code], [Journal Desc], [GL Account], Amount, [Line Description], XREF1, XREF2, XREF3, [Journal ID - Batch #] from [Sandbox].[dbo].[Results] where [Company Code] = ''02'' " | findstr /v /c:"-" /b > "E:\FlexiExport\FlexiGWPMemoCompany02.csv"'
exec master..xp_cmdshell 'sqlcmd -s, -W -Q "set nocount on; select [Company Code], [GL Effective Date], [Journal Code], [Journal Desc], [GL Account], Amount, [Line Description], XREF1, XREF2, XREF3, [Journal ID - Batch #] from [Sandbox].[dbo].[Results] where [Company Code] = ''10'' " | findstr /v /c:"-" /b > "E:\FlexiExport\FlexiGWPMemoCompany10.csv"'
delete from [Sandbox].[dbo].[Results]
exec master..xp_cmdshell 'ren E:\FlexiExport\"FlexiGWPMemoCompany02.csv" "FlexiGWPMemoCompany02-%date:~10,4%%date:~4,2%%date:~7,2%.csv"'
exec master..xp_cmdshell 'ren E:\FlexiExport\"FlexiGWPMemoCompany10.csv" "FlexiGWPMemoCompany10-%date:~10,4%%date:~4,2%%date:~7,2%.csv"'
exec master..xp_cmdshell 'E:\FlexiExport\SFTPtoFlexiPROD.bat'