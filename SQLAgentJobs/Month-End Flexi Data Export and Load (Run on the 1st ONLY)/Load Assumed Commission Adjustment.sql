/*  Run from Sandbox  */

/*  MH 08/25/2021 - New process to move all deferred MGA commission realized in the previous month from deferred to realized (earned).
					The transaction date (ReportEndDate) will be one month and one day prior to the 1st of the report month, so running 
					this for July 2021 would only use transactions that were booked prior to June 1st.  Get the MGA commission for 
					AmortYearNum = 2021	and AmortMonthNum = 7 only and create JEs to pull that commission out of the deferred GL Accounts 
					and into the realized (earned)GL Accounts
*/

declare @ReportBeginDate			date;
declare @ReportEndDate				date;
declare @CompanyID					int;



begin 


-- Run back to the start of the book, so:
set @ReportBeginDate    = '1/1/2018'
--  MH  12/8/2021 - This date should be the PREVIOUS month-end date
-- set @ReportEndDate      = dateadd(d, -1, GetDate())
set @ReportEndDate      = dateadd(d, -1, GetDate())

-- Uncomment to test a previous month-end load
-- set @ReportEndDate      = dateadd(d, -1, '12/1/2021')

--  Uncomment to hard-code @ReportEndDate
-- set @ReportEndDate      = '9/30/2021'
-- @CompanyID is not used for this process
set @CompanyID			= 7

declare @AmortYearNum		int
declare @AmortMonthNum		int
declare @HldReportEndDate	date

/*  MH  12/21/2021 - The AmortYearNum should be using dateadd(m, 1, @ReportEndDate), not @ReportEndDate 
set @AmortYearNum		= datepart(yyyy, @ReportEndDate) */
set @AmortYearNum		= datepart(yyyy, dateadd(m, 1, @ReportEndDate))
set @AmortMonthNum		= datepart(mm, dateadd(m, 1, @ReportEndDate))


-- This variable is only for the GL Effective Posting date, which is the 1st of the month AFTER the @ReportEndDate 
-- (the run date when auto-running on the 1st of each month)
-- set @HldReportEndDate	= dateadd(m, 1, dateadd(d, 1, @ReportEndDate))
set @HldReportEndDate	= dateadd(d, 1, @ReportEndDate)

/*

create table #Auto_Subline_Premium_by_QuoteID (QuoteID int, PolicyNumber varchar(20), ALPrem money, APDPrem money, AutoBTM money)
create nonclustered index idx_QuoteID on #Auto_Subline_Premium_by_QuoteID (QuoteID)

insert into #Auto_Subline_Premium_by_QuoteID
select *
from [MGADS0005.NY.MGASYSTEMS.COM].[MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[ReportReference].[v_Auto_Subline_Premium_by_QuoteID]

*/

create table #Results (TransEffDate								char(8),
--					   LineName									varchar(100),
					   AmortCategory							varchar(50),
					   TotalAssumedMGACommission				money,
	                   CurrentMonthAssumedMGACommission			money)


insert into #Results
select aaaaaaa.TransEffDate,
--       aaaaaaa.LineName,
       aaaaaaa.AmortCategory,
	   sum(round(aaaaaaa.TotalAssumedMGACommission, 2)) TotalAssumedMGACommission,
	   sum(round(aaaaaaa.CurrentMonthAssumedMGACommission, 2)) CurrentMonthAssumedMGACommission

from (
select convert(char(10), @HldReportEndDate, 112) TransEffDate,
--       aaaaaa.LineName,
	   aaaaaa.AmortCategory,
       sum(aaaaaa.AmortMGACommision) TotalAssumedMGACommission,
	   sum(case when aaaaaa.AmortYearNum = @AmortYearNum and aaaaaa.AmortMonthNum = @AmortMonthNum
	            then aaaaaa.AmortMGACommision end) CurrentMonthAssumedMGACommission
	   
from (
select aaaaa.QuoteID,
	   aaaaa.EffectiveDate,
	   aaaaa.TransDate,
--	   max(aaaaa.MonthNum) MonthNum,
       convert(varchar(2), datepart(mm, aaaaa.TransDate)) MonthNum,
	   aaaaa.AmortCategory,
--     max(aaaaa.AmortYearNum) AmortYearNum,
--     DATENAME(MONTH, DATEADD(MONTH, convert(int, max(aaaaa.AmortMonthNum)), '2020-12-01')) AmortMonthName,
--	   max(aaaaa.AmortMonthNum) AmortMonthNum,
       convert(varchar(4), datepart(yyyy, aaaaa.TransDate)) AmortYearNum,
       DATENAME(MONTH, aaaaa.TransDate) AmortMonthName,
	   right('00' + convert(varchar(2), datepart(mm, aaaaa.TransDate)), 2) AmortMonthNum,
	   sum(aaaaa.AmortPct) AmortPct,
	   sum(aaaaa.AmortMGACommision) AmortMGACommision
from (
select aaaa.QuoteID,
	   aaaa.EffectiveDate,
	   aaaa.TransDate,
	   crtpa.MonthNum,
	   crtpa.AmortCategory, /*
       datepart(yyyy, dateadd(m, crtpa.MonthNum - 1, aaaa.TransDate)) AmortYearNum,
       datename(mm, dateadd(m, crtpa.MonthNum - 1, aaaa.TransDate)) AmortMonthName,
	   right('00' + convert(varchar, datepart(mm, dateadd(m, crtpa.MonthNum - 1, aaaa.TransDate))), 2) AmortMonthNum, */
       datepart(yyyy, dateadd(m, crtpa.MonthNum - 1, aaaa.EffectiveDate)) AmortYearNum,
       datename(mm, dateadd(m, crtpa.MonthNum - 1, aaaa.EffectiveDate)) AmortMonthName,
	   right('00' + convert(varchar, datepart(mm, dateadd(m, crtpa.MonthNum - 1, aaaa.EffectiveDate))), 2) AmortMonthNum,
	   crtpa.AmortPct,
	   convert(money, aaaa.MGACommission * crtpa.AmortPct) AmortMGACommision
from (
select aaa.QuoteID,
       aaa.PostDate TransDate,
       aaa.EffectiveDate,
       sum(aaa.Amount) MGACommission
from (
select inv.QuoteID, 
       convert(date, q.EffectiveDate) EffectiveDate,
       min(convert(date, j.PostDate)) PostDate,
       sum(jp.Amount * -1) Amount
from [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].[tblQuotes] q,
     [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].[tblFin_Invoices] inv,
     [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].[tblFin_JournalPostings] jp,
	 [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].[tblFin_Journal] j,
     [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].[tblCompanyLines] cl,
	 [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].[tblCompanyLocations] cloc,
	 [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].[tblCompanies] co
where q.QuoteID = inv.QuoteID
  and inv.Failed = 0
  and inv.InvoiceNum = jp.InvoiceNum
  and jp.TransactNum = j.TransactNum
  and jp.GLAcctID = 179 -- Commission Income
  and q.CompanyLineGuid = cl.CompanyLineGUID
  and q.CompanyLocationGuid = cloc.CompanyLocationGUID
  and cloc.CompanyGUID = co.CompanyGUID
  and co.CompanyName <> 'Placeholder Company'
group by inv.QuoteID,
       q.EffectiveDate
) aaa
where aaa.PostDate between @ReportBeginDate and @ReportEndDate
group by aaa.QuoteID,
       aaa.PostDate,
       aaa.EffectiveDate
) aaaa,
     [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[ReportReference].[CompanyReinsTreatyPremAmort] crtpa
where aaaa.EffectiveDate between crtpa.PolEffBeginDate and crtpa.PolEffEndDate
--  and aaaa.QuoteID = 502
--  and aaaa.LineName = 'Commercial Crime'
) aaaaa
where dateadd(d, -1, 
	  dateadd(m,  1, convert(date, convert(char(4), datepart(yyyy, aaaaa.TransDate))  + '-' +
								   convert(char(2), datepart(mm,   aaaaa.TransDate))  + '-' + '01'))) >= 
	  dateadd(d, -1, 
	  dateadd(m,  1, convert(date, convert(char(4), aaaaa.AmortYearNum)  + '-' +
								   convert(char(2), aaaaa.AmortMonthNum) + '-' + '01')))
group by  aaaaa.QuoteID,
	   aaaaa.EffectiveDate,
	   aaaaa.TransDate,
	   aaaaa.AmortCategory
union all
select aaaaa.QuoteID,
	   aaaaa.EffectiveDate,
	   aaaaa.TransDate,
	   aaaaa.MonthNum,
	   aaaaa.AmortCategory,
       aaaaa.AmortYearNum,
       aaaaa.AmortMonthName,
	   aaaaa.AmortMonthNum,
	   aaaaa.AmortPct,
	   aaaaa.AmortMGACommision
from (
select aaaa.QuoteID,
	   aaaa.EffectiveDate,
	   aaaa.TransDate,
	   crtpa.MonthNum,
	   crtpa.AmortCategory, /*
       datepart(yyyy, dateadd(m, crtpa.MonthNum - 1, aaaa.TransDate)) AmortYearNum,
       datename(mm, dateadd(m, crtpa.MonthNum - 1, aaaa.TransDate)) AmortMonthName,
	   right('00' + convert(varchar, datepart(mm, dateadd(m, crtpa.MonthNum - 1, aaaa.TransDate))), 2) AmortMonthNum, */
       datepart(yyyy, dateadd(m, crtpa.MonthNum - 1, aaaa.EffectiveDate)) AmortYearNum,
       datename(mm, dateadd(m, crtpa.MonthNum - 1, aaaa.EffectiveDate)) AmortMonthName,
	   right('00' + convert(varchar, datepart(mm, dateadd(m, crtpa.MonthNum - 1, aaaa.EffectiveDate))), 2) AmortMonthNum,
	   crtpa.AmortPct,
	   convert(money, aaaa.MGACommission * crtpa.AmortPct) AmortMGACommision
	   
from (
select aaa.QuoteID,
       aaa.PostDate TransDate,
       aaa.EffectiveDate,
       sum(aaa.Amount) MGACommission
from (
select inv.QuoteID, 
       convert(date, q.EffectiveDate) EffectiveDate,
       min(convert(date, j.PostDate)) PostDate,
       sum(jp.Amount * -1) Amount
from [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].[tblQuotes] q,
     [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].[tblFin_Invoices] inv,
     [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].[tblFin_JournalPostings] jp,
	 [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].[tblFin_Journal] j,
     [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].[tblCompanyLines] cl,
	 [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].[tblCompanyLocations] cloc,
	 [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].[tblCompanies] co
where q.QuoteID = inv.QuoteID
  and inv.Failed = 0
  and inv.InvoiceNum = jp.InvoiceNum
  and jp.TransactNum = j.TransactNum
  and jp.GLAcctID = 179 -- Commission Income
  and q.CompanyLineGuid = cl.CompanyLineGUID
  and q.CompanyLocationGuid = cloc.CompanyLocationGUID
  and cloc.CompanyGUID = co.CompanyGUID
  and co.CompanyName <> 'Placeholder Company'
group by inv.QuoteID,
       q.EffectiveDate
) aaa
where aaa.PostDate between @ReportBeginDate and @ReportEndDate
group by aaa.QuoteID,
       aaa.PostDate,
       aaa.EffectiveDate
) aaaa,
     [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[ReportReference].[CompanyReinsTreatyPremAmort] crtpa
where aaaa.EffectiveDate between crtpa.PolEffBeginDate and crtpa.PolEffEndDate
--  and aaaa.QuoteID = 502
--  and aaaa.LineName = 'Commercial Crime'
) aaaaa
where dateadd(d, -1, 
	  dateadd(m,  1, convert(date, convert(char(4), datepart(yyyy, aaaaa.TransDate))  + '-' +
								   convert(char(2), datepart(mm,   aaaaa.TransDate))  + '-' + '01'))) < 
	  dateadd(d, -1, 
	  dateadd(m,  1, convert(date, convert(char(4), aaaaa.AmortYearNum)  + '-' +
								   convert(char(2), aaaaa.AmortMonthNum) + '-' + '01')))
) aaaaaa
group by --aaaaaa.LineName,
	   aaaaaa.AmortCategory
) aaaaaaa
group by aaaaaaa.TransEffDate,
--   aaaaaaa.LineName,
   aaaaaaa.AmortCategory
having sum(aaaaaaa.CurrentMonthAssumedMGACommission) <> 0


/*


select *
from #Results


*/


-- Reset @RptEndDate to GL Posting Date
/*  MH  - 12/21/2021 - Don't need this now, the LoadDate for the FlexiJournalEntries and FlexiJournalEntriesCommissionAdjustment
                       tables should be the current date and is consistent with the query to create the csv file down below

set @ReportEndDate = @HldReportEndDate
*/

-- AdjustDeferred

insert into [Sandbox].dbo.FlexiJournalEntries
select *, '', '', convert(date, GetDate())
from (
select '02' [Company Code],
        aaaaaa.TransEffDate [GL Effective Date],
		'IMS' [Journal Code],
/*  MH - 12/10/2021 - Switch [Journal Desc] and [Line Description] for display in Flexi
		case when aaaaaa.AmortCategory = 'Underwriting'
	        then 'Deferred Underwriting Revenue'
			when aaaaaa.AmortCategory = 'Servicing'
	        then 'Deferred Servicing Revenue'
			when aaaaaa.AmortCategory = 'Loss Control'
	        then 'Deferred Loss Control Revenue'
			when aaaaaa.AmortCategory = 'Claims'
	        then 'Deferred Claims Revenue' end "Journal Desc", */
	   '' [Journal Desc],
	   '02' + -- Company Code
	   case when aaaaaa.AmortCategory = 'Underwriting'
	        then '2900000007'
			when aaaaaa.AmortCategory = 'Servicing'
	        then '2900000009'
			when aaaaaa.AmortCategory = 'Loss Control'
	        then '2900000008'
			when aaaaaa.AmortCategory = 'Claims'
	        then '2900000003' end +
--       '101401510002' + 
       '01' + -- Cost Center
	   '000' + -- LOB
 /*      case when aaaaaa.LineName = 'Commercial Property'
		     then '100'
			 when aaaaaa.LineName = 'Commercial General Liability'
		     then '200'
			 when aaaaaa.LineName = 'Commercial Inland Marine'
		     then '300'
			 when aaaaaa.LineName = 'Commercial Crime'
		     then '400'
			 when aaaaaa.LineName = 'Commercial Auto Liability'
		     then '501'
			 when aaaaaa.LineName = 'Commercial Auto PD'
		     then '502'
			 when aaaaaa.LineName = 'Umbrella'
		     then '600' end  + */
--  MH - St Code 32 for NY
        '32' + 
		'00' +
--		IsNull(bbb.Xtra1, '00')
--  MH - Program Code 10 for NYCON
        '10' [GL Account],
		sum(aaaaaa.CurrentMonthAssumedMGACommission)  Amount,
/*  MH - 12/10/2021 - Switch [Journal Desc] and [Line Description] for display in Flexi
	   '' [Line Description], */
		case when aaaaaa.AmortCategory = 'Underwriting'
	        then 'Deferred Underwriting Revenue'
			when aaaaaa.AmortCategory = 'Servicing'
	        then 'Deferred Servicing Revenue'
			when aaaaaa.AmortCategory = 'Loss Control'
	        then 'Deferred Loss Control Revenue'
			when aaaaaa.AmortCategory = 'Claims'
	        then 'Deferred Claims Revenue' end [Line Description],
	   '' XREF1,
	   '' XREF2
from #Results aaaaaa
group by aaaaaa.TransEffDate,
         aaaaaa.AmortCategory




union all



-- Adjust Current Month



select '02' [Company Code],
        aaaaaa.TransEffDate [GL Effective Date],
		'IMS' [Journal Code],
/*  MH - 12/10/2021 - Switch [Journal Desc] and [Line Description] for display in Flexi
		case when aaaaaa.AmortCategory = 'Underwriting'
	        then 'Underwriting Revenue'
			when aaaaaa.AmortCategory = 'Servicing'
	        then 'Servicing Revenue'
			when aaaaaa.AmortCategory = 'Loss Control'
	        then 'Loss Control Revenue'
			when aaaaaa.AmortCategory = 'Claims'
	        then 'Claims Revenue' end "Journal Desc", */
	   '' [Journal Desc],
	   '02' + -- Company Code
	   case when aaaaaa.AmortCategory = 'Underwriting'
	        then '4500000007'
			when aaaaaa.AmortCategory = 'Servicing'
	        then '4500000009'
			when aaaaaa.AmortCategory = 'Loss Control'
	        then '4500000008'
			when aaaaaa.AmortCategory = 'Claims'
	        then '4500000004' end +
--       '101401510002' + 
       '01' + -- Cost Center
	   '000' + -- LOB
 /*      case when aaaaaa.LineName = 'Commercial Property'
		     then '100'
			 when aaaaaa.LineName = 'Commercial General Liability'
		     then '200'
			 when aaaaaa.LineName = 'Commercial Inland Marine'
		     then '300'
			 when aaaaaa.LineName = 'Commercial Crime'
		     then '400'
			 when aaaaaa.LineName = 'Commercial Auto Liability'
		     then '501'
			 when aaaaaa.LineName = 'Commercial Auto PD'
		     then '502'
			 when aaaaaa.LineName = 'Umbrella'
		     then '600' end  + */
--  MH - St Code 32 for NY
        '32' + 
		'00' +
--		IsNull(bbb.Xtra1, '00')
--  MH - Program Code 10 for NYCON
        '10' [GL Account],
		sum(aaaaaa.CurrentMonthAssumedMGACommission) * -1 Amount,
/*  MH - 12/10/2021 - Switch [Journal Desc] and [Line Description] for display in Flexi
	   '' [Line Description], */
		case when aaaaaa.AmortCategory = 'Underwriting'
	        then 'Underwriting Revenue'
			when aaaaaa.AmortCategory = 'Servicing'
	        then 'Servicing Revenue'
			when aaaaaa.AmortCategory = 'Loss Control'
	        then 'Loss Control Revenue'
			when aaaaaa.AmortCategory = 'Claims'
	        then 'Claims Revenue' end [Line Description],
	   '' XREF1,
	   '' XREF2
from #Results aaaaaa
group by aaaaaa.TransEffDate,
         aaaaaa.AmortCategory
) aaaaaaa




/* So the csv file process only picks up the entries from this process */



insert into [Sandbox].dbo.FlexiJournalEntriesCommissionAdjustment
select *, '', '', convert(date, GetDate())
from (
select '02' [Company Code],
        aaaaaa.TransEffDate [GL Effective Date],
		'IMS' [Journal Code],
/*  MH - 12/10/2021 - Switch [Journal Desc] and [Line Description] for display in Flexi
		case when aaaaaa.AmortCategory = 'Underwriting'
	        then 'Deferred Underwriting Revenue'
			when aaaaaa.AmortCategory = 'Servicing'
	        then 'Deferred Servicing Revenue'
			when aaaaaa.AmortCategory = 'Loss Control'
	        then 'Deferred Loss Control Revenue'
			when aaaaaa.AmortCategory = 'Claims'
	        then 'Deferred Claims Revenue' end "Journal Desc", */
	   '' [Journal Desc],
	   '02' + -- Company Code
	   case when aaaaaa.AmortCategory = 'Underwriting'
	        then '2900000007'
			when aaaaaa.AmortCategory = 'Servicing'
	        then '2900000009'
			when aaaaaa.AmortCategory = 'Loss Control'
	        then '2900000008'
			when aaaaaa.AmortCategory = 'Claims'
	        then '2900000003' end +
--       '101401510002' + 
       '01' + -- Cost Center
	   '000' + -- LOB
 /*      case when aaaaaa.LineName = 'Commercial Property'
		     then '100'
			 when aaaaaa.LineName = 'Commercial General Liability'
		     then '200'
			 when aaaaaa.LineName = 'Commercial Inland Marine'
		     then '300'
			 when aaaaaa.LineName = 'Commercial Crime'
		     then '400'
			 when aaaaaa.LineName = 'Commercial Auto Liability'
		     then '501'
			 when aaaaaa.LineName = 'Commercial Auto PD'
		     then '502'
			 when aaaaaa.LineName = 'Umbrella'
		     then '600' end  + */
--  MH - St Code 32 for NY
        '32' + 
		'00' +
--		IsNull(bbb.Xtra1, '00')
--  MH - Program Code 10 for NYCON
        '10' [GL Account],
		sum(aaaaaa.CurrentMonthAssumedMGACommission)  Amount,
/*  MH - 12/10/2021 - Switch [Journal Desc] and [Line Description] for display in Flexi
	   '' [Line Description], */
		case when aaaaaa.AmortCategory = 'Underwriting'
	        then 'Deferred Underwriting Revenue'
			when aaaaaa.AmortCategory = 'Servicing'
	        then 'Deferred Servicing Revenue'
			when aaaaaa.AmortCategory = 'Loss Control'
	        then 'Deferred Loss Control Revenue'
			when aaaaaa.AmortCategory = 'Claims'
	        then 'Deferred Claims Revenue' end [Line Description],
	   '' XREF1,
	   '' XREF2
from #Results aaaaaa
group by aaaaaa.TransEffDate,
         aaaaaa.AmortCategory




union all



-- Adjust Current Month



select '02' [Company Code],
        aaaaaa.TransEffDate [GL Effective Date],
		'IMS' [Journal Code],
/*  MH - 12/10/2021 - Switch [Journal Desc] and [Line Description] for display in Flexi
		case when aaaaaa.AmortCategory = 'Underwriting'
	        then 'Underwriting Revenue'
			when aaaaaa.AmortCategory = 'Servicing'
	        then 'Servicing Revenue'
			when aaaaaa.AmortCategory = 'Loss Control'
	        then 'Loss Control Revenue'
			when aaaaaa.AmortCategory = 'Claims'
	        then 'Claims Revenue' end "Journal Desc", */
	   '' [Journal Desc],
	   '02' + -- Company Code
	   case when aaaaaa.AmortCategory = 'Underwriting'
	        then '4500000007'
			when aaaaaa.AmortCategory = 'Servicing'
	        then '4500000009'
			when aaaaaa.AmortCategory = 'Loss Control'
	        then '4500000008'
			when aaaaaa.AmortCategory = 'Claims'
	        then '4500000004' end +
--       '101401510002' + 
       '01' + -- Cost Center
	   '000' + -- LOB
 /*      case when aaaaaa.LineName = 'Commercial Property'
		     then '100'
			 when aaaaaa.LineName = 'Commercial General Liability'
		     then '200'
			 when aaaaaa.LineName = 'Commercial Inland Marine'
		     then '300'
			 when aaaaaa.LineName = 'Commercial Crime'
		     then '400'
			 when aaaaaa.LineName = 'Commercial Auto Liability'
		     then '501'
			 when aaaaaa.LineName = 'Commercial Auto PD'
		     then '502'
			 when aaaaaa.LineName = 'Umbrella'
		     then '600' end  + */
--  MH - St Code 32 for NY
        '32' + 
		'00' +
--		IsNull(bbb.Xtra1, '00')
--  MH - Program Code 10 for NYCON
        '10' [GL Account],
		sum(aaaaaa.CurrentMonthAssumedMGACommission) * -1 Amount,
/*  MH - 12/10/2021 - Switch [Journal Desc] and [Line Description] for display in Flexi
	   '' [Line Description], */
		case when aaaaaa.AmortCategory = 'Underwriting'
	        then 'Underwriting Revenue'
			when aaaaaa.AmortCategory = 'Servicing'
	        then 'Servicing Revenue'
			when aaaaaa.AmortCategory = 'Loss Control'
	        then 'Loss Control Revenue'
			when aaaaaa.AmortCategory = 'Claims'
	        then 'Claims Revenue' end [Line Description],
	   '' XREF1,
	   '' XREF2
from #Results aaaaaa
group by aaaaaa.TransEffDate,
         aaaaaa.AmortCategory
) aaaaaaa



--drop table #Auto_Subline_Premium_by_QuoteID
drop table #Results



exec master..xp_cmdshell 'sqlcmd -s, -W -Q "set nocount on; select [Company Code], [GL Effective Date], [Journal Code], [Journal Desc], [GL Account], Amount, [Line Description], XREF1, XREF2, XREF3, [Journal ID - Batch #] from [Sandbox].[dbo].[FlexiJournalEntriesCommissionAdjustment] where [Load Date] = convert(date, GetDate()) and [Journal Code] = ''IMS'' /* and [Company Code] = ''02''*/ " | findstr /v /c:"-" /b > "E:\FlexiExport\FlexiMonthlyMGACommAdj.csv"'
exec master..xp_cmdshell 'ren E:\FlexiExport\"FlexiMonthlyMGACommAdj.csv" "FlexiMonthlyMGACommAdj-%date:~10,4%%date:~4,2%%date:~7,2%.csv"'
exec master..xp_cmdshell 'E:\FlexiExport\SFTPtoFlexiPROD.bat'



end