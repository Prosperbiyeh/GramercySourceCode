

/*  To run from GRAMERCYMGA  */





declare @ReportBeginDate			date;
declare @ReportEndDate				date;
declare @CompanyID					int;

begin 

-- Run on the 1st of next month, so @ReportBeginDate is the previous month
set @ReportBeginDate	= dateadd(m, -1, GetDate())
-- Run on the 1st of next month, so @ReportEndDate is the previous day
set @ReportEndDate      = dateadd(d, -1, GetDate())
set @CompanyID			= 7 --Hardcode Stillwater


-- Just in case...
truncate table [Sandbox].[dbo].tblQuotes

insert into [Sandbox].[dbo].tblQuotes
select a.QuoteID,
	   a.QuoteGuid,
       a.OriginalQuoteGuid,
	   a.EndorsementEffective,
	   a.EffectiveDate,
	   a.QuoteStatusID,
	   a.ExpirationDate,
	   a.DateBound,
	   a.InsuredPolicyName,
	   a.PolicyNumber,
	   a.TransactionTypeID,
	   a.PolicyTypeID,
	   a.DisplayStatus,
	   a.NetRate_QuoteID,
	   a.LineGUID,
	   a.CompanyLineGUID,
	   a.RiskDescription
from [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].tblQuotes a
where a.DateBound is not NULL
group by a.QuoteID,
	   a.QuoteGuid,
       a.OriginalQuoteGuid,
	   a.EndorsementEffective,
	   a.EffectiveDate,
	   a.QuoteStatusID,
	   a.ExpirationDate,
	   a.DateBound,
	   a.InsuredPolicyName,
	   a.PolicyNumber,
	   a.TransactionTypeID,
	   a.PolicyTypeID,
	   a.DisplayStatus,
	   a.NetRate_QuoteID,
	   a.LineGUID,
	   a.CompanyLineGUID,
	   a.RiskDescription


create table #Auto_Subline_Premium_by_QuoteID (QuoteID int, PolicyNumber varchar(20), ALPrem money, APDPrem money, AutoBTM money)
create nonclustered index idx_QuoteID on #Auto_Subline_Premium_by_QuoteID (QuoteID)

insert into #Auto_Subline_Premium_by_QuoteID
select a.*
from [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[ReportReference].[v_Auto_Subline_Premium_by_QuoteID] a,
	 [Sandbox].[dbo].tblQuotes b
where a.QuoteID = b.QuoteID



create table #AssumedEP     (QuoteID						int, 
							 InsuredPolicyName				varchar(100), 
							 PolicyNumber					varchar(20), 
							 EffectiveDate					datetime,
							 TransEffDate					date,
							 PolicyType						varchar(10),
							 TransactionType				varchar(25),
							 DisplayStatus					varchar(100),
							 LineName						varchar(100),
							 GWP							money,
							 EqBrkdwn						money,
							 TotGWP							money,
							 AssumedPremium					money,
							 CurrentAssumedPremium			money,
--							 PriorAssumedPremium			money,
							 PeriodEarnedPremium			money,
							 TreatySharePct					decimal(6, 5),
							 PeriodAssumedEarnedPremium		money,
							 ITDEarnedPremium				money,
							 ITDAssumedEarnedPremium		money/*,
							 PriorITDAssumedEarnedPremium	money*/,
							 CurrentAssumedCommission		money,
							 CurrentCededCommission         money)

create table #Results ([Company Code]		char(2),
                       [GL Effective Date]  char(8),
                       [Journal Code]		varchar(10),
					   [Journal Desc]		varchar(100),
					   [GL Account]			varchar(50),
					   [Amount]				money,
					   [Line Description]	varchar(100),
					   [XREF1]				varchar(100),
					   [XREF2]				varchar(100))

insert into #AssumedEP
select ccc.QuoteID,
       ccc.InsuredPolicyName,
       ccc.PolicyNumber,
	   ccc.EffectiveDate,
	   ccc.TransEffDate,
	   ccc.PolicyType,
	   ccc.TransactionType,
	   ccc.DisplayStatus,
	   ccc.LineName,
	   ccc.GWP,
	   ccc.EqBrkdwn,
	   ccc.TotGWP,
	   ccc.AssumedPremium,
	   IsNull(case when ccc.TransEffDate >= @ReportBeginDate then ccc.AssumedPremium end, 0) CurrentAssumedPremium,
--	   IsNull(case when ccc.TransEffDate < @ReportBeginDate then ccc.AssumedPremium end, 0) PriorAssumedPremium,
	   convert(money, IsNull([Sandbox].[ReportReference].[CalcEarnedPremium](ccc.QuoteID, @ReportBeginDate, @ReportEndDate, @ReportEndDate, ccc.TotGWP), 0)) As PeriodEarnedPremium,
	   ccc.TreatySharePct,
	   convert(money, round(IsNull([Sandbox].[ReportReference].[CalcEarnedPremium](ccc.QuoteID, @ReportBeginDate, @ReportEndDate, @ReportEndDate, ccc.TotGWP), 0) 
	           * ccc.TreatySharePct, 2)) PeriodAssumedEarnedPremium,
	   convert(money, IsNull([Sandbox].[ReportReference].[CalcEarnedPremium](ccc.QuoteID, '1/1/2017', @ReportEndDate, @ReportEndDate, ccc.TotGWP), 0)) As ITDEarnedPremium,
	   convert(money, round(IsNull([Sandbox].[ReportReference].[CalcEarnedPremium](ccc.QuoteID, '1/1/2017', @ReportEndDate, @ReportEndDate, ccc.TotGWP), 0) 
	           * ccc.TreatySharePct, 2)) ITDAssumedEarnedPremium/*,
	   IsNull(case when ccc.TransEffDate < @ReportBeginDate then
	   convert(money, round(IsNull([Sandbox].[ReportReference].[CalcEarnedPremium](ccc.QuoteID, '1/1/2017', dateadd(d, -1, @ReportBeginDate), dateadd(d, -1, @ReportBeginDate), ccc.TotGWP), 0) 
	           * ccc.TreatySharePct, 2)) end, 0) PriorITDAssumedEarnedPremium */,
	   IsNull(case when ccc.TransEffDate >= @ReportBeginDate then ccc.AssumedCommission end, 0) CurrentAssumedCommission,
	   Round(convert(money, round(IsNull([Sandbox].[ReportReference].[CalcEarnedPremium](ccc.QuoteID, @ReportBeginDate, @ReportEndDate, @ReportEndDate, ccc.TotGWP), 0) 
	           * ccc.TreatySharePct, 2)) *
	             ccc.AssumedCommissionPct, 2)  As CurrentCededCommission


from (
select aaa.QuoteID,
       aaa.InsuredPolicyName,
       aaa.PolicyNumber,
	   aaa.EffectiveDate,
	   aaa.TransEffDate,
	   aaa.PolicyType,
	   aaa.TransactionType,
	   aaa.DisplayStatus,
	   aaa.LineName,
       sum(GWP) GWP,
	   IsNull((SELECT		sum(CASE WHEN iq.TypeOfBusiness NOT IN ('Endorsement', 'Cancellation', 'Reinstate', 'Audit')
												 THEN iqlc.Premium + ISNULL(iqlc.TerrorismPremium, 0)
												 ELSE iqlc.Endorse + ISNULL(iqlc.TerrorismEndorse, 0)
											     END)
							FROM		[MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].NetRate_Quote_Insur_Quote iq
							INNER JOIN	[MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].NetRate_Quote_Insur_Quote_Locat iql ON iql.QuoteID = iql.QuoteID
							INNER JOIN	[MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].NetRate_Quote_Insur_Quote_Locat_Compa iqlc ON iql.LocationID = iqlc.LocationID
							WHERE aaa.NetRate_QuoteID = iq.QuoteID
							    AND aaa.LineName = 'Commercial Property'
								AND iqlc.OtherDesc in ( 'ISO Equipment Breakdown',
														'ISO Equipment Breakdown Terrorism',
														'Equipment Breakdown')), 0) EqBrkdwn,
       sum(GWP)  -
	   IsNull((SELECT		sum(CASE WHEN iq.TypeOfBusiness NOT IN ('Endorsement', 'Cancellation', 'Reinstate', 'Audit')
												 THEN iqlc.Premium + ISNULL(iqlc.TerrorismPremium, 0)
												 ELSE iqlc.Endorse + ISNULL(iqlc.TerrorismEndorse, 0)
											     END)
							FROM		[MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].NetRate_Quote_Insur_Quote iq
							INNER JOIN	[MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].NetRate_Quote_Insur_Quote_Locat iql ON iq.QuoteID = iql.QuoteID
							INNER JOIN	[MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].NetRate_Quote_Insur_Quote_Locat_Compa iqlc ON iql.LocationID = iqlc.LocationID
							WHERE aaa.NetRate_QuoteID = iq.QuoteID
							    AND aaa.LineName = 'Commercial Property'
								AND iqlc.OtherDesc in ( 'ISO Equipment Breakdown',
														'ISO Equipment Breakdown Terrorism',
														'Equipment Breakdown')), 0) TotGWP,
      aaa.TreatySharePct,
	   convert(money, round((sum(GWP)  -
	   IsNull((SELECT		sum(CASE WHEN iq.TypeOfBusiness NOT IN ('Endorsement', 'Cancellation', 'Reinstate', 'Audit')
												 THEN iqlc.Premium + ISNULL(iqlc.TerrorismPremium, 0)
												 ELSE iqlc.Endorse + ISNULL(iqlc.TerrorismEndorse, 0)
											     END)
							FROM		[MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].NetRate_Quote_Insur_Quote iq
							INNER JOIN	[MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].NetRate_Quote_Insur_Quote_Locat iql ON iq.QuoteID = iql.QuoteID
							INNER JOIN	[MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].NetRate_Quote_Insur_Quote_Locat_Compa iqlc ON iql.LocationID = iqlc.LocationID
							WHERE aaa.NetRate_QuoteID = iq.QuoteID
							    AND aaa.LineName = 'Commercial Property'
								AND iqlc.OtherDesc in ( 'ISO Equipment Breakdown',
														'ISO Equipment Breakdown Terrorism',
														'Equipment Breakdown')), 0)) *
       aaa.TreatySharePct, 2)) AssumedPremium,
	   aaa.AssumedCommissionPct,
	   convert(money, round(
	   convert(money, round((sum(GWP)  -
	   IsNull((SELECT		sum(CASE WHEN iq.TypeOfBusiness NOT IN ('Endorsement', 'Cancellation', 'Reinstate', 'Audit')
												 THEN iqlc.Premium + ISNULL(iqlc.TerrorismPremium, 0)
												 ELSE iqlc.Endorse + ISNULL(iqlc.TerrorismEndorse, 0)
											     END)
							FROM		[MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].NetRate_Quote_Insur_Quote iq
							INNER JOIN	[MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].NetRate_Quote_Insur_Quote_Locat iql ON iq.QuoteID = iql.QuoteID
							INNER JOIN	[MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].NetRate_Quote_Insur_Quote_Locat_Compa iqlc ON iql.LocationID = iqlc.LocationID
							WHERE aaa.NetRate_QuoteID = iq.QuoteID
								AND aaa.LineName = 'Commercial Property'
								AND iqlc.OtherDesc in ('ISO Equipment Breakdown',
																						'ISO Equipment Breakdown Terrorism',
																						'Equipment Breakdown')), 0)) *
       aaa.TreatySharePct, 2)) * aaa.AssumedCommissionPct, 2)) AssumedCommission


from (
select a.QuoteID,
       a.NetRate_QuoteID,
       a.InsuredPolicyName,
       a.PolicyNumber,
	   a.EffectiveDate,
	   convert(date, case when a.DateBound < a.EffectiveDate then a.EffectiveDate else a.DateBound end) TransEffDate,
	   d.Description PolicyType,
	   IsNull(e.TransactionType, case when d.Description = 'New' then 'New Business' else d.Description end) TransactionType,
	   a.DisplayStatus,
	   c.LineName,
	   crtls.TreatySharePct,
	   crtls.AssumedCommissionPct,
	          ISNULL((SELECT     SUM(INVD.AmtBilled)
							FROM       [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].tblFin_InvoiceDetails INVD
							INNER JOIN [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].tblFin_PolicyCharges PC ON INVD.ChargeCode = PC.ChargeCode
							WHERE      INVD.InvoiceNum = b.InvoiceNum
							  AND      INVD.CompanyLineGuid = cl.CompanyLineGuid
							AND        PC.ChargeType = 'P'
							), 0) GWP
from [Sandbox].[dbo].tblQuotes a
     left join [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].[lstTransactionTypes] e
	  on a.TransactionTypeID = e.ID
	 left join [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].[lstPolicyTypes] d
	  on a.PolicyTypeID = d.PolicyTypeID,
	 [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].[tblFin_Invoices] b,
     [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].[tblFin_InvoiceDetails] id,
     [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].[tblCompanyLines] cl,
	 [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].[tblCompanyLocations] cloc,
	 [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].[tblCompanies] co,
	 [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].[lstLines] c,	 
	 [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[ReportReference].[CompanyReinsTreaties] crt,
	 [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[ReportReference].[CompanyReinsTreatyLineShare] crtls
where convert(date, case when a.DateBound < a.EffectiveDate then a.EffectiveDate else a.DateBound end) < dateadd(d, 1, @ReportEndDate)
  and a.QuoteID = b.QuoteID
  and b.Failed = 0
  and b.InvoiceNum = id.InvoiceNum
  and id.CompanyLineGuid = cl.CompanyLineGUID
  and cl.CompanyLocationGUID = cloc.CompanyLocationGUID
  and cloc.CompanyGUID = co.CompanyGUID
  and co.CompanyName <> 'Placeholder Company'
  and co.CompanyID = @CompanyID
  and cl.LineGUID = c.LineGUID
  and co.CompanyID = crt.CompanyID
  and crt.CompanyReinsTreatyID = crtls.CompanyReinsTreatyID
  and c.LineID = crtls.LineID 
  and convert(date, a.EffectiveDate) between crt.TreatyBeginDate and crt.TreatyEndDate
  and c.LineName <> 'Commercial Auto'
--  and a.QuoteID = 6737
group by a.QuoteID,
       a.NetRate_QuoteID,
       a.InsuredPolicyName,
       a.PolicyNumber,
	   a.EffectiveDate,
	   convert(date, case when a.DateBound < a.EffectiveDate then a.EffectiveDate else a.DateBound end),
	   d.Description,
	   IsNull(e.TransactionType, case when d.Description = 'New' then 'New Business' else d.Description end),
	   a.DisplayStatus,
	   c.LineName,
	   crtls.TreatySharePct,
	   crtls.AssumedCommissionPct,
	   b.InvoiceNum,
	   cl.CompanyLineGuid

union all

select zzz.QuoteID,
       zzz.NetRate_QuoteID,
       zzz.InsuredPolicyName,
       zzz.PolicyNumber,
	   zzz.EffectiveDate,
	   zzz.TransEffDate,
	   zzz.PolicyType,
	   zzz.TransactionType,
	   zzz.DisplayStatus,
	   zzz.LineName,
	   zzz.TreatySharePct,
	   zzz.AssumedCommissionPct,
       max(zzz.GWP) GWP
from (
select a.QuoteID,
       a.NetRate_QuoteID,
       a.InsuredPolicyName,
       a.PolicyNumber,
	   a.EffectiveDate,
	   convert(date, case when a.DateBound < a.EffectiveDate then a.EffectiveDate else a.DateBound end) TransEffDate,
	   d.Description PolicyType,
	   IsNull(e.TransactionType, case when d.Description = 'New' then 'New Business' else d.Description end) TransactionType,
	   a.DisplayStatus,
	   'Commercial Auto Liability' LineName,
	   crtls.TreatySharePct,
	   crtls.AssumedCommissionPct,
--	   max(b.AnnualPremium) GWP
       convert(money, case when IsNull(max(asp.AutoBTM), 0) = 0
					  then max(asp.ALPrem)
					  else max(asp.AlPrem) + (max(asp.AlPrem) / (max(asp.AlPrem) + max(asp.APDPrem)) * max(asp.AutoBTM)) end) GWP
from [Sandbox].[dbo].tblQuotes a
     left join [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].[lstTransactionTypes] e
	  on a.TransactionTypeID = e.ID
	 left join [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].[lstPolicyTypes] d
	  on a.PolicyTypeID = d.PolicyTypeID,
	 [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].[tblFin_Invoices] b,
     [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].[tblFin_InvoiceDetails] id,
     [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].[tblCompanyLines] cl,
	 [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].[tblCompanyLocations] cloc,
	 [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].[tblCompanies] co,
	 [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].[lstLines] c,	 
	 [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[ReportReference].[CompanyReinsTreaties] crt,
	 [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[ReportReference].[CompanyReinsTreatyLineShare] crtls,
	 #Auto_Subline_Premium_by_QuoteID asp
where convert(date, case when a.DateBound < a.EffectiveDate then a.EffectiveDate else a.DateBound end) < dateadd(d, 1, @ReportEndDate)
  and a.QuoteID = b.QuoteID
  and b.Failed = 0
  and b.InvoiceNum = id.InvoiceNum
  and id.CompanyLineGuid = cl.CompanyLineGUID
  and cl.CompanyLocationGUID = cloc.CompanyLocationGUID
  and cloc.CompanyGUID = co.CompanyGUID
  and co.CompanyName <> 'Placeholder Company'
  and co.CompanyID = @CompanyID
  and cl.LineGUID = c.LineGUID
  and co.CompanyID = crt.CompanyID
  and crt.CompanyReinsTreatyID = crtls.CompanyReinsTreatyID
  and c.LineID = crtls.LineID 
  and convert(date, a.EffectiveDate) between crt.TreatyBeginDate and crt.TreatyEndDate
  and c.LineName = 'Commercial Auto'
  and a.QuoteID = asp.QuoteID
--  and a.QuoteID = 6737
group by a.QuoteID,
       a.NetRate_QuoteID,
       a.InsuredPolicyName,
       a.PolicyNumber,
	   a.EffectiveDate,
	   convert(date, case when a.DateBound < a.EffectiveDate then a.EffectiveDate else a.DateBound end),
	   d.Description,
	   IsNull(e.TransactionType, case when d.Description = 'New' then 'New Business' else d.Description end),
	   a.DisplayStatus,
	   c.LineName,
	   crtls.TreatySharePct,
	   crtls.AssumedCommissionPct,
	   b.InvoiceNum,
	   cl.CompanyLineGuid
having convert(money, case when IsNull(max(asp.AutoBTM), 0) = 0
					  then max(asp.ALPrem)
					  else max(asp.AlPrem) + (max(asp.AlPrem) / (max(asp.AlPrem) + max(asp.APDPrem)) * max(asp.AutoBTM)) end) <> 0




union all


select a.QuoteID,
       a.NetRate_QuoteID,
       a.InsuredPolicyName,
       a.PolicyNumber,
	   a.EffectiveDate,
	   convert(date, case when a.DateBound < a.EffectiveDate then a.EffectiveDate else a.DateBound end) TransEffDate,
	   d.Description PolicyType,
	   IsNull(e.TransactionType, case when d.Description = 'New' then 'New Business' else d.Description end) TransactionType,
	   a.DisplayStatus,
	   'Commercial Auto PD' LineName,
	   crtls.TreatySharePct,
	   crtls.AssumedCommissionPct,
--	   max(b.AnnualPremium) GWP
	   convert(money, case when IsNull(max(asp.AutoBTM), 0) = 0
	                  then max(asp.APDPrem) 
			          else max(asp.APDPrem) + (max(asp.APDPrem) / (max(asp.AlPrem) + max(asp.APDPrem)) * max(asp.AutoBTM)) end) GWP
from [Sandbox].[dbo].tblQuotes a
     left join [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].[lstTransactionTypes] e
	  on a.TransactionTypeID = e.ID
	 left join [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].[lstPolicyTypes] d
	  on a.PolicyTypeID = d.PolicyTypeID,
	 [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].[tblFin_Invoices] b,
     [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].[tblFin_InvoiceDetails] id,
     [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].[tblCompanyLines] cl,
	 [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].[tblCompanyLocations] cloc,
	 [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].[tblCompanies] co,
	 [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].[lstLines] c,	 
	 [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[ReportReference].[CompanyReinsTreaties] crt,
	 [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[ReportReference].[CompanyReinsTreatyLineShare] crtls,
	 #Auto_Subline_Premium_by_QuoteID asp
where convert(date, case when a.DateBound < a.EffectiveDate then a.EffectiveDate else a.DateBound end) < dateadd(d, 1, @ReportEndDate)
  and a.QuoteID = b.QuoteID
  and b.Failed = 0
  and b.InvoiceNum = id.InvoiceNum
  and id.CompanyLineGuid = cl.CompanyLineGUID
  and cl.CompanyLocationGUID = cloc.CompanyLocationGUID
  and cloc.CompanyGUID = co.CompanyGUID
  and co.CompanyName <> 'Placeholder Company'
  and co.CompanyID = @CompanyID
  and cl.LineGUID = c.LineGUID
  and co.CompanyID = crt.CompanyID
  and crt.CompanyReinsTreatyID = crtls.CompanyReinsTreatyID
  and c.LineID = crtls.LineID 
  and convert(date, a.EffectiveDate) between crt.TreatyBeginDate and crt.TreatyEndDate
  and c.LineName = 'Commercial Auto'
  and a.QuoteID = asp.QuoteID
--  and a.QuoteID = 6737
group by a.QuoteID,
       a.NetRate_QuoteID,
       a.InsuredPolicyName,
       a.PolicyNumber,
	   a.EffectiveDate,
	   convert(date, case when a.DateBound < a.EffectiveDate then a.EffectiveDate else a.DateBound end),
	   d.Description,
	   IsNull(e.TransactionType, case when d.Description = 'New' then 'New Business' else d.Description end),
	   a.DisplayStatus,
	   c.LineName,
	   crtls.TreatySharePct,
	   crtls.AssumedCommissionPct,
	   b.InvoiceNum,
	   cl.CompanyLineGuid
having convert(money, case when IsNull(max(asp.AutoBTM), 0) = 0
	                  then max(asp.APDPrem) 
			          else max(asp.APDPrem) + (max(asp.APDPrem) / (max(asp.AlPrem) + max(asp.APDPrem)) * max(asp.AutoBTM)) end) <> 0
) zzz
group by zzz.QuoteID,
       zzz.NetRate_QuoteID,
       zzz.InsuredPolicyName,
       zzz.PolicyNumber,
	   zzz.EffectiveDate,
	   zzz.TransEffDate,
	   zzz.PolicyType,
	   zzz.TransactionType,
	   zzz.DisplayStatus,
	   zzz.LineName,
	   zzz.TreatySharePct,
	   zzz.AssumedCommissionPct


) aaa
--where aaa.LineName = 'Commercial Inland Marine'
group by aaa.QuoteID,
       aaa.NetRate_QuoteID,
       aaa.InsuredPolicyName,
       aaa.PolicyNumber,
	   aaa.EffectiveDate,
	   aaa.TransEffDate,
	   aaa.PolicyType,
	   aaa.TransactionType,
	   aaa.DisplayStatus,
	   aaa.LineName,
	   aaa.TreatySharePct,
	   aaa.AssumedCommissionPct
) ccc
/*
where --convert(money, IsNull([MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[ReportReference].[CalcEarnedPremium](ccc.QuoteID, @ReportBeginDate, @ReportEndDate, @ReportEndDate, ccc.TotGWP), 0)) <> 0
      convert(money, IsNull([MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[ReportReference].[CalcEarnedPremium](ccc.QuoteID, '1/1/2017', @ReportEndDate, @ReportEndDate, ccc.TotGWP), 0))  <> 0 */


-- Assumed Earned Premium  JEs

/*

select *
from #AssumedEP

*/

-- Current Assumed WP - Current Assumed EP


insert into #Results
select '10' [Company Code],
 --       convert(varchar(8), aaaa.TransEffDate, 112) [GL Effective Date],
        convert(varchar(8), @ReportEndDate, 112) [GL Effective Date],
		'IMS' [Journal Code],
		'PREM ASMD FROM AFFIL UPR CHG' /*+ 
		case when aaaa.LineName = 'Commercial Property'
		     then 'COML PROPERTY'
			 when aaaa.LineName = 'Commercial General Liability'
		     then 'COML GENERAL LIABILITY'
			 when aaaa.LineName = 'Commercial Inland Marine'
		     then 'COML INLAND MARINE'
			 when aaaa.LineName = 'Commercial Crime'
		     then 'COML CRIME'
			 when aaaa.LineName = 'Commercial Auto Liability'
		     then 'COMMERCIAL AUTO LIABILITY'
			 when aaaa.LineName = 'Commercial Auto PD'
		     then 'COMMERCIAL PHYSICAL DAMAGE'
			 when aaaa.LineName = 'Umbrella'
		     then 'UMBRELLA' end */ "Journal Desc",
       '10' +
	   '4200122000' + 
       '00' + -- Cost Center
	   '000' + /*
       case when aaaa.LineName = 'Commercial Property'
		     then '100'
			 when aaaa.LineName = 'Commercial General Liability'
		     then '200'
			 when aaaa.LineName = 'Commercial Inland Marine'
		     then '300'
			 when aaaa.LineName = 'Commercial Crime'
		     then '400'
			 when aaaa.LineName = 'Commercial Auto Liability'
		     then '501'
			 when aaaa.LineName = 'Commercial Auto PD'
		     then '502'
			 when aaaa.LineName = 'Umbrella'
		     then '600' end  + */
--  MH - St Code 32 for NY
        '32' + 
		'00' +
--		IsNull(bbb.Xtra1, '00')
--  MH - Program Code 10 for NYCON
        '10' [GL Account],	
		sum(aaaa.CurrentAssumedPremium) - sum(aaaa.PeriodAssumedEarnedPremium)
		Amount,
	   '' [Line Description],
	   '' XREF1,
	   '' XREF2
from #AssumedEP aaaa /*
group by --convert(varchar(8), aaaa.TransEffDate, 112),
       'PREM ASMD FROM AFFIL UPR CHG' /*+ 
		case when aaaa.LineName = 'Commercial Property'
		     then 'COML PROPERTY'
			 when aaaa.LineName = 'Commercial General Liability'
		     then 'COML GENERAL LIABILITY'
			 when aaaa.LineName = 'Commercial Inland Marine'
		     then 'COML INLAND MARINE'
			 when aaaa.LineName = 'Commercial Crime'
		     then 'COML CRIME'
			 when aaaa.LineName = 'Commercial Auto Liability'
		     then 'COMMERCIAL AUTO LIABILITY'
			 when aaaa.LineName = 'Commercial Auto PD'
		     then 'COMMERCIAL PHYSICAL DAMAGE'
			 when aaaa.LineName = 'Umbrella'
		     then 'UMBRELLA' end */,		        
       '10'
	   + '4200122000' + 
       '00' + -- Cost Center
	   '000' + /*
       case when aaaa.LineName = 'Commercial Property'
		     then '100'
			 when aaaa.LineName = 'Commercial General Liability'
		     then '200'
			 when aaaa.LineName = 'Commercial Inland Marine'
		     then '300'
			 when aaaa.LineName = 'Commercial Crime'
		     then '400'
			 when aaaa.LineName = 'Commercial Auto Liability'
		     then '501'
			 when aaaa.LineName = 'Commercial Auto PD'
		     then '502'
			 when aaaa.LineName = 'Umbrella'
		     then '600' end  + */
--  MH - St Code 32 for NY
        '32' + 
		'00' +
--		IsNull(bbb.Xtra1, '00')
--  MH - Program Code 10 for NYCON
        '10'
*/
--  Balancing JEs

insert into #Results
select '10' [Company Code],
 --       convert(varchar(8), aaaa.TransEffDate, 112) [GL Effective Date],
        convert(varchar(8), @ReportEndDate, 112) [GL Effective Date],
		'IMS' [Journal Code],
		'PREMIUM ASSUMED UPR < 1 YR' /*+ 
		case when aaaa.LineName = 'Commercial Property'
		     then 'COML PROPERTY'
			 when aaaa.LineName = 'Commercial General Liability'
		     then 'COML GENERAL LIABILITY'
			 when aaaa.LineName = 'Commercial Inland Marine'
		     then 'COML INLAND MARINE'
			 when aaaa.LineName = 'Commercial Crime'
		     then 'COML CRIME'
			 when aaaa.LineName = 'Commercial Auto Liability'
		     then 'COMMERCIAL AUTO LIABILITY'
			 when aaaa.LineName = 'Commercial Auto PD'
		     then 'COMMERCIAL PHYSICAL DAMAGE'
			 when aaaa.LineName = 'Umbrella'
		     then 'UMBRELLA' end */"Journal Desc",
       '10' +
	   '2500902010' + 
       '00' + -- Cost Center
	   '000' + /*
       case when aaaa.LineName = 'Commercial Property'
		     then '100'
			 when aaaa.LineName = 'Commercial General Liability'
		     then '200'
			 when aaaa.LineName = 'Commercial Inland Marine'
		     then '300'
			 when aaaa.LineName = 'Commercial Crime'
		     then '400'
			 when aaaa.LineName = 'Commercial Auto Liability'
		     then '501'
			 when aaaa.LineName = 'Commercial Auto PD'
		     then '502'
			 when aaaa.LineName = 'Umbrella'
		     then '600' end  + */
--  MH - St Code 32 for NY
        '32' + 
		'00' +
--		IsNull(bbb.Xtra1, '00')
--  MH - Program Code 10 for NYCON
        '10' [GL Account],
		(sum(aaaa.CurrentAssumedPremium) - sum(aaaa.PeriodAssumedEarnedPremium)) * -1 Amount,
	   '' [Line Description],
	   '' XREF1,
	   '' XREF2
from #AssumedEP aaaa /*
group by --convert(varchar(8), aaaa.TransEffDate, 112),
       'PREMIUM ASSUMED UPR < 1 YR' /*+ 
		case when aaaa.LineName = 'Commercial Property'
		     then 'COML PROPERTY'
			 when aaaa.LineName = 'Commercial General Liability'
		     then 'COML GENERAL LIABILITY'
			 when aaaa.LineName = 'Commercial Inland Marine'
		     then 'COML INLAND MARINE'
			 when aaaa.LineName = 'Commercial Crime'
		     then 'COML CRIME'
			 when aaaa.LineName = 'Commercial Auto Liability'
		     then 'COMMERCIAL AUTO LIABILITY'
			 when aaaa.LineName = 'Commercial Auto PD'
		     then 'COMMERCIAL PHYSICAL DAMAGE'
			 when aaaa.LineName = 'Umbrella'
		     then 'UMBRELLA' end*/,		        
       '10' +
	   '2500902010' + 
       '00' + -- Cost Center
	   '000' + /*
       case when aaaa.LineName = 'Commercial Property'
		     then '100'
			 when aaaa.LineName = 'Commercial General Liability'
		     then '200'
			 when aaaa.LineName = 'Commercial Inland Marine'
		     then '300'
			 when aaaa.LineName = 'Commercial Crime'
		     then '400'
			 when aaaa.LineName = 'Commercial Auto Liability'
		     then '501'
			 when aaaa.LineName = 'Commercial Auto PD'
		     then '502'
			 when aaaa.LineName = 'Umbrella'
		     then '600' end  + */
--  MH - St Code 32 for NY
        '32' + 
		'00' +
--		IsNull(bbb.Xtra1, '00')
--  MH - Program Code 10 for NYCON
        '10' */


-- Current Assumed WP



insert into #Results
select '10' [Company Code],
 --       convert(varchar(8), aaaa.TransEffDate, 112) [GL Effective Date],
        convert(varchar(8), @ReportEndDate, 112) [GL Effective Date],
		'IMS' [Journal Code],
		'AGENTS BALANCES PICC - SPAC' /*+ 
		case when aaaa.LineName = 'Commercial Property'
		     then 'COML PROPERTY'
			 when aaaa.LineName = 'Commercial General Liability'
		     then 'COML GENERAL LIABILITY'
			 when aaaa.LineName = 'Commercial Inland Marine'
		     then 'COML INLAND MARINE'
			 when aaaa.LineName = 'Commercial Crime'
		     then 'COML CRIME'
			 when aaaa.LineName = 'Commercial Auto Liability'
		     then 'COMMERCIAL AUTO LIABILITY'
			 when aaaa.LineName = 'Commercial Auto PD'
		     then 'COMMERCIAL PHYSICAL DAMAGE'
			 when aaaa.LineName = 'Umbrella'
		     then 'UMBRELLA' end */ "Journal Desc",
       '10' +
	   '1401510002' + 
       '00' + -- Cost Center
	   '000' + /*
       case when aaaa.LineName = 'Commercial Property'
		     then '100'
			 when aaaa.LineName = 'Commercial General Liability'
		     then '200'
			 when aaaa.LineName = 'Commercial Inland Marine'
		     then '300'
			 when aaaa.LineName = 'Commercial Crime'
		     then '400'
			 when aaaa.LineName = 'Commercial Auto Liability'
		     then '501'
			 when aaaa.LineName = 'Commercial Auto PD'
		     then '502'
			 when aaaa.LineName = 'Umbrella'
		     then '600' end  + */
--  MH - St Code 32 for NY
        '32' + 
		'00' +
--		IsNull(bbb.Xtra1, '00')
--  MH - Program Code 10 for NYCON
        '10' [GL Account],
		sum(aaaa.CurrentAssumedPremium)		
		Amount,
	   '' [Line Description],
	   '' XREF1,
	   '' XREF2
from #AssumedEP aaaa /*
group by --convert(varchar(8), aaaa.TransEffDate, 112),
       'AGENTS BALANCES PICC - SPAC' /*+ 
		case when aaaa.LineName = 'Commercial Property'
		     then 'COML PROPERTY'
			 when aaaa.LineName = 'Commercial General Liability'
		     then 'COML GENERAL LIABILITY'
			 when aaaa.LineName = 'Commercial Inland Marine'
		     then 'COML INLAND MARINE'
			 when aaaa.LineName = 'Commercial Crime'
		     then 'COML CRIME'
			 when aaaa.LineName = 'Commercial Auto Liability'
		     then 'COMMERCIAL AUTO LIABILITY'
			 when aaaa.LineName = 'Commercial Auto PD'
		     then 'COMMERCIAL PHYSICAL DAMAGE'
			 when aaaa.LineName = 'Umbrella'
		     then 'UMBRELLA' end */,		        
       '10'
	   + '1401510002' + 
       '00' + -- Cost Center
	   '000' + /*
       case when aaaa.LineName = 'Commercial Property'
		     then '100'
			 when aaaa.LineName = 'Commercial General Liability'
		     then '200'
			 when aaaa.LineName = 'Commercial Inland Marine'
		     then '300'
			 when aaaa.LineName = 'Commercial Crime'
		     then '400'
			 when aaaa.LineName = 'Commercial Auto Liability'
		     then '501'
			 when aaaa.LineName = 'Commercial Auto PD'
		     then '502'
			 when aaaa.LineName = 'Umbrella'
		     then '600' end  + */
--  MH - St Code 32 for NY
        '32' + 
		'00' +
--		IsNull(bbb.Xtra1, '00')
--  MH - Program Code 10 for NYCON
        '10'
*/

--  Balancing JEs

insert into #Results
select '10' [Company Code],
 --       convert(varchar(8), aaaa.TransEffDate, 112) [GL Effective Date],
        convert(varchar(8), @ReportEndDate, 112) [GL Effective Date],
		'IMS' [Journal Code],
		'PREMIUM ASSUMED FROM AFFILIATE' /*+ 
		case when aaaa.LineName = 'Commercial Property'
		     then 'COML PROPERTY'
			 when aaaa.LineName = 'Commercial General Liability'
		     then 'COML GENERAL LIABILITY'
			 when aaaa.LineName = 'Commercial Inland Marine'
		     then 'COML INLAND MARINE'
			 when aaaa.LineName = 'Commercial Crime'
		     then 'COML CRIME'
			 when aaaa.LineName = 'Commercial Auto Liability'
		     then 'COMMERCIAL AUTO LIABILITY'
			 when aaaa.LineName = 'Commercial Auto PD'
		     then 'COMMERCIAL PHYSICAL DAMAGE'
			 when aaaa.LineName = 'Umbrella'
		     then 'UMBRELLA' end */"Journal Desc",
       '10' +
	   '4000122000' + 
       '00' + -- Cost Center
	   '000' + /*
       case when aaaa.LineName = 'Commercial Property'
		     then '100'
			 when aaaa.LineName = 'Commercial General Liability'
		     then '200'
			 when aaaa.LineName = 'Commercial Inland Marine'
		     then '300'
			 when aaaa.LineName = 'Commercial Crime'
		     then '400'
			 when aaaa.LineName = 'Commercial Auto Liability'
		     then '501'
			 when aaaa.LineName = 'Commercial Auto PD'
		     then '502'
			 when aaaa.LineName = 'Umbrella'
		     then '600' end  + */
--  MH - St Code 32 for NY
        '32' + 
		'00' +
--		IsNull(bbb.Xtra1, '00')
--  MH - Program Code 10 for NYCON
        '10' [GL Account],
	     sum(aaaa.CurrentAssumedPremium) * -1 Amount,
	   '' [Line Description],
	   '' XREF1,
	   '' XREF2
from #AssumedEP aaaa /*
group by --convert(varchar(8), aaaa.TransEffDate, 112),
       'PREMIUM ASSUMED FROM AFFILIATE' /*+ 
		case when aaaa.LineName = 'Commercial Property'
		     then 'COML PROPERTY'
			 when aaaa.LineName = 'Commercial General Liability'
		     then 'COML GENERAL LIABILITY'
			 when aaaa.LineName = 'Commercial Inland Marine'
		     then 'COML INLAND MARINE'
			 when aaaa.LineName = 'Commercial Crime'
		     then 'COML CRIME'
			 when aaaa.LineName = 'Commercial Auto Liability'
		     then 'COMMERCIAL AUTO LIABILITY'
			 when aaaa.LineName = 'Commercial Auto PD'
		     then 'COMMERCIAL PHYSICAL DAMAGE'
			 when aaaa.LineName = 'Umbrella'
		     then 'UMBRELLA' end*/,		        
       '10' +
	   '4000122000' + 
       '00' + -- Cost Center
	   '000' + /*
       case when aaaa.LineName = 'Commercial Property'
		     then '100'
			 when aaaa.LineName = 'Commercial General Liability'
		     then '200'
			 when aaaa.LineName = 'Commercial Inland Marine'
		     then '300'
			 when aaaa.LineName = 'Commercial Crime'
		     then '400'
			 when aaaa.LineName = 'Commercial Auto Liability'
		     then '501'
			 when aaaa.LineName = 'Commercial Auto PD'
		     then '502'
			 when aaaa.LineName = 'Umbrella'
		     then '600' end  + */
--  MH - St Code 32 for NY
        '32' + 
		'00' +
--		IsNull(bbb.Xtra1, '00')
--  MH - Program Code 10 for NYCON
        '10' */


-- Current Assumed Commission



insert into #Results
select '10' [Company Code],
 --       convert(varchar(8), aaaa.TransEffDate, 112) [GL Effective Date],
        convert(varchar(8), @ReportEndDate, 112) [GL Effective Date],
		'IMS' [Journal Code],
		'COMMISSION ASSUMED PAID' /*+ 
		case when aaaa.LineName = 'Commercial Property'
		     then 'COML PROPERTY'
			 when aaaa.LineName = 'Commercial General Liability'
		     then 'COML GENERAL LIABILITY'
			 when aaaa.LineName = 'Commercial Inland Marine'
		     then 'COML INLAND MARINE'
			 when aaaa.LineName = 'Commercial Crime'
		     then 'COML CRIME'
			 when aaaa.LineName = 'Commercial Auto Liability'
		     then 'COMMERCIAL AUTO LIABILITY'
			 when aaaa.LineName = 'Commercial Auto PD'
		     then 'COMMERCIAL PHYSICAL DAMAGE'
			 when aaaa.LineName = 'Umbrella'
		     then 'UMBRELLA' end */ "Journal Desc",
       '10' +
	   '6000222000' + 
       '00' + -- Cost Center
	   '000' + /*
       case when aaaa.LineName = 'Commercial Property'
		     then '100'
			 when aaaa.LineName = 'Commercial General Liability'
		     then '200'
			 when aaaa.LineName = 'Commercial Inland Marine'
		     then '300'
			 when aaaa.LineName = 'Commercial Crime'
		     then '400'
			 when aaaa.LineName = 'Commercial Auto Liability'
		     then '501'
			 when aaaa.LineName = 'Commercial Auto PD'
		     then '502'
			 when aaaa.LineName = 'Umbrella'
		     then '600' end  + */
--  MH - St Code 32 for NY
        '32' + 
		'00' +
--		IsNull(bbb.Xtra1, '00')
--  MH - Program Code 10 for NYCON
        '10' [GL Account],
--		sum(aaaa.CurrentAssumedCommission) Amount,
		sum(aaaa.CurrentCededCommission) Amount,
	   '' [Line Description],
	   '' XREF1,
	   '' XREF2
from #AssumedEP aaaa /*
group by --convert(varchar(8), aaaa.TransEffDate, 112),
       'COMMISSION ASSUMED PAID' /*+ 
		case when aaaa.LineName = 'Commercial Property'
		     then 'COML PROPERTY'
			 when aaaa.LineName = 'Commercial General Liability'
		     then 'COML GENERAL LIABILITY'
			 when aaaa.LineName = 'Commercial Inland Marine'
		     then 'COML INLAND MARINE'
			 when aaaa.LineName = 'Commercial Crime'
		     then 'COML CRIME'
			 when aaaa.LineName = 'Commercial Auto Liability'
		     then 'COMMERCIAL AUTO LIABILITY'
			 when aaaa.LineName = 'Commercial Auto PD'
		     then 'COMMERCIAL PHYSICAL DAMAGE'
			 when aaaa.LineName = 'Umbrella'
		     then 'UMBRELLA' end */,		        
       '10'
	   + '6000222000' + 
       '00' + -- Cost Center
	   '000' + /*
       case when aaaa.LineName = 'Commercial Property'
		     then '100'
			 when aaaa.LineName = 'Commercial General Liability'
		     then '200'
			 when aaaa.LineName = 'Commercial Inland Marine'
		     then '300'
			 when aaaa.LineName = 'Commercial Crime'
		     then '400'
			 when aaaa.LineName = 'Commercial Auto Liability'
		     then '501'
			 when aaaa.LineName = 'Commercial Auto PD'
		     then '502'
			 when aaaa.LineName = 'Umbrella'
		     then '600' end  + */
--  MH - St Code 32 for NY
        '32' + 
		'00' +
--		IsNull(bbb.Xtra1, '00')
--  MH - Program Code 10 for NYCON
        '10'
*/

--  Balancing JEs

insert into #Results
select '10' [Company Code],
 --       convert(varchar(8), aaaa.TransEffDate, 112) [GL Effective Date],
        convert(varchar(8), @ReportEndDate, 112) [GL Effective Date],
		'IMS' [Journal Code],
		'AGENTS BALANCES PICC - SPAC' /*+ 
		case when aaaa.LineName = 'Commercial Property'
		     then 'COML PROPERTY'
			 when aaaa.LineName = 'Commercial General Liability'
		     then 'COML GENERAL LIABILITY'
			 when aaaa.LineName = 'Commercial Inland Marine'
		     then 'COML INLAND MARINE'
			 when aaaa.LineName = 'Commercial Crime'
		     then 'COML CRIME'
			 when aaaa.LineName = 'Commercial Auto Liability'
		     then 'COMMERCIAL AUTO LIABILITY'
			 when aaaa.LineName = 'Commercial Auto PD'
		     then 'COMMERCIAL PHYSICAL DAMAGE'
			 when aaaa.LineName = 'Umbrella'
		     then 'UMBRELLA' end */"Journal Desc",
       '10' +
	   '1401510002' + 
       '00' + -- Cost Center
	   '000' + /*
       case when aaaa.LineName = 'Commercial Property'
		     then '100'
			 when aaaa.LineName = 'Commercial General Liability'
		     then '200'
			 when aaaa.LineName = 'Commercial Inland Marine'
		     then '300'
			 when aaaa.LineName = 'Commercial Crime'
		     then '400'
			 when aaaa.LineName = 'Commercial Auto Liability'
		     then '501'
			 when aaaa.LineName = 'Commercial Auto PD'
		     then '502'
			 when aaaa.LineName = 'Umbrella'
		     then '600' end  + */
--  MH - St Code 32 for NY
        '32' + 
		'00' +
--		IsNull(bbb.Xtra1, '00')
--  MH - Program Code 10 for NYCON
        '10' [GL Account],
--	     sum(aaaa.CurrentAssumedCommission) * -1 Amount,
		 sum(aaaa.CurrentCededCommission) * -1 Amount,
	   '' [Line Description],
	   '' XREF1,
	   '' XREF2
from #AssumedEP aaaa /*
group by --convert(varchar(8), aaaa.TransEffDate, 112),
       'AGENTS BALANCES PICC - SPAC' /*+ 
		case when aaaa.LineName = 'Commercial Property'
		     then 'COML PROPERTY'
			 when aaaa.LineName = 'Commercial General Liability'
		     then 'COML GENERAL LIABILITY'
			 when aaaa.LineName = 'Commercial Inland Marine'
		     then 'COML INLAND MARINE'
			 when aaaa.LineName = 'Commercial Crime'
		     then 'COML CRIME'
			 when aaaa.LineName = 'Commercial Auto Liability'
		     then 'COMMERCIAL AUTO LIABILITY'
			 when aaaa.LineName = 'Commercial Auto PD'
		     then 'COMMERCIAL PHYSICAL DAMAGE'
			 when aaaa.LineName = 'Umbrella'
		     then 'UMBRELLA' end*/,		        
       '10' +
	   '1401510002' + 
       '00' + -- Cost Center
	   '000' + /*
       case when aaaa.LineName = 'Commercial Property'
		     then '100'
			 when aaaa.LineName = 'Commercial General Liability'
		     then '200'
			 when aaaa.LineName = 'Commercial Inland Marine'
		     then '300'
			 when aaaa.LineName = 'Commercial Crime'
		     then '400'
			 when aaaa.LineName = 'Commercial Auto Liability'
		     then '501'
			 when aaaa.LineName = 'Commercial Auto PD'
		     then '502'
			 when aaaa.LineName = 'Umbrella'
		     then '600' end  + */
--  MH - St Code 32 for NY
        '32' + 
		'00' +
--		IsNull(bbb.Xtra1, '00')
--  MH - Program Code 10 for NYCON
        '10' */

/*
		
select [Company Code],
	   [GL Effective Date],
	   [Journal Code],
	   [Journal Desc],
	   [GL Account],
	   Amount,
	   [Line Description],
	   XREF1,
	   XREF2,
	   '',
	   '',
	   @ReportEndDate
from #Results
order by abs(Amount) desc


select sum(PeriodAssumedEarnedPremium), sum(CurrentAssumedPremium), sum(CurrentAssumedCommission)
from #AssumedEP

*/



insert into [Sandbox].dbo.FlexiJournalEntries
select [Company Code],
	   [GL Effective Date],
	   [Journal Code],
/*  MH - 12/10/2021 - Switch [Journal Desc] and [Line Description] for display in Flexi
	   [Journal Desc], */
	   [Line Description],
	   [GL Account],
	   Amount,
/*  MH - 12/10/2021 - Switch [Journal Desc] and [Line Description] for display in Flexi
	   [Line Description], */
	   [Journal Desc],
	   XREF1,
	   XREF2,
	   '',
	   '',
	   @ReportEndDate
from #Results

/* So the csv file process only picks up the entries from this process */

insert into [Sandbox].[dbo].[FlexiJournalEntriesAssumedPremCommUEPR]
select [Company Code],
	   [GL Effective Date],
	   [Journal Code],
/*  MH - 12/10/2021 - Switch [Journal Desc] and [Line Description] for display in Flexi
	   [Journal Desc], */
	   [Line Description],
	   [GL Account],
	   Amount,
/*  MH - 12/10/2021 - Switch [Journal Desc] and [Line Description] for display in Flexi
	   [Line Description], */
	   [Journal Desc],
	   XREF1,
	   XREF2,
	   '',
	   '',
	   @ReportEndDate
from #Results


drop table #Auto_Subline_Premium_by_QuoteID
drop table #AssumedEP
drop table #Results 


truncate table [Sandbox].[dbo].tblQuotes


exec master..xp_cmdshell 'sqlcmd -s, -W -Q "set nocount on; select [Company Code], [GL Effective Date], [Journal Code], [Journal Desc], [GL Account], Amount, [Line Description], XREF1, XREF2, XREF3, [Journal ID - Batch #] from [Sandbox].[dbo].[FlexiJournalEntriesAssumedPremCommUEPR] where [Load Date] = convert(date, dateadd(d, -1, GetDate())) and [Journal Code] = ''IMS'' /* and [Company Code] = ''02''*/ " | findstr /v /c:"-" /b > "E:\FlexiExport\FlexiMonthlyAssumed.csv"'
exec master..xp_cmdshell 'ren E:\FlexiExport\"FlexiMonthlyAssumed.csv" "FlexiMonthlyAssumed-%date:~10,4%%date:~4,2%%date:~7,2%.csv"'
exec master..xp_cmdshell 'E:\FlexiExport\SFTPtoFlexiPROD.bat'



end

