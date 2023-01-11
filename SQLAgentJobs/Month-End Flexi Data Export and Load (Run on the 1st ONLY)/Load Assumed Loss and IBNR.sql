/* Run on GRAMERCYMGA in Sandbox */

declare @ReportBeginDate			date;
declare @ReportEndDate				date;
declare @ReportRunEndDate			date;
declare @CarrierID					int;
declare @CompanyID					int;
declare @LossReportBeginDate		date;
declare @LossReportEndDate			date;

begin 

-- Run back to the start of the book for Stillwater, so:
set @ReportBeginDate		= '7/1/2019'
-- initially set to end of first year, then incremented to end of next year as Accident Year is incremented
set @ReportEndDate			= '12/31/' + convert(char(4), datepart(yyyy, @ReportBeginDate))
-- Run on the 1st of next month, so @ReportRunEndDate is the previous day
set @ReportRunEndDate		= dateadd(d, -1, GetDate())
-- To override End Date for reruns
--set @ReportRunEndDate = '12/31/2021' 
set @CompanyID				= 7 --Hardcode Stillwater
set @LossReportBeginDate	= @ReportBeginDate
set @LossReportEndDate		= @ReportRunEndDate


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
	 [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].tblQuotes b
where a.QuoteID = b.QuoteID



create table #AssumedEP     (AccidentYear				int,
                             QuoteID					int, 
							 InsuredPolicyName			varchar(100), 
							 PolicyNumber				varchar(20), 
							 EffectiveDate				datetime,
							 TransEffDate				date,
							 PolicyType					varchar(10),
							 TransactionType			varchar(25),
							 DisplayStatus				varchar(100),
							 LineName					varchar(100),
							 GWP						money,
							 EqBrkdwn					money,
							 TotGWP						money,
							 AssumedPremium				money,
							 PeriodEarnedPremium		money,
							 TreatySharePct				decimal(6, 5),
							 PeriodAssumedEarnedPremium money)

create table #AssumedIBNR (CompanyID					int,
						   AccidentYear					int,
						   LineName						varchar(100),
						   PeriodAssumedEarnedPremium	money,
			               LossUltLossRatio				decimal(4, 3),
						   UltLossAmt					money,
						   AlaeUltLossRatio				decimal(4, 3),
						   UltAlaeAmt					money)

create table #AssumedIBNRLosses	  (CompanyID					int,
								   AccidentYear					int,
								   LineName						varchar(100),
								   ALAEPaid						money,
								   ALAEReserve					money,
								   ALAERecovery					money,
								   IndemnityPaid				money,
								   IndemnityReserve				money,
								   IndemnityRecovery			money,
								   TotalALAE					money,
								   TotalIndemnity				money)


create table #Results ([Company Code]		char(2),
                       [GL Effective Date]  char(8),
                       [Journal Code]		varchar(10),
					   [Journal Desc]		varchar(100),
					   [GL Account]			varchar(50),
					   [Amount]				money,
					   [Line Description]	varchar(100),
					   [XREF1]				varchar(100),
					   [XREF2]				varchar(100))


/* For a rerun */



delete from [Sandbox].[dbo].[IBNR_Monthly_Detail]
where [ReportEndDate] = @ReportRunEndDate

delete from [Sandbox].[dbo].[IBNR_Monthly_Summary]
where [ReportEndDate] = @ReportRunEndDate

delete from [Sandbox].[dbo].[IBNR_Adjustments]
where [TransDate] = @ReportRunEndDate

delete from [Sandbox].[dbo].[FlexiJournalEntries]
where [GL Effective Date] = convert(char(8), @ReportRunEndDate, 112)
  and [GL Account] in ('10520020220000000320010',
						 '10200010220000000320010',
						 '10520032220000000320010',
						 '10200032220000000320010')



while @ReportBeginDate < @ReportRunEndDate

	begin

      if @ReportEndDate > @ReportRunEndDate
	     begin
		       set @ReportEndDate =  @ReportRunEndDate
	     end


		insert into #AssumedEP
		select datepart(yyyy, @ReportBeginDate) AccidentYear,
			   ccc.QuoteID,
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
			   convert(money, IsNull([Sandbox].[ReportReference].[CalcEarnedPremium](ccc.QuoteID, @ReportBeginDate, @ReportEndDate, @ReportEndDate, ccc.TotGWP), 0)) As PeriodEarnedPremium,
			   ccc.TreatySharePct,
			   convert(money, round(IsNull([Sandbox].[ReportReference].[CalcEarnedPremium](ccc.QuoteID, @ReportBeginDate, @ReportEndDate, @ReportEndDate, ccc.TotGWP), 0) 
					   * ccc.TreatySharePct, 2)) PeriodAssumedEarnedPremium

		from (
		select aaa.QuoteID,
			   aaa.NetRate_QuoteID,
			   aaa.InsuredPolicyName,
			   aaa.PolicyNumber,
			   aaa.EffectiveDate,
			   aaa.TransEffDate,
			   aaa.PolicyType,
			   aaa.TransactionType,
			   aaa.DisplayStatus,
			   aaa.LineName,
			   sum(GWP) GWP,
			   IsNull((SELECT		sum(CASE WHEN NetRate_Quote_Insur_Quote.TypeOfBusiness NOT IN ('Endorsement', 'Cancellation', 'Reinstate', 'Audit')
														 THEN NetRate_Quote_Insur_Quote_Locat_Compa.Premium + ISNULL(NetRate_Quote_Insur_Quote_Locat_Compa.TerrorismPremium, 0)
														 ELSE NetRate_Quote_Insur_Quote_Locat_Compa.Endorse + ISNULL(NetRate_Quote_Insur_Quote_Locat_Compa.TerrorismEndorse, 0)
														 END)
									FROM		[MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].NetRate_Quote_Insur_Quote
									INNER JOIN	[MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].NetRate_Quote_Insur_Quote_Locat ON NetRate_Quote_Insur_Quote.QuoteID = NetRate_Quote_Insur_Quote_Locat.QuoteID
									INNER JOIN	[MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].NetRate_Quote_Insur_Quote_Locat_Compa ON NetRate_Quote_Insur_Quote_Locat.LocationID = NetRate_Quote_Insur_Quote_Locat_Compa.LocationID
									WHERE aaa.NetRate_QuoteID = NetRate_Quote_Insur_Quote.QuoteID
										AND aaa.LineName = 'Commercial Property'
										AND NetRate_Quote_Insur_Quote_Locat_Compa.OtherDesc in ('ISO Equipment Breakdown',
																								'ISO Equipment Breakdown Terrorism',
																								'Equipment Breakdown')), 0) EqBrkdwn,
			   sum(GWP)  -
			   IsNull((SELECT		sum(CASE WHEN NetRate_Quote_Insur_Quote.TypeOfBusiness NOT IN ('Endorsement', 'Cancellation', 'Reinstate', 'Audit')
														 THEN NetRate_Quote_Insur_Quote_Locat_Compa.Premium + ISNULL(NetRate_Quote_Insur_Quote_Locat_Compa.TerrorismPremium, 0)
														 ELSE NetRate_Quote_Insur_Quote_Locat_Compa.Endorse + ISNULL(NetRate_Quote_Insur_Quote_Locat_Compa.TerrorismEndorse, 0)
														 END)
									FROM		[MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].NetRate_Quote_Insur_Quote
									INNER JOIN	[MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].NetRate_Quote_Insur_Quote_Locat ON NetRate_Quote_Insur_Quote.QuoteID = NetRate_Quote_Insur_Quote_Locat.QuoteID
									INNER JOIN	[MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].NetRate_Quote_Insur_Quote_Locat_Compa ON NetRate_Quote_Insur_Quote_Locat.LocationID = NetRate_Quote_Insur_Quote_Locat_Compa.LocationID
									WHERE aaa.NetRate_QuoteID = NetRate_Quote_Insur_Quote.QuoteID
										AND aaa.LineName = 'Commercial Property'
										AND NetRate_Quote_Insur_Quote_Locat_Compa.OtherDesc in ('ISO Equipment Breakdown',
																								'ISO Equipment Breakdown Terrorism',
																								'Equipment Breakdown')), 0) TotGWP,
			  aaa.TreatySharePct,
			   convert(money, round((sum(GWP)  -
			   IsNull((SELECT		sum(CASE WHEN NetRate_Quote_Insur_Quote.TypeOfBusiness NOT IN ('Endorsement', 'Cancellation', 'Reinstate', 'Audit')
														 THEN NetRate_Quote_Insur_Quote_Locat_Compa.Premium + ISNULL(NetRate_Quote_Insur_Quote_Locat_Compa.TerrorismPremium, 0)
														 ELSE NetRate_Quote_Insur_Quote_Locat_Compa.Endorse + ISNULL(NetRate_Quote_Insur_Quote_Locat_Compa.TerrorismEndorse, 0)
														 END)
									FROM		[MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].NetRate_Quote_Insur_Quote
									INNER JOIN	[MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].NetRate_Quote_Insur_Quote_Locat ON NetRate_Quote_Insur_Quote.QuoteID = NetRate_Quote_Insur_Quote_Locat.QuoteID
									INNER JOIN	[MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].NetRate_Quote_Insur_Quote_Locat_Compa ON NetRate_Quote_Insur_Quote_Locat.LocationID = NetRate_Quote_Insur_Quote_Locat_Compa.LocationID
									WHERE aaa.NetRate_QuoteID = NetRate_Quote_Insur_Quote.QuoteID
										AND aaa.LineName = 'Commercial Property'
										AND NetRate_Quote_Insur_Quote_Locat_Compa.OtherDesc in ('ISO Equipment Breakdown',
																								'ISO Equipment Breakdown Terrorism',
																								'Equipment Breakdown')), 0)) *
			   aaa.TreatySharePct, 2)) AssumedPremium


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
		--	   max(b.AnnualPremium) GWP
			   ISNULL((SELECT     SUM(INVD.AmtBilled)
									FROM       [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].tblFin_InvoiceDetails INVD
									INNER JOIN [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].tblFin_PolicyCharges PC ON INVD.ChargeCode = PC.ChargeCode
									WHERE      INVD.InvoiceNum = b.InvoiceNum
									  AND      INVD.CompanyLineGuid = cl.CompanyLineGuid
									AND        PC.ChargeType = 'P'
									), 0) GWP
		from [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].[tblQuotes] a
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
		where a.PolicyNumber is not NULL
		--  and convert(date, case when a.DateBound < a.EffectiveDate then a.EffectiveDate else a.DateBound end) >= @ReportBeginDate 
		  and convert(date, case when a.DateBound < a.EffectiveDate then a.EffectiveDate else a.DateBound end) < dateadd(d, 1, @ReportEndDate)
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
		from [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].[tblQuotes] a
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
		where a.PolicyNumber is not NULL
		--  and convert(date, case when a.DateBound < a.EffectiveDate then a.EffectiveDate else a.DateBound end) >= @ReportBeginDate 
		  and convert(date, case when a.DateBound < a.EffectiveDate then a.EffectiveDate else a.DateBound end) < dateadd(d, 1, @ReportEndDate)
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
		from [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].[tblQuotes] a
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
		where a.PolicyNumber is not NULL
		--  and convert(date, case when a.DateBound < a.EffectiveDate then a.EffectiveDate else a.DateBound end) >= @ReportBeginDate 
		  and convert(date, case when a.DateBound < a.EffectiveDate then a.EffectiveDate else a.DateBound end) < dateadd(d, 1, @ReportEndDate)
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
			where --convert(money, IsNull([ReportReference].[CalcEarnedPremium](ccc.QuoteID, @ReportBeginDate, @ReportEndDate, @ReportEndDate, ccc.TotGWP), 0)) <> 0
				  convert(money, IsNull([ReportReference].[CalcEarnedPremium](ccc.QuoteID, '1/1/2017', @ReportEndDate, @ReportEndDate, ccc.TotGWP), 0))  <> 0 */

 
--		set @ReportBeginDate    = dateadd(yyyy, 1, @ReportBeginDate)
        set @ReportBeginDate     = dateadd(dd, 1, @ReportEndDate)
		set @ReportEndDate		 = dateadd(dd, -1, dateadd(yyyy, 1, @ReportBeginDate))

		if @ReportEndDate > @ReportRunEndDate 
			begin
				set @ReportEndDate = @ReportRunEndDate
			end    

	end;



	     
		insert into #AssumedIBNR
		select @CompanyID CompanyID,
		       a.AccidentYear,
			   a.LineName,
			   sum(a.PeriodAssumedEarnedPremium) PeriodAssumedEarnedPremium,
			   b.LossUltLossRatio,
			   convert(money, round(sum(a.PeriodAssumedEarnedPremium) * b.LossUltLossRatio, 2)) UltLossAmt,
			   b.AlaeUltLossRatio,
			   convert(money, round(sum(a.PeriodAssumedEarnedPremium) * b.AlaeUltLossRatio, 2)) UltAlaeAmt
		from #AssumedEP a,
			 [Sandbox].[dbo].[IBNR_CARRIER_ACCYR_LOB_ULR] b
		where a.LineName = b.LineName
		  and a.AccidentYear = b.AccidentYear
		group by a.AccidentYear,
			   a.LineName,
			   b.LossUltLossRatio,
			   b.AlaeUltLossRatio

		insert into #AssumedIBNRLosses
		select @CompanyID CompanyID,
			   aaaaa.accident_year AccidentYear,
			   case when aaaaa.LOB = 'Auto Liability'
					then 'Commercial Auto Liability'
					when aaaaa.LOB = 'Auto Physical Damage'
					then 'Commercial Auto PD'
					when aaaaa.LOB = 'Crime'
					then 'Commercial Crime'
					when aaaaa.LOB = 'General Liability'
					then 'Commercial General Liability'
					when aaaaa.LOB = 'Inland Marine'
					then 'Commercial Inland Marine'
					when aaaaa.LOB = 'Commercial Property'
					then 'Commercial Property'
					when aaaaa.LOB = 'Excess Liability'
					then 'Umbrella' end LOB,
		/*	   aaaaa.TreatySharePct,
			   sum(aaaaa.IndemnityIncurredLoss) +
			   sum(aaaaa.ExpenseIncurredLoss) TotalIncurredLoss,
			   sum(aaaaa.IndemnityRecovery) +
			   sum(aaaaa.ExpenseRecovery) TotalRecovery,
			   sum(aaaaa.ExpensePaid) ExpensePaid,
			   sum(aaaaa.ExpenseReserve) ExpenseReserve,
			   sum(aaaaa.IndemnityPaid) IndemnityPaid,
			   sum(aaaaa.IndeminityReserve) IndeminityReserve,
			   sum(aaaaa.IndemnityRecovery) IndemnityRecovery,
			   sum(aaaaa.ExpenseRecovery) ExpenseRecovery,
			   sum(aaaaa.IndemnityIncurredLoss) IndemnityIncurredLoss,
			   sum(aaaaa.ExpenseIncurredLoss) ExpenseIncurredLoss, */
			   IsNull(sum(aaaaa.TSExpensePaid), 0) ALAEPaid,
			   IsNull(sum(aaaaa.TSExpenseReserve), 0) ALAEReserve,
			   IsNull(sum(aaaaa.TSExpenseRecovery), 0) ALAERecovery,
			   IsNull(sum(aaaaa.TSIndemnityPaid), 0) IndemnityPaid,
			   IsNull(sum(aaaaa.TSIndemnityReserve), 0) IndemnityReserve,
			   IsNull(sum(aaaaa.TSIndemnityRecovery), 0) IndemnityRecovery,
			   IsNull(sum(aaaaa.TSExpensePaid) + sum(aaaaa.TSExpenseReserve) - sum(aaaaa.TSExpenseRecovery), 0) ALAETotal,
			   IsNull(sum(aaaaa.TSIndemnityPaid) + sum(aaaaa.TSIndemnityReserve) - sum(aaaaa.TSIndemnityRecovery), 0) IndemnityTotal
		from (
		select aaaa.claim_id,
			   aaaa.InsuredPolicyName,
			   aaaa.ContractorType,
			   aaaa.claim_num,
			   aaaa.ClaimantName,
			   aaaa.PolicyEffectiveDate,
			   aaaa.policy_year,
			   aaaa.loss_date,
			   aaaa.accident_year,
			   aaaa.LOB,	    
			   aaaa.coverage_name,
			   aaaa.Carrier,
			   aaaa.IndeminityReserve,
			   aaaa.ExpenseReserve,
			   aaaa.IndemnityPaid,
			   aaaa.ExpensePaid,
			   aaaa.IndemnityRecovery,
			   aaaa.ExpenseRecovery,
			   aaaa.IndemnityIncurredLoss,
			   aaaa.ExpenseIncurredLoss,
			   aaaa.TreatySharePct,
			   convert(money, round(aaaa.IndeminityReserve		* aaaa.TreatySharePct, 2)) TSIndemnityReserve,
			   convert(money, round(aaaa.ExpenseReserve			* aaaa.TreatySharePct, 2)) TSExpenseReserve,
			   convert(money, round(aaaa.IndemnityPaid			* aaaa.TreatySharePct, 2)) TSIndemnityPaid,
			   convert(money, round(aaaa.ExpensePaid			* aaaa.TreatySharePct, 2)) TSExpensePaid,
			   convert(money, round(aaaa.IndemnityRecovery		* aaaa.TreatySharePct, 2)) TSIndemnityRecovery,
			   convert(money, round(aaaa.ExpenseRecovery		* aaaa.TreatySharePct, 2)) TSExpenseRecovery,
			   convert(money, round(aaaa.IndemnityIncurredLoss	* aaaa.TreatySharePct, 2)) TSIndemnityIncurredLoss,
			   convert(money, round(aaaa.ExpenseIncurredLoss	* aaaa.TreatySharePct, 2)) TSExpenseIncurredLoss
		from (
		select aaa.claim_id,       
			   aaa.InsuredPolicyName,
			  (select max(RiskDescription)
			   from [Sandbox].[dbo].tblQuotes tq
			   where aaa.InsuredPolicyName = tq.InsuredPolicyName
				 and tq.QuoteID = (select max(tq2.QuoteID)
								   from [Sandbox].[dbo].tblQuotes tq2
								   where tq2.InsuredPolicyName = tq.InsuredPolicyName)) ContractorType,
		--	   max(aaa.RiskDescription) ContractorType,
			   aaa.claim_num,
			   aaa.ClaimantName,
			   aaa.PolicyEffectiveDate,
			   aaa.policy_year,
			   aaa.loss_date,
			   datepart(yyyy, aaa.loss_date) accident_year,
			   aaa.LOB,	    
			   aaa.coverage_name,
			   aaa.Carrier,
			   IsNull(sum(case when aaa.MainTransType = 'Paid Loss' and aaa.IndExp = 'I'
							   then aaa.Amount * -1 
							   when aaa.MainTransType in ('Reserve', 'Recovery') and aaa.IndExp = 'I'
							   then aaa.Amount
							   end), 0) IndeminityReserve,
			   IsNull(sum(case when aaa.MainTransType = 'Paid Loss' and aaa.IndExp = 'E'
							   then aaa.Amount * -1 
							   when aaa.MainTransType in ('Reserve', 'Recovery') and aaa.IndExp = 'E'
							   then aaa.Amount
							   end), 0) ExpenseReserve,
			   IsNull(sum(case when aaa.MainTransType = 'Paid Loss' and aaa.IndExp = 'I' and aaa.transaction_indicator not in ('R', 'I')
/*  MH  6/14/2022 - This is a Paid Reimbursement that should be included as a Paid Loss */
--																	and aaa.reserve_paid_id <> '000250000263171'
							   then aaa.Amount end), 0) IndemnityPaid,
			   IsNull(sum(case when aaa.MainTransType = 'Paid Loss' and aaa.IndExp = 'E' and aaa.transaction_indicator not in ('R', 'I')
							   then aaa.Amount end), 0) ExpensePaid,
			   IsNull(sum(case when aaa.MainTransType = 'Recovery' and aaa.IndExp = 'I'
							   then aaa.Amount * -1 end), 0) IndemnityRecovery,
			   IsNull(sum(case when aaa.MainTransType = 'Recovery' and aaa.IndExp = 'E'
							   then aaa.Amount * -1 end), 0) ExpenseRecovery,
			   IsNull(sum(case when aaa.IndExp = 'I' and aaa.MainTransType in ('Reserve', 'Recovery')
							   then aaa.Amount end), 0) IndemnityIncurredLoss,
			   IsNull(sum(case when aaa.IndExp = 'E' and aaa.MainTransType in ('Reserve', 'Recovery')
							   then aaa.Amount end), 0) ExpenseIncurredLoss,
			  (select rtls.TreatySharePct
			   from [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[ReportReference].[CompanyReinsTreaties] rt,
					[MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[ReportReference].[CompanyReinsTreatyLineShare] rtls
			   where aaa.CompanyID = rt.CompanyID
				 and aaa.PolicyEffectiveDate between rt.TreatyBeginDate and rt.TreatyEndDate
				 and rt.CompanyReinsTreatyID = rtls.CompanyReinsTreatyID
				 and aaa.LineID = rtls.LineId) TreatySharePct
		from (
		select a.claim_id,
			   e.InsuredPolicyName,
		--       a.file_claim_id,
			   e.RiskDescription,
			   a.fh_claim_num claim_num,
			   g.item_name CauseOfLoss,
			   b.accident_description,
			   co.CompanyName,
			   e.PolicyNumber,
			   convert(date, e.EffectiveDate) PolicyEffectiveDate,
			   datepart(yyyy, e.EffectiveDate) policy_year,
			   lob.lob_name LOB,
			   case when lob.lob_name = 'General Liability'
					then 5
					when lob.lob_name in ('Auto Liability', 'Auto Physical Damage')
					then 7
					when lob.lob_name = 'Commercial Property'
					then 6
					when lob.lob_name = 'Excess Liability'
					then 24 
					when lob.lob_name = 'Inland Marine'
					then 22
					when lob.lob_name = 'Crime'
					then 14
					end LineID,
			   j.item_name coverage_name,
			   h.reserve_type_name, 
			   b.party_id,
			   loc.accident_city,
			   loc.accident_state,
			   loc.accident_zip,
			   ltrim(case when b.first_name is NULL 
					then b.last_name
					else b.first_name + ' ' + b.last_name end) ClaimantName,
			   a.loss_date,
			   c.added_date,
/*  MH  6/14/2022 - To back out Paid Reimbursements from Paid Losses instead of being recoveries */
	   case when c.recovery_type = 4
	        then 'P'
/*  MH  9/26/2022 - To include this particular transaction with transaction_indicator = 'I' as a Paid Loss */
			when c.reserve_paid_id = '001020000264612'
			then 'P'
			else c.transaction_indicator end transaction_indicator,
--	   c.transaction_indicator,
			   case when c.reserve_or_paid_code = 'P'
					then 'Paid Loss'
					when c.recovery_type is not NULL or c.reserve_description like '%Recovery%'
					then 'Recovery'
					when c.reserve_or_paid_code = 'R'
					then 'Reserve'
					end MainTransType,
			   case when c.reserve_or_paid_code = 'P'
					then 'Paid Loss'
					when c.recovery_type is not NULL
					then (select rt.recovery_type_desc
						  from [FHE].[dbo].[fv_lookup_pay_recov_type] rt
						  where c.recovery_type = rt.recovery_type_code)
					when c.reserve_or_paid_code = 'R'
					then c.reserve_description
					end TransType,
			   case when i.item_name = 'Indemnity' then 'I'
					else 'E' end IndExp, 
		--	   c.recovery_type,
			   c.loss_amt Amount,
			   c.reserve_paid_id,
			   co.CompanyId,
			   co.CompanyName Carrier	   
		from [FHE].[dbo].[fh_claim] a
			 left join [FHE].[dbo].[fh_code_client] g
			   on a.loss_causation_id = g.item_id
			 left join 
			 [FHE].[dbo].[fh_lawsuit] ls
			   on a.claim_id = ls.claim_id,
			 [FHE].[dbo].[fh_claim_accident] loc,
			 [FHE].[dbo].[fh_party] b
			 join [FHE].[dbo].[fh_reserve_paid] c
			   on b.party_id = c.party_id /*
			  and c.added_date >= @LossReportBeginDate 
			  and c.added_date < dateadd(d, 1, @LossReportEndDate) */
			  and c.reserve_date >= @LossReportBeginDate 
			  and c.reserve_date < dateadd(d, 1, @LossReportEndDate)
			 join [FHE].[dbo].[fh_reserve_type] rt
			   on rt.reserve_type_id = c.reserve_type_id
			 join [FHE].[dbo].[fh_reserve_type] h
			   on c.reserve_type_id = h.reserve_type_id
			 join [FHE].[dbo].[fh_code_general] i
			   on i.item_id = h.reserve_group_id
			 join [FHE].[dbo].[fh_policy_coverage] pc
			   on b.policy_coverage_id = pc.policy_coverage_id
			 join [FHE].[dbo].[fh_code_general] j
			   on j.item_id = pc.coverage_id
			 join [FHE].[dbo].[fh_lob] lob
			   on pc.lob_id = lob.lob_id,
			 [FHE].[dbo].[fh_policy] d,
			 [Sandbox].[dbo].tblQuotes e,
			 [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].[lstLines] f,
			 [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].[tblCompanyLines] cl,
			 [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].[tblCompanyLocations] cloc,
			 [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].[tblCompanies] co
		where d.tier1_company_id = 'C13339'
		  and a.claim_id = b.claim_id
		  and b.claim_id = loc.claim_id
		  and a.policy_id = d.policy_id
		  and replace(d.policy_num, '-', '') = replace(e.PolicyNumber, '-', '')
		--  and convert(date, d.policy_begin_date) = convert(date, e.EffectiveDate)
		  and e.QuoteID =  IsNull((select max(ee.QuoteID)
							from [Sandbox].[dbo].tblQuotes ee
							where ee.PolicyNumber = e.PolicyNumber
							  and IsNull(ee.EndorsementEffective, ee.EffectiveDate) = (select max(IsNull(eee.EndorsementEffective, eee.EffectiveDate))
																						 from [Sandbox].[dbo].tblQuotes eee
																						 where eee.PolicyNumber = ee.PolicyNumber
																						   and IsNull(eee.EndorsementEffective, eee.EffectiveDate) < dateadd(d, 1, a.loss_date))),
								   (select max(ee.QuoteID)
									from [Sandbox].[dbo].tblQuotes ee
									where ee.PolicyNumber = e.PolicyNumber))
		  and e.LineGUID = f.LineGUID
		  and e.CompanyLineGuid = cl.CompanyLineGUID
		  and cl.CompanyLocationGUID = cloc.CompanyLocationGUID
		  and cloc.CompanyGUID = co.CompanyGUID
		  and co.CompanyID in (@CompanyID)
/*  MH  11/30/2022 - To stop the reopened reserve of $350,000 on fh_claim_num 209076 from re-posting with no adjusting entry to the original
                     $350,000 reserve which has been hard-deleted from the FHE database */
		  and c.reserve_paid_id <> '000250000346512'
		--  and a.fh_claim_num in ('209729')
		) aaa 
		--where aaa.claim_status <> 'Closed'
		group by aaa.claim_id,       
			   aaa.InsuredPolicyName,
			   aaa.claim_num,
			   aaa.ClaimantName,
			   aaa.PolicyEffectiveDate,
			   aaa.policy_year,
			   aaa.loss_date,
			   datepart(yyyy, aaa.loss_date),
			   aaa.LOB,
			   aaa.coverage_name,
			   aaa.Carrier,
			   aaa.CompanyID,
			   aaa.PolicyEffectiveDate,
			   aaa.LineID
		) aaaa
		) aaaaa
		group by aaaaa.LOB,
			   aaaaa.accident_year,
			   case when aaaaa.LOB = 'Auto Liability'
					then 'Commercial Auto Liability'
					when aaaaa.LOB = 'Auto Physical Damage'
					then 'Commercial Auto PD'
					when aaaaa.LOB = 'Crime'
					then 'Commercial Crime'
					when aaaaa.LOB = 'General Liability'
					then 'Commercial General Liability'
					when aaaaa.LOB = 'Inland Marine'
					then 'Commercial Inland Marine'
					when aaaaa.LOB = 'Commercial Property'
					then 'Commercial Property'
					when aaaaa.LOB = 'Excess Liability'
					then 'Umbrella' end

/*
select *
from #AssumedIBNR
*/



        insert into [Sandbox].[dbo].IBNR_Monthly_Detail
		select @ReportRunEndDate ReportEndDate,
		       a.*,
		       IsNull(b.ALAEPaid, 0) ALAEPaid, IsNull(b.ALAEReserve, 0) ALAEReserve, IsNull(b.ALAERecovery, 0) ALAERecovery,
			   IsNull(b.IndemnityPaid, 0) IndemnityPaid, IsNull(b.IndemnityReserve, 0) IndemnityReserve, IsNull(b.IndemnityRecovery, 0) IndemnityRecovery,
			   IsNull(b.TotalALAE, 0) TotalALAE, IsNull(b.TotalIndemnity, 0) TotalIndemnity,
			   case when a.UltLossAmt - IsNull(b.TotalIndemnity, 0) < 0
					then a.UltLossAmt
					else IsNull(b.TotalIndemnity, 0) end LimitedTotalIndemnity,
			   case when a.UltAlaeAmt - IsNull(b.TotalALAE, 0) < 0
					then a.UltAlaeAmt
					else IsNull(b.TotalALAE, 0) end LimitedTotalALAE
		from #AssumedIBNR a
		left join #AssumedIBNRLosses b
		  on a.CompanyID = b.CompanyID
		 and a.AccidentYear = b.AccidentYear
		 and a.LineName = b.LineName
		 


		insert into [Sandbox].[dbo].IBNR_Monthly_Summary
		select aaa.ReportEndDate,
		       round(aaa.PeriodAssumedEarnedPremium, 2),
			   round(aaa.UltLossAmt, 2),
			   round(aaa.LimitedTotalIndemnity, 2),
			   round(aaa.LossIBNRAdjustment, 2),
			   round(aaa.UltLossAmt - (aaa.LimitedTotalIndemnity + aaa.LossIBNRAdjustment), 2) LossAdjustment,
			   round(aaa.UltAlaeAmt, 2),
			   round(aaa.LimitedTotalALAE, 2),
			   round(aaa.AlaeIBNRAdjustment, 2),
			   round(aaa.UltAlaeAmt - (aaa.LimitedTotalALAE		 + aaa.AlaeIBNRAdjustment), 2) AlaeAdjustment
		from (
		select a.ReportEndDate,
		       sum(a.PeriodAssumedEarnedPremium) PeriodAssumedEarnedPremium,
		       sum(a.UltLossAmt) UltLossAmt,
			   sum(a.TotalIndemnity) TotalIndemnity,
		       sum(a.LimitedTotalIndemnity) LimitedTotalIndemnity,
			  (select sum(b.LossIBNRAdjustment)
			   from [Sandbox].[dbo].[IBNR_Adjustments] b
			   where b.TransDate < a.ReportEndDate) LossIBNRAdjustment,
		       sum(a.UltAlaeAmt) UltAlaeAmt,
			   sum(a.TotalALAE) TotalALAE,
			   sum(a.LimitedTotalALAE) LimitedTotalALAE,
			  (select sum(b.AlaeIBNRAdjustment)
			   from [Sandbox].[dbo].[IBNR_Adjustments] b
			   where b.TransDate < a.ReportEndDate) AlaeIBNRAdjustment
		from [Sandbox].[dbo].IBNR_Monthly_Detail a
		where a.ReportEndDate = @ReportRunEndDate
		group by a.ReportEndDate
		) aaa




/*

select *
from #AssumedIBNRLosses

*/

insert into [Sandbox].[dbo].[IBNR_Adjustments]
select [ReportEndDate],
       [CurrentLossIBNRAdjustment],
	   [CurrentAlaeIBNRAdjustment]
from [Sandbox].[dbo].[IBNR_Monthly_Summary]
where [ReportEndDate] = @ReportRunEndDate





-- IBNR  JEs

-- Loss (Indemnity) Adjustment

insert into #Results
select '10' [Company Code],
        convert(varchar(8), aaaa.[ReportEndDate], 112) [GL Effective Date],
		'IMS' [Journal Code],
		'LOSS ASSUMED IBNR CHANGE' "Journal Desc",
       '10' +
       '5200202200' + 
       '00' + -- Cost Center
	   '000' + 
--  MH - St Code 32 for NY
        '32' + 
		'00' +
--  MH - Program Code 10 for NYCON
        '10' [GL Account],
		aaaa.CurrentLossIBNRAdjustment Amount,
	   '' [Line Description],
	   '' XREF1,
	   '' XREF2
from [Sandbox].[dbo].IBNR_Monthly_Summary aaaa
where aaaa.[ReportEndDate] = @ReportRunEndDate

-- Balancing Entry

insert into #Results
select '10' [Company Code],
        convert(varchar(8), aaaa.[ReportEndDate], 112) [GL Effective Date],
		'IMS' [Journal Code],
		'LOSS RESERVES ASSUMED IBNR' "Journal Desc",
       '10' +
       '2000102200' + 
       '00' + -- Cost Center
	   '000' + 
--  MH - St Code 32 for NY
        '32' + 
		'00' +
--  MH - Program Code 10 for NYCON
        '10' [GL Account],
		aaaa.CurrentLossIBNRAdjustment * -1 Amount,
	   '' [Line Description],
	   '' XREF1,
	   '' XREF2
from [Sandbox].[dbo].IBNR_Monthly_Summary aaaa
where aaaa.[ReportEndDate] = @ReportRunEndDate



-- ALAE (Expense) Adjustment

insert into #Results
select '10' [Company Code],
        convert(varchar(8), aaaa.[ReportEndDate], 112) [GL Effective Date],
		'IMS' [Journal Code],
		'ADJUSTING-OTHER ASM IBNR CHG' "Journal Desc",
       '10' +
       '5200322200' + 
       '00' + -- Cost Center
	   '000' + 
--  MH - St Code 32 for NY
        '32' + 
		'00' +
--  MH - Program Code 10 for NYCON
        '10' [GL Account],
		aaaa.CurrentALAEIBNRAdjustment Amount,
	   '' [Line Description],
	   '' XREF1,
	   '' XREF2
from [Sandbox].[dbo].IBNR_Monthly_Summary aaaa
where aaaa.[ReportEndDate] = @ReportRunEndDate

-- Balancing Entry

insert into #Results
select '10' [Company Code],
        convert(varchar(8), aaaa.[ReportEndDate], 112) [GL Effective Date],
		'IMS' [Journal Code],
		'ADJ-OTHR RESERVE ASSUMED IBNR' "Journal Desc",
       '10' +
       '2000322200' + 
       '00' + -- Cost Center
	   '000' + 
--  MH - St Code 32 for NY
        '32' + 
		'00' +
--  MH - Program Code 10 for NYCON
        '10' [GL Account],
		aaaa.CurrentALAEIBNRAdjustment * -1 Amount,
	   '' [Line Description],
	   '' XREF1,
	   '' XREF2
from [Sandbox].[dbo].IBNR_Monthly_Summary aaaa
where aaaa.[ReportEndDate] = @ReportRunEndDate

/*
insert into [Sandbox].[dbo].[FlexiJournalEntries]
select *, '', ''
from #Results


		
select *
from #Results

*/

--Run on the 1st, @ReportBeginDate reset to 1st of previous month
set @ReportBeginDate	= dateadd(m, -1, GetDate())
-- To override Begin Date for reruns
--set @ReportBeginDate = '7/1/2021'
--Run on the 1st, @ReportEndDate reset to previous day
set @ReportEndDate		= dateadd(d, -1, GetDate())
-- To override End Date for reruns
--set @ReportEndDate = '7/31/2021'
set @CarrierID = '7' -- Hardcoded for Stillwater

/* For a rerun */



delete from [Sandbox].[dbo].[FlexiJournalEntries]
where [GL Effective Date] = convert(char(8), @ReportEndDate, 112)
  and [GL Account] in ('10500020200000000320010',
					   '10200020000000000320010',
					   '10500032200000000320010',
					   '10200020000000000320010', -- same as 200 balancing code above
					   '10520020210000000320010',
					   '10200010210000000320010',
					   '10520032210000000320010',
					   '10200032210000000320010')



create table #tblQuotes	(QuoteID				int, 
						 PolicyNumber			varchar(20), 
						 EndorsementEffective	date, 
						 EffectiveDate			date, 
						 CompanyLineGuid		uniqueidentifier,
						 LineGUID				uniqueidentifier,
						 RiskDescription		varchar(1000),
						 InsuredPolicyName		varchar(500),
						 ProducerName			varchar(300),
						 InsuredCity			varchar(50),
						 InsuredState			char(2))

create nonclustered index idx_tblQuotes1 on #tblQuotes (QuoteID, PolicyNumber)

insert into #tblQuotes
select QuoteID,
       PolicyNumber,
	   EndorsementEffective,
	   EffectiveDate,
	   CompanyLineGuid,
	   LineGUID,
	   RiskDescription,
	   InsuredPolicyName,
	   ProducerName,
	   InsuredCity,
	   InsuredState
from [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].[tblQuotes]


create table #AssumedLoss (claim_id					char(15),
						   InsuredPolicyName		varchar(100),
						   ContractorType			varchar(100),
						   claim_num				char(6),
						   ClaimantName				varchar(100),
						   PolicyEffectiveDate		date,
						   policy_year				char(4),
						   loss_date				datetime,
						   accident_year			char(4),
						   LOB						varchar(100),
						   coverage_name			varchar(100),
						   Carrier					varchar(100),
						   IndemnityReserve			money,
						   ExpenseReserve			money,
						   IndemnityPaid			money,
						   ExpensePaid				money,
						   IndemnityRecovery		money,
						   ExpenseRecovery			money,
						   IndemnityIncurredLoss	money,
						   ExpenseIncurredLoss		money,
						   TreatySharePct			decimal (6, 5),
						   TSIndemnityReserve		money,
						   TSExpenseReserve			money,
						   TSIndemnityPaid			money,
						   TSExpensePaid			money,
						   TSIndemnityRecovery		money,
						   TSExpenseRecovery		money,
						   TSIndemnityIncurredLoss	money,
						   TSExpenseIncurredLoss	money)




insert into #AssumedLoss				
/*
select aaaaa.LOB,
       aaaaa.accident_year AccidentYear,
--	   aaaaa.TreatySharePct,
	   sum(aaaaa.IndemnityIncurredLoss) +
	   sum(aaaaa.ExpenseIncurredLoss) TotalIncurredLoss,
	   sum(aaaaa.IndemnityRecovery) +
	   sum(aaaaa.ExpenseRecovery) TotalRecovery,
	   sum(aaaaa.ExpensePaid) ExpensePaid,
	   sum(aaaaa.ExpenseReserve) ExpenseReserve,
	   sum(aaaaa.IndemnityPaid) IndemnityPaid,
	   sum(aaaaa.IndeminityReserve) IndeminityReserve,
	   sum(aaaaa.IndemnityRecovery) IndemnityRecovery,
	   sum(aaaaa.ExpenseRecovery) ExpenseRecovery,
	   sum(aaaaa.IndemnityIncurredLoss) IndemnityIncurredLoss,
	   sum(aaaaa.ExpenseIncurredLoss) ExpenseIncurredLoss,
	   sum(aaaaa.TSExpensePaid) ALAEPaid,
	   sum(aaaaa.TSExpenseReserve) ALAEReserve,
	   sum(aaaaa.TSExpenseRecovery) ALAERecovery,
	   sum(aaaaa.TSIndemnityPaid) IndemnityPaid,
	   sum(aaaaa.TSIndemnityReserve) IndemnityReserve,
	   sum(aaaaa.TSIndemnityRecovery) IndemnityRecovery,
	   sum(aaaaa.TSExpensePaid) + sum(aaaaa.TSExpenseReserve) ALAETotal,
	   sum(aaaaa.TSIndemnityPaid) + sum(aaaaa.TSIndemnityReserve) IndemnityTotal
from ( */
select aaaa.claim_id,
       aaaa.InsuredPolicyName,
	   aaaa.ContractorType,
	   aaaa.claim_num,
	   aaaa.ClaimantName,
	   aaaa.PolicyEffectiveDate,
	   aaaa.policy_year,
	   aaaa.loss_date,
	   aaaa.accident_year,
	   aaaa.LOB,	    
	   aaaa.coverage_name,
	   aaaa.Carrier,
	   aaaa.IndeminityReserve,
	   aaaa.ExpenseReserve,
	   aaaa.IndemnityPaid,
	   aaaa.ExpensePaid,
	   aaaa.IndemnityRecovery,
	   aaaa.ExpenseRecovery,
	   aaaa.IndemnityIncurredLoss,
	   aaaa.ExpenseIncurredLoss,
	   aaaa.TreatySharePct,
	   convert(money, round(aaaa.IndeminityReserve		* aaaa.TreatySharePct, 2)) TSIndemnityReserve,
	   convert(money, round(aaaa.ExpenseReserve			* aaaa.TreatySharePct, 2)) TSExpenseReserve,
	   convert(money, round(aaaa.IndemnityPaid			* aaaa.TreatySharePct, 2)) TSIndemnityPaid,
	   convert(money, round(aaaa.ExpensePaid			* aaaa.TreatySharePct, 2)) TSExpensePaid,
	   convert(money, round(aaaa.IndemnityRecovery		* aaaa.TreatySharePct, 2)) TSIndemnityRecovery,
	   convert(money, round(aaaa.ExpenseRecovery		* aaaa.TreatySharePct, 2)) TSExpenseRecovery,
	   convert(money, round(aaaa.IndemnityIncurredLoss	* aaaa.TreatySharePct, 2)) TSIndemnityIncurredLoss,
	   convert(money, round(aaaa.ExpenseIncurredLoss	* aaaa.TreatySharePct, 2)) TSExpenseIncurredLoss
from (
select aaa.claim_id,       
       aaa.InsuredPolicyName,
	  (select max(RiskDescription)
	   from #tblQuotes tq
	   where aaa.InsuredPolicyName = tq.InsuredPolicyName
	     and tq.QuoteID = (select max(tq2.QuoteID)
						   from #tblQuotes tq2
						   where tq2.InsuredPolicyName = tq.InsuredPolicyName)) ContractorType,
--	   max(aaa.RiskDescription) ContractorType,
	   aaa.claim_num,
	   aaa.ClaimantName,
	   aaa.PolicyEffectiveDate,
	   aaa.policy_year,
	   aaa.loss_date,
	   datepart(yyyy, aaa.loss_date) accident_year,
	   aaa.LOB,	    
	   aaa.coverage_name,
	   aaa.Carrier,
	   IsNull(sum(case when aaa.MainTransType = 'Paid Loss' and aaa.IndExp = 'I'
					   then aaa.Amount * -1 
					   when aaa.MainTransType in ('Reserve', 'Recovery') and aaa.IndExp = 'I'
					   then aaa.Amount
					   end), 0) IndeminityReserve,
	   IsNull(sum(case when aaa.MainTransType = 'Paid Loss' and aaa.IndExp = 'E'
					   then aaa.Amount * -1 
					   when aaa.MainTransType in ('Reserve', 'Recovery') and aaa.IndExp = 'E'
					   then aaa.Amount
					   end), 0) ExpenseReserve,
	   IsNull(sum(case when aaa.MainTransType = 'Paid Loss' and aaa.IndExp = 'I' and aaa.transaction_indicator not in ('R', 'I')
/*  MH  6/14/2022 - This is a Paid Reimbursement that should be included as a Paid Loss */
--	                                                        and aaa.reserve_paid_id <> '000250000263171'
					   then aaa.Amount end), 0) IndemnityPaid,
	   IsNull(sum(case when aaa.MainTransType = 'Paid Loss' and aaa.IndExp = 'E' and aaa.transaction_indicator not in ('R', 'I')
					   then aaa.Amount end), 0) ExpensePaid,
	   IsNull(sum(case when aaa.MainTransType = 'Recovery' and aaa.IndExp = 'I'
					   then aaa.Amount * -1 end), 0) IndemnityRecovery,
	   IsNull(sum(case when aaa.MainTransType = 'Recovery' and aaa.IndExp = 'E'
					   then aaa.Amount * -1 end), 0) ExpenseRecovery,
	   IsNull(sum(case when aaa.IndExp = 'I' and aaa.MainTransType in ('Reserve', 'Recovery')
	                   then aaa.Amount end), 0) IndemnityIncurredLoss,
	   IsNull(sum(case when aaa.IndExp = 'E' and aaa.MainTransType in ('Reserve', 'Recovery')
	                   then aaa.Amount end), 0) ExpenseIncurredLoss,
	  (select rtls.TreatySharePct
	   from [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[ReportReference].[CompanyReinsTreaties] rt,
	        [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[ReportReference].[CompanyReinsTreatyLineShare] rtls
       where aaa.CompanyID = rt.CompanyID
	     and aaa.PolicyEffectiveDate between rt.TreatyBeginDate and rt.TreatyEndDate
		 and rt.CompanyReinsTreatyID = rtls.CompanyReinsTreatyID
	     and aaa.LineID = rtls.LineId) TreatySharePct
from (
select a.claim_id,
       e.InsuredPolicyName,
--       a.file_claim_id,
       e.RiskDescription,
	   a.fh_claim_num claim_num,
	   g.item_name CauseOfLoss,
	   b.accident_description,
	   co.CompanyName,
	   e.PolicyNumber,
	   convert(date, e.EffectiveDate) PolicyEffectiveDate,
	   datepart(yyyy, e.EffectiveDate) policy_year,
	   lob.lob_name LOB,
	   case when lob.lob_name = 'General Liability'
			then 5
			when lob.lob_name in ('Auto Liability', 'Auto Physical Damage')
			then 7
			when lob.lob_name = 'Commercial Property'
			then 6
			when lob.lob_name = 'Excess Liability'
			then 24 
			when lob.lob_name = 'Inland Marine'
			then 22
			when lob.lob_name = 'Crime'
			then 14
			end LineID,
	   j.item_name coverage_name,
	   h.reserve_type_name, 
	   b.party_id,
	   loc.accident_city,
	   loc.accident_state,
	   loc.accident_zip,
	   ltrim(case when b.first_name is NULL 
			then b.last_name
			else b.first_name + ' ' + b.last_name end) ClaimantName,
       a.loss_date,
	   c.added_date,
/*  MH  6/14/2022 - To back out Paid Reimbursements from Paid Losses instead of being recoveries */
	   case when c.recovery_type = 4
	        then 'P'
/*  MH  9/26/2022 - To include this particular transaction with transaction_indicator = 'I' as a Paid Loss */
			when c.reserve_paid_id = '001020000264612'
			then 'P'
			else c.transaction_indicator end transaction_indicator,
--	   c.transaction_indicator,
	   case when c.reserve_or_paid_code = 'P'
			then 'Paid Loss'
	        when c.recovery_type is not NULL or c.reserve_description like '%Recovery%'
			then 'Recovery'
			when c.reserve_or_paid_code = 'R'
	        then 'Reserve'
			end MainTransType,
	   case when c.reserve_or_paid_code = 'P'
			then 'Paid Loss'
			when c.recovery_type is not NULL
			then (select rt.recovery_type_desc
			      from [FHE].[dbo].[fv_lookup_pay_recov_type] rt
				  where c.recovery_type = rt.recovery_type_code)
			when c.reserve_or_paid_code = 'R'
	        then c.reserve_description
			end TransType,
	   case when i.item_name = 'Indemnity' then 'I'
	        else 'E' end IndExp, 
--	   c.recovery_type,
       c.loss_amt Amount,
	   c.reserve_paid_id,
	   co.CompanyId,
	   co.CompanyName Carrier	   
from [FHE].[dbo].[fh_claim] a
     left join [FHE].[dbo].[fh_code_client] g
	   on a.loss_causation_id = g.item_id
	 left join 
	 [FHE].[dbo].[fh_lawsuit] ls
	   on a.claim_id = ls.claim_id,
	 [FHE].[dbo].[fh_claim_accident] loc,
     [FHE].[dbo].[fh_party] b
	 join [FHE].[dbo].[fh_reserve_paid] c
	   on b.party_id = c.party_id
      and c.added_date >= @ReportBeginDate 
	  and c.added_date < dateadd(d, 1, @ReportEndDate)
	 join [FHE].[dbo].[fh_reserve_type] rt
	   on rt.reserve_type_id = c.reserve_type_id
	 join [FHE].[dbo].[fh_reserve_type] h
       on c.reserve_type_id = h.reserve_type_id
	 join [FHE].[dbo].[fh_code_general] i
       on i.item_id = h.reserve_group_id
	 join [FHE].[dbo].[fh_policy_coverage] pc
	   on b.policy_coverage_id = pc.policy_coverage_id
	 join [FHE].[dbo].[fh_code_general] j
       on j.item_id = pc.coverage_id
	 join [FHE].[dbo].[fh_lob] lob
       on pc.lob_id = lob.lob_id,
	 [FHE].[dbo].[fh_policy] d,
     #tblQuotes e,
	 [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].[lstLines] f,
	 [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].[tblCompanyLines] cl,
	 [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].[tblCompanyLocations] cloc,
	 [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].[tblCompanies] co
where d.tier1_company_id = 'C13339'
  and a.claim_id = b.claim_id
  and b.claim_id = loc.claim_id
  and a.policy_id = d.policy_id
  and replace(d.policy_num, '-', '') = replace(e.PolicyNumber, '-', '')
--  and convert(date, d.policy_begin_date) = convert(date, e.EffectiveDate)
  and e.QuoteID =  IsNull((select max(ee.QuoteID)
					from #tblQuotes ee
					where ee.PolicyNumber = e.PolicyNumber
					  and IsNull(ee.EndorsementEffective, ee.EffectiveDate) = (select max(IsNull(eee.EndorsementEffective, eee.EffectiveDate))
																				 from #tblQuotes eee
																				 where eee.PolicyNumber = ee.PolicyNumber
																				   and IsNull(eee.EndorsementEffective, eee.EffectiveDate) < dateadd(d, 1, a.loss_date))),
                           (select max(ee.QuoteID)
							from #tblQuotes ee
							where ee.PolicyNumber = e.PolicyNumber))
  and e.LineGUID = f.LineGUID
  and e.CompanyLineGuid = cl.CompanyLineGUID
  and cl.CompanyLocationGUID = cloc.CompanyLocationGUID
  and cloc.CompanyGUID = co.CompanyGUID
  and co.CompanyID in (@CarrierID)
/*  MH  11/30/2022 - To stop the reopened reserve of $350,000 on fh_claim_num 209076 from re-posting with no adjusting entry to the original
                     $350,000 reserve which has been hard-deleted from the FHE database */
		  and c.reserve_paid_id <> '000250000346512'
--  and a.fh_claim_num in ('209729')
) aaa 
--where aaa.claim_status <> 'Closed'
group by aaa.claim_id,       
       aaa.InsuredPolicyName,
	   aaa.claim_num,
	   aaa.ClaimantName,
	   aaa.PolicyEffectiveDate,
	   aaa.policy_year,
	   aaa.loss_date,
	   datepart(yyyy, aaa.loss_date),
	   aaa.LOB,
	   aaa.coverage_name,
	   aaa.Carrier,
	   aaa.CompanyID,
	   aaa.PolicyEffectiveDate,
	   aaa.LineID
) aaaa
/*
where aaaa.LOB = 'General Liability'
  and aaaa.accident_year = 2019
*/
/*
) aaaaa
group by aaaaa.LOB,
       aaaaa.accident_year/*,
	   aaaaa.TreatySharePct
order by 1, 3, 2*/
order by 1, 2 
*/





--  Paid Loss Indemnity (less Recoveries) JEs


insert into #Results
select '10' [Company Code],
        convert(varchar(8), @ReportEndDate, 112) [GL Effective Date],
		'IMS' [Journal Code],
		'LOSS ASSUMED PAID' /*+ 
		case when aaaa.LOB = 'Commercial Property'
		     then 'COML PROPERTY'
			 when aaaa.LOB = 'General Liability'
		     then 'COML GENERAL LIABILITY'
			 when aaaa.LOB = 'Inland Marine'
		     then 'COML INLAND MARINE'
			 when aaaa.LOB = 'Crime'
		     then 'COML CRIME'
			 when aaaa.LOB = 'Auto Liability'
		     then 'COMMERCIAL AUTO LIABILITY'
			 when aaaa.LOB = 'Auto Physical Damage'
		     then 'COMMERCIAL PHYSICAL DAMAGE'
			 when aaaa.LOB = 'Excess Liability'
		     then 'UMBRELLA' end*/ "Journal Desc",
       '10' +
	   '5000202000' + 
       '00' + -- Cost Center 
	   '000' + /*
       case when aaaa.LOB = 'Commercial Property'
		     then '100'
			 when aaaa.LOB = 'General Liability'
		     then '200'
			 when aaaa.LOB = 'Inland Marine'
		     then '300'
			 when aaaa.LOB = 'Crime'
		     then '400'
			 when aaaa.LOB = 'Auto Liability'
		     then '501'
			 when aaaa.LOB = 'Auto Physical Damage'
		     then '502'
			 when aaaa.LOB = 'Excess Liability'
		     then '600' end  + */
--  MH - St Code 32 for NY
        '32' + 
		'00' +
--		IsNull(bbb.Xtra1, '00')
--  MH - Program Code 10 for NYCON
        '10' [GL Account],
		(sum(aaaa.TSIndemnityPaid) - sum(aaaa.TSIndemnityRecovery)) Amount,
	   '' [Line Description],
	   '' XREF1,
	   '' XREF2
from #AssumedLoss aaaa
/*
group by 'LOSS ASSUMED PAID' /*+ 
		case when aaaa.LOB = 'Commercial Property'
		     then 'COML PROPERTY'
			 when aaaa.LOB = 'General Liability'
		     then 'COML GENERAL LIABILITY'
			 when aaaa.LOB = 'Inland Marine'
		     then 'COML INLAND MARINE'
			 when aaaa.LOB = 'Crime'
		     then 'COML CRIME'
			 when aaaa.LOB = 'Auto Liability'
		     then 'COMMERCIAL AUTO LIABILITY'
			 when aaaa.LOB = 'Auto Physical Damage'
		     then 'COMMERCIAL PHYSICAL DAMAGE'
			 when aaaa.LOB = 'Excess Liability'
		     then 'UMBRELLA' end*/,        
       '10' +
	   '5000202000' + 
       '00' + -- Cost Center
	   '000' + /*
       case when aaaa.LOB = 'Commercial Property'
		     then '100'
			 when aaaa.LOB = 'General Liability'
		     then '200'
			 when aaaa.LOB = 'Inland Marine'
		     then '300'
			 when aaaa.LOB = 'Crime'
		     then '400'
			 when aaaa.LOB = 'Auto Liability'
		     then '501'
			 when aaaa.LOB = 'Auto Physical Damage'
		     then '502'
			 when aaaa.LOB = 'Excess Liability'
		     then '600' end  + */
--  MH - St Code 32 for NY
        '32' + 
		'00' +
--		IsNull(bbb.Xtra1, '00')
--  MH - Program Code 10 for NYCON
        '10'
*/
--  Paid Loss Indemnity (less Recoveries) Balancing JEs

insert into #Results
select '10' [Company Code],
        convert(varchar(8), @ReportEndDate, 112) [GL Effective Date],
		'IMS' [Journal Code],
		'REINSURANCE PAYABLE ON PD LOSS'/* +  
		case when aaaa.LOB = 'Commercial Property'
		     then 'COML PROPERTY'
			 when aaaa.LOB = 'General Liability'
		     then 'COML GENERAL LIABILITY'
			 when aaaa.LOB = 'Inland Marine'
		     then 'COML INLAND MARINE'
			 when aaaa.LOB = 'Crime'
		     then 'COML CRIME'
			 when aaaa.LOB = 'Auto Liability'
		     then 'COMMERCIAL AUTO LIABILITY'
			 when aaaa.LOB = 'Auto Physical Damage'
		     then 'COMMERCIAL PHYSICAL DAMAGE'
			 when aaaa.LOB = 'Excess Liability'
		     then 'UMBRELLA' end */"Journal Desc",
       '10' +
	   '2000200000' + 
       '00' + -- Cost Center
	   '000' + /*
       case when aaaa.LOB = 'Commercial Property'
		     then '100'
			 when aaaa.LOB = 'General Liability'
		     then '200'
			 when aaaa.LOB = 'Inland Marine'
		     then '300'
			 when aaaa.LOB = 'Crime'
		     then '400'
			 when aaaa.LOB = 'Auto Liability'
		     then '501'
			 when aaaa.LOB = 'Auto Physical Damage'
		     then '502'
			 when aaaa.LOB = 'Excess Liability'
		     then '600' end  + */
--  MH - St Code 32 for NY
        '32' + 
		'00' +
--		IsNull(bbb.Xtra1, '00')
--  MH - Program Code 10 for NYCON
        '10' [GL Account],
		(sum(aaaa.TSIndemnityPaid) - sum(aaaa.TSIndemnityRecovery)) * -1 Amount,
	   '' [Line Description],
	   '' XREF1,
	   '' XREF2
from #AssumedLoss aaaa
/*
group by 'REINSURANCE PAYABLE ON PD LOSS' /* + 
		case when aaaa.LOB = 'Commercial Property'
		     then 'COML PROPERTY'
			 when aaaa.LOB = 'General Liability'
		     then 'COML GENERAL LIABILITY'
			 when aaaa.LOB = 'Inland Marine'
		     then 'COML INLAND MARINE'
			 when aaaa.LOB = 'Crime'
		     then 'COML CRIME'
			 when aaaa.LOB = 'Auto Liability'
		     then 'COMMERCIAL AUTO LIABILITY'
			 when aaaa.LOB = 'Auto Physical Damage'
		     then 'COMMERCIAL PHYSICAL DAMAGE'
			 when aaaa.LOB = 'Excess Liability'
		     then 'UMBRELLA' end*/,		        
       '10' +
	   '2000200000' + 
       '00' + -- Cost Center
	   '000' + /*
       case when aaaa.LOB = 'Commercial Property'
		     then '100'
			 when aaaa.LOB = 'General Liability'
		     then '200'
			 when aaaa.LOB = 'Inland Marine'
		     then '300'
			 when aaaa.LOB = 'Crime'
		     then '400'
			 when aaaa.LOB = 'Auto Liability'
		     then '501'
			 when aaaa.LOB = 'Auto Physical Damage'
		     then '502'
			 when aaaa.LOB = 'Excess Liability'
		     then '600' end  + */
--  MH - St Code 32 for NY
        '32' + 
		'00' +
--		IsNull(bbb.Xtra1, '00')
--  MH - Program Code 10 for NYCON
        '10'
*/


--  Paid Loss Expense (less Recoveries)  JEs


insert into #Results
select '10' [Company Code],
        convert(varchar(8), @ReportEndDate, 112) [GL Effective Date],
		'IMS' [Journal Code],
		'ADJUSTING-OTHR ASSUMED PAID' /*+ 
		case when aaaa.LOB = 'Commercial Property'
		     then 'COML PROPERTY'
			 when aaaa.LOB = 'General Liability'
		     then 'COML GENERAL LIABILITY'
			 when aaaa.LOB = 'Inland Marine'
		     then 'COML INLAND MARINE'
			 when aaaa.LOB = 'Crime'
		     then 'COML CRIME'
			 when aaaa.LOB = 'Auto Liability'
		     then 'COMMERCIAL AUTO LIABILITY'
			 when aaaa.LOB = 'Auto Physical Damage'
		     then 'COMMERCIAL PHYSICAL DAMAGE'
			 when aaaa.LOB = 'Excess Liability'
		     then 'UMBRELLA' end */"Journal Desc",
       '10' +
	   '5000322000' + 
       '00' + -- Cost Center
	   '000' + /*
       case when aaaa.LOB = 'Commercial Property'
		     then '100'
			 when aaaa.LOB = 'General Liability'
		     then '200'
			 when aaaa.LOB = 'Inland Marine'
		     then '300'
			 when aaaa.LOB = 'Crime'
		     then '400'
			 when aaaa.LOB = 'Auto Liability'
		     then '501'
			 when aaaa.LOB = 'Auto Physical Damage'
		     then '502'
			 when aaaa.LOB = 'Excess Liability'
		     then '600' end  + */
--  MH - St Code 32 for NY
        '32' + 
		'00' +
--		IsNull(bbb.Xtra1, '00')
--  MH - Program Code 10 for NYCON
        '10' [GL Account],
		(sum(aaaa.TSExpensePaid) - sum(aaaa.TSExpenseRecovery)) Amount,
	   '' [Line Description],
	   '' XREF1,
	   '' XREF2
from #AssumedLoss aaaa
/*
group by 'ADJUSTING-OTHR ASSUMED PAID' /*+ 
		case when aaaa.LOB = 'Commercial Property'
		     then 'COML PROPERTY'
			 when aaaa.LOB = 'General Liability'
		     then 'COML GENERAL LIABILITY'
			 when aaaa.LOB = 'Inland Marine'
		     then 'COML INLAND MARINE'
			 when aaaa.LOB = 'Crime'
		     then 'COML CRIME'
			 when aaaa.LOB = 'Auto Liability'
		     then 'COMMERCIAL AUTO LIABILITY'
			 when aaaa.LOB = 'Auto Physical Damage'
		     then 'COMMERCIAL PHYSICAL DAMAGE'
			 when aaaa.LOB = 'Excess Liability'
		     then 'UMBRELLA' end*/,	   
       '10' +
	   '5000322000' + 
       '00' + -- Cost Center
	   '000' + /*
       case when aaaa.LOB = 'Commercial Property'
		     then '100'
			 when aaaa.LOB = 'General Liability'
		     then '200'
			 when aaaa.LOB = 'Inland Marine'
		     then '300'
			 when aaaa.LOB = 'Crime'
		     then '400'
			 when aaaa.LOB = 'Auto Liability'
		     then '501'
			 when aaaa.LOB = 'Auto Physical Damage'
		     then '502'
			 when aaaa.LOB = 'Excess Liability'
		     then '600' end  + */
--  MH - St Code 32 for NY
        '32' + 
		'00' +
--		IsNull(bbb.Xtra1, '00')
--  MH - Program Code 10 for NYCON
        '10'
*/


--  Paid Loss Expense (less Recoveries) Balancing JEs

insert into #Results
select '10' [Company Code],
        convert(varchar(8), @ReportEndDate, 112) [GL Effective Date],
		'IMS' [Journal Code],
		'REINSURANCE PAYABLE ON PD LOSS' /*+ 
		case when aaaa.LOB = 'Commercial Property'
		     then 'COML PROPERTY'
			 when aaaa.LOB = 'General Liability'
		     then 'COML GENERAL LIABILITY'
			 when aaaa.LOB = 'Inland Marine'
		     then 'COML INLAND MARINE'
			 when aaaa.LOB = 'Crime'
		     then 'COML CRIME'
			 when aaaa.LOB = 'Auto Liability'
		     then 'COMMERCIAL AUTO LIABILITY'
			 when aaaa.LOB = 'Auto Physical Damage'
		     then 'COMMERCIAL PHYSICAL DAMAGE'
			 when aaaa.LOB = 'Excess Liability'
		     then 'UMBRELLA' end */"Journal Desc",
       '10' +
	   '2000200000' + 
       '00' + -- Cost Center
	   '000' + /*
       case when aaaa.LOB = 'Commercial Property'
		     then '100'
			 when aaaa.LOB = 'General Liability'
		     then '200'
			 when aaaa.LOB = 'Inland Marine'
		     then '300'
			 when aaaa.LOB = 'Crime'
		     then '400'
			 when aaaa.LOB = 'Auto Liability'
		     then '501'
			 when aaaa.LOB = 'Auto Physical Damage'
		     then '502'
			 when aaaa.LOB = 'Excess Liability'
		     then '600' end  + */
--  MH - St Code 32 for NY
        '32' + 
		'00' +
--		IsNull(bbb.Xtra1, '00')
--  MH - Program Code 10 for NYCON
        '10' [GL Account],
		(sum(aaaa.TSExpensePaid) - sum(aaaa.TSExpenseRecovery)) * -1 Amount,
	   '' [Line Description],
	   '' XREF1,
	   '' XREF2
from #AssumedLoss aaaa
/*
group by 'REINSURANCE PAYABLE ON PD LOSS' /* + 
		case when aaaa.LOB = 'Commercial Property'
		     then 'COML PROPERTY'
			 when aaaa.LOB = 'General Liability'
		     then 'COML GENERAL LIABILITY'
			 when aaaa.LOB = 'Inland Marine'
		     then 'COML INLAND MARINE'
			 when aaaa.LOB = 'Crime'
		     then 'COML CRIME'
			 when aaaa.LOB = 'Auto Liability'
		     then 'COMMERCIAL AUTO LIABILITY'
			 when aaaa.LOB = 'Auto Physical Damage'
		     then 'COMMERCIAL PHYSICAL DAMAGE'
			 when aaaa.LOB = 'Excess Liability'
		     then 'UMBRELLA' end*/,		        
       '10' +
	   '2000200000' + 
       '00' + -- Cost Center
	   '000' + /*
       case when aaaa.LOB = 'Commercial Property'
		     then '100'
			 when aaaa.LOB = 'General Liability'
		     then '200'
			 when aaaa.LOB = 'Inland Marine'
		     then '300'
			 when aaaa.LOB = 'Crime'
		     then '400'
			 when aaaa.LOB = 'Auto Liability'
		     then '501'
			 when aaaa.LOB = 'Auto Physical Damage'
		     then '502'
			 when aaaa.LOB = 'Excess Liability'
		     then '600' end  + */
--  MH - St Code 32 for NY
        '32' + 
		'00' +
--		IsNull(bbb.Xtra1, '00')
--  MH - Program Code 10 for NYCON
        '10'
*/



--  Case Reserves Indemnity  JEs


insert into #Results
select '10' [Company Code],
        convert(varchar(8), @ReportEndDate, 112) [GL Effective Date],
		'IMS' [Journal Code],
		'LOSS ASSUMED CASE CHANGE' /* + 
		case when aaaa.LOB = 'Commercial Property'
		     then 'COML PROPERTY'
			 when aaaa.LOB = 'General Liability'
		     then 'COML GENERAL LIABILITY'
			 when aaaa.LOB = 'Inland Marine'
		     then 'COML INLAND MARINE'
			 when aaaa.LOB = 'Crime'
		     then 'COML CRIME'
			 when aaaa.LOB = 'Auto Liability'
		     then 'COMMERCIAL AUTO LIABILITY'
			 when aaaa.LOB = 'Auto Physical Damage'
		     then 'COMMERCIAL PHYSICAL DAMAGE'
			 when aaaa.LOB = 'Excess Liability'
		     then 'UMBRELLA' end */"Journal Desc",
       '10' +
	   '5200202100' + 
       '00' + -- Cost Center
	   '000' + /*
       case when aaaa.LOB = 'Commercial Property'
		     then '100'
			 when aaaa.LOB = 'General Liability'
		     then '200'
			 when aaaa.LOB = 'Inland Marine'
		     then '300'
			 when aaaa.LOB = 'Crime'
		     then '400'
			 when aaaa.LOB = 'Auto Liability'
		     then '501'
			 when aaaa.LOB = 'Auto Physical Damage'
		     then '502'
			 when aaaa.LOB = 'Excess Liability'
		     then '600' end  + */
--  MH - St Code 32 for NY
        '32' + 
		'00' +
--		IsNull(bbb.Xtra1, '00')
--  MH - Program Code 10 for NYCON
        '10' [GL Account],
		sum(aaaa.TSIndemnityReserve) Amount,
	   '' [Line Description],
	   '' XREF1,
	   '' XREF2
from #AssumedLoss aaaa
/*
group by 'LOSS ASSUMED CASE CHANGE' /* + 
		case when aaaa.LOB = 'Commercial Property'
		     then 'COML PROPERTY'
			 when aaaa.LOB = 'General Liability'
		     then 'COML GENERAL LIABILITY'
			 when aaaa.LOB = 'Inland Marine'
		     then 'COML INLAND MARINE'
			 when aaaa.LOB = 'Crime'
		     then 'COML CRIME'
			 when aaaa.LOB = 'Auto Liability'
		     then 'COMMERCIAL AUTO LIABILITY'
			 when aaaa.LOB = 'Auto Physical Damage'
		     then 'COMMERCIAL PHYSICAL DAMAGE'
			 when aaaa.LOB = 'Excess Liability'
		     then 'UMBRELLA' end*/,		        
       '10' +
	   '5200202100' + 
       '00' + -- Cost Center
	   '000' + /*
       case when aaaa.LOB = 'Commercial Property'
		     then '100'
			 when aaaa.LOB = 'General Liability'
		     then '200'
			 when aaaa.LOB = 'Inland Marine'
		     then '300'
			 when aaaa.LOB = 'Crime'
		     then '400'
			 when aaaa.LOB = 'Auto Liability'
		     then '501'
			 when aaaa.LOB = 'Auto Physical Damage'
		     then '502'
			 when aaaa.LOB = 'Excess Liability'
		     then '600' end  + */
--  MH - St Code 32 for NY
        '32' + 
		'00' +
--		IsNull(bbb.Xtra1, '00')
--  MH - Program Code 10 for NYCON
        '10'
*/
--  Case Reserves Indemnity Balancing JEs

insert into #Results
select '10' [Company Code],
        convert(varchar(8), @ReportEndDate, 112) [GL Effective Date],
		'IMS' [Journal Code],
		'LOSS RESERVES ASSUMED CASE' /* + 
		case when aaaa.LOB = 'Commercial Property'
		     then 'COML PROPERTY'
			 when aaaa.LOB = 'General Liability'
		     then 'COML GENERAL LIABILITY'
			 when aaaa.LOB = 'Inland Marine'
		     then 'COML INLAND MARINE'
			 when aaaa.LOB = 'Crime'
		     then 'COML CRIME'
			 when aaaa.LOB = 'Auto Liability'
		     then 'COMMERCIAL AUTO LIABILITY'
			 when aaaa.LOB = 'Auto Physical Damage'
		     then 'COMMERCIAL PHYSICAL DAMAGE'
			 when aaaa.LOB = 'Excess Liability'
		     then 'UMBRELLA' end */ "Journal Desc",
       '10' +
	   '2000102100' + 
       '00' + -- Cost Center
	   '000' + /*
       case when aaaa.LOB = 'Commercial Property'
		     then '100'
			 when aaaa.LOB = 'General Liability'
		     then '200'
			 when aaaa.LOB = 'Inland Marine'
		     then '300'
			 when aaaa.LOB = 'Crime'
		     then '400'
			 when aaaa.LOB = 'Auto Liability'
		     then '501'
			 when aaaa.LOB = 'Auto Physical Damage'
		     then '502'
			 when aaaa.LOB = 'Excess Liability'
		     then '600' end  + */
--  MH - St Code 32 for NY
        '32' + 
		'00' +
--		IsNull(bbb.Xtra1, '00')
--  MH - Program Code 10 for NYCON
        '10' [GL Account],
		sum(aaaa.TSIndemnityReserve) * -1 Amount,
	   '' [Line Description],
	   '' XREF1,
	   '' XREF2
from #AssumedLoss aaaa
/*
group by 'LOSS RESERVES ASSUMED CASE' /* + 
		case when aaaa.LOB = 'Commercial Property'
		     then 'COML PROPERTY'
			 when aaaa.LOB = 'General Liability'
		     then 'COML GENERAL LIABILITY'
			 when aaaa.LOB = 'Inland Marine'
		     then 'COML INLAND MARINE'
			 when aaaa.LOB = 'Crime'
		     then 'COML CRIME'
			 when aaaa.LOB = 'Auto Liability'
		     then 'COMMERCIAL AUTO LIABILITY'
			 when aaaa.LOB = 'Auto Physical Damage'
		     then 'COMMERCIAL PHYSICAL DAMAGE'
			 when aaaa.LOB = 'Excess Liability'
		     then 'UMBRELLA' end*/,		        
       '10' +
	   '2000102100' + 
       '00' + -- Cost Center
	   '000' + /*
       case when aaaa.LOB = 'Commercial Property'
		     then '100'
			 when aaaa.LOB = 'General Liability'
		     then '200'
			 when aaaa.LOB = 'Inland Marine'
		     then '300'
			 when aaaa.LOB = 'Crime'
		     then '400'
			 when aaaa.LOB = 'Auto Liability'
		     then '501'
			 when aaaa.LOB = 'Auto Physical Damage'
		     then '502'
			 when aaaa.LOB = 'Excess Liability'
		     then '600' end  + */
--  MH - St Code 32 for NY
        '32' + 
		'00' +
--		IsNull(bbb.Xtra1, '00')
--  MH - Program Code 10 for NYCON
        '10'
*/

--  Case Reserves Expense  JEs


insert into #Results
select '10' [Company Code],
        convert(varchar(8), @ReportEndDate, 112) [GL Effective Date],
		'IMS' [Journal Code],
		'ADJUSTING-OTHER ASM CASE CHG' /* + 
		case when aaaa.LOB = 'Commercial Property'
		     then 'COML PROPERTY'
			 when aaaa.LOB = 'General Liability'
		     then 'COML GENERAL LIABILITY'
			 when aaaa.LOB = 'Inland Marine'
		     then 'COML INLAND MARINE'
			 when aaaa.LOB = 'Crime'
		     then 'COML CRIME'
			 when aaaa.LOB = 'Auto Liability'
		     then 'COMMERCIAL AUTO LIABILITY'
			 when aaaa.LOB = 'Auto Physical Damage'
		     then 'COMMERCIAL PHYSICAL DAMAGE'
			 when aaaa.LOB = 'Excess Liability'
		     then 'UMBRELLA' end */ "Journal Desc",
-- This is for all Paid Loss (IND and EXP right now, need new codes
       '10' +
	   '5200322100' + 
       '00' + -- Cost Center
	   '000' + /*
       case when aaaa.LOB = 'Commercial Property'
		     then '100'
			 when aaaa.LOB = 'General Liability'
		     then '200'
			 when aaaa.LOB = 'Inland Marine'
		     then '300'
			 when aaaa.LOB = 'Crime'
		     then '400'
			 when aaaa.LOB = 'Auto Liability'
		     then '501'
			 when aaaa.LOB = 'Auto Physical Damage'
		     then '502'
			 when aaaa.LOB = 'Excess Liability'
		     then '600' end  + */
--  MH - St Code 32 for NY
        '32' + 
		'00' +
--		IsNull(bbb.Xtra1, '00')
--  MH - Program Code 10 for NYCON
        '10' [GL Account],
		sum(aaaa.TSExpenseReserve) Amount,
	   '' [Line Description],
	   '' XREF1,
	   '' XREF2
from #AssumedLoss aaaa
/*
group by 'ADJUSTING-OTHER ASM CASE CHG' /* + 
		case when aaaa.LOB = 'Commercial Property'
		     then 'COML PROPERTY'
			 when aaaa.LOB = 'General Liability'
		     then 'COML GENERAL LIABILITY'
			 when aaaa.LOB = 'Inland Marine'
		     then 'COML INLAND MARINE'
			 when aaaa.LOB = 'Crime'
		     then 'COML CRIME'
			 when aaaa.LOB = 'Auto Liability'
		     then 'COMMERCIAL AUTO LIABILITY'
			 when aaaa.LOB = 'Auto Physical Damage'
		     then 'COMMERCIAL PHYSICAL DAMAGE'
			 when aaaa.LOB = 'Excess Liability'
		     then 'UMBRELLA' end*/,		      
       '10' +
	   '5200322100' + 
       '00' + -- Cost Center
	   '000' + /*
       case when aaaa.LOB = 'Commercial Property'
		     then '100'
			 when aaaa.LOB = 'General Liability'
		     then '200'
			 when aaaa.LOB = 'Inland Marine'
		     then '300'
			 when aaaa.LOB = 'Crime'
		     then '400'
			 when aaaa.LOB = 'Auto Liability'
		     then '501'
			 when aaaa.LOB = 'Auto Physical Damage'
		     then '502'
			 when aaaa.LOB = 'Excess Liability'
		     then '600' end  + */
--  MH - St Code 32 for NY
        '32' + 
		'00' +
--		IsNull(bbb.Xtra1, '00')
--  MH - Program Code 10 for NYCON
        '10'
*/
--  Case Reserves Expense Balancing JEs

insert into #Results
select '10' [Company Code],
        convert(varchar(8), @ReportEndDate, 112) [GL Effective Date],
		'IMS' [Journal Code],
		'ADJ-OTHR RESERVE ASSUMED CASE' /* + 
		case when aaaa.LOB = 'Commercial Property'
		     then 'COML PROPERTY'
			 when aaaa.LOB = 'General Liability'
		     then 'COML GENERAL LIABILITY'
			 when aaaa.LOB = 'Inland Marine'
		     then 'COML INLAND MARINE'
			 when aaaa.LOB = 'Crime'
		     then 'COML CRIME'
			 when aaaa.LOB = 'Auto Liability'
		     then 'COMMERCIAL AUTO LIABILITY'
			 when aaaa.LOB = 'Auto Physical Damage'
		     then 'COMMERCIAL PHYSICAL DAMAGE'
			 when aaaa.LOB = 'Excess Liability'
		     then 'UMBRELLA' end */ "Journal Desc",
       '10' +
	   '2000322100' + 
       '00' + -- Cost Center
	   '000' + /*
       case when aaaa.LOB = 'Commercial Property'
		     then '100'
			 when aaaa.LOB = 'General Liability'
		     then '200'
			 when aaaa.LOB = 'Inland Marine'
		     then '300'
			 when aaaa.LOB = 'Crime'
		     then '400'
			 when aaaa.LOB = 'Auto Liability'
		     then '501'
			 when aaaa.LOB = 'Auto Physical Damage'
		     then '502'
			 when aaaa.LOB = 'Excess Liability'
		     then '600' end  + */
--  MH - St Code 32 for NY
        '32' + 
		'00' +
--		IsNull(bbb.Xtra1, '00')
--  MH - Program Code 10 for NYCON
        '10' [GL Account],
		sum(aaaa.TSExpenseReserve) * -1 Amount,
	   '' [Line Description],
	   '' XREF1,
	   '' XREF2
from #AssumedLoss aaaa
/*
group by 'ADJ-OTHR RESERVE ASSUMED CASE' /* + 
		case when aaaa.LOB = 'Commercial Property'
		     then 'COML PROPERTY'
			 when aaaa.LOB = 'General Liability'
		     then 'COML GENERAL LIABILITY'
			 when aaaa.LOB = 'Inland Marine'
		     then 'COML INLAND MARINE'
			 when aaaa.LOB = 'Crime'
		     then 'COML CRIME'
			 when aaaa.LOB = 'Auto Liability'
		     then 'COMMERCIAL AUTO LIABILITY'
			 when aaaa.LOB = 'Auto Physical Damage'
		     then 'COMMERCIAL PHYSICAL DAMAGE'
			 when aaaa.LOB = 'Excess Liability'
		     then 'UMBRELLA' end*/,		        
       '10' +
	   '2000322100' + 
       '00' + -- Cost Center
	   '000' + /*
       case when aaaa.LOB = 'Commercial Property'
		     then '100'
			 when aaaa.LOB = 'General Liability'
		     then '200'
			 when aaaa.LOB = 'Inland Marine'
		     then '300'
			 when aaaa.LOB = 'Crime'
		     then '400'
			 when aaaa.LOB = 'Auto Liability'
		     then '501'
			 when aaaa.LOB = 'Auto Physical Damage'
		     then '502'
			 when aaaa.LOB = 'Excess Liability'
		     then '600' end  + */
--  MH - St Code 32 for NY
        '32' + 
		'00' +
--		IsNull(bbb.Xtra1, '00')
--  MH - Program Code 10 for NYCON
        '10'

*/



insert into [Sandbox].[dbo].[FlexiJournalEntries]
/*  MH - 12/10/2021 - Switch [Journal Desc] and [Line Description] for display in Flexi
select *, '', '', convert(date, dateadd(d, -1, GetDate())) */
select [Company Code],
       [GL Effective Date],
	   [Journal Code],
	   [Line Description],
	   [GL Account],
	   [Amount],
	   [Journal Desc],
	   [XREF1],
	   [XREF2], '', '', convert(date, dateadd(d, -1, GetDate()))
from #Results
where Amount <> 0



/*

select * 
from #Results
where Amount <> 0

*/




--drop table #tblQuotes
drop table #AssumedLoss
drop table #Results

drop table #Auto_Subline_Premium_by_QuoteID
drop table #AssumedEP
drop table #AssumedIBNR
drop table #AssumedIBNRLosses



truncate table [Sandbox].[dbo].tblQuotes



exec master..xp_cmdshell 'sqlcmd -s, -W -Q "set nocount on; select [Company Code], [GL Effective Date], [Journal Code], [Journal Desc], [GL Account], Amount, [Line Description], XREF1, XREF2, XREF3, [Journal ID - Batch #] from [Sandbox].[dbo].[FlexiJournalEntries] where [Load Date] = convert(date, dateadd(d, -1, GetDate()))  and [Journal Code] = ''IMS'' and [GL Account] in (''10520020220000000320010'',''10200010220000000320010'',''10520032220000000320010'',''10200032220000000320010'',''10500020200000000320010'',''10200020000000000320010'',''10500032200000000320010'',''10200020000000000320010'',''10520020210000000320010'',''10200010210000000320010'',''10520032210000000320010'',''10200032210000000320010'') " | findstr /v /c:"-" /b > "E:\FlexiExport\FlexiMonthlyLoss.csv"'
exec master..xp_cmdshell 'ren E:\FlexiExport\"FlexiMonthlyLoss.csv" "FlexiMonthlyLoss-%date:~10,4%%date:~4,2%%date:~7,2%.csv"'
exec master..xp_cmdshell 'E:\FlexiExport\SFTPtoFlexiPROD.bat'






end