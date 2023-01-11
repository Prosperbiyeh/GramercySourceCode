
declare @ReportAsOfDate			date;
declare @InForceOnly			int;

set @ReportAsOfDate     = convert(date, GetDate())
set @InForceOnly		= 1


delete from [Sandbox].[dbo].[InForceVehicleCountsByYYYYMM] where YYYYMM = convert(char(6), @ReportAsOfDate, 112)


insert into [Sandbox].[dbo].[InForceVehicleCountsByYYYYMM]
select convert(char(6), @ReportAsOfDate, 112) YYYYMM,
		'Commercial Auto Liability' LineName,
		aa.InsuredType,
		count(case when aa.VehicleType = 'Private Passenger Type'
					then aa.VehicleUnitNumber end) PPVehicles,
		count(case when aa.VehicleType = 'Truck'
					then aa.VehicleUnitNumber end) Trucks,
		count(case when aa.VehicleType like '%Trailer%'
					then aa.VehicleUnitNumber end) Trailers
from (
select --q.QuoteID,
		--q.TransactionTypeID,
		q.InsuredPolicyName InsuredName,
		(select max(tq2.RiskDescription)
		from [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].tblQuotes tq1,
				[MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].tblSubmissionGroup sg1,
				[MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].tblSubmissionGroup sg2,
				[MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].tblQuotes tq2
		where q.QuoteID = tq1.QuoteID
			and tq1.SubmissionGroupGuid = sg1.SubmissionGroupGuid
			and sg1.InsuredGuid = sg2.InsuredGuid
			and sg2.SubmissionGroupGUID = tq2.SubmissionGroupGuid
			and tq2.QuoteID = (select max(tq3.QuoteID)
								from [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].tblQuotes tq3
								where tq3.SubmissionGroupGUID = tq2.SubmissionGroupGuid
								and tq3.RiskDescription is not NULL)) InsuredType,
		q.PolicyNumber,
		q.EffectiveDate,
		bv.RegState,
		loc.City Location,
--	   loc.UnitNumber,
--	   bv.BusinessAutoID,
--	   bv.[Current],
		loc.BusinessAutoTerritory,
		bv.VIN,
		bv.VehicleUnitNumber,
		bv.VehicleTypeDesc VehicleType,
		bv.ClassCode VehicleClassCode,
		bv.ModelYear,
		IsNull(bv.WeightClass, 'N/A') WeightClass,
		convert(money, bv.CostNew) CostNew,
		(select case when IsNumeric(bvv.Comprehensive) = 1
				then '$' + bvv.Comprehensive
				else bvv.Comprehensive end
		from [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].[NetRate_Quote_Insur_Quote_Locat_Busin_Vehic_Vehic] bvv
		where bv.VehiclePolicyLimitsID = bvv.VehicleID
			and bvv.NodeName = 'VehicleCoverages') CompDeductible,
		(select case when IsNumeric(bvv.Collision) = 1
				then '$' + bvv.Collision
				else bvv.Collision end
		from [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].[NetRate_Quote_Insur_Quote_Locat_Busin_Vehic_Vehic] bvv
		where bv.VehiclePolicyLimitsID = bvv.VehicleID
			and bvv.NodeName = 'VehicleCoverages') CollisionDeductible,
		(select   case when IsNumeric(Liability) = 0 then 0 else
				convert(money, IsNull(replace(replace(Liability, ',', ''), '$', ''), 0)) end +
				case when IsNumeric(Medical) = 0 then 0 else
				convert(money, IsNull(replace(replace(Medical, ',', ''), '$', ''), 0)) end +
				case when IsNumeric(PersonalInjury) = 0 then 0 else
				convert(money, IsNull(replace(replace(PersonalInjury, ',', ''), '$', ''), 0)) end +
     			case when IsNumeric(PPI) = 0 then 0 else
				convert(money, IsNull(replace(replace(PPI, ',', ''), '$', ''), 0)) end +
				case when IsNumeric(Uninsured) = 0 then 0 else
				convert(money, IsNull(replace(replace(Uninsured, ',', ''), '$', ''), 0)) end +
				case when IsNumeric(Underinsured) = 0 then 0 else
				convert(money, IsNull(replace(replace(Underinsured, ',', ''), '$', ''), 0)) end +
				case when IsNumeric(UninsuredPD) = 0 then 0 else
				convert(money, IsNull(replace(replace(UninsuredPD, ',', ''), '$', ''), 0)) end +
				case when IsNumeric(SpecifiedCause) = 0 then 0 else
				convert(money, IsNull(replace(replace(SpecifiedCause, ',', ''), '$', ''), 0)) end
		from [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].[NetRate_Quote_Insur_Quote_Locat_Busin_Vehic_Vehic] bvv
		where bv.VehiclePolicyLimitsID = bvv.VehicleID
			and bvv.NodeName = 'VehiclePremiums') AutoLiabilityPremium,
		(select   case when IsNumeric(Comprehensive) = 0 then 0 else
				convert(money, IsNull(replace(replace(Comprehensive, ',', ''), '$', ''), 0)) end +
				case when IsNumeric(Collision) = 0 then 0 else	            
				convert(money, IsNull(replace(replace(Collision, ',', ''), '$', ''), 0)) end +
				case when IsNumeric(Towing) = 0 then 0 else
				convert(money, IsNull(replace(replace(Towing, ',', ''), '$', ''), 0)) end +
				case when IsNumeric(Rental) = 0 then 0 else
				convert(money, IsNull(replace(replace(Rental, ',', ''), '$', ''), 0)) end +
				case when IsNumeric(Audio) = 0 then 0 else
				convert(money, IsNull(replace(replace(Audio, ',', ''), '$', ''), 0)) end +
				case when IsNumeric(Tapes) = 0 then 0 else
				convert(money, IsNull(replace(replace(Tapes, ',', ''), '$', ''), 0)) end +
				case when IsNumeric(WindHailQuake) = 0 then 0 else
				convert(money, IsNull(replace(replace(WindHailQuake, ',', ''), '$', ''), 0)) end +
				case when IsNumeric(MCCA) = 0 then 0 else
				convert(money, IsNull(replace(replace(MCCA, ',', ''), '$', ''), 0)) end +
				case when IsNumeric(CollisionWaiver) = 0 then 0 else
				convert(money, IsNull(replace(replace(CollisionWaiver, ',', ''), '$', ''), 0)) end + 
				IsNull(PDLiabBuyback, 0) +
				IsNull(AutoLoan, 0) +
				IsNull(Cargo, 0) +
				convert(money, IsNull(replace(replace(SupplementalSpouse, ',', ''), '$', ''), 0)) +
				IsNull(UninsuredPassengers, 0) +
				IsNull(CombinedPhysical, 0) +
				convert(money, IsNull(replace(replace(UnderinsuredPD, ',', ''), '$', ''), 0)) +
				convert(money, IsNull(replace(replace(CombinedPhysicalTowingUnit, ',', ''), '$', ''), 0)) +
				IsNull(UninsuredDed, 0) +
				IsNull(AutoLoanOTC, 0) +
				IsNull(AutoLoanColl, 0)
		from [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].[NetRate_Quote_Insur_Quote_Locat_Busin_Vehic_Vehic] bvv
		where bv.VehiclePolicyLimitsID = bvv.VehicleID
			and bvv.NodeName = 'VehiclePremiums') AutoPDPremium
from [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].[tblQuotes] q,
		[MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].[NetRate_Quote_Insur_Quote_Polic] pol,
		[MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].[NetRate_Quote_Insur_Quote_Locat] loc,
		[MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].[NetRate_Quote_Insur_Quote_Locat_Busin] lb,
		[MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].[NetRate_Quote_Insur_Quote_Locat_Busin_Vehic] bv,
		[MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].[tblCompanyLocations] cloc
where q.PolicyNumber is not NULL
	and q.QuoteID = (select max(aa.QuoteID)
					from [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].[tblQuotes] aa
					where aa.PolicyNumber = q.PolicyNumber
					and aa.EffectiveDate = q.EffectiveDate
					and aa.DateCreated <= @ReportAsOfDate
					and aa.EffectiveDate < @ReportAsOfDate)
	and q.ExpirationDate >= case when @InForceOnly = 1
								then @ReportAsOfDate
								else q.ExpirationDate end
	and q.QuoteStatusID <> 12
	and q.NetRate_QuoteID = pol.QuoteID
	and pol.QuoteID = loc.QuoteID
	and loc.LocationID = lb.LocationID
--  and loc.UnitNumber = 1
	and lb.BusinessAutoID = bv.BusinessAutoID
	and bv.UnitNumber is not NULL
	and IsNull(bv.[Transaction], '') <> 'Deleted'
	and q.CompanyLocationGuid = cloc.CompanyLocationGUID
	and q.InsuredPolicyName not like 'Test -%'
--  and q.QuoteID = 6303
) aa
group by aa.InsuredType
union all
select convert(char(6), @ReportAsOfDate, 112) YYYYMM,
		'Commercial Auto PD' LineName,
		InsuredType,
		count(case when aa.VehicleType = 'Private Passenger Type' and aa.AutoPDPremium > 0
					then aa.VehicleUnitNumber end) PPVehicles,
		count(case when aa.VehicleType = 'Truck' and aa.AutoPDPremium > 0
					then aa.VehicleUnitNumber end) Trucks,
		count(case when aa.VehicleType like '%Trailer%' and aa.AutoPDPremium > 0
					then aa.VehicleUnitNumber end) Trailers
from (
select --q.QuoteID,
		--q.TransactionTypeID,
		q.InsuredPolicyName InsuredName,
		(select max(tq2.RiskDescription)
		from [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].tblQuotes tq1,
				[MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].tblSubmissionGroup sg1,
				[MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].tblSubmissionGroup sg2,
				[MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].tblQuotes tq2
		where q.QuoteID = tq1.QuoteID
			and tq1.SubmissionGroupGuid = sg1.SubmissionGroupGuid
			and sg1.InsuredGuid = sg2.InsuredGuid
			and sg2.SubmissionGroupGUID = tq2.SubmissionGroupGuid
			and tq2.QuoteID = (select max(tq3.QuoteID)
								from [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].tblQuotes tq3
								where tq3.SubmissionGroupGUID = tq2.SubmissionGroupGuid
								and tq3.RiskDescription is not NULL)) InsuredType,
		q.PolicyNumber,
		q.EffectiveDate,
		bv.RegState,
		loc.City Location,
--	   loc.UnitNumber,
--	   bv.BusinessAutoID,
--	   bv.[Current],
		loc.BusinessAutoTerritory,
		bv.VIN,
		bv.VehicleUnitNumber,
		bv.VehicleTypeDesc VehicleType,
		bv.ClassCode VehicleClassCode,
		bv.ModelYear,
		IsNull(bv.WeightClass, 'N/A') WeightClass,
		convert(money, bv.CostNew) CostNew,
		(select case when IsNumeric(bvv.Comprehensive) = 1
				then '$' + bvv.Comprehensive
				else bvv.Comprehensive end
		from [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].[NetRate_Quote_Insur_Quote_Locat_Busin_Vehic_Vehic] bvv
		where bv.VehiclePolicyLimitsID = bvv.VehicleID
			and bvv.NodeName = 'VehicleCoverages') CompDeductible,
		(select case when IsNumeric(bvv.Collision) = 1
				then '$' + bvv.Collision
				else bvv.Collision end
		from [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].[NetRate_Quote_Insur_Quote_Locat_Busin_Vehic_Vehic] bvv
		where bv.VehiclePolicyLimitsID = bvv.VehicleID
			and bvv.NodeName = 'VehicleCoverages') CollisionDeductible,
		(select   case when IsNumeric(Liability) = 0 then 0 else
				convert(money, IsNull(replace(replace(Liability, ',', ''), '$', ''), 0)) end +
				case when IsNumeric(Medical) = 0 then 0 else
				convert(money, IsNull(replace(replace(Medical, ',', ''), '$', ''), 0)) end +
				case when IsNumeric(PersonalInjury) = 0 then 0 else
				convert(money, IsNull(replace(replace(PersonalInjury, ',', ''), '$', ''), 0)) end +
     			case when IsNumeric(PPI) = 0 then 0 else
				convert(money, IsNull(replace(replace(PPI, ',', ''), '$', ''), 0)) end +
				case when IsNumeric(Uninsured) = 0 then 0 else
				convert(money, IsNull(replace(replace(Uninsured, ',', ''), '$', ''), 0)) end +
				case when IsNumeric(Underinsured) = 0 then 0 else
				convert(money, IsNull(replace(replace(Underinsured, ',', ''), '$', ''), 0)) end +
				case when IsNumeric(UninsuredPD) = 0 then 0 else
				convert(money, IsNull(replace(replace(UninsuredPD, ',', ''), '$', ''), 0)) end +
				case when IsNumeric(SpecifiedCause) = 0 then 0 else
				convert(money, IsNull(replace(replace(SpecifiedCause, ',', ''), '$', ''), 0)) end
		from [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].[NetRate_Quote_Insur_Quote_Locat_Busin_Vehic_Vehic] bvv
		where bv.VehiclePolicyLimitsID = bvv.VehicleID
			and bvv.NodeName = 'VehiclePremiums') AutoLiabilityPremium,
		(select   case when IsNumeric(Comprehensive) = 0 then 0 else
				convert(money, IsNull(replace(replace(Comprehensive, ',', ''), '$', ''), 0)) end +
				case when IsNumeric(Collision) = 0 then 0 else	            
				convert(money, IsNull(replace(replace(Collision, ',', ''), '$', ''), 0)) end +
				case when IsNumeric(Towing) = 0 then 0 else
				convert(money, IsNull(replace(replace(Towing, ',', ''), '$', ''), 0)) end +
				case when IsNumeric(Rental) = 0 then 0 else
				convert(money, IsNull(replace(replace(Rental, ',', ''), '$', ''), 0)) end +
				case when IsNumeric(Audio) = 0 then 0 else
				convert(money, IsNull(replace(replace(Audio, ',', ''), '$', ''), 0)) end +
				case when IsNumeric(Tapes) = 0 then 0 else
				convert(money, IsNull(replace(replace(Tapes, ',', ''), '$', ''), 0)) end +
				case when IsNumeric(WindHailQuake) = 0 then 0 else
				convert(money, IsNull(replace(replace(WindHailQuake, ',', ''), '$', ''), 0)) end +
				case when IsNumeric(MCCA) = 0 then 0 else
				convert(money, IsNull(replace(replace(MCCA, ',', ''), '$', ''), 0)) end +
				case when IsNumeric(CollisionWaiver) = 0 then 0 else
				convert(money, IsNull(replace(replace(CollisionWaiver, ',', ''), '$', ''), 0)) end + 
				IsNull(PDLiabBuyback, 0) +
				IsNull(AutoLoan, 0) +
				IsNull(Cargo, 0) +
				convert(money, IsNull(replace(replace(SupplementalSpouse, ',', ''), '$', ''), 0)) +
				IsNull(UninsuredPassengers, 0) +
				IsNull(CombinedPhysical, 0) +
				convert(money, IsNull(replace(replace(UnderinsuredPD, ',', ''), '$', ''), 0)) +
				convert(money, IsNull(replace(replace(CombinedPhysicalTowingUnit, ',', ''), '$', ''), 0)) +
				IsNull(UninsuredDed, 0) +
				IsNull(AutoLoanOTC, 0) +
				IsNull(AutoLoanColl, 0)
		from [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].[NetRate_Quote_Insur_Quote_Locat_Busin_Vehic_Vehic] bvv
		where bv.VehiclePolicyLimitsID = bvv.VehicleID
			and bvv.NodeName = 'VehiclePremiums') AutoPDPremium
from [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].[tblQuotes] q,
		[MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].[NetRate_Quote_Insur_Quote_Polic] pol,
		[MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].[NetRate_Quote_Insur_Quote_Locat] loc,
		[MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].[NetRate_Quote_Insur_Quote_Locat_Busin] lb,
		[MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].[NetRate_Quote_Insur_Quote_Locat_Busin_Vehic] bv,
		[MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].[tblCompanyLocations] cloc
where q.PolicyNumber is not NULL
	and q.QuoteID = (select max(aa.QuoteID)
					from [MGADS0005.NY.MGASYSTEMS.COM].[GramercyRisk].[dbo].[tblQuotes] aa
					where aa.PolicyNumber = q.PolicyNumber
					and aa.EffectiveDate = q.EffectiveDate
					and aa.DateCreated <= @ReportAsOfDate
					and aa.EffectiveDate < @ReportAsOfDate)
	and q.ExpirationDate >= case when @InForceOnly = 1
								then @ReportAsOfDate
								else q.ExpirationDate end
	and q.QuoteStatusID <> 12
	and q.NetRate_QuoteID = pol.QuoteID
	and pol.QuoteID = loc.QuoteID
	and loc.LocationID = lb.LocationID
--  and loc.UnitNumber = 1
	and lb.BusinessAutoID = bv.BusinessAutoID
	and bv.UnitNumber is not NULL
	and IsNull(bv.[Transaction], '') <> 'Deleted'
	and q.CompanyLocationGuid = cloc.CompanyLocationGUID
	and q.InsuredPolicyName not like 'Test -%'
--  and q.QuoteID = 6303
) aa
group by aa.InsuredType