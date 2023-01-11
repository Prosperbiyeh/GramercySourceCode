use [FHE]

declare	@load_start_dt	datetime
declare @load_end_dt	datetime
declare @rows			int

set @load_start_dt = GETDATE()


begin transaction 

delete from FHE.dbo.fh_policy
delete from FHE.dbo.fh_policy_coverage
delete from FHE.dbo.fh_claim
delete from FHE.dbo.fh_claim_history
delete from FHE.dbo.fh_claim_accident
delete from FHE.dbo.fh_party
delete from FHE.dbo.fh_party_history
delete from FHE.dbo.fh_party_status
delete from FHE.dbo.fh_payable
delete from FHE.dbo.fh_reserve_paid
delete from FHE.dbo.fh_lawsuit
delete from FHE.dbo.fh_reserve_type
delete from FHE.dbo.fh_company
delete from FHE.dbo.fh_code_client
delete from FHE.dbo.fh_code_general
delete from FHE.dbo.fh_user
delete from FHE.dbo.fh_lob
delete from FHE.dbo.fh_lookup

insert into [FHE].[dbo].[fh_policy]
select policy_id,
		branch_id,
		tier1_company_id,
		policy_num,
		primary_carrier_id,
		policy_desc,
		deductible_amt,
		aggregate_limit_amt,
		primary_holder_name,
		secondary_holder_name,
		holder_address1,
		holder_address2,
		holder_city,
		holder_state,
		holder_zip_code,
		holder_phone,
		holder_fax,
		replication_flag,
		policy_begin_date,
		policy_end_date,
		policy_premium_amt,
		cancellation_date,
		global_yn,
		lob_id,
		tier_company_id,
		policy_plan_id,
		cert_no,
		hourly_rate,
		mileage_rate,
		comments,
		broker_id,
		writing_carrier_id,
		location_number,
		temp_tier1_company_id,
		entered_date
from [10.16.3.60].[FECertus].[dbo].fh_policy
where tier1_company_id = 'C13339'




insert into [FHE].[dbo].[fh_policy_coverage]
select c.policy_coverage_id,
		c.policy_id,
		c.coverage_id,
		c.branch_id,
		c.carrier_company_id,
		c.begin_coverage_amt,
		c.end_coverage_amt,
		c.coverage_pct,
		c.replication_flag,
		c.begin_coverage_date,
		c.end_coverage_date,
		c.sir_with_lob,
		c.lob_id,
		c.deductible,
		c.sir,
		c.med_pay,
		c.limit_of_liability,
		c.lol_per_claim,
		c.aggregate,
		c.comments,
		c.class_a_erodes,
		c.class_b_erodes,
		c.class_c_erodes,
		c.class_d_erodes,
		c.sir_deduct_flag
from [10.16.3.60].[FECertus].[dbo].fh_policy a,
     [10.16.3.60].[FECertus].[dbo].fh_policy_coverage c
where a.tier1_company_id = 'C13339'
  and a.policy_id = c.policy_id





insert into [FHE].[dbo].[fh_claim]
select b.claim_id,
		b.branch_id,
		b.fh_claim_num,
		b.tier_claim_num,
		b.lob_id,
		b.handler_id,
		b.tier_company_id,
		b.tier_contact_id,
		b.bill_to_company_id,
		b.received_date,
		b.reported_date,
		b.loss_date,
		b.lost_time_yn,
		b.in_hearing_yn,
		b.controlling_state,
		b.loss_causation_id,
		b.accident_location_id,
		b.claim_type_id,
		b.claim_status_id,
		b.closure_method_id,
		b.open_close_status,
		b.closed_date,
		b.reopened_date,
		b.policy_id,
		b.claimant_id,
		b.next_log_num,
		b.billing_type,
		b.billing_schedule_id,
		b.final_bill_yn,
		b.close_after_final_bill_yn,
		b.flat_fee_bill_date,
		b.bill_comment_id,
		b.replication_flag,
		b.print_bill_type,
		b.print_bill_method,
		b.osha_yn,
		b.claim_text1,
		b.claim_text2,
		b.claim_text3,
		b.claim_text4,
		b.claim_text5,
		b.claim_code1,
		b.claim_code2,
		b.claim_code3,
		b.claim_code4,
		b.claim_code5,
		b.claim_date1,
		b.claim_date2,
		b.claim_date3,
		b.claim_date4,
		b.claim_date5,
		b.claim_numb1,
		b.claim_numb2,
		b.claim_numb3,
		b.claim_numb4,
		b.claim_numb5,
		b.catastrophe_number,
		b.claim_catastrophe_yn,
		b.claim_category,
		b.date_entered,
		b.duplicate_yn,
		b.old_claim_id,
		b.payroll_state,
		b.policy_location_id,
		b.sic_code,
		b.original_claim_number,
		b.copyfrom_date,
		b.copyto_date,
		b.edi_sent_fh_claim_num,
		b.secondary_handler_id,
		b.legacy_claim_num,
		b.ace_analysis_of_loss_code,
		b.ace_accident_town_code,
		b.pay_freeze_flag,
		b.sub_location_id,
		b.sir,
		b.deductible,
		b.class_a_erodes,
		b.policy_coverage_id,
		b.temp_pol_id,
		b.class_b_erodes,
		b.class_c_erodes,
		b.class_d_erodes,
		b.handler_id2,
		b.confidential_include_yn
from [10.16.3.60].[FECertus].[dbo].fh_policy a,
     [10.16.3.60].[FECertus].[dbo].fh_claim b
where a.tier1_company_id = 'C13339'
  and a.policy_id = b.policy_id



insert into [FHE].[dbo].[fh_claim_history]
select c.history_datetime,
		c.history_action_type,
		c.history_user_id,
		c.claim_id,
		c.branch_id,
		c.fh_claim_num,
		c.tier_claim_num,
		c.lob_id,
		c.handler_id,
		c.tier_company_id,
		c.tier_contact_id,
		c.bill_to_company_id,
		c.received_date,
		c.reported_date,
		c.loss_date,
		c.lost_time_yn,
		c.in_hearing_yn,
		c.controlling_state,
		c.loss_causation_id,
		c.accident_location_id,
		c.claim_type_id,
		c.claim_status_id,
		c.closure_method_id,
		c.open_close_status,
		c.closed_date,
		c.reopened_date,
		c.policy_id,
		c.claimant_id,
		c.next_log_num,
		c.billing_type,
		c.billing_schedule_id,
		c.final_bill_yn,
		c.close_after_final_bill_yn,
		c.flat_fee_bill_date,
		c.bill_comment_id,
		c.replication_flag,
		c.print_bill_type,
		c.print_bill_method,
		c.osha_yn,
		c.claim_text1,
		c.claim_text2,
		c.claim_text3,
		c.claim_text4,
		c.claim_text5,
		c.claim_code1,
		c.claim_code2,
		c.claim_code3,
		c.claim_code4,
		c.claim_code5,
		c.claim_date1,
		c.claim_date2,
		c.claim_date3,
		c.claim_date4,
		c.claim_date5,
		c.claim_numb1,
		c.claim_numb2,
		c.claim_numb3,
		c.claim_numb4,
		c.claim_numb5,
		c.catastrophe_number,
		c.claim_catastrophe_yn,
		c.claim_category,
		c.date_entered,
		c.duplicate_yn,
		c.old_claim_id,
		c.payroll_state,
		c.policy_location_id,
		c.sic_code,
		c.original_claim_number,
		c.copyfrom_date,
		c.copyto_date,
		c.edi_sent_fh_claim_num,
		c.handler_id2,
		c.confidential_include_yn
from [10.16.3.60].[FECertus].[dbo].fh_policy a,
     [10.16.3.60].[FECertus].[dbo].fh_claim b,
     [10.16.3.60].[FECertus].[dbo].fh_claim_history c
where a.tier1_company_id = 'C13339'
  and a.policy_id = b.policy_id
  and b.claim_id = c.claim_id




insert into [FHE].[dbo].[fh_claim_accident]
select c.claim_id,
		c.accident_location,
		c.accident_city,
		c.accident_state,
		c.accident_zip,
		c.accident_county,
		c.police_agency,
		c.police_report,
		c.insured_cited_yn,
		c.insured_cited_rsn,
		c.other_cited_yn,
		c.other_cited_rsn,
		c.facts,
		c.country_id
from [10.16.3.60].[FECertus].[dbo].fh_policy a,
     [10.16.3.60].[FECertus].[dbo].fh_claim b,
     [10.16.3.60].[FECertus].[dbo].fh_claim_accident c
where a.tier1_company_id = 'C13339'
  and a.policy_id = b.policy_id
  and b.claim_id = c.claim_id





insert into [FHE].[dbo].[fh_party]
select c.party_id,
		c.claim_id,
		c.branch_id,
		c.party_type_code,
		c.open_close_status,
		c.open_close_date,
		c.party_num,
		c.first_name,
		c.middle_initial,
		c.last_name,
		c.soc_sec_num,
		c.address1,
		c.address2,
		c.city,
		c.state,
		c.zip_code,
		c.home_phone,
		c.work_phone,
		c.other_phone,
		c.age,
		c.sex,
		c.occupation_id,
		c.department_id,
		c.injury_id,
		c.sickness_id,
		c.body_part_id,
		c.osha_200_id,
		c.pay_period,
		c.pay_type,
		c.avg_weekly_wage,
		c.full_or_restricted,
		c.in_litigation_yn,
		c.in_subrogation_yn,
		c.spouse_name,
		c.spouse_address1,
		c.spouse_address2,
		c.spouse_city,
		c.spouse_state,
		c.spouse_zip_code,
		c.spouse_age,
		c.spouse_soc_sec_num,
		c.spouse_home_phone,
		c.spouse_work_phone,
		c.spouse_other_phone,
		c.number_of_dependents,
		c.driver_license_num,
		c.vehicle_driver_yn,
		c.vehicle_passenger_yn,
		c.vehicle_owner_yn,
		c.pedestrian_yn,
		c.facts,
		c.represented_by_lawyer_yn,
		c.represented_by_doctor_yn,
		c.deductible_amt,
		c.deductible_paid_yn,
		c.premises_type,
		c.premises_description,
		c.premises_owner_name,
		c.premises_owner_address,
		c.premises_owner_phone,
		c.product_type,
		c.product_description,
		c.product_mfg_name,
		c.product_mfg_address,
		c.product_mfg_phone,
		c.accident_location,
		c.product_site_location,
		c.name_of_fire_police_called,
		c.replication_flag,
		c.as_of_status_code,
		c.opened_date,
		c.closed_date,
		c.reopened_date,
		c.birth_date,
		c.hire_date,
		c.death_date,
		c.last_work_day_date,
		c.first_day_off_work_date,
		c.return_to_work_date,
		c.spouse_birth_date,
		c.party_text1,
		c.party_text2,
		c.party_text3,
		c.party_text4,
		c.party_text5,
		c.party_code1,
		c.party_code2,
		c.party_code3,
		c.party_code4,
		c.party_code5,
		c.party_date1,
		c.party_date2,
		c.party_date3,
		c.party_date4,
		c.party_date5,
		c.party_numb1,
		c.party_numb2,
		c.party_numb3,
		c.party_numb4,
		c.party_numb5,
		c.accident_description,
		c.agree_to_compensate,
		c.aww_method,
		c.class_code,
		c.subclass_code,
		c.comp_rate,
		c.controversion_yn,
		c.date_claim_denied,
		c.date_dw3_received,
		c.date_of_representation,
		c.days_per_week,
		c.denial_reason_code,
		c.denial_recession_date,
		c.denial_reason_description,
		c.employment_status,
		c.estimated_aww,
		c.fraud_indicator,
		c.initial_treatment_code,
		c.injury_description,
		c.injury_site_address1,
		c.injury_site_address2,
		c.injury_site_city,
		c.injury_site_state,
		c.injury_site_zip_code,
		c.marital_status,
		c.mco,
		c.mmi_date,
		c.on_premises_yn,
		c.other_loss_condition,
		c.other_weekly_pay,
		c.percent_impairment,
		c.preferred_worker_yn,
		c.prior_existence_yn,
		c.represented_yn_dw3,
		c.salary_continued_yn,
		c.surgery_required_yn,
		c.wages_paid_on_dol_yn,
		c.year_last_exposed,
		c.loss_condition_code,
		c.driver_license_state,
		c.property_id,
		c.osha_private_yn,
		c.email_address,
		c.pmsi_sent_flag,
		c.pmsi_status,
		c.ccsbr_sent_flag,
		c.msp_query_yn,
		c.policy_coverage_id,
		c.legacy_party_num,
		c.ace_claimant_type_code,
		c.ace_damage_status_code,
		c.country_id,
		c.iron_coverage_id,
		c.location_number,
		c.red_display_yn,
		c.body_part_location_cd,
		c.body_part_finger_toe_cd
from [10.16.3.60].[FECertus].[dbo].fh_policy a,
     [10.16.3.60].[FECertus].[dbo].fh_claim b,
     [10.16.3.60].[FECertus].[dbo].fh_party c
where a.tier1_company_id = 'C13339'
  and a.policy_id = b.policy_id
  and b.claim_id = c.claim_id





insert into [FHE].[dbo].[fh_party_history]
select d.history_datetime,
		d.history_action_type,
		d.history_user_id,
		d.party_id,
		d.claim_id,
		d.branch_id,
		d.party_type_code,
		d.open_close_status,
		d.open_close_date,
		d.party_num,
		d.first_name,
		d.middle_initial,
		d.last_name,
		d.soc_sec_num,
		d.address1,
		d.address2,
		d.city,
		d.state,
		d.zip_code,
		d.home_phone,
		d.work_phone,
		d.other_phone,
		d.age,
		d.sex,
		d.occupation_id,
		d.department_id,
		d.injury_id,
		d.sickness_id,
		d.body_part_id,
		d.osha_200_id,
		d.pay_period,
		d.pay_type,
		d.avg_weekly_wage,
		d.full_or_restricted,
		d.in_litigation_yn,
		d.in_subrogation_yn,
		d.spouse_name,
		d.spouse_address1,
		d.spouse_address2,
		d.spouse_city,
		d.spouse_state,
		d.spouse_zip_code,
		d.spouse_age,
		d.spouse_soc_sec_num,
		d.spouse_home_phone,
		d.spouse_work_phone,
		d.spouse_other_phone,
		d.number_of_dependents,
		d.driver_license_num,
		d.vehicle_driver_yn,
		d.vehicle_passenger_yn,
		d.vehicle_owner_yn,
		d.pedestrian_yn,
		d.facts,
		d.represented_by_lawyer_yn,
		d.represented_by_doctor_yn,
		d.deductible_amt,
		d.deductible_paid_yn,
		d.premises_type,
		d.premises_description,
		d.premises_owner_name,
		d.premises_owner_address,
		d.premises_owner_phone,
		d.product_type,
		d.product_description,
		d.product_mfg_name,
		d.product_mfg_address,
		d.product_mfg_phone,
		d.accident_location,
		d.product_site_location,
		d.name_of_fire_police_called,
		d.replication_flag,
		d.as_of_status_code,
		d.opened_date,
		d.closed_date,
		d.reopened_date,
		d.birth_date,
		d.hire_date,
		d.death_date,
		d.last_work_day_date,
		d.first_day_off_work_date,
		d.return_to_work_date,
		d.spouse_birth_date,
		d.party_text1,
		d.party_text2,
		d.party_text3,
		d.party_text4,
		d.party_text5,
		d.party_code1,
		d.party_code2,
		d.party_code3,
		d.party_code4,
		d.party_code5,
		d.party_date1,
		d.party_date2,
		d.party_date3,
		d.party_date4,
		d.party_date5,
		d.party_numb1,
		d.party_numb2,
		d.party_numb3,
		d.party_numb4,
		d.party_numb5,
		d.accident_description,
		d.agree_to_compensate,
		d.aww_method,
		d.class_code,
		d.subclass_code,
		d.comp_rate,
		d.controversion_yn,
		d.date_claim_denied,
		d.date_dw3_received,
		d.date_of_representation,
		d.days_per_week,
		d.denial_reason_code,
		d.denial_recession_date,
		d.denial_reason_description,
		d.employment_status,
		d.estimated_aww,
		d.fraud_indicator,
		d.initial_treatment_code,
		d.injury_description,
		d.injury_site_address1,
		d.injury_site_address2,
		d.injury_site_city,
		d.injury_site_state,
		d.injury_site_zip_code,
		d.marital_status,
		d.mco,
		d.mmi_date,
		d.on_premises_yn,
		d.other_loss_condition,
		d.other_weekly_pay,
		d.percent_impairment,
		d.preferred_worker_yn,
		d.prior_existence_yn,
		d.represented_yn_dw3,
		d.salary_continued_yn,
		d.surgery_required_yn,
		d.wages_paid_on_dol_yn,
		d.year_last_exposed,
		d.loss_condition_code,
		d.driver_license_state,
		d.property_id,
		d.osha_private_yn,
		d.email_address,
		d.pmsi_sent_flag,
		d.pmsi_status,
		d.ccsbr_sent_flag,
		d.msp_query_yn,
		d.body_part_location_cd,
		d.body_part_finger_toe_cd
from [10.16.3.60].[FECertus].[dbo].fh_policy a,
     [10.16.3.60].[FECertus].[dbo].fh_claim b,
     [10.16.3.60].[FECertus].[dbo].fh_party c,
	 [10.16.3.60].[FECertus].[dbo].fh_party_history d
where a.tier1_company_id = 'C13339'
  and a.policy_id = b.policy_id
  and b.claim_id = c.claim_id
  and c.party_id = d.party_id




insert into [FHE].[dbo].[fh_party_status]
select d.party_status_id,
		d.party_id,
		d.claim_id,
		d.branch_id,
		d.open_close_status,
		d.open_close_date,
		d.replication_flag,
		d.claim_status
from [10.16.3.60].[FECertus].[dbo].fh_policy a,
     [10.16.3.60].[FECertus].[dbo].fh_claim b,
     [10.16.3.60].[FECertus].[dbo].fh_party c,
	 [10.16.3.60].[FECertus].[dbo].fh_party_status d
where a.tier1_company_id = 'C13339'
  and a.policy_id = b.policy_id
  and b.claim_id = c.claim_id
  and c.party_id = d.party_id




insert into [FHE].[dbo].[fh_payable]
select d.payable_id,
		d.branch_id,
		d.check_register_yn,
		d.paid_yn,
		d.transaction_type_code,
		d.deposit_or_payment_code,
		d.payment_status_code,
		d.party_id,
		d.claim_id,
		d.lob_id,
		d.checking_account_id,
		d.vendor_selection_code,
		d.payment_type_id,
		d.payee_num,
		d.payee_name,
		d.address1,
		d.address2,
		d.city,
		d.state,
		d.zip_code,
		d.invoice_num,
		d.invoice_amt,
		d.approved_amt,
		d.type_1099,
		d.icd9_id1,
		d.icd9_id2,
		d.icd9_id3,
		d.icd9_id4,
		d.lost_time_yn,
		d.lost_days_num,
		d.extra_days_num,
		d.payable_comment,
		d.statement_of_account,
		d.posted_payable_user_id,
		d.approved_payable_user_id,
		d.check_num,
		d.cleared_bank_yn,
		d.reimbursement_id,
		d.check_type_code,
		d.replication_flag,
		d.check_print_batch,
		d.invoice_date,
		d.service_begin_date,
		d.service_end_date,
		d.check_date,
		d.void_date,
		d.approved_date,
		d.benefit_adj_amt,
		d.benefit_adj_code,
		d.comp_rate,
		d.export_indicator,
		d.late_reason,
		d.lump_sum_yn,
		d.main_id,
		d.posted_date,
		d.unreconciled_indicator,
		d.void_stoppay_indicator,
		d.mmi_date,
		d.recovery_type,
		d.subro_or_property_id,
		d.check_book_id,
		d.repriced_yn,
		d.provider_first,
		d.provider_last,
		d.invoice_type,
		d.bill_type,
		d.length_of_stay,
		d.drg_code,
		d.jurisdiction_state,
		d.jurisdiction_zip,
		d.image_id,
		d.pmsi_bill_id,
		d.pmsi_image_ref_num,
		d.ccsbr_bill_id,
		d.ppo_network_name,
		d.override_ofac_yn,
		d.distribute_yn,
		d.distribute_date,
		d.ace_flag,
		d.country,
		d.iron_transaction_id,
		d.iron_transaction_type,
		d.policy_coverage_id,
		d.billable_yn,
		d.invoice_id,
		d.voided_invoice_id,
		d.taxable_approved_amt,
		d.ace_non_taxable_trans_code,
		d.ace_transaction_code,
		d.SIR_process_date,
		d.above_amt,
		d.below_amt,
		d.gl_sent_date,
		d.gl_void_sent_date,
		d.temp_policy_coverage_id,
		d.TempApplyToSIR,
		d.TempBelowAmt,
		d.TempAboveAmt,
		d.image_id2
from [10.16.3.60].[FECertus].[dbo].fh_policy a,
     [10.16.3.60].[FECertus].[dbo].fh_claim b,
     [10.16.3.60].[FECertus].[dbo].fh_party c,
	 [10.16.3.60].[FECertus].[dbo].fh_payable d
where a.tier1_company_id = 'C13339'
  and a.policy_id = b.policy_id
  and b.claim_id = c.claim_id
  and c.party_id = d.party_id




insert into [FHE].[dbo].[fh_reserve_paid]
select d.reserve_paid_id,
		d.party_id,
		d.claim_id,
		d.branch_id,
		d.payable_id,
		d.handler_id,
		d.reserve_or_paid_code,
		d.reserve_description,
		d.reserve_type_id,
		d.reserve_paid_amt,
		d.replication_flag,
		d.reserve_date,
		d.current_claim_category,
		d.current_party_status,
		d.modified_indicator,
		d.reserve_type_code,
		d.transaction_indicator,
		d.paid_yn,
		d.present_value_yn,
		d.current_pay_type,
		d.alae_amt,
		d.loss_amt,
		d.recovery_type,
		d.added_date,
		d.iron_transaction_id,
		d.error_flag_yn
from [10.16.3.60].[FECertus].[dbo].fh_policy a,
     [10.16.3.60].[FECertus].[dbo].fh_claim b,
     [10.16.3.60].[FECertus].[dbo].fh_party c,
	 [10.16.3.60].[FECertus].[dbo].fh_reserve_paid d
where a.tier1_company_id = 'C13339'
  and a.policy_id = b.policy_id
  and b.claim_id = c.claim_id
  and c.party_id = d.party_id

set @rows = @@ROWCOUNT


/*  MH  - 12/01/2022 - To adjust $350,000 reserve that was deleted from
               FHE by Certus on 11/18/2022 back to its original date */

update [FHE].[dbo].[fh_reserve_paid]
set added_date = '2020-06-24 12:57:03.703',
    reserve_date = '2020-06-24 12:56:46.000',
	reserve_description = 'New Reserve',
	reserve_type_code = 'NEW'
where reserve_paid_id = '000250000346512'




insert into [FHE].[dbo].[fh_lawsuit]
select d.lawsuit_id,
		d.party_id,
		d.claim_id,
		d.branch_id,
		d.lawsuit_type,
		d.court_cause_num,
		d.court_state,
		d.court_federal_code,
		d.court_description,
		d.trial_date_flag,
		d.estimated_recovery_amt,
		d.actual_recovery_amt,
		d.judge_name,
		d.possible_jury_composition,
		d.judge_notes,
		d.court_notes,
		d.jury_notes,
		d.plaintiff_name,
		d.plaintiff_address1,
		d.plaintiff_address2,
		d.plaintiff_attorney_name,
		d.plaintiff_attorney_address1,
		d.plaintiff_attorney_address2,
		d.plaintiff_attorney_phone,
		d.plaintiff_attorney_fax,
		d.plaintiff_attorney_notes,
		d.defendant_name,
		d.defendant_address1,
		d.defendant_address2,
		d.defendant_attorney_name,
		d.defendant_attorney_address1,
		d.defendant_attorney_address2,
		d.defendant_attorney_phone,
		d.defendant_attorney_fax,
		d.defendant_attorney_notes,
		d.facts_of_loss,
		d.nature_of_plaintiff_claim,
		d.liability_issues_involved,
		d.statement_of_liability,
		d.plaintiff_negligence_pct,
		d.defendant_negligence_pct,
		d.co_defendant_names,
		d.defense_notes,
		d.indemnity_notes,
		d.hold_harmless_notes,
		d.contribution_notes,
		d.property_damage_paid_amt,
		d.property_damage_owed_amt,
		d.lost_wages_incurred_amt,
		d.lost_wages_owed_amt,
		d.medical_expense_incurred_amt,
		d.medical_expense_owed_amt,
		d.other_damages_amt,
		d.other_damages_description,
		d.liens_to_be_protected_amt,
		d.liens_description,
		d.defendant_advanced_pay_amt,
		d.defendant_advanced_pay_desc,
		d.plaintiff_collateral_amt,
		d.plaintiff_collateral_desc,
		d.expense_cost_to_date_amt,
		d.preparation_cost_to_date_amt,
		d.expert_wit_cost_to_date_amt,
		d.trial_time_cost_to_date_amt,
		d.current_demand_amt,
		d.current_offer_amt,
		d.negotiation_notes,
		d.plaintiff_strength_weak_notes,
		d.defendant_strength_weak_notes,
		d.counterclaim_filed_yn,
		d.cost_to_defend_low_amt,
		d.cost_to_defend_high_amt,
		d.jury_value_low_amt,
		d.jury_value_high_amt,
		d.settlement_value_low_amt,
		d.settlement_value_high_amt,
		d.cash_settlement_struct_desc,
		d.petition_notes,
		d.discovery_notes,
		d.motion_notes,
		d.notes,
		d.replication_flag,
		d.trial_date,
		d.current_demand_date,
		d.current_offer_date,
		d.petition_filed_date,
		d.petition_answer_due_date,
		d.petition_answered_date,
		d.our_discovery_filed_date,
		d.our_discovery_answer_due_date,
		d.our_discovery_answered_date,
		d.their_discovery_filed_date,
		d.their_disc_answer_due_date,
		d.their_discovery_answered_date,
		d.our_motion_filed_date,
		d.our_motion_answer_due_date,
		d.our_motion_answered_date,
		d.their_motion_filed_date,
		d.their_motion_answer_due_date,
		d.their_motion_answered_date,
		d.reconstruction_request_date,
		d.reconstruction_received_date,
		d.pretrial_report_request_date,
		d.pretrial_report_received_date,
		d.lien_letter_date
from [10.16.3.60].[FECertus].[dbo].fh_policy a,
     [10.16.3.60].[FECertus].[dbo].fh_claim b,
     [10.16.3.60].[FECertus].[dbo].fh_party c,
	 [10.16.3.60].[FECertus].[dbo].fh_lawsuit d
where a.tier1_company_id = 'C13339'
  and a.policy_id = b.policy_id
  and b.claim_id = c.claim_id
  and c.party_id = d.party_id




insert into [FHE].[dbo].[fh_reserve_type]
select d.reserve_type_id,
		d.reserve_type_name,
		d.reserve_group_id,
		d.replication_flag,
		d.line_no,
		d.med_button,
		d.order_number,
		d.party_type,
		d.medicare_bi_yn,
		d.ace_coverage_code,
		d.ace_reserve_code,
		d.iron_coverage_id,
		d.iron_reserve_code,
		d.indemnity_yn
from [10.16.3.60].[FECertus].[dbo].fh_reserve_type d




insert into [FHE].[dbo].[fh_company]
select d.company_id,
		d.company_code,
		d.company_group,
		d.tier_type,
		d.company_name,
		d.tier1_company_id,
		d.tier2_company_id,
		d.tier3_company_id,
		d.tier4_company_id,
		d.tier5_company_id,
		d.tier6_company_id,
		d.tier1_name,
		d.tier2_name,
		d.tier3_name,
		d.tier4_name,
		d.tier5_name,
		d.tier6_name,
		d.address1,
		d.address2,
		d.city,
		d.state,
		d.zip_code,
		d.county,
		d.federal_id,
		d.phone1,
		d.phone2,
		d.fax,
		d.checking_account_id,
		d.next_claim_num,
		d.handler_hourly_rate,
		d.clerical_hourly_rate,
		d.mileage_rate,
		d.photograph_rate,
		d.photocopy_rate,
		d.handler_office_percent,
		d.clerical_office_percent,
		d.flat_rate_office_percent,
		d.expense_office_percent,
		d.replication_flag,
		d.on_notice_pct,
		d.billing_service_id,
		d.quantity_num,
		d.rate_amt,
		d.office_pct,
		d.global_tier_yn,
		d.tpa_insured_flag,
		d.dba_name,
		d.cross_reference_num,
		d.email_address,
		d.self_insured_yn,
		d.employer_tier_level,
		d.location_tier_level,
		d.industry_code,
		d.location_number,
		d.ui_number,
		d.pmsi_checking_account,
		d.pmsi_charge_res_type_id,
		d.pmsi_charge_pay_type_id,
		d.pmsi_charge_loss_or_alae,
		d.pmsi_fee_res_type_id,
		d.pmsi_fee_pay_type_id,
		d.pmsi_fee_loss_or_alae,
		d.pmsi_pay_cat_code,
		d.pmsi_exclude_yn,
		d.ccsbr_exclude_yn,
		d.ccsbr_checking_account,
		d.ccsbr_charge_pay_type_id,
		d.ccsbr_charge_res_type_id,
		d.ccsbr_charge_loss_or_alae,
		d.ccsbr_fee_pay_type_id,
		d.ccsbr_fee_res_type_id,
		d.ccsbr_fee_loss_or_alae,
		d.ccsbr_pay_cat_code,
		d.specific_schedule_codes_yn,
		d.primary_handler_id,
		d.secondary_handler_id,
		d.policy_tier_level,
		d.ace_flag,
		d.country_id,
		d.bill_to_company_id,
		d.split_billing_flag,
		d.split_payable_flag,
		d.concept_one_flag,
		d.ironshore_flag,
		d.ironshore_location_flag,
		d.entity_id,
		d.copy_note_to_invoice_flag,
		d.payable_invoicing_yn,
		d.begin_date,
		d.analytic_export_yn,
		d.analytic_amount,
		d.analytic_bill_to,
		d.analytic_bill_service,
		d.analytic_bill_charge,
		d.analytic_medical_days,
		d.analytic_diary_handler,
		d.analytic_diary_priority,
		d.analytic_fee_type,
		d.analytic_payee_fed_id,
		d.analytic_payment_type,
		d.analytic_reserve_type,
		d.analytic_financial_type,
		d.sage_export_yn
from [10.16.3.60].[FECertus].[dbo].fh_policy a,
	 [10.16.3.60].[FECertus].[dbo].fh_company d
where a.tier1_company_id = 'C13339'
  and a.tier_company_id = d.company_id
group by d.company_id,
		d.company_code,
		d.company_group,
		d.tier_type,
		d.company_name,
		d.tier1_company_id,
		d.tier2_company_id,
		d.tier3_company_id,
		d.tier4_company_id,
		d.tier5_company_id,
		d.tier6_company_id,
		d.tier1_name,
		d.tier2_name,
		d.tier3_name,
		d.tier4_name,
		d.tier5_name,
		d.tier6_name,
		d.address1,
		d.address2,
		d.city,
		d.state,
		d.zip_code,
		d.county,
		d.federal_id,
		d.phone1,
		d.phone2,
		d.fax,
		d.checking_account_id,
		d.next_claim_num,
		d.handler_hourly_rate,
		d.clerical_hourly_rate,
		d.mileage_rate,
		d.photograph_rate,
		d.photocopy_rate,
		d.handler_office_percent,
		d.clerical_office_percent,
		d.flat_rate_office_percent,
		d.expense_office_percent,
		d.replication_flag,
		d.on_notice_pct,
		d.billing_service_id,
		d.quantity_num,
		d.rate_amt,
		d.office_pct,
		d.global_tier_yn,
		d.tpa_insured_flag,
		d.dba_name,
		d.cross_reference_num,
		d.email_address,
		d.self_insured_yn,
		d.employer_tier_level,
		d.location_tier_level,
		d.industry_code,
		d.location_number,
		d.ui_number,
		d.pmsi_checking_account,
		d.pmsi_charge_res_type_id,
		d.pmsi_charge_pay_type_id,
		d.pmsi_charge_loss_or_alae,
		d.pmsi_fee_res_type_id,
		d.pmsi_fee_pay_type_id,
		d.pmsi_fee_loss_or_alae,
		d.pmsi_pay_cat_code,
		d.pmsi_exclude_yn,
		d.ccsbr_exclude_yn,
		d.ccsbr_checking_account,
		d.ccsbr_charge_pay_type_id,
		d.ccsbr_charge_res_type_id,
		d.ccsbr_charge_loss_or_alae,
		d.ccsbr_fee_pay_type_id,
		d.ccsbr_fee_res_type_id,
		d.ccsbr_fee_loss_or_alae,
		d.ccsbr_pay_cat_code,
		d.specific_schedule_codes_yn,
		d.primary_handler_id,
		d.secondary_handler_id,
		d.policy_tier_level,
		d.ace_flag,
		d.country_id,
		d.bill_to_company_id,
		d.split_billing_flag,
		d.split_payable_flag,
		d.concept_one_flag,
		d.ironshore_flag,
		d.ironshore_location_flag,
		d.entity_id,
		d.copy_note_to_invoice_flag,
		d.payable_invoicing_yn,
		d.begin_date,
		d.analytic_export_yn,
		d.analytic_amount,
		d.analytic_bill_to,
		d.analytic_bill_service,
		d.analytic_bill_charge,
		d.analytic_medical_days,
		d.analytic_diary_handler,
		d.analytic_diary_priority,
		d.analytic_fee_type,
		d.analytic_payee_fed_id,
		d.analytic_payment_type,
		d.analytic_reserve_type,
		d.analytic_financial_type,
		d.sage_export_yn




insert into [FHE].[dbo].[fh_code_client]
select d.item_id,
		d.item_code,
		d.item_name,
		d.code_type_id,
		d.tier1_company_id,
		d.replication_flag,
		d.active_yn,
		d.confidential_yn,
		d.default_yn,
		d.group_description,
		d.sub_code,
		d.icd9_e_code,
		d.ace_code,
		d.ironshore_code,
		d.icd10_code,
		d.inactive_date
from [10.16.3.60].[FECertus].[dbo].fh_code_client d
where d.tier1_company_id = 'C13339'




insert into [FHE].[dbo].[fh_code_general]
select d.item_id,
		d.item_code,
		d.item_name,
		d.code_type_id,
		d.replication_flag,
		d.closed_limit_amt,
		d.confidential_yn,
		d.default_yn,
		d.effect_1099_yn,
		d.effect_incurred_yn,
		d.effect_paids_yn,
		d.group_description,
		d.order_number,
		d.prorate_yn,
		d.state_code,
		d.sub_code,
		d.active_yn,
		d.stat_code,
		d.ace_code,
		d.ironshore_code,
		d.ind_or_exp_flag,
		d.auto_close_diary_yn,
		d.analytic_type
from [10.16.3.60].[FECertus].[dbo].fh_code_general d




insert into [FHE].[dbo].[fh_user]
select d.user_id,
		d.user_type,
		d.user_job,
		d.role_id,
		d.last_name,
		d.first_name,
		d.user_name,
		d.branch_id,
		d.claim_id,
		d.supervisor_id,
		d.next_log_num,
		d.access_day1,
		d.access_day2,
		d.access_day3,
		d.access_day4,
		d.access_day5,
		d.access_day6,
		d.access_day7,
		d.replication_flag,
		d.logon_status,
		d.logon_last_date,
		d.reserve_max,
		d.approve_max,
		d.tier_filter_expression,
		d.assign_claim_yn,
		d.active_user_yn,
		d.alter_pay_type_yn,
		d.brch_sel_on_prt_check_yn,
		d.dial_in_branch_id,
		d.change_note_date_yn,
		d.claim_category_update_yn,
		d.brch_sel_on_view_pay_yn,
		d.diary_other_users_yn,
		d.diary_update_days,
		d.note_access,
		d.note_update_days,
		d.notes_other_user_yn,
		d.other_branch_access_yn,
		d.reserve_update_date_yn,
		d.reserve_update_desc_yn,
		d.third_party_access,
		d.tier_access,
		d.transfer_payment_yn,
		d.update_void_date_yn,
		d.view_confid_claims_yn,
		d.pk_num_beg,
		d.pk_num_end,
		d.internal_use1,
		d.global_handler_yn,
		d.edit_claim_num_yn,
		d.pass_last_changed,
		d.no_fail_attempts,
		d.last_login_attempt,
		d.temp_yn,
		d.pass_expire_days,
		d.email_address,
		d.automation_user_type,
		d.phone_number,
		d.confirm_timeout,
		d.pmsi_login,
		d.pmsi_password,
		d.pmsi_supervisor_yn,
		d.claim_search_sort,
		d.party_search_sort,
		d.email_signature,
		d.title,
		d.fax_number,
		d.menu_bar_style,
		d.menu_collapse_delay,
		d.supervisor_id2,
		d.service_date_override_yn,
		d.imap_host,
		d.imap_port,
		d.imap_username,
		d.imap_password,
		d.imap_folder,
		d.imap_max,
		d.login_ipv4_restricted_yn,
		d.login_ipv4_range_low,
		d.login_ipv4_range_high,
		d.login_ipv6_restricted_yn,
		d.login_ipv6_range_low,
		d.login_ipv6_range_high,
		d.noncheck_max,
		d.view_private_diary_yn,
		d.reserves_by_claim_or_transaction
from [10.16.3.60].[FECertus].[dbo].fh_user d




insert into [FHE].[dbo].[fh_lob]
select d.lob_id,
		d.lob_name,
		d.lob_type,
		d.replication_flag,
		d.default_on_dddw_yn
from [10.16.3.60].[FECertus].[dbo].fh_lob d




insert into [FHE].[dbo].[fh_lookup]
select d.lookup_id,
		d.lookup_type,
		d.lookup_code,
		d.lookup_display
from [10.16.3.60].[FECertus].[dbo].fh_lookup d


commit



set @load_end_dt = GETDATE()

insert into [FHE].[dbo].[load_info]
values(@load_start_dt, @load_end_dt, @rows)