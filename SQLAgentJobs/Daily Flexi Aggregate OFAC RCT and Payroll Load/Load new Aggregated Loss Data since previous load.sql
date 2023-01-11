USE FHE


declare @ReportBeginDate		datetime
declare @AsOfDate				date

/*  RELOAD

truncate table [FHE].[dbo].[LossesByYYYYMM]

*/

select @ReportBeginDate = IsNull(max(added_date), '1/1/2018')
from [FHE].[dbo].[LossesByYYYYMM]

set @AsOfDate = GetDate()



begin 

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
						 InsuredState			char(2),
						 TreatySharePct			decimal(6, 5))

create nonclustered index idx_tblQuotes1 on #tblQuotes (QuoteID, PolicyNumber)

insert into #tblQuotes
select a.QuoteID,
       a.PolicyNumber,
	   a.EndorsementEffective,
	   a.EffectiveDate,
	   a.CompanyLineGuid,
	   a.LineGUID,
	   a.RiskDescription,
	   a.InsuredPolicyName,
	   a.ProducerName,
	   a.InsuredCity,
	   a.InsuredState,
	   IsNull(rtls.TreatySharePct, 0) TreatySharePct
from [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].[tblQuotes] a,
	 [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].[lstLines] f,
	 [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].[tblCompanyLines] cl,
	 [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].[tblCompanyLocations] cloc,
	 [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].[tblCompanies] co,
	 [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[ReportReference].[CompanyReinsTreaties] rt,
	 [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[ReportReference].[CompanyReinsTreatyLineShare] rtls
where a.LineGUID = f.LineGUID
  and a.CompanyLineGuid = cl.CompanyLineGUID
  and cl.CompanyLocationGUID = cloc.CompanyLocationGUID
  and cloc.CompanyGUID = co.CompanyGUID
  and co.CompanyID = rt.CompanyID
  and convert(date, a.EffectiveDate) between rt.TreatyBeginDate and rt.TreatyEndDate
  and rt.CompanyReinsTreatyID = rtls.CompanyReinsTreatyID
  and f.LineID = rtls.LineId

insert into [FHE].[dbo].[LossesByYYYYMM]
select aaaa.*
from (
select aaa.claim_id,       
		aaa.PolicyNumber,
		aaa.InsuredPolicyName,
		(select max(RiskDescription)
		from #tblQuotes tq
		where aaa.InsuredPolicyName = tq.InsuredPolicyName
			and tq.QuoteID = (select max(tq2.QuoteID)
							from #tblQuotes tq2
							where tq2.InsuredPolicyName = tq.InsuredPolicyName)) ContractorType,
		aaa.claim_num,
		aaa.ClaimantName,
		aaa.policy_year,
		aaa.reported_date,
		convert(char(6), aaa.reported_date, 112) reported_yyyymm,
		aaa.loss_date,
		datepart(yyyy, aaa.loss_date) accident_year,
		aaa.added_date,
		convert(char(6), aaa.added_date, 112) trans_yyyymm,
/*  MH  - 9/12/2022 - Per Matt, use the loss date instead of the date deported

		datepart(yyyy, aaa.added_date) - datepart(yyyy, aaa.reported_date) valuation_year,
		((convert(int, datepart(yyyy, aaa.added_date)) - convert(int, datepart(yyyy, aaa.reported_date))) * 4) + convert(int, datepart(q, aaa.added_date)) -1 valuation_qtr,
		((convert(int, datepart(yyyy, aaa.added_date)) - convert(int, datepart(yyyy, aaa.reported_date))) * 12) + convert(int, datepart(m, aaa.added_date)) -1 valuation_month,

		datediff(d, aaa.reported_date, aaa.added_date) / 365.25 trend_year,
		datediff(d, aaa.reported_date, aaa.added_date) / 91.3125 trend_qtr,
		datediff(d, aaa.reported_date, aaa.added_date) / 30.4375 trend_month,

*/

		datepart(yyyy, aaa.added_date) - datepart(yyyy, aaa.loss_date) valuation_year,
		((convert(int, datepart(yyyy, aaa.added_date)) - convert(int, datepart(yyyy, aaa.loss_date))) * 4) + convert(int, datepart(q, aaa.added_date)) -1 valuation_qtr,
		((convert(int, datepart(yyyy, aaa.added_date)) - convert(int, datepart(yyyy, aaa.loss_date))) * 12) + convert(int, datepart(m, aaa.added_date)) -1 valuation_month,

		datediff(d, aaa.loss_date, aaa.added_date) / 365.25 trend_year,
		datediff(d, aaa.loss_date, aaa.added_date) / 91.3125 trend_qtr,
		datediff(d, aaa.loss_date, aaa.added_date) / 30.4375 trend_month,

		aaa.closed_date,
		datediff(d, aaa.loss_date, aaa.reported_date) report_lag,
		aaa.days_open,
		aaa.LOB,
		aaa.claim_status,
		aaa.coverage_name,
		aaa.adjuster,
		aaa.loss_location,
		aaa.insured_location,  
		aaa.in_ligitation,
		case when aaa.in_ligitation = 'Y' then aaa.jurisdiction end jurisdiction,
		case when aaa.in_ligitation = 'Y' then aaa.defense_attorney end defense_attorney,
		aaa.Broker,
		aaa.Carrier,
		IsNull(case when aaa.MainTransType = 'Paid Loss' and aaa.IndExp = 'I'
						then aaa.Amount * -1 
						when aaa.MainTransType in ('Reserve', 'Recovery') and aaa.IndExp = 'I'
						then aaa.Amount
						end, 0) IndeminityOutstandingReserve,
		IsNull(case when aaa.MainTransType = 'Paid Loss' and aaa.IndExp = 'E'
						then aaa.Amount * -1 
						when aaa.MainTransType in ('Reserve', 'Recovery') and aaa.IndExp = 'E'
						then aaa.Amount
						end, 0) ExpenseOutstandingReserve,
		IsNull(case when aaa.MainTransType = 'Paid Loss' and aaa.IndExp = 'I' and aaa.transaction_indicator not in ('R', 'I')
/*  MH  6/14/2022 - This is a Paid Reimbursement that should be included as a Paid Loss */
--	                                                        and aaa.reserve_paid_id <> '000250000263171'
						then aaa.Amount end, 0) IndemnityPaid,
		IsNull(case when aaa.MainTransType = 'Paid Loss' and aaa.IndExp = 'E' and aaa.transaction_indicator not in ('R', 'I')
						then aaa.Amount end, 0) ExpensePaid,
		IsNull(case when aaa.MainTransType = 'Recovery' and aaa.IndExp = 'I'
						then aaa.Amount * -1 end, 0) IndemnityRecovery,
		IsNull(case when aaa.MainTransType = 'Recovery' and aaa.IndExp = 'E'
						then aaa.Amount * -1 end, 0) ExpenseRecovery,
		IsNull(case when aaa.IndExp = 'I' and aaa.MainTransType in ('Reserve', 'Recovery')
						then aaa.Amount end, 0) IndemnityIncurredLoss,
		IsNull(case when aaa.IndExp = 'E' and aaa.MainTransType in ('Reserve', 'Recovery')
						then aaa.Amount end, 0) ExpenseIncurredLoss,
		case when aaa.TransType like '%Reserve%'  and aaa.IndExp = 'I' then aaa.reserve_date end last_indemnity_reserve_post,
		case when aaa.TransType like '%Reserve%'  and aaa.IndExp = 'E' then aaa.reserve_date end last_expense_reserve_post,
		aaa.TreatySharePct,
		aaa.party_id
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
		f.LineCode PolicyType,
		lob.lob_name LOB,
		j.item_name coverage_name,
		h.reserve_type_name, 
		b.party_id,
		loc.accident_city,
		loc.accident_state,
		loc.accident_zip,
		(select u.first_name + ' ' + u.last_name
		from [dbo].[fh_claim_history] k,
				[dbo].[fh_user] u
		where k.claim_id = a.claim_id
			and k.history_datetime = (select max(kk.history_datetime)
									from [dbo].[fh_claim_history] kk
									where k.claim_id = kk.claim_id
										and kk.history_datetime < dateadd(d, 1, @AsOfDate))
			and k.handler_id = u.user_id) adjuster,
		ltrim(case when b.first_name is NULL 
			then b.last_name
			else b.first_name + ' ' + b.last_name end) ClaimantName,
		a.loss_date,
		a.reported_date,	   
		(select cs.open_close_date
		from [dbo].[fv_party_status] cs
		where b.party_id = cs.party_id
			and cs.open_close_date = (select max(cs2.open_close_date)
									from [dbo].[fv_party_status] cs2
									where cs.party_id = cs2.party_id
										and cs2.open_close_status_name = 'Closed'
										and cs2.open_close_date < dateadd(d, 1, @AsOfDate))) closed_date,
		(select cs.open_close_status_name
		from [dbo].[fv_party_status] cs
		where b.party_id = cs.party_id
			and cs.open_close_date = (select max(cs2.open_close_date)
									from [dbo].[fv_party_status] cs2
									where cs.party_id = cs2.party_id
										and cs2.open_close_date < dateadd(d, 1, @AsOfDate)))
		claim_status,
		datediff(d, a.reported_date, case when ph.open_close_status = 'C'
											then ph.closed_date 
											else @AsOfDate end) days_open,
		c.reserve_date,
		IsNull(c.added_date, a.reported_date) added_date,
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
					from [dbo].[fv_lookup_pay_recov_type] rt
					where c.recovery_type = rt.recovery_type_code)
			when c.reserve_or_paid_code = 'R'
			then c.reserve_description
			end TransType,
		case when i.item_name = 'Indemnity' then 'I'
			else 'E' end IndExp,  	   
		(select ph.in_litigation_yn
		from [dbo].[fh_party_history] ph
		where b.party_id = ph.party_id
			and ph.history_datetime = (select max(ph2.history_datetime)
										from [dbo].[fh_party_history] ph2
										where ph.party_id = ph2.party_id
										and ph2.history_datetime < dateadd(d, 1, @AsOfDate))) in_ligitation,   
--	   c.recovery_type,
		c.loss_amt Amount,
		c.reserve_paid_id,
		ls.court_description jurisdiction,
		ls.defendant_attorney_name defense_attorney,
		e.ProducerName Broker,
		cloc.LocationName Carrier,
		(select ltrim(acc.accident_city + case when IsNull(acc.accident_city, ' ') = ' ' then ' ' else ', ' end + acc.accident_state)
		from [dbo].[fh_claim_accident] acc
		where a.claim_id = acc.claim_id) loss_location,
		e.InsuredCity + ', ' + e.InsuredState insured_location,
		e.TreatySharePct
from [dbo].[fh_claim] a
		left join [dbo].[fh_code_client] g
		on a.loss_causation_id = g.item_id
		left join 
		[dbo].[fh_lawsuit] ls
		on a.claim_id = ls.claim_id,
		[dbo].[fh_claim_accident] loc,
		[dbo].[fh_party] b
		left join [dbo].[fh_reserve_paid] c
		on b.party_id = c.party_id
		and c.added_date >= @ReportBeginDate
		and c.added_date <= dateadd(d, 1, @AsOfDate)
		left join [dbo].[fh_reserve_type] rt
		on rt.reserve_type_id = c.reserve_type_id
		left join [dbo].[fh_reserve_type] h
		on c.reserve_type_id = h.reserve_type_id
		left join [dbo].[fh_code_general] i
		on i.item_id = h.reserve_group_id /* 
		left join [dbo].[fh_claim_history] k
		on k.claim_id = c.claim_id
		and k.history_datetime = (select max(kk.history_datetime)
								from [dbo].[fh_claim_history] kk
								where k.claim_id = kk.claim_id
									and kk.history_datetime < dateadd(d, 1, @AsOfDate)) */
		left join [dbo].[fh_policy_coverage] pc
		on b.policy_coverage_id = pc.policy_coverage_id
		left join [dbo].[fh_code_general] j
		on j.item_id = pc.coverage_id
		left join [dbo].[fh_lob] lob
		on pc.lob_id = lob.lob_id,
		[dbo].[fh_policy] d,
		#tblQuotes e,
		[MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].[lstLines] f,
		[MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].[tblCompanyLines] cl,
		[MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].[tblCompanyLocations] cloc,
		[MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].[tblCompanies] co,
		[dbo].[fh_party_history] ph
where /*d.tier1_company_id = 'C13339'
	and */a.claim_id = b.claim_id
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
	and ph.claim_id = b.claim_id
	and ph.party_id = b.party_id
	and ph.history_datetime = (select max(ph2.history_datetime)
							from [dbo].[fh_party_history] ph2
							where ph.claim_id = ph2.claim_id
								and ph.party_id = ph2.party_id
								and ph2.history_datetime < dateadd(d, 1, @AsOfDate))
--  and a.fh_claim_num in ('207796')

) aaa
where IsNull(aaa.added_date, aaa.reported_date) > @ReportBeginDate
) aaaa

drop table #tblQuotes


end