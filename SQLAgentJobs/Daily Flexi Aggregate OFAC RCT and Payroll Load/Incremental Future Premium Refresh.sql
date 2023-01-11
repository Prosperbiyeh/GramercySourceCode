


declare @RptBeginDate			date;
declare @RptEndDate				date;
declare @AsOfDate				date;

declare @ReportBeginDate		date;
declare @ReportEndDate			date;
declare @NewRows				int;



begin 

set @RptBeginDate		= dateadd(d, -1, GetDate())
set @RptEndDate			= dateadd(m, 1, dateadd(yyyy, 1, GetDate()))

set @ReportBeginDate	= @RptBeginDate
set @ReportEndDate		= dateadd(d, -1, dateadd(m, 1, convert(char(6), @RptBeginDate, 112) + '01'))



create table #Auto_Subline_Premium_by_QuoteID (QuoteID int, PolicyNumber varchar(20), ALPrem money, APDPrem money, AutoBTM money)
create nonclustered index idx_QuoteID on #Auto_Subline_Premium_by_QuoteID (QuoteID)

insert into #Auto_Subline_Premium_by_QuoteID
select *
from [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[ReportReference].[v_Auto_Subline_Premium_by_QuoteID]




create table #EqBreakdown (QuoteID int, EQBkdwnPrem money)
--create nonclustered index idx_EBQuoteID on #EqBreakdown (QuoteID)

insert into #EqBreakdown
select *
from (
select tq.QuoteID,
CASE WHEN iq.TypeOfBusiness NOT IN ('Endorsement', 'Cancellation', 'Reinstate', 'Audit')
											THEN iqlc.Premium + ISNULL(iqlc.TerrorismPremium, 0)
											ELSE iqlc.Endorse + ISNULL(iqlc.TerrorismEndorse, 0)
											END EQBkdwnPrem
FROM		[MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].[tblQuotes] tq,
            [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].NetRate_Quote_Insur_Quote iq
INNER JOIN	[MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].NetRate_Quote_Insur_Quote_Locat iql ON iq.QuoteID = iql.QuoteID
INNER JOIN	[MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].NetRate_Quote_Insur_Quote_Locat_Compa iqlc ON iql.LocationID = iqlc.LocationID
WHERE tq.DateBound is not NULL
  and tq.NetRate_QuoteID = iq.QuoteID
  and iqlc.OtherDesc in ( 'ISO Equipment Breakdown',
							'ISO Equipment Breakdown Terrorism',
							'Equipment Breakdown')
group by tq.QuoteID,
CASE WHEN iq.TypeOfBusiness NOT IN ('Endorsement', 'Cancellation', 'Reinstate', 'Audit')
											THEN iqlc.Premium + ISNULL(iqlc.TerrorismPremium, 0)
											ELSE iqlc.Endorse + ISNULL(iqlc.TerrorismEndorse, 0)
											END
) aaa
where IsNull(aaa.EQBkdwnPrem, 0) <> 0


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
from [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].tblQuotes a,
	 [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].[tblFin_Invoices] b,
	 [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].[tblFin_InvoiceDetails] id,
	 [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].tblFin_PolicyCharges pc
where a.DateBound is not NULL																												
  and a.QuoteID = b.QuoteID
  and b.Failed = 0
  and b.InvoiceNum = id.InvoiceNum
  and id.ChargeCode = pc.ChargeCode
  and pc.ChargeType = 'P'
/* Just get the new bound transactions */
  and not exists (select 1
			      from [Sandbox].[dbo].[PremiumByYYYYMMFuture] c
				  where a.QuoteID = c.QuoteID)
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

set @NewRows = @@ROWCOUNT

--  Skip to the last month if nothing to load

if @NewRows = 0
begin

set @ReportBeginDate	= (select convert(date, max(YYYYMM) + '01')
						   from [Sandbox].[dbo].[PremiumByYYYYMMFuture])
set @ReportEndDate		= dateadd(dd, -1, dateadd(m, 1, @ReportBeginDate)) 

end

while @ReportEndDate <= @RptEndDate

	begin

	    if convert(char(6), @ReportBeginDate, 112) = (select max(YYYYMM)
													  from [Sandbox].[dbo].[PremiumByYYYYMMFuture])
			begin

--  When the YYYYMM of the @ReportBeginDate = the last month loaded, 
--  reload Sandbox tblQuotes table with all transactions
--  -AND- wipe that month out and recalculate EP for all transactions that will earn premium in that YYYYMM

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
				from [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].tblQuotes a,
					 [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].[tblFin_Invoices] b,
					 [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].[tblFin_InvoiceDetails] id
				where a.DateBound is not NULL																												
				  and a.QuoteID = b.QuoteID
				  and b.Failed = 0
				  and b.InvoiceNum = id.InvoiceNum /*  We want all transactions for the last month  
				  and not exists (select 1
								  from [Sandbox].[dbo].[PremiumByYYYYMMFuture] c
								  where a.QuoteID = c.QuoteID) */
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

				delete from [Sandbox].[dbo].[PremiumByYYYYMMFuture]
				where YYYYMM = (select max(YYYYMM)
								from [Sandbox].[dbo].[PremiumByYYYYMMFuture])
			
			end


		insert into [Sandbox].[dbo].[PremiumByYYYYMMFuture]
			select convert(char(6), @ReportBeginDate, 112) YYYYMM,
			ccc.QuoteID,
			ccc.InsuredPolicyName,
			ccc.PolicyNumber,
			ccc.EffectiveDate,
			ccc.TransEffDate,
			ccc.PolicyType,
			ccc.TransactionType,
			ccc.DisplayStatus,
			ccc.LineName,
			ccc.CompanyName,
			ccc.GWP,
			ccc.EqBrkdwn,
			ccc.TotGWP,
			ccc.AssumedPremium,
			convert(money, IsNull([Sandbox].[ReportReference].[CalcEarnedPremium](ccc.QuoteID, @ReportBeginDate, @ReportEndDate, @ReportEndDate, ccc.GWP), 0)) As PeriodEarnedPremium,
		    ccc.TreatySharePct,
		    convert(money, round(IsNull([Sandbox].[ReportReference].[CalcEarnedPremium](ccc.QuoteID, @ReportBeginDate, @ReportEndDate, @ReportEndDate, ccc.TotGWP), 0) 
				   * ccc.TreatySharePct, 2)) PeriodAssumedEarnedPremium,
		    convert(money, IsNull([Sandbox].[ReportReference].[CalcEarnedPremium](ccc.QuoteID, '1/1/2017', @ReportEndDate, @ReportEndDate, ccc.GWP), 0)) As ITDEarnedPremium,
		    convert(money, round(IsNull([Sandbox].[ReportReference].[CalcEarnedPremium](ccc.QuoteID, '1/1/2017', @ReportEndDate, @ReportEndDate, ccc.TotGWP), 0) 
				   * ccc.TreatySharePct, 2)) ITDAssumedEarnedPremium
--		into [ReportReference].[PremiumByYYYYMMFuture]
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
			   aaa.CompanyName,
			   sum(GWP) GWP,
/*
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
														'Equipment Breakdown')), 0) EqBrkdwn,
*/
	   IsNull(eb.EQBkdwnPrem, 0) EqBrkdwn,
       sum(GWP)  -
/*
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
*/
	  IsNull(eb.EQBkdwnPrem, 0) TotGWP,
      aaa.TreatySharePct,
	  convert(money, round((sum(GWP)  -
/*
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
*/
	   IsNull(eb.EQBkdwnPrem, 0))  *  aaa.TreatySharePct, 2)) AssumedPremium,


	   aaa.AssumedCommissionPct,
	   convert(money, round((sum(GWP)  -
/*
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
*/
	   IsNull(eb.EQBkdwnPrem, 0))  *  aaa.AssumedCommissionPct, 2)) AssumedCommission


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
			   co.CompanyName,
			   IsNull(crtls.TreatySharePct, 0) TreatySharePct,
			   IsNull(crtls.AssumedCommissionPct, 0) AssumedCommissionPct,
	          ISNULL((SELECT     SUM(INVD.AmtBilled)
							FROM       [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].[tblFin_Invoices] bb,
							           [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].tblFin_InvoiceDetails INVD
							INNER JOIN [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].tblFin_PolicyCharges PC ON INVD.ChargeCode = PC.ChargeCode
							WHERE a.QuoteID = bb.QuoteID
							  AND bb.Failed = 0     
							  AND INVD.InvoiceNum = bb.InvoiceNum
							  AND      INVD.CompanyLineGuid = cl.CompanyLineGuid
							  AND        PC.ChargeType = 'P'
							), 0) GWP
		from [Sandbox].[dbo].tblQuotes tq,
		     [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].tblQuotes a
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
		where tq.QuoteID = a.QuoteID
		  and convert(date, case when tq.DateBound < tq.EffectiveDate then tq.EffectiveDate else tq.DateBound end) < dateadd(d, 1, @ReportEndDate)			
		  and a.QuoteID = b.QuoteID
		  and b.Failed = 0
		  and b.InvoiceNum = id.InvoiceNum
		  and id.CompanyLineGuid = cl.CompanyLineGUID
		  and cl.CompanyLocationGUID = cloc.CompanyLocationGUID
		  and cloc.CompanyGUID = co.CompanyGUID
		  and co.CompanyName <> 'Placeholder Company'
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
			   co.CompanyName,
			   crtls.TreatySharePct,
			   crtls.AssumedCommissionPct,
--			   b.InvoiceNum,
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
			   zzz.CompanyName,
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
			   co.CompanyName,
			   IsNull(crtls.TreatySharePct, 0) TreatySharePct,
			   IsNull(crtls.AssumedCommissionPct, 0) AssumedCommissionPct,
		--	   max(b.AnnualPremium) GWP
			   convert(money, case when IsNull(max(asp.AutoBTM), 0) = 0
							  then max(asp.ALPrem)
							  else max(asp.AlPrem) + (max(asp.AlPrem) / (max(asp.AlPrem) + max(asp.APDPrem)) * max(asp.AutoBTM)) end) GWP
		from [Sandbox].[dbo].tblQuotes tq,
		     [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].tblQuotes a
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
		where tq.QuoteID = a.QuoteID
		  and convert(date, case when tq.DateBound < tq.EffectiveDate then tq.EffectiveDate else tq.DateBound end) < dateadd(d, 1, @ReportEndDate)
		  and a.QuoteID = b.QuoteID
		  and b.Failed = 0
		  and b.InvoiceNum = id.InvoiceNum
		  and id.CompanyLineGuid = cl.CompanyLineGUID
		  and cl.CompanyLocationGUID = cloc.CompanyLocationGUID
		  and cloc.CompanyGUID = co.CompanyGUID
		  and co.CompanyName <> 'Placeholder Company'
		  and cl.LineGUID = c.LineGUID
		  and co.CompanyID = crt.CompanyID
		  and crt.CompanyReinsTreatyID = crtls.CompanyReinsTreatyID
		  and c.LineID = crtls.LineID 
		  and convert(date, a.EffectiveDate) between crt.TreatyBeginDate and crt.TreatyEndDate
		  and c.LineName = 'Commercial Auto'
		  and tq.QuoteID = asp.QuoteID
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
			   co.CompanyName,
			   crtls.TreatySharePct,
			   crtls.AssumedCommissionPct,
--			   b.InvoiceNum,
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
			   co.CompanyName,
			   IsNull(crtls.TreatySharePct, 0) TreatySharePct,
			   IsNull(crtls.AssumedCommissionPct, 0) AssumedCommissionPct,
		--	   max(b.AnnualPremium) GWP
			   convert(money, case when IsNull(max(asp.AutoBTM), 0) = 0
							  then max(asp.APDPrem) 
							  else max(asp.APDPrem) + (max(asp.APDPrem) / (max(asp.AlPrem) + max(asp.APDPrem)) * max(asp.AutoBTM)) end) GWP
		from [Sandbox].[dbo].tblQuotes tq,
		     [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].tblQuotes a
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
		where tq.QuoteID = a.QuoteID
		  and convert(date, case when tq.DateBound < tq.EffectiveDate then tq.EffectiveDate else tq.DateBound end) < dateadd(d, 1, @ReportEndDate)
		  and a.QuoteID = b.QuoteID
		  and b.Failed = 0
		  and b.InvoiceNum = id.InvoiceNum
		  and id.CompanyLineGuid = cl.CompanyLineGUID
		  and cl.CompanyLocationGUID = cloc.CompanyLocationGUID
		  and cloc.CompanyGUID = co.CompanyGUID
		  and co.CompanyName <> 'Placeholder Company'
		  and cl.LineGUID = c.LineGUID
		  and co.CompanyID = crt.CompanyID
		  and crt.CompanyReinsTreatyID = crtls.CompanyReinsTreatyID
		  and c.LineID = crtls.LineID 
		  and convert(date, a.EffectiveDate) between crt.TreatyBeginDate and crt.TreatyEndDate
		  and c.LineName = 'Commercial Auto'
		  and tq.QuoteID = asp.QuoteID
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
			   co.CompanyName,
			   crtls.TreatySharePct,
			   crtls.AssumedCommissionPct,
--			   b.InvoiceNum,
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
			   zzz.CompanyName,
			   zzz.TreatySharePct,
			   zzz.AssumedCommissionPct


		) aaa
   left join #EqBreakdown eb
     on aaa.QuoteID = eb.QuoteID
	and aaa.LineName = 'Commercial Property'

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
				aaa.CompanyName,
			   aaa.TreatySharePct,
			   aaa.AssumedCommissionPct,
			   eb.EQBkdwnPrem
		) ccc

		set @ReportBeginDate	= dateadd(dd, 1, @ReportEndDate)
		set @ReportEndDate		= dateadd(dd, -1, dateadd(m, 1, @ReportBeginDate))

end


drop table #Auto_Subline_Premium_by_QuoteID
drop table #EqBreakdown


truncate table [Sandbox].[dbo].tblQuotes



end