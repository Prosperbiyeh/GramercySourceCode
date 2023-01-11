

/*  LOB Transactions */


-- REMOVED LOB!!!!!!!

SET ANSI_NULLS, QUOTED_IDENTIFIER ON;

--declare @GLCompanyId		varchar(10);
declare @DateFrom			date;
declare @DateTo				date;

begin 






set @DateFrom		= dateadd(d, -1, GetDate())
set @DateTo			= @DateFrom		
--set @GLCompanyId	= '17'



/*  MH 11/5/2021 - To flip sign on out-of-balance JEs */


exec [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].spFin_CostCenterAllocationUpdate


insert into [Sandbox].dbo.FlexiJournalEntries
select /*aaaa.TransactNum,
       */aaaa.[Company Code],
	   aaaa.[GL Effective Date],
	   aaaa.[Journal Code],
/*  MH - 12/10/2021 - Switch [Journal Desc] and [Line Description] for display in Flexi
	   replace(aaaa.[Journal Desc], ',', '') [Journal Desc], */
	   '' [Journal Desc],
	   aaaa.[GL Account],
--	   aaaa.Amount,					
	   sum(aaaa.CCAAmount) Amount, /*
	   IsNull(aaaa.[Line Description], '') [Line Description],
	   IsNull(aaaa.EntityName, '') XREF1,
	   IsNull(aaaa.PolicyNumber, '') XREF2*/
/*  MH - 12/10/2021 - Switch [Journal Desc] and [Line Description] for display in Flexi
	   '' [Line Description], */
	   replace(aaaa.[Journal Desc], ',', '') [Line Description],
	   '' XREF1,
	   '' XREF2,
	   '' [XREF3],
	   '' [Journal ID - Batch #],
	   @DateTo
from (
select --aaa.*,
       aaa.TransactNum,
	   aaa.[GL Account] GLAcctNum,
       bbb.CO "Company Code",
	   aaa.[GL Effective Date],
	   aaa.[Journal Code],
	   aaa.[Journal Desc],
       bbb.CO +
	   replace(bbb.Major, '-', '') +
	   '01' +
	   /*
	   case when aaa.CostCenter = 'Overhead'
	        then '03'
			when aaa.CostCenter = 'NYCON'
			then '01'
			when aaa.CostCenter = 'Consulting'
			then '02' end + */
		'000' + /*
        case when aaa.LineName = 'Commercial Property'
		     then '100'
			 when aaa.LineName = 'Commercial General Liability'
		     then '200'
			 when aaa.LineName = 'Commercial Inland Marine'
		     then '300'
			 when aaa.LineName = 'Commercial Crime'
		     then '400'
			 when aaa.LineName = 'Commercial Auto'
		     then '500'
			 when aaa.LineName = 'Umbrella'
		     then '600' end  + */
--	    IsNull(bbb.LOB, '000') +
--		IsNull(bbb.State, '00') +
--  MH - St Code 32 for NY
        '32' + 
		'00' +
--		IsNull(bbb.Xtra1, '00')
--  MH - Program Code 10 for NYCON
        '10'
			[GL Account],
	   aaa.CCAAmount,
	   aaa.[Line Description],
	   aaa.EntityGuid,
	   aaa.EntityName,
	   aaa.LineName,
	   aaa.PolicyNumber
from (
SELECT jp.TransactNum,
       J.GlCompanyId "Company Code",
       convert(varchar(8), J.PostDate, 112) "GL Effective Date",
	   'IMS PREM' "Journal Code",
	   GL.FullName "Journal Desc",
	   GL.AcctNum "GL Account",
	   jp.Amount,
	   convert(money, CCA.Amount) CCAAmount,
	   jp.Comments "Line Description",
	   jp.EntityGuid,
	   en.EntityName,
	   EG.GroupName,
	   case when EG.GroupId = 2 then 'Overhead' else EG.GroupName end AS [CostCenter],
	   EG.GroupId AS [CostCenterId],
	   GL.GlCompanyId,
	   CO.Location,
	   l.LineName,
	   tq.PolicyNumber PolicyNumber
--	   case when en.EntityType = 'Insured' then tq.PolicyNumber end PolicyNumber
FROM [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].tblFin_GLAccounts GL
INNER JOIN [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].tblFin_JournalPostings jp
  ON JP.GLAcctID = GL.GLAcctID
INNER JOIN [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].tblFin_Journal J
  ON J.TransactNum = JP.TransactNum
INNER JOIN [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].tblFin_Invoices inv
  ON jp.InvoiceNum = inv.InvoiceNum
INNER JOIN [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].tblQuotes tq
  ON inv.QuoteID = tq.QuoteID
LEFT join [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].[viewEntityNames] en
  on jp.EntityGuid = en.EntityGUID
INNER JOIN [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].tblFin_GlAccountTypes GLT
  ON GLT.GlAcctId = GL.GLAcctID
INNER JOIN [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].tblFin_GlFinancialAcctTypes GLFT 
  ON GLFT.GlAcctId = GL.GlAcctId
INNER JOIN [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].lstGLAcctTypes LGT 
  ON LGT.AcctTypeId = GLFT.AcctTypeId
INNER JOIN [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].tblFin_CostCenterAllocation CCA
  ON CCA.PostingNum = JP.PostingNum
INNER JOIN [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].tblEntityGroups EG
  ON EG.GroupId = CCA.CostCenterId AND EG.Inactive = 0
INNER JOIN [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].tblClientOffices CO
  ON CO.OfficeID = GL.GlCompanyId
INNER JOIN [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].tblCompanyLines cl
  ON jp.CompanyLineGuid = cl.CompanyLineGUID
INNER JOIN [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].lstLines l
  ON cl.LineGUID = l.LineGUID
where GL.GlCompanyId = 17
--  MH 08072021 - Changed to use Created date for future and past PostDates, catchup for 07282021 thru 08062021 was run on 08072021
--  and convert(date, J.PostDate) between @DateFrom and @DateTo
  and convert(date, J.Created) between @DateFrom and @DateTo
--  and jp.TransactNum = 26
) aaa
left join [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[ReportReference].[GRMCOALOOKUP] bbb
   on aaa.[GL Account] = bbb.[GLAccount]
--order by 3
--order by aaa.TransactNum 

)aaaa
group by aaaa.[Company Code],
	   aaaa.[GL Effective Date],
	   aaaa.[Journal Code],
	   aaaa.[Journal Desc],
	   aaaa.[GL Account]/*,
	   aaaa.[Line Description],
	   aaaa.EntityGuid,
	   aaaa.EntityName,
	   aaaa.PolicyNumber,
	   aaaa.TransactNum       */
having sum(aaaa.CCAAmount) <> 0



/*  MH  8/27/2021 - Add additional non-Invoice policy premium transactions */



insert into [Sandbox].dbo.FlexiJournalEntries
select --aaaa.TransactNum,
	   aaaa.[Company Code],
	   aaaa.[GL Effective Date],
	   aaaa.[Journal Code],
/*  MH - 12/10/2021 - Switch [Journal Desc] and [Line Description] for display in Flexi
	   replace(aaaa.[Journal Desc], ',', '') [Journal Desc], */
	   IsNull(aaaa.[Line Description], '') [Journal Desc],
	   aaaa.[GL Account],
	   sum(aaaa.CCAAmount) Amount,
/*  MH - 12/10/2021 - Switch [Journal Desc] and [Line Description] for display in Flexi
	   IsNull(aaaa.[Line Description], '') [Line Description], */
	   replace(aaaa.[Journal Desc], ',', '') [Line Description],
--	   aaaa.EntityGuid,
	   IsNull(aaaa.EntityName, '') XREF1,
	   '' XREF2,
	   '' XREF3,
	   '' "Journal ID - Batch #",
	   @DateTo
from (
select --aaa.*,
       aaa.TransactNum,
	   aaa.[GL Account] GLAcctNum,
       bbb.CO "Company Code",
	   aaa.[GL Effective Date],
	   aaa.[Journal Code],
	   aaa.[Journal Desc],
       bbb.CO + 
	   replace(bbb.Major, '-', '') +
	   case when aaa.CostCenter = 'Overhead'
	        then '03'
			when aaa.CostCenter = 'NYCON'
			then '01'
			when aaa.CostCenter = 'Consulting'
			then '02' end +
	    IsNull(bbb.LOB, '000') +
		IsNull(bbb.State, '00') +
		'00' +
		IsNull(bbb.Xtra1, '00')
			[GL Account],
	   aaa.CCAAmount,
	   aaa.[Line Description],
	   aaa.EntityGuid,
	   aaa.EntityName
from (
SELECT jp.TransactNum,
       J.GlCompanyId "Company Code",
       convert(varchar(8), J.PostDate, 112) "GL Effective Date",
	   'IMS PREM' "Journal Code",
	   GL.FullName "Journal Desc",
	   GL.AcctNum "GL Account",
	   jp.Amount,
	   convert(money, CCA.Amount) CCAAmount, /*
	   case when sign(jp.Amount) <> sign(CCA.Amount) 
	        then CCA.Amount * -1
	        else CCA.Amount end CCAAmount, */
	   jp.Comments "Line Description",
	   jp.EntityGuid,
	   en.EntityName,
	   EG.GroupName,
	   case when EG.GroupId = 2 then 'Overhead' else EG.GroupName end AS [CostCenter],
	   EG.GroupId AS [CostCenterId],
	   GL.GlCompanyId,
	   CO.Location
FROM [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].tblFin_GLAccounts GL
INNER JOIN [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].tblFin_JournalPostings jp
  ON JP.GLAcctID = GL.GLAcctID
INNER JOIN [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].tblFin_Journal J
  ON J.TransactNum = JP.TransactNum
LEFT join [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].[viewEntityNames] en
  on jp.EntityGuid = en.EntityGUID
INNER JOIN [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].tblFin_GlAccountTypes GLT
  ON GLT.GlAcctId = GL.GLAcctID
INNER JOIN [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].tblFin_GlFinancialAcctTypes GLFT 
  ON GLFT.GlAcctId = GL.GlAcctId
INNER JOIN [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].lstGLAcctTypes LGT 
  ON LGT.AcctTypeId = GLFT.AcctTypeId
INNER JOIN [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].tblFin_CostCenterAllocation CCA
  ON CCA.PostingNum = JP.PostingNum
INNER JOIN [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].tblEntityGroups EG
  ON EG.GroupId = CCA.CostCenterId AND EG.Inactive = 0
INNER JOIN [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].tblClientOffices CO
  ON CO.OfficeID = GL.GlCompanyId
where GL.GlCompanyId in (17, 18)
  and convert(date, J.Created) between @DateFrom and @DateTo
  and not exists (select 1
				  from [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].tblFin_Invoices fi,
					   [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].tblQuotes tq
				  where fi.InvoiceNum = jp.InvoiceNum
				    and tq.QuoteID = fi.QuoteID)
  and not exists (select 1
				  from [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].tblCompanyLines cl
				  where jp.CompanyLineGuid = cl.CompanyLineGUID)
--  and jp.TransactNum = 32395



) aaa
left join [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[ReportReference].[GRMCOALOOKUP] bbb
       on aaa.[GL Account] = bbb.[GLAccount]
)aaaa
--  MH 11/2/2021 - To get all cost centers
--where aaaa.[GL Account] in ('02110000000402000000000', '02240000000402000000000')
--  MH  2/3/2022 - Just get everything now, a few entries were missed
--where substring(aaaa.[GL Account], 1, 12) in ('021100000004', '022400000004')
group by --aaaa.TransactNum,
       aaaa.[Company Code],
	   aaaa.[GL Effective Date],
	   aaaa.[Journal Code],
	   aaaa.[Journal Desc],
	   aaaa.[GL Account],
	   aaaa.[Line Description],
--	   aaaa.EntityGuid,
	   aaaa.EntityName
order by [GL Account], [Journal Desc], [GL Effective Date]




/*  MH  8/27/2021 - Add Daily MGA Commission Adjustment JEs */

/*  Run from Sandbox  */

/*  MH 08/13/2021 - Need to add Current Month 02-450000000X backout and back all of the Commission Income out each day for Stillwater
					Must run one day at a time */

declare @ReportBeginDate			date;
declare @ReportEndDate				date;
--declare @CompanyID					int;







set @ReportBeginDate    = dateadd(d, -1, GetDate())
--set @ReportBeginDate    = '1/3/2022'
set @ReportEndDate      = @ReportBeginDate
--set @CompanyID			= 7


/*

create table #Auto_Subline_Premium_by_QuoteID (QuoteID int, PolicyNumber varchar(20), ALPrem money, APDPrem money, AutoBTM money)
create nonclustered index idx_QuoteID on #Auto_Subline_Premium_by_QuoteID (QuoteID)

insert into #Auto_Subline_Premium_by_QuoteID
select *
from [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[ReportReference].[v_Auto_Subline_Premium_by_QuoteID]

*/

create table #Results (TransEffDate								char(8),
					   Created									date,
--					   LineName									varchar(100),
					   AmortCategory							varchar(50),
					   TotalAssumedMGACommission				money,
	                   CurrentMonthAssumedMGACommission			money,
					   FutureAssumedMGACommission				money,
					   TotalCommissionIncome					money)

/*

while @ReportBeginDate < convert(date, GetDate())


begin

*/


insert into #Results
select aaaaaaa.TransEffDate,
	   aaaaaaa.Created,
--       aaaaaaa.LineName,
       aaaaaaa.AmortCategory,
	   sum(round(aaaaaaa.TotalAssumedMGACommission, 2)) TotalAssumedMGACommission,
	   sum(round(aaaaaaa.CurrentMonthAssumedMGACommission, 2)) CurrentMonthAssumedMGACommission,
	   sum(round(aaaaaaa.TotalAssumedMGACommission, 2)) -
	   sum(round(aaaaaaa.CurrentMonthAssumedMGACommission, 2)) FutureAssumedMGACommission,
       (select sum(jp.Amount * -1) Amount
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
		  and convert(char(10), j.PostDate, 112) = TransEffDate
		  and convert(date, j.Created) between @ReportBeginDate and @ReportEndDate)  MGACommission

from (
select convert(char(10), aaaaaa.TransDate, 112) TransEffDate,
	   aaaaaa.Created,
--       aaaaaa.LineName,
	   aaaaaa.AmortCategory,
       sum(aaaaaa.AmortMGACommision) TotalAssumedMGACommission,
	   IsNull(
	   sum(case when aaaaaa.AmortYearNum = convert(char(4), datepart(yyyy, aaaaaa.TransDate)) 
	             and aaaaaa.AmortMonthNum = right('00' + convert(varchar(2), datepart(mm, aaaaaa.TransDate)), 2)
	            then aaaaaa.AmortMGACommision end), 0) CurrentMonthAssumedMGACommission
	   
from (

		select aaaaa.QuoteID,
			   aaaaa.EffectiveDate,
			   aaaaa.TransDate,
			   aaaaa.Created,
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
			   aaaa.Created,
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
			   aaa.Created,
			   aaa.EffectiveDate,
			   sum(aaa.Amount) MGACommission
		from (
		select inv.QuoteID, 
			   convert(date, q.EffectiveDate) EffectiveDate,
			   convert(date, j.PostDate) PostDate,
			   convert(date, j.Created) Created,
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
		  and convert(date, j.Created) between @ReportBeginDate and @ReportEndDate
		group by inv.QuoteID, 
			   convert(date, q.EffectiveDate),
			   convert(date, j.PostDate),
			   convert(date, j.Created)
		) aaa
--		where aaa.PostDate between @ReportBeginDate and @ReportEndDate
		group by aaa.QuoteID,
			   aaa.PostDate,
			   aaa.Created,
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
			   aaaaa.Created,
			   aaaaa.AmortCategory
		union all
		select aaaaa.QuoteID,
			   aaaaa.EffectiveDate,
			   aaaaa.TransDate,
			   aaaaa.Created,
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
			   aaaa.Created,
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
			   aaa.Created,
			   aaa.EffectiveDate,
			   sum(aaa.Amount) MGACommission
		from (
		select inv.QuoteID, 
			   convert(date, q.EffectiveDate) EffectiveDate,
			   convert(date, j.PostDate) PostDate,
			   convert(date, j.Created) Created,
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
		  and convert(date, j.Created) between @ReportBeginDate and @ReportEndDate
		group by inv.QuoteID, 
			   convert(date, q.EffectiveDate),
			   convert(date, j.PostDate),
			   convert(date, j.Created)
		) aaa
--		where aaa.PostDate between @ReportBeginDate and @ReportEndDate
		group by aaa.QuoteID,
			   aaa.PostDate,
			   aaa.Created,
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
group by /*aaaaaa.LineName,
	   */convert(char(10), aaaaaa.TransDate, 112),
	   aaaaaa.Created,
	   aaaaaa.AmortCategory
) aaaaaaa
group by aaaaaaa.TransEffDate,
	   aaaaaaa.Created,
--     aaaaaaa.LineName,
       aaaaaaa.AmortCategory
having sum(aaaaaaa.CurrentMonthAssumedMGACommission) <> 0


/*


set @ReportBeginDate = dateadd(d, 1, @ReportBeginDate)
set @ReportEndDate   = @ReportBeginDate



end

*/

/* MH 1/09/2022 - New sync logic for possiblility of multiple Post Dates within one load */


update #Results
set CurrentMonthAssumedMGACommission = CurrentMonthAssumedMGACommission +
									   (select max(TotalCommissionIncome) -sum(TotalAssumedMGACommission)
									    from #Results a
										where #Results.TransEffDate = a.TransEffDate
										  and #Results.Created = a.Created)
where AmortCategory = 'Underwriting'





/* MH 1/09/2022 - Old sync for old one day load logic
-- MH 8/23/2021 - To sync Commission Income backout to Initial Commission Income JE for this Date Range (one day on go live)
--				  Adjust both the Commission Income and Underwriting Revenue JEs here

declare @CommAndUWRevenueAdj	money
set @CommAndUWRevenueAdj = 0



select @CommAndUWRevenueAdj = IsNull(aaaaa.Amount, 0)
from (
select sum(aaaa.CCAAmount) + (select sum(FutureAssumedMGACommission) + 
									 sum(CurrentMonthAssumedMGACommission)
							  from #Results) Amount
from (
select --aaa.*,
       aaa.TransactNum,
	   aaa.[GL Account] GLAcctNum,
       bbb.CO "Company Code",
	   aaa.[GL Effective Date],
	   aaa.[Journal Code],
	   aaa.[Journal Desc],
       bbb.CO +
	   replace(bbb.Major, '-', '') +
	   '01' +
	   '000' + 
       '32' + 
	   '00' +
       '10'
			[GL Account],
	   aaa.CCAAmount,
	   aaa.[Line Description],
	   aaa.EntityGuid,
	   aaa.EntityName,
	   aaa.LineName,
	   aaa.PolicyNumber
from (
SELECT jp.TransactNum,
       J.GlCompanyId "Company Code",
       convert(varchar(8), J.PostDate, 112) "GL Effective Date",
	   'IMS PREM' "Journal Code",
	   GL.FullName "Journal Desc",
	   GL.AcctNum "GL Account",
	   jp.Amount,
	   convert(money, CCA.Amount) CCAAmount,
	   jp.Comments "Line Description",
	   jp.EntityGuid,
	   en.EntityName,
	   EG.GroupName,
	   case when EG.GroupId = 2 then 'Overhead' else EG.GroupName end AS [CostCenter],
	   EG.GroupId AS [CostCenterId],
	   GL.GlCompanyId,
	   CO.Location,
	   l.LineName,
	   tq.PolicyNumber PolicyNumber
FROM [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].tblFin_GLAccounts GL
INNER JOIN [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].tblFin_JournalPostings jp
  ON JP.GLAcctID = GL.GLAcctID
INNER JOIN [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].tblFin_Journal J
  ON J.TransactNum = JP.TransactNum
INNER JOIN [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].tblFin_Invoices inv
  ON jp.InvoiceNum = inv.InvoiceNum
INNER JOIN [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].tblQuotes tq
  ON inv.QuoteID = tq.QuoteID
INNER JOIN [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].tblCompanyLocations cloc
  ON tq.CompanyLocationGUID = cloc.CompanyLocationGUID
INNER JOIN [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].tblCompanies comp
  ON cloc.CompanyGUID = comp.CompanyGUID
LEFT join [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].[viewEntityNames] en
  on jp.EntityGuid = en.EntityGUID
INNER JOIN [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].tblFin_GlAccountTypes GLT
  ON GLT.GlAcctId = GL.GLAcctID
INNER JOIN [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].tblFin_GlFinancialAcctTypes GLFT 
  ON GLFT.GlAcctId = GL.GlAcctId
INNER JOIN [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].lstGLAcctTypes LGT 
  ON LGT.AcctTypeId = GLFT.AcctTypeId
INNER JOIN [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].tblFin_CostCenterAllocation CCA
  ON CCA.PostingNum = JP.PostingNum
INNER JOIN [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].tblEntityGroups EG
  ON EG.GroupId = CCA.CostCenterId AND EG.Inactive = 0
INNER JOIN [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].tblClientOffices CO
  ON CO.OfficeID = GL.GlCompanyId
INNER JOIN [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].tblCompanyLines cl
  ON jp.CompanyLineGuid = cl.CompanyLineGUID
INNER JOIN [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].lstLines l
  ON cl.LineGUID = l.LineGUID
where GL.GlCompanyId = 17
--  and convert(date, J.Created) <= @ReportEndDate
  and convert(date, J.PostDate) between @ReportBeginDate and @ReportEndDate
) aaa
left join [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[ReportReference].[GRMCOALOOKUP] bbb
   on aaa.[GL Account] = bbb.[GLAccount]

)aaaa
where aaaa.[GL Account] = '02450000000101000320010'
group by aaaa.[Company Code],
	   aaaa.[GL Effective Date],
	   aaaa.[Journal Code],
	   aaaa.[Journal Desc],
	   aaaa.[GL Account]
) aaaaa



select @CommAndUWRevenueAdj



select *
from #Results



*/

-- Deferred

insert into [Sandbox].dbo.FlexiJournalEntries
select *, '', '', @ReportEndDate
from (
select '02' [Company Code],
        aaaaaa.TransEffDate [GL Effective Date],
		'IMS PREM' [Journal Code],
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
		sum(aaaaaa.FutureAssumedMGACommission) * -1 Amount,
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



-- Current Month



select '02' [Company Code],
        aaaaaa.TransEffDate [GL Effective Date],
		'IMS PREM' [Journal Code],
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
/* MH 1/09/2022 - Old sync for old one day load logic
		sum(aaaaaa.CurrentMonthAssumedMGACommission) * -1 +
		case when aaaaaa.AmortCategory = 'Underwriting'
		     then @CommAndUWRevenueAdj
			 else 0 end	Amount, */
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



union all

/* One Balancing Entry for the sum of the deferred and current month */



select '02' [Company Code],
        aaaaaa.TransEffDate [GL Effective Date],
		'IMS PREM' [Journal Code],
/*  MH - 12/10/2021 - Switch [Journal Desc] and [Line Description] for display in Flexi
		'Commission Income' "Journal Desc", */
	   '' [Journal Desc],
	   '02' + -- Company Code
	   '4500000001' +
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
/* MH 1/09/2022 - Old sync for old one day load logic
		sum(aaaaaa.FutureAssumedMGACommission) + sum(aaaaaa.CurrentMonthAssumedMGACommission) - @CommAndUWRevenueAdj Amount, */
		sum(aaaaaa.FutureAssumedMGACommission) + sum(aaaaaa.CurrentMonthAssumedMGACommission) Amount,
/*  MH - 12/10/2021 - Switch [Journal Desc] and [Line Description] for display in Flexi
	   '' [Line Description], */
		'Commission Income' [Line Description],
	   '' XREF1,
	   '' XREF2
from #Results aaaaaa
group by aaaaaa.TransEffDate
) aaaaaaa
where Amount <> 0


drop table #Results

declare @RecordCount	int


select @RecordCount = count(*)
from [Sandbox].[dbo].[FlexiJournalEntries] a 
where [Load Date] = convert(date, dateadd(d, -1, GetDate())) 
  and [Journal Code] = 'IMS PREM'


if @RecordCount > 0

	begin

		exec master..xp_cmdshell 'sqlcmd -s, -W -Q "set nocount on; select a.[Company Code], a.[GL Effective Date], a.[Journal Code], a.[Journal Desc], a.[GL Account], a.Amount, a.[Line Description], a.XREF1, a.XREF2, a.XREF3, a.[Journal ID - Batch #] from [Sandbox].[dbo].[FlexiJournalEntries] a where [Load Date] = convert(date, dateadd(d, -1, GetDate())) and [Journal Code] = ''IMS PREM'' /* and [Company Code] = ''02''*/ " | findstr /v /c:"-" /b > "E:\FlexiExport\FlexiDailyPrem.csv"'
		exec master..xp_cmdshell 'ren E:\FlexiExport\"FlexiDailyPrem.csv" "FlexiDailyPrem-%date:~10,4%%date:~4,2%%date:~7,2%.csv"'
		exec master..xp_cmdshell 'E:\FlexiExport\SFTPtoFlexiPROD.bat'
	end


end